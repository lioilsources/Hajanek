# Hajánek: zásady ochrany soukromí

Platné od 6. 11. 2026.

Hajánek je aplikace s pohádkami a zvuky na usínání pro děti. Je zdarma, bez
reklam, bez účtu a bez sledování.

**Provozovatel:** {{PROVOZOVATEL}}, kontakt {{EMAIL}}.

## Co appka nesbírá

- Žádný účet, jméno, e-mail ani telefonní číslo.
- Žádnou reklamu, analytiku, sledování ani identifikátory pro reklamu.
- Nic o dítěti. Dítě appku jen poslouchá.

## Co zůstává jen v telefonu

Oblíbené pohádky, vlastní mixy zvuků a nastavení (časovač, hlasitost,
rituál). Smažou se s odinstalováním appky.

## Stahování pohádek

Appka si stahuje katalog pohádek a zvuky z GitHub Pages
(`lioilsources.github.io`). GitHub přitom vidí IP adresu zařízení, jako
u každé webové stránky. Zásady GitHubu:
<https://docs.github.com/site-policy/privacy-policies/github-general-privacy-statement>.

## Hlas, který čte pohádky

Pohádky čte hlas, který je součástí telefonu nebo televize (iOS, Android,
Google TV, Apple TV). Text pohádky zpracuje řečový engine zařízení. Podle
nastavení zařízení ho může poslat i výrobci (Apple, Google); tím se řídí
jejich zásady, ne naše.

## Hlas rodiče (zkušební verze)

Tato část platí jen tehdy, když si rodič v appce sám nahraje svůj hlas.
Funkce je zkušební a zdarma.

- **Co se odesílá:** nahrávka hlasu (5–30 s), jméno hlasu, které rodič
  zadá, a text souhlasu, který rodič nahlas přečte. Appka si při tom vytvoří
  anonymní identifikátor zařízení. Ten se uloží do zabezpečeného úložiště
  telefonu a není svázaný s žádnou osobou.
- **K čemu:** jen k vytvoření hlasu, kterým appka čte pohádky tomuto
  zařízení. Případně také spárované televizi. Nahrávka ani hlas se nepoužijí
  k ničemu jinému. Neprodáváme je, nesdílíme a netrénujeme na nich modely.
- **Kde:** na serverech provozovatele ({{UMISTENI}}). Hlas se vytváří na vlastním
  počítači provozovatele, ne u cizí cloudové služby. Spojení jde přes síť
  Cloudflare (šifrované HTTPS).
- **Jak dlouho:** dokud hlas rodič nesmaže. Tlačítkem Smazat v appce se
  nahrávka i hotové části hlasu hned smažou ze serveru. Do několika hodin
  zmizí i z počítače, kde se hlas vytváří, a ze spárovaných televizí.
  Technické záznamy serveru (IP adresa, čas požadavku) se uchovávají
  {{LOGY_DNI}} dní kvůli provozu a ochraně před zneužitím.
- **Souhlas:** nahrávat smí jen ten, komu hlas patří. Souhlas potvrzuje
  zaškrtnutím a přečtením souhlasné věty. Souhlas lze kdykoli odvolat
  smazáním hlasu.

## Párování s televizí

Když rodič propojí televizi s telefonem šestimístným kódem, uvidí televize
hlasy z telefonu a bude jimi číst. Kód platí 10 minut. Hlas smazaný
v telefonu zmizí i z televize.

## Vaše práva

Podle GDPR máte právo na přístup k údajům, jejich opravu, výmaz, omezení
zpracování a přenositelnost. Máte také právo podat stížnost u Úřadu pro
ochranu osobních údajů (<https://uoou.gov.cz>). Hlas smažete přímo v appce.
Kvůli ostatnímu napište na {{EMAIL}}. Protože nemáme účty, uveďte prosím
přibližný čas nahrání a jméno hlasu.

## Změny

Když se zásady změní, změní se datum nahoře. Placené funkce, pokud přibudou,
budou popsané tady dřív, než se v appce objeví.
