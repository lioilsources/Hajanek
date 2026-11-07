# Podklady pro obchody

Hajánek 1.0.0 (7. 11. 2026): zdarma, bez IAP, jen hlas zařízení
(`VOICE_CLONING` vypnuté), 2 pohádky (Karkulka, Zlatovláska; drafty skryté).

Screenshoty se renderují z widgetů appky ve stavu, jaký má store build:

```sh
cd app
for d in iphone ipad android; do
  SCREENSHOT_STORE=1 SCREENSHOT_DEVICE=$d SCREENSHOT_DIR=/tmp/shots/$d \
    flutter test test/screenshots_test.dart
done
```

Grafiky (TV banner, feature graphic): `tools/render_tv_banner.sh`.

Zásady soukromí: `docs/PRIVACY.md`, publikované jako
<https://lioilsources.github.io/hajanek-content/privacy.html>
(soubor `privacy.html` v repu `hajanek-content`).

## App Store (`appstore/`)

Vyplněno přes App Store Connect API: čeština jako hlavní jazyk a angličtina,
název, podtitul, popis, klíčová slova, propagační text, podpora a marketing
`https://olin.now/hajanek`, zásady soukromí, kategorie Lifestyle a Books,
věk 4+, cena zdarma, všechny země, screenshoty (iPhone 6,9" a iPad 13"),
build 1.0.0 (5).

Klíčová slova cs: `pohádky,usínání,spánek,ukolébavka,děti,dobrou noc,uspávání,meditace,bílý šum,moře,déšť`

Zbývá ve webovém rozhraní:

- App Privacy: „Data Not Collected“.
- App Review Information: kontakt (jméno, telefon, e-mail), bez přihlášení.
- Content Rights: appka obsahuje obsah třetích stran (přírodní zvuky CC0),
  práva k němu máme.
- Odeslat ke kontrole.

## Google Play (`play/`)

- Krátký popis (max. 80 znaků): `Klidné pohádky na dobrou noc, přírodní zvuky a ukolébavky. Bez reklam.`
- Dlouhý popis: `full_description_cs.txt`.
- Telefon: `phone/` (1080×2160). Android TV: `tv/` (1920×1080) a banner
  `tv/banner_1280x720.png` o úroveň výš.
- Feature graphic: `feature_1024x500.png`. Ikona 512×512: `icon_512.png`.
- AAB: GitHub release `v1.0.0`, soubor `app-release.aab`.
- Kategorie: Životní styl (nebo Rodičovství). Cílová skupina: rodiče; appka
  není určená k tomu, aby ji ovládaly děti samy. Pokud se zvolí věk do 13 let,
  platí zásady Families: bez reklam a analytiky to splňujeme.
- Data safety: appka **nesbírá ani nesdílí žádná data**, šifrování
  přenosu ano (HTTPS), účet ne.
- Oprávnění: `RECORD_AUDIO` je v manifestu kvůli funkci hlasu rodiče, která
  je ve 1.0.0 vypnutá; appka o mikrofon nikdy nežádá.
- Hodnocení obsahu (IARC): bez násilí, strachu, vulgarit, nákupů a interakce
  uživatelů, tedy PEGI 3.
