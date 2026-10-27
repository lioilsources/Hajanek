# HAJANEK_TV_PLAN.md — Hajánek na Apple TV a Google TV (handoff pro Opus)

> Návrh z 27. 10. 2026 (Fable). Stav: **Ol1n 27. 10. 2026 rozhodl, že volbu
> Apple TV cesty 3A/3B dělá spike** (§3 Doporučení, §8 krok 2). Ostatní otázky
> §10 čekají; §8 kroky 1–2 se mohou dělat hned.
> Navazuje na [`HAJANEK_PLAN.md`](HAJANEK_PLAN.md), [`CONTRACTS.md`](CONTRACTS.md)
> a [ADR-003](adr/ADR-003-voice-architecture.md). Výstupem spiku má být
> **ADR-004 (platforma pro Apple TV)** a změna CONTRACTS §6 (párování).

---

## 0. Co chceme a proč

Televize v dětském pokoji / obýváku má pustit tu samou usínací meditaci jako
telefon: hlas (telefonu, nebo rodiče) + podkres, rituál, časovač. Rodič ovládá
dálkovým ovladačem, obraz je skoro černý, po dohrání televize sama usne.
Obsah (katalog, skripty, smyčky) i backend (`hajanek-api`) zůstávají stejné.

Dvě věci jsou na TV **jinak než na telefonu** a řídí celý plán:

1. **TV nemá mikrofon pro appku** (tvOS ho appkám nedává vůbec, Android TV
   jen někdy přes ovladač). Nahrávání hlasu zůstává v telefonu; TV si hlas
   musí **převzít** → párování zařízení (§5).
2. **Český systémový TTS na TV není jistý.** tvOS i Google TV mají
   syntetizátor řeči, ale jestli je v něm `cs-CZ` a v jaké kvalitě, nikdo
   neověřil (§8 krok 1). Když chybí, „hlas telefonu“ na TV nemá čím číst →
   plán B je serverově předrenderovaný **hlas vypravěče** (§5.3).

Levný mezikrok, který funguje už dnes bez kódu: **AirPlay z iPhonu na Apple
TV** (systémová volba výstupu, přehrávač je `just_audio`). Google Cast tak
jednoduše nejde (vyžaduje Cast SDK). Není to náhrada TV appky, ale je dobré
to Ol1novi říct.

---

## 1. Výchozí stav (co máme a využijeme)

| Část | Stav | Pro TV |
|---|---|---|
| `app/` Flutter 3.44.4, iOS 15+ / Android minSdk 26 | hotové MVP | jeden kód pro telefon + TV (Android jistě, tvOS podle §3) |
| Přehrávač: `ScriptSequencer` → `VoiceSource` (`SystemTtsSource`, `ClonedVoiceSource`), `AudioEngine` (3 ambient vrstvy, `just_audio`), rituál, časovač | čistý Dart + pluginy | beze změny; mění se jen pluginy pod ním |
| Katalog: bundle → dokumenty → Pages, obsahově adresované bloby | hotové | beze změny |
| `hajanek-api`: anonymní zařízení, hlasy **vázané na zařízení** (`voices.device_id`) | hotové | **nutná změna**: hlas musí být dostupný i spárované TV (§5) |
| Release: `release-android.yml` (AAB+APK), `release-ios.yml` (TestFlight), golden v `../Distribution` | hotové | Android: stejný artefakt + TV metadata; tvOS: nový workflow |
| Platformní větvení v appce | jen 2 místa (`system_tts.dart`, `voice_screen.dart`) | přidat `formFactor` (phone/tv) jako provider, nevětvit podle OS |
| Focus/klávesnice v UI | prakticky nic (2 výskyty) | TV UI je focus-first → nová vrstva obrazovek (§6) |

---

## 2. Rozsah

| Fáze | Obsah | Hotovo když |
|---|---|---|
| **TV-0 měření a spike** (2–4 dny) | TTS `cs` na Apple TV i Google TV; `flutter-tvos` hello + port audio pluginů; ADR-004 | Ol1n má v ruce čísla a rozhodnutí §10 |
| **TV-1 Google TV** (1–2 týdny) | manifest, 10-foot UI, D-pad, párování (API + telefon + TV), interní Play track s form faktorem TV | Alexek usne u televize na hlas rodiče |
| **TV-2 Apple TV** (1–3 týdny podle ADR-004) | tvOS build dle zvolené cesty, stejné UI a párování, TestFlight tvOS | totéž na Apple TV |
| **TV-3 hlas vypravěče** (jen pokud TTS na TV chybí) | serverový default hlas s komerční licencí, klipy přes Pages | TV čte i bez českého systémového TTS |

---

## 3. Apple TV — dvě cesty, rozhodnout spikem (ADR-004)

Flutter **oficiálně tvOS nepodporuje.** Existuje komunitní toolchain
[`fluttertv/flutter-tvos`](https://github.com/fluttertv/flutter-tvos)
(drop-in náhrada `flutter` CLI + předkompilovaný tvOS engine, SDK se
nepatchuje; vydání `v3.47.x-tvos.1.10.x`, BSD-3, ~250 commitů, jeden
udržovatelský tým) a index pluginů
[`fluttertv/plugins`](https://github.com/fluttertv/plugins) (25 balíčků).

### 3A. `flutter-tvos` — jeden kód s telefonem

Co sedí: `path_provider_tvos`, `flutter_secure_storage_tvos`,
`flutter_tts_tvos`, `wakelock_plus_tvos`, `url_launcher_tvos` existují.
`record` se na tvOS prostě nenačte (plugin bez `tvos:` se ignoruje) a na TV
ho nevoláme.

Co chybí a musí se **portovat** (`flutter-tvos plugin port` udělá kostru
z iOS implementace):

| plugin | iOS implementace | šance na tvOS |
|---|---|---|
| `just_audio` | AVQueuePlayer (ObjC) | vysoká — AVFoundation je na tvOS |
| `audio_session` | AVAudioSession | vysoká, tvOS má méně kategorií; stačí `playback` |
| `audio_service` | MPRemoteCommandCenter + MPNowPlayingInfoCenter | střední; na TV není lock screen, tlačítko play/pause ovladače může přijít i jako klávesa — možná na TV `audio_service` úplně vynechat |
| `sqlite3_flutter_libs` (pod `drift_flutter`) | bundlovaná sqlite | tvOS má systémovou `libsqlite3`; ověřit, že `sqlite3` package ji otevře bez pluginu |

Další háčky: toolchain pinuje Flutter 3.47.x, repo je na 3.44.4 → nejdřív
zvednout Flutter v repu (`flutter-tvos versions`). Engine se podepisuje
distribučním certifikátem při buildu (bez podpisu padá externí TestFlight,
ITMS-91065; CI chce `APP_STORE_CONNECT_KEY_*`). `Platform.isIOS` je na tvOS
`true` — nevětvit podle OS, ale podle `formFactor`. Žádný WebKit, clipboard,
haptika (nepotřebujeme).

Rizika: neoficiální toolchain (upgrade Flutteru = čekat na jejich release;
při zániku projektu zůstane poslední engine), vlastní údržba 3 portů pluginů,
App Review s neobvyklým enginem (jiné appky jím prošly, ale nic nezaručuje).

### 3B. Nativní tvOS appka (SwiftUI)

Tenký přehrávací klient: katalog + obsahově adresované bloby, **port parseru
skriptu do Swiftu** (CONTRACTS §2/§7; golden test
`docs/testdata/utterances.golden.json` ho ohlídá stejně jako Go a Dart),
sekvencer, `AVSpeechSynthesizer`, `AVPlayerLooper` pro smyčky, klipy,
rituál/časovač, párování, SwiftUI s focusem. Bez mikrofonu, bez nastavení
hlasu — jen přehrávání.

Výhody: oficiální SDK, žádná závislost na komunitním toolchainu, nejlepší
tvOS UX (parallax ikony, top shelf, Siri Remote). Nevýhody: třetí
implementace přehrávače (sekvencer a rituál se mohou rozjet s Dartem — golden
test hlídá jen parser), odhad 3–4 týdny proti 1–2 u 3A, každá nová funkce
dvakrát.

### Doporučení (rozhodnuto 27. 10. 2026)

Ol1n rozhodl: **volbu 3A/3B dělá spike**, ne odhad dopředu. Spike odpovídá
na technickou část (jdou porty audio pluginů?); závislost na komunitním
toolchainu jako taková je přijatelná, pokud spike projde.

Spike **3A s timeboxem 3 dny**: hello-app na tvOS simulátoru, port
`just_audio` + `audio_session`, přehrát ambient smyčku + jeden klip, `drift`
otevře databázi, `flutter_tts_tvos` vrátí seznam hlasů. Když to projde →
ADR-004 = 3A. Když se port zasekne na něčem zásadním (engine, audio session,
podpis) → ADR-004 = 3B a §8 krok 6 se nahradí nativním projektem
`tv/` v monorepu.

---

## 4. Google TV — stejný kód, stejný artefakt

Android TV je Flutterem podporovaný normální Android. Jeden AAB pro telefon
i TV, Play Console se jen přidá form faktor **Android TV** (Setup → Advanced
settings → Form factors) a projde TV review.

Manifest (`app/android/app/src/main/AndroidManifest.xml`):

```xml
<uses-feature android:name="android.software.leanback" android:required="false"/>
<uses-feature android:name="android.hardware.touchscreen" android:required="false"/>
<!-- RECORD_AUDIO implicitně vyžaduje mikrofon → TV bez mikrofonu by appku v Play neviděla -->
<uses-feature android:name="android.hardware.microphone" android:required="false"/>
<application android:banner="@drawable/tv_banner" …>
  <activity …>
    <intent-filter>
      <action android:name="android.intent.action.MAIN"/>
      <category android:name="android.intent.category.LAUNCHER"/>
      <category android:name="android.intent.category.LEANBACK_LAUNCHER"/>
    </intent-filter>
```

Banner 320×180 px (xhdpi) s názvem „Hajánek“ (z `assets/icon/icon.svg`).
minSdk 26 vyhovuje (TV chce ≤ 31). Detekce TV za běhu: `UiModeManager`
(`UI_MODE_TYPE_TELEVISION`) přes miniaturní MethodChannel v `MainActivity`
→ `formFactor` provider. Audio: `just_audio` + `audio_service` foreground
service fungují i na TV. TTS: Google TV obvykle má „Speech Recognition &
Synthesis“, ale češtinu a offline hlas ověřit (§8 krok 1); návod „doinstalujte
český hlas“ na TV nefunguje stejně jako na telefonu (bez Play Store UI pro
TTS) → text návodu pro TV zvlášť.

Play listing: TV screenshoty 1920×1080 (min. 2), TV banner 1280×720, zmínka
Android TV v popisu. Review kontroluje: celé UI landscape, D-pad bez dotyku,
viditelný focus, Back se chová předvídatelně, žádný text pod ~24 sp.

---

## 5. Společné změny: hlas rodiče na TV, hlas vypravěče

### 5.1 Párování (API)

Hlasy jsou dnes vlastněné zařízením. TV se musí stát členem téže
**domácnosti** jako telefon, který hlas nahrál. Návrh (do CONTRACTS §6, nová
migrace `0003_households`):

- `households(id, created_at)`; `devices.household_id` NOT NULL (migrace
  založí domácnost každému existujícímu zařízení). `voices.device_id`
  zůstává (kdo nahrál, kdo smí mazat), **oprávnění ke čtení** hlasu, renderů
  a klipů = shodná `household_id`.
- `POST /v1/pairings` (device = TV) → `201 {code: "483920", expires_at}`;
  6 číslic, platnost 10 min, jeden aktivní kód na zařízení, rate limit
  jako `POST /v1/devices`.
- `POST /v1/pairings/{code}/claim` (device = telefon) → TV přejde do
  domácnosti telefonu (TV tam vždy vstupuje, nikdy naopak — TV nemá hlasy);
  kód se spálí. Špatný kód = `404`, 5 pokusů/min/IP.
- `GET /v1/pairings/{code}` (device = TV) → `{status: pending|claimed}`;
  TV polluje po 3 s, dokud čeká obrazovka s kódem.
- `DELETE /v1/devices/me` z TV smaže jen TV (hlasy patří telefonu).
  `DELETE /v1/voices/{id}` smí jen `device_id` vlastník; TV hlas jen používá.
- Worker a joby se nemění. `POST …/renders` smí i TV (render pro domácnost je
  idempotentní, nic nenafoukne).

### 5.2 Párování (appka)

- **TV**: obrazovka „Hlas rodiče“ místo nahrávání ukáže kód a větu „V
  telefonu otevřete Hlas → Propojit televizi a zadejte 483 920“. Po `claimed`
  se objeví hlasy, stáhnou se klipy stejným kódem jako dnes
  (`applicationSupport/voices/{id}/`).
- **Telefon**: na obrazovce Hlas přibude „Propojit televizi“ → číselné pole
  → potvrzení „Televize propojena, hlasy se tam stáhnou samy“.
- Hlas pro přehrávání je dnes jeden pro celou appku; na TV to zůstává.

### 5.3 Hlas vypravěče (plán B, fáze TV-3)

Pokud krok 1 ukáže, že `cs-CZ` TTS na TV chybí nebo je nepoužitelný:
jeden sdílený hlas `narrator-cs` renderovaný na Sparku stejnou pipeline jako
klony (render → klipy AAC −23 LUFS), ale **bez auth a publikovaný na Pages**
jako obsahově adresované bloby katalogu (`catalog/blobs/{sha256}.m4a`,
nová sekce `narrators` v catalog.json, schema 3). Odhad objemu: 10 pohádek ×
~10 min × 64 kbps ≈ 50 MB — stahovat podle potřeby, ne do bundlu. Podmínka z
ADR-003 platí dvojnásob: engine s **komerční licencí** (XTTS-v2 nelze;
kandidáti dle ADR-001, nebo Piper `cs_CZ` MIT jako nouzová kvalita). Přínos
i pro telefony se špatným systémovým hlasem. Rozhodnutí Ol1na (§10).

---

## 6. UX pro TV (10-foot UI)

- Jedna sada obrazovek, dvě rozložení: `formFactor == tv` přepíná na TV
  varianty Domů / detail / přehrávač / nastavení / hlas. Mixér a jukebox
  zjednodušit na výběr presetů (3 vrstvy posuvníky dálkovým ovladačem jsou
  utrpení). Obrazovka nahrávání na TV neexistuje.
- **Focus-first**: `FocusTraversalGroup`, viditelný focus (zvětšení + okraj),
  mřížka pohádek s předvídatelným směrovým pohybem (Flutter bere geometricky
  nejbližší widget → pro mřížku stačí, pro složitější rozložení zvážit balíček
  `dpad`). Siri Remote: swipe = šipky, click = select, Menu/Back = zpět;
  na kořenové obrazovce Menu **ukončí appku** (tvOS HIG, nebránit tomu).
  Tlačítko play/pause ovladače → přehrávač (na Androidu `MEDIA_BUTTON`,
  na tvOS klávesa / `MPRemoteCommandCenter` podle portu).
- **Noční obraz**: po startu přehrávání téměř černá obrazovka, jen název
  pohádky a sekce (Úvod / Vstup / Příběh / Dojezd) a jemný stav časovače,
  bez animací. Po 10 s bez ovladače zmizí i to. Držet obrazovku vzhůru
  (`wakelock_plus`, tvOS `isIdleTimerDisabled`) **jen během přehrávání**;
  po dohrání/časovači wakelock pustit, aby TV sama usnula — TV ve standby
  neposílá zvuk, takže „zvuk dál a obraz pryč“ nejde, obraz musí být tmavý.
- Hlasitost řídí ovladač TV; posuvník hlas↔podkres zůstává v nastavení.
- Textové vstupy (oslovení dítěte) jdou přes klávesnici ovladače, OK.
- Všechny české texty dál v `core/strings.dart`; TV varianty vět (návod bez
  Play Store, párování) tam přidat, ne inline.

---

## 7. Release a infrastruktura

- **Android**: beze změny workflow; stejný AAB. Jednou v Play Console přidat
  form faktor Android TV, TV grafiku a screenshoty. Firebase dál přeskočit.
- **tvOS (cesta 3A)**: nový `release-tvos.yml` odvozený z golden
  `../Distribution/workflows/release-ios.yml` (macOS runner, instalace
  `flutter-tvos`, podpis enginu, `xcodebuild` tvOS scheme, TestFlight).
  App Store Connect: k existující appce **přidat platformu tvOS** (stejný
  bundle ID `com.ol1n.hajanek`, jeden záznam, jeden listing). Nový App Store
  provisioning profile pro tvOS → `Distribution/Apple/Hajanek/`;
  `setup-gh-secrets.sh` rozšířit o druhý profil. Grafika: vrstvená ikona
  1280×768 (parallax), top shelf 1920×720, screenshoty 1920×1080.
- **tvOS (cesta 3B)**: samostatný Xcode projekt `tv/`, stejný workflow bez
  Flutteru; `make test` navíc spustí Swift golden test parseru.
- Verze: TV sdílí `version` v `pubspec.yaml` a tag `v*` staví vše.
- Testovací hardware: Apple TV 4K (tvOS 17+) a Google TV (Chromecast with
  Google TV nebo TV s Android TV 12+); pro vývoj tvOS simulátor a Android TV
  AVD (1080p). Bez reálného Google TV se neověří dostupnost TTS.

---

## 8. Kroky pro Opus (pořadí)

1. **Změřit TTS na TV** (½ dne, nerozhoduje nic, dá data pro §10):
   jednoduchá appka / skript vypíše `getVoices` na tvOS simulátoru a
   Android TV AVD, a Ol1n totéž pustí na reálných krabičkách (simulátory
   nemusí mít stejné hlasy). Výstup: tabulka hlasů `cs` × platforma ×
   kvalita × offline do ADR-004.
2. **Spike `flutter-tvos`** (3 dny timebox, viz §3 Doporučení). Výstup:
   `docs/adr/ADR-004-tv-platform.md` s rozhodnutím 3A/3B a seznamem portů.
   Pokud 3A: porty jako samostatné balíčky `app/packages/just_audio_tvos`
   atd. (federované pluginy, `tvos:` v pubspec), pokus o PR do
   `fluttertv/plugins`.
3. **`formFactor` provider + TV rozložení** (§6) nejdřív na Android TV AVD:
   Domů, detail, přehrávač s nočním obrazem, nastavení, obrazovka Hlas bez
   nahrávání. Widget testy s `formFactor = tv` a simulací šipek.
4. **Android TV manifest + banner** (§4), ověřit na AVD leanback launcher,
   D-pad, Back, zhasnutí a probuzení; `flutter build appbundle` beze změny CI.
5. **Párování**: migrace `0003_households`, sqlc dotazy, 3 endpointy, testy
   (cizí kód = 404, expirace, rate limit, TV nesmí mazat hlas), CONTRACTS §6
   + §8 bod 5; appka: obrazovka kódu na TV, „Propojit televizi“ v telefonu;
   end-to-end: telefon nahraje → TV spáruje → klipy na TV → přehrání.
6. **Apple TV build** podle ADR-004 (3A: zvednout Flutter, porty, tvOS target
   v Xcode, `release-tvos.yml`; 3B: projekt `tv/`, Swift parser + golden
   test, přehrávač, párování).
7. **Store**: Play form faktor TV + grafika; App Store Connect platforma
   tvOS + profil + secrets; interní testy; 1 týden s Alexkem u televize.
8. **TV-3 hlas vypravěče** jen po rozhodnutí v §10 a výběru licencovaného
   enginu: `forge narrator` render → bloby na Pages, catalog schema 3,
   `NarratorVoiceSource` (klipy bez auth) s fallbackem na systémový hlas.

Při každém kroku dál platí z `app/README.md`: `flutter analyze`, `flutter
test` z `app/` nad celým repem, `tools/sync_app_bundle.sh` po změně obsahu,
release vždy `INCLUDE_DRAFTS=false`.

---

## 9. Co ověřit na zařízení (TV)

- Reálný seznam hlasů `cs` na Apple TV a Google TV; že `whisper` (pitch 0.95,
  pomaleji) na TV hlasu nezní divně.
- 20 minut přehrávání: spořič / standby se nespustí při wakelocku a spustí
  po jeho uvolnění; TV ve standby = ticho (očekávané, ne chyba).
- Siri Remote: swipe po mřížce, Menu na kořeni ukončí, play/pause v půlce
  věty (pauza uprostřed promluvy ji čte znovu od začátku — na TV stejně).
- Android TV: Back během přehrávání se vrátí na detail, zvuk běží dál;
  foreground service bez notifikační lišty se chová klidně.
- Párování: expirace kódu, dvě TV v jedné domácnosti, smazání hlasu
  v telefonu smaže klipy na TV při příštím pollingu.
- Čitelnost nočního obrazu z 3 m a že opravdu nesvítí (OLED i LCD).
- Ogg Opus smyčky na tvOS přes portovaný `just_audio` (dnes ověřeno jen iOS
  26 simulátor, `integration_test/codec_probe_test.dart`).

---

## 10. Otevřené otázky pro Ol1na

- ~~Apple TV cestou 3A nebo 3B~~ — rozhodnuto 27. 10. 2026: rozhodne spike
  (§3 Doporučení). Výsledek zapsat do ADR-004.
- Pořadí: Google TV první (levnější, stejný kód), nebo Apple TV (doma je
  Apple TV?). Plán počítá Google TV první.
- Když na TV chybí český TTS: dělat **hlas vypravěče** (TV-3, vyžaduje
  licencovaný engine a ~50 MB stahování), nebo na TV nabízet jen hlas rodiče
  a bez něj pohádku „jen s podkresem“?
- Má TV umět i jukebox a mixér, nebo jen pohádky + rituál (menší UI, méně
  focusu)?
- Jedna domácnost = jeden telefon a N televizí stačí? Sdílení hlasu mezi dvěma
  telefony (babička) je fáze 3 v `HAJANEK_PLAN.md` a párování ho umožní
  skoro zadarmo (telefon → telefon stejným kódem).

---

## 11. Zdroje

- flutter-tvos: https://github.com/fluttertv/flutter-tvos, pluginy
  https://github.com/fluttertv/plugins (stav k 27. 10. 2026: 25 balíčků,
  bez `just_audio`/`audio_service`/`audio_session`)
- Android TV: https://developer.android.com/training/tv/start/start,
  publikace a checklist https://developer.android.com/training/tv/publishing/checklist,
  distribuce https://developer.android.com/training/tv/publishing/distribute
- tvOS řeč: `AVSpeechSynthesisVoice.speechVoices()`
  https://developer.apple.com/documentation/avfaudio/avspeechsynthesisvoice
- Flutter D-pad: https://pub.dev/packages/dpad
