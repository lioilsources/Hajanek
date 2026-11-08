# Plán: Hajánek ve více jazycích

> Stav 8. 11. 2026: hotovo ve verzi 1.1.0 (forge, appka, 10 pohádek × 9 jazyků).
> Navazuje na plán §2 (fáze 3), CONTRACTS §2–§3.

## Rozhodnutí

- **Jazyky první vlny:** `cs` (zdroj), `en`, `de`, `es`, `fr`, `pt-BR`,
  `it`, `pl`, `sk`. Druhá vlna (nl, sv, ja, ko …) jde stejnou cestou.
- **Kontrola překladů:** jen LLM. Rodilý mluvčí není podmínkou vydání.
  Proto deterministický judge běží pro každý jazyk zvlášť (zakázaná slova,
  tempo) a LLM-judge hodnotí v cílovém jazyce.
- **Postava a značka:** všude **Hajánek**, bez lokálního Sandmana.
  V obchodech a v textu, kde se háček špatně čte, je `Hajanek`.

## Obsah

Překlad není doslovný. Je to **adaptace**: stejné sekce, stejné pauzy,
stejná zjemnění, krátké věty a přirozený dětský jazyk cílové země.

```
content/
  scripts/{id}.10.md                 # cs, zdroj
  i18n/{lang}/scripts/{id}.10.md     # adaptace
  i18n/{lang}/forbidden_words.txt    # zakázané kmeny pro jazyk
  i18n/{lang}/titles.json            # názvy ambientů a presetů
```

- Front matter: stejné `id`, přeložený `title`, nové `lang: en` a
  `source_lang: cs`. `status` začíná na `draft` a po LLM-judge se mění na
  `reviewed`.
- **Názvy pohádek:** ustálené tam, kde existují (Little Red Riding Hood,
  Rotkäppchen, Caperucita Roja…). Pozor: Zlatovláska **není** Goldilocks.
  České pohádky (Budulínek, Smolíček, Dlouhý Široký…) mají popisný název.
- **Refrény** (judge je v daném jazyce kontroluje):

| lang | refrén v příběhu | konec |
|---|---|---|
| cs | A všechno je v pořádku. | A Hajánek už jde kolem. / Dobrou noc, {{osloveni\|broučku}}. |
| en | And everything is all right. | And Hajánek is already passing by. / Good night, {{osloveni\|little one}}. |
| de | Und alles ist gut. | Und Hajánek kommt schon vorbei. / Gute Nacht, {{osloveni\|mein Schatz}}. |
| es | Y todo está bien. | Y Hajánek ya pasa por aquí. / Buenas noches, {{osloveni\|cariño}}. |
| fr | Et tout va bien. | Et Hajánek passe déjà tout près. / Bonne nuit, {{osloveni\|mon trésor}}. |
| pt-BR | E está tudo bem. | E o Hajánek já vem passando. / Boa noite, {{osloveni\|meu bem}}. |
| it | E va tutto bene. | E Hajánek sta già passando. / Buonanotte, {{osloveni\|tesoro}}. |
| pl | I wszystko jest dobrze. | A Hajánek już przechodzi obok. / Dobranoc, {{osloveni\|kochanie}}. |
| sk | A všetko je v poriadku. | A Hajánek už ide okolo. / Dobrú noc, {{osloveni\|zlatíčko}}. |

- `{{osloveni}}`: rodič zadává oslovení ve tvaru, jak ho chce slyšet. Pátý
  pád je jen česká a slovenská nápověda v UI.

## Katalog: schema zůstává 2

Appka 1.0.0 v obchodech zná jen `schema: 2` a jeden `catalog.json`. Proto:

- `catalog.json` zůstává český, beze změny. Starým appkám se nic nerozbije.
- Každý další jazyk má vlastní katalog `i18n/{lang}/catalog.json` se
  `schema: 2`, novým polem `lang` a skripty `i18n/{lang}/scripts/…`.
- Ambient soubory jsou sdílené (`ambient/…`). V jazykovém katalogu se liší
  jen `title` u ambientů a presetů.
- `forge publish --lang L` (nebo `--all-langs`) staví katalog jazyka.
  `version` se vede pro každý jazyk zvlášť.

## Appka

1. **UI texty:** `S` přejde na `flutter gen-l10n` (ARB pro 9 jazyků,
   `cs` je šablona). Zhruba 125 řetězců.
2. **Jazyk obsahu:** podle jazyka zařízení s fallbackem na `en`. Rodič ho
   může v Nastavení přepnout (česká rodina v zahraničí). Uloží se v nastavení.
3. **Katalog:** bundle obsahuje všechny jazyky (texty jsou malé). Sync stahuje
   katalog zvoleného jazyka. `CatalogRepository` dostane `lang`.
4. **Systémový hlas:** `pickCzechVoice` se zobecní na `pickVoice(lang)`, se
   stejným řazením kvality a offline. Nápověda „Telefon nemá český hlas“
   bude „…nemá hlas pro {jazyk}“.
5. **Hlas rodiče:** zůstává `cs` za přepínačem `VOICE_CLONING`. Engine pro
   další jazyky se vybírá spolu s komerčním enginem (IAP_PLAN).

## forge

- `judge`: zakázaná slova z `i18n/{lang}/forbidden_words.txt`,
  `wpm` pro jazyk v `config.yaml` (`judge.wpm_by_lang`), délka věty ≤ 18 slov
  zůstává (pro `de` ≤ 16, kvůli složeninám), `?` a `¿` jsou zakázané.
  Jazyk judge pozná z `lang` ve front matter. `wpm` je zatím všude 95, dokud
  sonda nezměří tempo systémových hlasů v jednotlivých jazycích.
  LLM-judge dostane checklist s jazykem a refrény jako parametry.
- `translate --lang L --tale ID`: české skripty → LLM adaptace → judge →
  `i18n/{lang}/scripts/`. Jen dávka, žádné noční běhy.

## Obchody

- **App Store:** lokalizace `en-US`, `en-GB`, `de-DE`, `es-ES`, `es-MX`,
  `fr-FR`, `pt-BR`, `it`, `pl`, `sk` přes API (klíč App Manager). Název
  „Hajánek“, podtitul a popis v jazyce, screenshoty z harnessu s `locale`.
- **Google Play:** stejné texty v `app/store/play/{lang}/`, vkládá Ol1n.
- Anglický název přestane být „Czech Bedtime Tales“ a bude „Hajánek: Bedtime
  Stories“.

## Pořadí

1. Kontrakty: tento plán do CONTRACTS §2–§3 (pole `lang`, cesty `i18n/`).
2. Adaptace 10 pohádek × 8 jazyků (agenti, každý jazyk zvlášť) a LLM-judge
   v jazyce. Běží souběžně s kroky 3–4.
3. forge: `judge --lang`, `publish --lang`, testy.
4. Appka: gen-l10n, volba jazyka, `pickVoice(lang)`, katalog podle jazyka,
   testy, screenshoty pro každý jazyk.
5. Publikace katalogů, vydání 1.1.0, lokalizace v obchodech.

## Rizika

- **Bez rodilé kontroly** může projít nepřirozená formulace. Hodnocení v
  obchodech sledovat po jazycích. Nejhorší jazyk dostane rodilou kontrolu.
- **Systémové hlasy:** kvalita se liší podle jazyka i zařízení. Sonda
  `tts_probe_test` se pustí pro každý jazyk na iOS simulátoru a Android
  emulátoru.
- **Délka:** tempo řeči a délka slov se v jazycích liší. Judge hlídá ±15 %
  pro každý jazyk.
