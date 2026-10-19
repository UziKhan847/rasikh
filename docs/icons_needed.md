# Icons still needed (for Claude Design)

The app's icons all go through `lib/ui/app_icons.dart`. Most already use the redesign's **QiraahIcons** font (47 glyphs, U+E001–U+E02F). The ones below are still **stand-ins** — a neutral Material Rounded icon — until a matching Qiraah glyph is drawn.

## How to draw them

- Same family as the existing QiraahIcons (`design_handoff_qiraah_flutter/icons/svg/` has the 47 sources to match):
  - a 24-unit grid that fills the em box;
  - line icons, strokes 1.7–2.6 units, **round caps and joins**, expanded to outlines;
  - single colour (tinted in the app); no fills except where the existing set uses them (filled star, filled bookmark, play).
- Directional icons (anything with an arrow) should be drawn pointing **right/forward**; the app mirrors them in RTL.
- Deliver them as SVGs plus an updated `QiraahIcons.ttf` (with `codepoints.json`), continuing the codepoints from **U+E030**. The suggested codepoint for each is in the table.
- Swapping one in is a one-line change in `app_icons.dart` (`static const tashkil = QiraahIcons.tashkil;`).

## The 39 icons

| # | Name (`AppIcons.`) | Suggested codepoint | Used for | Stand-in today (Material) |
|---|---|---|---|---|
| 1 | `coach` | U+E030 | Reading Coach module; Spot the Letter drill | `remove_red_eye_rounded` |
| 2 | `stop` | U+E031 | Players: stop recitation | `stop_rounded` |
| 3 | `mic` | U+E032 | Tajwīd “Recite” phase (coming soon) | `mic_none_rounded` |
| 4 | `video` | U+E033 | Lesson “Watch” buttons | `ondemand_video_rounded` |
| 5 | `lock` | U+E034 | Locked/coming-soon lessons and phases | `lock_outline_rounded` |
| 6 | `textSize` | U+E035 | Arabic text-size controls | `text_fields_rounded` |
| 7 | `gridView` | U+E036 | Word-grid layout, Tajwīd letters phase | `grid_view_rounded` |
| 8 | `shapeHeight` | U+E037 | Joining Forms: heights & tails | `height_rounded` |
| 9 | `shapeJoin` | U+E038 | Joining Forms: how letters join | `link_rounded` |
| 10 | `shapeRoute` | U+E039 | Joining Forms: the kāf route | `route_rounded` |
| 11 | `shapeStack` | U+E03A | Joining Forms: stacking | `layers_rounded` |
| 12 | `bolt` | U+E03B | Fluency Sprint | `bolt_rounded` |
| 13 | `comfort` | U+E03C | Reading Coach comfort preset | `auto_fix_high_rounded` |
| 14 | `dots` | U+E03D | Dot Detective; colour-coded dots | `blur_on_rounded` |
| 15 | `zoom` | U+E03E | Tracing board: reset zoom | `zoom_out_map_rounded` |
| 16 | `dot` | U+E03F | Qirāʾāt reader list bullet | `brightness_1` |
| 17 | `speed` | U+E040 | Counts Studio tempo | `speed_rounded` |
| 18 | `bell` | U+E041 | Settings: daily reminder | `notifications_none_rounded` |
| 19 | `download` | U+E042 | Downloads: download | `download_rounded` |
| 20 | `upload` | U+E043 | Backup: export | `upload_rounded` |
| 21 | `delete` | U+E044 | Downloads: delete | `delete_outline_rounded` |
| 22 | `sync` | U+E045 | Downloads: check for updates | `sync_rounded` |
| 23 | `partial` | U+E046 | Downloads: partly downloaded | `incomplete_circle_rounded` |
| 24 | `devices` | U+E047 | Settings: layout (auto) | `devices_rounded` |
| 25 | `phone` | U+E048 | Settings: layout (phone) | `smartphone_rounded` |
| 26 | `desktop` | U+E049 | Settings: layout (desktop) | `desktop_windows_rounded` |
| 27 | `brush` | U+E04A | Settings: style (ornate/gradients) | `brush_rounded` |
| 28 | `document` | U+E04B | About: licences / privacy | `description_outlined` |
| 29 | `pen` | U+E04C | Muṣḥaf/reader: mark recitation (marking mode) | `edit_rounded` |
| 30 | `undo` | U+E04D | Marking bar: undo the last mark | `undo_rounded` |
| 31 | `chart` | U+E04E | Hifz: statistics | `insights_rounded` |
| 32 | `person` | U+E04F | Hifz: a reciter's mark book | `person_outline_rounded` |
| 33 | `group` | U+E050 | Hifz: book members (listeners, checkers) | `group_outlined` |
| 34 | `comment` | U+E051 | Marks: comment on a word | `chat_bubble_outline_rounded` |
| 35 | `link` | U+E052 | Hifz: share / join a book | `link_rounded` |
| 36 | `cloud` | U+E053 | Settings: account & sync | `cloud_outlined` |
| 37 | `hifz` | U+E054 | Hifz section tab | `hearing_rounded` |
| 38 | `add` | U+E055 | Add a mark / book | `add_rounded` |
| 39 | `more` | U+E056 | More actions | `more_horiz_rounded` |
| 40 | `review` | U+E057 | Hifz / muṣḥaf: review your marks | `fact_check_outlined` |
| 41 | `cards` | U+E058 | Review: show as verse cards | `view_carousel_outlined` |
| 42 | `memorize` | U+E059 | Muṣḥaf: memorize (hide the page) | `visibility_off_outlined` |
| 43 | `show` | U+E05A | Memorize: show the page | `visibility_outlined` |
| 44 | `nextVerse` | U+E05B | Memorize: reveal the rest of the āyah (points left: the text runs right to left) | `keyboard_double_arrow_left_rounded` |
| 45 | `prevVerse` | U+E05C | Memorize: hide the āyah again | `keyboard_double_arrow_right_rounded` |
| 47 | `pdf` | U+E05E | Hifz / statistics: export a PDF report | `picture_as_pdf_outlined` |
| 46 | `pageOn` | U+E05D | Memorize: rest of the page, then turn (points left: onward) | `first_page_rounded` |

## Not icons (already done)

- The **launcher icon** is the design's icon 1a (cream `#F2EEE4` glyph on emerald `#0F3B32`), generated for every platform by `tools/icons/make_launcher_icons.py` from `assets/brand/icon-glyph.png`.
- Module tiles (Qāʿidah, Tajwīd, Tashkīl…) show **Arabic glyphs** on hue-tinted tiles, not icons, as in the prototype.
