# Ambient smyčky — licence a atribuce

Všechny zdrojové nahrávky jsou **CC0 1.0 (Creative Commons Zero, public domain
dedication)** — atribuce není povinná, uvádíme ji dobrovolně (slušnost + dohledatelnost
původu). Šumy jsou syntetizované ffmpeg (`anoisesrc`), bez cizího materiálu.
Stav ověřen 2026-10-20 přímo na stránkách zvuků (Freesound uvádí „Creative Commons 0“).

| soubor | zdroj (stránka) | autor | licence | originál | použitý soubor |
|---|---|---|---|---|---|
| `sea.opus` | [Waves at Baltic Sea shore](https://freesound.org/people/pulswelle/sounds/339517/) (Hohwacht, DE, 2016) | pulswelle | CC0 1.0 | WAV 44.1 kHz/24 bit, stereo, 26:04 | HQ preview Ogg Vorbis ~179 kbps, výřez 445–553 s |
| `rain.opus` | [Soft rain on roof window](https://freesound.org/people/Metadex/sounds/235827/) (2014) | Metadex | CC0 1.0 | WAV 48 kHz/24 bit, stereo, 3:16 | HQ preview ~219 kbps, výřez 5–103 s |
| `stream.opus` | [Stream Wyre forest 8.1.14](https://freesound.org/people/turbostream/sounds/220528/) (Wyre Forest, UK, 2014) | turbostream | CC0 1.0 | FLAC 44.1 kHz/16 bit, stereo, 6:30 | HQ preview ~240 kbps, výřez 10–118 s |
| `fireplace.opus` | [Fireplace crackling wood little flame](https://freesound.org/people/BonnyOrbit/sounds/484338/) (Ticino, CH, 2019) | BonnyOrbit (Bonny Orbit Sound Library) | CC0 1.0 | WAV 48 kHz/24 bit, stereo, 2:04 | HQ preview ~215 kbps, výřez 5–115 s |
| `wind.opus` | [Forest, close up of trees rustling in the wind](https://freesound.org/people/Anya_Media/sounds/523389/) (Hexham, UK, 2020) | Anya_Media | CC0 1.0 | WAV 48 kHz/16 bit, stereo, 2:19 | HQ preview ~162 kbps, výřez 20–130 s |
| `night-meadow.opus` | [Night Crickets Back Porch](https://freesound.org/people/hdfreema/sounds/333221/) (Charlotte, NC, US, 2016) | hdfreema | CC0 1.0 | AIFF 48 kHz/16 bit, stereo, 3:40 | HQ preview ~162 kbps, výřez 110–218 s |
| `pink-noise.opus` | vlastní syntéza (`anoisesrc=color=pink`, seedy 11/29) | Hajánek | vlastní, bez omezení | — | — |
| `brown-noise.opus` | vlastní syntéza (`anoisesrc=color=brown`, seedy 11/29) | Hajánek | vlastní, bez omezení | — | — |

Ukolébavky `lullaby-*.opus` jsou vlastní generace modelem **ACE-Step 1.5 turbo**
(licence MIT; výstupy modelu nejsou omezené a lze je užít komerčně), spuštěným na
vlastním hardwaru (AiStack). Bez cizího zvukového materiálu, bez textu (instrumentální),
melodie nejsou převzaté. Prompt a seed každé smyčky jsou v `ambient.json`.

Doporučený text do „O aplikaci → Zvuky“:

> Přírodní zvuky: pulswelle, Metadex, turbostream, BonnyOrbit, Anya_Media a hdfreema
> (freesound.org, CC0). Děkujeme!

## Co jsme vědomě NEpoužili

- **BBC Sound Effects** (sound-effects.bbcrewind.co.uk) — licence RemArc dovoluje jen
  osobní, vzdělávací a výzkumné užití; komerční aplikace = nutná placená licence.
- **Cokoli CC BY-NC / CC BY-NC-SA / „Sampling+“** — nekomerční / nejasné.
- **CC BY(-SA)** — legální, ale vyžaduje atribuci (SA navíc sdílení derivátu pod
  stejnou licencí); CC0 alternativy existovaly, takže nepotřebné.
- **Sonniss GDC Game Audio Bundle** — royalty-free, bez atribuce, komerčně OK pro
  „finished game, film, app“, ale zakazuje redistribuci zvuků „jako zvukových efektů“
  (i upravených) a zakazuje AI/ML trénink. Naše `.opus` smyčky jsou veřejně na CDN jako
  samostatně stažitelné soubory → šedá zóna (de facto redistribuce surového zvuku).
  Proto nepoužito; případně jen po právním výkladu.
- **Wikimedia Commons „Ocean Waves on a Tropical Beach.ogg“** (CC0) — nekonzistentní
  autorství (popis „By J.D. Savanyu“ vs. nahrávající „Jarrod stanley“, „own work“,
  nahráno 2026-08) → nejistý původ, nepoužito.
