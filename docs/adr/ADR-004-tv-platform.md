# ADR-004: Platforma pro Apple TV (a měření TTS na televizích)

- **Stav:** přijato 3A (5. 11. 2026, Ol1n); appka přešla na Flutter 3.47.
  Na reálné Apple TV zbývá ověřit Opus, české hlasy a podpis. Google TV je hotová cestou „stejný kód, stejný artefakt“
  (HAJANEK_TV_PLAN §4).
- **Navazuje na:** [HAJANEK_TV_PLAN.md](../HAJANEK_TV_PLAN.md), ADR-003.

## Kontext

Flutter tvOS oficiálně nepodporuje. Plán nabízí dvě cesty:

- **3A:** komunitní toolchain `fluttertv/flutter-tvos` s jedním kódem pro
  telefon i TV. Je potřeba portovat `just_audio`, `audio_session`, případně
  `audio_service`, a ověřit `sqlite3`.
- **3B:** nativní SwiftUI klient `tv/` jako tenký přehrávač s vlastním
  parserem hlídaným golden testem.

Ol1n rozhodl, že volbu udělá třídenní spike 3A. Druhým vstupem je, jestli
televize vůbec mají český systémový hlas. Když ho nemají, čte TV jen hlas
rodiče z párování, nebo hlas vypravěče (TV-3).

## Měření TTS (§8 krok 1)

Sonda: `app/integration_test/tts_probe_test.dart` (řádky `TTS_PROBE`).

| platforma | zařízení | české hlasy | kvalita | offline | mluví + completion |
|---|---|---|---|---|---|
| Google TV (Android 16, API 36) | emulátor `google-tv` arm64, 27. 10. 2026 | `cs-cz-x-jfs-local`, `cs-cz-x-jfs-network`, `cs-CZ-language` | high | `network_required: 0` u `-local`, ale příznak **`notInstalled`** | ano, `completed` za 5,3 s (věta ~4 s) |
| Google TV | reálná krabička | – | – | – | **čeká na Ol1na** |
| tvOS 27 | simulátor Apple TV 4K (3rd gen), 28. 10. 2026 | `com.apple.voice.super-compact.cs-CZ.Zuzana` (jediný) | default (super-compact) | ano (systémový) | ano, `completed` za 5,1 s |
| Apple TV 4K | reálná | – | – | – | **čeká na Ol1na** |

Postřehy z Google TV emulátoru:

- `getLanguages` obsahuje češtinu (81 jazyků, 473 hlasů). `pickCzechVoice`
  vybere `cs-cz-x-jfs-local`.
- `notInstalled` znamená, že hlasová data nejsou v zařízení. Na emulátoru
  s internetem se věta přesto přečetla, pravděpodobně se data stáhla nebo
  použila síť. Na reálné TV ověřit, jestli čte i offline. Když ne, je to
  argument pro TV-3 (hlas vypravěče) nebo pro hlas rodiče jako výchozí na TV.
- Detekce `formFactor` přes `UiModeManager` vrací na Google TV `tv`.

## Ověřeno na Google TV emulátoru (1080p)

- Appka je v leanback launcheru (`LEANBACK_LAUNCHER`, banner) a sama
  přepne na TV rozhraní.
- D-pad funguje: mřížka 3 sloupce, záhlaví je dosažitelné šipkou nahoru,
  select otevře detail a Spustit spustí přehrávání.
- Noční obraz po 10 s zčerná. Back vrátí na detail a `MediaSession` dál
  hlásí `PLAYING`. Po Zastavit zmizí `KEEP_SCREEN_ON` i stav přehrávání.
- Párování proti lokálnímu `hajanek-api` funguje: TV ukáže kód, „telefon“
  (curl) ho potvrdí, TV ukáže „Propojeno“ a hlas telefonu se objeví
  v seznamu hlasů TV.

## Spike 3A (28. 10. 2026)

Toolchain `fluttertv/flutter-tvos` `v3.47.8-tvos.1.11.4` (Flutter 3.47.8,
Dart 3.13.7), nainstalovaný zvlášť v `~/Dev/flutter-tvos`. Simulátor tvOS 27.0.
Všechna čtyři kritéria z plánu §3 prošla, trvalo to zhruba půl dne ze tří:

1. **hello-app:** běží (Impeller/Metal). Release build pro zařízení (AOT,
   `--no-codesign`) se zkompiluje; podpis a TestFlight netestováno.
2. **audio:** `just_audio` + `audio_session` + `audio_service` přes
   `flutter-tvos plugin port`. Hraje skutečná `brown-noise.opus` (Ogg Opus,
   smyčka) i `.m4a` klip; navíc Opus v CAF a MP4. `audio_session` potřeboval
   ~10 řádků `#if !TARGET_OS_TV` (4 symboly, které na tvOS nejsou).
   `audio_service` potřebuje `sqflite_tvos` (kvůli flutter_cache_manager).
3. **drift:** zápis i čtení, data přežijí restart. Toolchain na tvOS nespouští
   native-asset hooky, takže `sqlite3` použije systémovou libsqlite3 (3.54.0);
   do tvOS Runneru přidat `-lsqlite3`.
4. **TTS:** `flutter_tts` + `flutter_tts_tvos`, česká Zuzana čte a pošle
   completion (viz tabulka výše).

Dál: `flutter_secure_storage_tvos` a `path_provider_tvos` fungují.
`wakelock_plus` 1.8.2 má chybu v balení (`tvos:` ukazuje na kód v `ios/`),
obejde se `dependency_overrides` a `wakelock_plus_tvos`. `record` na tvOS
není a TV ho nevolá.

Skutečná `app/` se pro tvOS sestaví (32 s) a ukáže domovskou obrazovku
s katalogem, zatím v telefonním rozložení, protože tvOS runner ještě nemá
kanál `com.ol1n.hajanek/device`.

Podklady: větev `spike/tvos`, složka `spikes/tvos/`
(`evidence/run.log` s řádky `SPIKE`/`TTS_PROBE`, screenshoty, `PORTING_REPORT.md`
u každého portu).

## Rozhodnutí

**Přijato 3A** (flutter-tvos, jeden kód pro telefon i TV). Žádný ze spouštěčů
3B (engine, audio session, podpis) se neukázal; podpis jen nebyl vyzkoušen.

Cena, se kterou počítáme:

- Flutter pro tvOS je připnutý toolchainem (3.47.8); appka je na 3.47.9,
  tedy ve stejné řadě. Při povyšování hlídat, ať se neodtrhne.
- Tři malé porty (`just_audio_tvos`, `audio_session_tvos`, `audio_service_tvos`)
  a obejití wakelocku udržujeme sami v `app/packages/`; odhad 0,5–1 den.
- Native assets na tvOS neběží; týká se `sqlite3`, `objective_c` a každého
  budoucího FFI pluginu.
- Pozor na logy: plný xcodebuild log z flutter-tvos vypisuje prostředí
  včetně tajných proměnných. V CI je nefiltrovat ven.

Na reálné Apple TV ještě ověřit na reálné Apple TV: dekódování Ogg Opus (záloha:
Opus v CAF přes `afconvert -f caff -d opus`, nebo AAC), dostupnost lepších
českých hlasů než super-compact, podpis a TestFlight.

Při 3A potřebuje tvOS runner kanál `com.ol1n.hajanek/device` → `isTv`
(`UIDevice.current.userInterfaceIdiom == .tv`), na Dart straně se nic nemění.
