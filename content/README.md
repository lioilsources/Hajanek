# content/ — obsah Hajánka

Zdrojová data, ze kterých `forge` generuje audio a katalog. Formáty jsou
popsané v [`docs/CONTRACTS.md`](../docs/CONTRACTS.md).

| Cesta | Co |
|---|---|
| `tales/{id}.md` | předloha: front matter (metadata, `softening`) + krátké převyprávění volného díla |
| `scripts/gold/{id}.{len}.md` | ručně psané vzorové skripty (`status: gold`) — few-shot pro LLM a test fixture pro judge |
| `scripts/{id}.{len}.md` | ostatní skripty; `status: draft` = čeká na kontrolu člověkem, forge je bez `--allow-draft` nenamluví |
| `prompts/script_template.md` | prompt pohádka → meditace |
| `prompts/judge_checklist.md` | LLM-judge (doplněk k deterministickým kontrolám ve `forge judge`) |
| `prompts/forbidden_words.txt` | zakázané kmeny slov (prefixy) |
| `presets/presets.json` | presety mixu podkresů |
| `ambient/` | bezešvé smyčky + skript na jejich výrobu (viz `ambient/README.md`) |
| `estimate_duration.py` | rychlý odhad délky skriptu po sekcích (95 slov/min + pauzy) |

## Kontrola skriptu draft → gold

1. `python3 content/estimate_duration.py content/scripts/{id}.10.md` — 9,3–10,3 min.
2. `forge judge content/scripts/{id}.10.md` — deterministické kontroly + LLM-judge.
3. Přečíst nahlas, potichu, pomalu. Hledat: napětí, otázky, dlouhé věty,
   slova, která TTS špatně vysloví (zkratky, číslice, cizí slova).
4. Přepnout `status: draft` → `status: reviewed` (a do `gold/` jen výjimečně,
   když má sloužit jako vzor).
