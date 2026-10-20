# ADR-000: Výchozí odpovědi na otevřené otázky (plán §8)

- **Stav:** navrženo (20. 10. 2026), čeká na potvrzení Ol1nem
- **Kontext:** Plán §8 nechává otevřené otázky. Implementace MVP nemůže
  čekat, takže každá dostala vratnou výchozí odpověď. Změna kterékoli z nich
  je levná, pokud se udělá před nočním generováním katalogu.

| Otázka | Výchozí rozhodnutí | Proč / jak vrátit |
|---|---|---|
| Jméno dítěte ve skriptu v MVP? | **Ne.** Formát ho ale už podporuje: `{{osloveni|broučku}}` (oslovení v 5. pádě, jen v `uvod`/`dojezd`). MVP vždy použije fallback. | Oslovení místo podmětu řeší shodu slovesa („ty spinkáš“ × „Alexek spinká“). Zapnutí ve fázi 1 = forge přegeneruje jen první a poslední sekci. |
| Korpus sdílet se Storytellerem? | **Kopírovat.** `content/tales/*.md` jsou vlastní krátká převyprávění volných děl. | `storyteller-corpus/corpus/data/raw` obsahuje převážně anglické sbírky, české klasiky tam nejsou. Sdílený balíček `tales-corpus` dává smysl až ve fázi 3 (vícejazyčnost). |
| Nekomerční licence XTTS v MVP? | **Cílit rovnou na permisivní licenci** (viz ADR-001). | Fáze 2 = IAP; přegenerovat celý katalog jiným hlasem by znamenalo, že rodiče, kteří si zvykli na hlas, ho ztratí. |
| Hudební kolébavky? | **V MVP jen přírodní zvuky a šumy** (8 smyček, viz ADR-002). | Kolébavka z hracího strojku (lidová melodie, vlastní syntéza) je kandidát pro fázi 1. |

**Důsledky:** všechno výše je vratné. Jediné rozhodnutí, které by se později
měnilo draze, je volba TTS enginu pro výchozí hlasy (ADR-001).
