# Qiraah Arabiyyah — Third-party sources & licences

## Fonts (bundled in `assets/fonts/`)
| Font | Source | Licence | Notes |
|---|---|---|---|
| UthmanicHafs.ttf | King Fahd Glorious Quran Printing Complex (KFGQPC) | KFGQPC custom licence — free to use & redistribute, **no modification, no sale** | NOT OSI/FSF-free → F-Droid will treat as a NonFree asset |
| ScheherazadeNew.ttf | SIL International | SIL Open Font License 1.1 | Qur'an-adjacent Arabic UI/body typeface and Urdu's fallback face. **Gap, pre-existing:** unlike the other OFL-licensed fonts here, its licence text isn't yet bundled under `LICENSES/` — needs adding, same as `Inter-OFL.txt`/`NotoNastaliqUrdu-OFL.txt` |
| DigitalKhattV2.otf, DigitalKhattIndoPak.otf | [DigitalKhatt project](https://github.com/DigitalKhatt) — Amine Anane, sponsored by Tarteel Inc.; bundled via Waqar Ahmed's [Quran Revision Companion](https://github.com/Waqar144/quran_memorization_helper) | **SIL Open Font License 1.1** — licence text at `LICENSES/DigitalKhatt-OFL.txt`. (The MIT covers Waqar Ahmed's app that redistributed them, not the fonts themselves: both binaries declare OFL 1.1 in their own `name` table, nameID 13, with the copyright at nameID 0.) | Powers the 15-line muṣḥaf page; DigitalKhattIndoPak also renders the card reader's Indo-Pak script, and DigitalKhattV2 is the reader's optional Madani typeface |
| SurahNames.ttf, Bismillah.ttf | Waqar Ahmed's [Quran Revision Companion](https://github.com/Waqar144/quran_memorization_helper) | MIT License | Ornamental glyphs for the 15-line muṣḥaf headers |
| Inter-Regular/Medium/SemiBold/Bold.ttf | [Inter](https://github.com/rsms/inter) (via Google Fonts) | SIL Open Font License 1.1 | Latin-language (English/French/Spanish) UI typeface of the redesign — licence text at `LICENSES/Inter-OFL.txt`. Static instances (opsz 14) cut from the upstream variable font: a variable (gvar) font is a known trigger for Skia text-shaper hangs on some Android GPU/driver combinations |
| SourceSerif4-Regular/Medium.ttf | [Source Serif 4](https://github.com/adobe-fonts/source-serif) (Adobe, via Google Fonts) | SIL Open Font License 1.1 | Display headings of the redesign — licence text at `LICENSES/SourceSerif4-OFL.txt`. Static instances (opsz 32), for the same Skia reason |
| NotoNaskhArabic-Regular/SemiBold/Bold.ttf | [Noto Naskh Arabic](https://github.com/notofonts/arabic) (via Google Fonts) | SIL Open Font License 1.1 | Arabic letters and the Arabic-language UI — licence text at `LICENSES/NotoNaskhArabic-OFL.txt`. Static instances |
| QiraahIcons.ttf | The app's own icon font, from the design handoff (`design_handoff_qiraah_flutter/`) | Project asset | Every UI icon (`lib/ui/qiraah_icons.dart`, mapped in `lib/ui/app_icons.dart`) |
| NotoNastaliqUrdu-Variable.ttf | [Noto Nastaliq Urdu](https://github.com/notofonts/nastaliq) | SIL Open Font License 1.1 | Urdu-language UI typeface — licence text at `LICENSES/NotoNastaliqUrdu-OFL.txt` |

### Removed: PDMSSaleem.ttf, IndoPak.ttf
Both were removed before the Play Store submission (2026-07-28) and are no
longer bundled. PDMS Saleem's EULA (from pakdata.com) grants free *use* but
clause 1 forbids redistribution without a separate licence from PDMS, and
clause 3 forbids modification/adaptation — bundling it in the app is
redistribution. IndoPak.ttf's provenance was unverified and it had become
unused (the app was already steering Indo-Pak readers to PDMS Saleem).
Neither is needed: **both** the card reader and the 15-line muṣḥaf render
Indo-Pak with DigitalKhattIndoPak.otf, already bundled for the muṣḥaf above.
The reader's text uses a different codepoint convention for a couple of marks
than the font (and the muṣḥaf's own corpus) expect — see the 1:1 transcode in
`QuranRepo._transcodeIndopak` (`lib/data/quran.dart`) — but no separate font
or licence is involved.

## 15-line muṣḥaf (text + layout data, `assets/quran/mushaf_*.json`)
The Madani- and Indo-Pak-script 15-line page/line breaks, and the fonts above,
are adapted from **Waqar Ahmed's** open-source app **Quran Revision Companion**
(F-Droid: `com.wqar.quran_mem_helper`; source: <https://github.com/Waqar144/quran_memorization_helper>),
**MIT License**. The underlying parametric typesetting is the
[DigitalKhatt](https://github.com/DigitalKhatt) project. His copyright notice
and the full license text are bundled at
`LICENSES/quran_memorization_helper-MIT.txt`, per the MIT License's
requirement to preserve them in any redistribution — keep both that file and
the in-app credit (About → Sources & Licences, and About → Credits &
gratitude) in any fork or re-release.

## Qur'an text (bundled in `assets/quran/`)
Uthmani (Madani) & IndoPak texts, Tanzil / QUL-compatible datasets.
Tanzil terms: attribution required; the text must not be altered. The app ships
the text verbatim (tokenized only); tashkīl-stripping is a display option.

The exceptions are three load-time codepoint substitutions, all 1:1 and
length-preserving, and reversible (the shipped asset files themselves are
untouched):

- **A data-correctness fix, always, on every Uthmani load**: U+0652→U+06DF,
  wherever U+0652 sits on ا, و or ي. The reader's `assets/quran/u/` marks a
  written-but-silent letter (the farqa alif after وا, the silent wāw of
  أُو۟لَـٰٓئِكَ, and the like) with U+0652 ARABIC SUKUN, which means "no vowel
  on an otherwise pronounced consonant" — wrong for a letter that isn't
  pronounced at all. The 15-line muṣḥaf's own corpus already uses the correct
  mark, U+06DF ARABIC SMALL HIGH ROUNDED ZERO (Unicode's own definition: "used
  in the Qurʼān to indicate a letter that is not pronounced"), so this brings
  the reader into agreement with it. Confirmed safe by an exhaustive scan of
  the whole corpus: U+0652 never once falls on any other letter, so this can
  never touch a real sukūn (which the corpus writes with the separate U+06E1).
  See `QuranRepo._fixSilentLetterMark`.
- **Indo-Pak, always**: U+06E1→U+0652, U+06E0→U+06DF, to match
  DigitalKhattIndoPak.otf. See `QuranRepo._transcodeIndopak`.
- **Madani/Uthmani, on top of the fix above**: U+0657→U+08F0, U+065E→U+08F1,
  U+0656→U+08F2 — the same three open-tanwīn marks in the two Unicode
  conventions, which is exactly how the muṣḥaf's own Uthmani corpus writes
  them — plus U+06E4→U+0653, which is an **approximation** rather than a
  re-encoding: the full-size maddah stands in for the small high one, in 26
  characters across the 15 sajdah verses, because DigitalKhattV2.otf has no
  glyph for U+06E4 and the muṣḥaf corpus omits it entirely. This one is a
  font-compatibility transcode, not a correctness fix, and applies only when
  rendering with DigitalKhattV2 — the reader's one Madani face. See
  `QuranRepo._transcodeUthmaniKhatt`.

None of these are a wording, reading, or orthography change. All three are
pinned by tests (`test/uthmani_silent_letter_test.dart`,
`test/indopak_transcode_test.dart`, `test/uthmani_khatt_transcode_test.dart`)
that assert character count, word count and word boundaries are unchanged
across all 6,236 āyāt.
The 15-line page/line text is a separate dataset — see the section above.

## Audio (streamed, not bundled)
- Verse recitation: Shaykh Khalifah Al-Tunaiji — EveryAyah.com (free to use; credit).
- Word-timed recitation: Al-ʿAfāsī & Al-Ḥuṣarī — timings and audio URLs from the
  Quran.com (Quran Foundation) QDC API, served from verses.quran.com; Ḥuṣarī's
  audio specifically comes back host-qualified to mirrors.quranicaudio.com.
- Word-by-word audio: Quran.com / QuranCDN, courtesy Markaz Tafsir. (No word
  meanings/translations are fetched or shown anywhere in the app — see
  *Design decisions* in README.md.)

## Data
- Qirā'āt reader biographies: facts summarized from abouttajweed.com.
- Tajwīd rules, letter data, drills: original to this app.

## Flutter packages
audioplayers (MIT) · flutter_svg (MIT) · http (BSD-3) · path_provider (BSD-3) ·
shared_preferences (BSD-3).
All compatible with Play Store & F-Droid; licences surface in-app via
About → Open-source licences.

## App licence
Not yet chosen. F-Droid requires a free licence for the app code itself
(GPL-3.0-or-later or MIT recommended). Add a LICENSE file before submission.
