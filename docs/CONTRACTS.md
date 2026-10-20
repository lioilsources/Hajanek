# Hajánek — sdílené kontrakty

Jediné místo, kde jsou definované formáty, na kterých se shodují `content/`,
`forge/`, `api/` a `app/`. Změna tady = změna ve všech čtyřech.

## 1. Identifikátory

| Věc | Formát | Příklady |
|---|---|---|
| pohádka | kebab-case ASCII | `cervena-karkulka`, `zlatovlaska` |
| hlas | ASCII, interní | `mama`, `tata`, `babicka` (UI label: „Měkký“, „Hluboký“, „Vlídný“) |
| délka | minuty, int | `5`, `10`, `15`, `20` (MVP jen `10`) |
| ambient | kebab-case ASCII | viz §4 |
| preset | kebab-case ASCII | `prales-v-noci`, `plaz-vecer` |

## 2. Skript meditace (`content/scripts/{tale}.{length}.md`)

UTF-8 markdown s YAML front matter:

```markdown
---
id: cervena-karkulka
title: Červená Karkulka
source: lidová, zapsal Charles Perrault / bratři Grimmové (volné dílo)
age: 3+
setting: les              # les | more | hrad | louka | vesnice | hory | zahrada
ambient: wind             # doporučený podkres (id z §4)
length_min: 10
tension_original: 4       # 0–5, kolik napětí měl originál (kolik se změkčovalo)
characters: [Karkulka, babička, vlk, myslivec]
---

## uvod
[soft] Lehni si pěkně do postýlky.
[pause 3s]
...

## vstup
...

## pribeh
...

## dojezd
[slow] ...
[whisper] ...a Hajánek už jde kolem.
[pause 10s]
```

Pravidla parseru (`forge/internal/script`, zrcadleně v pythonu):

- Sekce jsou **přesně** `uvod`, `vstup`, `pribeh`, `dojezd`, v tomto pořadí.
- Jeden neprázdný řádek = jedna **promluva** (TTS se volá po promluvách).
- `[pause Ns]` na samostatném řádku = ticho N sekund (desetinné povoleno,
  `[pause 1.5s]`). Pauzy vkládá mixér, nikdy TTS.
- Tónové značky na začátku řádku: `[soft]` (výchozí), `[slow]`, `[whisper]`.
  Platí **od toho řádku až do další tónové značky nebo konce sekce**.
- `{{osloveni|fallback}}` = oslovení dítěte (rituál, fáze 1), jinak text za `|`.
  Rodič ho v appce zadává **v 5. pádě** („Alexku“, „Aničko“), protože se
  používá výhradně jako oslovení: `Dobrou noc, {{osloveni|broučku}}.` —
  tím odpadá shoda slovesa s podmětem (ty spinkáš × Alexek spinká).
  Smí se objevit jen v sekcích `uvod` a `dojezd` (zbytek audia je sdílený).
  MVP oslovení nepoužívá → vždy fallback.
- Komentáře `<!-- ... -->` se ignorují.
- Front matter `status`: `draft` (vygenerováno, čeká na člověka),
  `reviewed` (schváleno k namluvení), `gold` (ručně psaný vzor, few-shot).
  `forge voice` bez `--allow-draft` odmítne `draft`.
- Hledání skriptu: `content/scripts/{id}.{len}.md`, jinak
  `content/scripts/gold/{id}.{len}.md`.

Mapování tónu na TTS parametry (výchozí, ladí se v `forge/config.yaml`):

| tón | rychlost | gain | poznámka |
|---|---|---|---|
| soft | 0.85× | 0 dB | |
| slow | 0.78× | −3 dB | |
| whisper | 0.75× | −10 dB | whisper mód enginu, jinak low-pass 3.5 kHz |

Navíc v `dojezd` rychlost lineárně klesá na 0.75× a gain na −6 dB.

## 3. Katalog (`catalog.json`, publikováno na GitHub Pages)

```json
{
  "schema": 1,
  "version": 3,
  "generated_at": "2026-10-20T03:12:00Z",
  "base_url": "https://lioilsources.github.io/hajanek-content/",
  "voices": [
    {"id": "mama", "label": "Měkký", "free": true}
  ],
  "tales": [
    {
      "id": "cervena-karkulka",
      "title": "Červená Karkulka",
      "age": "3+",
      "setting": "les",
      "ambient": "wind",
      "free": true,
      "tracks": [
        {"voice": "mama", "length_min": 10,
         "path": "audio/cervena-karkulka/mama/10.opus",
         "duration_s": 604.2, "bytes": 3625000,
         "sha256": "…"}
      ]
    }
  ],
  "ambient": [
    {"id": "sea", "title": "Moře", "path": "ambient/sea.opus",
     "duration_s": 90.0, "bytes": 1080000, "sha256": "…",
     "free": true, "license": "CC0", "source": "…"}
  ],
  "presets": [
    {"id": "plaz-vecer", "title": "Pláž večer",
     "layers": [{"ambient": "sea", "volume": 0.8},
                {"ambient": "night-meadow", "volume": 0.3}]}
  ]
}
```

- `path` je relativní k `base_url`. Soubory jsou immutable — změna obsahu =
  nová `sha256` a nová `version` katalogu; app stahuje jen změny podle `sha256`.
- `version` je monotónní integer; app porovnává s lokální.
- `presets[].layers`: 1–3 vrstvy, `volume` 0.0–1.0.
- App má v bundlu **kopii** katalogu + ambient smyčky (`app/assets/`), takže
  funguje i bez prvního stažení. Audio meditací se stahuje (nebo je v bundlu
  pro free tier, rozhoduje build flag `BUNDLE_TALES`).

## 4. Ambient smyčky (MVP: 8)

| id | název v UI | zdroj |
|---|---|---|
| `sea` | Moře | CC0 nahrávka |
| `rain` | Déšť na střechu | CC0 nahrávka |
| `stream` | Potůček | CC0 nahrávka |
| `fireplace` | Krb | CC0 nahrávka |
| `wind` | Vítr v korunách | CC0 nahrávka |
| `night-meadow` | Noční louka | CC0 nahrávka (cvrčci) |
| `pink-noise` | Růžový šum | syntéza ffmpeg |
| `brown-noise` | Hnědý šum | syntéza ffmpeg |

Formát: Opus 96 kbps stereo, 48 kHz, 60–120 s, bezešvá smyčka
(crossfade loop), loudness −30 LUFS integrated (podkres musí být tišší než
hlas na −23 LUFS).

## 5. Audio meditace

`audio/{tale}/{voice}/{length}.opus` — Opus 48 kbps mono 48 kHz,
−23 LUFS integrated, true-peak −3 dBTP. Soubor **nemá** fade-out ani podkres;
obojí řeší app.

## 6. API (`hajanek-api.ol1n.com`)

| Metoda | Cesta | Popis |
|---|---|---|
| GET | `/healthz` | `{"ok":true}` |
| GET | `/v1/catalog` | 302 na aktuální `catalog.json` na Pages (nebo JSON, pokud `?inline=1`) |
| GET | `/v1/catalog/version` | `{"version":3,"url":"…"}` — levný check pro app |
| POST | `/v1/jobs` | (interní, token) zařadí generační job `{kind, tale, voice, length_min}` |
| GET | `/v1/jobs/{id}` | (admin/worker token) stav jobu |
| GET | `/v1/jobs?status=` | (admin/worker token) výpis jobů |
| POST | `/v1/jobs/claim` | (interní, worker na Sparku) vezme další job s leasem; 204 = fronta prázdná |
| POST | `/v1/jobs/{id}/heartbeat` | (interní) prodlouží lease |
| POST | `/v1/jobs/{id}/complete` | (interní) `{ok, result, error, retry?}` — `retry: true` vrátí job do fronty |

Katalog, který API přijme, musí navíc splnit: `sha256` = 64 hex znaků, každá
pohádka má ≥ 1 stopu, odkazy na hlasy/ambient existují, `version` je vyšší
než u posledního přijatého (stejná verze s jiným obsahem = odmítnuto).

Fáze 2 (`/v1/voice/*`) zatím neexistuje.
