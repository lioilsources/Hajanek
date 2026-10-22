# Hajánek — mobilní aplikace (Flutter MVP)

Usínací pohádkové meditace pro děti: hlas + podkres přírodních zvuků, rituál
„dobrou noc“, časovač, jukebox zvuků. Offline-first, žádný účet, žádná analytika.
Bundle ID `com.ol1n.hajanek` (iOS i Android), iOS 15+, Android 8+ (minSdk 26).

Architektura hlasu: [ADR-003](../docs/adr/ADR-003-voice-architecture.md).
Katalog nese **texty skriptů**, ne audio. Pohádku čte buď **hlas telefonu**
(systémové TTS, offline), nebo **hlas rodiče** — klon vytvořený na Sparku,
stažený po větách jako klipy. Formáty: [CONTRACTS.md](../docs/CONTRACTS.md).

## Spuštění

```bash
cd app
flutter pub get
dart run build_runner build      # jen po změně tabulek v lib/core/db/database.dart
flutter run                      # zařízení/simulátor
flutter test                     # unit + widget testy (čte i ../docs/testdata)
flutter analyze
```

`flutter test` se spouští z `app/` a potřebuje celé repo: golden test parseru
čte `../docs/testdata/utterances.golden.json` a test bundlu porovnává
`assets/scripts/` s `../content/scripts/`.

### `--dart-define`

| proměnná | výchozí | k čemu |
|---|---|---|
| `CATALOG_URL` | `https://lioilsources.github.io/hajanek-content/catalog.json` | odkud se stahuje katalog |
| `API_URL` | `https://hajanek-api.ol1n.com` | hajanek-api (registrace zařízení, hlasy rodičů, klipy) |
| `INCLUDE_DRAFTS` | `true` | ukázat pohádky, jejichž skript v bundlu má `status: draft`. **Pro release musí být `false`** (`flutter build ipa --dart-define=INCLUDE_DRAFTS=false`). Drafty jsou zatím i v publikovaném katalogu (`forge publish --drafts`, kvůli testu s Alexkem); appka je pozná podle `status` skriptu. |

Appka mluví jen s Pages (katalog) a s `hajanek-api`; nikdy s `llm.ol1n.com`
a nepotřebuje žádné CF Access tajnosti.

### Obsah v bundlu

Bundle je přesná kopie publikovaného katalogu (`hajanek-content`):

```bash
forge/bin/forge publish --repo . --content-pages ../hajanek-content --drafts --min-version N
tools/sync_app_bundle.sh      # catalog.json + skripty + ambient + nahrávací text → app/assets/
```

Testy `bundled scripts are copies of content/` a `bundled files match their
hashes` spadnou, když se na to zapomene.

## Struktura

```
lib/
  main.dart              init: drift, katalog, audio_session, audio_service, TTS, API
  app.dart               MaterialApp.router + go_router trasy
  core/
    script/script.dart   parser skriptu (CONTRACTS §2/§7): promluvy a pauzy se
                         sekcí a tónem, oslovení, NFC, utterance_key, odhad délky
    script/tone.dart     tabulka tónů + dojezd ramp + převod rychlosti pro platformu
    strings.dart         všechny české texty UI na jednom místě
    theme.dart, widgets.dart, providers.dart, content_ref.dart (bundle vs. soubor)
    db/database.dart     drift: oblíbené, historie, předvolby, key/value nastavení
  features/
    catalog/             modely catalog.json (schema 2), plán synchronizace,
                         repozitář, Domů, detail pohádky
    player/              script_sequencer (čistý Dart: promluvy → VoiceSource,
                         pauzy → Timer), voice_source (ClonedVoiceSource s
                         fallbackem), system_tts (flutter_tts, výběr českého hlasu),
                         audio_engine (3 ambient vrstvy + přehrávač klipů),
                         rituál, controller, audio_service handler, obrazovka
    voice/               hajanek-api klient, stav hlasů rodiče (polling, stahování
                         klipů), obrazovka „Hlas“, nahrávání vzorku
    mixer/, timer/, settings/
assets/
  catalog/catalog.json   kopie publikovaného katalogu (schema 2, všech 10 pohádek)
  scripts/{id}.10.md     texty všech skriptů (8 z 10 je zatím draft)
  voice/recording_script.md   text, který rodič čte při nahrávání
  ambient/{id}.opus      8 zvuků + 14 ukolébavek
```

## Jak to funguje

- **Katalog**: start z bundlu → novější uložený `catalog.json` z dokumentů →
  na pozadí kontrola vzdáleného. Je-li `version` vyšší, stáhnou se všechny
  změněné skripty a smyčky (podle `sha256`, ověří se hash) a teprve pak se
  atomicky přepne `catalog.json`. Soubory jsou adresované obsahem
  (`catalog/blobs/{sha256}.md|.opus`). Vzdálený katalog jiného `schema`
  (např. starý schema 1 na Pages) se tiše ignoruje.
- **Přehrávač**: jeden pro oba hlasy. `ScriptSequencer` jde po položkách
  skriptu; promluvu předá `VoiceSource`, pauzu odměří časovačem. Pauza
  uprostřed promluvy zastaví TTS/klip a po pokračování ji přečte znovu od
  začátku; pauza uprostřed ticha si pamatuje zbytek. Rituál: podkres sám N s →
  skript (podkres ztlumený ×0.6) → podkres doznívá → fade-out. Konec skriptu
  = „voiceCompleted“ pro rituál i časovač „po dohrání“.
- **Hlas telefonu** (`SystemTtsSource`): `cs-CZ`, z `getVoices` vybere nejlepší
  český hlas (iOS premium > enhanced > default, Android podle kvality,
  offline přednostně). Tón: rychlost relativně k normálu (iOS 0.5 = normál,
  Android 1.0), hlasitost = tón × posuvník hlas↔podkres × fade časovače
  (u TTS platí od další věty), `whisper` navíc pitch 0.95.
- **Hlas rodiče** (`ClonedVoiceSource`): klip
  `applicationSupport/voices/{id}/{utterance_key}.m4a`; chybí-li, větu přečte
  hlas telefonu. Klíč se počítá z textu s fallbackem oslovení (CONTRACTS §7),
  takže nastavené oslovení dítěte klipy nerozbije.
- **Nahrání hlasu**: jméno → text k přečtení (první věta je souhlas) → zaškrtnutý
  souhlas → nahrávka 5–30 s (AAC 48 kHz mono, bez AGC/potlačení šumu/echo
  cancel; Android zdroj `VOICE_RECOGNITION`) → poslech → odeslání. Zařízení se
  jednou zaregistruje (`POST /v1/devices`), token je ve `flutter_secure_storage`.
  Pak `POST /v1/voices`; stav se polluje každé 2 min, dokud hlas není hotový
  („Hlas se připravuje, bude hotový do rána“). Když je `ready`: `POST renders`
  pro všechny free pohádky (znovu jen při změně sha skriptu), manifesty,
  stažení chybějících klipů (`.part` + rename, kontrola délky v bajtech),
  průběh „x z y vět“. Smazání: potvrzení → `DELETE /v1/voices/{id}` → smaže
  klipy v telefonu. Chyby sítě jsou klidné české věty, nic dalšího se nerozbije.
- **Lock screen**: název pohádky a aktuální sekce (Úvod / Vstup / Příběh /
  Dojezd), play/pause/stop.
- **Bez českého hlasu** v telefonu ukáže Domů (a obrazovka Hlas) návod, jak ho
  doinstalovat.

## Co je potřeba ověřit na zařízení

- **Systémové TTS se zamčenou obrazovkou na iOS**: session je
  `AVAudioSessionCategoryPlayback` (audio_session + `setSharedInstance(true)`,
  `autoStopSharedSession(false)`, `UIBackgroundModes=audio`). Ověřit, že
  AVSpeechSynthesizer čte dál po zamčení i po 10+ minutách, že se mezi větami
  session nedeaktivuje (podkres nesmí utichnout) a že pauza/pokračování z lock
  screenu funguje uprostřed věty.
- **Android na pozadí**: běží foreground service audio_service; ověřit čtení
  se zhasnutým displejem a bez podkresu (jen TTS) a že TTS nebere audio focus
  ambientu.
- **Dostupnost českého hlasu**: co vrací `getVoices` na iOS (Zuzana
  default/enhanced/premium) a na Androidu (Google TTS, `network_required`),
  a že se návod k instalaci zobrazí jen tehdy, když opravdu chybí.
- **Kvalita nahrávky**: že je zvuk z mikrofonu nezpracovaný (iOS bez voice
  processing, Android `VOICE_RECOGNITION`), dost hlasitý a že klon z ní zní
  přirozeně; že se po nahrávání vrátí session na přehrávání.
- **Rychlost a hlasitost tónů**: dojezd má zpomalovat a ztišovat plynule;
  na iOS se rychlost 0.85× mapuje na `0.425`.
- Dál platí z dřívějška: bezešvost smyček, souběh přehrávačů, Ogg Opus na
  iOS 15–25 (ověřeno jen iOS 26 simulátor, `integration_test/codec_probe_test.dart`).

## Co chybí

- Oslovení dítěte je v nastavení, ale skripty ho v MVP nepoužívají
  (CONTRACTS §2) — všechny čtou fallback.
- Volba hlasu po pohádkách (teď jeden hlas pro celou appku), délky 5/15/20 min,
  statistika „kdy usnul“.
- Licence klonování (ADR-003): placený „Můj hlas“ neprojde, dokud nebude
  český klonující engine s komerční licencí.

## Release

Tag `v*` spustí dva workflowy, oba vždy s `INCLUDE_DRAFTS=false`:

- `release-android.yml`: podepsané AAB + APK (`hajanek-<tag>.apk`, na to
  odkazuje olin.now/hajanek) na GitHub Release. Firebase se přeskočí, dokud
  není `FIREBASE_ANDROID_APP_ID`.
- `release-ios.yml`: archiv s ručním podpisem (Release config má
  `CI_PROFILE_NAME`, CI za něj dosadí UUID profilu) → TestFlight + IPA na
  GitHub Release.

Secrets jednou, až leží App Store profil v `Distribution/Apple/Hajanek/`:
`Distribution/scripts/setup-gh-secrets.sh --repo lioilsources/Hajanek --bundle-id com.ol1n.hajanek`.
Upload keystore se vygeneruje do `Distribution/Android/Hajanek/` a do Bitwardenu
(`Hajanek Android Signing`); do gitu nepatří a nikdy se nesmí smazat.

Podfile zvedá deployment target všech podů na 15.0: podspec Flutteru má 13.0
a Xcode 27 pod 15.0 nepostaví.

Ikona: zdroj `assets/icon/icon.svg`, z něj `icon.png` a `icon_foreground.png`
(adaptivní, průhledná); platformní ikony `dart run flutter_launcher_icons`.
Ten při generování přepíše v `project.pbxproj` nesouvisející
`ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` na `AppIcon` — vrať to.
