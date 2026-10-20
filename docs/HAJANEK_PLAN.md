# HAJANEK_PLAN.md — Hajánek: meditace na spaní pro děti (handoff pro Opus)

> **Název appky: Hajánek** (rozhodnuto 20. 10. 2026). Repo `lioilsources/Hajanek`,
> bundle ID `com.ol1n.hajanek` (iOS i Android), API `hajanek-api.ol1n.com`,
> obsahové repo `hajanek-content` → GitHub Pages. V UI vždy s diakritikou „Hajánek“.
> Motiv pro skripty: Hajánek je postavička, která večer obchází děti a zavírá jim
> očka — může sloužit jako opakující se refrén v dojezdu každé meditace
> („…a Hajánek už jde kolem…“).

> **Aktualizace 20. 10. 2026 — změna architektury hlasu ([ADR-003](adr/ADR-003-voice-architecture.md)):**
> výchozí hlas je **TTS telefonu** (app čte skript po promluvách), hlas rodiče se
> nahrává v appce a klonuje přes existující AiStack audio službu na Sparku.
> Odpadá benchmark TTS (§3.4), výchozí hlasy ze Sparku (§1.3, §4.2) a audio
> pipeline hlas → mastering → QA (§3.3 body 2–4). Katalog nese texty skriptů.
> Formáty: [`CONTRACTS.md`](CONTRACTS.md).

> Handoff dokument pro Claude Code (Opus). Cíl: připravit repo, architekturu a MVP
> mobilní appky, která dítěti pustí 10minutovou uklidňující meditaci na spaní
> postavenou na známé pohádce, s příjemným (volitelně naklonovaným rodičovským)
> hlasem a podkresem přírodních zvuků. Vše běží na vlastní infrastruktuře Ol1na
> (Spark pro generování, JODA pro backend, GitHub Pages pro distribuci obsahu).

---

## 0. Proč to vzniká (problém)

- Meditace na spaní pro děti **fungují** (Alexek: 10 min a spí), ale nabídka je mizerná:
  na YouTube ~10 kusů v češtině, z toho použitelné 3 — zbytek má nepříjemný hlas,
  reklamy, nebo se nedá pustit se zhasnutou obrazovkou.
- Chybí: pěkný hlas, dost obsahu (aby se to neohrálo), offline/bez reklam,
  časovač, podkres zvuků, a hlavně **hlas rodiče** — dítě usíná nejlíp na známý hlas.
- Konkurenční výhoda: vlastní TTS + klonování hlasu na Sparku → nulové marginální
  náklady na nový obsah, lokální zpracování hlasu (soukromí), český obsah jako první.

**Akceptační kritérium MVP:** Alexek usne během přehrávání bez zásahu rodiče,
minimálně 5 večerů z 7, a vydrží to ≥ 3 týdny bez omrzení (dost obsahu + rotace).

---

## 1. Produkt — tři pilíře

### 1.1 Pohádkové meditace (core)
Textová předloha = klasická pohádka (Červená Karkulka, Zlatovláska, Perníková
chaloupka, Šípková Růženka, Tři prasátka, Hrnečku vař, Dlouhý Široký a Bystrozraký,
O Smolíčkovi, Budulínek, Sněhurka…). Předloha se **přepíše do formátu usínací
meditace**:

- Pevná struktura ~10 min (konfigurovatelně 5/10/15/20):
  1. **Uvedení** (60–90 s): lehni si, přikrývka, dech, těžká víčka — 2. osoba, přítomný čas.
  2. **Vstup do pohádky** (60 s): „A teď si představ, že jdeš lesní pěšinkou…“
  3. **Tělo příběhu** (5–7 min): pomalé tempo, dlouhé pauzy, smyslové detaily
     (vůně, teplo, zvuky), **bez napětí a strachu** — vlk je ospalý a hodný, drak
     chrápe; konflikt se změkčí nebo přeskočí. Opakující se uklidňující refrén
     („…a všechno je v pořádku…“).
  4. **Dojezd** (90 s): postavy usínají, hlas zpomaluje a tichne, poslední věty
     jsou šepot, pak jen podkres, který doběhne / fade-out.
- Jazykové zásady: krátké věty, žádné otázky vyžadující odpověď, žádné „pozor!“,
  žádné spočítání/úkoly. Slovník dítěte 3–8 let.
- Generuje LLM (lokálně na Sparku přes vLLM/LiteLLM) podle **promptové šablony +
  few-shot** z ručně odladěných 2–3 vzorových skriptů. Výstup = SSML-like
  markdown s explicitními pauzami `[pause 3s]`, tempem a sílou hlasu
  (`[soft]`, `[whisper]`).
- Výstup prochází **kontrolou** (LLM-judge + checklist): délka, zakázaná slova,
  žádné napětí, klesající dynamika ke konci.

### 1.2 Jukebox uklidňujících zvuků
- Smyčkovatelné ambientní podkresy (vlastní generace nebo CC0 zdroje, nikdy
  copyrightované nahrávky): šum moře, zpěv ptáků v pralese, cikády u moře, déšť
  na střechu, potok, oheň v krbu, vítr v korunách, noční louka, bílý/růžový/hnědý
  šum, srdeční tep (pro nejmenší), jemná kolébavka (hudební box).
- Lze pustit **samostatně** (bez pohádky) nebo jako **podkres pod meditaci**
  (ducking pod hlasem, viz 3.3).
- Mix: 1 hlavní vrstva + až 2 vedlejší (např. moře + cikády), každá s vlastní
  hlasitostí. Uložené presety („Prales v noci“, „Pláž večer“).

### 1.3 Klonování hlasu (premium / fáze 2)
- Rodič v appce **přečte krátký scénář** (1–3 min, cca 15 vět navržených tak, aby
  pokryly českou fonetiku + měkký usínací tón). Nahrávka jde na Spark, vznikne
  hlasový profil, všechny meditace se dají **přegenerovat jeho hlasem**.
- Hlas je vázaný na účet, zpracovává se jen na vlastní infrastruktuře, uživatel
  ho může kdykoliv smazat (včetně vygenerovaného audia).
- Pravidla: klonuje se **výhradně vlastní hlas** uživatele (souhlas při nahrávání,
  nahrávka musí obsahovat vyřčenou souhlasnou větu, kterou lze ověřit ASR).
  Žádné nahrávání jiných osob z audia/videa. Vygenerované audio nese neslyšitelný
  watermark (viz AILineage — lze navázat na podepsaný manifest).
- Výchozí hlasy (fáze 1): 2–3 kvalitní „domácí“ hlasy (ženský, mužský, babička),
  vybrané/odladěné na Sparku tak, aby byly opravdu příjemné — tohle je hlavní
  bod selhání konkurence, věnovat mu čas.

---

## 2. Rozsah fází

| Fáze | Obsah | Hotovo když |
|---|---|---|
| **MVP (0)** | Flutter app, 10 českých pohádek × 2 hlasy × 10 min, 8 zvuků, časovač, přehrávání na zamčeném displeji, offline, žádný login | Alexek test splněn, TestFlight + interní Play track |
| **1** | 30 pohádek, 3 hlasy, délky 5/10/15/20, mixér zvuků s presety, rituál „dobrou noc“ (viz 4.3), noční pipeline na Sparku | Public beta, Play + App Store |
| **2** | Klonování hlasu rodiče, účet (jen pro hlas), přegenerování katalogu vlastním hlasem | První platící uživatelé |
| **3** | SK/EN/DE/PL verze, balíčky pohádek (monetizace jako Lexify/Storyteller), vlastní text pohádky → meditace, sdílení hlasu v rodině | Škálování |

---

## 3. Architektura

```
┌──────────────┐    katalog (JSON+opus)     ┌─────────────────────────┐
│ Flutter app  │ ◄────────────────────────── │ GitHub Pages / R2 CDN   │
│ iOS+Android  │                             └───────────▲─────────────┘
│ offline-first│    hlas (fáze 2, HTTPS)                 │ publish
└──────┬───────┘                                         │
       │                                        ┌────────┴────────┐
       ▼                                        │ JODA (Go API)   │
  hajanek-api.ol1n.com ──────────────────────│ sqlc + SQLite   │
       (Cloudflare Tunnel + Caddy)              │ job queue       │
                                                └────────┬────────┘
                                                         │ jobs
                                                ┌────────▼────────┐
                                                │ DGX Spark       │
                                                │ vLLM (skripty)  │
                                                │ TTS + voice clone│
                                                │ audio mix (ffmpeg)│
                                                └─────────────────┘
```

### 3.1 Mobilní app (Flutter)
- **Offline-first**: celý free katalog je v bundlu nebo se stáhne při prvním
  spuštění; nic nevyžaduje síť kromě aktualizace katalogu a klonování hlasu.
- Audio: `just_audio` + `audio_service` (background přehrávání, lock-screen
  ovládání, CarPlay/Android Auto není potřeba). Zvuky = gapless loop
  (`LoopMode.one` + předpřipravené bezešvé smyčky), hlas = jedna stopa.
  Mixování hlas + podkres se dělá **v appce** (2–3 paralelní `AudioPlayer`),
  aby šlo měnit poměr a podkres za běhu. Fade-out řeší app, ne soubor.
- UI: tmavé, **„noční“** — velmi nízký jas, žádné bílé plochy, velká tlačítka
  (rodič ovládá potmě), po 10 s neaktivity ztmavení. Fonty z `cute_kid_fonts`
  jen pro dětské prvky; ovládání pro rodiče střízlivé.
- Lokální stav: `drift`/sqlite — oblíbené, historie, presety mixu, poslední
  hlasitosti, časovač. Žádný účet v MVP.
- Platformy: iOS 15+, Android 8+. Permissions pro MVP: žádné (mikrofon až fáze 2).

### 3.2 Backend (Go, JODA)
- Jediný Go service `hajanek-api`: katalog (verze, URL), job queue pro
  generování (reuse vzoru z AiStack/controller-manager), ve fázi 2 endpointy
  pro nahrání hlasu a stažení přegenerovaného katalogu. SQLite + sqlc +
  golang-migrate, Docker Compose, Caddy, Cloudflare Tunnel.
- Statický obsah se **publikuje na GitHub Pages** (jako Lexify / Storyteller
  balíčky): `catalog.json` + `/audio/{tale}/{voice}/{length}.opus` +
  `/ambient/{name}.opus`. CDN zdarma, nulová zátěž na JODA.

### 3.3 Generační pipeline (Spark) — `hajanek-forge` (Go CLI + Python workers)
1. **tale → script**: LLM (vLLM přes LiteLLM) z předlohy vygeneruje skript dle
   šablony 1.1; uloží `script.md` s pauzami a tónem. LLM-judge kontrola.
2. **script → voice**: TTS engine (viz 3.4) po větách/odstavcích, pauzy vkládá
   mixér (ne TTS). Rychlost řeči ~0.85×, ke konci klesá na ~0.75× a hlasitost
   −6 dB, poslední odstavec whisper mód (pokud engine umí), jinak dodatečný
   low-pass + −10 dB.
3. **mastering** (ffmpeg): low-pass ~8 kHz (teplejší), jemný de-esser,
   loudness normalizace na **−23 LUFS** (tišší než běžný obsah), true-peak −3 dB,
   mírná reverb „pokojík“ pro měkkost. Export **Opus 48 kbps mono** (hlas) a
   **Opus 96 kbps stereo** (ambient smyčky, délka 60–120 s, bezešvé).
4. **QA**: automaticky Whisper ASR → porovnání se skriptem (WER < 5 %),
   detekce artefaktů (clipping, ticho > 15 s, vysoké frekvence). Náhodný ruční
   poslech 1/10.
5. **publish**: verze katalogu, commit do `hajanek-content` repa → Pages.
- Celé to běží **nočně** (cron na Sparku, vzor STORYTELLER_OFFLINE_PLAN.md),
  denní „nová meditace“ pro rotaci obsahu.

### 3.4 TTS / klonování hlasu — rozhodnutí pro Opus (ověřit aktuální stav modelů!)
Klíčová podmínka: **kvalitní čeština + zero-shot klonování + lokální běh na
GB10/ARM64**. Kandidáti k benchmarku (stav k mému vědomí, Opus ať ověří
aktuální verze/licence):
- **XTTS-v2** (Coqui) — čeština nativně, zero-shot klon z ~6 s, licence
  Coqui Public (nekomerční! → pozor na fázi 2/3 monetizace, zjistit alternativu
  nebo komerční licenci).
- **F5-TTS** + český fine-tune / **E2-TTS** — flow-matching, velmi přirozené,
  MIT licence; čeština jen přes komunitní fine-tune → zvážit vlastní fine-tune
  na Sparku (máme zkušenost z realeyes LoRA).
- **Fish Speech / OpenAudio**, **CosyVoice 2/3**, **Chatterbox (multilingual)**,
  **Orpheus**, **Kokoro** (bez klonu, ale velmi příjemný — kandidát na výchozí
  hlasy, pokud má češtinu).
- Postup: vybrat 3 enginy → stejná 1min ukázka skriptu v češtině → slepý
  poslech 3–5 rodičů (hodnotí „příjemnost“, ne jen srozumitelnost) → vítěz
  pro výchozí hlasy, vítěz pro klonování (může být jiný).
- Pokud žádný engine nedá dost dobrou češtinu zero-shot: **fine-tune na Sparku**
  (F5-TTS na CommonVoice cs + vlastní nahrávky) — vyhradit samostatný plán
  `HAJANEK_TTS_PLAN.md`.
- Watermark: zvážit AudioSeal (Meta) pro neslyšitelné značkování výstupu.

---

## 4. Obsah a UX detaily

### 4.1 Korpus pohádek
- Veřejná doména (Erben, Němcová, Grimmové, Andersen, Perrault — původní
  texty), reuse korpusu ze Storyteller projektu. **Ne** moderní/disneyovské
  verze a jména.
- Metadata: název, původ, věk (3+/5+/7+), prostředí (les/moře/hrad/louka) →
  automatické přiřazení doporučeného podkresu, hlavní postavy, „míra napětí
  originálu“ (kolik se musí změkčit).

### 4.2 Katalog hlasů (výchozí)
- `mama` (teplý ženský, alt), `tata` (hluboký, klidný), `babicka` (pomalá,
  trochu chraplavá) — názvy jen interní, v UI pojmenovat neutrálně podle
  dojmu („Měkký“, „Hluboký“, „Vlídný“).

### 4.3 Rituál „dobrou noc“ (fáze 1)
- Rodič nastaví: jméno dítěte (vloží se do skriptu — „…a Alexek se zachumlal…“,
  TTS ho vygeneruje jen pro 1. a poslední odstavec, zbytek je sdílený →
  levné), oblíbený podkres, délku, čas automatického ztlumení.
- Sekvence: 1 min jen podkres → meditace → podkres doběhne 20 min a utichne.
- Statistika pro rodiče: kdy se pohádka dohrála vs. kdy bylo zařízení naposledy
  pohnuto (hrubý proxy „kdy usnul“) — volitelné, bez cloudu.

### 4.4 Čeho se vyvarovat
- Žádné animace, obrázky, hra — obrazovka má být **nuda**. Jediný vizuál:
  pomalu dýchající kruh / hvězdné nebe s minimálním jasem, vypnutelné.
- Žádné notifikace, žádné „streaky“, žádná gamifikace pro dítě.
- Žádná reklama nikdy, ani ve free tieru.

---

## 5. Monetizace (fáze 2–3, nemusí blokovat MVP)
- Free: 5 pohádek, 2 hlasy, 4 zvuky, délka 10 min.
- Jednorázově **„Celá knihovna“** (všechny pohádky + hlasy + zvuky + délky) —
  non-consumable IAP, obsah z GitHub Pages jako u Lexify.
- Jednorázově **„Můj hlas“** — klon hlasu + přegenerování knihovny; možnost
  2. hlasu v rodině. Cenově výš (náklad na GPU čas a soukromí jako hodnota).
- Žádné předplatné v začátku (rodiče jich mají dost); zvážit později u
  měsíčních nových pohádek.

---

## 6. Repo & struktura (monorepo `lioilsources/Hajanek`)

```
hajanek/
  app/            Flutter (feature-first: catalog/, player/, mixer/, voice/, settings/)
  api/            Go service (cmd/, internal/{catalog,jobs,voice}, sqlc/, migrations/)
  forge/          generační pipeline (Go CLI orchestrace + python/ workers: tts, judge, qa)
  content/        skripty .md, předlohy, prompty, presety mixů (publikuje se do Pages repa)
  content-pages/  (samostatné repo) vygenerovaný katalog + audio → GitHub Pages
  docs/           tento plán, rozhodnutí (ADR), licence modelů a zvuků
  Makefile / docker-compose.yml
```

Konvence: Go 1.23+, sqlc, golang-migrate, SQLite; Flutter stable, riverpod,
drift, just_audio, audio_service; Python workers v `uv` venv na Sparku; ffmpeg 7.

---

## 7. Kroky pro Opus (pořadí)

1. **Ověř TTS krajinu** (web): aktuální verze + licence kandidátů z 3.4, čeština,
   běh na ARM64/Blackwell. Výstup: `docs/ADR-001-tts-engine.md` s doporučením
   a skriptem benchmarku. Nesázet na jeden model, naplánovat slepý test.
2. Založ monorepo dle §6, CI (GitHub Actions: Go test/lint, Flutter analyze).
3. `content/`: ručně napsat **2 vzorové meditační skripty** (Červená Karkulka,
   Zlatovláska) jako zlatý standard pro few-shot; prompt šablona + LLM-judge
   checklist; vygenerovat dalších 8 pohádek a nechat Ol1na zkontrolovat.
4. `forge/`: pipeline script→voice→master→qa→publish na vítězném enginu; nejdřív
   1 pohádka end-to-end, Ol1n poslechne s Alexkem **před** dalším škálováním.
5. Ambient smyčky: 8 zvuků, bezešvé (crossfade loop), ověřit zdroj/licence
   (CC0 nebo vlastní generace), uložit do `content/ambient/` + ADR o zdrojích.
6. `app/`: přehrávač + mixér + časovač + offline katalog + noční UI;
   `audio_service` na obou platformách otestovat přes zamčený displej a 20 min
   běhu na pozadí (iOS background audio mode!).
7. `api/`: minimální katalogový endpoint + publish na Pages; job queue připravit,
   ale voice endpointy až fáze 2.
8. TestFlight + Play internal; 2 týdny testu s Alexkem, deník usínání → iterace
   skriptů (nejčastější chyba bude tempo a napětí, ne technika).
9. Fáze 2 (samostatný plán `HAJANEK_VOICE_PLAN.md`): nahrávací flow v appce,
   souhlasná věta + ASR ověření, voice profil na Sparku, přegenerování, mazání,
   watermark, GDPR text.

---

## 8. Otevřené otázky pro Ol1na

- ~~Název appky~~ — rozhodnuto: **Hajánek** (viz hlavička).
- Chceme v MVP jméno dítěte ve skriptu (4.3), nebo až fáze 1?
- Má se korpus sdílet se Storytellerem jako samostatný balíček (`tales-corpus`),
  nebo kopírovat?
- Licence: jsme OK s nekomerční licencí XTTS pro MVP (bez IAP), nebo rovnou
  cílit na MIT/Apache engine kvůli fázi 2?
- Vlastní hudební kolébavky (generovat, nebo jen přírodní zvuky)?

---

## 9. Vazby na ostatní projekty
- **Storyteller** — korpus pohádek, noční offline pipeline, Pages monetizace.
- **AiStack** — job queue / controller vzor pro forge.
- **realeyes LoRA** — zkušenost s fine-tune na Sparku (případný TTS fine-tune).
- **AILineage** — podepsaný manifest + watermark pro vygenerovaný hlas.
- **cute_kid_fonts** — dětské typografické prvky.
- **Ol1nBot (Discord)** — notifikace o nočních generacích a releasech.
