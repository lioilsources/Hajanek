# Plán: placený „Můj hlas“ (IAP 0,99 $)

> Stav 6. 11. 2026: připraveno na později, nic z toho není v kódu. Appka
> jde do storů zdarma. Klonování je za přepínačem `VOICE_CLONING`
> (výchozí `false`) a se zapnutým přepínačem je to beta zdarma.
> Navazuje na plán §5, ADR-003 a CONTRACTS §6.

## Předpoklady (blokující)

1. **Komerční klonovací engine.** XTTS-v2 má nekomerční licenci CPML,
   kterou nejde koupit, a licence chatterbox-cs není ověřená (ADR-003).
   Placený hlas na nich prodávat nejde. Kandidáti z ADR-001: dots.tts-soar,
   MOSS-TTS (Apache-2.0). Hlasy z bety se po výměně enginu přegenerují.
2. **Kapacita Sparku.** Jeden GPU v nočním okně. Před spuštěním placené
   verze změřit, kolik hlasů za noc zvládne, a v appce ukazovat pořadí ve
   frontě.

## Produkt

- Jeden non-consumable produkt pro iOS i Android, `hajanek.my_voice`,
  0,99 USD (nejnižší cenový stupeň; v ČR kolem 25 Kč podle aktuální tabulky obchodu).
- Nákup patří domácnosti. Hlasy sdílí spárovaná TV, ale TV sama nekupuje.
- „Celá knihovna“ z plánu §5 je samostatný produkt, tady se neřeší.
- Kolik hlasů nákup odemyká: navrhuji 2 (máma a táta), stejně jako plán §5
  („možnost 2. hlasu v rodině“). Rozhodne Ol1n.

## Tok

1. **Rodič klepne na „Nahrát můj hlas“.** Bez nároku appka ukáže cenu a
   koupí `hajanek.my_voice` (knihovna `in_app_purchase`; RevenueCat jen tehdy,
   když nechceme psát ověřování sami).
2. **Appka pošle účtenku do `hajanek-api`.** Nový endpoint
   `POST /v1/entitlements` s `{platform, receipt | purchase_token}`. API ji
   ověří u Apple (App Store Server API) nebo u Google (Play Developer API,
   `purchases.products.get`). Pak zapíše nárok k domácnosti a nákup potvrdí
   (`acknowledge`). Nepotvrzený nákup Google do 3 dnů sám vrátí.
3. **`POST /v1/voices` vyžaduje nárok.** Bez nároku vrátí `402`.
4. **Obnova nákupu:** tlačítko „Obnovit nákup“ (Apple to vyžaduje). Na novém
   telefonu se nárok zapíše k nové domácnosti.

## Vracení peněz a selhání

Refund dělá obchod, appka ho sama vrátit nemůže. Strategie: **za
nepovedený hlas rodič neplatí podruhé**.

- **Hlas skončí `failed`** (vyčerpané pokusy, špatná nahrávka): nárok
  zůstává. Rodič nahraje znovu a nic dalšího neplatí. Appka napíše proč a co
  zkusit.
- **Opakovaně `failed`** (např. 3×): appka nabídne „Požádat o vrácení
  peněz“. Na iOS je to `showManageSubscriptions`/`beginRefundRequest` (StoreKit 2),
  na Androidu odkaz na Google Play. Tím chceme zabránit, aby rodič místo toho
  dal 1★.
- **Refund schválený obchodem:** API poslouchá serverové notifikace, tedy
  App Store Server Notifications v2 (`REFUND`) a Google RTDN
  (`voidedPurchases`). Nárok se zneplatní. Hotové hlasy **nemažeme** (dítě
  si na hlas zvyklo). Jen nejdou vytvářet nové.
- **Výpadek během generování** (Spark, audio služba, síť): už to řeší
  fronta jobů, tedy lease, opakování a reaper. Chybějící klip čte systémový
  hlas, takže pohádka vždy dohraje. Nárok tím nepropadá.
- **Hlas smazaný rodičem:** nárok zůstává a slot se uvolní.

## Notifikace

Klon trvá hodiny (noční GPU okno) a appka se dnes ptá serveru jen v popředí.

- Push „Tvůj hlas je hotový“: APNs a FCM. API pošle push, když hlas přejde
  do `ready` a stáhne se první pohádka. Token zařízení se registruje
  k `device`.
- Push i při `failed` s krátkým důvodem.
- Plán zakazuje notifikace pro dítě. Tyhle jsou pro rodiče, jednorázové,
  a appka si o povolení řekne až po odeslání nahrávky.

## Store a právo

- Popis v obchodě, zásady soukromí (`docs/PRIVACY.md`): doplnit nákup
  a nárok.
- Apple Kids kategorie: nákup musí být za rodičovskou bránou (parental gate).
- Google Data safety: audio (hlas) se sbírá, šifruje a dá se smazat.

## Testy

- API: ověření účtenky (mock Apple a Google), `402` bez nároku, refund
  zneplatní nárok, `failed` nárok zachová.
- App: tok nákupu s fake storem, obnova, rodičovská brána.
- Ručně: sandbox účet App Store a licencovaný tester v Play Console.
