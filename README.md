# قِرَاءَة — Qiraah Arabiyyah

A Flutter app that takes a learner from their **first alif to the ten Qirā'āt**:
reading, writing (stroke-direction tracing), every tashkīl mark with count
training, a full Tajwīd Academy (articulation points, letter qualities, every
rule family, muṣḥaf-specific special cases), a **Script & Symbols** reference
for Madani-vs-IndoPak orthography, a full offline Qur'an reader in **Madani**
script *and* a true **15-line muṣḥaf** with downloadable offline recitation,
and a dedicated **Reading Coach** for learners who struggle with look-alike
letters. Fully localized — **English, العربية, اردو, Français, Español** —
with a responsive layout that runs the same codebase on phone, tablet, and
desktop.

## Run it

```bash
flutter create . --platforms=android,ios,web,macos,windows,linux  # generates platform shells
flutter pub get   # also runs gen-l10n (pubspec `generate: true`)
flutter run
```

Requires Flutter 3.27+ (Material 3 `WidgetState*` APIs, `Color.withValues`).
Dependencies: `flutter_localizations` + `intl` (localization), `flutter_svg`,
`shared_preferences` (settings + progress), `audioplayers` (recitation),
`http` + `path_provider` (offline downloads), `flutter_local_notifications` +
`timezone` + `flutter_timezone` (the optional daily reminder). All typefaces (Qur'an script,
UI, Arabic body text) are bundled assets — no font is ever fetched over the
network.

## What's inside

| Module | What it covers |
|---|---|
| **Qur'an Reader** | The whole Qur'an offline (114 sūrahs / 6,236 āyahs bundled in assets), in both **Madani (Uthmani)** and **IndoPak** script, plus a true **15-line muṣḥaf** page (see Credits). Both scripts render with a DigitalKhatt face — DigitalKhattIndoPak for IndoPak, DigitalKhattV2 (also the 15-line muṣḥaf's own) for Madani, chosen over UthmanicHafs for how much more carefully it stacks marks (276 GPOS lookups against 21 — visible on a dagger alif crowded against a fatḥah). Each script's text is transcoded at load time to the codepoints its face actually has glyphs for, plus one data fix applied to every Uthmani load regardless of face: a written-but-silent letter (the farqa alif after وا, e.g.) now carries the correct Unicode mark for that, not a sukūn (see *Credits & licensing* below). Word-by-word tap-to-hear recitation, courtesy of Markaz Tafsir via QuranCDN; verse-by-verse recitation by Shaykh Khalīfah Al-Tunaiji, Mishary Al-ʿAfāsī, or Maḥmūd Al-Ḥuṣarī (the latter two also word-timed, for read-along highlighting). Per-surah offline download, plus a dedicated **Downloads manager** (Settings → Downloads) for bulk-downloading/deleting recitation and word-by-word audio across all 114 sūrahs with per-category storage totals — see *Data, downloads & privacy* below. Char-accurate Tajwīd coloring, adjustable font size/spacing, RTL-correct page header and navigation pinned regardless of UI language. **No word-by-word English translation is shown** — see *Design decisions* below. |
| **Qaidah Path** | The classical Qaidah sequence in eleven units: 28 letters + 8 extra letters (hamzah's seated forms, ة, ى, ٱ) and the 3 small letters (dagger alif, small wāw/yāʾ) → joining forms, including a **Special Shapes** section of hand-drawn muṣḥaf ligatures (kāf wrapping alif/lām, lām-alif, letter-stacking) for forms a font can't render correctly in isolation → ḥarakāt → tanwīn (with its two written shapes — see *Script & Symbols*) → sukūn & qalqalah → shaddah → madd & līn → reading real Qur'anic words → **waṣl** (hamzat al-waṣl, sun/moon letters) → **ḥurūf muqaṭṭaʿāt** (the disjointed letters opening 29 sūrahs, with their per-letter madd counts) → review. Every unit ends in a starred quiz. Each of the 28 letters' own detail page carries **Listen** (the letter's own sound via `letter_audio.dart`, never a verse — an honest "coming soon" until real clips are bundled) and **Watch**, a real stroke-by-stroke replay built from the Tracing Studio's own stroke data (`TracingBoard`'s `watch` mode) rather than a video stub. |
| **Tracing Studio** | A strict, progressive stroke engine with **three modes**: **Guided** (a comet leads, the ideal stroke inks itself in), **Outline** (the letterform is shown but you form every stroke — no comet, nothing fills in for you), and **Memory** (a blank board, from memory). All three grade real stroke direction, not just shape, with a per-stroke tolerance and look-ahead window — wrong direction never progresses. Dots are placed by tap afterwards. |
| **Tashkīl Lab** | Every mark — fatḥah/kasrah/ḍammah, sukūn, shaddah, all three tanwīn, madd ṭabī'ī (2), līn, maddah, muttaṣil (4–5), munfaṣil (4–5), lāzim (6), 'āriḍ (2/4/6), hamzat al-waṣl — each with a highlighted Qur'anic example and a **Counts Studio**: an animated, haptic metronome for 1/2/4/6-count timing at adjustable tempo. |
| **Tajwīd Academy** | Restructured as nine units, each a Learn → Letters/Test → Practice → Recite hub (mirroring the Qaidah Path's pattern): **Makhārij** (the 17-point/5-zone articulation scheme), **Ṣifāt** (all 15 classical letter qualities, both opposed pairs and standalone), then the rule families — **Nūn Sākinah & Tanwīn**, **Mīm Sākinah & Ghunnah**, **Madd**, **Lām Rules** (shamsiyyah/qamariyyah + lām al-jalālah), **Rules of Rā'** (tafkhīm/tarqīq), **Qalqalah** — and **Special Cases** (saktah, sīn-written-over-ṣād, *al-ān*'s ishmām, tashīl, imālah, and the compressed doubled-nūn spelling), each tied to exact muṣḥaf spots found programmatically, not hand-picked. Every rule is color-coded inside a real verse with a spot-the-rule quiz. **Recite is present but always "coming soon"** on every unit — there's no voice-input pipeline in the app yet (see *Design decisions*). In Arabic and Urdu, rule names display as the actual **Arabic term** (إقلاب, غُنَّة…), not a transliteration — see *Localization*. |
| **Script & Symbols** | A reference module, not a beginner path — every unit is Learn → Test → Practice, nothing locked. **Script Families** contrasts the same āyah across the bundled Madani and IndoPak corpora (hamzat al-waṣl as ٱ vs plain ا, the two silent-alif marks IndoPak collapses into one, tanwīn-meets-waṣl spelling, the sajdah ۩ glyph, tanwīn's stacked-vs-parallel default shape, which waqf marks appear). **Marks & Signs** covers tanwīn's two allograph shapes, the small letters, and the "two zeros." **Waqf & Stopping** covers all six stop marks. **Page Marks** covers sajdah and rubʿ al-ḥizb. |
| **Reading Coach** | A dyslexia-friendly mode: a one-tap comfort preset (larger glyphs, warm paper, word spacing, a focus window) plus fine-grained sliders that apply app-wide, including a toggle for **IndoPak tashkīl-mark names** (Zabar/Paish/Zair… in place of Fatḥah/Ḍammah/Kasrah…, defaulting on for Urdu on first run, overridable). Drills: *Spot the Letter* (look-alike families, optional color-coded dot badges), *Dot Detective*, a *Fluency Sprint* through al-Fātiḥah with a words-per-minute score, and spaced-repetition *Mistake Review*. |
| **Hifz (listening marks)** | A listener marks a recitation word by word on the 15-line muṣḥaf or in the reader — **mistake**, **tajwīd**, **hesitation** (self-corrected), **doubt** (had to be told) or a **note** — with a pen bar: pick a pen, tap words, tap again to remove, undo. Marks are stored by (sūrah, āyah, word) in the muṣḥaf's own word numbering, which the Madani and Indo-Pak texts share word for word (77,432 words), so a mark shows on the **same word in either script** (the reader's differently-split Tanzil text maps through a generated table, `lib/core/marks/card_align.g.dart`). Each word shows a tint plus a per-type pattern line drawn below the kasrahs. Marks belong to **mark books** (one per reciter) and **sessions** (sabaq / sabqi / manzil); an earlier mistake can later be **marked fixed**. **Statistics** by type, sūrah, juzʼ and page (a heatmap per script — Madani 604, Indo-Pak 610 pages), per session and over time, plus words marked more than once. Optional **sync** to a self-hosted PocketBase (see `server/README.md`): share a book with a code, listeners mark live, a checker reads and comments. |
| **Qirā'āt Hall** | Reader/transmitter data for all ten canonical readers is built and in place, but the hall itself is gated behind a "coming soon" panel on both layouts — it needs a qualified reviewer before it teaches anyone (see *Design decisions*). |

Around the modules: a **Today** screen (continue reading, streak and a daily
goal in minutes, verse of the day, today's lesson), **bookmarks** and
last-read position, a first-launch **welcome**, an optional **daily
reminder** (a local notification), **four themes** (Light, Mono, Night,
pure-black OLED) with optional ornate borders and gradients, an app-wide
**immersive mode**, and a streak/star **progress system** that persists
across launches.

### The design

The interface follows the design handoff in `design_handoff_qiraah_flutter/`
(colour tokens, type, the QiraahIcons font, ornaments and the prototype). The
handoff covered the main screens; the rest of the app was redesigned in the
same language. Where the build departs from it on purpose:

- The **15-line muṣḥaf keeps the DigitalKhatt fonts and the 604/610-page
  line layout**; only the chrome around it follows the design. The line data
  has no kashida, so lines are justified by widening the gaps between words.
  To keep those gaps print-like, each page's text is sized to its width and
  lines sit ~1.8 em apart (`MushafGeometry` in `lib/data/mushaf.dart`).
- The **daily goal is in minutes** everywhere (the prototype mixed pages and
  minutes).
- Light `ink3`/`mut` are a shade darker than the handoff's 6.9 values so hint
  text reaches 4.5:1 on the page background, not just on cards.
- Icons the font doesn't cover yet use neutral stand-ins, listed for drawing
  in [docs/icons_needed.md](docs/icons_needed.md).

## Data, downloads & privacy

No analytics, no ads, no tracking, and no account needed — the full policy is
at [docs/privacy-policy.html](docs/privacy-policy.html). In short:

- **Progress, settings, and downloaded audio stay on-device.** Everything is
  local storage (`SharedPreferences` for progress/settings, the app's own
  documents directory for downloaded audio) — nothing is uploaded anywhere.
- **Hifz marks are local too, unless you opt in to sync.** They live in
  `<app support>/marks/` (`lib/core/marks/`). Signing in to a marks account
  (username + password; email optional, for password reset only) syncs only
  the mark books you choose, to the project's own self-hosted PocketBase
  server (`server/`). Accounts can be deleted in the app or on the server's
  `delete-account.html` page.
  Settings → Your data offers a one-file local backup/restore (`BackupService`
  in `lib/core/settings.dart`) that never leaves the device unless you move
  the file yourself.
- **Recitation audio is fetched from its reciter's own host**, streamed or
  downloaded via the **Downloads manager** (`lib/core/downloads.dart`,
  `lib/screens/downloads_screen.dart`): `everyayah.com` (Al-Tunaiji,
  Al-ʿAfāsī, Al-Ḥuṣarī verse audio), the Quran.com/Quran Foundation QDC API
  (`api.quran.com` / `verses.quran.com`, plus its `quranicaudio.com` media
  mirrors, for word-timed recitation), and `audio.qurancdn.com` (word-by-word
  audio, courtesy Markaz Tafsir). See *Credits & licensing* for full
  attribution.
- **A small on-device log tracks download freshness.** `lib/core/audio.dart`'s
  `_FetchLog` records a local timestamp per downloaded quran.com/quranicaudio.com
  file (never for EveryAyah files) so `refreshStaleQuranCache()` can silently
  re-fetch anything older than 7 days when the Downloads screen opens — this
  satisfies Quran Foundation's terms for offline-cached content. It's a
  local, timestamp-only log; nothing about it is sent anywhere beyond the
  ordinary re-download request.
- **The daily reminder is local.** If turned on (Settings → Learning), the
  device schedules one notification a day at the chosen time
  (`lib/core/reminder.dart`); nothing is sent anywhere.
- **Every typeface is bundled** — see *Run it*, below. No font is ever
  fetched over the network.

## Responsive layout: phone, tablet, and desktop from one codebase

`useDesktop(context)` (`lib/core/responsive.dart`) decides which shell renders
(`lib/screens/shell/app_shell.dart`): bottom tabs (Today · Reader · Muṣḥaf ·
Learn · Trace) on a phone, a collapsible sidebar on desktop. Every screen is
one responsive widget — there are no separate desktop copies.

- **Desktop OS** (Linux/Windows/macOS) and **wide web** (≥1024px): the desktop
  shell always applies.
- **Native tablets** (`MediaQuery.shortestSide ≥ 600`, the standard Android
  breakpoint, checked on the *short* side so it survives rotation): the
  desktop shell applies automatically in Auto mode.
- **Phones**: always the mobile shell. This can't be overridden — even an
  explicit "Desktop" setting has no effect on a phone, and the settings picker
  (Settings → Layout) doesn't offer that option there at all, since the desktop
  shell's sidebar and multi-column layouts don't fit a phone screen regardless
  of what's requested.

A manual override (Auto / Mobile / Desktop, with Desktop hidden on phones)
lives in **Settings → Layout** and switches live.

## Localization (en · ar · ur · fr · es)

Strings live in `lib/l10n/app_<lang>.arb` — one file per language, `app_en.arb`
is the template — turned into `lib/l10n/app_localizations.dart` (**generated**,
not checked in) via `flutter gen-l10n`. **766 keys, 100% translated in all five
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
- **Every Tajwīd Academy unit's Recite phase is present but locked**, the
  same treatment: there's no voice-input pipeline in the app, so a phase that
  would need one is shown, not hidden, and taps through to "coming soon"
  rather than being silently absent from the hub.
- **A few Joining Forms "Special Shapes" are locked pending hand-drawn art.**
  Rendering these shapes as font-shaped text was actively wrong — isolating
  a contextual-form fragment made the font fall back to its default
  (isolated) glyph, not the shape being taught — so a shape with no
  hand-drawn SVG yet is shown dimmed with a "coming soon" tap-through rather
  than kept as a text tile that renders the wrong glyph.

## Architecture

```
assets/quran/         Qur'an text (Uthmani + IndoPak, both available in the
                       card reader and the 15-line muṣḥaf; see Credits) +
                       tajwīd spans + the 15-line muṣḥaf's own text/layout JSON
assets/fonts/          Inter (UI), Source Serif 4 (display), Noto Naskh Arabic,
                       NotoNastaliqUrdu, UthmanicHafs, DigitalKhattV2/IndoPak,
                       SurahNames, Bismillah, QiraahIcons (the icon font) — all
                       bundled locally, no runtime font-fetching — see CREDITS.md
assets/special_cases/  Hand-drawn SVGs for muṣḥaf ligatures/letter-stacking a
                       font can't render correctly in isolation (Joining
                       Forms' Special Shapes — see *What's inside*)
lib/
  core/      theme (four themes' tokens, muṣḥaf papers, gradients, type),
             settings, progress (incl. bookmarks, last read, minutes), l10n
             facade, responsive (phone/tablet/desktop), audio services
             (streaming + offline caching), downloads.dart (bulk offline
             audio), reminder.dart (daily notification), reader_size.dart
  ui/        the design kit (cards, rows, buttons, segmented controls…),
             app_icons.dart (every icon, by use), the QiraahIcons font class,
             ornaments (rosette, āyah marker, sūrah header), brand
  data/      letters (+ extra/small letters), stroke polylines, tashkīl,
             tajwīd rules + muṣḥaf-specific cases, makhārij, ṣifāt,
             muqaṭṭaʿāt, script differences, tanwīn allographs, qirā'āt,
             mushaf layout, quran repo, special_shapes.dart, glyph_names.dart
             (l10n composition helpers) ← pure data, easy to extend
  l10n/      app_<lang>.arb × 5 (translations) + generated AppLocalizations
  widgets/   TapScale, FadeSlideIn, ProgressRing, StarRow, reusable QuizScreen,
             lesson.dart (a shared LessonNode/LessonDetail tree — picker →
             detail page — now backing Qaidah's Joining Forms, the whole
             Tajwīd Academy, and Script & Symbols' Learn phases), common.dart
             (PhaseHub/UnitPhase — the shared Learn→Test→Practice→Recite hub)
  screens/   today, learn, settings, onboarding, quran list + reader, mushaf,
             qaidah, tracing, tashkeel (+ CountsStudio), tajweed, script,
             qiraat, dyslexia (Reading Coach), search, about, downloads
  screens/shell/  app_shell.dart (tabs / sidebar), modules.dart (the seven
             Learn modules)
  screens/lessons/  per-module lesson trees built on widgets/lesson.dart:
             qaidah_lessons.dart, forms_lessons.dart, tajwid_lessons.dart,
             script_lessons.dart; forms_quizzes.dart holds the joining-form
             question shapes for the Qaidah unit
tools/
  recording_studio/  a browser page for recording the letter/syllable audio
             and lesson videos, exporting a zip named for the app
  icons/     make_launcher_icons.py (every platform's launcher icon)
```

Content is deliberately separated from engines: the quiz engine, tracing
engine, lesson-tree engine, and counts metronome are generic; adding a
letter, rule, verse, or qirā'ah is a data edit, not an engine change.

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
- [ ] A voice-input pipeline for the Tajwīd Academy's Recite phase (currently
      "coming soon" on every unit — see *Design decisions*).
- [ ] Hand-drawn art for the remaining locked Special Shapes, and real
      Qur'anic examples for the newly added ones (see `special_shapes.dart`).
