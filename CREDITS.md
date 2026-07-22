# Qiraah Arabiyyah — Third-party sources & licences

## Fonts (bundled in `assets/fonts/`)
| Font | Source | Licence | Notes |
|---|---|---|---|
| UthmanicHafs.ttf | King Fahd Glorious Quran Printing Complex (KFGQPC) | KFGQPC custom licence — free to use & redistribute, **no modification, no sale** | NOT OSI/FSF-free → F-Droid will treat as a NonFree asset |
| ScheherazadeNew.ttf | SIL International | SIL Open Font License 1.1 | Free — include the OFL text |
| IndoPak.ttf | IndoPak/Nastaliq Quran font (community distribution) | Licence unverified | Verify origin before store submission |
| PDMSSaleem.ttf | Pakistan Data Management Services | Freeware, terms unverified | Currently unused in UI; consider removing |

## Runtime font (google_fonts package)
Outfit (UI) + Amiri fallback are fetched at runtime from Google Fonts (both OFL).
**F-Droid note:** runtime fetching is discouraged — bundle these as assets and
drop the `google_fonts` dependency for the F-Droid build.

## Qur'an text (bundled in `assets/quran/`)
Uthmani (Madani) & IndoPak texts, Tanzil / QUL-compatible datasets.
Tanzil terms: attribution required; the text must not be altered. The app ships
the text verbatim (tokenized only); tashkīl-stripping is a display option.

## Audio (streamed, not bundled)
- Verse recitation: Shaykh Khalifah Al-Tunaiji — EveryAyah.com (free to use; credit).
- Word-timed recitation: Al-ʿAfāsī & Al-Ḥuṣarī — Quran.com QDC API (attribution).
- Word-by-word audio & meanings: Quran.com / QuranCDN, courtesy Markaz Tafsir.

## Data
- Qirā'āt reader biographies: facts summarized from abouttajweed.com.
- Tajwīd rules, letter data, drills: original to this app.

## Flutter packages
audioplayers (MIT) · http (BSD-3) · path_provider (BSD-3) ·
shared_preferences (BSD-3) · google_fonts (Apache-2.0).
All compatible with Play Store & F-Droid; licences surface in-app via
About → Open-source licences.

## App licence
Not yet chosen. F-Droid requires a free licence for the app code itself
(GPL-3.0-or-later or MIT recommended). Add a LICENSE file before submission.
