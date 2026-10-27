# Hajánek

Usínací meditace pro děti postavené na klasických pohádkách — čte je hlas
telefonu, nebo **hlas rodiče** (nahraný v appce, naklonovaný na vlastním
serveru), s podkresem přírodních zvuků, offline, bez reklam. Plán:
[`docs/HAJANEK_PLAN.md`](docs/HAJANEK_PLAN.md), TV (Apple TV / Google TV):
[`docs/HAJANEK_TV_PLAN.md`](docs/HAJANEK_TV_PLAN.md). Sdílené formáty:
[`docs/CONTRACTS.md`](docs/CONTRACTS.md).

| Adresář | Co | Stav |
|---|---|---|
| `app/` | Flutter (iOS + Android): katalog, přehrávač s podkresem, mixér, časovač, noční UI | viz `app/README.md` |
| `api/` | Go `hajanek-api`: katalog, anonymní zařízení, hlasy rodičů, klipy, fronta jobů | |
| `forge/` | Go CLI: skript (LLM) → judge → publish katalogu; `worker` na Sparku klonuje hlasy přes AiStack audio | |
| `content/` | předlohy pohádek, skripty meditací, prompty, presety, ambient smyčky | 10 skriptů (2 gold, 8 draft), 8 smyček |
| `deploy/` | docker-compose (api + Caddy + cloudflared) pro JODA | neověřeno (Docker neběžel) |
| `docs/adr/` | ADR-000 výchozí odpovědi, ADR-001 rešerše TTS (nahrazeno), ADR-002 zdroje zvuků, ADR-003 architektura hlasu | |

## Rychlý start

```bash
make test        # api + forge + app testy + judge všech skriptů
make judge       # jen deterministická kontrola skriptů
make smoke       # forge: judge → publish katalogu do dočasného adresáře
make api-run     # lokální API (tokeny dev-admin / dev-worker)
make app-run     # flutter run
```

## Co chybí do MVP (vyžaduje Spark / člověka)

1. Kontrola 8 draft skriptů Ol1nem (`status: draft` → `reviewed`) — publikují se jen schválené.
2. App na reálném iPhonu/Androidu: český systémový hlas, čtení se zamčeným
   displejem, 20 min na pozadí, kvalita nahrávky mikrofonem.
3. Nasadit `hajanek-api` na JODA a `forge worker` na Spark; jeden hlas
   rodiče end-to-end → poslech s Alexkem.
4. Ruční poslech 8 ambient smyček (hlavně `rain`, `wind`).
5. Založit repo `hajanek-content` (GitHub Pages), TestFlight + Play internal.
6. Před placeným „Můj hlas“: český klonující engine s komerční licencí (ADR-003).
