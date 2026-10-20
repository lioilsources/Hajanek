# Hajánek

Usínací meditace pro děti postavené na klasických pohádkách — pomalý,
příjemný hlas, podkres přírodních zvuků, offline, bez reklam. Plán:
[`docs/HAJANEK_PLAN.md`](docs/HAJANEK_PLAN.md). Sdílené formáty:
[`docs/CONTRACTS.md`](docs/CONTRACTS.md).

| Adresář | Co | Stav |
|---|---|---|
| `app/` | Flutter (iOS + Android): katalog, přehrávač s podkresem, mixér, časovač, noční UI | viz `app/README.md` |
| `api/` | Go `hajanek-api`: katalog (poll z Pages, validace), fronta generačních jobů | testy prochází |
| `forge/` | Go CLI + Python workery: skript → judge → hlas → mastering → QA → publish | e2e běží s `dummy` TTS |
| `content/` | předlohy pohádek, skripty meditací, prompty, presety, ambient smyčky | 10 skriptů (2 gold, 8 draft), 8 smyček |
| `deploy/` | docker-compose (api + Caddy + cloudflared) pro JODA | neověřeno (Docker neběžel) |
| `docs/adr/` | ADR-000 výchozí odpovědi na otevřené otázky, ADR-001 TTS, ADR-002 zdroje zvuků | |

## Rychlý start

```bash
make test        # api + forge + app testy + judge všech skriptů
make judge       # jen deterministická kontrola skriptů
make smoke       # forge end-to-end s dummy TTS
make api-run     # lokální API (tokeny dev-admin / dev-worker)
make app-run     # flutter run
```

## Co chybí do MVP (vyžaduje Spark / člověka)

1. Slepý test TTS (ADR-001, `forge/python/bench/`) a výběr enginu + 2 výchozí hlasy.
2. Kontrola 8 draft skriptů Ol1nem (`status: draft` → `reviewed`).
3. `forge run` jedné pohádky na vítězném enginu → poslech s Alexkem **před** škálováním.
4. Ruční poslech 8 ambient smyček (hlavně `rain`, `wind`).
5. App na reálném zařízení: zamčený displej, 20 min na pozadí (iOS), přehrávání Opus na iOS.
6. Založit repo `hajanek-content` (GitHub Pages), TestFlight + Play internal.
