#!/bin/sh
# fetch_raw.sh — re-download the CC0 source recordings into raw/{id}/ (gitignored).
#
# Freesound "HQ preview" files (Ogg Vorbis, ~160–240 kbps) are public and need no
# login; the full-quality originals need a Freesound account/OAuth (see README).
# Downloads are untrusted data: each goes into its own fresh directory, is
# checked against a pinned SHA-256 and is only ever read by ffmpeg.
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
UA="HajanekAmbientFetch/1.0 (+content/ambient/README.md)"

# id | file | url | sha256
LIST='
sea|freesound-339517-hq.ogg|https://cdn.freesound.org/previews/339/339517_2367966-hq.ogg|eff8ed8beea7493ece218400f6f9b25885112e921aa4c5296e9dc9c583a07cc7
rain|freesound-235827-hq.ogg|https://cdn.freesound.org/previews/235/235827_4263095-hq.ogg|22b12d80c06f20cb1afe81cd5f153905650dd59cc56a10fc12e067d8c3dd7e1d
stream|freesound-220528-hq.ogg|https://cdn.freesound.org/previews/220/220528_3965914-hq.ogg|56a9edd45ee08e42fd950888f780b507d8a7686feab0874c434260b9cd1ee5d5
fireplace|freesound-484338-hq.ogg|https://cdn.freesound.org/previews/484/484338_5902878-hq.ogg|c7e89cf2617d36868bd9a7228193bb644e9ac43f1b1b42ddb65939200a48bd68
wind|freesound-523389-hq.ogg|https://cdn.freesound.org/previews/523/523389_2010973-hq.ogg|d57fddeea123289a35edb5e98ce6f6e01187f356b8d79627a4b7d4f895040ba8
night-meadow|freesound-333221-hq.ogg|https://cdn.freesound.org/previews/333/333221_2098408-hq.ogg|fa2c72df3427c971bdf83ef21a85d4c6223f8f56ae14f22627b4ec1b51ac1fa1
'

sha() { if command -v sha256sum >/dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -d' ' -f1; }

echo "$LIST" | while IFS='|' read -r id file url sum; do
  [ -n "$id" ] || continue
  [ -z "${1:-}" ] || [ "$1" = "$id" ] || continue
  dir="$HERE/raw/$id"
  if [ -f "$dir/$file" ] && [ "$(sha "$dir/$file")" = "$sum" ]; then
    echo "ok      $id (cached)"; continue
  fi
  rm -rf "$dir"; mkdir -p "$dir"
  curl -fsSL --retry 3 -A "$UA" -o "$dir/$file" "$url"
  got=$(sha "$dir/$file")
  if [ "$got" != "$sum" ]; then
    echo "MISMATCH $id: sha256 $got (expected $sum) — file kept for inspection" >&2
    exit 1
  fi
  echo "fetched $id"
done
