#!/bin/sh
# make_loops.sh — build seamless ambient loops for Hajánek (CONTRACTS.md §4).
#
# Input : content/ambient/sources.tsv  (one row per loop id)
#         content/ambient/raw/{id}/{file}  (downloaded originals, gitignored)
# Output: content/ambient/{id}.opus   Opus 96 kbps stereo 48 kHz, −30 LUFS,
#         exactly `len` seconds, loop point continuous (tail crossfaded into head).
#
# Usage:  ./make_loops.sh            build all rows, then verify
#         ./make_loops.sh sea rain   build only these ids, then verify them
#         ./make_loops.sh --verify   only verify existing .opus files
#
# Dependencies: POSIX sh, awk, ffmpeg/ffprobe (tested with 8.1). Nothing from
# raw/ is ever executed; raw files are only read by ffmpeg as audio input.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
TSV="$HERE/sources.tsv"
RAW="$HERE/raw"
TARGET_LUFS=${TARGET_LUFS:--30}
MAX_TP=${MAX_TP:--3}          # true peak ceiling (dBTP) we assert after gain
BITRATE=${BITRATE:-96k}
TMP=$(mktemp -d "${TMPDIR:-/tmp}/hajanek-loops.XXXXXX")
[ -n "${KEEP_TMP:-}" ] && echo "temp dir kept: $TMP" >&2 || trap 'rm -rf "$TMP"' EXIT INT TERM

FF="ffmpeg -hide_banner -nostdin -loglevel error -y"

die() { echo "ERROR: $*" >&2; exit 1; }
command -v ffmpeg >/dev/null || die "ffmpeg not found"

# rows: id <TAB> file <TAB> start <TAB> len <TAB> xfade <TAB> lowpass <TAB> note
rows() { awk -F'\t' '!/^#/ && NF>=6 {print}' "$TSV"; }

# integrated loudness (LUFS) and true peak (dBTP) of a file -> "I TP"
measure() {
  ffmpeg -hide_banner -nostdin -nostats -i "$1" \
    -af ebur128=peak=true -f null - 2>&1 |
    awk '/Integrated loudness:/ {s=1} s && /I:/ {i=$2} /True peak:/ {t=1} t && /Peak:/ {p=$2} END {print i, p}'
}

build() {
  id=$1 file=$2 start=$3 len=$4 xf=$5 lp=$6
  out="$HERE/$id.opus"
  seg="$TMP/$id.seg.wav"
  loop="$TMP/$id.loop.wav"
  total=$(awk -v a="$len" -v b="$xf" 'BEGIN{print a+b}')

  # 1) source → 48 kHz stereo float, trimmed to len+xfade, cleaned
  clean="highpass=f=40:p=2"
  [ "$lp" != "-" ] && clean="$clean,lowpass=f=$lp:p=1"
  case "$file" in
    synth:pink|synth:brown)
      color=${file#synth:}
      # two independent generators (different seeds) -> decorrelated true stereo
      $FF -f lavfi -i "anoisesrc=color=$color:seed=11:sample_rate=48000:amplitude=0.5:duration=$total" \
          -f lavfi -i "anoisesrc=color=$color:seed=29:sample_rate=48000:amplitude=0.5:duration=$total" \
          -filter_complex "[0:a][1:a]join=inputs=2:channel_layout=stereo,$clean[a]" \
          -map "[a]" -c:a pcm_f32le "$seg"
      ;;
    *)
      src="$RAW/$id/$file"
      [ -f "$src" ] || die "$id: missing source $src (see README.md, download step)"
      # mono sources are duplicated to both channels (pan); stereo kept as is
      $FF -ss "$start" -t "$total" -i "$src" \
          -af "aresample=48000:filter_size=64:cutoff=0.97,aformat=sample_fmts=fltp:channel_layouts=stereo,$clean" \
          -c:a pcm_f32le "$seg"
      ;;
  esac

  # 2) seamless loop: body = seg[xf, len+xf); its last xf seconds are
  #    equal-power crossfaded with head = seg[0, xf). Output is exactly len s and
  #    its end flows into seg[xf], which is where the output starts.
  $FF -i "$seg" -filter_complex "\
[0:a]asplit=2[a][b];\
[a]atrim=start=$xf:end=$total,asetpts=PTS-STARTPTS[body];\
[b]atrim=start=0:end=$xf,asetpts=PTS-STARTPTS[head];\
[body][head]acrossfade=d=$xf:c1=qsin:c2=qsin[o]" \
      -map "[o]" -c:a pcm_f32le "$loop"

  # 3) loudness: one static gain (no dynamic loudnorm -> no gain pumping at
  #    the seam). If the gained signal would exceed MAX_TP (fire crackles have
  #    ~30 dB crest factor), a fast peak limiter softens only the transients;
  #    loudness is then re-measured and the gain corrected (2 iterations).
  set -- $(measure "$loop")
  gain=$(awk -v t="$TARGET_LUFS" -v i="$1" 'BEGIN{printf "%.2f", t-i}')
  tp=$(awk -v p="$2" -v g="$gain" 'BEGIN{printf "%.2f", p+g}')
  af="volume=${gain}dB"
  lim=""
  if awk -v tp="$tp" -v m="$MAX_TP" 'BEGIN{exit !(tp>m)}'; then
    # limit 2 dB under the ceiling to leave room for inter-sample peaks
    lin=$(awk -v m="$MAX_TP" 'BEGIN{printf "%.4f", 10^((m-2)/20)}')
    lim=",alimiter=limit=$lin:attack=2:release=40:level=0:latency=1"
    for _ in 1 2; do
      $FF -i "$loop" -af "volume=${gain}dB$lim" -c:a pcm_f32le "$TMP/$id.lim.wav"
      set -- $(measure "$TMP/$id.lim.wav")
      gain=$(awk -v g="$gain" -v t="$TARGET_LUFS" -v i="$1" 'BEGIN{printf "%.2f", g+t-i}')
    done
    af="volume=${gain}dB$lim"
    echo "  note: $id peaks limited (pre-limit TP would be $tp dBTP)"
  fi

  # 4) encode
  $FF -i "$loop" -af "$af" -c:a libopus -b:a "$BITRATE" -vbr on \
      -application audio -ar 48000 -ac 2 -map_metadata -1 \
      -metadata title="Hajanek ambient: $id" "$out"
  printf '  built %-13s %ss  gain %+6.2f dB  -> %s\n' "$id" "$len" "$gain" "$(basename "$out")"
}

# --- verify -----------------------------------------------------------------
# Decode the .opus, concatenate 3x, then:
#  * integrated LUFS (ebur128) of the 3x stream
#  * silencedetect (-60 dB, 0.5 s): must find nothing
#  * seam check: RMS of the 50 ms block centred on each seam (t=len, 2*len)
#    vs. the 20 neighbouring 50 ms blocks (±0.5 s), full band and >6 kHz
#    (a click shows up as a high-band spike). PASS if, in both bands, the seam
#    block is not louder than the loudest neighbour +1 dB, and the >6 kHz seam
#    block is within ±6 dB of the neighbours' median. (Full-band ±3 dB vs the
#    median is too strict: a natural bubble/crackle can sit on the seam.)
#    Negative controls (hard-cut brown noise / sine) score +20..25 dB.
verify_one() {
  f=$1
  id=$(basename "$f"); id=${id%.*}
  dec="$TMP/$id.dec.wav"
  x3="$TMP/$id.x3.wav"
  $FF -i "$f" -c:a pcm_f32le "$dec"
  dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$dec")
  $FF -stream_loop 2 -i "$dec" -c:a pcm_f32le "$x3"

  set -- $(measure "$x3"); lufs=$1 tpk=$2
  sil=$(ffmpeg -hide_banner -nostdin -nostats -i "$x3" \
        -af silencedetect=noise=-60dB:d=0.5 -f null - 2>&1 | grep -c silence_start || true)

  # per-50ms-block RMS, block grid offset by 25 ms so each seam is a block centre
  blocks() { # $1 = extra filter prefix
    ffmpeg -hide_banner -nostdin -nostats -i "$x3" -af \
      "${1}atrim=start=0.025,asetpts=PTS-STARTPTS,pan=mono|c0=0.5*c0+0.5*c1,asetnsamples=n=2400:p=0,astats=metadata=1:reset=1:measure_perchannel=none:measure_overall=RMS_level,ametadata=print:key=lavfi.astats.Overall.RMS_level:file=-" \
      -f null - 2>/dev/null |
      awk -F'[ =:]+' '/pts_time/ {t=$NF} /RMS_level/ {print t, $NF}'
  }
  blocks ""                                  > "$TMP/$id.full"
  blocks "highpass=f=6000:p=2,"              > "$TMP/$id.high"

  seam_eval() { # file -> "worst_delta_vs_median worst_excess_vs_max"
    awk -v L="$dur" '
      { t[NR]=$1+0.025; r[NR]=($2=="-inf")?-120:$2+0; n=NR }
      END {
        wd=0; we=-99
        for (k=1;k<=2;k++) {
          s=k*L; c=0; best=1e9
          for (i=1;i<=n;i++) { d=t[i]+0.025-s; if (d<0) d=-d; if (d<best){best=d;c=i} }
          m=0; delete nb; mx=-200
          for (j=c-10;j<=c+10;j++) if (j!=c && j>=1 && j<=n) { m++; nb[m]=r[j]; if (r[j]>mx) mx=r[j] }
          # median
          for (a=1;a<=m;a++) for (b=a+1;b<=m;b++) if (nb[b]<nb[a]) {x=nb[a];nb[a]=nb[b];nb[b]=x}
          med=(m%2)?nb[(m+1)/2]:(nb[m/2]+nb[m/2+1])/2
          dv=r[c]-med; ex=r[c]-mx
          if ((dv<0?-dv:dv) > (wd<0?-wd:wd)) wd=dv
          if (ex>we) we=ex
        }
        printf "%.1f %.1f\n", wd, we
      }' "$1"
  }
  set -- $(seam_eval "$TMP/$id.full"); fd=$1 fe=$2
  set -- $(seam_eval "$TMP/$id.high"); hd=$1 he=$2
  ok=PASS
  awk -v a="$fd" -v b="$fe" -v c="$hd" -v d="$he" \
    'BEGIN{ if (b>1||d>1||c>6||c<-6) exit 0; exit 1 }' && ok=FAIL
  [ "$sil" -gt 0 ] && ok=FAIL
  size=$(wc -c < "$f" | awk '{printf "%.0f", $1/1024}')
  printf '%-13s %6.1f %7s %7s %5s %10s %10s %4s %6s  %s\n' \
    "$id" "$dur" "$lufs" "$tpk" "$sil" "$fd/$fe" "$hd/$he" "$ok" "${size}K" ""
  [ "$ok" = PASS ]
}

verify() {
  echo
  echo "verify (loop decoded and concatenated 3x; seam = 50 ms block at each wrap)"
  echo "seam cols: dB vs median of ±0.5 s neighbours / dB above neighbours' max"
  printf '%-13s %6s %7s %7s %5s %10s %10s %4s %6s\n' \
    id len_s LUFS dBTP sil full_seam hf_seam ok size
  fails=0
  for f in "$@"; do verify_one "$f" || fails=$((fails+1)); done
  [ "$fails" -eq 0 ] || { echo "$fails loop(s) FAILED verification" >&2; return 1; }
}

# --- main -------------------------------------------------------------------
if [ "${1:-}" = "--verify" ]; then
  shift
  if [ $# -eq 0 ]; then set -- "$HERE"/*.opus; else
    l=""; for i in "$@"; do
      if [ -f "$i" ]; then l="$l $i"; else l="$l $HERE/$i.opus"; fi
    done; set -- $l; fi
  verify "$@"; exit $?
fi

want=" $* "
built=""
rows > "$TMP/rows"
while IFS="$(printf '\t')" read -r id file start len xf lp note; do
  if [ $# -gt 0 ]; then case "$want" in *" $id "*) ;; *) continue ;; esac; fi
  build "$id" "$file" "$start" "$len" "$xf" "$lp"
  built="$built $HERE/$id.opus"
done < "$TMP/rows"
[ -n "$built" ] || die "nothing built (unknown id?)"
# shellcheck disable=SC2086
verify $built
