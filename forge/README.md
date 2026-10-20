# forge — generační pipeline Hajánka

`hajanek-forge` = Go CLI (orchestrace, parser, judge, mix, katalog) + Python
workery (TTS adaptéry, QA). Pohádka → skript → hlas → mastering → QA →
publikace do `hajanek-content` (GitHub Pages). Formáty: [`docs/CONTRACTS.md`](../docs/CONTRACTS.md),
plán: [`docs/HAJANEK_PLAN.md`](../docs/HAJANEK_PLAN.md) §1.1, §3.3, §3.4.

```sh
cd forge
go build -o bin/forge ./cmd/forge
go vet ./... && go test ./...
./testdata/smoke.sh            # end-to-end s dummy enginem, bez GPU a bez LLM
```

Potřeba: Go 1.26, ffmpeg (s libopus, `loudnorm`, `deesser`, `aecho`/`afir`, `ebur128`),
python3. Lokálně stačí holý python (dummy engine + QA přes ffmpeg); na Sparku `uv`.

## Příkazy

Každý krok je idempotentní: výstupy nesou `stamp` (hash vstupů + konfigurace)
a při shodě se přeskočí; `--force` vynutí přepočet. Společné přepínače:
`--repo`, `--content DIR` (jiný adresář obsahu, např. `testdata/content`),
`--config FILE`, `--force`.

| Příkaz | Co dělá |
|---|---|
| `forge script --tale ID --length 10` | předloha `content/tales/{id}.md` + `prompts/script_template.md` (sekce SYSTEM/USER, proměnné `{{tale_text}}` …) + 2 zlaté skripty jako few-shot → LLM → `content/scripts/{id}.{len}.md` se `status: draft`. Když deterministický judge neprojde, LLM dostane chyby a opraví (`llm.attempts`). Pak `forge judge`. |
| `forge judge [--no-llm] [--length N] FILE` | deterministické kontroly + volitelně LLM-judge (`prompts/judge_checklist.md`, skóre ≥ 4, žádné `blockers`). JSON report na stdout i do `work/_judge/`, exit 1 při neúspěchu. |
| `forge voice --tale --voice --length [--allow-draft]` | parser → promluvy → TTS worker → cache → `voice.wav` (48 kHz mono) s pauzami a mezerami. Skript se `status: draft` odmítne bez `--allow-draft`. |
| `forge master --tale --voice --length` | highpass 70 Hz, lowpass 8 kHz, de-esser, jemný „pokojík“ (`aecho`, nebo `afir` s generovanou IR), dvouprůchodový `loudnorm` −23 LUFS / TP −3 → `master.opus` (Opus 48 kbps mono 48 kHz) + `master.json` s naměřenou hlasitostí. |
| `forge master-ambient [--crossfade S] IN OUT` | bezešvá smyčka (posledních N s se prolne do začátku, výstup je o N s kratší), −30 LUFS, Opus 96 kbps stereo. |
| `forge qa --tale --voice --length` | `python/qa_worker.py`: Whisper ASR → WER proti textu skriptu, clipping, ticho > 15 s (mimo záměrné pauzy ze skriptu), energie nad 10 kHz → `qa.json`. |
| `forge publish --content-pages DIR [--commit]` | zkopíruje stopy, které prošly QA, do `audio/{tale}/{voice}/{len}.opus`, spočítá sha256/bytes/délku (ffprobe), sloučí `catalog.json`, `version` zvedne jen při změně, validuje (stejná pravidla jako `api/internal/catalog`). `--commit` = `git commit` v pages repu (nic jiného). |
| `forge run --tale --voice --length [--content-pages DIR]` | 1–6 za sebou; chybí-li skript, vygeneruje ho (pak ale stojí na `draft`); zastaví na judge/QA. |
| `forge nightly [--queue FILE] [--until 07:00] [--content-pages DIR] [--commit]` | joby z `hajanek-api` (když jsou `FORGE_API_URL` + `WORKER_TOKEN`), jinak z `queue.txt`; na konci jeden publish a souhrn na Discord (`DISCORD_WEBHOOK`). |

### Pracovní adresář

```
forge/work/                       (gitignored)
  _cache/tts/{engine}/{voice}/{sha256}.wav|json   cache promluv: sha256(engine, voice, text, speed, style)
  _judge/{id}.{len}.json                          reporty judge
  {tale}/{voice}/{len}/
    utt/            promluvy převzorkované na 48 kHz s gainem / low-passem
    voice.wav       sestavený hlas;  voice.json  manifest (časy, záměrná ticha, text)
    master.opus     výstup;          master.json loudness + ffprobe
    qa.json
```

## Skript → parametry hlasu

Parser (`internal/script`) implementuje CONTRACTS §2: pořadí sekcí, jedna
řádka = jedna promluva, `[pause Ns]` jen na samostatném řádku, tón platí do další
značky nebo konce sekce, `{{osloveni|fallback}}` jen v `uvod`/`dojezd` (MVP vždy
fallback), komentáře `<!-- -->`, `status: draft|reviewed|gold`. Hledání skriptu:
`content/scripts/{id}.{len}.md`, jinak `content/scripts/gold/{id}.{len}.md`.
Zrcadlo v pythonu: `python/script_parser.py` (jen extrakce, validuje Go).

Tóny a rampa se ladí v `config.yaml` (`tts.tones`, `tts.ramp`): soft 0.85×/0 dB,
slow 0.78×/−3 dB, whisper 0.75×/−10 dB (+ low-pass 3.5 kHz, pokud engine nemá
nativní šepot). V `dojezd` rychlost lineárně klesá k 0.75× a gain k −6 dB; rampa
nikdy promluvu nezrychlí ani nezesílí (bere se minimum s tónem). Mezi promluvami
je `tts.gap_s` ticha navíc k `[pause]`.

## Judge — deterministické kontroly

- skript projde parserem (sekce, značky, placeholder, front matter),
- odhad délky: 95 slov/min při 0.85× (pomalejší tóny úměrně déle) + pauzy +
  mezery, ±15 % od cílové délky; rozpočty sekcí z plánu §1.1 (`judge.section_budgets_10min`,
  škálují se lineárně s délkou),
- zakázaná slova z `content/prompts/forbidden_words.txt` (prefixy kmenů; víceslovné
  fráze jako podřetězec; `slovo=` = přesná shoda), jinak vestavěný seznam,
- věty ≤ 18 slov, žádný `?`,
- v `dojezd` aspoň jedna `[whisper]` promluva,
- pauzy rostou: průměr v `dojezd` ≥ průměr v `pribeh`, nejdelší pauza je v `dojezd`
  (varování, když se v dojezdu zkracují nebo skript nekončí pauzou).

Oba zlaté skripty (`content/scripts/gold/`) projdou; testy to hlídají.

## TTS enginy

`python/tts_worker.py` běží jako jeden proces na `forge voice` a mluví JSON lines:
požadavek `{text, speed, style, voice_ref, out_path}` → odpověď
`{ok, duration_s, style_applied}`. Registr adaptérů `python/engines/`:

| engine | stav |
|---|---|
| `dummy` | tichý tón + růžový šum, délka slova/2.5 s / speed; jen stdlib → celá pipeline jede bez GPU |
| `dots`, `moss`, `pocket` | tenké obaly nad `python/bench/engines/` (shortlist ADR-001). **Neověřené v pipeline** — čekají na rozhodnutí v [ADR-001](../docs/adr/ADR-001-tts-engine.md). Bez nainstalovaného enginu worker vrátí chybu s odkazem na ADR. |

Engine se volí `tts.engine` v `config.yaml` nebo `FORGE_TTS_ENGINE`. Reference hlasu:
`voices[].ref` (relativně k `forge/`, např. `voices/mama/ref.wav` + `ref.txt`,
volitelně `ref.whisper.wav`). Každý engine má vlastní venv (konfliktní torch):

```sh
cd forge/python
uv sync --extra whisper --extra dots     # na Sparku; torch cu130 viz python/bench/README.md
export FORGE_PYTHON="uv run --project python --extra whisper --extra dots python"
```

## QA

`qa_worker.py` bez `faster-whisper` ASR přeskočí (varování), bez `numpy` dělá
signálové kontroly přes ffmpeg `astats`/`silencedetect`. Prahy v `config.yaml` (`qa:`):
WER ≤ 5 %, clipping ≥ −0.1 dBFS, ticho > 15 s mimo záměrná ticha z manifestu,
energie nad 10 kHz ≤ −35 dB vůči celku. `FORGE_QA_SKIP_ASR=1` vypne ASR.
Samostatně: `python3 python/qa_worker.py --audio X.opus --script content/scripts/…md`.

## Publikace a katalog

- Stopy se berou z `work/*/*/*/` s `qa.json` `ok: true`.
- Metadata pohádky z front matter skriptu; `free` z front matter, jinak ze stávajícího
  katalogu, jinak `publish.default_free`.
- Ambient: `content/ambient/{id}.opus` + metadata v `content/ambient/ambient.json`
  (`[{id, title, license, source, free}]`; `title` doplní §4, `license` je povinná).
- Presety: `content/presets/presets.json`. Preset, jehož vrstvy odkazují na
  nepublikovaný ambient, se vynechá; stejně tak se vyprázdní `tales[].ambient`,
  dokud smyčka není publikovaná (API by jinak katalog odmítlo).
- Pohádka bez stop se do katalogu nedostane; `version` roste jen při změně obsahu.

## Noční běh na Sparku

`deploy/hajanek-forge.{service,timer}` (systemd user timer, start 22:00
Europe/Prague, nové joby se neberou po 07:00) nebo `deploy/crontab.example`.
Proměnné v `deploy/forge.env` (vzor `forge.env.example`, gitignored).

Worker API (CONTRACTS §6, `api/README.md`): `POST /v1/jobs/claim {worker, kinds}`
(204 = nic), heartbeat každé 2 min, `complete {worker, ok, result, error, retry}`;
`retry: true` jen u přechodných chyb (LLM 5xx/429, timeout, pád TTS workeru).
Druhy jobů: `script`, `voice`, `master` (+QA), `publish`, `tale` (celá pipeline,
prázdný hlas = všechny hlasy). Fronta bez API: `queue.txt`, řádky
`tale voice délka [kind]` (`-` místo hlasu = všechny); hotové kroky se díky
cache neopakují.

## Proměnné prostředí

`LLM_BASE_URL`, `LLM_API_KEY`, `LLM_MODEL` (LiteLLM na Sparku, OpenAI-kompatibilní),
`FORGE_PYTHON`, `FORGE_TTS_ENGINE`, `FORGE_API_URL`, `WORKER_TOKEN`,
`FORGE_WORKER_NAME`, `FORGE_JOB_KINDS`, `DISCORD_WEBHOOK`, `HAJANEK_PAGES_DIR`,
`HAJANEK_ROOT`, `FORGE_QA_SKIP_ASR`, `WHISPER_DEVICE`, `WHISPER_COMPUTE`.
