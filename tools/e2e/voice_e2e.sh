#!/usr/bin/env bash
# End-to-end test of the parent-voice flow (CONTRACTS §8) on localhost:
# forge publish → hajanek-api → device + voice upload → forge worker against a
# fake AiStack audio service → render manifest → clip download → isolation →
# shared clips across tales → delete. Needs go, python3, ffmpeg, curl.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
W=$(mktemp -d)
P_PAGES=18701 P_AUDIO=18702 P_API=18703
A=http://127.0.0.1:$P_API
cleanup() { kill $(jobs -p) 2>/dev/null || true; wait 2>/dev/null || true; rm -rf "$W"; }
trap cleanup EXIT
fail() { echo "FAIL: $*"; exit 1; }
json() { python3 -c "import sys,json;d=json.load(sys.stdin);print($1)"; }

(cd "$ROOT/forge" && go build -o bin/forge ./cmd/forge)
(cd "$ROOT/api" && CGO_ENABLED=0 go build -o bin/hajanek-api ./cmd/hajanek-api)
FORGE="$ROOT/forge/bin/forge"

mkdir -p "$W/pages" "$W/data"
"$FORGE" publish --repo "$ROOT" --content-pages "$W/pages" > /dev/null
python3 - "$W/pages/catalog.json" "http://127.0.0.1:$P_PAGES/" <<'PY'
import json, sys
p, base = sys.argv[1:]
c = json.load(open(p)); c["base_url"] = base
json.dump(c, open(p, "w"), ensure_ascii=False)
PY
ffmpeg -v error -y -f lavfi -i "sine=f=220:d=1.2" -ar 48000 -ac 1 "$W/tone.wav"
ffmpeg -v error -y -f lavfi -i "sine=f=180:d=12" -ar 48000 -ac 1 "$W/sample.wav"

(cd "$W/pages" && exec python3 -m http.server $P_PAGES --bind 127.0.0.1 > /dev/null 2>&1) &
python3 "$ROOT/tools/e2e/fake_audio.py" $P_AUDIO "$W/tone.wav" "$W/audio.log" &
PORT=$P_API DB_PATH="$W/data/api.db" DATA_DIR="$W/data/files" \
  CATALOG_URL=http://127.0.0.1:$P_PAGES/catalog.json CATALOG_POLL=2s \
  ADMIN_TOKEN=adm WORKER_TOKEN=wrk DEVICE_RATE_LIMIT=off \
  "$ROOT/api/bin/hajanek-api" > "$W/api.log" 2>&1 &
for _ in $(seq 50); do curl -sf $A/v1/catalog/version > /dev/null && break; sleep 0.2; done

export FORGE_API_URL=$A WORKER_TOKEN=wrk AUDIO_URL=http://127.0.0.1:$P_AUDIO
worker() { "$FORGE" worker --once --repo "$ROOT" > /dev/null 2>&1; }
tts_calls() { grep -c '^TTS' "$W/audio.log" || true; }
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }

TOK=$(curl -sf -X POST $A/v1/devices | json 'd["token"]'); H="Authorization: Bearer $TOK"
VID=$(curl -sf -X POST $A/v1/voices -H "$H" -F sample=@"$W/sample.wav" -F name=Test \
  -F consent=true -F "consent_text=Jsem Test a souhlasím" | json 'd["id"]')
worker
[ "$(curl -sf $A/v1/voices/"$VID" -H "$H" | json 'd["status"]')" = ready ] || fail "voice not ready"
echo "ok  voice_create → ready"

curl -sf -X POST $A/v1/voices/"$VID"/renders -H "$H" -d '{"tale":"cervena-karkulka","length_min":10}' > /dev/null
worker
M=$(curl -sf $A/v1/voices/"$VID"/renders/cervena-karkulka/10 -H "$H")
read -r ST DONE TOTAL < <(echo "$M" | json 'd["status"],d["done"],d["total"]' | tr -d "(),'")
[ "$ST" = done ] && [ "$DONE" = "$TOTAL" ] || fail "render: $ST $DONE/$TOTAL"
[ "$(tts_calls)" = "$TOTAL" ] || fail "expected $TOTAL TTS calls, got $(tts_calls)"
echo "ok  render cervena-karkulka: $DONE/$TOTAL clips, worker and api agree on utterance keys"

U=$(echo "$M" | json 'list(d["clips"].values())[0]["url"]')
curl -sf -o "$W/clip.m4a" $A"$U" -H "$H"
[ "$(ffprobe -v error -show_entries stream=codec_name -of csv=p=0 "$W/clip.m4a")" = aac ] || fail "clip is not AAC"
echo "ok  clip download (AAC)"

TOK2=$(curl -sf -X POST $A/v1/devices | json 'd["token"]'); H2="Authorization: Bearer $TOK2"
[ "$(code $A/v1/voices/"$VID" -H "$H2")$(code $A"$U" -H "$H2")$(code -X DELETE $A/v1/voices/"$VID" -H "$H2")" = 404404404 ] \
  || fail "another device can see the voice"
echo "ok  other device gets 404 everywhere"

B=$(tts_calls)
curl -sf -X POST $A/v1/voices/"$VID"/renders -H "$H" -d '{"tale":"zlatovlaska","length_min":10}' > /dev/null
worker
read -r DONE TOTAL < <(curl -sf $A/v1/voices/"$VID"/renders/zlatovlaska/10 -H "$H" | json 'd["done"],d["total"]' | tr -d "(),'")
NEW=$(( $(tts_calls) - B ))
[ "$DONE" = "$TOTAL" ] && [ "$NEW" -lt "$TOTAL" ] || fail "zlatovlaska: $DONE/$TOTAL, $NEW new calls"
echo "ok  render zlatovlaska: $TOTAL clips, $((TOTAL - NEW)) reused from cervena-karkulka"

[ "$(code -X DELETE $A/v1/voices/"$VID" -H "$H")" = 204 ] || fail "delete"
worker
grep -q "VOICE_DELETE /v1/audio/voices/hajanek-$VID" "$W/audio.log" || fail "voice not deleted in audio service"
[ "$(code $A"$U" -H "$H")" = 404 ] || fail "clip still served"
[ -z "$(find "$W/data/files" -type f -not -path '*/scripts/*')" ] || fail "files left after delete"
echo "ok  delete: sample, clips and audio-service voice gone"
echo PASS
