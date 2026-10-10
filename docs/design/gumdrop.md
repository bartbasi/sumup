# Direction 1: Gumdrop

**Tactile candy.** Chunky tiles you want to press.

## Concept

Every tile is a squircle with a darker lip underneath, like a keycap or a gummy sweet sitting on a tray. When your finger joins a tile to the chain it presses down into the tray, and the chain is a white rope that shows in the gaps between tiles, so a chain reads as beads on a string. Small values are bright candy colors, big values turn into deep jewel tones, and the rarest tiles become licorice, pearl and gold with a candy colored rim. Everything sits in soft rounded containers: a tray for the board, pills for the scores, a floating dock for the boosters. Motion is springy, with overshoot on arrival and a squash when tiles land.

## Layout (1080 by 2400)

- Top row: round settings button on the left, a "Best" pill on the right. Below it the score, centered and huge.
- Board in a rounded tray, 36 px from the screen edges.
- Boosters in a floating rounded dock above the gesture bar. Each booster is a raised button with its cost inside.
- Chain preview: a white bubble above the last tile in the chain, holding a mini tile of the result.
- Game over: the board dims under a plum scrim and a rounded card springs up from the bottom with the score, the best tile as a real tile, and a big pink "Shuffle for 1,500" button.
- Settings: the same card style, with a chunky toggle and skin chips that show three mini tiles each.

## Palette

| Token | Hex | Use |
|---|---|---|
| bg | #150820 | screen background, deep plum |
| tray | #20112F | board tray |
| slot | #2A1A3A | empty cell while tiles fall |
| surface | #2B183D | pills, dock, cards |
| surface_raised | #3F2956 | booster buttons, secondary buttons, chips |
| surface_lip | #090213 | lip under raised surfaces |
| ink | #FFF7FC | main text |
| ink_soft | #D3BDE5 | labels |
| ink_dark | #1C0D2B | text on bright fills |
| accent | #FF63B2 | hot pink: primary button, active booster |
| accent_pressed | #EB4B9F | |
| accent_lip | #A9246E | |
| lemon | #FFDC4F | hint pill, new best badge |
| lemon_lip | #BF9007 | |
| disabled_surface | #1D1625 | booster you cannot afford: flat, no lip |
| disabled_ink | #A39AAE | its icon and cost |
| chain, target | #FFF7FC | rope, rings; target ring has a #1C0D2B edge |
| scrim | #150820 at 78% | behind dialogs |

## Tile ramp

| Value | Fill | Number | | Value | Fill | Number |
|---|---|---|---|---|---|---|
| 2 mint | #35F3B5 | #1C0D2B | | 2K amethyst | #7D24D3 | #FFF7FC |
| 4 sky | #58CCFF | #1C0D2B | | 4K fuchsia | #B70385 | #FFF7FC |
| 8 periwinkle | #9398FF | #1C0D2B | | 8K ruby | #C2152F | #FFF7FC |
| 16 orchid | #E17AF8 | #1C0D2B | | 16K ember | #AB4B01 | #FFF7FC |
| 32 bubblegum | #FF81B6 | #1C0D2B | | 32K licorice | #2C1A3F | #FFF7FC |
| 64 watermelon | #FF6170 | #1C0D2B | | 64K pearl | #FDF1FC | #1C0D2B |
| 128 tangerine | #FF9A5F | #1C0D2B | | 128K gold | #F7C243 | #1C0D2B |
| 256 lemon | #FFDC4F | #1C0D2B | | above 128K | #F7C243 | #1C0D2B |
| 512 emerald | #047B60 | #FFF7FC | | | | |
| 1024 sapphire | #1957D2 | #FFF7FC | | | | |

From 32K up every tile also gets a candy rim, so the rare tiles never rely on color alone. Lowest tile contrast: 512 at 4.98:1.

## Type

System font (Roboto on Android, Segoe UI on Windows), heavy throughout, sentence case.

| Role | Size | Weight | Tracking |
|---|---|---|---|
| display (score) | 136 | 900 black | -2 |
| title | 76 | 900 | -1 |
| body | 46 | 700 | 0 |
| label | 34 | 700 | +1 |
| tile number | 48% of tile for 1 character, 44% for 2, 36% for 3, 28.5% for 4 | 900 | -1 |

## Shape

Tile corners 30% of the tile side. Lip 7.5% of the side, color = fill darkened 34%. Gaps 18 px, tray padding 22 px, tray radius 60 px. Dock 208 px tall, radius 68 px. Buttons radius 44 px with a 10 px lip.

## Motion

Springy and physical. Tiles pop in from 20% scale with a back ease (0.32 s, 35 ms stagger). Chained tiles press in (0.10 s). On merge the chain tiles get sucked into the last tile (0.18 s, back ease in) and the result pops to 122% with an elastic settle (0.34 s). Falling tiles overshoot and squash 12% on landing (0.28 s). Buttons press to 92% and spring back (0.30 s). A targeted tile wobbles 4 degrees on a 0.9 s loop.
