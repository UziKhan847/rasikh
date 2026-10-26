# Justified Madani muṣḥaf — prototype

This runs **digitalkhatt.org's own justification engine** over the app's Madani lines, offline. The engine is `vendor/just.service.ts`, MIT, from DigitalKhatt/digitalkhatt-js.

It uses **DigitalKhatt New Madina** (`fonts/madina.otf`, OFL, DigitalKhatt/madinafont). It fits each line with kashīdas and widened letter forms: the font's `cv01`–`cv18` alternates. Space-only stretching is used as a last resort.

Every alternate is an ordinary glyph in the font, so the result can be drawn from the glyph atlas, exactly like today. Nothing is shaped at run time.

## Run

    cd tool/mushaf_justify && npm install            # harfbuzzjs 0.4.5, as the site
    node --experimental-transform-types justify.mts  # → out/lines.json (≈8 s)
    tool/mushaf_atlas/.venv/bin/python tool/mushaf_justify/render.py 3 50 106 250 582
                                                     # → out/page_<n>.png

`justify.mts` patches only the vendored files' imports, into `out/ts/`. A newer `just.service.ts` from the site drops in as is.

## What it does with our text

**Our lines are the input.** `assets/quran/mushaf_u_text.json` is cut by `mushaf_u_layout.json`. It is already in DigitalKhatt's encoding. Compared line by line with the site's `quran_text_madina.ts`, 8,795 lines are identical, ignoring U+034F.
- The only differences are al-Fātiḥah's basmala line and one moved word on each of pages 27, 379 and 451.
- So no word mapping is needed: our tokens, and the tajwīd and marks keyed to them, stay as they are.

**The site's mark-order fix is applied:** U+034F around hamza and madda on alif, wāw and yāʾ.

**The measure is per page, as the site sets it.** Each page is sized to its widest line, and the other lines are stretched to it. This matches how the app already sizes a page. The site's narrower lines (pages 1–2, and a few near the end) keep their ratios.

## Results (all 604 pages)

| | now: DigitalKhattV2, spaces widened | justified: New Madina |
|---|---|---|
| Lines | 8,820 | 8,820 (21 squeezed slightly: narrow special lines) |
| Words stretched (kashīda / wider form) | — | 18,080 of 83,669 (21.6%) |
| Distinct glyphs (atlas sprites) | 630 | 839 (+33%, still one sheet per size) |
| Distinct word shapes (`.bin` entries) | 21,488 | 26,781 (+25%, ≈3.4 MB vs 2.7 MB) |

The side-by-side pages are in `out/page_<n>.png`.

## If adopted: building it into the app

*Adopted: the Madani atlas is built this way (the app keeps its spaces and only spreads rounding; narrow lines stay narrow). The notes below are the plan as it was.*

1. **Atlas.** `tool/mushaf_atlas/gen_atlas.py` gets a `madina` config.
   - It reads `out/lines.json` and shapes each token with its characters' features, `madina.otf` and `cluster_level` characters.
   - Glyph clusters map back through the U+034F insertions to our token's characters, so `char_rules` (tajwīd) keeps working.
   - Each token takes its own run. Identical runs are still shared.
2. **Spaces.** The line's spaces come from the engine (`simpleSpacing` and `ayaSpacing`, in font units) and are stored per line. `AtlasLine` then lays words with those gaps, instead of spreading the leftover width.
3. **Geometry.** `MushafGeometry.refEm['uthmani']` becomes madina's typical page measure. The scanned page ratios stay.
4. **Fonts.** `madina.otf` goes to `assets/fonts/`, with its OFL notice in `LICENSES/`. It's needed only to build; the app draws from the atlas. Word sheets and the reader keep DigitalKhattV2/UthmanicHafs, or switch too.
5. **Choice.** Replace the Madani atlas, or ship both and let a muṣḥaf-style setting choose (about +3.5 MB).
