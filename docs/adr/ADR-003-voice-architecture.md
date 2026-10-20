# ADR-003: Hlas telefonu jako výchozí, klon hlasu rodiče přes AiStack

- **Stav:** přijato (20. 10. 2026, rozhodnutí Ol1na)
- **Nahrazuje:** ADR-001 (výběr TTS enginu a slepý test)

## Kontext

Původní plán (§1.3, §3.3–3.4) počítal s vlastními výchozími hlasy
generovanými na Sparku, s benchmarkem TTS enginů a s pipeline hlas →
mastering → QA → Opus na Pages. Přitom:

- Hlavní hodnota je **hlas rodiče** — dítě usíná nejlíp na známý hlas.
- AiStack `services/audio` už umí `POST /v1/audio/voices` (klon z 5–30 s
  nahrávky) a `POST /v1/audio/tts` (čeština přes chatterbox-cs / XTTS-v2).
  Ol1nLLM má hotové nahrávání v appce a přehrávání po kusech.
- Telefon má český hlas zdarma, offline a bez generování (iOS cs-CZ,
  Android Google cs).

## Rozhodnutí

1. **Výchozí hlas = systémové TTS telefonu.** App čte skript po promluvách,
   pauzy a tón (rychlost, hlasitost) řídí sama. Katalog nese texty skriptů,
   ne audio (CONTRACTS §3, §5).
2. **Hlas rodiče = klon v AiStack audio službě.** Nahrávka v appce →
   `hajanek-api` → noční/okenní job → `forge worker` na Sparku volá audio
   službu po LAN (`spark:8093`) → klipy po promluvách (AAC, −23 LUFS) zpět do
   `hajanek-api` → app je stáhne (CONTRACTS §6–§8).
3. **App nikdy nemluví s `llm.ol1n.com`.** Service token Cloudflare Access
   by šel z veřejné appky vytáhnout. Jediný veřejný bod je `hajanek-api`
   s anonymním tokenem zařízení; hlasy jsou oddělené po zařízení.
4. **Jeden přehrávač pro oba zdroje.** Promluva = systémové TTS, nebo klip
   podle `utterance_key` (CONTRACTS §7). Chybějící klip → systémový hlas.
5. Odpadá: benchmark TTS, výchozí hlasy ze Sparku, `forge voice/master/qa`,
   audio meditací na Pages. Zůstává: `forge script/judge/publish`,
   `master-ambient`, nový `forge worker`.

## Důsledky

- **Licence klonování:** česky dnes v audio službě klonuje XTTS-v2 (CPML,
  nekomerční) a chatterbox-cs (licence neověřená). Worker proto posílá
  `commercial_only=false`. **Pro placený „Můj hlas“ (IAP) to neprojde** —
  před monetizací je potřeba český klonující engine s komerční licencí
  (kandidáti z rešerše v ADR-001: dots.tts-soar, MOSS-TTS, Apache-2.0).
- **Kvalita systémového hlasu** se liší podle telefonu (iOS „Zuzana“ v
  kvalitě Enhanced/Premium je výrazně lepší než výchozí; app to rodiči
  poradí). Šeptání systémové TTS neumí — `whisper` = pomaleji, tišeji.
- **GPU okno:** klonující enginy běží na Sparku jen v okně s volnou pamětí.
  Hlas se proto „připravuje“ hodiny, ne minuty. App to musí říct.
- **Soukromí:** vzorek a klipy jsou na JODA a ve Sparku, nikde jinde.
  Smazání hlasu maže obojí. Hlas v audio službě má prefix `hajanek-`, aby se
  nemíchal s hlasy MemeShorts/Ol1nLLM.
- Plán §3.3 (noční pipeline audia) a §3.4 (výběr TTS) jsou tímto zastaralé.
