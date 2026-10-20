# forge — obsahová pipeline a hlasový worker Hajánka

`hajanek-forge` = Go CLI. Dělá dvě věci (ADR-003):

1. **Obsah:** pohádka → skript (LLM) → judge → publikace textů skriptů, ambient
   smyček a presetů do `hajanek-content` (GitHub Pages, katalog schema 2).
   Audio meditací se negeneruje — výchozí hlas je systémové TTS telefonu.
2. **Hlas rodiče:** `forge worker` na Sparku bere joby z `hajanek-api` a volá
   AiStack audio službu (`spark:8093`): klon hlasu, namluvení promluv, AAC klipy
   zpět do API.

Formáty: [`docs/CONTRACTS.md`](../docs/CONTRACTS.md), rozhodnutí:
[`docs/adr/ADR-003-voice-architecture.md`](../docs/adr/ADR-003-voice-architecture.md).

```sh
cd forge
go build -o bin/forge ./cmd/forge
go vet ./... && go test ./...
./testdata/smoke.sh            # judge → ambient → publish do dočasného adresáře, kontrola katalogu
```

Potřeba: Go 1.26, ffmpeg (s libopus, AAC, `loudnorm`, `ebur128`) — pro
`master-ambient`, publikaci ambientu a kódování klipů ve workeru. Testy bez
ffmpeg přeskočí jen test kódování klipu.

## Příkazy

Společné přepínače: `--repo`, `--content DIR` (jiný adresář obsahu, např.
`testdata/content`), `--config FILE`, `--force` (jen `script`: přepiš existující skript).

| Příkaz | Co dělá |
|---|---|
| `forge script --tale ID --length 10` | předloha `content/tales/{id}.md` + `prompts/script_template.md` (sekce SYSTEM/USER, proměnné `{{tale_text}}` …) + 2 zlaté skripty jako few-shot → LLM → `content/scripts/{id}.{len}.md` se `status: draft`. Když deterministický judge neprojde, LLM dostane chyby a opraví (`llm.attempts`). Pak `forge judge`. |
| `forge judge [--no-llm] [--length N] FILE` | deterministické kontroly + volitelně LLM-judge (`prompts/judge_checklist.md`, skóre ≥ 4, žádné `blockers`). JSON report na stdout i do `work/_judge/`, exit 1 při neúspěchu. |
| `forge master-ambient [--crossfade S] IN OUT` | bezešvá smyčka (posledních N s se prolne do začátku, výstup je o N s kratší), −30 LUFS, Opus 96 kbps stereo. |
| `forge publish --content-pages DIR [--commit]` | skripty se `status: reviewed\|gold` → `scripts/{id}.{len}.md`, ambient → `ambient/{id}.opus`, presety; přestaví `catalog.json` (schema 2), `version` zvedne jen při změně obsahu, validuje. `--commit` = `git commit` v pages repu (nic jiného). |
| `forge nightly [--queue FILE] [--until 07:00] [--content-pages DIR] [--commit]` | joby `script` a `publish` z `hajanek-api` (když jsou `FORGE_API_URL` + `WORKER_TOKEN`), jinak z `queue.txt`; na konci jeden publish a souhrn na Discord (`DISCORD_WEBHOOK`). |
| `forge worker [--once]` | hlasový worker (níže). Bez `--once` běží pořád; s `--once` skončí, když je fronta prázdná nebo když job vrátil do fronty (engine dole). |

Fronta bez API (`queue.txt`): řádky `tale délka [kind]` (výchozí `script`) nebo
`publish`; `#` = komentář.

## Skript

Parser (`internal/script`) implementuje CONTRACTS §2 a §7: pořadí sekcí, jedna
řádka = jedna promluva, `[pause Ns]` jen na samostatném řádku, tón platí do další
značky a na začátku sekce se vrací na `soft`, `{{osloveni|fallback}}` jen v
`uvod`/`dojezd` (MVP vždy fallback), komentáře `<!-- -->`, `status:
draft|reviewed|gold`. Text promluvy je ořezaný, běhy bílých znaků jsou jedna
mezera, Unicode NFC. `Script.Sequence(voiceID)` vrací promluvy a pauzy s
`utterance_key` = `sha256(voice_id ␟ tón ␟ text)`; testuje se proti
`docs/testdata/utterances.golden.json` (stejný soubor testuje Dart v appce).

Hledání skriptu: `content/scripts/{id}.{len}.md`, jinak
`content/scripts/gold/{id}.{len}.md`. Draft v `scripts/` tedy zakryje zlatou
kopii stejného id.

Rychlosti tónů (`speech.tones` v `config.yaml`): soft 0.85×, slow 0.78×,
whisper 0.75×; v `dojezd` rychlost lineárně klesá k 0.75× (`speech.ramp`).
Slouží pro odhady délky (judge, `est_duration_s`) a jako `speed` pro klonující
engine. Hlasitost řídí přehrávač v appce.

## Judge — deterministické kontroly

- skript projde parserem (sekce, značky, placeholder, front matter),
- odhad délky: 95 slov/min při 0.85× (pomalejší tóny úměrně déle) + pauzy +
  mezery mezi promluvami (`speech.gap_s`), ±15 % od cílové délky; rozpočty sekcí
  z plánu §1.1 (`judge.section_budgets_10min`, škálují se lineárně s délkou),
- zakázaná slova z `content/prompts/forbidden_words.txt` (prefixy kmenů; víceslovné
  fráze jako podřetězec; `slovo=` = přesná shoda), jinak vestavěný seznam,
- věty ≤ 18 slov, žádný `?`,
- v `dojezd` aspoň jedna `[whisper]` promluva,
- pauzy rostou: průměr v `dojezd` ≥ průměr v `pribeh`, nejdelší pauza je v `dojezd`
  (varování, když se v dojezdu zkracují nebo skript nekončí pauzou).

Oba zlaté skripty (`content/scripts/gold/`) projdou; testy to hlídají.

## Publikace a katalog (schema 2)

- Skripty: každé `{id}.{len}.md` ze `scripts/` a `scripts/gold/` (podle pořadí
  hledání). Publikuje se jen `reviewed` a `gold`; drafty a nevalidní skripty jsou
  ve výstupu v `skipped`. Soubor se kopíruje beze změny, katalog nese `sha256`,
  `bytes` a `est_duration_s` (odhad jako judge).
- Metadata pohádky z front matter skriptu; `free` z front matter, jinak ze
  stávajícího katalogu, jinak `publish.default_free`.
- Ambient: `content/ambient/{id}.opus` + metadata v `content/ambient/ambient.json`
  (`[{id, title, license, source, free}]`; `title` doplní §4, `license` je povinná).
- Presety: `content/presets/presets.json`. Preset, jehož vrstvy odkazují na
  nepublikovaný ambient, se vynechá; `tales[].ambient` se vyprázdní, dokud
  smyčka není publikovaná.
- Katalog se staví znovu z `content/`; ze starého se bere jen `version`, `base_url`
  a `free`. Validace jako v API: `schema` = 2, sha256 = 64 hex, každá pohádka
  ≥ 1 skript, odkazy na ambient existují, soubory sedí velikostí, `version` je
  vyšší než u předchozího katalogu (nebo stejná při stejném obsahu).

## Hlasový worker (`forge worker`, Spark)

Claim `POST /v1/jobs/claim {worker, kinds: [voice_create, voice_delete, render]}`
(204 = nic, pak čeká `worker.idle_s`), heartbeat na pozadí každých
`worker.heartbeat_s` a navíc mezi promluvami, `complete {worker, ok, result,
error, retry}`. Ztracená lease (404/409 na heartbeat) job přeruší.

| job | co dělá |
|---|---|
| `voice_create {voice_id}` | `GET /v1/worker/voices/{id}/sample` → `POST {AUDIO_URL}/v1/audio/voices` (multipart `voice_id=hajanek-{id}`, `sample`, `rights=own`, `source=hajanek-app`, `language=cs`, `replace=true`) → `POST /v1/worker/voices/{id}/status {status:"ready"}`. Odmítnutý vzorek (4xx, např. 422 krátký) → `status: failed` + `error`. |
| `voice_delete {voice_id}` | `DELETE {AUDIO_URL}/v1/audio/voices/hajanek-{id}`; 404 = v pořádku. |
| `render {voice_id, tale, length_min}` | `GET /v1/worker/scripts/{tale}/{len}` → parser → unikátní `utterance_key` → `GET /v1/worker/clips/{voice_id}` (`{keys}` — hotové se přeskočí) → pro každý chybějící po jednom: `POST /v1/audio/tts {text, language:"cs", voice:"hajanek-{id}", commercial_only:false, speed, format:"wav"}` → `202 {job_id}` → poll `GET /v1/audio/jobs/{id}` do `done` → `GET` výstupu (`outputs[0].url`) → ffmpeg: dvouprůchodový `loudnorm` −23 LUFS, AAC 64 kbps mono 48 kHz `.m4a` → `PUT /v1/worker/clips/{voice_id}/{key}` s `X-Duration-S`. Výsledek `{done, total}`. |

Chyby: audio služba **503** (GPU engine v tomhle okně neběží), 5xx, 429, síť a
`status: error` audio jobu → `retry: true` (job se vrátí do fronty, worker chvíli
počká). **403** (licence) a ostatní 4xx → job selže bez opakování. Klonující
enginy jsou nekomerční/neověřené (ADR-003) — proto `commercial_only=false`.

Nasazení: `deploy/hajanek-forge-worker.service` (systemd user service, běží
pořád, `Restart=always`). Volitelně `AUDIO_API_KEY`, pokud má audio služba klíč.

## Noční běh na Sparku

`deploy/hajanek-forge.{service,timer}` (systemd user timer, start 22:00
Europe/Prague, nové joby se neberou po 07:00) nebo `deploy/crontab.example` —
jen `forge nightly` (skripty + publikace). Proměnné v `deploy/forge.env`
(vzor `forge.env.example`, gitignored).

### Pracovní adresář

```
forge/work/                (gitignored)
  _judge/{id}.{len}.json   reporty judge
  _worker/render-*/        dočasné WAV/M4A při renderu (mažou se po jobu)
```

## Proměnné prostředí

`LLM_BASE_URL`, `LLM_API_KEY`, `LLM_MODEL` (LiteLLM na Sparku, OpenAI-kompatibilní),
`FORGE_API_URL`, `WORKER_TOKEN`, `FORGE_WORKER_NAME`, `AUDIO_URL` (výchozí
`http://localhost:8093`), `AUDIO_API_KEY`, `DISCORD_WEBHOOK`, `HAJANEK_PAGES_DIR`,
`HAJANEK_ROOT`.
