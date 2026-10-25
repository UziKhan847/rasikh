# Nabr — recon report (milestone 1)

The brief is `NABR_BRIEF.md`. Its data lives in:
- `assets/nabr/nabr_content.json`: the teaching content the app ships;
- `nabr_golden_tests.json`, `nabr_special_locations.json` and `nabr_intonation_hints.json` here: the engine's inputs and tests.

The whole module stays behind `nabrEnabled` until the Shaykh has reviewed it and permission is confirmed.

## 1. How the muṣḥaf turns text into glyphs, and where colour goes

**Nothing is shaped while the app runs.** `tool/mushaf_atlas/gen_atlas.py` does the shaping offline:
1. It shapes every line of `assets/quran/mushaf_{u,i}_text.json` with HarfBuzz, using the bundled DigitalKhatt font, the way Flutter would.
2. It cuts the line into tokens. A token is a word or a ۝. Tokens are separated by U+200C (ZWNJ) inside each āyah string.
3. It rasterises every glyph once into the sheets in `assets/quran/atlas/`.

**Drawing:** the app (`lib/data/mushaf_atlas.dart`, `lib/screens/mushaf/mushaf_line.dart`) draws each line with `drawRawAtlas`. It looks glyphs up by token, so a word's address is (global āyah, word index). That maps one-to-one onto the brief's `s:a:w`.

**Colour already works per glyph.** For each token, `MushafAtlas.tajwidPairs` holds (glyph index, tajwīd rule) pairs. They are built by `char_rules`, which maps the reader text's tajwīd character ranges onto glyphs through each glyph's source character index (its HarfBuzz cluster).

**Where Nabr plugs in:** Nabr colouring adds a parallel `nabrPairs` table built the same way, from the engine's word-relative character ranges.
- A stressed letter inside a ligature colours the whole cluster, such as لا or the lām–lām–hāʾ of ٱللَّه. These cases get listed in the review.
- Colour never changes the shaping, so justified widths can't shift.

## 2. Code points actually used (verified against the data, not guessed)

Inventory from the muṣḥaf texts the engine will read. Counts are over the whole Qurʾān.

**Madani: `mushaf_u_text.json`** (DigitalKhatt encoding)
- **Base letters:** ء and ا–ي, plus ى and ة.
- **Hamza:** never precomposed. أ إ ؤ ئ are written as a seat plus U+0654 (hamza above) or U+0655 (hamza below).
- **Alif waṣla** ٱ (U+0671).
- **Vowels** U+064E–0650. **Tanwīn:** U+064B–064D, plus the open tanwīn forms U+08F0 (fatḥatān), U+08F1 (ḍammatān) and U+08F2 (kasratān).
- **Sukūn** U+0652, the only sukūn here. The reader text uses U+06E1 instead.
- **Shadda** U+0651. **Dagger alif** U+0670.
- **Small wāw / small yāʾ** U+06E5 and U+06E6 (ṣila).
- **Not pronounced:**
  - **U+06DF** (round zero, 3,988 times) and U+06E0 (rectangular zero) are the zero marks;
  - **U+06E2** and U+06ED (iqlāb mīm);
  - **U+06DC** and U+06E3 (sīn for ṣād).
- **Other marks:** madda U+0653; U+06E4 and U+06E7–06E8 (small high madda, yāʾ, nūn); U+08F3 (small high wāw, once).
- **Waqf signs:** U+06D6–06DB.
- **Markers:** ۝ U+06DD plus Arabic-Indic digits; U+06DE (rubʿ); U+06E9 (sajda).
- **Joiners:** U+200C between tokens; U+034F (CGJ, 5 times) to order marks; tatweel U+0640 (1,652 times, mostly as a hamza seat, e.g. ٱلْـَٔاخِرَة).

**Indo-Pak: `mushaf_i_text.json`**
- **Letters:** the same letters. Yāʾ is U+064A, not ی; final hāʾ is U+0647, not ہ. So the brief's guess of ی/ہ doesn't hold for this data.
- **Sukūn:** U+0652, 62,383 times. Indo-Pak writes a sukūn even on madd letters.
- **Hamza:** U+0654/0655, with U+034F (CGJ, 3,263 times) between a letter and its marks.
- **Signs not in the Madani text:**
  - U+0614 (takhallus) and U+0615 (small high ṭāʾ: a waqf mark);
  - U+0617 (small high zayn);
  - U+06D9 (lām-alif, lā waqf);
  - **U+089C** (2,098 times, the Indo-Pak madd sign);
  - U+08D5–08DF (small high ṣād, ʿayn, qāf, waqf words, saktah…);
  - U+08E2 (disputed āyah end, 118 times).
- **Zero marks:** U+06DF (round zero) 26 times only. Indo-Pak usually shows an unpronounced letter by leaving it **unvowelled**, so "no mark on a letter" means silent. This is one reason the engine runs on the Madani text and is aligned onto Indo-Pak afterwards (brief §3.7).

**The reader texts** (`assets/quran/u`, `assets/quran/i`) use a different encoding:
- precomposed أ إ ؤ ئ;
- U+06E1 as the sukūn;
- the QPC private uses U+0656, U+0657 and U+065E for the open-tanwīn forms.

The engine must read the **muṣḥaf** texts, because its spans are applied to the glyphs drawn from them.

## 3. Morphology source (the app may be commercial)

| Source | Licence | Notes |
|---|---|---|
| **MASAQ v2** (Sawalha et al., Mendeley Data, DOI 10.17632/9yvrzxktmr.2, Oct 2024) | **CC BY 3.0** (as the dataset record and the ACL 2025 paper state) | **Recommended.** Over 131K morphological entries and 123K syntactic-function instances (72 roles), as txt/CSV/XLSX/XML/JSON. Built on **Tanzil** text, so it aligns per word with our QPC/DigitalKhatt words by s:a:w (normalised letters). The few words split differently between Tanzil and QPC get an explicit alignment table, and failures are logged. Attribution goes in About and `LICENSES/`. |
| QuranMorph (SinaLab, Birzeit, 2025) | Described as open-source; no licence named in what I found | Hand-lemmatised (77,429 words). Use only once its licence is confirmed from the download. |
| Quranic Arabic Corpus v0.4 (Leeds) | GNU GPL; "research / non-commercial" per its FAQ | **Not used** unless cleared in writing. |
| *Iʿrāb al-Qurʾān al-Karīm*, al-Daʿʿās, Ḥamīdān & al-Qāsim (Dār al-Munīr / Dār al-Fārābī, Damascus, 1425 AH; on Shamela as book 23584) | A copyrighted print book; Shamela hosting is not a licence | **The human reference, not the data.** It gives one opinion per word, which helps consistency, but it is running prose ("الواو: حرف عطف…"), not segments. Any word whose stress depends on a tag (relative vs restrictive mā, conjunctive vs root wāw, jussive) goes to the Shaykh's review with al-Daʿʿās's analysis next to it. Extracting data from it would need the publishers' permission. |

**Before milestone 3**, download MASAQ v2 from the Mendeley page. A click is needed. Then confirm the licence text in the archive, and I'll check it covers what the engine needs:
- prefix/stem/suffix segments;
- jussive and imperative mood;
- relative vs restrictive mā (REL vs PREV);
- INC (alā);
- vocative and interrogative particles.

**Sources:**
- [MASAQ v2 (Mendeley Data)](https://data.mendeley.com/datasets/9yvrzxktmr/2)
- [MASAQ v1](https://data.mendeley.com/datasets/9yvrzxktmr/1)
- [MASAQ Parser, ACL 2025](https://preview.aclanthology.org/aacl-dois/2025.clrel-1.7)
- [QuranMorph (arXiv 2506.18148)](https://arxiv.org/abs/2506.18148v1)
- [SinaLab Quran Corpus](https://sina.birzeit.edu/quran/)

## 4. Plan from here (brief §9)

1. ~~Recon~~ (this report).
2. **Teaching module:** Learn, Practice, Quiz and Colour guide, from `assets/nabr/nabr_content.json`, behind `nabrEnabled` (off).
3. **Engine** (`tool/nabr/`, pure Dart). This starts only after the Shaykh's review of the content and golden tests comes back through the content review page (`tools/content_review/`):
   - units and G1–G4, with the single-word golden tests;
   - G5–G7, S-rules, P3, conflicts, and all golden tests;
   - whole-muṣḥaf build and sanity checks; the review goes to the content review page as well as `build/nabr_review.csv`, and corrections go to `overrides.json`;
   - rendering via `nabrPairs` (Madani, then Indo-Pak alignment, then overlay mode);
   - PDF sample.

## 5. Questions still open (brief §10)

- **Natural stresses:** show `nat` stresses in the muṣḥaf, or only in lessons? (The default proposed is hidden in the muṣḥaf.)
- **Waqf signs:** at ۘ, ۚ and similar signs, use the joined reading or the pause reading?
- **Ligatures:** is colouring a whole ligature cluster acceptable when the stress falls inside one?
- **Default display mode:** Nabr mode or overlay mode?
- **Review badge:** who reviews the per-word output, and should the app show a "reviewed" badge per sūrah?
