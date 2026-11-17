# Hajánek

<!-- Max 80 řádků. Co se nevejde, jde do docs/ a sem jeden odkaz. Veřejné repo: žádné LAN IP, domovské cesty, ID. -->

## Účel
Usínací meditace pro děti na motivy klasických pohádek: Flutter app (iOS, Android, TV), Go API a Go `forge` (skript → judge → publish katalogu, worker na klonování hlasu rodiče). Offline, bez reklam.

## Build a test
```
make test     # api + forge (go vet + test) + app (flutter analyze + test) + judge skriptů — gate před pushem
make judge    # deterministická kontrola skriptů v content/
make smoke    # forge: judge → publish do dočasného adresáře
make e2e      # hlas rodiče end-to-end (api + worker + fake audio)
make api-run  # lokální API
make app-run  # flutter run
```
CI navíc: `go test -race`, `sqlc diff` v `api/`. App potřebuje sousední repo `CuteKidFonts` (path dependency v `app/pubspec.yaml`).

## Mapa
- `app/` Flutter appka (katalog, přehrávač, mixér, časovač, TV); `app/store/` texty do obchodů
- `api/` Go `hajanek-api`, migrace v `api/migrations/`, dotazy přes sqlc
- `forge/` Go CLI a worker; `forge/deploy/forge.env.example` vzor configu
- `content/` předlohy, skripty meditací, prompty, presety, ambient smyčky
- `deploy/` docker-compose (api + Caddy + cloudflared)
- `docs/` plány, `CONTRACTS.md` (sdílené formáty), `adr/`, privacy/support stránky
- `tools/` e2e, TV banner, sync bundlu

## Invarianty
- Publikují se jen skripty `reviewed` nebo `gold` (drafty jen na vyžádání); release build s `--dart-define=INCLUDE_DRAFTS=false`.
- Formáty mezi app, api a forge drží `docs/CONTRACTS.md`.

## Kam dál
`README.md`, `app/README.md`, `docs/HAJANEK_PLAN.md`, `docs/HAJANEK_TV_PLAN.md`, `docs/adr/`, `Prompts/`
