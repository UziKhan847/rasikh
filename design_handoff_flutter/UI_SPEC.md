# UI elements spec

This covers the look of every UI element in the redesign, not just the backdrop. The code is in `lib/kids_backdrops/kb_components.dart` (the elements) and `kb_screens.dart` (all 13 screens assembled from them). The source of truth is `source/Kids Backdrops.dc.html`. Every value below comes from its inline CSS.

## 1. Rules for any element

1. **Solid faces.** Cards, tiles and buttons are opaque (`surface`, `tile`, `cardDeep`, `reward`). There are no translucent cards and no glass or blur panels.
2. **Hard bottom edge + soft shadow.** Every raised element has a darker copy of its own shape 3–8 px below it (the "edge"), plus a soft black drop shadow. This makes the chunky 3D look, and it's what the old UI was missing. → `KbSurface` + `KbElev`.
3. **Selection = outside ring + accent edge.** A selected or current item gets a 3–4 px `accent` ring outside the shape, and its edge colour changes to `accentEdge`. The size doesn't change.
4. **Text on the backdrop** is limited to headings and one-line subtitles. They are white with an 8-direction deep outline and a drop edge (`KbHeading`, `KbSubtitle`). Anything longer goes on a card.
5. **Buttons with a text label** are either `cardDeep` with white text (primary) or `surface` with `linkInk` text (secondary). Plain `accent` is only for icon-only buttons and progress fills, because white on accent fails contrast on several themes.
6. **Letters always sit on a tile.** Never put an Arabic glyph directly on the backdrop.
7. **Locked items stay solid.** Locked content fades (grey + 40 %), or gets a small lock badge. The card itself never goes transparent.
8. **Colours come only from `KbUi`.** It derives every colour from the theme and mode, so Light/Dark/OLED and all 12 themes work automatically.

## 2. Colour tokens (`KbUi`)

| token | light | dark / oled | used for |
|---|---|---|---|
| surface | #FFFFFF | mix(dark, white, .09) / #161618 | card & tile faces |
| edge | mix(deep, white, .45) | #000000 | edge under surface elements |
| ink / inkSoft | text / mix(text, white, .3) | #F5F2EE / mix(#F5F2EE, surface, .35) | text on cards |
| tile / tileInk | mix(bright, white, .72) / deep | mix(dark, accent, .35) / mix(bright, white, .3) | glyph tiles, selected tile bg |
| cardDeep / cardDeepEdge | deep / mix(cardDeep, black, .45) | mix(deep, accent, .25) / same | primary buttons, practice card |
| accent / accentEdge | accent / deep | accent / mix(deep, black, .4) | selection ring, progress, icon buttons |
| reward / rewardEdge / rewardInk | reward / mix(reward, black, .3) / mix(text, black, .35) | same | done states, earned badges, bingo pick |
| track | mix(bright, white, .78) | mix(surface, black, .35) | progress track, toggle off |
| linkInk | deep | bright | secondary button text, prices |
| good / bad | mix(#3DBE6E / #E2574C, surface, .75 / .6) with line #2E9E5B / #D2463B and edge #237A46 / #9E2F27 | | answer feedback |

## 3. Elevation (`KbElev`)

CSS `box-shadow: 0 E px 0 EDGE, 0 Y px B px rgba(0,0,0,A)`

| preset | E | Y | B | A | where |
|---|---|---|---|---|---|
| edge3 | 3 | – | – | – | small pills on cards, arrow dot, quiz bar |
| edge4 | 4 | – | – | – | back button, gem counter, Cancel, Get |
| edge5 | 5 | – | – | – | write-screen buttons, accent go button |
| edge6 | 6 | – | – | – | Start Learning / Next |
| pill | 4 | 10 | 20 | .20 | Listen, See the whole path |
| avatar | 4 | 8 | 14 | .18 | avatar picker cell |
| tile | 5 | 10 | 20 | .18 | badge, stat, option, theme shop tile |
| option | 5 | 10 | 18 | .18 | quiz answer, gender chip |
| letter | 5 | 10 | 18 | .20 | bingo cell |
| field | 5 | 12 | 24 | .18 | name field |
| card | 6 | 14 | 28 | .20 | list cards, rank row, looks row, settings card |
| cardHi | 6 | 14 | 28 | .22 | Home next card, Me avatar |
| cardDeep | 6 | 14 | 28 | .25 | Practice card (+ 2 px inner top highlight) |
| game | 6 | 12 | 20 | .20 | three-in-a-row & memory cells |
| big | 7 | 16 | 30 | .25 | lesson letter cards, profile avatar, quiz word |
| board | 7 | 18 | 34 | .28 | writing board |
| hero | 8 | 20 | 40 | .30 | Hamzah card |

## 4. Radii and type

- **Radii:** cards 24 (rows 22, hero 32, board 30), tiles 20, glyph tiles 18–20 (big 28–30), buttons 999 (pills) or 30 (big), chips 18, field 22, nav top 28.
- **Type:** Baloo Bhaijaan 2. Page title 30/800 (Me name 32, game titles 32, Home sections 25, Rewards sections 23, settings sections 21). Card titles 20–22/800. Body 16/600. Captions 15/600. Buttons 18–22/800.
- **Arabic letters:** Noto Naskh Arabic 600. **Quranic words:** Amiri Quran 400, line height 1.9.
- **Padding:** Pill padding has more space on top than bottom (e.g. 9 / 7). This is intentional, because Baloo's baseline sits high. Keep it.

## 5. Elements → widget

| prototype element | widget |
|---|---|
| Page heading on sky | `KbHeading(text, fontSize:)` |
| Subtitle on sky | `KbSubtitle` |
| Any raised box | `KbSurface(color, edge, elev, radius, outline)` |
| Secondary / primary pill | `KbPill(kind: surface / deep / outlined)` |
| Start Learning / Next | `KbBigButton` (disabled = `disabledBg`, inkSoft) |
| Back / go round button | `KbRoundButton(accent:)` |
| Progress | `KbProgress`, quiz: `KbFramedProgress` |
| Gem balance | `KbGemCounter` |
| Home next-lesson card | `KbNextCard` |
| Home lesson path (zig-zag, dashed line) | `KbLessonPath` / `KbPathNode` |
| Practice card | `KbDeepCard` |
| Learn list card | `KbLearnCard` |
| Leaderboard row | `KbRankRow` |
| Badge | `KbBadgeTile` |
| Theme shop tile | `KbThemeShopTile` |
| Looks row (owned / for sale) | `KbLooksRow` |
| Stat tile | `KbStatTile` |
| Appearance / text-size option | `KbOptionTile` |
| Setting + switch | `KbSettingCard` + `KbToggle` |
| Avatar picker cell | `KbAvatarPickerTile` |
| Gender chip | `KbChoiceChip` |
| Name field | `KbTextField` |
| Bingo / TTT / memory / quiz cell | `KbGlyphCell(state:)` |
| Bottom nav | `KbNavBar` |

## 6. Screens

`kb_screens.dart` has all 13: Home, Learn, Rank, Rewards, Me, New Profile, Lesson step, Write, Letter Bingo, Three in a Row, Memory Match, Warm-up quiz and Hamzah card. They use the prototype's demo data. Map them onto your real screens by keeping the widget tree and spacing, and replacing the data with your models.

`KbGallery` is a debug screen with the same switcher as the prototype (long-press). Use it to compare against the HTML side by side.
