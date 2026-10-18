# Qiraah icon font

All the line icons from the prototype are packaged as a TrueType icon font, and you use them exactly like Flutter's `Icons.*`.

## Files
- `flutter/assets/fonts/QiraahIcons.ttf`: the icon font (47 glyphs, Private Use Area U+E001 and up)
- `flutter/lib/qiraah_icons.dart`: the `QiraahIcons` class with `IconData` constants, plus a `QiraahIcons.all` map
- `flutter/lib/qiraah_icons_example.dart`: a gallery widget for checking every glyph
- `flutter/pubspec_snippet.yaml`: font and asset declarations to merge into `pubspec.yaml`
- `icons/svg/*.svg`: the source SVGs (24×24, `currentColor`), for design tools or for `flutter_svg` if needed
- `icons/codepoints.json`: name → codepoint
- `icons/preview.png`: a contact sheet of the font as rendered

## Setup
1. Copy `flutter/assets/fonts/QiraahIcons.ttf` to `<app>/assets/fonts/` and `flutter/lib/qiraah_icons.dart` to `<app>/lib/ui/icons/`.
2. Merge `pubspec_snippet.yaml` into `pubspec.yaml`. The family name must be exactly `QiraahIcons`.
3. Use the icons: `Icon(QiraahIcons.play, size: 24, color: context.qc.ink)`.
4. Release builds tree-shake unused glyphs automatically, because every constant is `const IconData`.

## Design notes
- Every icon is drawn on a 24-unit grid that fills the em box, so `size: 24` matches the prototype 1:1. Common sizes in the prototype are 16, 18, 20 and 22.
- Strokes are already expanded to outlines at the prototype's stroke widths (1.7–2.6), with round caps and joins, so icons scale like any glyph. Tint them with `color`.
- `back`, `chevronLeft` and `chevronRight` set `matchTextDirection: true`, so they mirror in RTL contexts.
- Two-tone icons from the prototype (the tajwīd dots and the active word in `wordByWord`) are single-colour glyphs. For the coloured tajwīd legend, draw three `Container` circles in the tajwīd colours instead.
- The app/launcher glyph (`assets/icon-glyph.png`, icon 1a) is a raster, not part of the font. Use it with `flutter_launcher_icons` (emerald `#0F3B32` background, cream `#F2EEE4` glyph).

## Prototype → icon map
| Dart | Codepoint | Name |
|---|---|---|
| `QiraahIcons.sidebarShow` | 0xe001 | sidebar_show |
| `QiraahIcons.sidebarHide` | 0xe002 | sidebar_hide |
| `QiraahIcons.home` | 0xe003 | home |
| `QiraahIcons.reader` | 0xe004 | reader |
| `QiraahIcons.mushaf` | 0xe005 | mushaf |
| `QiraahIcons.learn` | 0xe006 | learn |
| `QiraahIcons.trace` | 0xe007 | trace |
| `QiraahIcons.tune` | 0xe008 | tune |
| `QiraahIcons.streak` | 0xe009 | streak |
| `QiraahIcons.star` | 0xe00a | star |
| `QiraahIcons.settings` | 0xe00b | settings |
| `QiraahIcons.recite` | 0xe00c | recite |
| `QiraahIcons.check` | 0xe00d | check |
| `QiraahIcons.play` | 0xe00e | play |
| `QiraahIcons.chevronRight` | 0xe00f | chevron_right |
| `QiraahIcons.search` | 0xe010 | search |
| `QiraahIcons.bookmark` | 0xe011 | bookmark |
| `QiraahIcons.chevronDown` | 0xe012 | chevron_down |
| `QiraahIcons.back` | 0xe013 | back |
| `QiraahIcons.gapDecrease` | 0xe014 | gap_decrease |
| `QiraahIcons.gapIncrease` | 0xe015 | gap_increase |
| `QiraahIcons.tajweed` | 0xe016 | tajweed |
| `QiraahIcons.chevronUp` | 0xe017 | chevron_up |
| `QiraahIcons.wordByWord` | 0xe018 | word_by_word |
| `QiraahIcons.unpin` | 0xe019 | unpin |
| `QiraahIcons.close` | 0xe01a | close |
| `QiraahIcons.dragHandle` | 0xe01b | drag_handle |
| `QiraahIcons.dockBottom` | 0xe01c | dock_bottom |
| `QiraahIcons.pause` | 0xe01d | pause |
| `QiraahIcons.skipPrevious` | 0xe01e | skip_previous |
| `QiraahIcons.skipNext` | 0xe01f | skip_next |
| `QiraahIcons.repeat` | 0xe020 | repeat |
| `QiraahIcons.quiz` | 0xe021 | quiz |
| `QiraahIcons.volume` | 0xe022 | volume |
| `QiraahIcons.timer` | 0xe023 | timer |
| `QiraahIcons.reset` | 0xe024 | reset |
| `QiraahIcons.rotate` | 0xe025 | rotate |
| `QiraahIcons.contrast` | 0xe026 | contrast |
| `QiraahIcons.indexList` | 0xe027 | index_list |
| `QiraahIcons.focus` | 0xe028 | focus |
| `QiraahIcons.chevronLeft` | 0xe029 | chevron_left |
| `QiraahIcons.focusExit` | 0xe02a | focus_exit |
| `QiraahIcons.viewSpread` | 0xe02b | view_spread |
| `QiraahIcons.viewSingle` | 0xe02c | view_single |
| `QiraahIcons.fitWidth` | 0xe02d | fit_width |
| `QiraahIcons.starFilled` | 0xe02e | star_filled |
| `QiraahIcons.bookmarkFilled` | 0xe02f | bookmark_filled |

Where they appear:
- **Navigation:** home, reader, mushaf, learn, trace, settings
- **Reader header:** back, mushaf, tajweed, tune, chevronUp
- **Player:** play, pause, skipPrevious, skipNext, repeat, recite, wordByWord, unpin, dockBottom, chevronDown, close, dragHandle
- **Muṣḥaf:** chevronLeft and chevronRight (page turns), rotate (landscape), contrast (page colour), indexList, focus and focusExit, viewSpread, viewSingle, fitWidth
- **Reader controls:** gapDecrease and gapIncrease
- **Other:** sidebarShow and sidebarHide, search, bookmark and bookmarkFilled, star (filled), streak, check, quiz, volume (listen), timer (count trainer), reset (Trace → Clear)

## Adding icons later
Add a 24×24 SVG to `icons/svg/`, then regenerate the font with any SVG-to-font tool that expands strokes (for example `icon_font_generator` after running the SVG through `picosvg`). Keep codepoints U+E001–U+E02F stable and append new icons from U+E030.
