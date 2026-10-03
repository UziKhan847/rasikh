> **Already built in the app:** v1 plus most of v2. Only apply what's missing: diff each file before replacing, and keep any app-side changes.

# Kids Backdrops: v2 update (the app already has v1)

v1 (backdrops, UI kit, screens, theme shop) is already in the app. This update only changes what's listed below. The source of truth is `source/Kids Backdrops.dc.html`.

# Rules
1. **Replace files. Don't merge by hand.** The Dart in `lib/kids_backdrops/` is ported line by line from the prototype. Don't redesign or simplify it. If something looks wrong, diff it against the JS function of the same name.
2. **Leave v1 alone** apart from the files and widgets listed here. Don't touch app logic, navigation or screens not mentioned.
3. Work one step at a time, and check each step before starting the next.

## 1. Replace these files
Copy these over the v1 versions in the app's `lib/kids_backdrops/`:
- `kb_themes.dart`: new theme flags, a parallax and blur table, and 50 avatars as PNGs.
- `kb_scene.dart`: the new lighting, suns, silhouettes and clouds, the fix for seams while swiping, and new layer painters.
- `kb_widgets.dart`, `kb_components.dart`, `kb_screens.dart`: the only change is that avatars now load as `Image.asset` PNGs instead of SVGs.

Add a new file: `kb_parallax.dart`.

Replace the app's avatar images with `assets/avatars/` (1x, `2.0x/`, `3.0x/`). Remove the old avatar SVGs and any `flutter_svg` avatar code. The new avatars' soft shadows use SVG blur filters, which `flutter_svg` can't draw.

Then run `flutter analyze`. It must be clean.

## 2. Re-verify the painter
- Replace `reference/` in the app with the new one. The v1 images are no longer valid.
- Run `flutter test test/kb_backdrop_compare_test.dart`. All 72 cases must pass.
- If a case fails, compare `test/_out/…png` and its `.diff.png` with the reference. Fix the translation, not the thresholds.

What the painter now does:
- **Light-mode lighting** (all themes except Night and Rain): richer sky, a warm side facing the sun and a cool shaded side on each ridge, a bright rim on slopes facing the sun, and a stronger edge on the near ridge.
- **Suns:** in light modes there's no hard disc. A white-hot core fades straight into the glow, with a wide wash across the sky. Sunrise keeps its soft disc. Sunset has a big low sun on the horizon in every mode, and Sunrise gets a glowing horizon sun in Dark and OLED. The sun rays and the thin ring around the sun and moon are gone.
- **Sunset:** the ridges are near-black silhouettes.
- **Rain clouds:** soft blurred puffs, 8 blobs each.
- **Removed:** the blossom flowers, the cave crystals, and the light shafts in Forest and Cave. Forest now has a normal sun and Cave has none.

## 3. Parallax on the 5 tab screens
Wrap the tab shell like this. Keep the app's existing tab state and nav bar:
```dart
final camX = ValueNotifier<double>(0);    // owned by the tab shell
final scrollY = ValueNotifier<double>(0);      // = current page's ScrollController.offset; reset to 0 on tab change
final scrollExtent = ValueNotifier<double>(0); // = current page's position.maxScrollExtent (update on scroll + after layout)

KbParallaxBackdrop(
  theme: theme, mode: mode, style: style,
  cameraX: camX, scrollY: scrollY, scrollExtent: scrollExtent,
  strength: 1.0,   // Off 0 · Subtle .6 · Normal 1 · Strong 1.6
  depthBlur: true,
  motion: settings.motion,
  child: KbSwipeTabs(
    index: tab, onChanged: (i) => setState(() => tab = i), camera: camX,
    child: KeyedSubtree(key: ValueKey(tab), child: pages[tab]),
  ),
)
```
- Each layer is painted once and only translated when the user scrolls or swipes. Never repaint on scroll.
- Swiping sideways moves only the backdrop. The page content stays still, and after the release the new tab fades in over 220 ms. Past the first and last tab the drag rubber-bands at 0.3×. It takes 70 px to change tab. Nav-bar taps animate the camera the same way.
- Vertical parallax runs for the whole page: progress = offset / maxScrollExtent, travel = progress × min(400, maxScrollExtent). The layers reach full travel exactly at the bottom, so no empty space shows and they never go still mid-scroll. Pass `scrollExtent`; without it the old 400 px stop is used.
- Parallax, depth blur and bokeh are all off in the Original style and when `MediaQuery.disableAnimations` is on.
- Non-tab screens (lessons, games, profile) keep the v1 `KbBackdrop`.

## 4. Depth blur
- The far ridge gets σ 2.6, the mid ridge σ 1.1, the near ridge stays sharp, and the foreground bokeh gets σ 9, all multiplied by `width / 390`. The values are in `kbDepthBlur`.
- `KbParallaxBackdrop` already handles this. Check on a real device that scrolling stays at 60 fps.

## 5. Avatars (50: 31 animals + 19 objects)
- 13 free and 30 locked, with prices in `kbAvatars`.
- Added after the first v2 drop: **Lion Cub** (free), **Goat** (60), **Buffalo** (90), **Whale** (120), **Wolf** (100).
- **Objects** (all locked, listed after the animals in `kbAvatars`): Shield 60, Sword 80, Helmet 100, Tasbeeh 40, Prayer Mat 40, Topi 40, Dates 30, Qahwa 60, Chai 30, Flask 50, Lantern 80, Crescent 100, Palm Tree 40, Mosque 120, Quran Stand 100, Miswak 30, Zamzam 50, Attar 60.
- **Ice Cube** is reward-only: it unlocks from the existing **Streak Freeze** reward and can't be bought. It's in `kbAvatars` with no price; hide it from the shop and grant it when the Streak Freeze reward is claimed. They use the same PNG pipeline and avatar tile, so nothing else changes. Use `flutter analyze` and check the picker scrolls cleanly with 50 tiles.
- New in this update: **Grizzly** (free), **Kangaroo** (free), **Hippo** (60), **Crocodile** (90), **Rhino** (90) and **Shark** (120).
- Every avatar is redrawn in the new style (plain shapes, soft shadows, light from the top left). The picker grid and tiles are the same as in v1. Only the images and the list change.

## 6. Sun glow, bloom and saturation (light modes)
- `kb_scene.dart`: the light-mode sun glow is 1.3× stronger and wider, and the sky wash is stronger (.6 / .24).
- New `kbPaintBloom`: light from the sun bleeds over the hills in front of it. `KbParallaxBackdrop` paints it above the ridges with `BlendMode.screen`, moving at the `orn` parallax speed. `bloom:` Off 0 · Soft .6 · Medium 1 · Strong 1.5 (**default**, the chosen value). Light modes and sun themes only; dark/OLED are unchanged.
- The bloom layer must NOT sit inside its own `RepaintBoundary`, or the screen blend has nothing to blend with. If it renders as a flat wash on device, wrap the sky/orn/ridges/bloom group in one `RepaintBoundary` instead.
- New `saturation:` (default **1.3**, the chosen value; options 1 / 1.15 / 1.3 / 1.5) wraps the backdrop (not the UI) in `ColorFiltered(ColorFilter.matrix(kbSaturation(x)))`.
- The bloom's lens flare is a short oval through the sun that fades out sideways. Don't use a full-width band; it reads as a hard line.
- Expose both as settings next to Parallax and Depth blur.

## 7. Fidelity: Standard / High / Ultra (new)
New file `kb_hifi.dart`. `kb_parallax.dart` and `kb_themes.dart` are updated to use it. Add `sensors_plus` to pubspec.yaml (used for tilt).
- `KbParallaxBackdrop(fidelity: KbFidelity.high)` is the default. Add a setting next to Parallax and Depth blur: **Standard / High / Ultra**. Suggest Ultra on newer phones and drop to Standard in battery saver.
- **High:** film grain (`KbGrain`, overlay blend, so pure black stays black on OLED), per-theme specks (`kbFxRecipe`: bubbles, fireflies + leaves, petals, sand, stars + shooting star, snowflakes, rain, cave motes, warm dust, plus lens hexes and sparkles) at 3 depths, mist (`mist0`/`mist1` layers in front of far and mid, drifting), and phone tilt (`KbTilt`, per-layer px in `kbTiltPx`). High replaces the old motes layer; bokeh stays.
- **Ultra:** god rays, glow on fireflies/sparkles/cave motes, water glints (wave themes), clouds and birds (light modes), specks that brighten near the sun and swirl away from the finger (a `Listener` around the backdrop; translucent, so taps still reach the UI), rim light on ridge tops (`_RidgePainter.rim`), a slow hue/brightness shimmer, extra blur on far layers as the page scrolls (`kbScrollBlur`), and a vignette.
- `KbFxLightPainter` and `KbGrain` must not sit inside their own `RepaintBoundary`, because their screen/overlay blends need the scene underneath. Same rule as bloom.
- Check on a mid-range Android: Ultra scroll blur rebuilds an `ImageFiltered` per frame while scrolling. If it drops frames, remove `kbScrollBlur` first.
- **Tilt (High + Ultra)** has two inputs, both handled in `KbTilt` (`kb_hifi.dart`):
  - **Phone / tablet:** the accelerometer through `sensors_plus`. Tilting the device shifts each layer by `kbTiltPx[role]` × tilt (-1..1), so the front layers move most. It's smoothed with a ~140 ms ease.
  - **Desktop / web with a mouse:** pointer hover over the backdrop, the same as the prototype demo. Centre = 0, edges = ±1. `KbParallaxBackdrop` wraps itself in a `MouseRegion` + `Listener`; `onPointerHover` calls `KbTilt.pointer`, and leaving the window eases back to centre.
  - Once a real sensor reading arrives, mouse input is ignored. Touch drags never drive tilt; they keep scrolling and swiping tabs.
  - Desktop builds skip the sensor entirely. On web the sensor is tried first (phones), then it falls back to the mouse.
  - iOS needs no permission prompt for the accelerometer in a native app. (The prototype asks because Safari on the web requires it.)
  - If it moves the wrong way on a device, flip the sign of x in `KbTilt.start`. Tilt is off when the system "reduce motion" setting is on.
- **UI tilt** (`uiTilt:` 0 off · 1 subtle (default) · 1.6 strong): the whole `child` (the app UI passed into `KbParallaxBackdrop`) turns slightly to face the tilt, up to 2.5° × k, and floats up to 5 px × k, using the same `KbTilt` value. It works through a `Transform` with perspective, so taps still land correctly. Expose it as a setting next to Fidelity.
  - If you only want the page content to tilt and the bottom nav to stay put, wrap just the page body in the same `Transform` instead of the whole `child`.
  - Rotation is kept small on purpose so text stays sharp. Don't go above 1.6.
  - Flip the sign of `rotateX` if the UI tips the wrong way vertically on device.

## Watch out for
- **Vertical seams while swiping:** ridge gradients must use the fixed top `(base − amp) × H` and the sun's global position (`lx × W − x0`). The sun's glow must fill the whole widened canvas. The v2 code already does this, so don't "optimise" it back.
- **Blur:** canvas `blur(N)` maps to `ImageFilter.blur(sigmaX: N)`.
- **Colours:** keep them as `0xRRGGBB` ints until `kbC()` is called. No `.withOpacity`.
