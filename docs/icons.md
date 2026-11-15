# Icons used in Qiraah Arabiyyah

Since the redesign, every icon in the app goes through one file,
`lib/ui/app_icons.dart`, which maps each use to a glyph of the **QiraahIcons**
font (see `design_handoff_qiraah_flutter/ICONS.md` for the font and its 47
glyphs).

The icons the font doesn't cover yet are listed in
[icons_needed.md](icons_needed.md), with where each is used, a suggested
codepoint and the drawing rules for Claude Design.

The launcher icons are made from `assets/apk_icons/` (drawn from
`assets/brand/rasikh_icon.svg`) by `dart run flutter_launcher_icons`; see
`flutter_launcher_icons.yaml`.
