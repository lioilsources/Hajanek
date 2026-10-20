#!/usr/bin/env bash
# End-to-end smoke test with the dummy TTS engine (no GPU, no LLM needed).
# Usage: forge/testdata/smoke.sh [TMPDIR]
set -euo pipefail
FORGE="$(cd "$(dirname "$0")/.." && pwd)"
TMP="${1:-$(mktemp -d)}"
mkdir -p "$TMP"
CONTENT="$TMP/content"; PAGES="$TMP/pages"
rm -rf "$CONTENT" "$PAGES"
cp -R "$FORGE/testdata/content" "$CONTENT"
mkdir -p "$CONTENT/ambient"

cd "$FORGE"
go build -o bin/forge ./cmd/forge
export FORGE_TTS_ENGINE=dummy

# Ambient loop: 20 s of synthetic pink noise → seamless −30 LUFS loop.
ffmpeg -hide_banner -v error -y -f lavfi -i "anoisesrc=d=20:c=pink:r=48000:a=0.2" -ac 2 "$TMP/pink.wav"
./bin/forge master-ambient "$TMP/pink.wav" "$CONTENT/ambient/night-meadow.opus" >/dev/null
echo '[{"id":"night-meadow","title":"Noční louka","license":"CC0","source":"ffmpeg anoisesrc (smoke test)","free":true}]' \
  > "$CONTENT/ambient/ambient.json"
mkdir -p "$CONTENT/presets"
echo '[{"id":"louka","title":"Louka","layers":[{"ambient":"night-meadow","volume":0.6}]}]' > "$CONTENT/presets/presets.json"

./bin/forge run --content "$CONTENT" --tale test-pohadka --voice mama --length 2 --content-pages "$PAGES"

# Nightly from a queue file: everything cached, catalog must not change.
echo "test-pohadka mama 2" > "$TMP/queue.txt"
./bin/forge nightly --content "$CONTENT" --queue "$TMP/queue.txt" --until none --content-pages "$PAGES" >/dev/null

OUT="$PAGES/audio/test-pohadka/mama/2.opus"
echo "--- ffprobe"
ffprobe -v error -show_entries stream=codec_name,sample_rate,channels:format=duration,size -of compact "$OUT"
echo "--- ebur128"
ffmpeg -hide_banner -nostats -i "$OUT" -filter_complex ebur128=peak=true -f null - 2>&1 \
  | sed -n '/Summary:/,$p' | grep -E "I:|LRA:|Peak:"
echo "--- catalog"
python3 -c "import json,sys; c=json.load(open(sys.argv[1])); print('version', c['version'], 'tales', [t['id'] for t in c['tales']], 'ambient', [a['id'] for a in c['ambient']], 'presets', [p['id'] for p in c['presets']])" "$PAGES/catalog.json"
