## Desktop mode (this revision)

The app now has a full **desktop layout** that activates automatically on Linux,
Windows and macOS (and wide desktop browsers), while phones and tablets keep the
mobile layout. A manual override lives in **About → Display → Layout**
(Auto / Mobile / Desktop) and in the desktop top-bar menu, and switches live.

- **Sidebar shell** — brand, the eight studios, a streak card, and About, with an
  icon-only rail when the window is narrow.
- **Home dashboard** — greeting hero with Resume + Today's-lesson and stars/letters
  stats; an "Explore the path" card grid; a Jump-to-a-rule strip; and a right rail
  with **Verse of the day** (tap to hear Tunaiji), a **This-week** 7-day tracker,
  and global **Reading-setup** toggles.
- **Top bar** — section title, sūrah search, and a settings menu.

New cross-cutting features added to **both** layouts:
- **Streak + weekly goal** tracking (`ProgressStore`) — any earned progress counts
  toward today; the week resets on Mondays.
- **Verse of the day** (shared pool, picked by calendar day) on both home screens.
- **Letters-learned** progress (opening a letter in Qaidah Path now records it).

The desktop sidebar hosts the existing studio screens (Reader, Qaidah, Tracing,
Tashkīl, Tajwīd, Reading Coach, Qirā'āt, About) embedded without their own app
bars. Per-screen desktop-specific layouts (multi-column grids, side panels) can be
tailored further on request.

# قِرَاءَة — Qiraah Arabiyyah

A modern, animated Flutter app that takes a learner from their **first alif to the ten Qirā'āt**: reading, writing (tracing with stroke direction), every tashkīl with count training, color-coded Tajwīd with Qur'anic examples, and a dedicated **Reading Coach** for dyslexic learners.

## Run it

```bash
flutter create . --platforms=android,ios,web,macos,windows,linux  # generates platform shells
flutter pub get   # also runs gen-l10n (pubspec `generate: true`)
flutter run
```

Requires Flutter 3.27+ (uses Material 3 `WidgetState*` APIs and `Color.withValues`). The two dependencies are `google_fonts` (Amiri for Qur'anic Arabic, Outfit for UI) and `shared_preferences` (settings + progress).

## Localization (en · ar · ur · fr · es)

Strings live in `lib/l10n/app_<lang>.arb` — one file per language, `app_en.arb`
is the template. `lib/l10n/app_localizations.dart` is **generated** (not checked
in) and appears after:

```bash
flutter gen-l10n     # regenerate on demand
# or simply:
flutter pub get      # runs it too, via `generate: true` in pubspec.yaml
```

Until you run one of those, the `import '../l10n/app_localizations.dart';` in
`lib/core/l10n.dart` is reported as missing — that is expected.

Read a string with `context.l10n.someKey`; a typo is a compile error rather than
a silent fallback. Config lives in `l10n.yaml`. To add a string: put it in
`app_en.arb` (plus `@key` metadata if it takes placeholders), translate it in the
other four, and rerun `flutter gen-l10n`. Any key missing from a locale falls
back to English and is listed in `lib/l10n/untranslated.json` after a build.

Keys must be valid Dart identifiers **and not reserved words** — `continue` has
to be `continueLabel`, since the key becomes a getter name.

## What's inside

| Module | What it covers |
|---|---|
| **Qur'an Reader** | The **whole Qur'an offline** (114 surahs / 6,236 ayahs bundled in assets) in **Madani (Uthmani)** and **IndoPak** scripts, ayah-by-ayah and word-by-word like quran.com. Tap any word to hear it — word-by-word recitation **courtesy of Markaz Tafsir**, served via `audio.qurancdn.com/wbw/sss_vvv_www.mp3`, local-first with a per-surah **offline download** button (skips already-downloaded files). Live font-size slider (persisted), per-word English meanings fetched once per surah from the QUL-backed quran.com API and cached to disk, sequential play of a whole ayah from the word clips, and audio/video buttons that show a "coming soon" notice where media doesn't exist yet. Fonts: Amiri Quran for Madani, Noto Nastaliq Urdu for IndoPak (swap in KFGQPC/QPC fonts for production). Word tokenization merges waqf/annotation signs so word numbering stays aligned with the wbw audio (verified against quran.com word counts). |
| **Qaidah Path** | The full classical Qaidah sequence: 28 letters (forms, dots, Qur'anic example each) → joining forms lab → ḥarakāt → tanwīn → sukūn & qalqalah → shaddah → madd & līn → reading real Qur'anic words → review. Every unit ends in a starred drill. |
| **Tracing Studio** | The signature feature, with a **strict progressive engine**: you must start at the stroke's start point, then *push the mint fill along the path* — it only advances forward, within a tight tolerance and a small look-ahead window, so wrong direction never progresses. Straying off the path or lifting before the end **fails and resets the stroke**. A coral comet shows what's next; the finger halo turns coral the moment you drift. Dots are placed by tap afterwards. Stroke data in `lib/data/strokes.dart` is ordered polylines — swap in calligraphic data anytime. |
| **Tashkīl Lab** | Every mark — fatḥah/kasrah/ḍammah, sukūn, shaddah, all three tanwīn, madd ṭabī'ī (2), līn, maddah, muttaṣil (4–5), munfaṣil (4–5), lāzim (6), 'āriḍ (2/4/6), hamzat al-waṣl — each with a highlighted Qur'anic example and a **Counts Studio**: an animated, haptic metronome for 1/2/4/6-count timing at adjustable tempo. |
| **Tajwīd Academy** | Nūn-sākinah rules (iẓhār, idghām ±ghunnah, iqlāb, ikhfā'), mīm-sākinah rules, ghunnah, qalqalah, all madd categories, lām shamsiyyah/qamariyyah, tafkhīm/tarqīq — each color-coded inside a real verse, plus a spot-the-rule quiz. |
| **Reading Coach** | Dyslexia-friendly mode: one-tap comfort preset (larger glyphs, warm paper, word spacing, focus window) plus fine-grained sliders that apply **app-wide**. Drills: *Spot the Letter* (look-alike families ب ت ث ن ي / ج ح خ / د ذ / ر ز / س ش / ص ض / ط ظ / ع غ / ف ق with optional color-coded dot badges), *Dot Detective*, and a *Fluency Sprint* through al-Fātiḥah word-by-word with a words-per-minute score. |
| **Qirā'āt Hall** | Advanced mode: all ten readers with both rāwīs, signature features (Warsh's 6-count madd, Ibn Kathīr's ṣilah, Ḥamzah's imālah…), and famous side-by-side variants vs Ḥafṣ (1:4 مالك/ملك, 2:9, 2:10, the ṣirāṭ articulations, the single Ḥafṣ imālah in 11:41, munfaṣil lengths). Framed honestly as a *map* — recitation itself needs a teacher with ijāzah. |

**Three themes** — Light, Dark, and pure-black **OLED** — switchable from the home hero chip or Reading-setup panel, built on a mint `#00C9A7` / coral `#FF6B67` / lilac design system. Progress (stars per activity) and all settings persist across launches.

## Architecture

```
assets/quran/   meta.json + per-surah text: u/ (Uthmani) and i/ (IndoPak)
lib/
  core/      theme (3-mode palette + tajwid colors), settings, progress, wbw audio service
  data/      letters, stroke polylines, tashkil, tajwid rules, qira'at, quran repo  ← pure data, easy to extend
  widgets/   TapScale, FadeSlideIn, ProgressRing, StarRow, reusable QuizScreen
  screens/   home, quran reader, qaidah, tracing, tashkeel(+CountsStudio), tajweed, qiraat, dyslexia
```

Content is deliberately separated from engines: the quiz engine, tracing engine, and counts metronome are generic; adding a letter, rule, verse, or qirā'ah is a one-line data edit.

## Accuracy notes (please read)

- Verse texts and rule examples were written carefully, but **have an Arabic-literate reviewer verify every Qur'anic string** before shipping — and ideally replace inline strings with the Tanzil/QPC Uthmani text dataset.
- Tracing polylines are simplified Qaidah-style skeletons (clear, correct direction and stroke order) — not calligraphy. For production, digitize naskh stroke paths and drop them into `strokes.dart`.
- Qirā'āt content is presented as study notes with an in-app disclaimer; this is the correct framing for an app.

## Verse audio finally working (this revision)

The Tunaiji verse audio was failing silently because the legacy quran.com API
(`/resources/recitations`) only exposes 12 reciters and **Tunaiji isn't one of
them** (quran.com serves him through its newer OAuth-gated API). The real source
is EveryAyah — and the earlier 404 was a **casing bug** in the folder name.

Verse audio now streams directly, no API/auth:

    https://everyayah.com/data/khalefa_al_tunaiji_64kbps/{sss}{vvv}.mp3

e.g. `…/002030.mp3` for 2:30. Local-first if downloaded. Every step also logs
under `[AyahAudio]` and failures surface in a SnackBar instead of failing mute.

## Reader UX + IndoPak pause marks (earlier)

- **Retractable header**: the reader control panel now collapses to a thin
  summary bar (tap to expand), and the collapsed state is remembered.
- **Landscape layout**: in landscape the panel lays out horizontally on two
  short rows instead of a tall stack, so the verses are actually visible.
- **Words-per-segment reachable**: the 1–6 chips now wrap, so 5 and 6 are no
  longer cut off, and **word-by-word can be switched off** from the options
  sheet (not just the header).
- **IndoPak stopping points fixed**: 114 waqf/pause marks across 108 IndoPak
  āyāt were standalone tokens that floated away from their word (a
  non-breaking-space artifact). They're now attached to the preceding word in
  the data, the tokenizer no longer inserts a gap, and the IndoPak tajwīd
  spans were regenerated to match — so pause marks sit correctly, like Madani.

## IndoPak rendering + tajwīd (earlier)

- **Crammed reader header redesigned** into clean full-width segmented controls
  (script · font, then word-by-word and size on their own rows) so nothing
  overlaps on narrow phones.
- **Missing-glyph boxes fixed**: the IndoPak text carried 15 small annotation
  marks (e.g. U+0658, U+08E2) that neither bundled IndoPak font has glyphs for,
  so they rendered as □. Those marks are now stripped from the IndoPak data, and
  the word tokenizer merges any stray annotation mark into its neighbour.
- **Char-accurate IndoPak tajwīd**: previously IndoPak only got a crude
  whole-word tint. The verified Madani tajwīd spans are now transferred onto the
  IndoPak text by base-letter (rasm) alignment — all 73,555 spans — so coloring
  is per-letter in IndoPak too, matching Madani. Stored in
  `assets/quran/t_indopak/`.

## Verse audio fix (earlier)

Verse-by-verse recitation (Shaykh Khalifah Al-Tunaiji) previously pointed at a
hard-coded EveryAyah folder that 404'd. It now **resolves through the quran.com v4
API** (the same no-auth host the reader already uses for word meanings):

1. `GET /resources/recitations` → find the Tunaiji ayah-by-ayah recitation by name
   (so a renamed CDN folder can never break it again),
2. `GET /recitations/{id}/by_chapter/{surah}` → the per-ayah relative paths,
3. resolved against `https://verses.quran.com/…`, cached per surah, local-first for
   downloaded audio.

Both the per-ayah play button and the surah download use this path.

## Tracing Studio v5 (earlier this batch)

- **Stroke order from the Markaz Umaza guide**: every letterform's stroke **count, direction, and start point** is now authored to match the official teaching guide — جـ/حـ/خـ draw the head left-to-right *then* the bowl; عـ is two strokes (cup, then tail); صـ's eye runs right then loops back; سـ/شـ teeth are separate strokes; طـ/ظـ lay the body before the standing stem; dots are placed last. All four positions (alone · start · middle · end) follow the guide.
- **Lift and continue**: lifting your finger mid-stroke now *pauses* at the comet instead of snapping back to the start — set the pen back down on the glowing comet and carry on. Wandering off the path also pauses there rather than resetting, so you never lose your place.

## Tracing Studio v4 (earlier)

- **Authentic letterforms**: every stroke skeleton is now machine-extracted from the KFGQPC Uthman Taha glyphs themselves (the same naskh as the reference SVG) — rasterize → skeletonize → calligraphic ordering (eye/loop first from its junction, س/ش teeth as one pen-retrace zigzag, ط/ظ body before stem, tall risers top-down). جـ سـ عـ فـ and friends are no longer hand-drawn approximations.
- **All four positions**: alone · start · middle · end for every letter (connector stubs included), with a position picker; non-connectors (ا د ذ ر ز و) correctly offer only alone/end. 110 generated glyphs in `lib/data/strokes_gen.dart` — regenerate via `pipeline/extract.py`.
- **Word tracing**: ten shaped words (بسم · الله · رب · نور · قل · كتاب · قلم · سلام · يوم · نون) traced right-to-left on a wide board.
- **Memory mode**: a blank board — draw the form yourself, tap its dots, hit **Check**. The evaluator resamples your strokes, solves the best stroke-assignment, and grades shape (symmetric mean distance), pen **direction** (flags reversed strokes), dot placement, and extras — with a per-stroke ✓/✗ report and stars saved separately from Guided mode.
- Uthmani-style dotless isolated/final yā’ gets two synthesized teaching dots.

## New in the previous revision

- **Reader layout controls**: word-gap slider, 1–6 word grouping (remainder becomes a smaller final segment), one-segment-per-line mode, ḥarakāt (tashkīl) hide toggle, and a tajwīd-colors toggle with legend — all in the ⚙ Reader options sheet, all persisted.
- **Tajwīd coloring**: 73,555 rule spans generated at build time against the exact bundled text (ghunnah, idghām ±ghunnah, iqlāb, ikhfā' + shafawī pair, qalqalah incl. ayah-final, madd 2/muttaṣil/munfaṣil/lāzim, lām shamsiyyah, silent letters). Char-accurate in Madani; word-level tint in IndoPak. Auto-disabled while tashkīl is hidden.
- **Verse recitation**: Shaykh Khalifah Al-Tunaiji via EveryAyah, with its own play button per ayah and a per-surah download alongside the word-by-word download (both in the ⬇ menu).
- **Bundled fonts**: KFGQPC Uthmanic Hafs + Scheherazade New for Madani; IndoPak + PDMS Saleem for IndoPak — switchable per script in the reader.
- **Two theme families × three modes**: Mint (Flurent-style) and Noor (warm cream/coral/teal from the design brief), each in Light / Dark / pure-black OLED. Tap the home chip to cycle modes, long-press to swap families (also in Reading setup).
- **Localization**: English, العربية, اردو, Français, Español (app flips RTL for Arabic/Urdu). Core navigation/reader/about strings are translated; remaining screens migrate progressively via `L10n.t`.
- **Tracing v3**: all stroke skeletons redrawn against the Uthmanic Hafs letterforms with correct pen order (ṣād/ṭā eye drawn left-shoulder → right → back left; ʿayn as one continuous cup-then-bowl movement; jīm/sīn/fā single strokes), and rendered/detected as smooth Catmull-Rom curves — no more pointy bends.
- **About page** crediting Markaz Tafsir, Al-Tunaiji, Tanzil/QUL, and the typefaces.
- **AndroidManifest.xml** included with the needed permissions (INTERNET, ACCESS_NETWORK_STATE — nothing else required; downloads use scoped app storage).

## Credits & sources

- **Word-by-word audio:** Markaz Tafsir (via QuranCDN). Credited in the reader footer **and** the About page.
- **Verse recitation:** Shaykh Khalifah Al-Tunaiji, via EveryAyah.com (`{sss}{vvv}.mp3`).
- **Qur'an text:** Tanzil Uthmani (via risan/quran-json) and IndoPak (via fawazahmed0/quran-api), both QUL-compatible; you can re-export the same structures from QUL (qul.tarteel.ai) and drop them into `assets/quran/`.
- **Word meanings:** quran.com v4 API (QUL-backed), fetched once per surah and cached on-device. Fully optional — the reader works offline without it.

Note: `audioplayers`/`path_provider` downloads need mobile/desktop; on web the reader streams audio instead and says so.

## Roadmap to “nothing missing”

1. **Audio** — letter makhārij recordings and verse recitations per riwāyah (`audioplayers` + downloadable packs); tap-to-hear everywhere.
2. **Recording + feedback** — record the learner, compare madd durations against the Counts Studio beat.
3. **Full muṣḥaf reader** with the tajwīd color engine applied automatically (rule detection over the Tanzil text is rule-based and very feasible).
4. **Spaced repetition** scheduling over the existing star data.
5. **More tracing glyphs** — joined forms and full words.
6. **Arabic/localized UI** (the architecture keeps all UI strings in widgets, ready for `intl`).
# qiraah_arrabiyyah
# qiraah_arrabiyyah
