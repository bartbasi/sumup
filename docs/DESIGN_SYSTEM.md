# numbersgame Design System

Owner: senior-graphic-designer. Status: Phase 2, for building in Phase 3.

This document specifies every visual value of the three built in skins: **Gumdrop** (the default), **Slate** and **Nova**. By Bart's decision the tile-board-artist writes the SkinData resources (src/skins/<id>/<id>.tres) from it, the ui-motion-artist builds the Themes, icons and motion helpers from it, and the senior-graphic-designer reviews both. Nobody invents a value: if one is missing, ask.

How the code reads skins (class names, methods, signals, file layout) is in docs/ARCHITECTURE.md. This document gives the token names, the values, and how each component looks and moves.

**Checked source.** Three scripts prove the values that ship. They load the SkinData resources (src/skins/<id>/<id>.tres) through SkinCatalog, label tiles with NumberFormat.tile_label, and the label check measures each skin in its own font (Outfit for Gumdrop and Nova, the system font for Slate):

```bash
godot --headless --path . --script res://tools/contrast_check.gd   # every number on its tile, every text pair: 4.5:1 or better
godot --headless --path . --script res://tools/ramp_check.gd       # neighboring tile colors look different (section 1.3)
godot --headless --path . --script res://tools/label_check.gd      # labels fit, digits 12 dp or more
```

The Phase 1 token files `tools/directions/<skin>/tokens.gd` still mirror this document for the prototypes, and the skin tests in tests/skins/ prove that every SkinData resource holds exactly those values.

If this document and a token file or a SkinData resource disagree, this document wins and the other is a bug.

## Contents

1. Principles
2. Canvas, units and layout
3. The skin token schema
4. Gumdrop (default)
5. Slate
6. Nova
7. Shared screen arrangements
8. Hard Stop 1 review fixes
9. Launcher icon

---

## 1. Principles

### 1.1 Everything is made in code

Every visual is drawn in code: StyleBoxFlat, Theme resources, `_draw()`, gradients and meshes built in code, canvas_item shaders that work on the Compatibility renderer, and Tweens. The only files that are not code are the Outfit font and its license in src/design/fonts/ (docs/ASSETS.md), and the launcher icon PNGs, which a tool script draws (section 9).

### 1.2 The number is always shown

Every tile shows its label. Color is never the only signal. The label sits on the flat tile fill and nothing passes through the label's bounding box (a chain line, a ring, a glow, a shine, a highlight): the contrast check proves fill against number, so that pair must be what the eye sees. Where a line must pass under a number (Slate), a plate of the tile fill covers the whole label first.

### 1.3 Neighbors never look alike

Small tile clearing (GDD D-38) keeps about ten consecutive values on the board. The four values of the spawn window are the most common tiles, and a chain is built from equal and double values. So every ramp is **categorical**: each step jumps far round the hue wheel (about 144 degrees, a pentad step), tiles take the lightness at which their hue is most vivid, and tiers separate the hues that repeat. The ramp check holds the OKLab distance between tile fills to:

| Pair | Minimum OKLab distance |
|---|---|
| A value and its double | 0.17 |
| Two steps apart (times 4) | 0.12 |
| Three steps apart (times 8) | 0.09 |
| Any tile against the skin background | 0.15 |

For scale: 0.02 is about the smallest visible step, and the Hard Stop 1 complaints were all pairs at 0.07 to 0.12.

### 1.4 Contrast

Every tile number on its fill, and every text color on its background, is at least 4.5:1 (WCAG 2 relative luminance). Text may only be drawn with a pair listed for its skin in section 4, 5 or 6. A new combination needs a new pair here and in the token file first.

### 1.5 Performance

Target 60 fps on a mid range Android phone with a full board.
- Redraw only when something changes.
- Build StyleBoxes, gradients and arrays once and reuse them; no allocation inside `_draw()` or `_process()`.
- No per tile shaders. Glows use one radial gradient texture made once and drawn tinted.
- No MSAA. Antialias with StyleBoxFlat `anti_aliasing = true` (corner_detail 12 or more for squircles) and `antialiased = true` on `draw_line`, `draw_polyline`, `draw_arc` and `draw_circle`.

### 1.6 Motion and input

A move's animation follows a fixed order, and input reopens (GDD D-35) when every tile is at rest on its cell. Decorative tails (Nova's glow bloom, the clear notice) may keep running and never block input. See each skin's motion table for the timings.

---

## 2. Canvas, units and layout

### 2.1 Canvas and units

- The base canvas is **1080 by 2400 logical px**, portrait, stretch mode `canvas_items` with aspect `expand`. On a phone wider than 9:20 the logical canvas grows sideways (for example 1200 by 2400 on 18:9, 1350 by 2400 on 16:9) and everything scales by the phone's height over 2400.
- Every length in this document is in logical px on that canvas unless it says "fraction of the tile side" or dp.
- On a 360 dp wide 20:9 phone, 3 logical px are 1 dp.

### 2.2 Safe areas

- Read the safe area from the display (notch, punch hole, rounded corners, gesture or button bar). No text and no touch target sits outside it.
- Backgrounds, the board tray, the scrim and sheet panels extend under the insets to the screen edges.
- The HUD's top edge sits on the safe area's top. The booster bar's bottom edge sits on the safe area's bottom. A bottom sheet runs to the screen edge and pads its content by the bottom inset.

### 2.3 The play screen stack

From top to bottom: HUD (`hud_height`), `space_s`, board, `space_s`, booster bar (`bar_height`, which includes the hint row). The board takes the largest size that fits:
- Width: at most the canvas width less `board_margin` on each side.
- Height: the board's preferred height for that width, which must fit between the HUD and the bar. If it does not, the board shrinks evenly and stays centered.
- The board never stretches. Tiles stay square (orbs round).

Board preferred height for a tile side `t`:

| Skin | Board height | Board width |
|---|---|---|
| Gumdrop | 8t + 7 x `board_gap` + 2 x `board_padding` | 5t + 4 x `board_gap` + 2 x `board_padding` |
| Slate | 8t + 7 x `board_gap` | 5t + 4 x `board_gap` |
| Nova | 8 x pitch, orb diameter t = `orb_scale` x pitch | 5 x pitch |

### 2.4 Tile size targets (GDD A-1)

Full spec on 18:9 phones (360 by 720 dp) and taller: tiles at least 56 dp, 4 character digits at least 12 dp. 16:9 phones get smaller tiles with the same proportions. Worked out from the token heights in this document at 3x density, with a 24 dp status bar and a 24 dp gesture bar (20:9: a 40 dp status bar with a camera cutout and a 22 dp gesture bar):

| Phone | Gumdrop | Slate | Nova |
|---|---|---|---|
| 20:9, 360 x 800 dp | 60.5 dp | 63.5 dp | 58.2 dp |
| 18:9, 360 x 720 dp | 56.9 dp | 59.6 dp | 57.1 dp |
| 16:9, 360 x 640 dp, gesture bar | 49.9 dp | 52.3 dp | 50.2 dp |
| 16:9, 360 x 640 dp, 48 dp button bar | 46.9 dp | 49.3 dp | 47.5 dp |

To get there, Gumdrop's HUD and dock were slimmed (section 8) and Nova's display size and ring buttons trimmed.

### 2.5 Tile labels (GDD D-31)

- Label rule: the full number up to 1024. From 2048 up, a number from 1 to 512 followed by K, M, B or T in steps of 1024: 2K, 64K, 128K, 1M, 1B, 1T. At most 4 characters up to 2^49.
- Size: `tile_number_scale[length - 1]` times the tile side (Nova: the orb diameter). The label never grows wider than `label_fit` times the side. If a phone's font renders wider than measured, shrink that label until it fits.
- Labels are data, not prose: never apply a case rule to them ("2K" never becomes "2k").
- Costs, the merge preview and Best Tile use the tile label format (D-32). The score is shown in full with commas.

### 2.6 The score fits

The score must fit 13 characters (GDD 14.2: 9,999,999,999). It is set in the display role. When it is too wide for its slot, its size shrinks until it fits, never below `display_fit_min`. Counting up (`score_count`) uses the final value's size for the whole count, so the number never jumps in size while it runs.

### 2.7 Touch

Every touch target is at least `touch_min` (144 px, 48 dp on a 360 dp wide phone) on each side, even where the drawn shape is smaller. Tiles are larger than that on every supported phone.

---

## 3. The skin token schema

Every skin defines every shared name below. Anything else a skin needs is an **extra**, listed under "Extras" in its section. Production code reads tokens through the SkinData API that ARCHITECTURE.md defines (fill for a value, ink for a value, tier for a value, color, number, motion spec, font, font size, cased text, tile font size, score font size).

### 3.1 Identity

| Name | Meaning |
|---|---|
| id | gumdrop, slate or nova |
| display_name | shown in the skin picker: Gumdrop, Slate, Nova |
| font_family | outfit or system |

### 3.2 Palette roles

| Role | Meaning |
|---|---|
| bg | screen background |
| surface | cards, sheets, pills, dock |
| surface_raised | raised controls: secondary buttons, chips, booster buttons |
| line | hairlines, dividers, ring outlines |
| ink | main text on dark |
| ink_muted | labels and secondary text on dark |
| ink_dark | text on bright fills |
| accent | primary button, active booster, selected chip |
| accent_pressed | accent while pressed |
| disabled_ink | text and icons of a disabled control |
| chain | chain line and the mark on chained tiles |
| target | press feedback and the Swap selection in targeting |
| joinable | the joinable highlight (D-40) |
| scrim | overlay behind dialogs, with alpha |
| badge | fill of badges: hint, Suggested, New best, the clear notice |
| badge_ink | text on badge |

### 3.3 Tile ramp

| Name | Meaning |
|---|---|
| tile_fill[17], tile_ink[17] | fill and number color for 2, 4, 8 ... 131072 |
| beyond_fill, beyond_ink | for every value above 131072 |
| tile_tier[17], beyond_tier | an integer per value; what a tier changes is per skin |

### 3.4 Type

| Name | Meaning |
|---|---|
| type roles | display (score), title, body (buttons, rows), label (small labels, costs), tile (numbers). Each has size (px; not for tile), weight (100 to 900), tracking (px between glyphs) and case (none, upper, lower) |
| tile_number_scale[4] | tile label size as a fraction of the tile side, for 1, 2, 3 and 4 characters |
| label_fit | widest label, fraction of the tile side |
| display_fit_min | smallest size the score may shrink to |

Outfit is a variable font: weights are set on its `wght` axis by integer tag (the string key "wght" is ignored in Godot 4.7). The system font is a SystemFont asking for Roboto, then Segoe UI, then sans-serif. Phones then use Roboto and Windows uses Segoe UI; plain sans-serif alone gives Arial on Windows.

### 3.5 Shape, layout and sizes

| Name | Meaning |
|---|---|
| board_margin | screen side to board, at most |
| board_gap | between tiles |
| board_padding | board edge to the outer tiles (Gumdrop's tray padding) |
| tile_radius | corner radius, fraction of the tile side (0.5 is a circle) |
| preview_scale | merge preview tile, fraction of the board tile |
| special_from | lowest value with the special treatment |
| chain_width | width of the chain line |
| chain_ring | thickness of the mark on chained tiles |
| joinable_ring | thickness of the joinable highlight |
| target_ring | thickness of the press feedback |
| space_xs, space_s, space_m, space_l, space_xl | spacing scale |
| touch_min | smallest touch target side |
| radius_button, radius_card, radius_chip | corner radii, px |
| hairline | divider thickness |
| hud_height, bar_height, hint_height | play screen heights (bar_height includes the hint row) |
| button_height, row_height | buttons and settings rows |
| icon_booster, icon_hud, icon_stroke | icon sizes; stroke on the 24 unit icon grid |
| toggle_w, toggle_h, toggle_knob | sound toggle |
| notice_height | the clear notice pill (Slate: the HUD context row it takes over) |
| notice_tile_scale | mini tiles in the clear notice, share of notice_height |
| notice_strike | the strike line across those mini tiles |

### 3.6 Motion names

Each has a duration (seconds; for loops the period), a transition and an ease (Godot Tween values), plus extras named in the skin's table.

| Name | Used for |
|---|---|
| spawn | new tiles appearing |
| fall | tiles falling after a clear |
| chain_add, chain_remove | a tile joining or leaving the chain (backtrack) |
| joinable_in | the joinable highlight appearing and moving |
| merge_travel | chain tiles moving into the last tile |
| merge_pop | the result tile arriving |
| clear | small tiles clearing (D-38) |
| clear_notice | the notice that says which values cleared (AT-104); extras: hold, out |
| press | press feedback under the finger in targeting |
| button_press, button_release | every button |
| dialog_in, dialog_out | sheets and panels |
| screen_fade | moving between screens |
| target_pulse | loop on the active booster and Swap's selected tile; 0 means still |
| score_count | the score counting up |
| skin_switch | switching skins live in Settings |

**Move sequence.** A committed chain plays: chain tiles `merge_travel` into the last tile, then `merge_pop` and `clear` together, then `fall` and `spawn` together (new tiles start as the falls land, staggered by `spawn.stagger` per tile in fill order). The clear notice appears with the clear and holds on its own. Input reopens when every tile is at rest.

---

## 4. Gumdrop (default)

Tactile candy. Chunky squircle tiles with a darker lip underneath, like keycaps or gummy sweets, on a deep plum night. Chains press tiles into the tray and string them on a white rope that shows in the gaps. Everything sits in soft rounded containers and moves with a springy bounce. Font: **Outfit**.

### 4.1 Palette

| Role | Hex | Use |
|---|---|---|
| bg | #150820 | deep plum |
| surface | #2B183D | pills, dock, cards, sheets |
| surface_raised | #3F2956 | booster buttons, secondary buttons, chips |
| line | #3F2956 | rounded divider, `hairline` thick |
| ink | #FFF7FC | |
| ink_muted | #D3BDE5 | |
| ink_dark | #1C0D2B | every tile number |
| accent | #FF63B2 | hot pink |
| accent_pressed | #EB4B9F | |
| disabled_ink | #A39AAE | |
| chain | #FFF7FC | rope and chained ring |
| target | #FFF7FC | press ring, drawn with a target_edge outline |
| joinable | #FFDC4F | lemon ring, drawn with a target_edge outline |
| scrim | #150820 at 78% (#150820C7) | |
| badge | #FFDC4F | lemon |
| badge_ink | #1C0D2B | |
| **Extras** | | |
| tray | #20112F | board tray |
| slot | #2A1A3A | empty cell while tiles fall |
| surface_lip | #090213 | lip under raised surfaces, the dock and cards |
| accent_lip | #A9246E | lip under accent buttons |
| badge_lip | #BF9007 | lip under badges |
| disabled_surface | #1D1625 | flat face of a disabled booster |
| target_edge | #1C0D2B | dark outer edge of the target and joinable rings |
| shine | #FFFFFF | shine on tier 3 tiles, at shine_alpha |

### 4.2 Tile ramp

Every number is #1C0D2B. Tier 1 is sorbet, tier 2 is candy, tier 3 is neon with a shine, and tier 4 is special with the candy rim. Chroma rises by tier, so the big tiles are the most vivid on the board.

| Value | Label | Name | Fill | Contrast | Tier |
|---|---|---|---|---|---|
| 2 | 2 | mint | #8FFFD0 | 15.22 | 1 |
| 4 | 4 | lavender | #B681EF | 6.46 | 1 |
| 8 | 8 | lemon | #FFE47D | 14.58 | 1 |
| 16 | 16 | sky | #5DAFF1 | 7.77 | 1 |
| 32 | 32 | coral | #F37069 | 6.42 | 1 |
| 64 | 64 | aqua | #32F3FC | 13.45 | 2 |
| 128 | 128 | hot pink | #F721B6 | 5.12 | 2 |
| 256 | 256 | lime | #AAFA2E | 14.38 | 2 |
| 512 | 512 | periwinkle | #6A88FA | 5.71 | 2 |
| 1024 | 1024 | tangerine | #FB8822 | 7.57 | 2 |
| 2048 | 2K | azure | #3BBEFE | 8.74 | 3 |
| 4096 | 4K | cherry | #FE4F6D | 5.74 | 3 |
| 8192 | 8K | spring green | #5EFF8F | 14.17 | 3 |
| 16384 | 16K | grape | #D056FF | 5.66 | 3 |
| 32768 | 32K | electric blue | #2FA9FF | 7.22 | 3 |
| 65536 | 64K | pearl | #FDF1FC | 16.78 | 4 |
| 131072 | 128K | gold | #F7C243 | 11.17 | 4 |
| above | 256K and up | gold | #F7C243 | 11.17 | 4 |

Closest pairs (ramp check): neighbors 0.206, times 4 0.141, times 8 0.210.

### 4.3 Text pairs

| Pair | Text on background | Ratio |
|---|---|---|
| Score and HUD numbers | ink on bg | 18.36 |
| HUD labels | ink_muted on bg | 11.20 |
| Pill, dock and card text | ink on surface | 15.35 |
| Pill, dock and card labels | ink_muted on surface | 9.36 |
| Booster cost, secondary buttons, chips | ink on surface_raised | 12.00 |
| Labels on raised surfaces | ink_muted on surface_raised | 7.32 |
| Booster cost, targeting | ink_dark on accent | 6.73 |
| Booster cost, disabled | disabled_ink on disabled_surface | 6.53 |
| Badges (hint, Suggested, New best, clear notice) | badge_ink on badge | 13.66 |
| Primary button, selected chip | ink_dark on accent | 6.73 |
| Primary button, pressed | ink_dark on accent_pressed | 5.29 |
| Text straight on the scrim (worst case over a pearl tile) | ink on scrim | 9.88 |

### 4.4 Type (Outfit)

| Role | Size | Weight | Tracking | Case |
|---|---|---|---|---|
| display (score) | 120 | 900 | -1 | as written |
| title | 76 | 900 | 0 | as written |
| body | 46 | 700 | 0 | as written |
| label | 34 | 700 | +1 | as written |
| tile | 48%, 44%, 36%, 31% of the tile side for 1 to 4 characters | 900 | 0 | |

`label_fit` 0.88. `display_fit_min` 76. Outfit is tighter than the Segoe UI of the Phase 1 renders, so the display tracking went from -2 to -1 and the title and tile tracking from -1 to 0.

### 4.5 Shape and sizes

| Name | Value | | Name | Value |
|---|---|---|---|---|
| board_margin | 36 | | radius_button | 44 |
| board_gap | 16 | | radius_card | 60 |
| board_padding | 18 | | radius_chip | 40 |
| tile_radius | 0.30 | | hairline | 4 |
| preview_scale | 0.46 | | hud_height | 255 |
| special_from | 65536 | | bar_height | 272 |
| chain_width | 30 | | hint_height | 88 |
| chain_ring | 7 | | button_height | 144 |
| joinable_ring | 6 | | row_height | 144 |
| target_ring | 9 | | icon_booster | 84 |
| space_xs, s, m, l, xl | 12, 24, 36, 56, 88 | | icon_hud | 64 |
| touch_min | 144 | | icon_stroke | 3.5 |
| notice_height | 88 | | toggle_w, toggle_h, toggle_knob | 140, 76, 54 |
| notice_tile_scale | 0.6 | | notice_strike | 4 |

**Extras:**
- Tray: `tray_radius` 60.
- Lip: `lip_darken` 0.34 (lip color = fill darkened by this). Depth by tier, as a fraction of the tile side: `lip_t1` 0.060, `lip_t2` 0.075, `lip_t3` 0.090, `lip_t4` 0.090. `lip_pressed` 0.020.
- Lift: `joinable_lift` 0.030, `target_lift` 0.040.
- Shine: `shine_alpha` 0.35, `shine_from_tier` 3, `shine_inset` 0.05, `shine_width` 0.045 (fractions of the tile side).
- Rings and rim: `preview_ring` 6, `target_edge_width` 4, `special_rim_width` 8, `special_rim_segments` 16.
- HUD and dock: `hud_top_row` 96, `hud_button_face` 96, `pill_height` 96, `pill_radius` 48, `dock_height` 184, `dock_radius` 64.
- Buttons: `button_lip` 10, `button_lip_pressed` 3, `active_raise` 6, `focus_width` 5, `focus_gap` 6.
- Toggle: `toggle_knob_lip` 5.

### 4.6 Motion: springy

| Name | Duration | Transition, ease | Extras |
|---|---|---|---|
| spawn | 0.30 | back, out | from_scale 0.2, stagger 0.03 |
| fall | 0.26 | back, out | squash 0.12 on landing |
| chain_add | 0.10 | quad, out | press_scale 0.94 |
| chain_remove | 0.10 | quad, out | |
| joinable_in | 0.12 | sine, out | |
| merge_travel | 0.18 | back, in | |
| merge_pop | 0.34 | elastic, out | peak_scale 1.22 |
| clear | 0.28 | back, in | burst_dots 6, burst_dot_size 0.07 (of the tile side), burst_reach 0.6 (of the tile side), burst_fade 0.36 s |
| clear_notice | 0.30 | back, out | from_scale 0.6, hold 1.6, out 0.20 |
| press | 0.08 | quad, out | |
| button_press | 0.08 | quad, out | press_scale 0.92 |
| button_release | 0.30 | back, out | |
| dialog_in | 0.42 | back, out | from_offset 240 (rises from below) |
| dialog_out | 0.20 | quad, in | |
| screen_fade | 0.22 | sine, in out | |
| target_pulse | 0.90 | sine, in out | wobble_degrees 4 |
| score_count | 0.50 | cubic, out | |
| skin_switch | 0.30 | sine, in out | |

A committed chain settles in about 0.9 s: travel 0.18, pop and clear 0.34, then fall and spawn.

### 4.7 Components

**Tile**
- Squircle, corner radius `tile_radius` of the side.
- The lip is the full tile shape in fill darkened by `lip_darken`. The top face, in the fill, is raised by the tier's lip depth, so the lip shows only along the bottom. The label is centered on the face.
- Tier 3 and 4 tiles get a shine: a quarter circle arc in shine at `shine_alpha`, round caps, following the face's top left corner. Its center is the corner's radius center, its radius is the corner radius less `shine_inset` of the side, and its width is `shine_width` of the side. It stays above the label box at every label length.

**Tile states**
- *Normal:* as above.
- *Chained:* pressed in. The lip shrinks to `lip_pressed`, the face moves down with it, the tile is scaled to `press_scale` 0.94, and a `chain_ring` ring in chain sits just outside the face. It stays this way while the tile is in the chain.
- *Joinable (D-40):* the tile lifts by `joinable_lift` (lip deeper, face higher) and gets a `joinable_ring` lemon ring with a `target_edge_width` target_edge outline outside it, so it reads on every tile and on the tray. It eases in over `joinable_in` and moves as the chain changes. Never on a chained tile.
- *Press feedback (D-43):* while a finger is down on a tile in targeting mode, the tile presses in (lip_pressed) and gets a `target_ring` ring in target with a target_edge outline. It means only "this is the tile under your finger".
- *Selected (Swap's first tile):* lifted by `target_lift` with the same double ring, wobbling by `wobble_degrees` on the `target_pulse` loop.
- *Special (64K up):* a candy rim round the face, `special_rim_width` wide, in `special_rim_segments` segments cycling the tier 1 and 2 fills.

**Board**
- A rounded tray in tray (`tray_radius`), `board_padding` inside, `board_gap` between tiles.
- An empty cell (while tiles fall) shows a flat squircle in slot.

**Chain line**
- A rope in chain, `chain_width` wide, round caps and joins, drawn **under** the tiles from center to center, so it shows in the gaps like beads on a string.
- It also runs from the last tile toward the finger.

**Merge preview**
- A mini tile of the result (`preview_scale` of the tile side, with its lip) and a `preview_ring` ring in chain.
- It sits centered on the gap crossing at the top left corner of the last chain tile, or the top right corner when that tile is in column 0. It covers only the rounded corners of the four tiles round the crossing, never a label.

**Merge, spawn and fall**
- Merge: chain tiles get sucked along the chain into the last tile (`merge_travel`, back ease in). The result pops to `peak_scale` and settles elastically (`merge_pop`).
- Spawn: tiles pop in from `from_scale` with a back ease, `stagger` per tile in fill order.
- Fall: back ease out, with a `squash` on landing (scale y 1 - squash, x 1 + squash / 2, then back).

**Small tile clear (D-38)**
- Every cleared tile squashes and shrinks to nothing (`clear`, back ease in).
- At the end it bursts into `burst_dots` candy dots in its own fill color, each `burst_dot_size` of the tile side across. They fly out `burst_reach` of the tile side, evenly spaced round the circle, and fade over `burst_fade` seconds.
- All cleared tiles clear together.

**Clear notice (AT-104)**
- A badge pill, `notice_height` tall, in badge with a badge_lip lip. It is centered horizontally on the board's top edge, overlapping the seam between HUD and board, so it never covers the rows the player works in.
- Content: a mini tile (`notice_tile_scale` of `notice_height`) of each cleared value with a `notice_strike` px badge_ink strike line across it, then the text in the body role, badge_ink. Padding `space_s` left and right, items `space_xs` apart.
- Text: "No more 2s" for one value, "No more 2s or 4s" for two, "No more 2s to 8s" for three or more. Values use the tile label format ("No more 2Ks").
- Motion: it springs in (`clear_notice`, from `from_scale`), holds `hold` seconds, fades out over `out`. It never blocks input.

**HUD (slimmed)**
- Top row, `hud_top_row` tall:
  - The pause button on the left: a raised squircle, face `hud_button_face`, an `icon_hud` icon, touch area `touch_min`.
  - A Best pill on the right: surface with a surface_lip lip, `pill_height` tall, `pill_radius` corners, sides padded by `space_s`; "Best" in label role ink_muted, the number in body role ink.
- Under it, the score, centered, in the display role, auto fitting (section 2.6).
- No caption above the score.

**Booster bar**
- A floating dock, `dock_height` tall and `dock_radius` corners, in surface with a surface_lip lip. It sits `board_margin` from the screen sides, with five raised buttons inside.
- The `hint_height` row above it holds the hint pill.
- Each button: surface_raised face, `radius_button` corners, `button_lip` lip. The dock pads its buttons by `space_xs` all round and spaces them `space_xs` apart. The five faces share the width equally, and each face is `dock_height` less 2 x `space_xs` less `button_lip` tall. The icon (`icon_booster`) sits over the cost in the label role, as a tile label.
- Looks:
  - *Normal:* as above.
  - *Pressed:* scale `press_scale`, lip down to `button_lip_pressed`.
  - *Active (targeting):* accent face, accent_lip lip, raised `active_raise`; icon and cost in ink_dark; `target_pulse` wobble.
  - *Disabled:* flat (no lip), sitting lower, disabled_surface face, icon and cost in disabled_ink.
  - *Suggested (D-42, in the out of moves offer):* a "Suggested" badge pill (badge, badge_ink, label role) sits on the button's top edge.
- Hint: a badge pill in the hint row, for example "Tap a tile to smash it".

**Icons**
- Chunky candy pictograms: strokes `icon_stroke` on a 24 unit grid, round caps and joins, filled where it helps.
- Set: hammer, swap, shuffle, double (x2 drawn as strokes), undo, pause, settings, sound on, sound off, close, check.
- Colors: ink normally, ink_dark on accent, disabled_ink when disabled.

**Sound toggle**
- A pill track `toggle_w` by `toggle_h` with a surface_lip lip.
- Off: surface_raised track, ink knob (`toggle_knob`, with a `toggle_knob_lip` lip in surface_lip) on the left.
- On: accent track, knob on the right.
- It slides with button_release.

**Backdrop:** flat bg.

**Buttons, panels and chips**
- *Primary:* accent face, accent_lip lip, ink_dark text in the body role, `radius_button` corners, `button_height` tall. Pressed: accent_pressed.
- *Secondary:* surface_raised with surface_lip lip, ink text.
- *Chip:* surface_raised, `radius_chip` corners. Selected: accent with ink_dark text.
- *Card and sheet panel:* surface, `radius_card` corners, surface_lip lip, `space_m` padding.
- *Divider:* a `hairline` rounded line in line.
- *Focus:* a `focus_width` accent outline `focus_gap` outside the button.

---

## 5. Slate

Editorial and exact. Small values are dark slabs with the number in a bright tint of the same hue. From 128 up a tile is a solid block of color with a black number, so the big tiles are seen first. Sharp corners, hairline rules, left aligned type, numbers top left (clear of the thumb). Motion is fast cuts, nothing bounces. Font: **system font** (Roboto on Android).

### 5.1 Palette

| Role | Hex | Use |
|---|---|---|
| bg | #0B0C0E | near black |
| surface | #181A1C | sheets, chips |
| surface_raised | #212326 | pressed chips and buttons |
| line | #36383B | 2 px hairlines |
| ink | #F5F2E9 | paper white |
| ink_muted | #A1A5AB | |
| ink_dark | #0E0F12 | numbers on blocks, text on paper and accent |
| accent | #FA5D36 | signal vermilion |
| accent_pressed | #E14D28 | |
| disabled_ink | #7D8085 | |
| chain | #F5F2E9 | chain line, nodes, chained frame |
| target | #FA5D36 | corner brackets |
| joinable | #F5F2E9 | hollow node and thin frame |
| scrim | #0B0C0E at 82% (#0B0C0ED1) | |
| badge | #FA5D36 | hint bar, Suggested, New best, clear notice |
| badge_ink | #0E0F12 | |
| **Extras** | | |
| chain_edge | #0E0F12 | dark edge each side of the chain line |

### 5.2 Tile ramp

Tier 1 slabs (2 to 64) have a dark fill and a bright number of the same hue, lightness alternating between neighbors. Tier 2 blocks (128 to 16K) are solid color with a black number. Tier 3 (32K up) is a block with an inner hairline frame. Hues from 15 to 55 degrees are kept free for the vermilion accent, so brackets and the hint bar never sit on a tile of their own color.

| Value | Label | Name | Fill | Number | Contrast | Tier |
|---|---|---|---|---|---|---|
| 2 | 2 | forest slab | #115D1C | #95F198 | 5.88 | 1 |
| 4 | 4 | navy slab | #1E327D | #C9D7F9 | 8.06 | 1 |
| 8 | 8 | oxblood slab | #7F1F26 | #F9CAC8 | 6.73 | 1 |
| 16 | 16 | teal slab | #156561 | #58F3EA | 5.03 | 1 |
| 32 | 32 | aubergine slab | #4F1F6C | #E5CCF9 | 8.22 | 1 |
| 64 | 64 | bronze slab | #6E4B0F | #F9D097 | 5.42 | 1 |
| 128 | 128 | amber | #F59E33 | #0E0F12 | 8.96 | 2 |
| 256 | 256 | cyan | #49F6FB | #0E0F12 | 14.47 | 2 |
| 512 | 512 | magenta | #F74AD8 | #0E0F12 | 6.32 | 2 |
| 1024 | 1024 | lime | #C2FC44 | #0E0F12 | 15.79 | 2 |
| 2048 | 2K | periwinkle | #9191F6 | #0E0F12 | 6.92 | 2 |
| 4096 | 4K | gold | #F9CB3D | #0E0F12 | 12.45 | 2 |
| 8192 | 8K | sky | #39C4F8 | #0E0F12 | 9.51 | 2 |
| 16384 | 16K | pink | #F75EA7 | #0E0F12 | 6.49 | 2 |
| 32768 | 32K | mint | #48FAB4 | #0E0F12 | 14.25 | 3 |
| 65536 | 64K | lilac | #AF83F6 | #0E0F12 | 6.75 | 3 |
| 131072 | 128K | paper | #F5F2E9 | #0E0F12 | 17.12 | 3 |
| above | 256K and up | paper | #F5F2E9 | #0E0F12 | 17.12 | 3 |

Closest pairs (ramp check): neighbors 0.210, times 4 0.135, times 8 0.094.

### 5.3 Text pairs

| Pair | Text on background | Ratio |
|---|---|---|
| Score and HUD numbers | ink on bg | 17.48 |
| Labels, secondary numbers, toggle OFF | ink_muted on bg | 7.91 |
| Signal label (OUT OF MOVES, RUN OVER) | accent on bg | 6.23 |
| Booster name and cost, disabled | disabled_ink on bg | 4.94 |
| Paper fill: active booster, selected chip, toggle ON | ink_dark on ink | 17.12 |
| Badges and the targeting hint bar | badge_ink on badge | 6.10 |
| Primary button | ink_dark on accent | 6.10 |
| Primary button, pressed | ink_dark on accent_pressed | 4.83 |
| Text on surface (sheets, chips, pressed rows) | ink on surface | 15.59 |
| Labels on surface | ink_muted on surface | 7.05 |
| Text on raised surface | ink on surface_raised | 14.07 |
| Labels on raised surface | ink_muted on surface_raised | 6.37 |

### 5.4 Type (system font: Roboto on Android)

| Role | Size | Weight | Tracking | Case |
|---|---|---|---|---|
| display (score) | 184 | 700 | -4 | as written |
| title | 72 | 700 | -1 | as written |
| body | 44 | 500 | 0 | as written |
| label | 30 | 600 | +4 | CAPITALS |
| tile (top left) | 40%, 40%, 33%, 31% of the tile side for 1 to 4 characters | 700 | -1 | |

`label_fit` 0.84. `display_fit_min` 96. The display and title tracking eased from -6 and -2 to -4 and -1: Roboto sits slightly tighter than the Segoe UI of the Phase 1 renders.

### 5.5 Shape and sizes

| Name | Value | | Name | Value |
|---|---|---|---|---|
| board_margin | 44 | | radius_button | 4 |
| board_gap | 10 | | radius_card | 0 |
| board_padding | 0 | | radius_chip | 4 |
| tile_radius | 0.032 (6 px at 190 px) | | hairline | 2 |
| preview_scale | 0.59 (112 px) | | hud_height | 350 |
| special_from | 32768 | | bar_height | 192 |
| chain_width | 8 | | hint_height | 112 (the HUD context row) |
| chain_ring | 6 | | button_height | 144 |
| joinable_ring | 2 | | row_height | 148 |
| target_ring | 6 | | icon_booster | 66 |
| space_xs, s, m, l, xl | 8, 20, 40, 64, 104 | | icon_hud | 72 |
| touch_min | 144 | | icon_stroke | 2 |
| notice_height | 112 (the HUD context row) | | toggle_w, toggle_h, toggle_knob | 132, 64, 44 |
| notice_tile_scale | 0.5 | | notice_strike | 2 |

**Extras:**
- Tile number: `number_inset` 0.11, `number_plate` 6.
- Chain line: `line_edge` 3, `node_size` 24.
- Joinable and selected: `joinable_node_stroke` 3 (the hollow node's stroke; `joinable_ring` is the frame), `selected_frame` 4.
- Brackets and frame: `target_bracket` 0.30, `special_inset` 0.06.
- Merge flash: `flash_cut` 0.05.
- Bar: `strip_height` 192.
- Toggle: `toggle_knob_inset` 10.
- Focus: `focus_width` 4, `focus_gap` 4.

### 5.6 Motion: fast and exact

| Name | Duration | Transition, ease | Extras |
|---|---|---|---|
| spawn | 0.14 | expo, out | from_scale_y 0 (wipes down from the top edge), stagger 0 |
| fall | 0.16 | quart, out | |
| chain_add, chain_remove | 0.06 | linear | |
| joinable_in | 0.06 | linear | |
| merge_travel | 0.12 | quart, in | |
| merge_pop | 0.16 | expo, out | flash 1.0 (the result shows paper, then cuts to its color below flash_cut) |
| clear | 0.14 | expo, in | |
| clear_notice | 0.12 | expo, out | hold 1.6, out 0.12 |
| press | 0.04 | linear | |
| button_press | 0.04 | linear | |
| button_release | 0.10 | quart, out | |
| dialog_in | 0.24 | expo, out | from_offset 32 (slides up 32 px), from_alpha 0; never scales |
| dialog_out | 0.12 | quart, in | |
| screen_fade | 0.12 | linear | |
| target_pulse | 0 | | no pulse: Slate holds still |
| score_count | 0.24 | quart, out | |
| skin_switch | 0.16 | linear | |

A committed chain settles in about 0.45 s.

### 5.7 Components

**Tile**
- Flat fill, corners `tile_radius`, no shadow, no gradient.
- The label sits top left, its cap top `number_inset` of the side from the top and left edges.

**Tile states**
- *Chained:* a `chain_ring` frame in chain, inset inside the tile edge, plus a filled `node_size` square node in chain at the center.
- *Joinable (D-40):* a `joinable_ring` frame in joinable, inset like the chain frame, plus a hollow `node_size` square at the center with a `joinable_node_stroke` stroke. It means "the line can come here".
- *Press feedback (D-43):* four corner brackets in target, `target_ring` thick, arms `target_bracket` of the side, hugging the outside of the tile edge with no offset.
- *Selected (Swap's first tile):* the same brackets plus a `selected_frame` frame in target inside the edge. They hold still.
- *Marks on blocks:* paper vanishes on the light blocks. On tier 2 and 3 tiles the chained frame, the joinable frame and the hollow node draw in ink_dark instead of chain and joinable. Every node, filled or hollow, gets a `line_edge` outline in chain_edge, like the chain line, so it reads on any tile.
- *Special (32K up):* an inner hairline frame in ink_dark, `hairline` thick, inset `special_inset`.

**Board:** no tray and no background. An empty cell shows a `hairline` frame in line.

**Chain line**
- Drawn node to node in one piece, straight segments, square ends, no tail toward the finger.
- First a chain_edge line, `chain_width + 2 x line_edge` wide, then the chain line, `chain_width` wide. Square nodes sit on the chained tile centers.
- Draw order: fills, frames, line, nodes, label plates, numbers.

**Label plate (fixes "32" reading as crossed out)**
- On a chained tile, before its number, fill a rectangle of the tile's own fill color covering the whole label's ink box grown by `number_plate` px.
- The line disappears under the plate and never shows between glyphs.

**Merge preview**
- Not on the board.
- The HUD's context row reads "CHAIN 6" on the left and shows the result as a tile (`preview_scale` of the board tile, 112 px) on the right.

**Merge, spawn and fall**
- Merge: chain tiles slide into the last tile (`merge_travel`). The result shows a paper fill for a beat, then cuts to its own color (`merge_pop`).
- Spawn: tiles wipe down from their top edge, all at once.
- Fall: quart ease out, no bounce.

**Small tile clear (D-38)**
- Every cleared tile wipes up to nothing (scale y to 0, pivot at the top, `clear`).
- No particles.

**Clear notice (AT-104)**
- It takes the HUD's context row for its hold time: a full width bar in badge.
- Content: the cleared values as small tiles (`notice_tile_scale` of `notice_height`) with a `notice_strike` px badge_ink strike line, then the text in the label role, badge_ink, in capitals: "NO MORE 2S". Padding `space_m` on the left, items `space_xs` apart.
- Motion: it cuts in and out with `clear_notice`.
- If a chain is being dragged, the notice waits until the finger lifts.

**HUD**
- Left aligned: "SCORE" in the label role over the score in display.
- On the right: the pause icon (no container, full touch area) and "BEST" over the best score in body.
- A hairline under the header, then the context row (`hint_height`):
  - while dragging, "CHAIN n" and the preview tile;
  - in targeting, a full width badge bar, for example "HAMMER: TAP A TILE TO SMASH IT";
  - otherwise empty.

**Booster bar**
- A full width strip, `strip_height` tall, with a hairline on top and hairlines between five equal columns.
- Each column: the icon, then the name and the cost in the label role.
- Looks:
  - *Pressed:* the column fills surface.
  - *Active:* the column fills ink (paper), content in ink_dark.
  - *Disabled:* content in disabled_ink, the cost struck through with a `hairline` line.
  - *Suggested:* a "SUGGESTED" badge (badge, badge_ink, label role) sits across the column's top hairline.

**Icons**
- Signage pictograms: straight segments and true circles, square caps, `icon_stroke` 2, no fills.
- Settings is three sliders. Pause is two upright bars.

**Sound toggle (fixes "does not show whether it is on")**
- A rectangular track `toggle_w` by `toggle_h` with a square knob.
- On: the track fills ink (paper), the knob in ink_dark sits right, and "ON" in the label role, ink_dark, sits inside the track on the left.
- Off: the track is bg with a `hairline` line outline, the knob in ink_muted sits left, and "OFF" in ink_muted sits inside on the right.
- The word and the fill both change, so the state reads without color.

**Backdrop:** flat bg.

**Buttons, panels and chips**
- *Primary:* accent fill, ink_dark text, `radius_button` corners, text left aligned.
- *Secondary:* a `hairline` outline in ink, ink text; pressed fills surface.
- *Chip:* surface; selected fills ink (paper) with ink_dark text.
- *Sheet panel:* bg with a `hairline` line on its open edge, square corners, `space_m` padding, rows split by hairlines.
- *Focus:* a `focus_width` accent outline `focus_gap` outside.

---

## 6. Nova

Tiles are stars. Round orbs float on deep space with no tray. Every value is a different kind of star: dark giants with white numbers and bright stars with dark numbers alternate, and each step jumps far round the hue wheel. The bigger the value, the wider its glow. A chain is a beam of light under the orbs. Light, airy type, lowercase labels, slow and fluid motion. Font: **Outfit**.

### 6.1 Palette

| Role | Hex | Use |
|---|---|---|
| bg | #040819 | deep space, edges and bottom |
| surface | #10162F | sheets |
| surface_raised | #1F2646 | rows and chips |
| line | #52628C | ring outlines, dividers |
| ink | #F7F9FF | |
| ink_muted | #ABB7D5 | |
| ink_dark | #060C20 | |
| accent | #49EAF2 | aurora cyan |
| accent_pressed | #17D0D8 | |
| disabled_ink | #848C9F | |
| chain | #FFFFFF | beam core, chained rim |
| target | #49EAF2 | dashed orbit |
| joinable | #FFFFFF | thin orbit |
| scrim | #040819 at 86% (#040819DB) | |
| badge | #49EAF2 | |
| badge_ink | #060C20 | |
| **Extras** | | |
| bg_glow | #181942 | lightest point of the backdrop glow |
| star | #FFFFFF | star dust |
| accent_violet | #9264EF | second aurora color for glows, never behind text |

### 6.2 Tile ramp

Tier 1 is 2 to 1K, tier 2 is 2K to 16K (wider glow), and tier 3 is 32K up (corona rays).

| Value | Label | Name | Fill | Number | Contrast | Tier |
|---|---|---|---|---|---|---|
| 2 | 2 | red dwarf | #D01D21 | #F7F9FF | 5.14 | 1 |
| 4 | 4 | yellow star | #FED33F | #060C20 | 13.51 | 1 |
| 8 | 8 | blue giant | #1957D2 | #F7F9FF | 5.98 | 1 |
| 16 | 16 | aqua nebula | #2AF0D5 | #060C20 | 13.43 | 1 |
| 32 | 32 | magenta nebula | #CA13B3 | #F7F9FF | 4.69 | 1 |
| 64 | 64 | orange giant | #FDA669 | #060C20 | 10.02 | 1 |
| 128 | 128 | violet | #693AD4 | #F7F9FF | 6.32 | 1 |
| 256 | 256 | aurora green | #9BF461 | #060C20 | 14.34 | 1 |
| 512 | 512 | crimson | #D31D4B | #F7F9FF | 4.93 | 1 |
| 1024 | 1024 | ice | #7ECFFD | #060C20 | 11.31 | 1 |
| 2048 | 2K | purple | #9129C8 | #F7F9FF | 5.95 | 2 |
| 4096 | 4K | gold | #F7E04F | #060C20 | 14.55 | 2 |
| 8192 | 8K | emerald | #0D7C59 | #F7F9FF | 4.93 | 2 |
| 16384 | 16K | rose | #FD8DC5 | #060C20 | 9.06 | 2 |
| 32768 | 32K | deep blue | #0A65AD | #F7F9FF | 5.74 | 3 |
| 65536 | 64K | supernova | #FEBC72 | #060C20 | 11.70 | 3 |
| 131072 | 128K | white hole | #FAFCFF | #060C20 | 18.90 | 3 |
| above | 256K and up | white hole | #FAFCFF | #060C20 | 18.90 | 3 |

Closest pairs (ramp check): neighbors 0.194, times 4 0.169, times 8 0.258.

### 6.3 Text pairs

| Pair | Text on background | Ratio |
|---|---|---|
| Score, lightest part of the backdrop | ink on bg_glow | 15.88 |
| Labels, lightest part of the backdrop | ink_muted on bg_glow | 8.33 |
| Labels, darkest part of the backdrop | ink_muted on bg | 9.93 |
| Booster cost, targeting | accent on bg_glow | 11.41 |
| Booster cost, disabled | disabled_ink on bg_glow | 4.96 |
| Badges | badge_ink on badge | 13.26 |
| Primary button, selected chip | ink_dark on accent | 13.26 |
| Primary button, pressed | ink_dark on accent_pressed | 10.22 |
| Sheet and card text | ink on surface | 16.94 |
| Sheet and card labels | ink_muted on surface | 8.89 |
| Rows and chips | ink on surface_raised | 14.01 |
| Labels on rows and chips | ink_muted on surface_raised | 7.35 |
| Text over the scrim (worst case over a white hole) | ink on scrim | 13.45 |
| Labels over the scrim (worst case) | ink_muted on scrim | 7.06 |

### 6.4 Type (Outfit)

| Role | Size | Weight | Tracking | Case |
|---|---|---|---|---|
| display (score) | 148 | 300 | 0 | as written |
| title | 68 | 300 | 0 | as written |
| body | 44 | 400 | 0 | as written |
| label | 32 | 400 | +3 | lowercase |
| tile | 46%, 42%, 37%, 31.5% of the orb diameter for 1 to 4 characters | 600 | 0 | |

`label_fit` 0.82. `display_fit_min` 80. The display shrank from 160 to 148 to reach 56 dp at 18:9, and the title tracking went from +1 to 0, because Outfit Light is wider set than Segoe UI Light.

### 6.5 Shape and sizes

| Name | Value | | Name | Value |
|---|---|---|---|---|
| board_margin | 44 | | radius_button | 72 (pill) |
| board_gap | 24 (orb_scale 0.88 of the pitch) | | radius_card | 64 (sheet top corners) |
| board_padding | 0 | | radius_chip | 72 |
| tile_radius | 0.5 (circle) | | hairline | 2 |
| preview_scale | 0.54 of the orb | | hud_height | 200 |
| special_from | 32768 | | bar_height | 254 |
| chain_width | 12 (beam core) | | hint_height | 64 |
| chain_ring | 8 | | button_height | 144 |
| joinable_ring | 3 | | row_height | 144 |
| target_ring | 4 | | icon_booster | 80 |
| space_xs, s, m, l, xl | 12, 28, 44, 72, 112 | | icon_hud | 72 |
| touch_min | 144 | | icon_stroke | 1.5 |
| notice_height | 80 | | toggle_w, toggle_h, toggle_knob | 124, 64, 40 |
| notice_tile_scale | 0.6 | | notice_strike | 2 |

**Extras:**
- Orb and rim: `orb_scale` 0.88, `rim_width` 4, `rim_lighten` 0.35.
- Glow: `glow_alpha_low` 0.10, `glow_alpha_high` 0.55, `glow_spread_low` 1.12, `glow_spread_high` 1.55. Both scale linearly by ramp index.
- Beam: `beam_glow_width` 44, `beam_glow_alpha` 0.28.
- Orbits: `orbit_offset` 0.10, `joinable_orbit` 0.05, `orbit_dashes` 24, `orbit_dash_fill` 0.55, `orbit_breath` 0.05, `orbit_turn` 0.08.
- Glow multipliers: `joinable_glow` 1.25, `chain_glow` 1.4, `target_glow` 1.5, `spawn_bloom` 0.6.
- Corona: `ray_count` 12, `ray_inner` 1.08, `ray_outer` 1.24, `ray_width` 3, `ray_lighten` 0.35, `ray_alpha` 0.6.
- Ring buttons: `ring_button` 136, `ring_width` 3.
- Disabled: `disabled_ring_alpha` 0.35, `disabled_ring_dashes` 16, `disabled_icon_alpha` 0.6.
- Star dust: `star_count` 70, `star_alpha_min` 0.08, `star_alpha_max` 0.35, `star_size_min` 1.5, `star_size_max` 3.5, `star_seed` 20261010, `star_clearance` 24.
- Backdrop glow: `backdrop_glow_x` 0.5, `backdrop_glow_y` 0.26, `backdrop_glow_radius` 0.95.
- HUD and icons: `hud_ring` 96, `icon_spark` 1.0, `icon_fit` 0.86, `icon_glow_alpha` 0.4.
- Active ring glow: `ring_glow_spread` 1.45, `ring_glow_alpha` 0.75.
- Focus: `focus_gap` 6.
- Toggle glow: `toggle_glow_spread` 1.9, `toggle_glow_alpha` 0.6.

### 6.6 Motion: fluid and calm

| Name | Duration | Transition, ease | Extras |
|---|---|---|---|
| spawn | 0.34 | sine, out | from_scale 0.55, from_alpha 0, stagger 0.04 |
| fall | 0.26 | cubic, out | |
| chain_add, chain_remove | 0.16 | sine, out | |
| joinable_in | 0.20 | sine, out | |
| merge_travel | 0.24 | cubic, in out | orbs glide along the beam path |
| merge_pop | 0.40 | sine, out | peak_glow 1.8; the glow tail does not block input |
| clear | 0.36 | sine, in | to_scale 0.4, sparks 8, spark_size 4 px, spark_reach 0.7 (of the orb diameter) |
| clear_notice | 0.40 | sine, out | from_offset 16 (rises 16 px), from_alpha 0, hold 1.8, out 0.30 |
| press | 0.10 | sine, out | |
| button_press | 0.10 | sine, out | press_scale 0.96 |
| button_release | 0.24 | sine, out | |
| dialog_in | 0.44 | sine, out | from_alpha 0, from_scale 0.96 |
| dialog_out | 0.28 | sine, in | |
| screen_fade | 0.36 | sine, in out | |
| target_pulse | 1.60 | sine, in out | alpha_low 0.45 |
| score_count | 0.60 | sine, out | |
| skin_switch | 0.40 | sine, in out | |

A committed chain settles in about 0.8 s; the bloom fades after.

### 6.7 Components

**Orb**
- A circle `orb_scale` of the cell pitch, flat fill. A `rim_width` rim in fill lightened by `rim_lighten` sits just inside the edge.
- The label is centered.
- The glow sits behind the orb in its fill color. Radius is the orb radius times a lerp from `glow_spread_low` to `glow_spread_high`; alpha a lerp from `glow_alpha_low` to `glow_alpha_high`. Both run by ramp index from 0 (value 2) to 16 (131072), so bigger values glow wider.
- The glow is one radial gradient texture made once and drawn tinted.

**Orb states**
- *Chained:* a `chain_ring` rim in chain and glow times `chain_glow`.
- *Joinable (D-40):* a thin solid orbit in joinable, `joinable_ring` wide, at radius times (1 + `joinable_orbit`), and glow times `joinable_glow`. It eases in over `joinable_in`.
- *Press feedback (D-43):* a dashed orbit in target, `target_ring` wide, at radius times (1 + `orbit_offset`), `orbit_dashes` dashes, and glow times `target_glow`.
- *Selected (Swap's first tile):* the dashed orbit turning `orbit_turn` per loop and breathing by `orbit_breath` on `target_pulse`.
- *Special (32K up):* `ray_count` corona rays from `ray_inner` to `ray_outer` orb radii, `ray_width` wide, in the fill lightened by `ray_lighten`, at `ray_alpha`.

**Board:** no tray and no grid lines. The orbs float on the backdrop.

**Chain beam**
- Drawn under the orbs, center to center, round joins.
- A `beam_glow_width` glow at `beam_glow_alpha` that takes the chained orbs' fill colors along its length.
- A chain core, `chain_width` wide, on top of the glow.
- It also runs to the finger.

**Merge preview**
- A small orb with its glow, `preview_scale` of the orb diameter.
- It sits on the gap crossing at the top left of the last chain orb (top right in column 0), clear of the four orbs round it.

**Merge, spawn and fall**
- Merge: orbs glide along the beam path into the last orb (`merge_travel`). It blooms to `peak_glow` times its glow and settles (`merge_pop`).
- Spawn: from `from_scale` and transparent, with a bloom of `spawn_bloom` extra glow at the midpoint.
- Fall: cubic ease out.

**Small tile clear (D-38)**
- Every cleared orb dims and shrinks to `to_scale` (`clear`, sine in) while `sparks` sparks in its fill color, `spark_size` px across, drift out `spark_reach` of the orb diameter and fade.
- Its glow goes out with it.

**Clear notice (AT-104)**
- A badge pill, `notice_height` tall, centered on the board's top edge. Content and padding as Gumdrop, with `notice_tile_scale` and `notice_strike`, and the text in the label role (lowercase): "no more 2s".
- Motion: it fades in from `from_alpha` while rising `from_offset` px (`clear_notice`), holds, fades out. It never blocks input.

**HUD**
- Centered: the score in the display role (light, auto fitting).
- Under it, "best 96,520" in the label role, `space_xs` below the score's baseline.
- The pause icon in a `hud_ring` ring at the top right.

**Booster bar**
- Five ring buttons in a row, no container: `ring_button` across, a `ring_width` ring in line, the icon inside.
- The cost sits under each ring in the label role. The `hint_height` row above holds the hint.
- Looks:
  - *Pressed:* scale `press_scale`, the ring brightens to ink.
  - *Active:* the ring fills accent, glowing accent and accent_violet (`ring_glow_spread`, `ring_glow_alpha`); icon ink_dark, cost accent; `target_pulse` breathing.
  - *Disabled (fixes "does not look disabled"):* the ring is dashed (`disabled_ring_dashes`) at `disabled_ring_alpha`, the icon is disabled_ink at `disabled_icon_alpha`, and the cost is disabled_ink struck through with a `hairline` line. No glow ever. Dashed ring, dim icon and struck cost together read as unavailable without color.
  - *Suggested:* a "suggested" badge on the ring's top edge, and the ring breathes in accent on `target_pulse`.
- Hint: centered ink_muted text in the label role, no panel.

**Icons**
- Thin and precise: `icon_stroke` 1.5 on the 24 unit grid, fitted to `icon_fit` of the icon box, round caps, a small spark dot (`icon_spark`) where it suits.
- Active icons get a soft glow at `icon_glow_alpha`.

**Sound toggle**
- A thin ring track `toggle_w` by `toggle_h` in line.
- Off: a disabled_ink knob on the left.
- On: an accent knob on the right with a glow (`toggle_glow_spread`, `toggle_glow_alpha`), and the track ring turns accent.

**Backdrop**
- A radial glow of bg_glow centered at (`backdrop_glow_x`, `backdrop_glow_y`) of the screen, radius `backdrop_glow_radius` of its width, fading to bg.
- On top, `star_count` star dust dots from the fixed `star_seed`.
- No star is drawn within `star_clearance` px of a rect that holds text (HUD, bar, panels, notice).

**Buttons, panels and chips**
- *Primary:* an accent pill, `radius_button`, ink_dark text. Pressed: accent_pressed.
- *Secondary:* a ring outline pill in line, ink text; pressed fills surface_raised.
- *Chip:* a surface_raised pill; selected fills accent.
- *Sheet panel:* surface, `radius_card` top corners, `space_m` padding.
- *Divider:* a `hairline` line in line.
- *Focus:* a ring in accent `focus_gap` outside.

---

## 7. Shared screen arrangements

Menus and dialogs keep one arrangement for every skin, drawn in each skin's style: its fonts, colors, buttons, panels and motion. In the tables, "panel" means the skin's dialog panel:
- **Gumdrop:** a lipped card, `board_margin` from the sides and bottom.
- **Slate:** a full width sheet with a hairline on its open edge.
- **Nova:** a sheet with rounded top corners.

Dialog panels anchor to the bottom of the safe area (thumb zone) and come in with `dialog_in` over the skin's scrim. The one exception is the out of moves offer, which takes the HUD's place so the board and the boosters stay visible. Android back closes the top dialog (or cancels targeting first, GDD 13.1).

The copy below is the design's working copy. Where the GDD fixes wording, the GDD wins.

### 7.1 Play screen frame

- HUD, board and booster bar as in section 2.3.
- The clear notice appears per skin (Gumdrop and Nova over the board's top edge, Slate in the HUD context row).
- The merge preview appears per skin.
- No other overlay ever covers the board during play.

### 7.2 Main menu

Shown only at first launch (no valid saved run) and after a run ends. Reopening the app with a saved run goes straight back into play (ARCHITECTURE.md section 11), so the main menu never offers Continue.

Over the backdrop, top to bottom:
1. The settings icon button, top right.
2. The wordmark "numbersgame" in the title role, ink, centered. Slate left aligns it.
3. A decorative row of four tiles (2, 4, 8, 16) drawn by the skin's tile component, `space_s` apart.
4. Records: "Best score" with the number, "Best tile" with a mini tile.
5. **New game**, the only button: primary, full width less `board_margin` each side, at the bottom of the safe area.

### 7.3 Pause

- Opened by the HUD's pause button or Android back during play.
- A panel with "Paused" (title), **Resume** (primary), **New game** (secondary), **Settings** (secondary). Back resumes.

### 7.4 New game confirmation (D-34)

- A panel: "Start a new game?" (title), "This run ends here. Its score already counts in your records." (body, muted).
- Buttons: **New game** (primary), **Cancel** (secondary).

### 7.5 Out of moves offer (D-19, D-42)

- The HUD is replaced, in place, by an offer panel:
  - "Out of moves" (title; Slate uses its accent signal label in capitals).
  - The current score.
  - "Pick a booster to keep this run going." (body, muted).
  - A row with the suggested buy button (primary, for example "Shuffle for 4K") and **End run** (secondary).
- The board stays fully visible and may shrink to fit under the taller panel.
- The booster bar stays: every booster with its cost, usable ones in the normal look, the rest disabled.
- The suggested booster (D-42) shows the Suggested badge in the bar:
  - Shuffle if it is usable, otherwise Undo if it is usable. The primary button then buys that booster ("Undo for 2K").
  - If neither is usable, nothing is marked. The panel shows **End run** alone as a primary button, and the text reads "No rescue left. Pick a booster or end the run."
- Choosing Hammer, Swap or Double enters targeting. The panel stays, the bar shows the active look, and tapping the active booster returns to the offer.

### 7.6 End of run (D-41)

- A panel over the scrim, the final board dimmed behind it.
- Content:
  - "Run over" (title; Slate: accent signal label).
  - The final score (display, auto fitting).
  - A **New best** badge if this run set the Best Score.
  - Rows, split by the skin's divider: "Best score" with the number, "Best tile" with a mini tile, "This run's highest tile" with a mini tile.
  - **New game** (primary) and **Main menu** (secondary).

### 7.7 Settings

- A panel:
  - "Settings" (title) with a close icon button.
  - "Sound" row with the toggle.
  - A divider.
  - "Skin" (label role), then three skin choices side by side.
  - The version line (label role, muted, centered; Slate left).
- **Each skin choice:**
  - A preview swatch in that skin's own bg (`radius_chip` of the current skin), holding tiles 2, 4 and 8 drawn by that skin's own tile component at 72 px.
  - Under it, a chip with the skin's name in that skin's font.
  - A swatch whose bg matches the panel gets a `hairline` edge in line.
  - The current skin's chip shows the selected look.
- Tapping a choice switches the whole game live: the screen cross-fades over `skin_switch` of the new skin, and the setting saves at once.

### 7.8 Badges

Every badge (the hint pill, Suggested, New best) is a pill in badge with badge_ink text in the label role. Its height is the label role's line height plus `space_xs` above and below, and its sides are padded by `space_s`. Gumdrop adds a badge_lip lip. Slate badges have square corners. Nova badges are full pills.

### 7.9 Fixed component constants

These numbers are the same in every skin and are not tokens. The components hold them as named constants:

| Constant | Value | Where |
|---|---|---|
| Main menu decorative tiles | 112 px side | 7.2 |
| Skin choice preview tiles | 72 px side | 7.7 |
| Skin choice swatch padding | 0.22 of the preview tile side | 7.7 |
| Skin choice swatch hairline edge | 2 px | 7.7 |
| Icon design grid | 24 units, scaled to the icon box | 4.7, 5.7, 6.7 |

### 7.10 Copy for new strings

| Where | Copy |
|---|---|
| Clear notice | "No more {v}s" / "No more {a}s or {b}s" / "No more {low}s to {high}s" (Slate in capitals, Nova lowercase) |
| Suggested badge | "Suggested" |
| New best badge | "New best" |
| Targeting hints | "Tap a tile to smash it" (Hammer), "Tap two tiles to swap them" (Swap), "Tap a tile to double it" (Double) |
| Swap after the first tap | "Now tap the tile to swap with" |

---

## 8. Hard Stop 1 review fixes

| Review point | Change |
|---|---|
| Small values hard to tell apart (Nova 4 and 8, Nova 32 and 64, Slate 2, 4 and 8) | All three ramps rebuilt as categorical ramps (section 1.3). Each step jumps about 144 degrees round the hue wheel at the lightness where that hue is most vivid, and tiers separate repeats. Nova alternates dark and light orbs. Slate slabs use the hues that stay rich when dark, with alternating lightness. A new script, tools/ramp_check.gd, proves it. Closest neighbors are now 0.19 to 0.21, against 0.07 to 0.12 before. |
| Nova disabled booster not clearly disabled | Dashed ring at 35% alpha, icon at 60% alpha in disabled_ink, cost struck through, never a glow (6.7). |
| Gumdrop 512 to 2K darker than the small tiles | No dark jewel tones any more. Chroma rises by tier: sorbet 2 to 32, candy 64 to 1K, neon with a shine 2K to 32K, special 64K up. The lip grows by tier, so big tiles also stand taller (4.2, 4.7). |
| Slate chain line makes "32" read as crossed out | A label plate of the tile fill covers the whole label box on chained tiles, so the line never shows between glyphs (5.7). |
| Slate sound toggle does not show its state | ON and OFF words inside the track, plus fill and knob position (5.7). |
| Gumdrop below 56 dp at 18:9 | The score caption is dropped, the display goes from 136 to 120, the dock from 208 to 184, the hint row from 120 to 88, gaps from 18 to 16 and tray padding from 22 to 18. Gumdrop now measures 56.9 dp at 18:9 (2.4). |
| Nova below 56 dp at 18:9 (found in the same check) | Display 160 to 148, ring buttons 148 to 136, a 64 px hint row. Nova now measures 57.1 dp. |
| Touch targets at 44 dp on a 360 dp phone | `touch_min` raised from 132 to 144 px (48 dp). |

Shared since Phase 1:
- The token names follow one schema (section 3): ink_soft became ink_muted, and divider, rule and ring became line.
- Slate's 128 moved off the vermilion accent hues.
- The joinable highlight, press feedback, Swap selection, clear effect and notice, Suggested badge, pause icon and the shared screens are new.

---

## 9. Launcher icon

Drawn in code by **tools/launcher_icon.gd** (senior-graphic-designer). Run it from the repo root with `godot --path . res://tools/launcher_icon.tscn`. It runs with a window, saves the PNGs and quits.
- The rope, tiles, ring and labels are drawn with `_draw()` into a SubViewport at 4 times the output size with no antialiasing, and every 4 by 4 block is averaged into one pixel (16 samples per pixel, better than MSAA and the same on every renderer).
- The background glow is worked out per pixel.
- It also checks that the foreground stays inside the safe circle (9.2) and writes a review sheet to docs/design/review/launcher-icon-check.png (ignored by git).

### 9.1 Files

The tool writes these to **launcher/** at the repo root, and only this tool writes there. Godot's Android export takes them and scales them to every density itself:

| Export setting | File | Size | Content |
|---|---|---|---|
| launcher_icons/main_192x192 | main_192.png | 192 x 192 | legacy icon: the 72 dp the launcher shows (9.2), background and foreground composited, corners rounded at 22% of the side, transparent outside |
| launcher_icons/adaptive_foreground_432x432 | adaptive_foreground_432.png | 432 x 432 | the foreground layer on transparent |
| launcher_icons/adaptive_background_432x432 | adaptive_background_432.png | 432 x 432 | the background layer, full bleed, opaque |
| launcher_icons/adaptive_monochrome_432x432 | adaptive_monochrome_432.png | 432 x 432 | the foreground silhouettes in white on transparent, for Android 13 themed icons |

The same main_192.png can serve as the project icon. The files are generated, so regenerating them gives the same pixels: two runs write byte for byte identical files.

### 9.2 Geometry

Adaptive icons are 108 by 108 dp. The launcher shows the inner 72 dp (288 px) through a mask shape that always keeps the inner 66 dp circle. At 432 px, 4 px are 1 dp: the safe circle has a radius of 132 px around (216, 216), and everything that matters stays inside it. The tool measures it: the foreground reaches 131.1 px from the center, the monochrome layer 130.4 px.

### 9.3 Design: Gumdrop, the default skin

- **Background:** Gumdrop bg #150820, with a radial glow of surface #2B183D centered at (216, 196), radius 260, fading to bg with a smooth (smoothstep) falloff.
- **Foreground:** two Gumdrop 2 tiles about to merge, joined by the rope.
  - **Tiles:** mint #8FFFD0 faces, side 92, corner radius 0.30, lips 0.075 of the side in the fill darkened 34%. Drawn as in 4.7: the lip is the full 92 px tile shape, the face sits on top of it raised by the lip depth, so the lip shows along the tile's own bottom. Lip and face turn together.
  - **Placement:** tile A is centered at (160, 164) and turned -6 degrees (counter-clockwise); tile B is centered at (272, 268) and turned 5 degrees (clockwise). About 20 px of gap stays between them, and the farthest corner sits about 130 px from the center, inside the safe circle.
  - **Rope:** the white rope #FFF7FC, 24 wide, round caps, from A's center to B's center, drawn under both tiles so it shows in the gap.
  - **Label:** "2" on each tile in Outfit Black (900), 44 px (the 1 character tile label size), #1C0D2B. Its ink box is centered on the face and it turns with the tile.
  - **Ring:** tile B has the chained ring, 5 px #FFF7FC just outside its face, as in 4.7. B is not pressed in: both tiles keep the 0.075 lip.
- **Monochrome:** the two tile silhouettes (lip and face) and the rope in white, the labels cut out (transparent). No ring.
- **Legacy 192:** the 72 dp the launcher shows (the 288 px square around the center) with background and foreground composited, scaled to 192, corners rounded at 22%. So the legacy icon matches the adaptive icon as a launcher shows it, rather than shrinking the art into the 18 dp margins no launcher shows.

It reads as "two equal tiles join" at every launcher size, and its colors match the default skin. The tool reads every color from Gumdrop's SkinData, not from its own copies, and also takes the corner radius (`tile_radius`), the lip darkening (`lip_darken`), the tile font and the label size from it.
