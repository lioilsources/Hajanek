# hajanek-api

Go služba „JODA“ pro Hajánka: katalogové endpointy pro appku a fronta
generačních jobů, kterou si v noci vybírá worker na DGX Sparku
(claim → heartbeat → complete). Kontrakt: [`docs/CONTRACTS.md`](../docs/CONTRACTS.md) §3 a §6.

- SQLite (čistě Go driver `modernc.org/sqlite`, bez cgo → jde přeložit na linux/arm64),
  migrace přes `golang-migrate` zabudované v binárce, dotazy přes `sqlc`.
- Katalog se **nehostuje** tady: služba pravidelně stahuje `catalog.json`
  z GitHub Pages (ETag / If-Modified-Since), validuje ho a poslední dobrou verzi
  drží v SQLite. Nevalidní katalog nikdy nepřepíše dobrý; stejně tak katalog
  s nižší (nebo stejnou) `version` a jiným obsahem.

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
internal/catalog/    validace catalog.json + poller s cache
internal/jobs/       fronta jobů (lease, reaper, dedupe)
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

### Joby (admin, `ADMIN_TOKEN`)

```sh
A='Authorization: Bearer dev-admin'

# zařadit job; kind: script | voice | master | publish | tale
curl -s -X POST localhost:8080/v1/jobs -H "$A" \
  -d '{"kind":"voice","tale":"zlatovlaska","voice":"mama","length_min":10,"priority":5}'
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

`tale` a `voice` jsou kebab-case ASCII, `length_min` ∈ {5, 10, 15, 20},
`priority` −1000..1000 (vyšší = dřív). GET jobů přijme i `WORKER_TOKEN`.

### Worker na Sparku (`WORKER_TOKEN`)

```sh
W='Authorization: Bearer dev-worker'

# vzít další job (atomicky; nejvyšší priorita, pak nejstarší)
curl -s -X POST localhost:8080/v1/jobs/claim -H "$W" \
  -d '{"worker":"spark-1","kinds":["script","voice"]}'
# 200 + job se stavem running a lease_expires_at, nebo 204 když není co dělat
# `kinds` je volitelné (prázdné = všechny), `worker` výchozí "default"

# prodloužit lease (posílat třeba každé 2–3 min u dlouhých jobů)
curl -s -X POST localhost:8080/v1/jobs/<id>/heartbeat -H "$W" -d '{"worker":"spark-1"}'

# hotovo
curl -s -X POST localhost:8080/v1/jobs/<id>/complete -H "$W" \
  -d '{"worker":"spark-1","ok":true,"result":{"path":"audio/zlatovlaska/mama/10.opus","wer":0.021}}'

# chyba (retry:true = přechodná chyba, vrátí job do fronty, pokud zbývají pokusy)
curl -s -X POST localhost:8080/v1/jobs/<id>/complete -H "$W" \
  -d '{"worker":"spark-1","ok":false,"error":"vLLM nedostupné","retry":true}'
```

Heartbeat/complete na job, který workerovi nepatří (propadlá lease, jiný
worker, už dokončený), vrací `409`; neexistující job `404`.

Životní cyklus: `queued` → (claim, `attempts++`) → `running` → `done` | `failed`.
Když lease vyprší (reaper nebo nejbližší claim), job se vrátí do `queued`;
po `JOB_MAX_ATTEMPTS` pokusech skončí jako `failed` s chybou `lease expired`.

## Docker a nasazení

```sh
docker buildx build --platform linux/arm64,linux/amd64 -t hajanek-api .   # z adresáře api/
```

Image je `distroless/static` (nonroot), DB ve volume `/data`. Kompletní
nasazení (hajanek-api + Caddy + Cloudflare Tunnel na `hajanek-api.ol1n.com`)
je v [`deploy/`](../deploy): `cp .env.example .env`,
`cp cloudflared/config.yml.example cloudflared/config.yml`, doplnit tunel
a `docker compose up -d --build`.
