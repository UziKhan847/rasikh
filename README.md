# قِرَاءَة — Qiraah Arabiyyah

A Flutter app that takes a learner from their **first alif to the ten Qirā'āt**:
reading, writing (stroke-direction tracing), every tashkīl mark with count
training, color-coded Tajwīd with real Qur'anic examples, a full offline
Qur'an reader in **Madani** script *and* a true **15-line muṣḥaf**, and a
dedicated **Reading Coach** for learners who struggle with look-alike letters.
Fully localized — **English, العربية, اردو, Français, Español** — with a
responsive layout that runs the same codebase on phone, tablet, and desktop.

## Run it

```bash
flutter create . --platforms=android,ios,web,macos,windows,linux  # generates platform shells
flutter pub get   # also runs gen-l10n (pubspec `generate: true`)
flutter run
```

Requires Flutter 3.27+ (Material 3 `WidgetState*` APIs, `Color.withValues`).
Dependencies: `flutter_localizations` + `intl` (localization), `flutter_svg`,
`shared_preferences` (settings + progress), `audioplayers` (recitation),
`http` + `path_provider` (offline downloads). Amiri (UI + Arabic, with
ScheherazadeNew as its fallback) is bundled as an asset — see
[CREDITS.md](CREDITS.md).

## What's inside

| Module | What it covers |
|---|---|
| **Qur'an Reader** | The whole Qur'an offline (114 sūrahs / 6,236 āyahs bundled in assets), in **Madani (Uthmani)** script, plus a true **15-line muṣḥaf** page (see Credits). IndoPak-script rendering is present in the data layer but currently gated off in the UI (shows "coming soon") pending a properly licensed Indo-Pak Qur'an face — see *Credits & licensing* below. Word-by-word tap-to-hear recitation, courtesy of Markaz Tafsir via QuranCDN; verse-by-verse recitation by Shaykh Khalīfah Al-Tunaiji. Per-surah offline download, char-accurate Tajwīd coloring, adjustable font size/spacing, RTL-correct page header and navigation pinned regardless of UI language. **No word-by-word English translation is shown** — see *Design decisions* below. |
| **Qaidah Path** | The classical Qaidah sequence in nine units: 28 letters (forms, dots, Qur'anic example each) → joining forms (with in-Qur'an examples and beginning/middle/end word cards) → ḥarakāt → tanwīn → sukūn & qalqalah → shaddah → madd & līn → reading real Qur'anic words → review. Every unit ends in a starred quiz. |
| **Tracing Studio** | A strict, progressive stroke engine with **three modes**: **Guided** (a comet leads, the ideal stroke inks itself in), **Outline** (the letterform is shown but you form every stroke — no comet, nothing fills in for you), and **Memory** (a blank board, from memory). All three grade real stroke direction, not just shape, with a per-stroke tolerance and look-ahead window — wrong direction never progresses. Dots are placed by tap afterwards. |
| **Tashkīl Lab** | Every mark — fatḥah/kasrah/ḍammah, sukūn, shaddah, all three tanwīn, madd ṭabī'ī (2), līn, maddah, muttaṣil (4–5), munfaṣil (4–5), lāzim (6), 'āriḍ (2/4/6), hamzat al-waṣl — each with a highlighted Qur'anic example and a **Counts Studio**: an animated, haptic metronome for 1/2/4/6-count timing at adjustable tempo. |
| **Tajwīd Academy** | Nūn-sākinah rules (iẓhār, idghām ±ghunnah, iqlāb, ikhfā'), mīm-sākinah rules, ghunnah, qalqalah, all madd categories, lām shamsiyyah/qamariyyah, tafkhīm/tarqīq — each color-coded inside a real verse, plus a spot-the-rule quiz. In Arabic and Urdu, rule names display as the actual **Arabic term** (إقلاب, غُنَّة…), not a transliteration — see *Localization*. |
| **Reading Coach** | A dyslexia-friendly mode: a one-tap comfort preset (larger glyphs, warm paper, word spacing, a focus window) plus fine-grained sliders that apply app-wide. Drills: *Spot the Letter* (look-alike families, optional color-coded dot badges), *Dot Detective*, a *Fluency Sprint* through al-Fātiḥah with a words-per-minute score, and spaced-repetition *Mistake Review*. |
| **Qirā'āt Hall** | Reader/transmitter data for all ten canonical readers is built and in place, but the hall itself is gated behind a "coming soon" panel on both layouts — it needs a qualified reviewer before it teaches anyone (see *Design decisions*). |

**Three theme modes** (Light / Dark / pure-black OLED) across two families
(Mint, Noor), an app-wide **immersive mode** (hides system bars for reading),
and a streak/star **progress system** that persists across launches.

## Responsive layout: phone, tablet, and desktop from one codebase

`useDesktop(context)` (`lib/core/responsive.dart`) decides which shell renders:

- **Desktop OS** (Linux/Windows/macOS) and **wide web** (≥1024px): the desktop
  shell always applies.
- **Native tablets** (`MediaQuery.shortestSide ≥ 600`, the standard Android
  breakpoint, checked on the *short* side so it survives rotation): the
  desktop shell applies automatically in Auto mode.
- **Phones**: always the mobile shell. This can't be overridden — even an
  explicit "Desktop" setting has no effect on a phone, and the settings picker
  (About → Layout) doesn't offer that option there at all, since the desktop
  shell's sidebar and multi-column layouts don't fit a phone screen regardless
  of what's requested.

A manual override (Auto / Mobile / Desktop, with Desktop hidden on phones)
lives in **About → Layout** and switches live.

## Localization (en · ar · ur · fr · es)

Strings live in `lib/l10n/app_<lang>.arb` — one file per language, `app_en.arb`
is the template — turned into `lib/l10n/app_localizations.dart` (**generated**,
not checked in) via `flutter gen-l10n`. **551 keys, 100% translated in all five
languages.** Config lives in `l10n.yaml`.

```bash
flutter gen-l10n     # regenerate on demand
flutter pub get      # runs it too, via `generate: true` in pubspec.yaml
```

Until you run one of those, the `import '../l10n/app_localizations.dart';` in
`lib/core/l10n.dart` is reported as missing — that's expected, it's generated
code. Read a string with `context.l10n.someKey`; a typo is a compile error
rather than a silent fallback.

Three things worth knowing about how this app approaches localization, beyond
just wiring up strings:

- **Composition over duplication.** Glyph names (300 of them — every letter ×
  every joining form) and tajwīd rule names/notes are not each translated
  individually. Instead, `lib/data/glyph_names.dart` composes them at display
  time from 33 keys (28 letter names + 5 form labels — Alone/Start/Middle/End
  for connecting letters, Alone/Joined for the six that don't connect forward),
  so one set of translations covers all 300 combinations. The 24 traced *words*
  (بسم, الله…) keep their own authored label, since a word isn't decomposable
  the same way. The same file resolves tajwīd rule names so Arabic/Urdu show
  the actual Arabic term while French/Spanish keep the scholarly
  transliteration their own tajwīd literature uses.
- **Quiz answers and their option pools always come from the same helper.**
  If a quiz's correct answer and its multiple-choice pool were generated
  independently, translating one but not the other would silently break the
  quiz in every non-English language. Every quiz in this app (letters, forms,
  tashkīl marks, tajwīd rules, dot counts, timing counts) builds both from one
  shared function.
- **Real ICU plurals**, not string concatenation — Arabic's six-way plural
  (zero/one/two/few/many/other) is handled properly for streaks, counts, and
  review-queue sizes, not just English's one/other.

To add a string: put it in `app_en.arb` (with `@key` placeholder metadata if
needed), translate it in the other four, rerun `flutter gen-l10n`. A key
missing from a locale falls back to English and is listed in
`lib/l10n/untranslated.json` after a build. Keys must be valid Dart
identifiers and not reserved words — `continue` is `continueLabel`, since the
key becomes a getter name.

**Not translated, by design:** the scholarly content in `lib/data/` — the ten
qārīs' biographies (`qiraat.dart`) and the tajwīd rule explanations
(`tajweed.dart`) stay in English pending a qualified reviewer, rather than
being machine-translated into Arabic or Urdu religious/technical writing.

## Design decisions worth knowing about

- **No word-by-word English translation is shown anywhere in the app**,
  including on the home screen's verse-of-the-day. This was a deliberate
  removal, not an oversight: an unreviewed machine/API-sourced translation of
  the Qur'an is worse than none. `QuranRepo.meanings()` and the `votd.dart`
  `tr` field were removed at the data layer, not just hidden in the UI, so
  they can't quietly resurface.
- **The Qirā'āt Hall is gated**, not deleted. The reader/transmitter data is
  fully built (`lib/data/qiraat.dart`); the screen shows a "coming soon" panel
  on both layouts because reciting an actual qirā'ah needs a teacher with
  ijāzah, and this hall is explicitly framed as a map of the subject, not a
  substitute for one.

## Architecture

```
assets/quran/   Qur'an text (Uthmani + IndoPak, the latter currently unused by
                the UI — see Credits) + tajwīd spans + the 15-line muṣḥaf's
                own text/layout JSON
assets/fonts/   UthmanicHafs, ScheherazadeNew, DigitalKhattV2/IndoPak,
                SurahNames, Bismillah, Amiri, Outfit, NotoNastaliqUrdu — all
                bundled locally, no runtime font-fetching — see CREDITS.md
lib/
  core/      theme (2 families × 3 modes + tajwīd colors), settings, progress,
             l10n facade, responsive (phone/tablet/desktop), audio services
  data/      letters, stroke polylines, tashkīl, tajwīd rules, qirā'āt, mushaf
             layout, quran repo, glyph_names.dart (l10n composition helpers)
             ← pure data, easy to extend
  l10n/      app_<lang>.arb × 5 (translations) + generated AppLocalizations
  widgets/   TapScale, FadeSlideIn, ProgressRing, StarRow, reusable QuizScreen
  screens/   home, quran reader, qaidah, tracing, tashkeel (+ CountsStudio),
             tajweed, qiraat, dyslexia, search, about, mushaf
  screens/desktop/  sidebar shell + per-tab desktop layouts
```

Content is deliberately separated from engines: the quiz engine, tracing
engine, and counts metronome are generic; adding a letter, rule, verse, or
qirā'ah is a data edit, not an engine change.

## Accuracy notes (please read before shipping)

- Verse texts and rule examples were written carefully, but **have an
  Arabic-literate reviewer verify every Qur'anic string** before shipping.
- Tracing polylines in `strokes.dart`/`strokes_gen.dart` are machine-extracted
  from the KFGQPC Uthman Taha glyphs with calligraphic stroke ordering — not
  independently reviewed calligraphy.
- The tajwīd rule explanations and qārī biographies in `lib/data/` are
  English-only pending review — see *Localization*, above.

## Credits & licensing

Full third-party attribution — fonts, the Qur'an text sources, recitation,
and, importantly, the **15-line muṣḥaf** (its text, page/line layout data, and
four of its fonts, adapted from Waqar Ahmed's open-source **Quran Revision
Companion**, MIT License) — lives in [CREDITS.md](CREDITS.md), with the actual
license text bundled at `LICENSES/quran_memorization_helper-MIT.txt`. The same
credits appear in-app at **About → Credits & gratitude** and
**About → Sources & Licences**, in all five languages. If you fork or
re-release this app, keep both.

## Roadmap

- [ ] Arabic-literate review pass over every bundled Qur'anic string and the
      tracing letterforms.
- [ ] Qualified-reviewer pass on the tajwīd rule explanations and qārī
      biographies, then translate them (currently English-only by design).
- [ ] Open the Qirā'āt Hall once the above review is done.
- [ ] Spaced-repetition scheduling over the existing star/progress data.
- [ ] More tracing content: joined forms and full words beyond the current
      ten-word set.
- [ ] Letter-makhārij audio recordings.
