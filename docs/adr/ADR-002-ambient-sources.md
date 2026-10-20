# ADR-002: Zdroje a výroba ambientních smyček

- **Stav:** přijato pro MVP (20. 10. 2026). Před vydáním ještě poslechnout (viz TODO).
- **Souvisí:** plán §1.2, §3.3 bod 3, §7 krok 5; `docs/CONTRACTS.md` §4;
  `content/ambient/` (README, LICENSES, sources.tsv, make_loops.sh, fetch_raw.sh).

## Kontext

Jukebox potřebuje 8 smyček (moře, déšť na střechu, potůček, krb, vítr v korunách,
noční louka, růžový a hnědý šum). Smyčky jsou veřejně na CDN (GitHub Pages) a hrají
v komerční aplikaci (IAP ve fázi 2). Proto smí pocházet jen z materiálu, který dovoluje
komerční užití **i veřejnou redistribuci upraveného zvuku**, a ideálně bez povinné
atribuce. Copyrightované nahrávky a NC licence jsou vyloučené.

## Zdroje a licence

Prověřené zdroje:

| zdroj | licence | verdikt |
|---|---|---|
| Freesound, filtr „Creative Commons 0“ | CC0 1.0 | **ano** — hlavní zdroj; licence uvedena přímo na stránce zvuku |
| Wikimedia Commons, jen PD/CC0 | PD / CC0 | **ano**, ale málo použitelného: pro krb, vítr a cvrčky nic ≥ 60 s; viz níže |
| BBC Sound Effects (bbcrewind) | RemArc: jen osobní / vzdělávací / výzkumné užití | **ne** — komerční užití vyžaduje placenou licenci |
| Sonniss GDC Game Audio Bundle | royalty-free, bez atribuce, komerční užití ve „finished game/film/app“ OK; zakázáno šířit zvuky „jako zvukové efekty“ (i upravené) a AI/ML trénink | **ne pro MVP** — naše `.opus` jsou samostatně stažitelné soubory na veřejném CDN, což je blízko zakázané redistribuci. Jen po právním výkladu. |
| CC BY / CC BY-SA | atribuce (SA i share-alike) | přípustné jen jako nouzovka; nebylo potřeba |
| CC BY-NC, Sampling+ | nekomerční / nejasné | **ne** |

Vybrané nahrávky (vše CC0 1.0, ověřeno 2026-10-20):

| id | nahrávka | autor | originál | proč tahle |
|---|---|---|---|---|
| `sea` | [Waves at Baltic Sea shore](https://freesound.org/people/pulswelle/sounds/339517/) | pulswelle | WAV 44.1 kHz/24 b, 26:04 | klidný příboj, pravidelné malé vlny, široké stereo; 26 min → lze vybrat okno bez událostí; 395 hodnocení |
| `rain` | [Soft rain on roof window](https://freesound.org/people/Metadex/sounds/235827/) | Metadex | WAV 48 kHz/24 b, 3:16 | jemný déšť na střešní okno zevnitř — „déšť na střechu“ z pohledu dětského pokoje; rovnoměrný. Hrom je až v 115–147 s, výřez 5–103 s se mu vyhýbá |
| `stream` | [Stream Wyre forest 8.1.14](https://freesound.org/people/turbostream/sounds/220528/) | turbostream | FLAC 44.1 kHz/16 b, 6:30 | malý lesní potok, velmi stabilní (LRA 0,6 LU), bez ptáků a lidí |
| `fireplace` | [Fireplace crackling wood little flame](https://freesound.org/people/BonnyOrbit/sounds/484338/) | BonnyOrbit | WAV 48 kHz/24 b, 2:04 | dohasínající krb: tiché praskání bez syčení a manipulace s polenem |
| `wind` | [Forest, close up of trees rustling in the wind](https://freesound.org/people/Anya_Media/sounds/523389/) | Anya_Media | WAV 48 kHz/16 b, 2:19 | šumění korun v poryvech, bez ptáků (alternativa „wind in the trees“ měla v 1. minutě ptáky a jinak < 60 s) |
| `night-meadow` | [Night Crickets Back Porch](https://freesound.org/people/hdfreema/sounds/333221/) | hdfreema | AIFF 48 kHz/16 b, 3:40 | husté, tiché noční cvrčky + žáby, nejstabilnější z kandidátů (σ momentary 0,4 LU); 198 hodnocení. Odmítnuto „DMP CRICKETS TEXAS“ (pronikavý tón 5 kHz) |
| `pink-noise` | syntéza `anoisesrc=color=pink` | — | — | vlastní; 2 seedy → dekorelované stereo, lowpass 7 kHz |
| `brown-noise` | syntéza `anoisesrc=color=brown` | — | — | vlastní; 2 seedy, lowpass 3,5 kHz |

Odmítnuté z Commons: „Ocean Waves on a Tropical Beach.ogg“ (CC0, ale nekonzistentní
autorství „By J.D. Savanyu“ vs. „Jarrod stanley, own work“, nahráno 2026-08 → nejistý
původ); „Snowmelt flowing into lake…“ (CC0 FLAC, ale −58 LUFS → +28 dB zisku = šum
předzesilovače). Záložní kandidát pro `stream`: „Vojníkov, 3. jez, středa.ogg“ (PD,
Juandev, Otava — česká řeka, 5 min), ale je to jez, ne potůček.

## Rozhodnutí

1. **Zdroj = Freesound CC0**, šumy vlastní syntézou. Atribuci uvádíme dobrovolně
   (`content/ambient/LICENSES.md` + obrazovka „O aplikaci“).
2. **Stahujeme HQ preview (Ogg Vorbis ~160–240 kbps) bez účtu**, ne originály.
   Originály vyžadují Freesound účet + OAuth2. Licence (CC0) platí pro dílo
   bez ohledu na formát; preview je jen jiné kódování téhož díla. Výstup je Opus
   96 kbps s lowpassem 9–12 kHz, preview má ~2× vyšší bitrate, takže dvojí lossy
   kódování by mělo být neslyšitelné — **ověřit poslechem**. Výměna za originál
   = jen jiný soubor v `raw/{id}/` (sources.tsv se nemění).
3. **Výroba čistě ffmpeg** (`make_loops.sh`): výřez → highpass 40 Hz (+ lowpass) →
   equal-power crossfade ocasu do hlavy (`acrossfade`, 5–10 s) → statický zisk na
   −30 LUFS (ne dynamický loudnorm — pumpoval by přes šev) → u krbu peak limiter na
   transienty (true-peak by jinak byl +3,3 dBTP) → Opus 96k stereo 48 kHz.
4. **Automatické ověření** po každé výrobě: 3× spojená smyčka, integrated LUFS,
   silencedetect, seam check (RMS 50ms bloku na švu vs. sousedé, plné pásmo i
   >6 kHz). Detektor ověřen negativní kontrolou (tvrdý střih → +21…25 dB → FAIL).
5. Raw soubory jsou gitignored, nedůvěryhodná data, jen vstup pro ffmpeg;
   `fetch_raw.sh` je stahuje do čerstvých adresářů a kontroluje pinnutý SHA-256.

## Výsledek (2026-10-20)

| id | délka | LUFS | true-peak | šev (plné / >6 kHz, dB vs. max sousedů) | velikost |
|---|---|---|---|---|---|
| sea | 100 s | −30,0 | −4,4 dBTP | −5,6 / −6,1 PASS | 1001 KiB |
| rain | 90 s | −29,9 | −4,8 | −2,2 / −8,9 PASS | 1019 KiB |
| stream | 100 s | −30,0 | −8,1 | −0,2 / −1,3 PASS | 1161 KiB |
| fireplace | 100 s | −30,0 | −3,4 | −1,1 / −19,5 PASS | 1195 KiB |
| wind | 100 s | −30,0 | −8,1 | −0,6 / −1,6 PASS | 1013 KiB |
| night-meadow | 100 s | −30,0 | −18,6 | −2,1 / −1,2 PASS | 1110 KiB |
| pink-noise | 60 s | −30,0 | −19,9 | −0,8 / −0,9 PASS | 629 KiB |
| brown-noise | 60 s | −30,0 | −18,1 | −1,2 / −0,5 PASS | 626 KiB |

Celkem ≈ 7,6 MiB. Ticho (−60 dB / 0,5 s) nikde.

## TODO

- [ ] **Ruční poslech** všech 8 smyček ve smyčce (sluchátka, nízká hlasitost) —
      automatika nepozná ptáka, auto ani nepříjemný charakter. Hlavně `rain`
      (popis zmiňuje ptáky a předměstský hukot) a `wind` (+24 dB zisku → šum mikrofonu?).
- [ ] Ověřit gapless v app (Opus pre-skip / end-trim na iOS i Androidu, `LoopMode.one`).
- [ ] Volitelně: originály z Freesound (účet + OAuth2) místo HQ preview.
- [ ] Mix vrstev v app: −30 LUFS je pro jednu vrstvu; při 3 vrstvách sčítání ~+3–5 dB
      → app by měla vedlejší vrstvy defaultně ztlumit (např. −6 dB).

## Kandidáti pro fázi 1 (mimo MVP)

| zvuk | návrh zdroje |
|---|---|
| cikády u moře | Freesound CC0 (hledat „cicadas“, Středomoří), vrstvit na `sea` |
| ptáci v pralese | Freesound CC0 „rainforest birds“ / Commons „Category:Rainforest sounds“ (jen PD/CC0) |
| srdeční tep | vlastní syntéza (2 tlumené sinusové „lub-dub“ pulzy ~60–70 BPM, lowpass) — žádná cizí nahrávka |
| kolébavka z hracího strojku | **jen public-domain melodie** (např. lidové „Halí belí“, „Hajej, dadej“, Brahmsova ukolébavka — skladatel † 1897) a **vlastní** syntéza/nahrávka; nikdy cizí nahrávka ani moderní aranžmá |
| bílý šum | syntéza `anoisesrc=color=white` + výrazný lowpass |
