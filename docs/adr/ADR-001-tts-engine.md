> **Nahrazeno [ADR-003](ADR-003-voice-architecture.md) (20. 10. 2026).** Výchozí hlas je TTS telefonu,
> klonování běží na existující AiStack audio službě. Benchmark enginů se nedělá; text níže
> zůstává jako rešerše licencí.

# ADR-001: TTS engine a klonování hlasu

- **Stav:** navrženo (provizorní rozhodnutí, finální po slepém testu)
- **Datum:** 2026-10-20
- **Souvisí:** `docs/HAJANEK_PLAN.md` §1.3, §3.3, §3.4, §7 krok 1; `docs/CONTRACTS.md` §2
- **Benchmark:** `forge/python/bench/` (README, ukázka, runner, adaptéry, slepý list)

> Všechna fakta o verzích a licencích byla ověřena 20. 10. 2026 přímo na
> Hugging Face (model card / API), GitHubu nebo PyPI — zdroj je u každého řádku.
> Co se ověřit nepodařilo, je označeno **„neověřeno“**. Kvalita češtiny je
> u většiny modelů tvrzení autorů; skutečný verdikt dá až slepý test.

## 1. Kontext

Hajánek generuje ~10min uspávací meditace offline na DGX Spark (GB10: aarch64,
CUDA 13, Blackwell sm_121, 128 GB unified memory). Výstup je statické audio
distribuované přes GitHub Pages. Ve fázi 2 přibude placená funkce „Můj hlas“
(IAP): rodič nahraje 1–3 min, na Sparku vznikne hlasový profil a katalog se
přegeneruje jeho hlasem. Od začátku tedy počítáme s **komerčním užitím**
(placená appka „Celá knihovna“ i „Můj hlas“), i když MVP zatím nic neprodává —
přegenerování celého katalogu kvůli změně enginu by stálo GPU čas i opakované
ladění hlasů.

Plán (§3.4) předpokládal kandidáty XTTS-v2, F5-TTS/E2-TTS, Fish Speech,
CosyVoice, Chatterbox, Orpheus, Kokoro. Za rok 2025–2026 se krajina výrazně
změnila: přibyla řada otevřených modelů s **nativní češtinou** a
**permisivní licencí** (MOSS-TTS v1.5, dots.tts), zatímco několik původních
kandidátů češtinu vůbec nemá.

## 2. Požadavky

| # | Požadavek | Váha |
|---|---|---|
| R1 | Kvalitní, příjemná čeština (nativně trénovaná, nebo dobrý fine-tune) | musí |
| R2 | Licence vah **i** kódu umožňující placenou appku (IAP) a generování na vlastním serveru | musí pro produkci |
| R3 | Zero-shot klonování z krátké nahrávky rodiče (fáze 2) | musí (fáze 2) |
| R4 | Lokální běh na GB10 (aarch64 + CUDA 13 + sm_121), bez cloudového API | musí |
| R5 | Řízení tempa (0.75–0.85×) a ideálně šepot/měkký tón | silně chtěné (jinak post-processing) |
| R6 | Stabilita na dlouhém textu (žádné halucinace, useknuté konce) | silně chtěné |
| R7 | Rozumná rychlost (noční dávka: ~30 pohádek × 3 hlasy × 10 min) | chtěné |

Poznámka k R5: u klonujících modelů se styl (tempo, šepot, klid) přebírá
hlavně z **referenční nahrávky**. Proto benchmark i produkce počítají se dvěma
referencemi na hlas: klidná (`ref.wav`) a šeptaná (`ref.whisper.wav`).

## 3. Kandidáti

Legenda licence: ✅ komerčně použitelné · ⚠️ podmíněně · ❌ nekomerční.

| Model | Verze / datum | Licence (váhy) | Čeština | Klonování | Šepot / rychlost | ARM64 / Blackwell | Zdroj |
|---|---|---|---|---|---|---|---|
| **XTTS-v2** (Coqui) | v2, HF 2023-10-31; udržovaný fork `coqui-tts` 0.28.0 (2026-10-19) | ❌ Coqui Public Model License (nekomerční). Kód forku MPL-2.0. Coqui (firma) skončila začátkem 2024 → komerční licenci **nelze koupit** (sekundární zdroj). Odkaz `coqui.ai/cpml` z model card 2026-10-20 neodpovídá. Změna licence: **žádná nalezena**. | nativní (17 jazyků vč. cs) | ano, ~6 s | `speed` ano, šepot ne | PyTorch, ARM64 neověřeno | https://huggingface.co/coqui/XTTS-v2 · https://github.com/idiap/coqui-ai-TTS · https://pypi.org/project/coqui-tts/ · https://www.promptquorum.com/de/power-local-llm/xtts-v2-review |
| **F5-TTS** (SWivid) | `f5-tts` 1.1.22 (2026-07-23) | ❌ váhy CC-BY-NC-4.0 (kód MIT) | ne; komunitní `chosenek/f5-tts-czech-model` (2026-04-02) **bez model card a bez licence** → nepoužitelné | ano | `speed` ano (neověřeno pro cs FT) | PyTorch | https://huggingface.co/SWivid/F5-TTS · https://pypi.org/project/f5-tts/ · https://huggingface.co/chosenek/f5-tts-czech-model |
| **E2-TTS** (SWivid) | HF 2024-10-14 | ❌ CC-BY-NC-4.0 | ne | ano | – | PyTorch | https://huggingface.co/SWivid/E2-TTS |
| **Fish Speech 1.5** | HF 2024-11-24 | ❌ CC-BY-NC-SA-4.0 | ne (13 jazyků bez cs dle tagů) | ano | – | – | https://huggingface.co/fishaudio/fish-speech-1.5 |
| **Fish Audio S2 Pro** | HF 2026-03-09 | ❌ Fish Audio Research License (jen výzkum/nekomerčně) | nativní (83 jazyků vč. cs); cs WER 2.84 na MiniMax testu (dle tabulky dots.tts) | ano | inline `[tag]` prozodie (neověřeno pro cs) | neověřeno | https://huggingface.co/fishaudio/s2-pro · https://github.com/studio-dots-ai/dots.tts |
| **Fish Audio Drama 3** | HF 2026-10-01, licence v1.0 z 2026-10-13 | ⚠️ Fish Audio Community License: komerčně jen do ročního obratu **< 500 000 USD**; **„Hosted Service“ (klonování z hlasu, který dodá uživatel) vyžaduje zvláštní licenci**; zákaz trénovat/distilovat jiné TTS z výstupů; povinné „Built with Fish Audio“ | tag cs (kvalita neověřena) | ano | přirozenojazykové řízení (neověřeno pro cs) | 35B MoE (3B aktivních), FP8 experti; servíruje SGLang-Omni / vLLM-Omni — FP8 na sm_121 neověřeno | https://huggingface.co/fishaudio/drama-3 · https://huggingface.co/fishaudio/drama-3/blob/main/LICENSE |
| **CosyVoice 3** (Fun-CosyVoice3-0.5B-2512) | HF 2025-12-11 | ✅ Apache-2.0 | **ne** (9 jazyků: zh, en, fr, es, ja, ko, it, ru, de) | ano | instrukce (neověřeno) | – | https://huggingface.co/FunAudioLLM/Fun-CosyVoice3-0.5B-2512 |
| **Chatterbox (multilingual)** | `chatterbox-tts` 0.1.7 (2026-03-26) | ✅ MIT | **ne** oficiálně (23 jazyků, cs mezi nimi není). Komunitní `Thomcles/Chatterbox-TTS-Czech` je gated, tag CC0 — obsah a kvalita **neověřeno** | ano | `exaggeration`/`cfg` (emoce), šepot ne | PyTorch | https://huggingface.co/ResembleAI/chatterbox · https://pypi.org/project/chatterbox-tts/ · https://huggingface.co/Thomcles/Chatterbox-TTS-Czech |
| **Orpheus** (Canopy Labs) | 3b-0.1-ft (2025-03, Apache-2.0); multilingual „research_release“ (2025-04) | 0.1-ft ✅ Apache-2.0; research release licence **neověřeno** (gated) | **ne** (vydány jen de, fr, es/it, ko, zh, hi) | ne (fixní hlasy) | emoční tagy (en) | Llama-3B, vLLM | https://huggingface.co/canopylabs |
| **Kokoro-82M** | `kokoro` 0.9.4 (2025-04-05) | ✅ Apache-2.0 | **ne** (en, ja, zh, es, fr, hi, it, pt-br) | ne | `speed` ano | malý, i CPU | https://huggingface.co/hexgrad/Kokoro-82M · https://huggingface.co/hexgrad/Kokoro-82M/blob/main/VOICES.md |
| **Qwen3-TTS** (Base/CustomVoice) | HF 2026-01-21 | ✅ Apache-2.0 | **ne** (10 jazyků bez cs) | ano (3 s) | instrukce tón/tempo | – | https://huggingface.co/Qwen/Qwen3-TTS-12Hz-1.7B-Base |
| **VoxCPM2** (OpenBMB) | HF 2026-04-03 | ✅ Apache-2.0 | **ne** v seznamu 30 jazyků; cs WER 24.13 na MiniMax testu (nepoužitelné) | ano | – | – | https://huggingface.co/openbmb/VoxCPM2 · https://github.com/studio-dots-ai/dots.tts |
| **OmniVoice** (k2-fsa) | `omnivoice` 0.2.1 (2026-07-16) | ❌ **váhy CC-BY-NC** (kvůli trénovacím datům, např. Emilia); kód Apache-2.0 | nativní (600+ jazyků vč. cs) | ano, 3–10 s | `speed`, `duration`; šepot jen ve „voice design“ (trénováno na zh/en) | PyTorch, i MPS | https://huggingface.co/k2-fsa/OmniVoice · https://github.com/k2-fsa/OmniVoice |
| **Higgs TTS 3** (Boson AI) | HF 2026-06-04 | ❌ Research & Non-Commercial (výjimka „Creator Use“ jen pro tvůrce obsahu; embedding v produktu vyžaduje komerční licenci) | tag cs (100 jazyků) | ano | – | 4B | https://huggingface.co/bosonai/higgs-tts-3-4b |
| **MOSS-TTS v1.5** (OpenMOSS) | HF 2026-05-25 | ✅ **Apache-2.0** | **nativní** (cs v seznamu 31 jazyků; jazykový tag doporučen) | ano (zero-shot, stabilnější než 1.0) | inline `[pause X.Ys]`; řízení délky po tokenech (1 s ≈ 12.5 tokenu) → tempo; šepot neověřeno | ~8.5 B parametrů (bf16 ~17 GB, v 128 GB pohodlně). Pinuje `torch==2.9.1+cu128` → na Sparku nahradit cu130 aarch64 wheelem (neověřeno). Menší varianty: Local-Transformer v1.5 (~4.6 B), Nano-100M (cs, Apache-2.0) | https://huggingface.co/OpenMOSS-Team/MOSS-TTS-v1.5 · https://huggingface.co/OpenMOSS-Team/MOSS-TTS · https://github.com/OpenMOSS/MOSS-TTS · https://huggingface.co/OpenMOSS-Team/MOSS-TTS-Nano-100M |
| **dots.tts** (dots-studio) | base 2026-06-03, soar 2026-06-04, mf-1/2step 2026-08-10 | ✅ **Apache-2.0** (kód i checkpointy) | **nativní / změřená**: MiniMax multilingual test, čeština WER 4.25 / SIM 84.2 (SOAR) vs. ElevenLabs 2.11 / 68.5, Fish S2 2.84 / 79.8 | ano (s přepisem reference nejlepší; i jen x-vector) | parametr rychlosti ani šepotu v README **není** → tempo time-stretchem, šepot šeptanou referencí | 2 B, bf16, volitelně `torch.compile`; ARM64 neověřeno | https://huggingface.co/dots-studio/dots.tts-soar · https://github.com/studio-dots-ai/dots.tts |
| **Pocket TTS – Czech** (komunitní, vvolhejn) | HF 2026-08-25; `pocket-tts` 3.3.0 (2026-09-24) | ✅ CC-BY-4.0 (atribuce ÚFAL / ParCzech4Speech) | **nativní** – trénováno od nuly na 976 h české řeči | ano (z audio souboru) | ne (teplota) | 6 vrstev, rychlejší než realtime **na CPU** → aarch64 bez CUDA problémů | https://huggingface.co/vvolhejn/pocket-tts-czech · https://huggingface.co/kyutai/pocket-tts · https://pypi.org/project/pocket-tts/ |
| VibeVoice (Microsoft) | 1.5B, 2025-08-25 | ✅ MIT | ne (en, zh) | – | – | – | https://huggingface.co/microsoft/VibeVoice-1.5B |
| Voxtral TTS (Mistral) | – | údajně CC-BY-NC (sekundární zdroj) | **neověřeno** – na HF nenalezeno | – | – | – | https://texttolab.com/blog/open-source-text-to-speech |

Pozn. k Pocket TTS Czech: trénováno výhradně na parlamentních projevech
(formální, převážně mužští dospělí mluvčí) — autor sám upozorňuje na slabší
výkon mimo tuto doménu. Je to spíš levná záloha a „kotva“ v testu.

### Mimo TTS

| Komponenta | Stav | Licence | Zdroj |
|---|---|---|---|
| **AudioSeal** (Meta) – watermark | `audioseal` 0.2.0 na PyPI, repo aktivní (push 2026-05) | ✅ MIT (kód i váhy) | https://github.com/facebookresearch/audioseal · https://huggingface.co/facebook/audioseal · https://pypi.org/project/audioseal/ |
| **Whisper large-v3** – ASR pro QA | cs ano | ✅ Apache-2.0 (dle HF card) | https://huggingface.co/openai/whisper-large-v3 |
| **Whisper large-v3-turbo** | cs ano, rychlejší | ✅ MIT | https://huggingface.co/openai/whisper-large-v3-turbo |
| **Parakeet TDT 0.6B v3** (NVIDIA) | 25 evropských jazyků vč. cs, 2025-08 | ✅ CC-BY-4.0 | https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3 |
| **Canary 1B v2** (NVIDIA) | cs ano, 2025-08 | ✅ CC-BY-4.0 | https://huggingface.co/nvidia/canary-1b-v2 |

Pro QA (WER < 5 %, §3.3 bod 4) doporučuji **Whisper large-v3** jako
výchozí (nejširší ekosystém, funguje i pro ASR ověření souhlasné věty ve fázi 2)
a Parakeet v3 jako druhý názor; kterou z nich lépe sedí na šepot, ukáže
benchmark (šepot bude mít WER vyšší — práh pro sekci `dojezd` zvlášť).

### Platforma (GB10)

- PyTorch publikuje aarch64 wheely pro CUDA 13 (`cu130`, verze 2.9.0 až
  2.14.1): https://download.pytorch.org/whl/cu130/torch/ — každý engine proto
  instalujeme do vlastního `uv` venv a jeho `torch` pin přepíšeme na cu130.
- Podpora sm_121 v jednotlivých kernelech (FlashAttention 2, FP8 MoE u Drama 3)
  **neověřeno** — benchmark běží s SDPA, flash-attn je volitelný.

## 4. Shortlist pro slepý test

Do užšího výběru jdou jen modely, které splňují R1 + R2 + R3 zároveň:

1. **dots.tts-soar** — Apache-2.0, jediný kandidát s **publikovaným měřením
   češtiny** (WER 4.25, nejvyšší podobnost mluvčího ze všech porovnávaných),
   2 B → rychlý. Slabina: chybí přímé řízení tempa/šepotu.
2. **MOSS-TTS v1.5** — Apache-2.0, čeština v oficiálním seznamu, explicitní
   pauzy a řízení délky (tempa), důraz na dlouhé texty. Slabina: 8 B, pomalejší,
   čeština bez publikovaného čísla.
3. **Pocket TTS – Czech** — CC-BY-4.0, čistě české váhy, běží na CPU (nulové
   riziko s CUDA/ARM). Slabina: parlamentní doména, komunitní projekt.

Nekomerční modely (XTTS-v2, OmniVoice, Fish S2 Pro, Higgs TTS 3) do testu
**nezařazujeme** — i kdyby vyhrály, nesmíme je nasadit. Volitelně lze jeden
(XTTS-v2) pustit mimo hodnocení jako interní „kotvu“, jak zní dosavadní
standard; jeho výstup se nikam nepublikuje.

## 5. Rozhodnutí (provizorní)

- **Engine pro výchozí hlasy (MVP, fáze 1):** **dots.tts-soar**, záloha
  **MOSS-TTS v1.5**. Výchozí hlasy `mama`/`tata`/`babicka` vzniknou klonováním
  z **námi pořízených referenčních nahrávek** dospělých mluvčích s písemným
  souhlasem (klidná + šeptaná reference na hlas). Licence Apache-2.0 → katalog
  je od prvního dne použitelný i v placené „Celé knihovně“, není nutné nic
  přegenerovávat.
- **Engine pro klonování rodiče (fáze 2):** stejný kandidát jako výše, pokud
  ve slepém testu s referencí „běžného rodiče“ (nahrávka z telefonu) obstojí;
  jinak vítěz testu mezi MOSS-TTS v1.5 a dots.tts. Pocket TTS Czech jen jako
  CPU záloha.
- **Vyřazeno pro produkci:** XTTS-v2 (CPML, bez cesty ke komerční licenci),
  F5/E2-TTS oficiální váhy (CC-BY-NC), OmniVoice (váhy CC-BY-NC), Fish S2 Pro
  a Higgs TTS 3 (nekomerční), Fish Drama 3 (obratový strop + „Hosted Service“
  by blokoval „Můj hlas“). Kokoro, CosyVoice 3, Chatterbox, Orpheus, Qwen3-TTS,
  VoxCPM2 češtinu nemají.
- **Odpověď na otevřenou otázku §8 plánu:** nekomerční XTTS ani pro MVP —
  permisivní engine s nativní češtinou dnes existuje, takže úspora není.
- **Tempo a šepot:** dle CONTRACTS §2. Pokud engine nemá nativní `speed`,
  tempo řeší time-stretch v mixéru (runner benchmarku to dělá stejně); šepot
  primárně šeptanou referencí, záložně low-pass 3.5 kHz + −10 dB.
- **Watermark:** AudioSeal (MIT) ve fázi 2 na veškerém audiu z klonovaného
  hlasu; zvážit už u výchozích hlasů.
- **ASR QA:** Whisper large-v3 (Apache-2.0).

Finální rozhodnutí = výsledek slepého testu (§7) + změřené RTF na Sparku.

## 6. Důsledky

- **+** Žádný licenční dluh: obsah vygenerovaný pro MVP lze prodávat.
- **+** Jeden engine pro výchozí hlasy i klonování → jedna pipeline, jeden
  tuning. Výchozí hlasy jsou technicky „klony“ souhlasících mluvčích.
- **−** Musíme pořídit kvalitní referenční nahrávky (studio/klidná místnost,
  klidný i šeptaný projev) a smlouvu s mluvčími (souhlas s klonováním a
  komerčním užitím hlasu).
- **−** dots.tts nemá řízení tempa → time-stretch může přidat artefakty; ověřit
  poslechem při 0.75×. Případně tempo „naučit“ pomalou referencí.
- **−** Modely z 2026 jsou mladé, API se mění → adaptéry v `forge/python/bench/engines/`
  izolují závislosti; každý engine má vlastní `uv` venv.
- **−** Atribuce: Pocket TTS Czech (CC-BY) by vyžadoval uvedení ÚFAL v appce.
- Fine-tune F5-TTS (§3.4 plánu) už není výchozí cesta; `HAJANEK_TTS_PLAN.md`
  založit jen pokud žádný shortlist engine neprojde testem — a pak fine-tunovat
  Apache model (dots.tts-base je k tomu určen), ne F5 s NC vahami.

## 7. Plán slepého testu

1. **Ukázka:** `forge/python/bench/sample_cs.md` (~1 min, všechny značky:
   `[soft]`, `[slow]`, `[whisper]`, `[pause Ns]`).
2. **Reference:** 1 dospělý mluvčí se souhlasem, 10–15 s klidného čtení
   (`ref.wav` + přepis `ref.txt`) a 5–10 s šepotu (`ref.whisper.wav` +
   `ref.whisper.txt`). Všechny enginy dostanou **stejnou** referenci.
   Druhé kolo: reference nahraná telefonem (simulace fáze 2).
3. **Generování:** `run_bench.py` pro každý engine → `out/{engine}/sample.wav`
   + `timing.json` (RTF). Všechny výstupy normalizovat na −23 LUFS (ffmpeg
   `loudnorm`) před poslechem, aby nevyhrával hlasitější.
4. **Anonymizace:** `make_blind_sheet.py` → `blind/A.wav, B.wav, C.wav`,
   skrytý klíč `blind/.key.json`, list `blind/rating_sheet.csv` s náhodným
   pořadím pro každého hodnotitele (ABX-like: každý slyší jiné pořadí).
5. **Hodnotitelé:** 3–5 rodičů, sluchátka nebo telefon u postele, večer.
   Hodnotí každý vzorek:
   - **příjemnost 1–5** (hlavní metrika: „pustil/a bych to svému dítěti na usínání“),
   - srozumitelnost 1–5,
   - přirozenost češtiny 1–5 (přízvuk, výslovnost ř/ě/ů, intonace),
   - poznámka (rušivé artefakty, šepot).
   Nesmí vědět, který engine je který; poslech celé minuty.
6. **Vyhodnocení:** průměr a medián příjemnosti; při remíze rozhoduje RTF a
   licence. Klíč se otevírá až po odevzdání všech listů.

Šablona listu (`rating_sheet.csv`):

```csv
rater,order,sample,prijemnost_1_5,srozumitelnost_1_5,prirozenost_cs_1_5,poznamka
R1,1,B,,,,
R1,2,A,,,,
R1,3,C,,,,
R2,1,C,,,,
```

## 8. Otevřené otázky

- Skutečná kvalita češtiny MOSS-TTS v1.5 a Pocket TTS Czech — bez
  publikovaných čísel; rozhodne test.
- Běh na GB10: kompilace/kompatibilita (sm_121, cu130, `torch.compile`,
  flash-attn) pro dots.tts a MOSS-TTS — **neověřeno**, ověří první běh benchmarku.
- dots.tts: má Python API parametr jazyka/tempa? README uvádí `--language`
  jen u CLI — **neověřeno**.
- Šepot: zvládnou klonující modely přenést šepot z reference v češtině?
  (Test sekce `dojezd`.)
- Komunitní `Thomcles/Chatterbox-TTS-Czech` (gated, CC0 tag) — stojí za to
  požádat o přístup jako 4. kandidát? Licence základního Chatterboxu je MIT.
- Fish Audio Drama 3: pokud by vyhrával kvalitou, je „Můj hlas“ Hosted Service
  ve smyslu licence? Pravděpodobně ano → bez dohody s Fish Audio nepoužitelné.
- Kdo namluví referenční hlasy (rodina vs. profesionál) a jakou smlouvou.
- Coqui: ukončení firmy je doloženo jen sekundárním zdrojem; licenční text
  CPML na `coqui.ai` 20. 10. 2026 nedostupný.
