# hajanek-api

Go služba „JODA“ pro Hajánka: katalogové endpointy pro appku, anonymní
zařízení a hlasy rodičů (vzorek → klon na Sparku → klipy po promluvách) a
fronta jobů, kterou si vybírá `forge worker` na DGX Sparku
(claim → heartbeat → complete). Kontrakt: [`docs/CONTRACTS.md`](../docs/CONTRACTS.md)
§3, §6–§8, architektura: [ADR-003](../docs/adr/ADR-003-voice-architecture.md).

- SQLite (čistě Go driver `modernc.org/sqlite`, bez cgo → jde přeložit na linux/arm64),
  migrace přes `golang-migrate` zabudované v binárce, dotazy přes `sqlc`.
- Katalog se **nehostuje** tady: služba pravidelně stahuje `catalog.json`
  z GitHub Pages (ETag / If-Modified-Since), validuje ho a poslední dobrou verzi
  drží v SQLite. Nevalidní katalog nikdy nepřepíše dobrý; stejně tak katalog
  s nižší (nebo stejnou) `version` a jiným obsahem. Katalog je `schema: 2`
  (texty skriptů, ne audio); katalog se starším schématem uložený v DB se
  po upgradu ignoruje a stáhne se znovu.
- Skripty (`tales[].scripts[].path`) se stahují z Pages až při potřebě,
  ověří se proti `sha256` z katalogu a cachují se v `DATA_DIR/scripts/{sha256}.md`.
- Vzorky a klipy leží na disku v `DATA_DIR/voices/{voice_id}/`
  (`sample.{wav,m4a,mp3}`, `clips/{utterance_key}.m4a`), metadata v SQLite.

## Lokální běh

```sh
cd api
make run                      # ADMIN_TOKEN=dev-admin, WORKER_TOKEN=dev-worker, DB v bin/
# nebo ručně:
ADMIN_TOKEN=dev-admin WORKER_TOKEN=dev-worker DB_PATH=/tmp/hajanek.db go run ./cmd/hajanek-api

make test                     # go test -race ./...
make vet
make sqlc                     # po změně sqlc/queries/*.sql nebo migrations/*.sql
```

Struktura:

```
cmd/hajanek-api/     main, graceful shutdown, `hajanek-api healthcheck` pro Docker
internal/config/     env proměnné
internal/catalog/    validace catalog.json (schema 2) + poller s cache + stahování skriptů
internal/script/     parser skriptu → promluvy a utterance_key (CONTRACTS §2, §7)
internal/voices/     zařízení, hlasy, rendery, klipy (DB + soubory v DATA_DIR)
internal/ids/        UUID / 64hex validace (vše, co jde do cest na disku)
internal/jobs/       fronta jobů (lease, reaper, dedupe, OnFinish hook)
internal/httpapi/    HTTP handlery
internal/db/         kód generovaný sqlc (+ open.go: otevření DB a migrace)
sqlc/                sqlc.yaml + queries/
migrations/          SQL migrace (embed)
```

## Proměnné prostředí

| Proměnná | Výchozí | Popis |
|---|---|---|
| `PORT` | `8080` | HTTP port |
| `DB_PATH` | `hajanek.db` | cesta k SQLite souboru |
| `CATALOG_URL` | `https://lioilsources.github.io/hajanek-content/catalog.json` | publikovaný katalog; sem míří i redirect z `/v1/catalog` |
| `CATALOG_POLL` | `5m` | jak často stahovat katalog (Go duration) |
| `ADMIN_TOKEN` | — (povinné) | bearer token pro zakládání a čtení jobů |
| `WORKER_TOKEN` | — (povinné) | bearer token pro workera; musí se lišit od `ADMIN_TOKEN` |
| `JOB_LEASE` | `10m` | délka lease po claimu / heartbeatu |
| `JOB_MAX_ATTEMPTS` | `3` | po kolika propadlých lease je job `failed` |
| `REAPER_INTERVAL` | `30s` | jak často se vrací propadlé lease do fronty |
| `DATA_DIR` | `data` | vzorky, klipy a cache skriptů (v Dockeru `/data/files`) |
| `MAX_VOICES_PER_DEVICE` | `3` | max. hlasů na zařízení (mazané se nepočítají) |
| `DEVICE_RATE_LIMIT` | `10/1h` | registrace zařízení na IP: `N/doba` (token bucket v paměti) nebo `off` |

IP klienta se bere z `X-Real-IP` (Caddy ho nastavuje z `CF-Connecting-IP`),
jinak z TCP spojení. Délku vzorku (5–30 s) kontroluje `ffprobe`, pokud je
v `PATH` (v image je); bez něj (lokální běh) se vzorek přijme a jen se zaloguje.

Logy jdou na stdout jako JSON (`slog`).

## Endpointy

### Veřejné

```sh
curl -s localhost:8080/healthz
# {"ok":true}

curl -si localhost:8080/v1/catalog            # 302 → CATALOG_URL
curl -s 'localhost:8080/v1/catalog?inline=1'  # poslední dobrý catalog.json (ETag = sha256, umí 304)

curl -s localhost:8080/v1/catalog/version
# {"url":"https://lioilsources.github.io/hajanek-content/catalog.json","version":3}
```

`/v1/catalog?inline=1` a `/v1/catalog/version` vrací `503`, dokud služba
nestáhla žádný platný katalog.

### Zařízení a hlasy (device token)

```sh
# registrace (anonymní, rate limit na IP) → 201
curl -s -X POST localhost:8080/v1/devices
# {"device_id":"…","token":"<64 hex>"}   token se ukáže jen jednou, server drží jen sha256
D='Authorization: Bearer <token>'

# nahrát hlas: wav/m4a/mp3 ≤ 5 MB, 5–30 s, souhlas povinný → 201, status pending, job voice_create
curl -s -X POST localhost:8080/v1/voices -H "$D" \
  -F sample=@nahravka.m4a -F name='Máma' -F consent=true \
  -F consent_text='Jsem Jana a souhlasím, aby Hajánek z této nahrávky vytvořil můj hlas.'
# {"id":"3f2c…","name":"Máma","status":"pending","created_at":"…"}

curl -s localhost:8080/v1/voices -H "$D"            # {"voices":[…]}
curl -s localhost:8080/v1/voices/<id> -H "$D"       # status: pending | ready | failed | deleting

# namluvit pohádku (hlas musí být ready, tale/délka musí být v katalogu) → 202
curl -s -X POST localhost:8080/v1/voices/<id>/renders -H "$D" \
  -d '{"tale":"cervena-karkulka","length_min":10}'
# {"voice_id":"…","tale":"cervena-karkulka","length_min":10,"script_sha256":"…",
#  "status":"queued","done":0,"total":87,"job_id":"…","updated_at":"…"}

# manifest klipů pro aktuální skript
curl -s localhost:8080/v1/voices/<id>/renders/cervena-karkulka/10 -H "$D"
# {"status":"running","script_sha256":"…","done":12,"total":87,
#  "clips":{"<utterance_key>":{"url":"/v1/clips/<id>/<key>.m4a","duration_s":3.2,"bytes":26112}}}

curl -s -o klip.m4a localhost:8080/v1/clips/<id>/<key>.m4a -H "$D"   # immutable cache

curl -s -X DELETE localhost:8080/v1/voices/<id> -H "$D"   # 204: vzorek a klipy hned pryč, job voice_delete
curl -s -X DELETE localhost:8080/v1/devices/me -H "$D"    # 204: zařízení + všechny jeho hlasy
```

- Cizí nebo neexistující hlas/klip je vždy `404` (existence se neprozradí).
- `POST …/renders` je idempotentní: dokud render job čeká nebo běží, vrací
  týž job; hotový render se stejným skriptem a všemi klipy se nezařazuje znovu.
  Neready hlas → `409`, neznámá pohádka/délka → `404`.
- Manifest: `status` je stav render jobu (`queued | running | done | failed`),
  nebo `none`, když pro aktuální verzi skriptu žádný render nebyl vyžádán.
  `done`/`total` se počítají živě z klipů pro klíče skriptu; `url` je
  relativní k API.
- Mazání: `DELETE` označí hlas `deleting`, smaže soubory, rendery, klipy,
  zruší čekající `voice_create`/`render` joby a zařadí `voice_delete`. Až
  worker ten job dokončí (`ok:true`), řádek hlasu se smaže úplně.
- Selže-li `voice_create` definitivně, hlas přejde do `failed`.

### Joby (admin, `ADMIN_TOKEN`)

```sh
A='Authorization: Bearer dev-admin'

# zařadit job; kind: script | publish | voice_create | voice_delete | render (+ starší voice | master | tale)
curl -s -X POST localhost:8080/v1/jobs -H "$A" \
  -d '{"kind":"script","tale":"zlatovlaska","length_min":10,"priority":5}'
# 201 + job; když už stejný job (kind+tale+voice+length) čeká nebo běží:
# 200 + ten existující job a hlavička X-Deduplicated: true

curl -s localhost:8080/v1/jobs/<id> -H "$A"
curl -s 'localhost:8080/v1/jobs?status=queued' -H "$A"   # queued | running | done | failed; max 100 nejnovějších
```

Pravidla pro spec jobu:

| kind | tale | voice | length_min |
|---|---|---|---|
| `script` | povinné | nesmí být | výchozí 10 |
| `voice`, `master` | povinné | povinné | výchozí 10 |
| `tale` (celá pipeline) | povinné | volitelné (prázdné = všechny hlasy) | výchozí 10 |
| `publish` | volitelné | jen s tale | jen s tale |
| `voice_create`, `voice_delete` | nesmí být | povinné jako `voice_id` (UUID) | nesmí být |
| `render` | povinné | povinné jako `voice_id` (UUID) | výchozí 10 |

U hlasových jobů vrací API (i claim) pole `voice_id`; při zakládání přijme
`voice_id` i `voice`.

Joby hlasů zakládá API samo (`POST /v1/voices`, `DELETE …`, `POST …/renders`).
`tale` a `voice` jsou kebab-case ASCII (u hlasových jobů UUID), `length_min` ∈ {5, 10, 15, 20},
`priority` −1000..1000 (vyšší = dřív). GET jobů přijme i `WORKER_TOKEN`.

### Worker na Sparku (`WORKER_TOKEN`)

```sh
W='Authorization: Bearer dev-worker'

# vzít další job (atomicky; nejvyšší priorita, pak nejstarší)
curl -s -X POST localhost:8080/v1/jobs/claim -H "$W" \
  -d '{"worker":"spark-1","kinds":["voice_create","voice_delete","render"]}'
# 200 + job se stavem running a lease_expires_at, nebo 204 když není co dělat
# `kinds` je volitelné (prázdné = všechny), `worker` výchozí "default"

# prodloužit lease (posílat třeba každé 2–3 min u dlouhých jobů)
curl -s -X POST localhost:8080/v1/jobs/<id>/heartbeat -H "$W" -d '{"worker":"spark-1"}'

# hotovo
curl -s -X POST localhost:8080/v1/jobs/<id>/complete -H "$W" \
  -d '{"worker":"spark-1","ok":true,"result":{"done":87,"total":87}}'

# chyba (retry:true = přechodná chyba, vrátí job do fronty, pokud zbývají pokusy)
curl -s -X POST localhost:8080/v1/jobs/<id>/complete -H "$W" \
  -d '{"worker":"spark-1","ok":false,"error":"audio služba 503","retry":true}'
```

Render job: worker může v `result` poslat `{"done":87,"total":87}`, uloží
se k renderu.

Endpointy pro hlasy (`WORKER_TOKEN`):

```sh
curl -s -o sample localhost:8080/v1/worker/voices/<id>/sample -H "$W"   # vzorek (404 u mazaného hlasu)
curl -s -X POST localhost:8080/v1/worker/voices/<id>/status -H "$W" -d '{"status":"ready"}'
curl -s -X POST localhost:8080/v1/worker/voices/<id>/status -H "$W" -d '{"status":"failed","error":"…"}'

curl -s localhost:8080/v1/worker/scripts/cervena-karkulka/10 -H "$W"     # text/markdown, X-Script-SHA256
curl -s localhost:8080/v1/worker/clips/<id> -H "$W"                      # {"keys":[…]} klipy, které už existují

# nahrát klip: m4a ≤ 2 MB, key = 64 hex (CONTRACTS §7), zápis přes temp + rename → 204
curl -s -X PUT localhost:8080/v1/worker/clips/<id>/<key> -H "$W" \
  -H 'X-Duration-S: 3.24' --data-binary @klip.m4a
```

`409` = hlas se maže (worker má práci zahodit), `400` = neplatné UUID/klíč
nebo `X-Duration-S`, `415` = tělo není MP4/M4A, `413` = moc velké.

Heartbeat/complete na job, který workerovi nepatří (propadlá lease, jiný
worker, už dokončený), vrací `409`; neexistující job `404`.

Životní cyklus: `queued` → (claim, `attempts++`) → `running` → `done` | `failed`.
Když lease vyprší (reaper nebo nejbližší claim), job se vrátí do `queued`;
po `JOB_MAX_ATTEMPTS` pokusech skončí jako `failed` s chybou `lease expired`.

## Docker a nasazení

```sh
docker buildx build --platform linux/arm64,linux/amd64 -t hajanek-api .   # z adresáře api/
```

Image je Alpine s `ffmpeg` (uživatel 65532), DB i `DATA_DIR` (`/data/files`)
ve volume `/data` — obsahuje hlasy rodičů, zálohovat a mazat s rozmyslem.
Caddy pouští těla do 6 MB (vzorky). Kompletní
nasazení (hajanek-api + Caddy + Cloudflare Tunnel na `hajanek-api.ol1n.com`)
je v [`deploy/`](../deploy); z Macu `deploy/deploy.sh api` (synchronizuje na
JODA, poprvé vygeneruje tokeny do `.env`, založí tunel `hajanek` + DNS
a spustí `docker compose up -d --build`).
