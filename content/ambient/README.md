# content/ambient — bezešvé ambientní smyčky

Formát dle `docs/CONTRACTS.md` §4: `{id}.opus`, Opus 96 kbps VBR, stereo, 48 kHz,
60–120 s, bezešvá smyčka, −30 LUFS integrated. Původ a licence:
[`LICENSES.md`](LICENSES.md), rozhodnutí: [`docs/adr/ADR-002-ambient-sources.md`](../../docs/adr/ADR-002-ambient-sources.md).

| id | délka | zdroj |
|---|---|---|
| `sea` | 100 s | Freesound 339517 (CC0) |
| `rain` | 90 s | Freesound 235827 (CC0) |
| `stream` | 100 s | Freesound 220528 (CC0) |
| `fireplace` | 100 s | Freesound 484338 (CC0) |
| `wind` | 100 s | Freesound 523389 (CC0) |
| `night-meadow` | 100 s | Freesound 333221 (CC0) |
| `pink-noise` | 60 s | syntéza ffmpeg |
| `brown-noise` | 60 s | syntéza ffmpeg |

## Soubory

- `sources.tsv` — tabulka: `id, file, start_s, len_s, xfade_s, lowpass_hz, note`.
  `file` je buď jméno v `raw/{id}/`, nebo `synth:pink` / `synth:brown`.
- `fetch_raw.sh` — stáhne zdroje do `raw/{id}/` (gitignored), ověří SHA-256.
- `make_loops.sh` — z `raw/` vyrobí `{id}.opus` a spustí ověření.
- `raw/` — **nedůvěryhodná data**, necommitují se; nic odtud se nespouští, čte je jen ffmpeg.

## Použití

```sh
./fetch_raw.sh                 # jednou (nebo ./fetch_raw.sh sea)
./make_loops.sh                # vše + verify
./make_loops.sh sea rain       # jen vybrané id
./make_loops.sh --verify       # jen kontrola existujících .opus
KEEP_TMP=1 ./make_loops.sh sea # ponechá mezivýsledky (wav) pro ladění
```

Závislosti: POSIX sh, awk, curl, ffmpeg/ffprobe (testováno 8.1; libopus nutný,
soxr není potřeba).

## Proces (make_loops.sh)

1. **Výřez** `start … start+len+xfade` ze zdroje, převzorkování na 48 kHz stereo float.
   Šumy: dva `anoisesrc` s různým seedem → `join` do stereo (dekorelované kanály).
2. **Čištění**: `highpass 40 Hz` (DC/rumble), `lowpass` 1. řádu dle tabulky (měkčí výšky).
3. **Bezešvá smyčka**: `acrossfade` (equal-power `qsin`) — posledních `xfade` s těla
   `[xfade, len+xfade)` se prolne s hlavou `[0, xfade)`. Výstup má přesně `len` s a jeho
   konec plynule navazuje na začátek (v originále jsou to sousední vzorky).
4. **Hlasitost**: změření ebur128 → jeden statický zisk na −30 LUFS (žádný dynamický
   loudnorm, aby zisk „nepumpoval“ přes šev). Pokud by true-peak přesáhl −3 dBTP
   (praskání krbu má crest ~30 dB), zapne se rychlý `alimiter` jen na transienty a zisk se
   dorovná (2 iterace).
5. **Export** libopus 96k VBR, `-application audio`, bez metadat zdroje.
6. **Verify**: dekóduje `.opus`, spojí 3×, měří integrated LUFS + true-peak (ebur128),
   `silencedetect` (−60 dB / 0,5 s → musí být 0) a **seam check**: RMS 50ms bloku
   vystředěného na každém švu vs. 20 sousedních bloků (±0,5 s), plné pásmo i >6 kHz
   (kliknutí = HF špička). PASS = šev není hlasitější než nejhlasitější soused +1 dB
   (obě pásma) a HF je do ±6 dB od mediánu. Negativní kontrola (tvrdě střižený
   hnědý šum / sinus) dává +21…25 dB → FAIL, detektor tedy funguje.

Výběr `start` v `sources.tsv`: okno s nejmenším rozptylem momentary loudness
(ebur128, bez výrazných událostí) + kontrola spektrogramu (žádné hlasy/auta/hromy
v okně; např. u `rain` je hrom v originále až 115–147 s, výřez končí na 103 s).

## Poslední běh (2026-10-20)

```
id             len_s    LUFS    dBTP   sil  full_seam    hf_seam   ok   size
sea            100.0   -30.0    -4.4     0  -1.7/-5.6  -2.0/-6.1 PASS  1001K
rain            90.0   -29.9    -4.8     0   0.5/-2.2  -2.4/-8.9 PASS  1019K
stream         100.0   -30.0    -8.1     0   3.8/-0.2   2.2/-1.3 PASS  1161K
fireplace      100.0   -30.0    -3.4     0   3.7/-1.1  0.8/-19.5 PASS  1195K
wind           100.0   -30.0    -8.1     0   0.1/-0.6  -0.7/-1.6 PASS  1013K
night-meadow   100.0   -30.0   -18.6     0  -0.5/-2.1   0.2/-1.2 PASS  1110K
pink-noise      60.0   -30.0   -19.9     0   0.1/-0.8  -0.1/-0.9 PASS   629K
brown-noise     60.0   -30.0   -18.1     0   0.1/-1.2   0.1/-0.5 PASS   626K
```
(seam sloupce: dB vs. medián sousedů / dB nad nejhlasitějším sousedem.
`stream` +3,8 dB vs. medián je přirozené „bublnutí“ — stejná špička je v originále
na stejném místě, šev je spojitý; nad maximem sousedů je −0,2 dB.)

## Poznámky pro app

- Gapless přehrávání Opus vyžaduje, aby dekodér respektoval pre-skip a end-trim
  z Ogg granule position (ExoPlayer/AVFoundation/just_audio s `LoopMode.one` to dělají);
  verify testuje přesně dekódovaný výstup ffmpeg.
- Zdroje jsou Freesound **HQ preview** (Vorbis ~160–240 kbps), ne originály: plná
  kvalita vyžaduje Freesound účet + OAuth2. Výstup je 96 kbps Opus s lowpassem
  9–12 kHz a zdroj má ~2× vyšší bitrate než výstup, takže ztráta je malá
  (dvojí lossy kódování; ověřit poslechem); pro „premium“ verzi lze originály
  stáhnout s účtem a jen vyměnit soubory v `raw/` (start/len zůstávají).
