# Nabr (Qurʾānic Stress) Module — Brief for Claude Code

> **Paste this to Claude Code to start:**
> "Read `NABR_BRIEF.md` and the JSON files next to it. Then explore my Flutter codebase, especially how the Mushaf is rendered with DigitalKhatt 2 (New Madani) and with the IndoPak script. Before writing any code, reply with: (1) a summary of how my renderer turns āya text into glyphs and where per-character colour could be injected; (2) the list of every Unicode code point used in each script's text data; (3) your implementation plan following the milestones in §9. Ask me about anything in §10 that you can't resolve from the code."

---

## 0. What we are building

Three things, inside the app's existing **Nabr** section:

1. **Learn / Practice / Quiz.** A teaching module whose content is already written in `nabr_content.json`, bilingual Arabic + English. It is based on *Ṣawn al-Lisān ʿan al-Laḥn fī al-Qurʾān* by Shaykh ʿAlī ʿAbd al-Tawwāb Aḥmad.
2. **Nabr colouring of the Mushaf.** This works like tajweed colouring, but it marks *which letter carries the stress (nabr)* and how strong that stress is. It must work in both renderers: DigitalKhatt 2 (New Madani) and IndoPak.
3. **A sample PDF export.** This means a few coloured pages with a legend page, to show to teachers and reviewers.

The rules are concrete, but applying them needs **phonological and morphological information that is not in the raw glyph string**. For example, you need to know whether an initial wāw is a conjunction or a root letter (وَكَتَبَ vs وَجِلَةٌ), whether a letter is silent, and whether a sukūn is original or only there because of a pause. So the colouring engine is a **pipeline that runs offline at build time**. The app only reads its precomputed output.

---

## 1. Files provided

| File | What it is |
|---|---|
| `NABR_BRIEF.md` | This brief. |
| `nabr_content.json` | All teaching content, structured: `lessons` (parts → chapters → blocks), `drills` (100 tap-the-stressed-letter items), `quiz` (71 multiple-choice questions), `colourGuide`, `meta`. |
| `nabr_golden_tests.json` | 100 expected results (word or phrase → stressed letters), taken from the book's examples and answer key. These are the engine's unit tests. |
| `nabr_special_locations.json` | Overrides driven by location for the special rules (innamā, annamā, biʾsamā, aynamā, kullamā, alā, lahum, yawma hum…) and for the strong "dropped letter" and heavy-madd stresses. |
| `nabr_intonation_hints.json` | Optional hints at the level of a whole āya (lower voice, raise voice, change of topic, question tone). These are icons or tooltips, not glyph colours. |

**String format in all content.** Strings use markdown-lite: `**bold**`, `*italic*`, `***bold-italic***`. Qurʾān quotes are wrapped in `﴿ ﴾`. Render Arabic strings with `TextDirection.rtl`, and English strings in LTR.

---

## 2. Part A: the teaching module

### 2.1 Content model (`nabr_content.json`)

```
lessons[]           // parts: part0 … part5
  .chapters[]
    .id, .ruleId     // ruleId: G1–G7 general rules, S1–S14 special rules, or null
    .titleAr/.titleEn
    .blocks[]        // see the block types below
drills[]            // tap the stressed letter(s)
quiz[]              // kind: "whichLetter" | "concept"
colourGuide         // levels, modifiers, overlay settings
```

**Block types** (each block has `type`):

| type | fields | how to render it |
|---|---|---|
| `paragraph` | `ar`, `en` | Arabic paragraph, with its English paragraph directly underneath. |
| `section` | `titleAr`, `titleEn` | Sub-heading. |
| `rule` | `num`, `ar`, `en` | A highlighted "rule card". These are the cards users should memorise. |
| `note` | `kind` (`warning`/`tip`/`summary`), `ar`, `en` | A callout. Colours: warning = red, tip = gold, summary = green. |
| `examples` | `items[]` with `word`, `tokens[]`, `stressedTokenIndices[]`, `stressOn{ar,en}`, `whyAr`, `whyEn` | An example table. Show the word big. Show the tokens spaced apart, with the stressed tokens in the level colour. Then show the reason. |
| `table` | `columns[]{ar,en}`, `rows[][]{ar?,en?}` | A generic bilingual table. |
| `takeaways` | `items[]{ar,en}` | End-of-chapter recap. |
| `practice` | `set`, `items[]` (words), `answers[]` (same shape as example items) | A practice sheet where the student answers first and then reveals the answer. |

### 2.2 Screens

- **Learn.** Parts → chapters → a scrolling lesson, with a progress indicator. Every example token row should be tappable so the student can hear audio later (optional, but leave a hook for it).
- **Practice.** Shows `drills[]`. The student sees the word as separate token "tiles" in RTL order and taps the stressed tile(s). For `mode: "multi"` they select all the correct tiles and press Check. Tokens listed in `nonSelectable` (the word separator `ـ`) cannot be selected. After checking, show `answerAr/En` and `explanationAr/En`.
- **Quiz.** Shows `quiz[]`. Shuffle the options when `shuffleOptions` is true (and you can also shuffle `whichLetter` options). Keep score. Spaced repetition is optional.
- **Colour guide.** Show `colourGuide.levels` and `modifiers`, each with its example words coloured.
- **Practice sets A, B, C.** Show these as worksheets with an answer reveal. Set B comes from al-Baqara 102 and Set C from Sūrat ʿAbasa, so link each one to its āya in the Mushaf.

### 2.3 Colouring a token row (for lessons and drills)

The tokens are already split for you, so this does **not** need the engine. Render each token as its own `TextSpan`, in **Scheherazade New** (or the app's lesson font). Colour a stressed token with its level colour. The token strings are written letters with their diacritics, so they stay legible when spaced apart. Do not join tokens into one word for this row. The whole word is shown separately, uncoloured or coloured from engine output.

---

## 3. Part B: the colouring engine (build-time pipeline)

### 3.1 Architecture

```
tool/nabr/                 (Dart CLI, run with `dart run tool/nabr/build.dart`)
  inputs:
    - Mushaf text per script, keyed by word location "s:a:w"
      (the app's existing DigitalKhatt v2 text + IndoPak text)
    - morphology per word (prefix / stem / suffix segments, POS, mood)
    - nabr_special_locations.json, overrides.json (human corrections)
  output:
    assets/nabr/nabr_madani.json      (or .bin / sqlite; see §3.8)
    assets/nabr/nabr_indopak.json
    build/nabr_review.csv             (every annotated word, for human review)
```

At runtime the app loads the asset for the active script and passes **colour spans** to the renderer. Nothing is computed while rendering.

### 3.2 Morphology source

You need prefix and suffix segmentation per word. You also need the mood (jussive), the imperative, and a few particle tags (relative `mā` vs restrictive `mā`; `alā` as an attention-getter).

- **The Quranic Arabic Corpus v0.4** (Leeds) is the classic source. It is under the GNU GPL, and its FAQ says the data is for research and non-commercial use. **Check this against the app's licence before shipping anything derived from it.**
- **Alternatives to evaluate:** MASAQ (stated as CC BY 3.0) and QuranMorph (SinaLab). Pick whichever has a clean licence and per-word alignment to the Ḥafṣ text. Record the choice in `tool/nabr/README.md`.
- **What you need from it:** for each word, its segments with their types. These are prefix (conjunction wa/fa, preposition bi/li/ka, emphatic lām, interrogative hamza, future sa-, vocative yā), stem, and suffix (attached pronoun, nā, nī, plural/dual markers). You also need the flags for jussive or imperative mood, REL vs restrictive (`PREV`) mā, and INC.

### 3.3 Step 1: normalise each script's text to code-point classes

Scan the app's actual text files and **list every code point** used (DigitalKhatt v2 uses Uthmani Unicode, for example U+06E1 for sukūn). Build an explicit class table. Do not guess. Expected classes:

| Class | Examples (verify against the data) |
|---|---|
| base consonant | ب ت ث … ي, with the hamza forms ء أ إ ؤ ئ all treated as **hamza** |
| alif / alif waṣla | ا (U+0627), ٱ (U+0671) |
| short vowels | fatḥa, ḍamma, kasra (U+064E–0650) |
| tanwīn | U+064B–064D, plus the open/sequential tanwīn forms if present (U+08F0–08F2) |
| sukūn | U+0652 and U+06E1 (Uthmani "khāʾ-head") |
| shadda | U+0651 |
| dagger alif | U+0670: a **pronounced long ā** |
| small wāw / small yāʾ | U+06E5, U+06E6: a pronounced long vowel (ṣila) |
| not pronounced | U+06DF and U+06E0 (round zeros) mark an unpronounced letter |
| other marks | madda U+0653, hamza above U+0654, iqlāb mīm U+06E2/U+06ED, the sakt sīn U+06DC, waqf signs (ۖ ۗ ۚ ۛ ۘ ۙ), āya-end markers |
| IndoPak extras | ی (U+06CC), ہ (U+06C1), and the IndoPak vowel/sukūn forms. Build its table separately. |

### 3.4 Step 2: build the phonological unit stream

For each āya, produce a **stream of pronounced units** in **joined (waṣl) reading**. Then produce the pause (waqf) variant for any word that can be paused on (the last word of the āya always; words at waqf signs optionally).

```dart
class Unit {
  String letter;        // normalised base letter, or 'ā' / 'ū' / 'ī' for long vowels
  Vowel vowel;          // a, i, u, or none (sukūn)
  bool isMadd;          // long vowel / madd letter (always sukūn)
  bool fromShaddaFirst; // first (silent) half of a doubled letter
  Origin origin;        // root, prefix, suffixPronoun, taMarbuta, other suffix
  bool presentPrefix;   // ya-/ta-/na-/a- prefix: treat as ROOT (see S13)
  int wordIndex;        // which word of the āya
  CharRange src;        // UTF-16 range in the SOURCE word string: the base letter + all its marks
  bool sukunIsOriginal; // false if the sukūn only comes from the pause
}
```

Rules for building the stream:

- **Shadda** → two units with the same `src`: the first is silent (`fromShaddaFirst`), the second carries the vowel.
- **Sun-letter assimilation** (ٱلشَّمْس, ٱلدُّنْيَا): the article's lām produces no unit. The first (silent) half of the following shadda gets `origin=prefix`, because it *is* the assimilated article.
- **Madd letters** (alif after fatḥa, wāw after ḍamma, yāʾ after kasra, dagger alif, small wāw/yāʾ) → a silent long-vowel unit. These count as a **sukūn** for the rules: the book treats the alif in الملائكة as "the third letter is a medial sukūn".
- **Letters that are not pronounced** produce **no unit** but keep their source range. This covers a letter marked with a round zero, the alif after plural wāw, a mid-phrase alif waṣla, the sun-letter lām, a dropped long vowel before a sukūn in joined reading (فِي ٱلْأَرْضِ), and the dropped dual alif.
- **Hamzat al-waṣl** is a unit only at the start of a reading after a pause. When it starts the āya, assume the reader starts there.
- **Tanwīn** → the vowel plus a final silent nūn unit (n). In a pause, tanwīn with fatḥa becomes ā, and the others drop.
- **Tāʾ marbūṭa** → t + vowel in joined reading; a silent h at a pause.
- **Final vowel at a pause** → removed. Set `sukunIsOriginal=false` on that unit.

### 3.5 Step 3: apply the rules

All indices below count **pronounced units within one word**, unless a rule says otherwise. `R` is the index of the first **root** unit (skip `origin==prefix` units). "Medial" means at least one more unit follows **in the same word**. "Final" means it is the word's last unit. A stressed unit gets a `level` and a `ruleId`.

**Global constraint: no two adjacent stressed units.** Treat the two halves of a shadda as separate units, so a shadda separates its neighbours. When two candidates touch, keep the stronger one using §3.5.4. If both reasons land on the same unit, keep it and record both rule ids.

#### 3.5.1 General rules

| id | condition | stress | level |
|---|---|---|---|
| **G1** | `U[R+1]` silent → natural | `U[R]` (even if it is a prefix that replaced an alif waṣla, e.g. وَاقْتُلُوا, بِاللَّهِ) | weak, `isNatural` |
| | else if `U[R+2]` silent **and medial** | `U[R+1]` | medium |
| | else | `U[R]` | medium |
| **G2** | for each silent `U[i]` followed by a voweled **medial** `U[i+1]` → candidate `U[i+1]`. Then look for the next silent unit `j` in the word: if `j == i+3` **and** `j` is medial → **move** to `U[i+2]` (joined reading only). At a pause, drop it if `U[j]` is a madd letter right before the last unit; otherwise keep it. If `j ≥ i+4`, keep `U[i+1]`. If `j == i+2`, the stress at `i+1` is natural. | as described | medium (natural ones weak) |
| **G3** | the unit right before the first `suffixPronoun` unit (and before tāʾ marbūṭa in joined reading, and before ـنِي) | that unit | weak |
| | **Exception:** if two or more units follow the pronoun's hāʾ/kāf (تَحَاوُرَكُمَا, شَهَادَتِهِمَا), move it **forward** to the pronoun consonant instead of dropping it | | weak |
| **G4** (pause) | the last unit is the second half of a shadda → stress the unit before the shadda pair | | medium (strong at a madd + shadda, see P3) |
| | the last unit is light and silent → stress `U[n-3]` | | medium |
| | **never** stress `U[n-2]` when `U[n-1]` is a final sukūn. When the sukūn is original (jussive, imperative, ى…), this holds **in joined reading too**, even if a helping vowel was added before a following sukūn (وَبَشِّرِ الَّذِينَ → bāʾ, not shīn). A pause-only sukūn blocks the stress **only at the pause**. | | |
| **G5** (between words, joined reading) | look at the next word's main stress. If it is on its **unit 0** → **separating**: the last unit of this word must NOT be stressed. If it is on its **unit 1** → **joining**: stress this word's last unit, unless that breaks the adjacency rule. | | weak |
| **G2 note** | If the silent unit that triggers G2 is a **prefix** unit (the article's lām in الْمَلَائِكَة, or the first half of a sun-letter shadda whose origin is the assimilated article), the G2 candidate is **weak and natural** and ranks **below G1**. The book stresses the **lām** of الملائكة (by G1), not the mīm. The sukūn that outranks other reasons is an *original, medial* one. | | |
| | **Silent units across words:** run G2 on the **āya stream** across word boundaries. Count the letters between the last silent unit of word A and the first silent unit of word B, **including units dropped in joining**. If there are 1–2, stress only before the first silent unit. If there are more than 2, stress before and after it (يَأْتِيَهُمُ اللَّهُ; حَاضِرِي الْمَسْجِدِ vs غَافِرِ الذَّنبِ). | | |
| **G6** | the word is a one-letter preposition (bi-/li-) + pronoun suffix → stress the preposition. If the pronoun is هُنَّ or كُنَّ, stress the hāʾ or kāf instead. | | medium |
| **G7** | the stem has exactly 2 pronounced units (دَم, قَد, لَم, هُوَ, مَن, يَد, غَد, هُم…) → stress the stem's first unit, in joined reading and at a pause. This **overrides G4**. Exception: a redundant mā after a particle (فَبِمَا) → stress the bāʾ. | | medium |

#### 3.5.2 Special rules (Part 2)

Apply these **after** the general rules and **before** the overrides.

- **S1–S8, S10, S12:** use `nabr_special_locations.json`. Each group gives a default plus explicit exceptions by `sūra:āya`. Find the target word inside the āya by matching base letters with the marks stripped. Set `level: special`.
- **S9 (أَفَلَا / أَوَلَا):** stress the lām.
- **S11 (عَلَى / عَلَا):** both follow G1 and are stressed on the ʿayn. Do not separate them.
- **S13 (added letters):**
  - With two or more prefix units → put a **weak** stress on the first prefix unit (وَلَأُضِلَّنَّهُمْ). If the unit after the second prefix is silent → put it on the second prefix instead (وَبِالرَّسُولِ).
  - With exactly one prefix unit → no stress on it. The exceptions are: the third root unit is a medial sukūn (وَتَفَقَّدَ, بِكِتَابِي) → a weak lead-in on the prefix; or the first root unit is silent (وَأْمُرْ, فَاسْلُكْ) → stress the prefix (this is G1 natural).
  - The present-tense prefix and the participle mīm count as **root**.

#### 3.5.3 Strong stresses (Part 3: preserving the letter)

- **P3_heavy_madd:** a long vowel followed by a doubled letter → **strong** stress on the doubled letter. Skip doubled م/ن, and skip qalqala letters (ق ط ب ج د) at the end of a word at a pause.
- **P3_doubled_waw_ya:** stress the unit **before** a doubled و or ي → **strong**.
- **P3_dropped_dual_alif:** use the list in `nabr_special_locations.json` → **strong**.
- **Hamza after a madd, at a pause** (السَّمَاءُ, شَيْءٌ): a **weak** stress on the hamza.
- **Two silent letters at a pause** (وَالْعَصْرْ): stress the unit before the first silent letter (this falls out of G4).

#### 3.5.4 Which reason wins when two stresses touch

The **stronger** reason wins, in this order:

1. strong (P3)
2. هُنَّ / كُنَّ
3. G2 (after a sukūn: original and medial)
4. G1 (first root letter)
5. G3 (pronoun or tāʾ marbūṭa)
6. G5 joining stress
7. S13 lead-in

The **rule beats meaning and spelling**. Do not add "anti-pun" exceptions (فَأَرُونِي, كَرِيمٍ, وَبَالَ). كُلَّ مَا in 23:44 counts as repetition, so stress the lām.

### 3.6 Step 4: produce one waqf variant

For the **last word of every āya**, output both the joined reading (only if the user turns on "continue past āya ends") and the pause reading. **Default display:** joined reading inside the āya, and the pause reading on the last word. Optional setting: show the pause variants at waqf signs using the `pauseOnly` modifier style.

Āyas that end in a question keep their G2 stress at the pause. See `keepStressAtPauseInQuestions` in the intonation file.

### 3.7 Step 5: map back to characters, per script

Each stressed unit already carries `src` (the UTF-16 range in the Madani word string). Output word-relative spans.

**IndoPak.** Do **not** re-derive anything from the IndoPak text. Run the engine **once**, on the Madani/morphology stream. Then align each word to the IndoPak string by walking the base letters in order. IndoPak writes some long vowels and silent letters differently, so allow the alignment to skip those. Log every word that fails to align to `nabr_review.csv`. Do not guess.

### 3.8 Output format

```json
{
  "version": 1,
  "script": "madani-dk2",
  "words": {
    "2:102:1": [ {"s": 0, "e": 2, "lv": "w", "r": "G1", "nat": true}, {"s": 4, "e": 6, "lv": "m", "r": "G2"} ],
    "2:102:2": []
  }
}
```

- `s`/`e` are word-relative UTF-16 offsets (end exclusive), covering the base letter **and all its following marks**.
- `lv` is the level: s = strong, m = medium, w = weak, x = special.
- `ctx` is optional: `"waqf"` or `"wasl"` when a stress applies in only one context.

If the file is too big, switch to SQLite or a binary format. Either way, load it lazily per page.

---

## 4. Rendering the colours

**First, read how the app currently renders each script.** Possibilities:

- **Flutter `TextSpan`s:** split each word into spans at the stress ranges and set `color`. Changing colour between spans normally does not break Arabic joining, but **test it in both fonts**. Pay particular attention to ligatures such as لا and the word الله, and to diacritic marks that stack on top of each other.
- **A HarfBuzz/FreeType custom renderer** (e.g. the `arabic_text_justification` package, which supports DigitalKhatt with kashida justification and has `WordColorSpan(wordIndex, start, end, color)`): its offsets are in the same word-relative code units, so you can pass the spans through. If you write the renderer yourself, map character ranges to **HarfBuzz clusters**. When a stressed letter sits inside a multi-letter cluster or ligature, the whole cluster gets coloured. Accept that, but list those cases in the review CSV.
- **Justified lines:** colouring must not change the shaping, or the kashida/justification widths will shift. Only colour (paint), never change the font run.

**Two display modes**, toggled in settings:

1. **Nabr mode:** glyph colours use the level colours. The tajweed colouring is off.
2. **Overlay mode:** tajweed colours stay on. Nabr is drawn as a short bar under the stressed glyph's bounding box, using `colourGuide.overlayMode`. This needs glyph bounds per character range, so implement it only if the renderer exposes them.

**Filters:** let the user show or hide each level. Hide `nat: true` stresses by default, because there are many of them and the reader produces them without effort anyway.

**Colour values:** see `colourGuide.levels[*].light/dark`. Never rely on colour alone: the legend also uses ● ◐ ○ ◆ and the overlay bars vary in thickness.

---

## 5. Tests and acceptance

1. **Golden tests:** convert `nabr_golden_tests.json` into Dart tests. Follow the token conventions in that file: tokens are written base letters in order, one token per doubled letter, `ـ` separates words, and the expected sets include natural stresses. Map the engine's units to these tokens by walking base letters. **Target: 100% pass**, or a written justification for each failure that I approve.
2. **Special locations:** every ref in `nabr_special_locations.json` must resolve to exactly one word. Fail the build otherwise.
3. **Sanity checks over the whole Mushaf:**
   - no two adjacent stressed units;
   - every word with at least 3 pronounced units has at least one medium, strong or special stress, or is listed in the CSV as an exception;
   - no stress on the letter before an original final sukūn, except in two-letter words.
4. **Human review:** `build/nabr_review.csv` has one row per word, with columns `ref, madani_text, indopak_text, stresses (letter + level + rule), flags`. A qualified teacher reviews it. Corrections go into `overrides.json` (`{"s:a:w": [spans]}`), which is applied last and wins.

---

## 6. PDF sample

- Render N chosen pages (suggested: al-Fātiḥa, the start of al-Baqara, and Sūrat ʿAbasa) in Nabr mode. Use the Flutter `pdf` package if it is already in the project. Otherwise, rasterise the page widgets at 300 dpi or better and embed them.
- Page 1 is the **legend** (`colourGuide`).
- The last page carries the **attribution and status**: *"Stress rules after Ṣawn al-Lisān ʿan al-Laḥn fī al-Qurʾān by Shaykh ʿAlī ʿAbd al-Tawwāb Aḥmad. Automated annotation, reviewed by: ______."*

---

## 7. Data hygiene

- The Qurʾān text is the app's existing source. Never modify it. All colouring lives in the separate asset.
- Version the asset: include the hash of the text and of the rule set, so a change to either forces a rebuild.

---

## 7b. Attribution and permission

- **In the app:** show a visible credit on the Nabr section's start screen and its About/info page: *"Rules and teaching content after Ṣawn al-Lisān ʿan al-Laḥn fī al-Qurʾān by Shaykh ʿAlī ʿAbd al-Tawwāb Aḥmad."* The text is in `meta.basedOn` in `nabr_content.json`. Show it in Arabic and English.
- **In the PDF:** use the attribution and "reviewed by" line from §6.
- **Permission:** the lesson content summarises a published book. The owner (me) will ask the author or publisher for permission before a commercial release. Put the module behind a feature flag (`nabrEnabled`) so it can ship or stay hidden independently of the rest of the app.

## 8. Things that are out of scope for v1

- Audio-driven feedback (checking whether the user stressed the right letter while reciting).
- Readings other than Ḥafṣ ʿan ʿĀṣim. The IndoPak muṣḥaf is also Ḥafṣ, so it is in scope. Readings like al-Kisāʾī's أَلَا يَا اسْجُدُوا are not.
- Intonation: only verse-level hints (`nabr_intonation_hints.json`), no glyph colouring.

---

## 9. Milestones (do them in order and show me each one)

1. **Recon:** a report on the renderer, the code-point inventory, and the morphology source with its licence.
2. **Teaching module:** Learn, Practice, Quiz and the Colour guide screens, built from `nabr_content.json` with no engine.
3. **Engine core:** units and G1–G4, with the golden tests that cover single words passing.
4. **Between-words and special rules:** G5–G7, S-rules, P3, and the conflict resolution, with all golden tests passing.
5. **Whole-Mushaf build:** the review CSV and the sanity checks.
6. **Rendering:** Madani with DigitalKhatt 2 first, then IndoPak alignment, then overlay mode.
7. **PDF sample export.**

---

## 10. Open questions: ask me rather than guessing

- Which morphology source can we use, given the app's licence (commercial or not)?
- Do we show natural (`nat`) stresses at all in the Mushaf, or only in lessons?
- How should a pause be handled at waqf signs: the joined reading by default, or the pause reading at ۘ / ۚ and similar signs?
- When a stressed letter is part of a ligature, is colouring the whole cluster acceptable?
- Overlay mode vs a separate nabr mode: which should be the default?
- Who will review the CSV, and should the app show a "reviewed" badge per sūra?
- Should the `nabrEnabled` feature flag default to on or off until permission is confirmed?
