# Qiraah Arabiyyah — Third-party sources & licences

## Fonts (bundled in `assets/fonts/`)
| Font | Source | Licence | Notes |
|---|---|---|---|
| UthmanicHafs.ttf | King Fahd Glorious Quran Printing Complex (KFGQPC) | KFGQPC custom licence — free to use & redistribute, **no modification, no sale** | NOT OSI/FSF-free → F-Droid will treat as a NonFree asset |
| ScheherazadeNew.ttf | SIL International | SIL Open Font License 1.1 | Free — include the OFL text |
| IndoPak.ttf | IndoPak/Nastaliq Quran font (community distribution) | Licence unverified | Verify origin before store submission |
| PDMSSaleem.ttf | Pakistan Data Management Services | Freeware, terms unverified | Currently unused in UI; consider removing |
| DigitalKhattV2.otf, DigitalKhattIndoPak.otf | [DigitalKhatt project](https://github.com/DigitalKhatt) (sponsored by Tarteel AI); bundled via Waqar Ahmed's [Quran Revision Companion](https://github.com/Waqar144/quran_memorization_helper) | See DigitalKhatt repo; app bundling it is MIT | Powers the 15-line muṣḥaf page |
| SurahNames.ttf, Bismillah.ttf | Waqar Ahmed's [Quran Revision Companion](https://github.com/Waqar144/quran_memorization_helper) | MIT License | Ornamental glyphs for the 15-line muṣḥaf headers |
| Amiri-Regular.ttf, Amiri-Bold.ttf | [Amiri](https://github.com/aliftype/amiri) | SIL Open Font License 1.1 | App-wide UI + Arabic typeface (ScheherazadeNew is the fallback) — licence text at `LICENSES/Amiri-OFL.txt` |

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
The 15-line page/line text is a separate dataset — see the section above.

## Audio (streamed, not bundled)
- Verse recitation: Shaykh Khalifah Al-Tunaiji — EveryAyah.com (free to use; credit).
- Word-timed recitation: Al-ʿAfāsī & Al-Ḥuṣarī — Quran.com QDC API (attribution).
- Word-by-word audio & meanings: Quran.com / QuranCDN, courtesy Markaz Tafsir.

## Data
- Qirā'āt reader biographies: facts summarized from abouttajweed.com.
- Tajwīd rules, letter data, drills: original to this app.

## Flutter packages
audioplayers (MIT) · http (BSD-3) · path_provider (BSD-3) ·
shared_preferences (BSD-3).
All compatible with Play Store & F-Droid; licences surface in-app via
About → Open-source licences.

## App licence
Not yet chosen. F-Droid requires a free licence for the app code itself
(GPL-3.0-or-later or MIT recommended). Add a LICENSE file before submission.
