# Hajánek — mobilní aplikace (Flutter MVP)

Usínací pohádkové meditace pro děti: hlas + podkres přírodních zvuků, rituál
„dobrou noc“, časovač, jukebox zvuků. Offline-first, žádný účet, žádná analytika.
Bundle ID `com.ol1n.hajanek` (iOS i Android), iOS 15+, Android 8+ (minSdk 26).

> ⚠️ **Nutno ověřit na zařízení: Ogg Opus na iOS.** Katalog (CONTRACTS §4–5)
> používá `.opus` (Ogg Opus). `just_audio` na iOS hraje přes AVPlayer a
> AVFoundation oficiálně podporuje Opus jen v kontejneru CAF; podpora Ogg
> kontejneru v AVPlayeru je nejistá (simulátor ani `flutter test` to neověří).
> **Fallback = AAC `.m4a` varianta** souborů pro iOS. V kódu jde vše přes jedinou
> funkci `platformAudioPath()` v `lib/features/catalog/catalog_sync.dart` —
> přepnutí přípony je jednořádková změna, ale katalog by pak potřeboval i
> `sha256`/`bytes` pro každou variantu (změna kontraktu, zatím neděláme).

## Spuštění

```bash
cd app
flutter pub get
dart run build_runner build      # jen po změně tabulek v lib/core/db/database.dart
flutter run                      # zařízení/simulátor
flutter test                     # unit + widget testy
flutter analyze
```

Jiná adresa katalogu (např. lokální server při vývoji):

```bash
flutter run --dart-define=CATALOG_URL=http://192.168.1.10:8000/catalog.json
```

Výchozí: `https://lioilsources.github.io/hajanek-content/catalog.json`.

## Struktura

```
lib/
  main.dart              init: drift, katalog, audio_session, audio_service
  app.dart               MaterialApp.router + go_router trasy
  core/
    strings.dart         všechny české texty UI na jednom místě
    theme.dart           noční paleta (téměř černá, tlumený teplý akcent), dětský font
    widgets.dart         dýchající kruh, ztmavení po 10 s nečinnosti, výběrový sheet
    providers.dart       databáze, oblíbené, uživatelské předvolby, hodiny
    audio_ref.dart       AssetRef / FileRef (bundle vs. stažený soubor)
    db/database.dart     drift: oblíbené, historie, předvolby, key/value nastavení
  features/
    catalog/             modely catalog.json, plán synchronizace, repozitář,
                         Domů, detail pohádky
    player/              rituál (čistý Dart stavový automat), audio engine
                         (1 hlas + 3 ambient přehrávače), audio_service handler,
                         controller, obrazovka přehrávače
    mixer/               jukebox: 1 hlavní + až 2 vedlejší vrstvy, předvolby
    timer/               časovač spánku (čistý Dart) + tlačítko/výběr
    settings/            nastavení (persistované v drift key/value)
assets/
  catalog/catalog.json   kopie katalogu v bundlu (verze 1)
  ambient/{id}.opus      8 ambient smyček (z content/ambient, CC0 / vlastní syntéza)
  audio/cervena-karkulka/mama/10.opus   PLACEHOLDER (8 s tón), aby šel přehrávač otestovat offline
```

## Jak to funguje

- **Katalog**: start z bundlu → pokud je v dokumentech novější uložený
  `catalog.json`, použije se ten → na pozadí kontrola vzdáleného katalogu. Je-li
  `version` vyšší, stáhnou se změněné soubory (podle `sha256`), ověří se hash a
  teprve pak se atomicky (rename) přepne `catalog.json`. Soubory se ukládají
  adresované obsahem (`catalog/blobs/{sha256}.opus`), takže nový katalog nikdy
  nepřepíše soubor, na který ukazuje starý. Ambient se drží vždy lokálně;
  pohádky se stahují na vyžádání (tlačítko „Stáhnout“) a při aktualizaci se
  obnoví jen ty, které už byly stažené. Bez sítě vše funguje.
- **Přehrávač**: hlas + až 3 ambient vrstvy jako paralelní `AudioPlayer`y,
  ambient `LoopMode.one`. Rituál (§4.3): podkres sám N s (výchozí 60) → pohádka
  (podkres ztlumený na ×0.6) → podkres doznívá (výchozí 20 min) → 60 s fade-out
  → stop. Bez rituálu: hned pohádka, po ní 60 s fade-out. Fade řeší aplikace.
  Posuvník hlas ↔ podkres. Zamčená obrazovka: play/pause/stop s názvem pohádky
  (`audio_service`).
- **Časovač**: vypnuto / 5 / 10 / 20 / 30 / 45 / 60 min / „po dohrání“;
  posledních 60 s plynule ztlumí vše a zastaví.
- **UI**: jen tmavé, velká tlačítka (≥ 56 px), po 10 s nečinnosti na
  přehrávači další ztmavení (první dotyk jen probudí). Jediný pohyb: dýchající
  kruh (vypnutelný). Názvy pohádek dětským fontem `cute_kid_fonts` (Baloo 2),
  ovládání systémovým písmem.

## Co je placeholder / co chybí

- `assets/audio/cervena-karkulka/mama/10.opus` — 8s sinusový tón, ne skutečná
  meditace. Ostatní stopy v `catalog.json` mají vymyšlené `sha256`/`bytes`
  (stažení skončí chybou hashe, dokud nebude publikován skutečný katalog
  z `content/`).
- Ambient smyčky jsou zkopírované z `content/ambient/` (skutečné CC0 nahrávky);
  při jejich změně je potřeba znovu přepočítat `sha256`/`bytes` v
  `assets/catalog/catalog.json` (nebo převzít katalog z publikačního kroku).
- Jen na reálném zařízení lze ověřit: ovládání na zamčené obrazovce, běh na
  pozadí 20+ min na iOS (UIBackgroundModes `audio` je nastaveno), přehrávání
  Ogg Opus na iOS, bezešvost smyček, souběh 4 přehrávačů.
- Jméno dítěte v rituálu, délky 5/15/20 min, statistika „kdy usnul“ — fáze 1.
- Ikona aplikace je zatím výchozí Flutter.
