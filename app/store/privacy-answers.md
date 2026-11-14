# Odpovědi pro App Privacy a Data safety

Platí pro první build s anonymními statistikami používání
(`docs/telemetry.md`, appka posílá jen s `TELEMETRY_KEY`). **Vyplnit, až
bude venku nová politika** (`docs/privacy.html` na GitHub Pages, a stejné
znění i v kopii v `hajanek-content`, dokud na ni obchody odkazují), **a před
odesláním toho buildu ke kontrole.** Odpovědi sedí s
`ios/Runner/PrivacyInfo.xcprivacy`. Tvrzení o formulářích ověř proti
aktuálnímu znění v konzolích.

Build bez klíče nic neposílá; dokud žádný takový build neodešel, platí
dosavadní „Data Not Collected“ / „nesbírá data“.

Hlas rodiče (`VOICE_CLONING`) je ve store buildu vypnutý. Až se zapne,
přibude nahrávka hlasu (Audio data) podle `docs/IAP_PLAN.md`; to tyto
odpovědi nepokrývají.

## App Store Connect → App Privacy

**Privacy Policy URL:** beze změny (stránka `privacy.html` na GitHub Pages).

**Do you or your third-party partners collect data from this app?** **Yes.**

**Data types collected** (zaškrtnout přesně tyto):

| Kategorie → typ | Linked to the user? | Used for tracking? | Purpose |
|---|---|---|---|
| Usage Data → **Product Interaction** | **No** | **No** | **Analytics** |
| Diagnostics → **Performance Data** | **No** | **No** | **Analytics** |
| Location → **Coarse Location** | **No** | **No** | **Analytics** |

Proč:

- *Product Interaction*: spuštění, obrazovky a čas na nich, spuštění a konec
  pohádky nebo jukeboxu, nastavený časovač, první použití funkcí, zobrazené
  chyby.
- *Performance Data*: deklarováno podle společné šablony měření. Hajánek
  dnes časy načítání neposílá; kdo chce deklaraci přesně podle dnešního
  slovníku, odškrtne tento řádek a odebere
  `NSPrivacyCollectedDataTypePerformanceData` z `PrivacyInfo.xcprivacy`.
- *Coarse Location*: vlastní příjemce vývojáře určí z IP adresy spojení
  zemi, uloží jen ji a IP neukládá. Kdyby se země na příjemci vypnula,
  odškrtnout tento řádek a odebrat `NSPrivacyCollectedDataTypeCoarseLocation`
  z manifestu.

Nesbírá se (nechat nezaškrtnuté): Contact Info, Health & Fitness, Financial
Info, Precise Location, Sensitive Info, Contacts, User Content (nahrávka
hlasu jen se zapnutým `VOICE_CLONING`, viz výše), Browsing History, Search
History, Identifiers (žádné User ID ani Device ID: ID relace je náhodné, žije
jen v paměti a znovu se nepoužije), Purchases, Other Usage Data, Crash Data,
Other Diagnostic Data, Other Data.

**Linked to the user: No** u všech typů: žádný účet, žádný identifikátor,
dvě relace nejde spojit.

**Tracking: No.** Nic se nespojuje s daty jiných firem, nic nejde
zprostředkovatelům dat, žádná reklama. ATT dotaz není potřeba
(`NSPrivacyTracking` je `false`).

## Google Play Console → Data safety

Statistiky jdou jen na vlastní server vývojáře v EU (Česko), žádná třetí
strana je nedostane, takže jde o *collected*, ne *shared*.

- Does your app collect or share any of the required user data types?
  **Yes.**
- Is all of the user data collected by your app encrypted in transit?
  **Yes** (klient statistik odmítne jiný než `https` host).
- Do you provide a way for users to request that their data is deleted?
  **No.** Appka nemá účet. Statistiky nenesou identifikátor, takže záznam
  nejde dohledat k člověku; vypínač v nastavení smaže neodeslané záznamy
  v zařízení a po 12 měsících se mažou. (Mazání na žádost je povinné jen pro
  appky s účtem.)
- Data types, vše **Collected**, **not shared**:

| Data type | Purpose | Ephemeral? | Required or optional |
|---|---|---|---|
| App activity → **App interactions** | **Analytics** | No | **Optional** (vypínač „Anonymní statistiky používání“ v nastavení) |
| Location → **Approximate location** | **Analytics** | No | **Optional** (týž vypínač); země určená příjemcem z IP, IP se neukládá |

Nesbírá se: přesná poloha, osobní údaje (oslovení dítěte nikdy neopustí
zařízení), finanční údaje, zdraví, zprávy, fotky a videa, audio (bez
`VOICE_CLONING`), soubory, kalendář, kontakty, historie prohlížení, ID
zařízení ani jiná ID, crash logy, diagnostika.

**Advertising ID: No.**

**Target audience and content:** rodiče, věk 18+. Nevolit věkovou skupinu
do 13 let: appka by spadla pod Families a politika slibuje, že tam není.
