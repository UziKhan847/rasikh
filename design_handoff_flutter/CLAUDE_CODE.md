# Kids Backdrops → Flutter

This folder replaces the earlier handoffs for implementation purposes. It covers **both the backdrops and the whole UI restyle**: cards, buttons, tiles, nav, headings and all 13 screens. The Dart files in `lib/kids_backdrops/` are ported from the working prototype in `source/Kids Backdrops.dc.html`. Your job is to wire them into the app and verify them. Do not re-derive the design.

Read `UI_SPEC.md` before touching any screen.

## Rules

1. **Do not redesign, simplify or "clean up" the painter.** Every constant (ridge heights, alpha values, blur radii, hash seeds) is tuned. If something looks wrong, compare against the JS function of the same name in `source/Kids Backdrops.dc.html` and fix the translation, not the numbers.
2. **Colours come only from `KbTheme` + `KbUi`.** No `Colors.xxx`, no hard-coded hex in screens.
3. **Avatars are already done.** Keep the app's existing avatar SVGs and loading code. Don't re-export, redraw or convert them. Only the frames around them (circle, ring, lock badge, shadows) are part of this restyle.
4. **One step at a time.** Finish and verify each step below before starting the next. Stop and report if a step fails.
5. `kb_themes.dart` is generated from the HTML. If a theme value must change, change it in both places.

## What's here

```
lib/kids_backdrops/
  kb_themes.dart   12 themes, avatar list + prices (generated)
  kb_scene.dart    palette(), yAt(), drawScene() → kbPaintScene(), drawMotes() → kbPaintMotes(), painters
  kb_ui.dart       UI colour tokens (surface, edge, tile, ink, heading outline shadows…)
  kb_widgets.dart  KbBackdrop, KbThemeIcon, KbThemeShopTile, KbAvatar, KbAvatarPickerTile, KbHeading
  kb_components.dart  UI kit: KbSurface + KbElev (the 3D edge look), pills, big button, cards, tiles, cells, nav…
  kb_screens.dart  all 13 screens built from the kit + KbGallery debug switcher
UI_SPEC.md         rules, tokens, elevation table, element → widget map
reference/
  backdrops/{vivid,original}/{light,dark,oled}/{theme}.png   390×844 @1x, rendered by the JS painter
  theme_icons/{light,dark,oled}/{theme}-3x.png                96 pt icons @3x
test/kb_backdrop_compare_test.dart   Dart painter vs reference PNGs
source/            the HTML prototype (open Kids Backdrops.dc.html in a browser)
```

## Steps

### 1. Install
- Copy `lib/kids_backdrops/` into the app's `lib/`.
- `KbAvatarInfo.asset` in `kb_themes.dart` points to `assets/avatars/<id>.svg`. Change the path to wherever the app's existing avatar SVGs live. Nothing else about avatars needs to change.
- Fonts: **Baloo Bhaijaan 2** (500–800), **Noto Naskh Arabic** (500–600), **Amiri Quran**, **Material Symbols Rounded** (variable, FILL 1, wght 600). Bundle them as assets (preferred for a kids app used offline), or use `google_fonts`. The widget code references them by these family names.
- Remove the old backdrop painter. Don't keep two implementations. Leave the existing avatar code alone.
- `flutter analyze` must be clean.

### 2. Verify the painter before touching any screen
- Copy `reference/` and `test/` into the app root, and replace `YOUR_APP` in the test imports.
- Run `flutter test test/kb_backdrop_compare_test.dart`. All 72 cases should pass.
- On failure, open `test/_out/<style>/<mode>/<theme>.png` next to the reference and the `.diff.png` heat-map. Red blocks show where the difference is. Fix the Dart translation by diffing it against the JS.
- Small anti-aliasing and blur differences are expected, which is why the thresholds aren't zero. Don't loosen them to make a test pass.

### 3. Backdrop behind every screen
```dart
KbBackdrop(
  theme: kbThemes.firstWhere((t) => t.id == settings.themeId),
  mode: settings.mode,          // KbMode.light / dark / oled
  style: KbStyle.vivid,
  motion: settings.motion,
  child: SafeArea(child: page),
)
```
- The design is authored at 390×844. The painter scales horizontally by `width/390`, and ridges sit at fixed fractions of the height. Pass the full screen size, not a padded box.
- Headings sit on the upper sky and cards scroll over the ridges. Compare layouts with the HTML (see step 6).

### 4. Theme shop (Rewards screen, above "Looks")
- A 3-column grid of `KbThemeShopTile`, gap 12. `ui` is the `KbUi` of the **current** theme.
- Tap on a locked tile → purchase flow (price = `theme.price` gems). Tap on an owned tile → apply the theme.
- The original 7 themes are free. Rain 80, Sunrise 80, Cave 100, Frozen 120, Snowy 120.
- `reference/theme_icons/` shows what each icon must look like.

### 5. Avatar frames
- The avatar images stay as they are. Only restyle what surrounds them.
- New Profile: a 6-column grid of `KbAvatarPickerTile`, gap 10 horizontal × 8 vertical. Selected: tile bg + 4 px accent ring. Locked: small lock badge at bottom-right.
- Elsewhere (leaderboard, Me), use `KbAvatar(avatar:, size:, background: kbC(ui.surface))`, or wrap the app's existing avatar widget in the same circle.

### 6. Run the gallery first
- Temporarily set `home: const KbGallery()` (in `kb_screens.dart`). Long-press to switch screen, theme and mode.
- Open `source/Kids Backdrops.dc.html` in Chrome at the same screen, theme and mode. Check them side by side at 390 wide. Fix the components until they match. This is the only step where you edit `kb_components.dart`.

### 7. Restyle the real screens
- Go screen by screen through the app. Replace the existing cards, buttons, tiles, list rows, nav bar and headings with the kit widgets, using the matching `kb_screens.dart` screen as the layout template (same widget order, same `_gap` values).
- **Remove all old styling.** That means Material `Card`, `ElevatedButton`, `ListTile`, `NavigationBar`, theme-based `ColorScheme` colours and translucent containers. Anything the kit doesn't cover must be built from `KbSurface` + `KbElev` following the rules in `UI_SPEC.md` §1.
- Keep the app's own logic, data and navigation. Only the presentation changes.
- After each screen, compare a screenshot with the HTML at the same theme and mode, in Light and in Dark, before moving on.
- Search for leftovers at the end: `grep -rn "Colors\.\|Card(\|ElevatedButton\|ListTile\|withOpacity" lib/`. Anything left in a restyled screen is a bug.

## Things that commonly go wrong
- **Wrong radial gradients**: canvas `createRadialGradient(x,y,r0, x,y,r1)` means the colour stops start at `r0/r1`, not 0 (`_radial()` handles this). Off-centre gradients (sun disc, moon) need `focal:`.
- **Blur**: CSS/canvas `blur(N)` is a Gaussian σ of N → `MaskFilter.blur(BlurStyle.normal, N)`. For `BoxShadow`/`Shadow`, convert with `kbCssBlur()`.
- **Moon**: needs `saveLayer` + `BlendMode.dstOut`. Painting a circle in the sky colour over it looks wrong on gradients.
- **Motes**: they belong on a separate `RepaintBoundary` so the static scene isn't repainted every frame. Honour `MediaQuery.disableAnimations`.
- **Deprecated Color APIs**: colours stay as `0xRRGGBB` ints until `kbC()`. Don't convert to `Color` early or use `.red`/`.withOpacity`.
