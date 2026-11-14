# Hajánek: zásady ochrany soukromí

Platné od 14. 11. 2026.

Hajánek je aplikace s pohádkami a zvuky na usínání. Je určená rodičům,
kteří ji pouštějí dětem. Je zdarma, bez reklam a bez účtu. Posílá anonymní
statistiky používání, které se dají kdykoli vypnout. Webová verze těchto
zásad: `docs/privacy.html`.

## Anonymní statistiky používání

- **Co se posílá:** appka se otevřela nebo šla do pozadí (a jestli přitom
  hrála pohádka nebo zvuky), která obrazovka se zobrazila a jak dlouho, která
  pohádka se spustila (hlas, rituál, časovač) a jak přehrávání skončilo
  (dohrálo, zastavil ho rodič nebo časovač, kolik procent zaznělo, kolik
  minut to trvalo), jaký časovač se nastavil, první použití funkcí (jukebox,
  oblíbené, uložený mix, časovač…) a zobrazené chyby. K tomu verze appky,
  platforma, jazyk appky, telefon nebo televize a dvě hrubá pásma (kolikrát
  se appka spustila, před kolika dny začalo měření). Úplný seznam:
  [`docs/telemetry.md`](telemetry.md).
- **Proč:** abychom viděli, kolik lidí se dostane k první dohrané pohádce,
  jestli se pohádky dohrávají a kde appka zlobí.
- **Bez identifikátorů:** žádné jméno, e-mail, účet, identifikátor zařízení
  ani reklamní identifikátor, žádný přesný model zařízení ani text, který do
  appky napíšete. Relace má náhodné číslo, které žije jen v paměti; dvě
  relace nejde spojit.
- **Nic o dítěti, nic o nahrávkách:** oslovení dítěte se neposílá. U hlasu
  rodiče se zaznamená jen to, že se funkce použila, nikdy nahrávka, její
  délka, jméno hlasu ani text souhlasu.
- **Kdo je dostává:** vývojář na vlastním serveru v EU (Česko). Nikdo další,
  žádná analytická firma ani jiná třetí strana. IP adresa se neukládá, slouží
  jen k určení země; země je jediný údaj o poloze.
- **Jak dlouho:** 12 měsíců. Offline čeká v zařízení nejvýš 500 záznamů.
- **Jak je vypnout:** Nastavení → Anonymní statistiky používání. Čekající
  záznamy se hned smažou a nic dalšího se neposílá.

## Co appka nesbírá

- Žádný účet, jméno, e-mail ani telefonní číslo.
- Žádná reklama, analytika třetích stran, sledování ani reklamní
  identifikátory.
- Nic o dítěti. Dítě appku jen poslouchá.
- Appka nepoužívá mikrofon.
- Přesnou polohu (jen zemi, viz výše).

## Co zůstává jen v zařízení

Oblíbené pohádky, vlastní mixy zvuků a nastavení (časovač, hlasitost,
rituál), a pro statistiky den začátku měření, počítadlo spuštění a použité
funkce. Nikam se neposílají a smažou se s odinstalováním appky.

## Stahování nových pohádek

Appka si občas stáhne katalog pohádek ze služby GitHub Pages
(`lioilsources.github.io`). Neposílá při tom nic o sobě ani o vás (statistiky
jdou zvlášť, viz výše). GitHub
ale vidí IP adresu zařízení, stejně jako u každé webové stránky. Zásady
GitHubu:
<https://docs.github.com/site-policy/privacy-policies/github-general-privacy-statement>.

## Hlas, který čte pohádky

Pohádky čte řečový engine, který je součástí telefonu nebo televize. Řídí ho
výrobce zařízení (Apple, Google) a platí pro něj jeho zásady. Podle
nastavení zařízení může text pohádky zpracovat i online.

## Děti

Hajánek ovládá rodič; dítě jen poslouchá. Appka není zařazená do kategorie
Kids v App Store ani do programu Families v Google Play. Statistiky
neobsahují nic, co by identifikovalo člověka.

## Kontakt

Dotazy a žádosti podle GDPR posílejte na business@olin.now, přes
<https://github.com/lioilsources/Hajanek/issues> nebo přes
<https://olin.now/hajanek>.

## Změny

Každá nová položka ve statistikách i funkce, která by sbírala jiná data
(například zkušební funkce s hlasem rodiče), se tu doplní dřív, než se
v appce objeví, a změní se datum nahoře.

<!-- Oddíl pro hlas rodiče (VOICE_CLONING) je v historii tohoto souboru,
     commit z PR #5; vrátit ho před zapnutím bety. -->
