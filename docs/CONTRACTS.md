# Hajánek — sdílené kontrakty

Jediné místo, kde jsou definované formáty, na kterých se shodují `content/`,
`forge/`, `api/` a `app/`. Změna tady = změna ve všech čtyřech.

## 1. Identifikátory

| Věc | Formát | Příklady |
|---|---|---|
| pohádka | kebab-case ASCII | `cervena-karkulka`, `zlatovlaska` |
| hlas | `system` nebo UUID klonu | `system`, `3f2c…` (UI: „Hlas telefonu“, jméno zadané rodičem) |
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

Pravidla parseru (`forge/internal/script` v Go, `app/lib/core/script/` v Dartu — oba testované proti `docs/testdata/utterances.golden.json`):

- Sekce jsou **přesně** `uvod`, `vstup`, `pribeh`, `dojezd`, v tomto pořadí.
- Jeden neprázdný řádek = jedna **promluva** (TTS se volá po promluvách).
- `[pause Ns]` na samostatném řádku = ticho N sekund (desetinné povoleno,
  `[pause 1.5s]`). Pauzy vkládá přehrávač v appce, nikdy TTS.
- Tónové značky na začátku řádku: `[soft]` (výchozí), `[slow]`, `[whisper]`.
  Platí **od toho řádku až do další tónové značky nebo konce sekce**.
- `{{osloveni|fallback}}` = oslovení dítěte (rituál, fáze 1), jinak text za `|`.
  Rodič ho v appce zadává **v 5. pádě** („Alexku“, „Aničko“), protože se
  používá výhradně jako oslovení: `Dobrou noc, {{osloveni|broučku}}.` —
  tím odpadá shoda slovesa s podmětem (ty spinkáš × Alexek spinká).
  Smí se objevit jen v sekcích `uvod` a `dojezd`.
  MVP oslovení nepoužívá → vždy fallback.
- Komentáře `<!-- ... -->` se ignorují.
- Front matter `status`: `draft` (vygenerováno, čeká na člověka),
  `reviewed` (schváleno k namluvení), `gold` (ručně psaný vzor, few-shot).
  `forge publish` publikuje jen `reviewed` a `gold`.
- Hledání skriptu: `content/scripts/{id}.{len}.md`, jinak
  `content/scripts/gold/{id}.{len}.md`.

Mapování tónu (výchozí hodnoty, ladí se v `app/lib/core/script/tone.dart`).
Rychlost je **relativní k normální rychlosti hlasu** — app ji převádí na
hodnoty platformy (iOS `AVSpeechUtterance` 0.5 = normál, Android 1.0 = normál).
Hlasitost je násobek hlasitosti hlasové stopy.

| tón | rychlost | hlasitost | systémové TTS navíc |
|---|---|---|---|
| soft | 0.85× | 1.0 | |
| slow | 0.78× | 0.75 | |
| whisper | 0.75× | 0.4 | pitch 0.95 |

V `dojezd` rychlost lineárně klesá k 0.75× a hlasitost k 0.5 (podle pořadí
promluvy v sekci). U klonovaného hlasu se rychlost posílá enginu jako `speed`
(Chatterbox ji ignoruje), hlasitost řeší přehrávač.

## 3. Katalog (`catalog.json`, publikováno na GitHub Pages)

Katalog nese **texty skriptů**, ne audio meditací. Audio vzniká až v
telefonu (systémové TTS) nebo na Sparku z hlasu rodiče (§8).

```json
{
  "schema": 2,
  "version": 3,
  "generated_at": "2026-10-20T03:12:00Z",
  "base_url": "https://lioilsources.github.io/hajanek-content/",
  "tales": [
    {
      "id": "cervena-karkulka",
      "title": "Červená Karkulka",
      "age": "3+",
      "setting": "les",
      "ambient": "wind",
      "free": true,
      "scripts": [
        {"length_min": 10,
         "path": "scripts/cervena-karkulka.10.md",
         "sha256": "…", "bytes": 5210,
         "est_duration_s": 583}
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
- Publikují se jen skripty se `status: reviewed | gold`.
- `est_duration_s` = odhad forge (95 slov/min při normální rychlosti + pauzy);
  skutečná délka závisí na hlasu.
- App má v bundlu **kopii** katalogu, všech skriptů a ambient smyček
  (`app/assets/`), takže funguje bez sítě od prvního spuštění.
- Validace (API i forge): `schema` = 2, `sha256` = 64 hex znaků, každá
  pohádka má ≥ 1 skript, odkazy na ambient existují, `version` je vyšší než
  u posledního přijatého (stejná verze s jiným obsahem = odmítnuto).

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
(crossfade loop), loudness −30 LUFS integrated.

## 5. Hlasy v appce

| id | zdroj | kde vzniká audio |
|---|---|---|
| `system` | TTS telefonu (`flutter_tts`; iOS cs-CZ, Android Google cs) | v telefonu, za běhu, po promluvách |
| `{voice_id}` (UUID) | klon hlasu rodiče (§8) | na Sparku, předem; app stahuje klipy |

Přehrávač je jeden: jde po promluvách skriptu, mezi nimi drží pauzy, a
promluvu buď předá systémovému TTS, nebo přehraje klip. Chybí-li u
klonovaného hlasu klip, promluva se přečte systémovým hlasem (a app to
v nastavení ukáže jako „hlas se ještě připravuje“).

## 6. API (`hajanek-api.ol1n.com`)

| Metoda | Cesta | Auth | Popis |
|---|---|---|---|
| GET | `/healthz` | – | `{"ok":true}` |
| GET | `/v1/catalog` | – | 302 na aktuální `catalog.json` na Pages (nebo JSON, pokud `?inline=1`) |
| GET | `/v1/catalog/version` | – | `{"version":3,"url":"…"}` |
| POST | `/v1/devices` | – (rate limit / IP) | anonymní registrace → `{device_id, token}` |
| DELETE | `/v1/devices/me` | device | smaže zařízení i všechny jeho hlasy a klipy |
| POST | `/v1/voices` | device | multipart `sample` (wav/m4a, 5–30 s), `name`, `consent=true`, `consent_text` → `201 {voice}` (`status: pending`) |
| GET | `/v1/voices` | device | hlasy zařízení |
| GET | `/v1/voices/{id}` | device (vlastník) | `{id, name, status: pending|ready|failed|deleting, error?, created_at}` |
| DELETE | `/v1/voices/{id}` | device (vlastník) | okamžitě smaže vzorek a klipy u nás, zařadí `voice_delete` na Sparku |
| POST | `/v1/voices/{id}/renders` | device (vlastník) | `{tale, length_min}` → zařadí `render` (idempotentní) → `{render}` |
| GET | `/v1/voices/{id}/renders/{tale}/{length}` | device (vlastník) | `{status, script_sha256, done, total, clips: {utterance_key: {url, duration_s, bytes}}}` |
| GET | `/v1/clips/{voice_id}/{utterance_key}.m4a` | device (vlastník) | klip |
| POST | `/v1/jobs` | admin | zařadí job `{kind, …}` |
| GET | `/v1/jobs/{id}`, `/v1/jobs?status=` | admin/worker | stav a výpis |
| POST | `/v1/jobs/claim` | worker | `{worker, kinds?}` → job s leasem; 204 = fronta prázdná |
| POST | `/v1/jobs/{id}/heartbeat` | worker | prodlouží lease |
| POST | `/v1/jobs/{id}/complete` | worker | `{ok, result, error, retry?}` |
| GET | `/v1/worker/voices/{id}/sample` | worker | vzorek pro upload do audio služby |
| GET | `/v1/worker/scripts/{tale}/{length}` | worker | text skriptu, který se má namluvit (z cache katalogu) |
| GET | `/v1/worker/clips/{voice_id}` | worker | `{"keys":[…]}` — klíče klipů, které už existují (worker je přeskočí) |
| PUT | `/v1/worker/clips/{voice_id}/{utterance_key}` | worker | nahraje klip (m4a ≤ 2 MB), `X-Duration-S` → 204 |
| POST | `/v1/worker/voices/{id}/status` | worker | `{status, error?}` |

`device` = `Authorization: Bearer <device token>`. Token je náhodných 32 B,
server drží jen jeho sha256. Žádné e-maily ani účty.

Upřesnění k hlasům:

- Cizí i neexistující hlas/klip = `404` (existence se neprozradí).
- Joby hlasů: `voice_create`, `voice_delete` (`voice_id` = UUID), `render`
  (`voice_id`, `tale`, `length_min`); job JSON nese `voice_id`, ne `voice`. `POST …/renders` je idempotentní (týž job,
  dokud čeká/běží) → `202 {voice_id, tale, length_min, script_sha256, status,
  done, total, job_id}`; hlas, který není `ready` → `409`.
- Manifest: `status` ∈ `none | queued | running | done | failed` (`none` =
  pro aktuální `script_sha256` nebyl render vyžádán); `done`/`total` se
  počítají z klipů pro klíče aktuálního skriptu; `url` je relativní k API.
- Worker smí v `complete` render jobu poslat `result: {done, total}`.
  `voice_delete` dokončený s `ok:true` smaže hlas definitivně; čekající
  `voice_create`/`render` joby mazaného hlasu se ruší. `409` na worker
  endpointech = hlas se maže.

## 7. Klíč promluvy (`utterance_key`)

```
utterance_key = hex(sha256(utf8(voice_id + "\x1f" + tone + "\x1f" + text)))
```

- `text` = promluva po náhradě `{{osloveni|fallback}}` za fallback, bez
  tónové značky, ořezaná o bílé znaky, vnitřní běhy bílých znaků nahrazené
  jednou mezerou, Unicode NFC. Tón se na začátku každé sekce vrací na `soft`.
- `tone` ∈ `soft | slow | whisper` (platný tón promluvy podle §2).
- Stejná věta v různých pohádkách (úvody, refrény) = stejný klip, generuje
  se jednou.
- Go (`forge`, `api`) i Dart (`app`) se testují proti
  `docs/testdata/utterances.golden.json`.

## 8. Hlas rodiče — tok

1. App: rodič přečte nahrávací text (`content/voice/recording_script.md`),
   jehož první věta je souhlasná („Jsem … a souhlasím, aby Hajánek z této
   nahrávky vytvořil můj hlas.“). Nahrávka 5–30 s, mono, bez potlačení šumu
   a AGC (mění barvu hlasu).
2. App → `POST /v1/voices`. API uloží vzorek, zařadí job `voice_create`.
3. Worker na Sparku (`forge worker`) vezme job, stáhne vzorek, nahraje ho do
   AiStack audio služby (`POST spark:8093/v1/audio/voices`, `voice_id =
   hajanek-{uuid}`, `rights=own`, `source=hajanek-app`) a nastaví `ready`.
   Ověření souhlasné věty přes ASR je TODO (fáze 2).
4. App → `POST /v1/voices/{id}/renders` pro vybrané pohádky (výchozí: všechny
   free). Worker pro každou promluvu bez klipu zavolá
   `POST spark:8093/v1/audio/tts` (`language=cs`, `voice=hajanek-{uuid}`,
   `commercial_only=false` — viz ADR-003), výsledek převede na AAC 64 kbps
   mono 48 kHz, −23 LUFS, a nahraje `PUT /v1/worker/clips/…`.
5. App stahuje klipy podle manifestu do `applicationSupport/voices/{id}/`
   a přehrává je přehrávačem z §5.
6. Smazání: `DELETE /v1/voices/{id}` → u nás hned pryč, job `voice_delete`
   smaže hlas i v audio službě.

GPU klonovací enginy na Sparku neběží pořád (rozvrh paměti v AiStack). Worker
proto bere `render` joby jen v okně, kdy je engine nahoře; když audio služba
vrátí 503, job vrátí do fronty (`retry: true`).
