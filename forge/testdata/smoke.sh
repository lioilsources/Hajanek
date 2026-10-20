#!/usr/bin/env bash
# End-to-end smoke test without GPU and LLM: judge → ambient loop → publish into
# a throwaway pages dir → validate catalog.json (schema 2, CONTRACTS §3).
# Usage: forge/testdata/smoke.sh [TMPDIR]
set -euo pipefail
FORGE="$(cd "$(dirname "$0")/.." && pwd)"
TMP="${1:-$(mktemp -d)}"
mkdir -p "$TMP"
CONTENT="$TMP/content"; PAGES="$TMP/pages"
rm -rf "$CONTENT" "$PAGES"
cp -R "$FORGE/testdata/content" "$CONTENT"
mkdir -p "$CONTENT/ambient" "$CONTENT/presets"

cd "$FORGE"
go build -o bin/forge ./cmd/forge

./bin/forge judge --no-llm --content "$CONTENT" "$CONTENT/scripts/test-pohadka.2.md" >/dev/null

# Ambient loop: 20 s of synthetic pink noise → seamless −30 LUFS loop.
ffmpeg -hide_banner -v error -y -f lavfi -i "anoisesrc=d=20:c=pink:r=48000:a=0.2" -ac 2 "$TMP/pink.wav"
./bin/forge master-ambient "$TMP/pink.wav" "$CONTENT/ambient/night-meadow.opus" >/dev/null
echo '[{"id":"night-meadow","title":"Noční louka","license":"CC0","source":"ffmpeg anoisesrc (smoke test)","free":true}]' \
  > "$CONTENT/ambient/ambient.json"
echo '[{"id":"louka","title":"Louka","layers":[{"ambient":"night-meadow","volume":0.6}]}]' > "$CONTENT/presets/presets.json"

./bin/forge publish --content "$CONTENT" --content-pages "$PAGES" >/dev/null
# Second run must not change anything.
./bin/forge publish --content "$CONTENT" --content-pages "$PAGES" | grep -q '"changed": false'

python3 - "$PAGES" <<'PY'
import hashlib, json, os, sys
pages = sys.argv[1]
c = json.load(open(os.path.join(pages, "catalog.json")))
assert c["schema"] == 2 and c["version"] == 1, (c["schema"], c["version"])
amb = {a["id"] for a in c["ambient"]}
def check(path, sha, size):
    b = open(os.path.join(pages, path), "rb").read()
    assert len(b) == size and hashlib.sha256(b).hexdigest() == sha, path
for t in c["tales"]:
    assert t["scripts"], t["id"]
    assert t["ambient"] in amb or t["ambient"] == "", t["id"]
    for s in t["scripts"]:
        check(s["path"], s["sha256"], s["bytes"])
        assert s["est_duration_s"] > 0
for a in c["ambient"]:
    check(a["path"], a["sha256"], a["bytes"])
for p in c["presets"]:
    assert all(l["ambient"] in amb for l in p["layers"]), p["id"]
print("catalog v%d: tales %s, ambient %s, presets %s" % (c["version"],
      [(t["id"], [s["est_duration_s"] for s in t["scripts"]]) for t in c["tales"]],
      sorted(amb), [p["id"] for p in c["presets"]]))
PY
