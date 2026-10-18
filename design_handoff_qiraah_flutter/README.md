# Handoff: Qiraah Arabiyyah — Flutter implementation

> **Start here, Claude Code.** The quickest path: read §Overview → §Design tokens → every "Update" section in order (later overrides earlier) → finish with **Update 6** and the **Final checklist** at the bottom.
>
>  Read this README top to bottom; later "Update" sections override earlier ones. Icons: read `ICONS.md` and use the bundled `QiraahIcons` font instead of any icon package. Prototype: `Qiraah App.dc.html`.

## Overview
Qiraah Arabiyyah is a Qur'an reading and learning app. This bundle covers the full redesign:
- a home screen
- a sūrah list
- the verse-by-verse reader, with two audio modes
- a 15-line Muṣḥaf: mobile portrait, mobile landscape, desktop two-page spread, and desktop single-page zoom
- Learn: the Qaidah path, units, the letters grid, letter detail and a quiz
- the Tajwīd Academy, its rule pages and a count trainer
- a letter Tracing Studio
- two bottom sheets (word-by-word details and reader settings)

It targets **one Flutter codebase** for phones (iOS/Android) and desktop/web (≥1024px).

## About the design files
The files in this bundle are **design references built in HTML**. They are prototypes that show the intended look and behaviour; they are not production code to port line by line. Recreate them in Flutter using idiomatic widgets, state management and packages. Open `Qiraah App.dc.html` in a browser to try every interaction (press **M** to switch between the phone and desktop views). All colours, sizes and data quoted below come from that file. The logic class near the bottom of the file holds every constant, including the demo data.

## Fidelity
**High fidelity.** Match the colours, type, spacing, radii and interactions exactly. The demo content (two full sūrahs and Muṣḥaf pages 1 and 602–604) is placeholder: replace it with a real Qur'an data source (see *Data*).

---

## Suggested Flutter architecture
- **Flutter 3.22+**, Material 3 turned off visually: build on `ThemeData` with custom colours, no ripple-heavy defaults (use `InkWell` with `splashFactory: NoSplash.splashFactory` or a subtle highlight).
- **State:** Riverpod (or Bloc). Suggested providers:
  - `navigationProvider`: the screen stack and the current tab
  - `readerProvider`: surah, ayah, word, playing, mode, speed, after-ayah rule, layout, tajweed, translation, font size, script, paper
  - `playerUiProvider`: `playerMinimised`
  - `shellProvider`: `sidebarCollapsed`, plus `isDesktop` derived from `MediaQuery`
  - `mushafProvider`: page, chromeVisible, paper, orientation, singlePageZoom, playing, tokenIndex
  - providers for learn, quiz and trace state
- **Routing:** `go_router` with a `ShellRoute`. The shell is a bottom tab bar on mobile and a sidebar on desktop. The Muṣḥaf route is full-screen (no shell chrome when it is immersive).
- **Audio:** `just_audio` plus `audio_service` for background playback. Highlighting words needs word-level timing data (per-word timestamps from the reciter's segments).
- **Fonts** (bundle them as assets, or use `google_fonts`):
  - `Amiri Quran`: all Qur'anic text
  - `Noto Naskh Arabic`: letters and tracing
  - `Hanken Grotesk` (400/500/600/700): UI
  - `Newsreader` (400/500): display headings
- **RTL:** wrap all Arabic in `Directionality(textDirection: TextDirection.rtl)`. The Muṣḥaf page order is RTL, so the next page is on the **left**: swipe right or press ← to go forward.
- **Breakpoint:** `isDesktop = width >= 1024`. Below that, use the phone layout and allow landscape orientation only on the Muṣḥaf route.

## Design tokens
**UI colours**
- `acc #0F7A62`
- `ink #16201C`, `ink2 #56605B`, `ink3 #8B928D`
- `line #E6E2D8`
- `red #B4483B`, `gold #B4862C`
- app background `#F5F3EE`
- sidebar `#FBFAF7` with a `#E6E2D8` right border; hover `#EFECE5`

**Reader paper (light)**
- `bg #F5F3EE`, `card #FFFFFF`
- `ink #16201C`, `ink2 #56605B`, `ink3 #8B928D`
- `line #E6E2D8`, `hl #D9ECE3`, `sel #F3EAD5`, `accent #0F7A62`

**Reader night**
- `bg #0E1412`, `card #161E1B`
- `ink #ECE8DF`, `ink2 #A3ABA6`, `ink3 #6F7873`
- `line #26302B`, `hl #1F4337`, `sel #3A3220`, `accent #3FB08F`

**Tajwīd colours** (light / night)

| Rule | Light | Night |
|---|---|---|
| madd (2 counts) | `#B4862C` | `#D9AE55` |
| madd lāzim (6) | `#B4483B` | `#E07A6C` |
| silent | `#A7ABA3` | `#5E6863` |
| qalqalah | `#2F6CA6` | `#7DAEDD` |
| idghām | `#1E8A86` | `#5CC3BE` |

When tajwīd colouring is off, all rule colours become `#C9CCC6`.

**Muṣḥaf papers** (keys: bg / paper / ink / line / acc / frame / soft / hl / hl2 / chrome / sub)
- **Cream:** `#E9E2D0` / `#FBF7EC` / `#1D2420` / `#E3D9C2` / `#0F6E58` / `#B4862C` / `#F4ECD8` / `#EFE3C5` / `#CBE3D6` / `rgba(251,247,236,.97)` / `#857B69`
- **White:** `#EDEFEC` / `#FFFFFF` / `#16201C` / `#E2E5E1` / `#0F7A62` / `#0F7A62` / `#EEF6F2` / `#EEF3EF` / `#CDE8DC` / `rgba(255,255,255,.97)` / `#8B928D`
- **Night:** `#090D0C` / `#121816` / `#E8E3D6` / `#25302C` / `#4DBB98` / `#A88A4E` / `#18211E` / `#1F2B27` / `#21473B` / `rgba(18,24,22,.97)` / `#7D8682`

**Tajwīd Academy rule hues** are oklch hue angles, used with fixed lightness and chroma. Convert them to sRGB at build time:

| Rule | Hue |
|---|---|
| ghunnah | 150 |
| iẓhār | 265 |
| ikhfāʾ | 170 |
| iqlāb | 230 |
| qalqalah | 215 |
| madd | 75 |
| madd lāzim | 28 |

**Radii:** chips 10–14; buttons 20 (40px circles); cards 20–22; player sheet 24 (top corners only); Muṣḥaf page 10 (on a spread, the inner spine edge is square); phone sheets 24–28.

**Shadows:**
- floating buttons: `0 8px 20px -10px rgba(20,30,25,.45)`
- page spread: `0 30px 60px -30px rgba(40,30,10,.45)`
- spine: inner shadow `inset ±22px 0 28px -22px rgba(60,40,10,.18)`
- play button: `0 8px 20px -8px rgba(15,122,98,.7)`

**Type scale:**
- section labels: 12/700, letter-spacing .06–.1em, uppercase, `#7A817C`
- body: 13–14
- titles: 15–16/700
- display: Newsreader 22–34
- reader Arabic: default 30px, adjustable with A−/A+
- Muṣḥaf font: auto-fitted (see below)

**Hit targets:** at least 44px on mobile. Icon buttons are 40px circles with a 1px `line` border.

## Shell
**Mobile**
- The phone frame in the prototype is presentation only. In Flutter the app fills the device.
- Bottom tabs: Today · Reader · Muṣḥaf · Learn · Trace. They show on the home, quran, learn and trace screens.

**Desktop**
- A 248px sidebar sits on the left (padding 24/16/18) and contains:
  - the logo: the **1a icon**, `assets/icon-glyph.png` used as a mask, cream `#F2EEE4` on emerald `#0F3B32`, a 34px rounded square with radius 9 and the glyph inset 6
  - "Qiraah" in Newsreader 22 with "ARABIYYAH" (10/700, .12em) beneath it
  - the nav items (height 44, radius 12)
  - a help card at the bottom
- **Collapsible sidebar:** a 32px "hide sidebar" icon button next to the logo collapses it completely. A 44px round floating button at **bottom-left (16,16)** brings it back. Animate the width from 248 to 0 over about 200ms.
- When the Muṣḥaf is immersive (menus hidden), the sidebar is hidden as well.

## Screens
1. **Home (Today):** a date greeting; a "Continue reading" card (sūrah, "Āyah 5 of 7 · Juz' 1", Resume and Recite buttons); a streak and daily goal; "Verse of the day"; "Today's lesson · Unit 3"; Explore tiles.
2. **Qur'an list:** a search field, a "Last read" card and a sūrah list (number, English and Arabic names, Meccan/Medinan, āyah count).
3. **Reader (verse by verse).**
   - **Header:** back button, title and subtitle, then three buttons: Full Muṣḥaf, Tajwīd toggle and Settings.
   - **Content column:**
     - max width 760px, centred (side padding `max(16, 50% − 380)`)
     - **when the desktop sidebar is collapsed, widen to 1080px** (`50% − 540`)
     - a banner card (sūrah name, meta, basmala)
     - then the āyah cards (Arabic words with tajwīd colouring, translation and per-āyah actions such as bookmark), or a word-grid layout
   - **Words** are tappable and open the Word sheet: segments, transliteration, meaning and "Recite from here".
   - **Audio player** (a bottom sheet with radius 24 on the top corners):
     - a 3px progress line
     - a segmented control: **Recitation** (waveform icon) or **Word by word** (blocks icon)
     - the current word in Arabic (28px) with its transliteration and meaning
     - controls: After-āyah (Continue / Stop / Repeat), Previous, a 60px Play button, Next, Speed
   - **Minimise the player** (on mobile portrait **and** desktop):
     - a 44×26 pill tab centred on the player's top edge (top −15), with a chevron that rotates 180° when the player is minimised
     - minimised, the player is one 40px-high row: a 40px Play button, the current word plus its meaning on one line (ellipsis), Previous, Next and Speed
     - the progress line stays
     - animate the height (`AnimatedSize`, 200–250ms)
   - Playing auto-scrolls the active āyah into view, 70px from the top, with smooth scrolling.
4. **Muṣḥaf: 15-line pages.**
   - **Portrait (mobile):**
     - pages are swipeable horizontally (RTL, newest page on the left), and the page follows your finger while dragging
     - snap animation: 380ms `cubic-bezier(.2,.8,.2,1)`
     - top bar: close, title and subtitle, landscape toggle
     - bottom bar: page colour, recite, index
     - **tapping the page toggles both bars** (opacity 250ms) so the text gets the full screen
   - **Landscape (mobile):**
     - one page scrolls vertically, with lines 2.25em tall
     - floating 46px round buttons at top-right: exit landscape, page colour, recite
   - **Desktop spread:**
     - two pages side by side; each page fills the available height with an aspect ratio of 0.68
     - spine shadows on the inner edges
     - pages are grouped into fixed spreads: [1, placeholder 2], [placeholder 601, 602], [603, 604]
     - turning pages: ← / → arrow buttons at the sides, ← and → keys, Space to recite, Esc to show the menus
     - top bar (64px): close, then a title block (`flex 1 1 160`, min width 140, title and subtitle both ellipsised)
     - top bar, continued: page chips (Go to page), "Recite this page" pill, **Single page** toggle (40px icon button), page colour, Focus (hides all menus)
   - **Desktop single page (zoom):**
     - shows one page at **1.6×**: page height = (viewport height − top bar − padding) × 1.6, so the page scrolls vertically inside a rounded container
     - no spine shadows
     - arrows and keys step one page at a time
     - each page turn resets the scroll to the top
     - the subtitle reads "Page N"
     - the toggle icon switches to "two pages"
   - **Line layout:** each page has exactly 15 line slots. Line types are a sūrah heading (framed box with a double border in `frame`, `soft` fill), the basmala (centred), a centred line, or a justified line. The āyah end-marker is an Arabic-Indic number inside ﴿ ﴾.
   - **Font auto-fit:** start from a base size (portrait 26px, landscape 50px, desktop ≈ `max(15, (viewportH − 174)/15 × 0.56)`, ×1.6 in single-page mode), then shrink it until the widest line fits. Cache the result per mode and viewport height. In Flutter, measure each line with `TextPainter` and pick the largest size that fits; do not use `FittedBox` per line, because line sizes must match across the page.
   - **Recitation:** highlight the current word (`hl2`) and its āyah (`hl`); in the demo it advances every 480ms.
5. **Learn → Qaidah path:** ten units (done, current, open or locked) → **Unit** (Learn / Test (best score) / Practice) → **Letters grid** (28 letters, "12 / 28 mastered") → **Letter detail** (Listen, Trace it, four positions, easily-confused letters, makhraj, Qur'anic examples) → **Quiz** (letter → four options, correct/try-again feedback, then Continue).
6. **Tajwīd Academy:** rule chips coloured as in the reader, a count trainer, and chapters. A **Rule** page has the description, a "When" block, its letters, a **count trainer** ("Hold for exactly N counts": press-and-hold, then scored) and examples with sūrah references.
7. **Tracing Studio:** a canvas with a ghost letter in Noto Naskh 200px; Guided or free mode; Clear; "Check my letter" scores the strokes against the ghost. In Flutter, use `CustomPainter` and `GestureDetector` pan events.
8. **Settings sheet:**
   - Script: Madani / IndoPak
   - Layout: Cards / Words
   - Open full Muṣḥaf
   - Text size: A− / A+
   - Page: Paper / Night
   - Tajwīd colours toggle
   - Reciter: three options
   - After an āyah: Continue / Stop / Repeat

## Interactions summary
- Keyboard (desktop): ← and → turn Muṣḥaf pages, Space plays or pauses, Esc shows the menus. **M** only switches device views in the prototype; don't ship it.
- Recitation advances word by word: recite mode is ~470ms per word in the demo and word-by-word mode is ~1300ms, both divided by speed. In production, drive this from real audio timestamps instead.
- After an āyah ends:
  - Continue: go to the next āyah
  - Repeat: replay the same āyah
  - Stop: stop playback
- Toasts last 2.4s.
- Transitions:
  - opacity: 250ms
  - page snap: 380ms `cubic-bezier(.2,.8,.2,1)`
  - colour and segment changes: 200ms

## Data
- Demo data lives in the constants `SD` (sūrahs with per-word segments, `text~rule` tajwīd tags, transliteration and meaning), `MPAGES` (15-line page definitions), `SURAHS`, `LETTERS`, `QUIZ`, `UNITS`, `RULE`, `CATS`, `RECITERS` and `TRACE` at the bottom of the HTML file.
- For production, use a licensed Madani 15-line page/line dataset, word-by-word translation data and per-word timing for each reciter.

## Assets
- `assets/icon-glyph.png`: the app glyph, used as an alpha mask. The chosen icon is **1a**: glyph `#F2EEE4` on `#0F3B32`. Generate launcher icons with `flutter_launcher_icons`, including an adaptive icon.
- All UI icons ship as the **QiraahIcons** font: see `ICONS.md` and use `Icon(QiraahIcons.x)` everywhere.

## Files
- `Qiraah App.dc.html`: the full interactive prototype (open it in a browser next to `support.js`)
- `App Icon Options.dc.html`: the icon explorations (1a is the selected one)
- `assets/icon-glyph.png`

## Suggested build order for Claude Code
1. Theme, tokens and fonts, then the responsive shell (tabs or the collapsible sidebar).
2. The reader and its audio player (both modes, minimise, auto-scroll), plus the word sheet and settings sheet.
3. The Muṣḥaf engine: the 15-line layout with font auto-fit, then portrait swipe, landscape, the desktop spread and single-page zoom, then immersive mode.
4. Learn, Quiz, Tajwīd and the count trainer, then Tracing.
5. Real data and audio.


---

## Update 2: universal themes, app settings, player and Muṣḥaf controls
This section **overrides** anything above that conflicts with it.

### 1. One app-wide theme (4 themes)
> **Mint has been removed.** Ignore every "mint" column, row and option below; the themes are Light, Mono, Night and OLED.

The theme now applies to **every screen**, including the sidebar, tabs, Home, Learn, Quiz, Tajwīd, Trace, Settings, the sheets, the reader and the Muṣḥaf. It is no longer a reader-only "paper".

- Model it as `enum AppTheme { light, mono, night, oled }`, persisted with `shared_preferences`.
- Build one `ThemeExtension<QiraahColors>` per theme and read colours only through `context.qc.*`. Never hard-code a hex value in widgets.

| token | light | mint | mono | night | oled |
|---|---|---|---|---|---|
| bg | F5F3EE | EAF6F0 | F4F4F4 | 0E1412 | 000000 |
| card | FFFFFF | FFFFFF | FFFFFF | 161E1B | 0B0F0D |
| ink | 16201C | 12241D | 111111 | ECE8DF | E6E2D8 |
| ink2 | 56605B | 4B6359 | 555555 | A3ABA6 | 9AA19D |
| ink3 | 8B928D | 7F978D | 858585 | 7D8681 | 737B77 |
| mut (section labels) | 7A817C | 6E867C | 757575 | 7D8681 | 737B77 |
| line | E6E2D8 | D3E8DE | E2E2E2 | 26302B | 1C2421 |
| line2 (card borders, dividers) | ECE8DF | DDEEE6 | EBEBEB | 222B27 | 161D1A |
| line3 (control borders, toggle off) | D9D5CB | C2DDD1 | D2D2D2 | 34403A | 2A3430 |
| track (segmented background) | F0EDE6 | DCEFE6 | ECECEC | 1C2522 | 121815 |
| segOn (selected segment) | FFFFFF | FFFFFF | FFFFFF | 2C3833 | 222B27 |
| side (desktop sidebar) | FBFAF7 | F3FAF6 | FAFAFA | 121916 | 000000 |
| hover | EFECE5 | E0F1E9 | EDEDED | 1C2522 | 121815 |
| acc (accent text, icons) | 0F7A62 | 0E8C6C | 111111 | 3FB08F | 3FB08F |
| accBg (filled buttons, white text) | 0F7A62 | 0E9A76 | 111111 | 16856A | 16856A |
| accSoft (selected nav fill) | E1EEE8 | D2F0E4 | E8E8E8 | 173A2F | 0F2A21 |
| accInk (text on accSoft) | 0B5E4B | 0A6B53 | 111111 | 9FE0C6 | 9FE0C6 |
| hero (feature cards, logo tile) | 0F3B32 | 0F3B32 | 1A1A1A | 0F3B32 | 0F3B32 |
| dim | B5BAB4 | A9C2B7 | B3B3B3 | 56605B | 4A524E |
| sel | F3EAD5 | FCEFD2 | EDEDED | 3A3220 | 2E2817 |
| outer (behind the app on desktop) | E8E4DA | D6EEE3 | E4E4E4 | 050807 | 000000 |
| ghost (Trace guide letter) | ECE7DC | D6EDE2 | EAEAEA | 26302B | 1A211E |

- **Mint** is the original, lighter-mood green theme.
- **Mono** is greyscale UI only. **Tajwīd colouring is still applied in Mono** (it uses the light tajwīd set). The tajwīd palette is independent of the app theme: night and oled use the dark tajwīd set, and all other themes use the light set.
- Use `ink` on `accSoft` and white on `accBg`. Toggle knobs are always white.
- **Status bar / system UI:** light icons in night and oled (`SystemUiOverlayStyle.light`), dark icons in the other themes.

**Reader palette per theme** (bg, card, ink, ink2, ink3, line, hl, sel, accent):
- light: F5F3EE, FFFFFF, 16201C, 56605B, 8B928D, E6E2D8, D9ECE3, F3EAD5, 0F7A62
- mint: EAF6F0, FFFFFF, 12241D, 4B6359, 7F978D, D3E8DE, C8EEDD, FCEFD2, 0E8C6C
- mono: F4F4F4, FFFFFF, 111111, 555555, 8A8A8A, E2E2E2, E4E4E4, EFEFEF, 111111
- night: 0E1412, 161E1B, ECE8DF, A3ABA6, 6F7873, 26302B, 1F4337, 3A3220, 3FB08F
- oled: 000000, 000000, E6E2D8, 9AA19D, 6A726E, 1C2421, 123326, 2E2817, 3FB08F

**Muṣḥaf paper follows the theme.**
- In the light theme the user can choose cream or white.
- The other themes map to their own paper: mint, mono, night or oled.
- Added papers (bg, paper, ink, line, acc, frame, soft, hl, hl2, sub):
  - mint: DCEFE6, F7FCF9, 14231D, D3E8DE, 0E8C6C, 12B88E, E6F6EE, E2F3EA, BFE9D6, 6E867C
  - mono: E9E9E9, FFFFFF, 111111, E2E2E2, 111111, 555555, F4F4F4, EDEDED, DADADA, 808080
  - oled: 000000, 000000, E2DED3, 1A211E, 46B592, 8A7342, 0A0F0D, 14201B, 173A2F, 6E7672
- The Muṣḥaf "page colour" button cycles cream → white → mono → night → oled, and **sets the app theme** as it goes (cream and white both mean the light theme).

### 2. App Settings screen (new)
- **Route:** `/settings`. On mobile, open it from a 40px cog button on Home, next to the streak chip. On desktop, it is a sidebar item below the main nav. It uses the same shell and a content column with a maximum width of 760.
- **Layout:**
  - title in Newsreader 30
  - section labels: 12/700, letter-spacing .08em, colour `mut`
  - grouped cards: radius 20, a 1px `line2` border, rows divided by 1px `line2`, row padding 14×16
  - each row has a title (15/700), an optional subtitle (12, `ink3`) and a control; the control wraps below the text on narrow widths
- **Theme:** a grid of four tiles (`minmax(150, 1fr)`): Light "Warm paper", Mono "Greyscale · tajwīd stays", Night "Low light", OLED "True black". Each tile has:
  - a 72px preview drawn in that theme's bg, card, ink and accent
  - a label, a subtitle and a radio dot
  - a 2px border that is `acc` when selected
- **Reading:**
  - Muṣḥaf paper (Cream / White, shown only in the light theme)
  - Arabic script (Madani / IndoPak)
  - Reader layout (Āyah cards / Word grid)
  - Arabic text size: A− / A+, with a live Arabic preview line capped at 72px
  - Tajwīd colours toggle
  - Show translation toggle
- **Recitation:**
  - reciter radio list
  - After an āyah (Stop / Continue / Repeat)
  - Playback speed (0.75× / 1× / 1.25×)
  - Follow along toggle (auto-scroll to the active āyah)
  - Audio player (Pinned / Floating / Hidden)
- **Learning:**
  - Daily goal (5 / 10 / 15 / 20 min)
  - Daily reminder toggle (schedule it with `flutter_local_notifications`)
- The reader's settings sheet shares the same state. Its "Page" control is now **Theme** (Light / Mono / Night / OLED).
- Keep all of this in one `SettingsController` (Riverpod `Notifier`) that persists every field.

### 3. Audio player: minimise, float or hide (mobile **and** desktop)
- **Player state:** `enum PlayerDock { pinned, floating, hidden }`, plus `bool minimised`.
- **Pinned** (the default): docked at the bottom, with radius 24 on the top corners. A pill tab on the top edge (36×24 segments, centred, 14px above the edge) holds three buttons:
  - **Unpin**: float the player
  - **Minimise / expand**: the chevron rotates 180°
  - **Hide**
- **Minimised:** a single row with Play (40px), the current word plus its meaning (ellipsis), Previous, Next and Speed. The 3px progress line stays.
- **Floating:**
  - a card with radius 22, width `min(620, screenWidth − 32)`, shadow `0 24 50 −20 rgba(20,30,25,.45)`
  - it starts bottom-centre, 24px from the bottom
  - its header row has a drag grip ("PLAYER"), then Pin back, Minimise and Hide
  - implement it as a `Stack` with `Positioned` driven by `GestureDetector.onPanUpdate`; clamp it 8px inside the reader bounds and remember the offset
  - the reader list gets extra bottom padding (280) so the last āyah can scroll clear of the card
- **Hidden:** no player. A 52px round button sits 24px from the bottom-right corner; its background is `accent` while audio is playing, otherwise `card`. Tapping it restores the player.
- Animate the changes with `AnimatedSize` / `AnimatedSwitcher` (200–250ms).

### 4. Reader header can be hidden
- An up-chevron button at the end of the header hides it.
- Once hidden, a 48×28 pill centred 8px from the top restores it, and the content's top padding becomes 44.
- This works on mobile and desktop.

### 5. Huge Arabic text
- The font size steps by 3 up to 44, then by 6.
- The maximum is **120 on desktop** and **64 on mobile**; clamp the size when the layout switches to mobile.
- The desktop reader header has an inline A− [size] A+ control.
- **Āyah words must wrap:** lay out each word as its own widget inside `Wrap(textDirection: rtl, spacing: 0.12em, runSpacing: 0)` (or a `Text.rich` with spaces between words), so large sizes break onto new lines instead of overflowing.

### 6. Collapsible desktop sidebar
- A 32px "hide sidebar" button sits next to the logo. Collapsing animates the sidebar width from 248 to 0.
- A 44px round button 16px from the bottom-left restores it.
- While the sidebar is collapsed, the reader column widens from 760 to 1080.

### 7. Desktop Muṣḥaf view modes
A three-way switch in the top bar (34px icon segments, the selected one filled `acc`):
1. **Spread:** two pages side by side (as before).
2. **Single:** one page at 1.6× the available height; it scrolls vertically.
3. **Fill width:** one page whose width fills the available area (minus the sidebar and padding). Its height is width ÷ 0.68, and it scrolls vertically. Recalculate the font fit whenever the width, the sidebar state or the menu visibility changes.

In single and fill-width modes, the arrows and keys turn **one page** at a time and reset the scroll to the top. The Focus button still hides all menus for fullscreen reading.

### Build order for this update
1. Add `QiraahColors` and `AppTheme`, and migrate every widget to theme tokens.
2. Add the SettingsController and the Settings screen, and wire the reader sheet to the same controller.
3. Add the player dock modes, the hideable header and the font range.
4. Add the sidebar collapse and the Muṣḥaf view modes.


---

## Update 3: word-grid controls and quick adjust

### Word grid
Each āyah's words are grouped into **cards of N words**.
- `wordsPerCard` can be 1 to 6 (default 1).
- A card is a rounded container (radius 16, `card` background, 1.5px border that turns `accent` when it holds the active or selected word, padding 6).
- Inside a card, each word is a tappable column (Arabic on top, transliteration below) with its own highlight background (`hl` while playing, `sel` when selected).
- The space between words inside a card is `max(2, gap / 2)`.

Layout options:
- **Alignment:** Right (the RTL start; the default) or Centre.
- **Each card on its own line:** a toggle. When on, use a `Column` with `crossAxisAlignment` end (right) or center. When off, use `Wrap(textDirection: rtl, alignment: start|center, spacing: gap, runSpacing: gap)`.
- **Gap between cards:** 0 to 64px in steps of 4 (default 8). Animate changes.

Put all of these in `ReaderSettings` and persist them. They appear in the reader's settings sheet (a "Word grid" section, shown only in the word-grid layout) and on the app Settings screen, under Reader layout.

### Quick adjust in the reader header
- **Desktop:** two inline pill steppers in the header:
  - text size: A− [value] A+
  - gap (word-grid layout only): ⇥⇤ [value] ⇤⇥
  - each is 40px high, radius 20, with 34px buttons
- **Mobile:** an **"Aa"** 40px button in the header, before Settings, that toggles a quick-adjust row under the header.
  - The row is centred and wraps. It holds 44px-high steppers: text size, plus gap in the word-grid layout.
  - The Aa button fills with `accent` while the row is open.
  - No trip to Settings is needed.


## Update 4: transliteration is opt-in
- `ReaderSettings.showTransliteration` defaults to **false**, and the setting is persisted.
- The point is to build Arabic reading, so never show transliteration by default.
- The toggle appears in two places: the reader settings sheet ("Transliteration", above Tajwīd colours) and the app Settings screen (Reading → "Show transliteration", under Show translation). Its subtitle reads "Off by default, so you learn to read the Arabic itself".
- When it's on:
  - **Āyah cards:** each word becomes a column with the Arabic, and under it the transliteration in Hanken Grotesk 600 at `max(11, arabicSize × 0.3)`, coloured `accent`.
  - **Word grid:** the transliteration shows under each word.
- When it's off, nothing renders under the words.
- The Word sheet (tap a word) still shows the transliteration, because there the user has asked for it.


## Update 5: icon font
Use the bundled `QiraahIcons` font for every UI icon, and don't add Lucide or Phosphor. Setup, the full name list and the screen mapping are in `ICONS.md`. Font and asset declarations are in `flutter/pubspec_snippet.yaml`.

## Bundle layout
```
README.md                  this spec (read first)
ICONS.md                   icon font guide
Qiraah App.dc.html         interactive prototype (open in a browser; M toggles the phone and desktop views)
App Icon Options.dc.html   app-icon explorations (1a chosen)
support.js                 prototype runtime
assets/icon-glyph.png      launcher glyph (icon 1a)
flutter/
  assets/fonts/QiraahIcons.ttf
  assets/ornaments/rosette.svg  ayah_marker.svg   (reference; Dart painters reproduce them)
  lib/qiraah_icons.dart
  lib/qiraah_ornaments.dart     gradients, Rosette, AyahMarker, SurahHeader
  lib/qiraah_icons_example.dart
  pubspec_snippet.yaml
icons/
  svg/*.svg  codepoints.json  preview.png
```


## Ornate borders & gradients (Settings → Style)
Two toggles, default ON. No background patterns anywhere.
- **Ornate borders** — Muṣḥaf surah header: band in page frame colour (soft fill, frame-tinted ends), inset double rule, wide pill cartouche (fills the band, ~1.4em side padding) on paper, small 8-point rosette each end; thin double frame on every page; reader surah banner gets the same treatment. Off = plain single-border headers.
- **Gradients** — deliberately very slight and dark: hero #09271F→#0F3B32 (140°), primary #0B5F4C→#0E7059; near-flat screen/side backgrounds. Per-theme stops in the `GR` table in Qiraah App.dc.html. Off = flat colours.


---

## Update 6: polish pass (overrides anything above)

### 6.1 Qur'ān font
- Use **KFGQPC Uthmanic Script HAFS** (family `Hafs`) for the Muṣḥaf, the reader in Madani script, Verse of the day, bookmarks and onboarding samples. Fallback `AmiriQuran`. Indo-Pak stays on `NotoNaskhArabic`.
- The font is **not bundled** (licence). Download it from the King Fahd Complex developer page and place it at `assets/fonts/UthmanicHafs_V22.ttf` (see `pubspec_snippet.yaml`).
- Production Muṣḥaf: for pixel-true Madani 15-line pages use the per-page **QPC V2** fonts (604 fonts, one per page, glyph codes from the quran.com/QUL dataset) and render each line with `FittedBox(fit: BoxFit.scaleDown)` so it never overflows. Āyah markers stay as `AyahMarker` widgets, not font glyphs.

### 6.2 Āyah markers
- Every āyah end is an `AyahMarker` (8-point outlined star + ring, Arabic-Indic numeral).
  - Verse cards: 30px badge before the "1:2" reference.
  - Recite text and Muṣḥaf: inline `WidgetSpan`, 1.35em, `alignment: PlaceholderAlignment.middle`.
- Colours: stroke is gold (light `#C9A253`, dark `#CFAE62`, mono `#9A9A9A`) when Ornate borders is on, otherwise the theme accent. Fill is the card or page paper. When that āyah is playing, the fill becomes the page `hl` colour.

### 6.3 Ornate borders & gradients (Settings → Style)
- Two persisted toggles in `SettingsController`: `ornate` (default true) and `gradients` (default true). There are **no** background patterns anywhere.
- `SurahHeader` in `qiraah_ornaments.dart` is the Muṣḥaf header. The pill cartouche **fills the band** between the two rosettes; title at 0.82em, line-height 1.75. When off, it's a plain single box on `soft`.
- Every Muṣḥaf page gets a thin frame: 1px `frame` at 60% opacity, 3px outer offset and 4×8 padding (special pages 1–2 keep their 1.5px frame).
- Reader surah banner: the same treatment with 22px rosettes, a pill around the name (2/56/4 padding), the band ends tinted gold at 12% and 10px above the "Meccan · 7 āyāt" line.
- Gradients are deliberately **dark and very slight**. Use `QGradients.of(theme)` for the hero card, primary buttons, screen background and sidebar; flat colours when off. The Muṣḥaf desk keeps a faint paper-tinted radial vignette (13% alpha).

### 6.4 Home hierarchy
- **Verse of the day** is editorial: centred, a small-caps label between two 28px gold hairlines (light `#B4862C`, dark `#C9A253`, mono `#8A8A8A`), Hafs 36px, translation in Newsreader italic 18px, then "Al-Fātiḥah · 1:2" and a 44px outlined play button.
- Streak day squares are capped at **36px** and never stretch.
- **Desktop ≥1280px wide:** a two-column grid (`1.45fr / 1fr`, 14px gap, page max 1200). Left: Continue reading, Today's lesson, Explore. Right: Streak, then Verse of the day.
- **Settings ≥1280px:** two columns (Theme/Style on the left, Reading/the rest on the right, 32px gap).

### 6.5 Motion
- Every route fades in (`FadeTransition`, 220ms ease).
- Desktop Muṣḥaf page turn: fade out plus slide 16px in the direction of travel (150ms), swap pages, then fade back in (160ms). Mobile keeps the swipe `PageView`.
- Empty states and bookmark cards rise in (opacity plus 8px translate, 250–300ms).

### 6.6 Onboarding (first launch only)
- A full-screen route on the hero gradient, three steps with dot progress (the active dot is 22px wide and gold `#E3C27A`, the others 6px) and Skip in the top right.
  1. **Welcome:** glyph tile (88px, radius 26, gold glyph mask), Bismillah in Hafs 30px gold, "Qiraah" in Newsreader 46px and a one-line promise.
  2. **How would you like to read?** Script cards (Madani / Indo-Pak, each showing a sample in its own font) and the reciter list (radio rows).
  3. **Set a gentle goal:** 5 / 10 / 15 / 20 min tiles plus a Daily reminder switch.
- Selected items get a 1.5px `#E3C27A` border and a 10% gold fill; unselected ones a 16% cream border.
- Bottom bar: a 54px Back circle (from step 2 on) and a 54px cream CTA (Begin, then Continue, then Start reading).
- Content is centred when it fits and scrolls from the top when it doesn't (`SingleChildScrollView` + `ConstrainedBox(minHeight)`, never clip the title).
- Persist `onboarded = true` on finish or Skip. Settings has a "Show welcome again" text button at the bottom.

### 6.7 Qur'ān list: Bookmarks tab and empty states
- A segmented control under the search field: **Sūrahs** | **Bookmarks · n**.
- Bookmark cards show a gold filled bookmark icon, "Al-Fātiḥah · 1:2", Open, the āyah in Hafs 24px and the translation. Tapping opens the reader at that āyah.
- **No bookmarks:** a 72px accent-soft circle with the bookmark icon, "No bookmarks yet" (Newsreader 24px), a hint line and an "Open Al-Fātiḥah" primary button.
- **No search results:** a 64px circle with the search icon, "No sūrah matches “q”", the hint "Try a number like 36, or a name like Yāsīn." and a "Clear search" outline button.

### 6.8 Reader tajwīd key
- When tajwīd colours are on, a collapsible card sits under the surah banner: a 44px header with five 8px colour dots, "Tajwīd colour key" and a chevron that rotates 180°.
- Expanded, it shows chips (rule dot plus name, tinted text) for Madd, Madd lāzim, Silent, Qalqalah and Ikhfāʾ/Ghunnah. It stays collapsed by default and its open state is not persisted.

### 6.9 Contrast tokens (replace earlier values)
- `ink3` / `mut`: light `#6F7671` / `#6B726D`, mono `#6E6E6E` / `#6A6A6A`, night `#8F9893`, oled `#878F8B`. All reach ≥4.5:1 on `card`.
- Muṣḥaf `sub`: cream `#6F6656`, white `#6F7671`, mono `#6E6E6E`, night `#929B96`, oled `#878F8B`.
- Muṣḥaf `frame` (gold): night `#CFAE62`, oled `#BE9A4E` (brighter than before).

---

## Final checklist for Claude Code
1. Merge `flutter/pubspec_snippet.yaml`, copy `flutter/assets/**` and `flutter/lib/*.dart` into the app, and download the fonts listed there (Google Fonts plus the KFGQPC Hafs font).
2. Theme tokens (Update 2 §1, with the 6.9 overrides) plus `QGradients`, and `SettingsController` including `ornate`, `gradients` and `onboarded`.
3. Shell (mobile tabs / collapsible desktop sidebar), the route fade and the onboarding gate.
4. Home (6.4) → Qur'ān list with Bookmarks (6.7) → Reader: cards, word grid, recite, `AyahMarker`, banner and tajwīd key → audio player (Update 2 §3).
5. Muṣḥaf: page colours, the 3 desktop view modes, `SurahHeader`, page frame, page-turn motion.
6. Learn: Qāʿidah path, letters, quiz, Tajwīd Academy, tracing.
7. Settings: every toggle, including Style, two columns on wide screens and "Show welcome again".
8. Check Light / Mono / Night / OLED × ornate on/off × gradients on/off on a phone, a 1024px window and a 1440px window. No text below 4.5:1, and no clipped Arabic at a 120px text size.
