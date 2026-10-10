# numbersgame: Game Design Document

Owner: lead-game-designer. Status: draft for Bart's sign-off at Hard Stop 1.

This document turns section 3 of docs/BRIEF.md into exact rules. The rules Bart confirmed are copied unchanged in section 4. Every gap the brief leaves open is settled here as a numbered designer decision (D-01, D-02, ...) with its reasoning and worked examples. Every tunable number lives in one table in section 18. Section 19 is the acceptance test list (AT-01, AT-02, ...) that QA walks and developers turn into unit tests.

All rules here describe the rules model only. They do not depend on any screen, so level goals could be added later. Nothing here is designed for level goals.

## 1. Decision summary

One line per designer decision. Bart signs off on this list.

| ID | Decision | Section |
|---|---|---|
| D-01 | The board stays 5 columns by 8 rows. | 5 |
| D-02 | A merge rounds down: the result is the largest power of two that is not more than the chain's sum. | 7 |
| D-03 | While dragging, from 2 tiles on, the player sees the value the chain would make. It updates on every added or removed tile and is hidden at 1 tile. | 7 |
| D-04 | A tile that would break the chain rules does not join. The chain is valid at every moment, so the only cancel case is lifting with 1 tile. | 6 |
| D-05 | Dragging back onto the previous tile removes the last tile. Other tiles already in the chain are ignored. | 6 |
| D-06 | The chain path may cross itself. Leaving the board keeps the chain. Lifting anywhere commits a chain of 2 or more. | 6 |
| D-07 | A tile joins only when the finger is within 0.42 of the tile pitch from its center, so diagonal moves never catch the side tiles. | 6 |
| D-08 | Only the first finger counts. Booster taps are ignored while a chain is being dragged. | 6 |
| D-09 | A committed chain resolves in a fixed order: score, place result, clear, gravity, spawn, records, save, move check. | 8 |
| D-10 | Spawn window: four values in a row, the top one is the larger of 16 and highest tile divided by 64. Weights 40, 30, 20, 10 from smallest to largest. | 9 |
| D-11 | The spawn window is worked out from the board at the moment of spawning, after gravity. A merge or Hammer that changes the highest tile changes the window at once. | 9 |
| D-12 | Empty cells fill column by column from the left, and from the top row down inside each column. | 9 |
| D-13 | Tiles smaller than the current spawn window stay on the board and play normally. | 9 |
| D-14 | Starting board: 40 tiles drawn from the starting spawn window, redrawn until it has a valid chain, with a fixed fallback after 100 tries. | 10 |
| D-15 | A board has a valid move if and only if two touching tiles (eight directions) have the same value. | 12 |
| D-16 | Best Score updates live whenever the current score goes above it. Bart, please confirm (see open question Q1). | 11 |
| D-17 | Best Tile is the highest value ever on the board, from any source (merge, Double, spawn). It never goes down. | 11 |
| D-18 | Only committed chains add points. Boosters never add points. | 11 |
| D-19 | No moves left: the run pauses on an offer of every booster the player can afford and use, Shuffle marked as the suggested rescue. The run ends only when the player taps End run, or at once if nothing is usable. | 12 |
| D-20 | Cost basis B is the larger of the highest tile on the board and 128. Hammer costs B, Swap B, Shuffle B, Double 2 times B, Undo half of B. | 13.2 |
| D-21 | A cost is read from the board when the booster is used and charged only when its effect applies. | 13.1 |
| D-22 | Targeting: tap the booster to enter, tap it again to cancel, tap another booster to switch. Nothing is charged until the effect applies. | 13.1 |
| D-23 | Hammer removes the tile, the tiles above fall one cell, and one new tile spawns at the top of that column. | 13.3 |
| D-24 | Swap works on any two tiles anywhere. Tapping the selected tile again deselects it. A tile with the same value as the selected one cannot be picked. | 13.4 |
| D-25 | Shuffle always leaves at least one valid chain when the board holds any two tiles of equal value, which is always true while the highest tile is below 2^40. | 13.5 |
| D-26 | Double doubles one tile in place. No gravity, no spawn. | 13.6 |
| D-27 | Undo goes back one step only. It restores the board from before the last chain and takes that chain's points off the score. Every cost paid since then stays spent, including Undo's own cost. | 13.7 |
| D-28 | Undo is affordable only when the score minus the last chain's points is at least the Undo cost. | 13.7 |
| D-29 | Undo does not lower Best Score or Best Tile and does not rewind the random number generator. | 13.7 |
| D-30 | Score never goes below zero: the rules model refuses any booster the player cannot afford. It never clamps a negative score to zero. | 13.8 |
| D-31 | Tile labels: the full number up to 1024. From 2048 up, a number from 1 to 512 plus K, M, B or T (2K, 512K, 1M). Never more than 4 characters. | 14 |
| D-32 | The score shows in full with commas (1,234,567). Booster costs and the merge preview use the tile label format. | 14 |
| D-33 | The run saves as soon as each move resolves, before its animation ends, and when the app is paused. A drag in progress and targeting mode are not saved. | 15 |
| D-34 | Starting a new game while a run is in progress asks for confirmation, then discards the saved run. | 15 |
| D-35 | One move at a time: no new chain or booster is accepted until the previous move has finished on screen. | 15 |
| D-36 | The click plays for every tile added to a chain, including the first, and once on commit. Never on backtrack or cancel. | 16 |
| D-37 | Tile values and the score are 64-bit integers with no cap. | 5 |

### 1.1 Open question for Bart

- **Q1. When does Best Score update?** This document uses the live rule (D-16): Best Score rises the moment the score passes it, so spending afterwards does not lower the record. The brief's line "spending on boosters lowers the final score" could instead mean Best Score should only take the score at the end of a run. Section 11.2 shows both rules side by side. Recommendation: the live rule. Changing it touches only D-16 and tests AT-41, AT-42 and AT-80.

### 1.2 Decisions worth a closer look

These settle gaps the brief leaves open, but they shape how the game feels, so Bart may want to read the reasoning:

- D-02 (round down): makes progress steadier and the late game tenser than rounding up.
- D-20 (costs scale with the highest tile): a booster costs about the same share of a typical score all run.
- D-27 (Undo after a booster): Undo also reverts any booster used after the last chain, and that booster's cost stays spent. This stops "booster then Undo" from being free.

## 2. Assumptions

| ID | Assumption | Why it matters |
|---|---|---|
| A-1 | The smallest supported phone is 360 dp wide in portrait. With 5 columns, a tile is about 56 to 60 dp wide. The rules assume tiles are never smaller than 56 dp. | Number labels (section 14) must be readable at this size. |
| A-2 | The typical scores in section 17 are estimates from a simple model, not playtest data. | Booster costs are tuned against them. They should be checked in Phase 4 play and retuned in section 18 if needed. |

## 3. Terms and notation

| Term | Meaning |
|---|---|
| Cell (c, r) | Column c from 0 (left) to 4 (right), row r from 0 (top) to 7 (bottom). Gravity pulls toward row 7. |
| Touching | Two different cells whose column and row each differ by at most 1. Each cell touches up to 8 others. |
| Chain | The ordered list of cells the finger has joined in one drag. |
| Sum | The total of the values in a chain. |
| H | The value of the highest tile on the board right now. |
| B | The booster cost basis, the larger of H and 128 (section 13.2). |
| Label | The text shown on a tile for its value (section 14). |
| Move | A committed chain, or one use of a booster (Undo included). |
| Resolved | The rules model has fully applied a move, including gravity and spawns. |
| Spawn window | The four values that new tiles can have right now (section 9). |
| Valid move | Any chain of 2 or more tiles that the player could commit right now. |

## 4. Confirmed rules (copied unchanged from docs/BRIEF.md, section 3)

These are Bart's words. Nothing in this document changes them. Sections 5 to 16 only fill the gaps.

**Board.** A grid of numbered tiles. Every value is a power of two. 5 columns by 8 rows unless the designer has a strong reason to change it.

**Making a chain.** The player drags a finger across tiles that touch, in any of eight directions (including diagonals). A tile cannot be used twice in one chain.

- The chain must start with two tiles of equal value.
- Each next tile must equal the previous tile or be double it.
- Lifting the finger with a chain of 2 or more commits it. Lifting on an invalid chain cancels with no penalty.

**Merge result.** The connected values are summed and converted to a power of two. Designer decides the rounding rule (round down or round up to a power of two) and shows at least six worked examples. The live result shows as a preview while dragging.

**After a merge.** The result lands on the last tile of the chain. Other chain tiles clear, tiles above fall down, and new tiles spawn from the top. Designer decides the spawn table: which values can spawn and how that range moves up as the board's highest tile grows.

**Score.** Each committed chain adds the sum of its tile values to the score. Track Best Score and Best Tile separately, because spending on boosters lowers the final score.

**Game over.** No valid chain exists on the board. Designer decides how the game-over moment offers any booster the player can still afford (Shuffle is the obvious rescue) before the run ends.

**Boosters.** Paid from current score. A booster the player cannot afford is visibly disabled. Score can never go below zero.

| Booster | Effect | Target |
|---|---|---|
| Hammer | Destroys one tile; tiles above fall, a new tile spawns | One tile |
| Swap | Swaps two tiles | Two tiles |
| Shuffle | Randomly rearranges the whole board | None |
| Double | Doubles one tile's value | One tile |
| Undo | Restores board and score to before the last chain. The Undo cost stays spent. | None |

Designer decides each booster's cost (flat, or scaled to board progress) with reasoning and examples from an early, mid and late game. Targeting boosters can be cancelled by tapping the booster again.

**Number display.** Large values abbreviate (for example 1024 stays, 2048 becomes 2K). Designer decides the exact threshold and format, and it must stay readable on the smallest tile size we support.

**Persistence.** The current run saves automatically and resumes after the app is closed or killed. Settings (sound on or off, selected skin) and Best Score and Best Tile persist.

## 5. Board

**D-01. The board is 5 columns by 8 rows (40 cells).**

Reasoning:

- It is the proven layout for this mechanic, and the brief's default.
- On a 360 dp wide phone a column is about 56 to 60 dp, above the 48 dp Android touch target, so diagonal drags stay accurate.
- 40 cells hold the full late game spread: four spawn values plus about seven levels of larger tiles up to the highest tile (section 9), with room left to maneuver. Fewer cells would end runs too early. More columns would push tiles under 56 dp.

Rules:

- Every cell holds exactly one tile whenever no move is resolving. Empty cells exist only inside a resolving move (between clearing and spawning).
- Every value is a power of two, 2 or more.

**D-37. Values and score are 64-bit integers with no cap.** Developers must not use floats for values, sums or the score. A run would need billions of moves to get near the 64-bit limit, so no cap rule is needed.

## 6. Making a chain

### 6.1 Joining rule (D-04)

The chain starts at the first tile the finger is over: the tile under the touch down point, or, if the touch lands in a gap, the first tile the finger then enters. That tile is the chain's first tile (length 1).

As the finger moves, a tile T joins the chain only if all of these hold:

1. T touches the chain's last tile (eight directions).
2. T is not already in the chain.
3. If the chain has 1 tile: T's value equals the last tile's value.
4. If the chain has 2 or more tiles: T's value equals the last tile's value, or is exactly double it.

If any condition fails, nothing happens. The finger may pass over T, and the chain stays as it was. Because a breaking tile can never join, the chain is valid at every moment once it has 2 tiles. The only "invalid chain" the player can lift on is a chain of 1 tile, which cancels with no penalty: board, score and Undo state stay exactly as they were.

Reasoning: refusing a bad tile is easier to read than letting it join and then failing the whole chain on lift. The player never loses a long chain to one slip.

The rules model also checks any chain handed to it before committing. A list of cells is a valid chain if and only if:

- it has 2 or more cells, all different;
- each cell touches the one before it;
- the second value equals the first;
- every later value equals the value before it or is double it.

An invalid list is refused and changes nothing.

### 6.2 Backtracking (D-05)

- If the finger moves onto the tile just before the last one, the last tile leaves the chain. Repeating this can shrink the chain back to its first tile.
- The first tile never leaves the chain during a drag. Lifting with only the first tile cancels.
- Moving onto any other tile already in the chain does nothing.
- A tile removed by backtracking can join again later in the same drag, following 6.1.

### 6.3 Path, leaving the board, lifting (D-06)

- The path may cross itself, for example (1,1) to (2,2) and later (2,1) to (1,2). The only rule is that each tile is used once.
- If the finger leaves the board, the chain stays as it is. Tiles join again when the finger comes back over a touching tile.
- Lifting the finger anywhere, on or off the board, commits a chain of 2 or more tiles and cancels a chain of 1.
- There is no limit on chain length other than the 40 cells.

### 6.4 Hit area (D-07)

The tile pitch is the distance between the centers of two side by side cells. The finger is "over" a tile only when it is within 0.42 times the pitch of that tile's center.

Reasoning: when the finger slides diagonally from one tile center to the next, its closest approach to the two side tiles' centers is 0.71 times the pitch. A radius of 0.42 leaves a clear margin, so a diagonal move never catches a side tile by accident. Between hit areas there are small dead zones where nothing happens.

Worked examples (pitch 60 dp, so the radius is 25.2 dp):

| Finger position relative to a tile center | Over that tile? |
|---|---|
| 20 dp to the right | Yes |
| 25 dp up | Yes |
| 27 dp to the left | No |
| 18 dp right and 18 dp down (25.5 dp away) | No |
| On the corner point shared by four cells (42.4 dp from each center) | No, over none of them |

### 6.5 One finger (D-08)

- Only the first finger that touches the board counts. Other fingers are ignored until it lifts.
- While a chain is being dragged, taps on booster buttons are ignored.
- If the app loses focus or the pause screen opens during a drag, the drag is cancelled with no penalty.

### 6.6 Worked examples

Part of a board (all other cells do not matter here):

```
         c1   c2   c3
row 5:    4    8   16
row 6:    2    2    4
row 7:    8   32    8
```

| # | Finger path | What happens | Chain after | Preview |
|---|---|---|---|---|
| C1 | (1,6) | First tile | 2 | none |
| C2 | then (2,6) | 2 equals 2, joins | 2, 2 | 4 |
| C3 | then (3,6) | 4 is double 2, joins | 2, 2, 4 | 8 |
| C4 | then (2,7) | 32 is 8 times 4, does not join | 2, 2, 4 | 8 |
| C5 | then (2,5) | Touches (3,6) diagonally, 8 is double 4, joins | 2, 2, 4, 8 | 16 |
| C6 | then (1,5) | 4 is half of 8, does not join | 2, 2, 4, 8 | 16 |
| C7 | then (3,5) | 16 is double 8, joins | 2, 2, 4, 8, 16 | 32 |
| C8 | then back to (2,5) | Previous tile, so 16 leaves | 2, 2, 4, 8 | 16 |
| C9 | then (2,6) | Already in the chain, not the previous tile, ignored | 2, 2, 4, 8 | 16 |
| C10 | lift | Commits: points +16, result 16 placed on (2,5), then gravity (section 8) | | |

A second drag on the same board: start at (1,6) = 2, move to (1,5) = 4. The 4 does not join because the first two tiles must be equal. Lift: the chain has 1 tile, so it cancels. Nothing changes.

## 7. Merge result and preview

### 7.1 Rounding (D-02)

**The result is the largest power of two that is not more than the sum.**

Developers compute it with integer bit operations (keep the highest set bit of the sum), never with floating point logarithms.

Two facts follow and are useful for tests:

- The result is never more than the sum.
- The result is always at least double the last tile of the chain. Reason: before the last tile (value M) the chain already holds at least M. The smallest case is a, a, 2a, 4a, ..., M/2, which sums to exactly M. So the sum is at least 2M.

Reasoning for rounding down rather than up:

1. A merge never creates value. The total value on the board can only stay the same or drop through a merge, so only spawns add value. Difficulty is then set by one thing, the spawn table, which makes it predictable and tunable.
2. The rule is easy to read: the result is at least double the biggest tile, and more only when the sum reaches the next power of two. Planning chains whose sums land on a power of two is the skill the game teaches.
3. Long chains still pay. Every tile adds its full value to the score and frees a cell.
4. Rounding up inflates fast. Five 2s would make 16, and long chains of small tiles would jump several levels at once. The highest tile would race ahead of the rest of the board and the late game would lose its tension.

### 7.2 Worked examples

| # | Chain in drag order | Sum | Result (round down) | Round up would give | Points added |
|---|---|---|---|---|---|
| M1 | 2, 2 | 4 | 4 (sum is already a power of two) | 4 | 4 |
| M2 | 2, 2, 2 | 6 | 4 | 8 | 6 |
| M3 | 4, 4, 8 | 16 | 16 (sum is already a power of two) | 16 | 16 |
| M4 | 2, 2, 2, 2, 2 | 10 | 8 | 16 | 10 |
| M5 | 2, 2, 4, 8, 16, 32 (four doubling steps) | 64 | 64 | 64 | 64 |
| M6 | 8, 8, 8, 16, 16, 32 | 88 | 64 | 128 | 88 |
| M7 | 2, 2, 2, 2, 2, 2, 2, 2, 4, 4, 8 (long chain, 11 tiles) | 32 | 32 | 32 | 32 |
| M8 | 2, 2, 4, 4, 4, 8, 8, 16 (three doubling steps) | 48 | 32 | 64 | 48 |
| M9 | 512, 512, 1024, 1024 | 3072 | 2048, shown as 2K | 4096 | 3072 |
| M10 | 64, 64, 64, 64 | 256 | 256 | 256 | 256 |

Check of the "at least double the last tile" fact: M2 last tile 2, result 4. M6 last tile 32, result 64. M8 last tile 16, result 32. M9 last tile 1024, result 2048.

### 7.3 Live preview (D-03)

- From the moment the chain has 2 tiles, the player sees the result value of the current chain, as a tile label (section 14).
- It updates after every tile added or removed.
- It is hidden when the chain has 1 tile, and removed when the finger lifts (commit or cancel).
- The player must always be able to see which tiles are in the chain and in what order, and the preview must not sit under the finger. Where and how it is drawn is a design system choice.

Worked example, dragging chain M8 one tile at a time:

| Step | Chain so far | Sum | Preview |
|---|---|---|---|
| 1 | 2 | 2 | none |
| 2 | 2, 2 | 4 | 4 |
| 3 | 2, 2, 4 | 8 | 8 |
| 4 | 2, 2, 4, 4 | 12 | 8 (unchanged: this tile adds points but does not raise the result) |
| 5 | 2, 2, 4, 4, 4 | 16 | 16 |
| 6 | 2, 2, 4, 4, 4, 8 | 24 | 16 |
| 7 | 2, 2, 4, 4, 4, 8, 8 | 32 | 32 |
| 8 | 2, 2, 4, 4, 4, 8, 8, 16 | 48 | 32 |
| 9 | backtrack off the 16 | 32 | 32 |

## 8. Resolving a committed chain

**D-09. A committed chain resolves in this exact order:**

1. Undo snapshot: store the board as it is now and the chain's sum (its points). This replaces any older snapshot (section 13.7).
2. Add the sum to the score.
3. Put the result value (section 7) in the chain's last cell.
4. Empty every other cell of the chain.
5. Gravity: in each column, tiles move straight down to fill the empty cells below them, keeping their order. The result tile falls too if cells below it were emptied.
6. Spawn: fill every empty cell (section 9). After gravity all empty cells are at the top of their columns.
7. Records: Best Score becomes the larger of Best Score and the score. Best Tile becomes the larger of Best Tile and H.
8. Save the run (section 15).
9. Move check: if the board has no valid move, open the no moves offer (section 12).

Steps 1 to 9 happen at once in the rules model. Animations play afterwards and never change the outcome.

Gravity worked examples. Values are listed top (row 0) to bottom (row 7).

**G1. Straight down, result does not move.** Column 2 holds 4, 16, 2, 8, 8, 8, 32, 64. Chain (2,3), (2,4), (2,5), values 8, 8, 8. Sum 24, result 16, points +24.

| Stage | Column 2, rows 0 to 7 |
|---|---|
| After steps 3 and 4 | 4, 16, 2, empty, empty, 16, 32, 64 |
| After gravity | empty, empty, 4, 16, 2, 16, 32, 64 |
| After spawn | new, new, 4, 16, 2, 16, 32, 64 |

**G2. The result tile falls.** Column 0 holds 2, 4, 8, 16, 32, 8, 4, 4. Chain (0,7), (0,6), (0,5), values 4, 4, 8. Sum 16, result 16 on (0,5), points +16.

| Stage | Column 0, rows 0 to 7 |
|---|---|
| After steps 3 and 4 | 2, 4, 8, 16, 32, 16, empty, empty |
| After gravity | empty, empty, 2, 4, 8, 16, 32, 16 |
| After spawn | new, new, 2, 4, 8, 16, 32, 16 |

**G3. Across columns.** Chain (1,6) = 2, (2,7) = 2, (3,6) = 4. Sum 8, result 8 on (3,6), points +8. Cell (1,6) empties: column 1 rows 0 to 5 fall one row and (1,0) spawns. Cell (2,7) empties: column 2 rows 0 to 6 fall one row and (2,0) spawns. Column 3 does not move. Spawn order: (1,0) first, then (2,0).

## 9. Spawning

### 9.1 Spawn window (D-10)

Let H be the highest tile on the board.

- Top = the larger of 16 and H / 64.
- The window is Top / 8, Top / 4, Top / 2 and Top.
- Weights, smallest value first: 40, 30, 20, 10.
- One draw: pick a whole number n from 0 to 99 with equal chance. 0 to 39 gives the smallest value, 40 to 69 the second, 70 to 89 the third, 90 to 99 the top value.
- The average spawned value is 2.6 times the smallest window value.

| Highest tile H | Spawn window (40, 30, 20, 10) | Average spawn |
|---|---|---|
| 2 to 1024 | 2, 4, 8, 16 | 5.2 |
| 2048 (2K) | 4, 8, 16, 32 | 10.4 |
| 4096 (4K) | 8, 16, 32, 64 | 20.8 |
| 8192 (8K) | 16, 32, 64, 128 | 41.6 |
| 16384 (16K) | 32, 64, 128, 256 | 83.2 |
| 32768 (32K) | 64, 128, 256, 512 | 166.4 |
| 65536 (64K) | 128, 256, 512, 1024 | 332.8 |
| 131072 (128K) | 256, 512, 1024, 2048 | 665.6 |
| 262144 (256K) | 512, 1024, 2048, 4096 | 1331.2 |
| 524288 (512K) | 1024, 2048, 4096, 8192 | 2662.4 |
| 1048576 (1M) | 2048, 4096, 8192, 16384 | 5324.8 |
| Each further doubling of H | The window moves up one step | Doubles |

Reasoning:

- The starting window of 2 to 16 gives plenty of equal pairs, and four values in a row give chains steps to climb.
- The window stays put until H reaches 2048, so players learn on small numbers. After that it moves up one step each time H doubles. The gap between new tiles and the highest tile stays fixed (H / 512 to H / 64), so each new record takes about the same amount of play, and long runs never stall grinding 2s toward a million.
- The smallest value is the most common, so equal pairs stay common and a board rarely dies by plain bad luck.
- Four values, not more: every extra value makes equal pairs rarer.

### 9.2 When the window is worked out (D-11)

The window is worked out once at the start of each spawn step, from the board after gravity. Spawns in the same step cannot change it: a spawn is never above Top, and Top is 16 or H / 64. The same applies to the spawn after a Hammer (section 13.3) and to the starting board (section 10), which counts as H below 16.

| # | Situation | H when spawning | Window |
|---|---|---|---|
| S1 | H is 1024. The player merges 1024, 1024 into 2048. | 2048 | 4, 8, 16, 32 |
| S2 | H is 4096 (only one), next highest 1024. The player hammers the 4096. | 1024 | 2, 4, 8, 16 |
| S3 | H is 2048. The player merges 2, 2, 2 elsewhere. | 2048 | 4, 8, 16, 32 |
| S4 | H is 131072. The player merges 65536, 65536 into 131072. | 131072 | 256, 512, 1024, 2048 |

### 9.3 Fill order (D-12)

Empty cells fill column by column from column 0 to column 4, and inside a column from the top row down. One draw per cell, in that order. This fixes the order of random draws, so a seeded run always repeats.

Worked example: after gravity the empty cells are (3,0), (1,0) and (1,1). The next three draws give 8, 2 and 4. Result: (1,0) = 8, (1,1) = 2, (3,0) = 4.

### 9.4 Tiles below the window (D-13)

Tiles smaller than the current window stay on the board and follow every normal rule.

Worked example: H reaches 2048 while the board holds three 2s. No new 2s spawn. Two touching 2s can still merge. A 2 that never meets another 2 stays until the player doubles it with Double (it becomes a 4, which still spawns), removes it with Hammer, or uses Swap to move it next to another 2.

Reasoning: removing them automatically would be a new feature. Leaving them adds light pressure in long runs and gives Hammer and Double a clear job.

### 9.5 Random numbers

Each run has one seedable random number generator, used for the starting board, spawns and Shuffle, in the order the moves happen. A new run takes a fresh random seed. Tests set the seed so results repeat. The generator's state is not saved; a resumed run takes a fresh random seed. This cannot be exploited, because every random result is saved the moment its move resolves (section 15).

## 10. Starting board

**D-14. The starting board is built like this:**

1. Fill all 40 cells in fill order (9.3) with draws from the starting window: 2, 4, 8, 16 with weights 40, 30, 20, 10.
2. If the board has a valid move (section 12.1), use it.
3. If not, redraw all 40 cells. At most 100 attempts in total.
4. If all 100 attempts fail, take the last attempt and set (1,7) to the value of (0,7). Those two cells touch, so the board now has a valid move.

A new run starts with score 0 and no Undo snapshot. Best Tile is updated from the starting board (step 7 of section 8 applies once to the new board).

Reasoning: a run must never start dead. A random board from this window almost never lacks a move, so step 4 exists only so the rule always finishes and can be tested.

Worked examples:

- ST1: the first attempt has two touching 4s. It is used as is.
- ST2: a test forces every attempt to come out as Board D (section 19), which has no valid move. After 100 attempts, (1,7) is set to the value of (0,7), which is 8. Cells (0,7) and (1,7) are now both 8 and form a valid move.

## 11. Score, Best Score and Best Tile

### 11.1 Score (D-18)

- A committed chain adds its sum to the score.
- Boosters never add points. Hammer, Swap, Shuffle and Double only cost points.
- Undo takes away the points of the chain it undoes (section 13.7).
- A new run starts at 0.

Worked example: score 0. Chain 2, 2, 2 adds 6 (score 6). Chain 4, 4, 8 adds 16 (score 22). Chain 8, 8 adds 16 (score 38).

### 11.2 Best Score (D-16)

After every resolved move, if the score is higher than Best Score, Best Score becomes the score. Best Score never goes down. It is saved with the settings, outside the run.

Reasoning: it needs no definition of when a run "ends" (game over, abandoned with New game, app uninstalled mid-run), and the player sees a new record the moment it happens. Spending still has a real cost: every point spent must be earned back before the run can set a higher record.

This is a decision Bart should confirm (open question Q1). His line "spending on boosters lowers the final score" could mean Best Score should only count the score at the end of a run. The alternative rule would be: Best Score updates only when a run ends, from the final score.

| # | Situation | Best Score with the live rule (D-16) | With the end of run alternative |
|---|---|---|---|
| B1 | Best Score 10,000. The run reaches 10,500. | 10,500 at once | Still 10,000 |
| B2 | Then the player spends 2,048 on Double. Score 8,452. | Stays 10,500 | Still 10,000 |
| B3 | The run ends at 9,000. | Stays 10,500 | Still 10,000 (9,000 is lower) |
| B4 | The run ends at 12,000. | 12,000 (already set live) | 12,000 |

### 11.3 Best Tile (D-17)

After every resolved move, and after the starting board is made, if H is higher than Best Tile, Best Tile becomes H. Best Tile never goes down. It counts every tile that was really on the board, however it got there: merge, Double, spawn or the starting board. It is saved with the settings, outside the run.

Reasoning: the rule matches what the player saw. A Double tile was paid for with score, and that tile can go on to merge into bigger ones. Excluding booster tiles would mean tracking where every tile came from.

| # | Situation | Best Tile after |
|---|---|---|
| T1 | Best Tile 4096. A merge makes 8192. | 8192 |
| T2 | The player uses Double on the 8192. | 16384 |
| T3 | The player hammers the 16384. H drops to 4096. | 16384 |
| T4 | A chain makes 32768, then the player uses Undo. | 32768 |

Before the first run ever, Best Score and Best Tile are both 0. After the first starting board appears, Best Tile is that board's highest tile (at most 16).

## 12. Game over

### 12.1 What counts as a valid move (D-15)

A board has a valid move if and only if two touching tiles (eight directions) have the same value.

Reason: every valid chain starts with two touching equal tiles, and any two touching equal tiles are already a valid chain. So the move check never needs to search for longer chains. Checking each cell against its right, lower left, lower and lower right neighbors covers every touching pair once.

| # | Board | Valid move? |
|---|---|---|
| V1 | Board D (section 19) | No |
| V2 | Board D with (2,0) changed to 4 | Yes: (1,0) and (2,0) are both 4, side by side |
| V3 | Board D with (1,1) changed to 2 | Yes: (0,0) and (1,1) are both 2, diagonal |
| V4 | Board D with (0,0) changed to 8 | Yes: (0,0) and (0,1) are both 8, one above the other |
| V5 | Board D with (0,0) and (2,0) changed to 4096 | No: the two 4096 tiles are two cells apart |

### 12.2 The no moves offer (D-19)

When the move check after a move, or after loading a saved run, finds no valid move:

1. Chain input stops. The board stays visible so the player can judge which booster would help.
2. The game works out which boosters are usable now. A booster is usable when it is affordable (section 13). Undo also needs a snapshot (section 13.7).
3. If none is usable, the run ends at once (12.3). The player sees that it ended because no moves were left.
4. Otherwise the player sees: that no moves are left; every booster with its cost, usable ones enabled and the rest visibly disabled; Shuffle marked as the suggested rescue whenever it is usable; and an End run choice.
5. Choosing Shuffle or Undo applies it at once. Choosing Hammer, Swap or Double enters targeting on the board. Cancelling targeting (tapping the booster again) returns to the offer with nothing charged.
6. After any booster resolves, the move check runs again. If a valid move exists, play goes on normally. If not, the offer opens again with costs and usability worked out afresh.
7. End run ends the run.

The offer has no time limit. The run never ends without the player choosing End run, unless nothing is usable.

Which boosters can rescue:

| Booster | Can it make a valid move? |
|---|---|
| Shuffle | Always, while any two tiles share a value (section 13.5). This is why it is the suggested rescue: it needs no planning at a tense moment. |
| Swap | Yes, whenever any two tiles share a value: swap one of them next to the other. Needs the player to spot it. |
| Undo | Yes: the board before the last chain had a valid move, the chain itself. |
| Double | Only if some tile touches a tile of double its value. |
| Hammer | Sometimes, through the fall and the new tile. Not guaranteed. |

All usable boosters are offered, because the brief says any booster the player can still afford. The game does not judge whether a choice will help.

### 12.3 When the run ends

- The saved run is deleted. Best Score and Best Tile are already up to date and stay saved.
- The player sees the final score, Best Score and Best Tile, and a way to start a new game.
- Nothing more can be done with that run.

### 12.4 Worked examples

All examples have H = 1024, so B = 1024. Costs: Hammer 1,024, Swap 1,024, Shuffle 1,024, Double 2,048, Undo 512.

| # | Situation | What the player sees and does | Result |
|---|---|---|---|
| GO1 | Score 5,000. Last chain gave 40 points. No moves. | All five usable. Shuffle marked. Taps Shuffle. | Score 3,976. Board has a valid move. Play goes on. |
| GO2 | Score 600. Last chain gave 40 points. No moves. | Hammer, Swap, Shuffle and Double disabled. Undo usable (600 minus 40 is 560, at least 512). Taps Undo. | Board from before the last chain. Score 600 minus 40 minus 512 = 48. Play goes on. |
| GO3 | Score 300. Last chain gave 40 points. No moves. | Nothing usable (300 minus 40 is 260, below 512). | Run ends at once. Final score 300. |
| GO4 | Score 1,500. No Undo snapshot (Undo was just used). No moves. | Hammer, Swap, Shuffle usable. Double and Undo disabled. Picks Hammer, then taps Hammer again. | Back at the offer. Score still 1,500. |
| GO5 | Same as GO4, after the cancel. | Picks Swap, then taps a 32 and a 4 that touches another 32. | The two 32s now touch. Score 476. Play goes on. |
| GO6 | Same as GO4, but the player hammers a 4 and the board still has no move. | Offer opens again. Every cost is at least 512, score is 476. | Nothing usable, so the run ends at once. Final score 476. |
| GO7 | The app is closed while the offer is open. | On reopening, the run loads, the move check finds no move. | The offer opens again, unchanged. |

## 13. Boosters

### 13.1 General rules (D-21, D-22)

- Each booster always shows its current cost.
- A booster is usable when it is affordable (score at least its cost). Undo has its own check (13.7). A booster that is not usable is visibly disabled, and tapping it does nothing.
- The cost is read from the board at the moment of use (D-21). It is charged in the same step as the effect, never before.
- Boosters can be used any time during play when no chain is being dragged and no move is still finishing on screen (D-35), and during the no moves offer.
- Shuffle and Undo have no target. Tapping them applies them at once.
- Hammer and Double need one tile. Swap needs two tiles. Tapping one of them enters targeting mode:
  - Nothing is charged. The player sees which booster is active.
  - While targeting, dragging does not build a chain. A tap on a tile (finger down and up on the same tile) picks it as a target. A drag that ends on a different tile picks nothing.
  - Tapping the same booster again cancels targeting. Nothing is charged.
  - Tapping a different usable booster cancels the first (nothing charged) and activates the second.
  - Taps outside the board and outside the booster buttons do nothing.
  - The Android back button cancels targeting first, before any other back action.
  - Pausing, or the app losing focus or closing, cancels targeting. Targeting is never saved.
- No move can happen while targeting, so the score and costs cannot change and the charge always succeeds.

### 13.2 Costs (D-20)

**Cost basis B is the larger of H (the highest tile on the board) and 128.**

| Booster | Cost | Late game cost in average moves of income (section 17) |
|---|---|---|
| Hammer | B | about 10 |
| Swap | B | about 10 |
| Shuffle | B | about 10 |
| Double | 2 x B | about 20 |
| Undo | B / 2 | about 5 |

Reasoning:

- Flat costs fail. Any flat price is either out of reach early or meaningless late, when scores run into the millions.
- Scaled to H, not to the score. The score grows in step with H (about 18 times H in the late game, section 17), so prices tied to H keep the same weight all run. A price that is a share of the score would always be affordable and would charge a careful player more. H rises only through play, and spending points does not lower it (only hammering the highest tile does), so spending lowers the score while prices stay put. Heavy spending runs out quickly.
- Costs are always powers of two, so they use the same label format as tiles (for example 64K) and stay short on the booster bar.
- Undo is cheapest. It fixes a slip of the finger, and the undone chain's points are lost too, so its real price is higher than shown.
- Hammer, Swap and Shuffle cost the same. Each fixes one problem. Shuffle is the guaranteed rescue, Swap is precise but needs a plan, Hammer clears one tile.
- Double costs most. It is the only booster that adds value to the board, and doubling the right tile can skip many moves of building.
- The 128 floor makes boosters a real choice from the first minute instead of free.

Examples from an early, a mid and a late game. Typical scores come from the model in section 17.

| Stage | H | Typical score | B | Hammer, Swap, Shuffle | Double | Undo | Hammer as share of score |
|---|---|---|---|---|---|---|---|
| First minutes | 32 | about 200 | 128 | 128 | 256 | 64 | 64 percent |
| Early | 256 | about 3,500 | 256 | 256 | 512 | 128 | 7.3 percent |
| Mid | 4096 (4K) | about 75,000 | 4096 | 4,096 (4K) | 8,192 (8K) | 2,048 (2K) | 5.5 percent |
| Late | 131072 (128K) | about 2,400,000 | 131072 | 131,072 (128K) | 262,144 (256K) | 65,536 (64K) | 5.5 percent |

In the first minutes boosters are a big decision (the score barely covers one). From the early game on, a Hammer costs about 5 to 7 percent of a typical score and a Double about 11 to 15 percent, so a player can afford a handful of rescues but not a habit.

Price changes during a run:

- Mid game, score 75,000. The player buys a Shuffle: score 70,904. Prices stay at 4,096 because H did not change.
- H is 1024 and the player merges two 1024s into 2048. Right after, Hammer goes from 1,024 to 2,048 and Double from 2,048 to 4,096.
- H is 4096 with only one such tile, next highest 1024. The player hammers the 4096 for 4,096. Right after, Hammer costs 1,024.

### 13.3 Hammer (D-23)

Target: any one tile, including the highest.

Effect, in order:

1. Charge B.
2. Empty the target cell.
3. Gravity in that column: the tiles above fall one cell.
4. Spawn one tile at the top of that column, from the window worked out after step 3 (9.2).
5. Records, save and move check, as steps 7 to 9 of section 8.

The Undo snapshot is not changed (13.7).

Worked examples:

- HM1: score 3,000, H = 1024. Column 3 holds 2, 8, 4, 16, 64, 8, 32, 2 (rows 0 to 7). Hammer on (3,4), the 64. Score 1,976. Column 3 becomes new, 2, 8, 4, 16, 8, 32, 2.
- HM2: score 10,000, one 4096, next highest 1024. Hammer on the 4096 costs 4,096 (read before the effect). Score 5,904. H is now 1024, so the new tile comes from 2, 4, 8, 16 and all prices drop to the 1024 level. Best Tile stays 4096.

### 13.4 Swap (D-24)

Target: two tiles anywhere on the board. They do not need to touch.

- The first tap on a tile selects it. The player sees it is selected.
- Tapping the selected tile again deselects it. Targeting stays on.
- Tapping a tile with the same value as the selected tile is ignored. Swapping equal values would change nothing but still cost points.
- Tapping any other tile completes the swap:
  1. Charge B.
  2. The two tiles change places. No gravity, no spawn.
  3. Records, save and move check, as steps 7 to 9 of section 8.

Worked examples:

- SW1: score 10,000, H = 2048. Select (0,0) = 32, tap (4,7) = 8. Now (0,0) = 8 and (4,7) = 32. Score 7,952.
- SW2: select a 32, then tap another 32. Nothing happens. The first 32 stays selected and nothing is charged.
- SW3: select a 32, tap it again. It is deselected, Swap stays active, nothing is charged. Tap Swap: targeting ends.

### 13.5 Shuffle (D-25)

Effect, in order:

1. Charge B.
2. Rearrange all 40 tiles at random, every arrangement equally likely. Values do not change, only their places.
3. If the new board has no valid move, rearrange again. At most 100 arrangements in total.
4. If all 100 have no valid move, take the last one and apply the fallback below.
5. Records, save and move check, as steps 7 to 9 of section 8.

Fallback: read the cells in reading order (row 0 left to right, then row 1, and so on). Find the first cell P whose value appears again later in reading order, and let Q be the first later cell with that value. Swap the tile in Q with the tile in the cell to the right of P, or, if P is in column 4, the cell below P. P and its twin now touch. (That neighbor cell is never Q itself, because then the board would already have had a valid move. When P is in column 4, a cell below it always exists: P has a later twin, so P cannot be the last cell, (4,7).)

Reasoning: a paid rescue must not fail by bad luck. With only one equal pair on the board (the worst real case), a random arrangement puts it touching about 16 percent of the time (123 touching cell pairs out of 780), so 100 straight failures happen about 3 times in 100 million. The fallback makes the guarantee exact and testable.

If no two tiles share a value, no arrangement can help. Shuffle still runs and is charged, then the no moves offer follows. This needs 40 different values, so a tile of at least 2^40, far beyond any real run. Shuffle is not blocked for it.

Worked examples:

- SH1: score 20,000, H = 4096. Shuffle costs 4,096. Score 15,904. Same 40 values, new places, at least one valid move.
- SH2: a test forces every arrangement to come out as Board D. Fallback: P = (0,0) (value 2), Q = (2,0) (the next 2 in reading order). Swap Q with the cell right of P, (1,0), which holds 4. Now (1,0) = 2 and (2,0) = 4. Cells (0,0) and (1,0) are both 2 and touch.

### 13.6 Double (D-26)

Target: any one tile, including the highest.

Effect, in order:

1. Charge 2 x B.
2. The tile's value doubles in place. No gravity, no spawn, no points.
3. Records (Best Tile can rise), save and move check, as steps 7 to 9 of section 8.

Worked examples:

- DB1: score 30,000, H = 4096. Double a 16 that touches a 32. Cost 8,192. Score 21,808. The two 32s now touch.
- DB2: score 30,000, H = 4096. Double the 4096. Cost 8,192 (read before the effect). Score 21,808. H is now 8192, so every price doubles right after. Best Tile becomes 8192 if it was lower.

### 13.7 Undo (D-27, D-28, D-29)

Snapshot: every committed chain stores the board from just before it and its points (step 1 of section 8). There is only ever one snapshot.

Undo is usable when both hold:

- a snapshot exists, and
- score minus the snapshot's points is at least the Undo cost (B / 2, from the current board).

Effect, in order:

1. The board becomes the snapshot board exactly.
2. The score becomes: score minus the snapshot's points minus the Undo cost.
3. The snapshot is cleared, so Undo is disabled until the next committed chain.
4. Records (they never go down), save and move check, as steps 7 to 9 of section 8. The move check always finds a move, because the chain that was undone was one.

Further rules:

- Undo goes back one step only.
- There is no snapshot at the start of a run or right after an Undo.
- Hammer, Swap, Shuffle and Double do not clear or replace the snapshot. If any of them was used after the last chain, Undo also undoes it (the board goes back to before the chain), and its cost stays spent.
- The random number generator is not rewound. Repeating the same chain after an Undo may bring different new tiles.
- Best Score and Best Tile are not lowered.

Reasoning:

- One step is enough to fix a mistake. More steps would turn Undo into a way to search for the best line, and would need far more saved data.
- Bart's rule restores the board and score from before the last chain and keeps the Undo cost spent. If a booster was used after that chain, restoring the old score in full would refund that booster, so any booster followed by an Undo would be free. Taking off only the chain's points keeps every paid cost paid. With no booster in between, the result is exactly Bart's rule: the old score minus the Undo cost.
- Checking affordability after the chain's points come off means the score can never go below zero.
- The cost comes from the current board like every other booster, so the price on the button is the price paid.

Worked examples:

| # | Situation | Undo usable? | Result |
|---|---|---|---|
| U1 | Score 1,000, H = 512. Chain 8, 8, 16 (+32). Score 1,032. Undo cost 256. | Yes: 1,032 minus 32 is 1,000 | Board from before the chain. Score 744 (1,000 minus 256). |
| U2 | As U1, then Hammer (512). Score 520. | Yes: 520 minus 32 is 488 | Board from before the chain, so the hammered tile is back too. Score 232 (1,000 minus 512 minus 256). |
| U3 | Right after U1. | No: no snapshot | Disabled until the next chain. |
| U4 | Start of a run. | No: no snapshot | Disabled. |
| U5 | Score 30. Chain 2, 2, 4, 8, 16, 32, 32 gives +96 and makes a 64. Score 126. H = 64, so B = 128 and the Undo cost is 64. | No: 126 minus 96 is 30, below 64 | Disabled, although the score shown (126) is above 64. Using it would have left minus 34. |
| U6 | Score 20,000, two 1024s, H = 1024. Chain 1024, 1024 (+2,048) makes 2048. Score 22,048. | Yes. Cost from the current board: B = 2048, Undo cost 1,024 | Board back with two 1024s. Score 18,976. Best Tile stays 2048. |
| U7 | Score 5,000, H = 1024. Chain (+40), then Shuffle (1,024). Score 4,016. | Yes: 4,016 minus 40 is 3,976, at least 512 | Board from before the chain, unshuffled. Score 3,464. The Shuffle cost stays spent. |

### 13.8 Score never goes below zero (D-30)

- The score is never below zero, at any moment.
- Chains only add points. A booster runs only when usable, and then the new score is the old score minus the cost, which is zero or more. For Undo, D-28 gives the same guarantee.
- The rules model itself must refuse a booster that is not usable: it returns a failure and changes nothing, even if the screen asks for it. It never clamps a negative score to zero, because clamping would hide a bug.

| # | Situation | Result |
|---|---|---|
| Z1 | Score 100, Hammer costs 128. | Hammer disabled. A forced call to the rules model is refused. Score stays 100, board unchanged. |
| Z2 | Score 128, Hammer costs 128. | Hammer usable. After use the score is 0, and every booster is disabled (the cheapest possible cost is 64). |
| Z3 | Score 0 and no moves. | Nothing usable. The run ends at once. |
| Z4 | Undo in U5. | Refused. It would have left minus 34. |

## 14. Number display

### 14.1 Tile labels (D-31)

Write a value as 2 to the power k.

- k from 1 to 10 (2 to 1024): the full number, with no separators.
- k of 11 or more: let u be the smaller of (k divided by 10, rounded down) and 4. The label is 2 to the power (k minus 10u), followed by K, M, B or T for u = 1, 2, 3 or 4. No space.

K, M, B and T here mean 1024, 1024 x 1024, and so on, the usual convention in this kind of game. A 2K tile is 2048.

| Value | k | Label |
|---|---|---|
| 2 | 1 | 2 |
| 512 | 9 | 512 |
| 1024 | 10 | 1024 |
| 2048 | 11 | 2K |
| 4096 | 12 | 4K |
| 65536 | 16 | 64K |
| 131072 | 17 | 128K |
| 524288 | 19 | 512K |
| 1048576 | 20 | 1M |
| 2097152 | 21 | 2M |
| 1073741824 | 30 | 1B |
| 2^40 | 40 | 1T |
| 2^49 | 49 | 512T |
| 2^50 | 50 | 1024T (from here on labels get longer, but no real run gets near this) |

Reasoning:

- The brief fixes the threshold: 1024 stays, 2048 becomes 2K.
- Steps of 1024 keep every label a whole number (2K, never 2.05K).
- Every value from 2 to 2^49 has a label of at most 4 characters. That is what makes labels readable on the smallest tile.

Readability requirement (assumption A-1): on a 56 dp tile, a 4 character label sits fully inside the tile with no clipping, and its digits are at least 12 dp tall. The design system picks the text sizes. It may use smaller text for 4 character labels than for shorter ones, but never below that minimum. QA checks it on a 360 dp wide screen.

### 14.2 Score, costs, preview and records (D-32)

| What | Format | Examples |
|---|---|---|
| Score and Best Score | Full number, commas every three digits, never abbreviated | 0, 999, 1,000, 75,000, 1,234,567 |
| Booster costs | Tile label format (costs are always powers of two) | 64, 4K, 128K |
| Merge preview | Tile label format | 32, 2K |
| Best Tile | Tile label format | 16K |

Reasoning: the score is exact and rarely a power of two, so abbreviating it would round it, and a score "2K" (2,000) would clash with the tile meaning of 2K (2,048). The screen showing the score must fit at least 13 characters (9,999,999,999). Players never need to compare a cost with the score by eye, because unaffordable boosters are visibly disabled.

## 15. Saving, resuming and move flow

### 15.1 What is saved (D-33)

| Data | Kept | Contents |
|---|---|---|
| Current run | Until the run ends or a new game replaces it | The 40 tile values, the score, and the Undo snapshot (40 values and the chain's points) or none |
| Settings | Always | Sound on or off (default on), selected skin (default: the approved direction) |
| Records | Always | Best Score, Best Tile |

Not saved: a drag in progress, targeting mode and a Swap selection, the no moves offer (worked out again on load), the random generator state (9.5) and animations.

When the run is saved:

- As soon as each move resolves in the rules model, before its animation ends.
- When a new run's starting board is made.
- When the app is paused, loses focus or is closed.

Saving right after the model resolves means closing the app during an animation cannot undo or reroll a move.

On load: show the saved board and score exactly, update the records (step 7 of section 8), then run the move check. If there is no valid move, open the no moves offer (12.2).

What a valid saved run looks like, for the save code's validation: exactly 40 values, each a power of two from 2 to 2^62; a score of 0 or more; an Undo snapshot that is either none or 40 values of the same kind plus points of 4 or more. Best Score is 0 or more. Best Tile is 0 or a power of two. If the saved run fails validation, it is discarded and a new run starts. Valid settings and records are kept.

### 15.2 New game during a run (D-34)

Starting a new game while a run is in progress asks the player to confirm. On confirm, the saved run is discarded and a new run starts. The discarded run's score already counted toward Best Score (D-16).

### 15.3 One move at a time (D-35)

After a move resolves, a new chain or booster tap is accepted only when that move's animation has finished. Input in the meantime is ignored, not queued. The player always acts on the board they can see. This rule does not set how long animations are; the design system keeps them short.

## 16. Click sound triggers (D-36)

- The click plays each time a tile joins a chain, including the first tile of a drag and a tile that joins again after a backtrack.
- It plays once when a chain commits.
- It does not play when a tile leaves by backtracking, when a drag cancels, or for boosters.
- It plays only when sound is on.

Worked example: drag 2, 2, 4, backtrack off the 4, move onto the 4 again, lift. Clicks: first 2, second 2, the 4, (none for the backtrack), the 4 again, the commit. Five clicks.

## 17. Score model (balance reasoning)

This model estimates typical scores so booster prices can be set. It is an estimate, not playtest data (assumption A-2).

- Let m be the average spawned value: 2.6 times the smallest window value (section 9.1).
- Every point of value on the board is counted in the score once for each merge it passes through. A tile of value V built from spawns averaging m passes through about log2(V / m) merges.
- When H first appears, the board also holds about another H in large tiles (H / 2, H / 4 and so on), so about 2H of built value. Rounding down loses roughly 20 percent on the way.

So, typical score when H first appears = 2.4 x H x log2(H / m).

Once H reaches 1024, the window keeps H / m at about 197 (512 / 2.6), and log2(197) is about 7.62. So from then on the typical score is about 18.3 x H.

| H | m | log2(H / m) | Typical score |
|---|---|---|---|
| 32 | 5.2 | 2.62 | 2.4 x 32 x 2.62 = 201, about 200 |
| 256 | 5.2 | 5.62 | 2.4 x 256 x 5.62 = 3,453, about 3,500 |
| 1024 | 5.2 | 7.62 | 2.4 x 1,024 x 7.62 = 18,727, about 19,000 |
| 4096 | 20.8 | 7.62 | 2.4 x 4,096 x 7.62 = 74,908, about 75,000 |
| 131072 | 665.6 | 7.62 | 2.4 x 131,072 x 7.62 = 2,397,045, about 2,400,000 |
| 1048576 | 5,324.8 | 7.62 | 2.4 x 1,048,576 x 7.62 = 19,176,358, about 19,000,000 |

Income per move in the late game: going from H to 2H adds about 18.3 x H to the score. It needs about 2.4 x H of new value from spawns (2H more on the board, plus the rounding loss), which is about 2.4 x 197 = 473 new tiles. If chains average about 3.5 tiles, each move spawns about 2.5 tiles, so that takes about 190 moves. Income is then about 18.3 x H / 190, roughly H / 10 per move. That gives the "average moves of income" column in section 13.2: Hammer, Swap and Shuffle (B = H) about 10 moves, Double about 20, Undo about 5.

Early in a run H is small, so each move earns more compared with H, and boosters cost only 2 to 3 moves of income at H = 256. That is deliberate: new players get to try boosters.

Playtest check for Phase 4: note the score and H at a few points in a few runs. If score divided by H is far from these numbers, retune the cost values in section 18.

## 18. Tunable values

Developers read every constant from this table. Bart can rebalance by changing values here. Keep every cost a power of two times B, so every cost stays a power of two and uses the tile label format.

| Name | Value | Meaning | Section |
|---|---|---|---|
| BOARD_COLUMNS | 5 | Board width in cells | 5 |
| BOARD_ROWS | 8 | Board height in cells | 5 |
| MIN_CHAIN_LENGTH | 2 | Fewest tiles a committed chain can have | 6 |
| JOIN_RADIUS | 0.42 | Hit radius around a tile center, as a share of the tile pitch | 6.4 |
| SPAWN_WINDOW_SIZE | 4 | Number of values that can spawn at once | 9.1 |
| SPAWN_WEIGHTS | 40, 30, 20, 10 | Weights from the smallest window value to the largest (they total 100) | 9.1 |
| SPAWN_TOP_MIN | 16 | The window's top value is never below this | 9.1 |
| SPAWN_TOP_DIVISOR | 64 | The window's top value is H divided by this, when that is above SPAWN_TOP_MIN | 9.1 |
| START_BOARD_MAX_ATTEMPTS | 100 | Starting board draws before the fallback | 10 |
| SHUFFLE_MAX_ATTEMPTS | 100 | Shuffle arrangements before the fallback | 13.5 |
| COST_BASIS_MIN | 128 | B is the larger of H and this | 13.2 |
| COST_HAMMER | B | Hammer cost | 13.2 |
| COST_SWAP | B | Swap cost | 13.2 |
| COST_SHUFFLE | B | Shuffle cost | 13.2 |
| COST_DOUBLE | 2 x B | Double cost | 13.2 |
| COST_UNDO | B / 2 | Undo cost | 13.2 |
| UNDO_DEPTH | 1 | Chains Undo can go back | 13.7 |
| LABEL_FULL_MAX | 1024 | Largest value shown as a full number | 14.1 |
| LABEL_STEP | 1024 | Size of each suffix step | 14.1 |
| LABEL_SUFFIXES | K, M, B, T | Suffixes for 1024, 1024 x 1024, and so on | 14.1 |
| SMALLEST_TILE_DP | 56 | Smallest tile size the labels must suit | 2, 14.1 |
| MIN_LABEL_DIGIT_HEIGHT_DP | 12 | Smallest digit height on a tile label | 14.1 |
| SCORE_MIN_CHARACTERS | 13 | Characters the score display must fit | 14.2 |
| SOUND_DEFAULT | On | Sound setting on first launch | 15.1, 16 |

## 19. Acceptance tests

Each test gives the setup, the action and the exact expected result. The Type says who runs it:

- **Unit**: the core logic or boosters developer builds the state directly in the rules model and turns the test into a unit test. QA checks the test exists and passes.
- **Play**: QA walks it in the running game (editor or phone).
- **Both**: a unit test for the rule, plus a QA check of what the player sees.

"Scripted spawn" means the test replaces the random draws with listed values, in fill order (9.3). A test that says "seeds 1 to N" repeats with each seed. Unless a test says otherwise, there is no Undo snapshot, Best Score is 0 and Best Tile is 0.

### 19.0 Test boards

**Board D** (no valid move, H = 16). Rows 0 to 7, columns 0 to 4:

```
row 0:   2   4   2   4   2
row 1:   8  16   8  16   8
row 2:   2   4   2   4   2
row 3:   8  16   8  16   8
row 4:   2   4   2   4   2
row 5:   8  16   8  16   8
row 6:   2   4   2   4   2
row 7:   8  16   8  16   8
```

Cells with equal values are always an even number of columns and an even number of rows apart, so they never touch.

**Board D1024**: Board D with (2,0) = 1024. Still no valid move. H = 1024, so B = 1024 and the costs are Hammer 1,024, Swap 1,024, Shuffle 1,024, Double 2,048, Undo 512.

**Board P** (the example board of section 6.6, H = 32):

```
row 0:   2   4   2   4   2
row 1:   8  16   8  16   8
row 2:   2   4   2   4   2
row 3:   8  16   8  16   8
row 4:   2   4   2   4   2
row 5:   8   4   8  16   8
row 6:   2   2   2   4   2
row 7:   8   8  32   8   8
```

**Board A4**: every cell is 4. **Board A2**: every cell is 2.

"Board D with (c,r) = v" means Board D with only the listed cells changed.

### 19.1 Board and starting board

**AT-01. Board size and starting values.** Type: Unit. Setup: new run, seed 1. Action: none. Expected: 40 tiles in 5 columns and 8 rows, every cell filled, every value is 2, 4, 8 or 16, score 0, Undo not usable.

**AT-02. Starting board always has a move.** Type: Unit. Setup: new runs with seeds 1 to 1,000. Action: none. Expected: every starting board has two touching tiles of equal value.

**AT-03. Starting board fallback.** Type: Unit. Setup: the starting board generator is forced to produce Board D on every attempt. Action: start a new run. Expected: exactly 100 attempts are made. The final board is Board D with (1,7) = 8. It has a valid move ((0,7) and (1,7)).

**AT-04. Starting value mix.** Type: Unit. Setup: 2,500 starting boards, seeds 1 to 2,500 (100,000 tiles). Action: count values. Expected: the shares of 2, 4, 8 and 16 are each within 1 percentage point of 40, 30, 20 and 10 percent.

**AT-05. Best Tile from the starting board.** Type: Unit. Setup: Best Score 0 and Best Tile 0. Action: start a new run. Expected: Best Tile equals the starting board's highest tile. Best Score is 0.

### 19.2 Making a chain

**AT-06. The first two tiles must be equal.** Type: Both. Setup: Board P, score 0. Action: drag from (1,6) (2) to (1,5) (4), then lift. Expected: the 4 does not join, the chain stays at 1 tile, no preview shows, and lifting cancels. Board, score and Undo state are unchanged, and the random generator was not used.

**AT-07. An equal second tile joins.** Type: Both. Setup: Board P. Action: drag (1,6) to (2,6). Expected: chain 2, 2. Preview 4.

**AT-08. A double joins from the third tile on.** Type: Both. Setup: AT-07 in progress. Action: move onto (3,6). Expected: chain 2, 2, 4. Preview 8.

**AT-09. More than double does not join.** Type: Both. Setup: AT-08 in progress. Action: move onto (2,7) (32). Expected: chain still 2, 2, 4. Preview 8.

**AT-10. Half does not join, diagonal does.** Type: Both. Setup: AT-08 in progress. Action: move onto (2,5) (8, diagonal from (3,6)), then onto (1,5) (4). Expected: (2,5) joins, chain 2, 2, 4, 8, preview 16. (1,5) does not join. Chain and preview unchanged.

**AT-11. All eight directions.** Type: Both. Setup: Board A4. Action: eight separate drags, each from (2,3) to one of (1,2), (2,2), (3,2), (1,3), (3,3), (1,4), (2,4), (3,4). Expected: in each drag the second tile joins and the preview shows 8.

**AT-12. Tiles that do not touch are refused.** Type: Unit. Setup: Board A4. Action: ask the rules model to commit [(2,3), (4,3)], then [(2,3), (2,5)], then [(0,0), (1,1), (3,3)]. Expected: all three are refused. Board and score unchanged.

**AT-13. Invalid chain lists are refused.** Type: Unit. Setup: Board A4 for the first two, Board P for the rest. Action: ask the rules model to commit each list: [(0,0), (1,0), (0,0)] (tile used twice); [(0,0)] (one tile); [(1,6), (1,5)] (2 then 4); [(1,6), (2,6), (2,7)] (2, 2, 32); [(1,6), (2,6), (3,6), (2,5), (1,5)] (8 then 4). Expected: every list is refused and nothing changes.

**AT-14. Backtracking shrinks the chain step by step.** Type: Both. Setup: Board P. Action: drag (1,6), (2,6), (3,6), (2,5), (3,5). Then move back onto (2,5), then (3,6), then (2,6), then (1,6), then lift. Expected: previews 4, 8, 16, 32 while building. After each backtrack: 4 tiles and preview 16; 3 tiles and preview 8; 2 tiles and preview 4; 1 tile and no preview. Lifting cancels. Nothing changes.

**AT-15. A backtracked tile can join again.** Type: Both. Setup: Board P, chain (1,6), (2,6), (3,6), (2,5), (3,5), then back onto (2,5). Action: move onto (3,5) again. Expected: (3,5) joins. Chain 2, 2, 4, 8, 16. Preview 32.

**AT-16. Other chain tiles are ignored.** Type: Both. Setup: Board P, chain (1,6), (2,6), (3,6), (2,5). Action: move onto (2,6). Expected: no change. Chain 2, 2, 4, 8. Preview 16.

**AT-17. Lifting commits.** Type: Both. Setup: Board P, score 0. Action: drag (1,6), (2,6), (3,6), (2,5), lift. Expected: score 16. The result 16 lands on (2,5) and falls to (2,6). Column 2, rows 1 to 7: 2, 8, 2, 8, 2, 16, 32. Cells (1,0), (2,0) and (3,0) hold new tiles from 2, 4, 8, 16. Undo is usable, and its snapshot is Board P with 16 points.

**AT-18. Lifting off the board commits.** Type: Play. Setup: any board with two touching equal tiles. Action: drag across the pair, slide the finger off the board, lift. Expected: the chain commits.

**AT-19. Leaving the board keeps the chain.** Type: Play. Setup: any board with three tiles x, x, 2x that touch in that order. Action: drag x, x; slide off the board; come back onto the 2x tile; lift. Expected: the chain stays at 2 tiles while off the board, the 2x tile joins on return, and the 3 tile chain commits.

**AT-20. The path may cross itself.** Type: Both. Setup: Board A4, score 0. Action: drag (1,1), (2,2), (2,1), (1,2), lift. Expected: all four join (the moves (1,1) to (2,2) and (2,1) to (1,2) cross). Preview 16. Score 16. The 16 stays on (1,2), because the cell below it is still full.

**AT-21. Hit radius.** Type: Both. Setup: tile pitch 60 dp, so the radius is 25.2 dp. Action: place the finger 20 dp right of a center, then 27 dp left of it, then 18 dp right and 18 dp down of it, then on the corner shared by four cells. Expected: over the tile; not over; not over; over no tile. Play check: on Board A4, swipe diagonally from (1,1) to (2,2) at normal speed ten times. (2,1) and (1,2) never join.

**AT-22. Only the first finger counts.** Type: Play. Setup: any board. Action: start a chain with one finger, touch the board with a second finger and move it over tiles. Expected: the second finger has no effect.

**AT-23. Booster taps are ignored during a drag.** Type: Play. Setup: score high enough for every booster. Action: while dragging a chain, tap Shuffle with another finger. Expected: nothing happens and nothing is charged.

**AT-24. A drag is cancelled by pause or focus loss.** Type: Play. Setup: a chain of 3 tiles in progress. Action: press the home button (or open pause), return. Expected: no chain in progress, board and score unchanged.

**AT-25. A chain can use the whole board.** Type: Unit. Setup: Board A2, score 0. Action: commit the snake path row 0 left to right, row 1 right to left, and so on to row 7 right to left (40 tiles, ending at (0,7)). Expected: score 80. (0,7) = 64. The other 39 cells hold new tiles from 2, 4, 8, 16.

### 19.3 Merge math

**AT-26. Rounding examples.** Type: Unit. Setup: for each row M1 to M10 of section 7.2, a board where that chain can be dragged. Action: commit it. Expected: the result and points exactly as in the table (for example M2: result 4, points 6; M6: result 64, points 88; M9: result 2048, points 3,072).

**AT-27. Result facts.** Type: Unit. Setup: 10,000 random valid chains (seeds 1 to 10,000). Action: compute each result. Expected: every result is a power of two, never more than the sum, more than half the sum, and at least double the chain's last tile.

**AT-28. Large values stay exact.** Type: Unit. Setup: Board D with (0,7) = 2^60 and (1,7) = 2^60, score 0. Action: commit (0,7), (1,7). Expected: (1,7) = 2^61 exactly, score 2^61 exactly. No floating point rounding anywhere.

### 19.4 Resolving a chain

**AT-29. Gravity example G1.** Type: Unit. Setup: column 2 holds 4, 16, 2, 8, 8, 8, 32, 64 (rows 0 to 7). Action: commit (2,3), (2,4), (2,5). Expected: column 2 is new, new, 4, 16, 2, 16, 32, 64. Points 24.

**AT-30. Gravity example G2.** Type: Unit. Setup: column 0 holds 2, 4, 8, 16, 32, 8, 4, 4. Action: commit (0,7), (0,6), (0,5). Expected: column 0 is new, new, 2, 4, 8, 16, 32, 16. Points 16.

**AT-31. Gravity example G3.** Type: Unit. Setup: Board P with (1,6) = 2, (2,7) = 2 and (3,6) = 4, scripted spawn 8 then 16. Action: commit (1,6), (2,7), (3,6). Expected: (3,6) = 8. Column 1 rows 0 to 5 moved down one row, column 2 rows 0 to 6 moved down one row. (1,0) = 8 and (2,0) = 16. Column 3 unchanged apart from (3,6).

**AT-32. Fill order.** Type: Unit. Setup: a board whose empty cells after gravity are (3,0), (1,0) and (1,1). Scripted spawn 8, 2, 4. Action: run the spawn step. Expected: (1,0) = 8, (1,1) = 2, (3,0) = 4.

**AT-33. Records update in the same move.** Type: Unit. Setup: Board D with (0,7) = 1024 and (1,7) = 1024, score 0, Best Score 0, Best Tile 1024. Action: commit (0,7), (1,7). Expected: right after the commit, before any other move, Best Score is 2,048 and Best Tile is 2048.

### 19.5 Spawning

**AT-34. Spawn window by highest tile.** Type: Unit. Setup: boards whose highest tile is 2, 16, 1024, 2048, 4096, 131072 and 1048576, and an empty board. Action: ask for the spawn window. Expected, in the same order: 2, 4, 8, 16; 2, 4, 8, 16; 2, 4, 8, 16; 4, 8, 16, 32; 8, 16, 32, 64; 256, 512, 1024, 2048; 2048, 4096, 8192, 16384; and 2, 4, 8, 16 for the empty board.

**AT-35. Spawn weights.** Type: Unit. Setup: H = 1024. Action: (a) map the draw numbers 0, 39, 40, 69, 70, 89, 90 and 99 to values; (b) make 100,000 seeded draws. Expected: (a) 2, 2, 4, 4, 8, 8, 16, 16. (b) The shares of 2, 4, 8 and 16 are each within 1 percentage point of 40, 30, 20 and 10 percent.

**AT-36. A merge that raises H raises the window at once.** Type: Unit. Setup: Board D with (0,7) = 1024 and (1,7) = 1024. Seeds 1 to 200. Action: commit (0,7), (1,7). Expected: the one new tile, at (0,0), is 4, 8, 16 or 32 every time, never 2.

**AT-37. A Hammer that lowers H lowers the window at once.** Type: Unit. Setup: Board D with (0,7) = 4096 and (4,7) = 1024, score 10,000, Best Tile 4096. Seeds 1 to 200. Action: Hammer on (0,7). Expected: score 5,904. The new tile at (0,0) is 2, 4, 8 or 16. Hammer now costs 1,024. Best Tile stays 4096.

**AT-38. Tiles below the window still play.** Type: Unit. Setup: Board D with (2,0) = 2048 and (1,6) = 2, so (0,6) and (1,6) are both 2. Score 0. Seeds 1 to 200. Action: commit (0,6), (1,6). Expected: (1,6) = 4, score 4, and the new tile at (0,0) is 4, 8, 16 or 32, never 2.

### 19.6 Score and records

**AT-39. Points are the sum, not the result.** Type: Unit. Setup: Board D with (1,0) = 2, so row 0 starts 2, 2, 2. Score 0. Action: commit (0,0), (1,0), (2,0). Expected: score 6. (2,0) = 4.

**AT-40. Boosters add no points.** Type: Unit. Setup: Board D1024, score 10,000. Action, in order: Hammer on (4,7); Swap (0,0) with (1,0); Double on (0,2); Shuffle. Expected: score after each step: 8,976; 7,952; 5,904; 4,880.

**AT-41. Best Score updates live and never drops.** Type: Both. Setup: Board D with (0,0) = 8, score 9,990, Best Score 10,000. Action: commit (0,0), (0,1) (8, 8), then Hammer on any tile. Expected: right after the commit, score and Best Score are both 10,006. After the Hammer (cost 128), score 9,878 and Best Score still 10,006.

**AT-42. Undo does not lower Best Score.** Type: Unit. Setup: the state right after the commit in AT-41 (score 10,006, Best Score 10,006). Action: Undo (cost 64). Expected: score 9,926. Best Score stays 10,006.

**AT-43. Best Tile counts Double and is not lowered by Hammer.** Type: Unit. Setup: Board D with (0,7) = 4096 and (1,7) = 4096, score 50,000, Best Tile 4096. Action: commit (0,7), (1,7); then Double on the 8192; then Hammer on the 16384. Expected: after the commit Best Tile 8192 and score 58,192. After Double (cost 16,384): score 41,808, Best Tile 16384. After Hammer (cost 16,384): score 25,424, H = 16, Best Tile still 16384.

**AT-44. Records persist.** Type: Play. Setup: finish a run that set a new Best Score and Best Tile. Action: close the app fully, reopen it, start a new run. Expected: Best Score and Best Tile show the values from the finished run.

### 19.7 Game over

**AT-45. Move check.** Type: Unit. Setup and expected, from section 12.1: Board D has no valid move. Board D with (2,0) = 4 has one. Board D with (1,1) = 2 has one. Board D with (0,0) = 8 has one. Board D with (0,0) = 4096 and (2,0) = 4096 has none.

**AT-46. A move that leaves no valid move opens the offer.** Type: Both. Setup: Board D with (0,0) = 4 and (1,0) = 2, score 5,000. Action: Swap (0,0) and (1,0). Expected: the board is now Board D, score 4,872, the no moves offer opens and dragging builds no chain.

**AT-47. What the offer shows.** Type: Both. Setup: Board D1024, score 5,000, an Undo snapshot worth 40 points whose board has a valid move. Action: run the move check. Expected: the offer opens. All five boosters are enabled with costs Hammer 1,024 (shown 1024), Swap 1,024, Shuffle 1,024, Double 2,048 (shown 2K), Undo 512. Shuffle is marked as suggested. End run is present. The board stays visible. In Play, the offer is still open after 60 seconds without input.

**AT-48. Shuffle rescues.** Type: Both. Setup: AT-47. Action: tap Shuffle. Expected: score 3,976. The board has a valid move. The offer closes and chains can be dragged.

**AT-49. Only Undo is usable.** Type: Both. Setup: Board D1024, score 600, an Undo snapshot worth 40 points whose board has a valid move. Action: open the offer, tap Undo. Expected: only Undo is enabled. After the tap, the board equals the snapshot board, score 48, and the offer closes.

**AT-50. Nothing usable ends the run at once.** Type: Both. Setup: Board D1024, score 300, an Undo snapshot worth 40 points. Action: run the move check. Expected: no offer. The run ends at once. The game over screen shows final score 300, Best Score, Best Tile and a way to start a new game. The saved run is deleted.

**AT-51. Cancelling targeting returns to the offer.** Type: Both. Setup: Board D1024, score 1,500, no snapshot. Action: open the offer, tap Hammer, tap Hammer again. Expected: before the taps, Hammer, Swap and Shuffle are enabled and Double and Undo disabled. After the second tap the offer is back and the score is still 1,500.

**AT-52. Swap rescues.** Type: Both. Setup: Board D1024 with (0,0) = 32 and (4,7) = 32, score 1,500. Action: from the offer, Swap (4,7) with (1,0). Expected: (1,0) = 32 and (4,7) = 4. Score 476. The board has a valid move and play goes on.

**AT-53. The offer repeats, then the run ends.** Type: Unit. Setup: Board D1024, score 1,500, no snapshot, scripted spawn 8. Action: Hammer on (4,7). Expected: column 4 reads 8, 2, 8, 2, 8, 2, 8, 2. Score 476. Still no valid move. Every cost is at least 512, so nothing is usable and the run ends at once with final score 476.

**AT-54. End run.** Type: Play. Setup: the offer is open with something usable. Action: tap End run. Expected: the game over screen shows the final score, Best Score, Best Tile and a way to start a new game. Closing and reopening the app does not resume that run.

**AT-55. The offer survives a restart.** Type: Both. Setup: the offer is open. Action: close the app fully and reopen it. Expected: same board and score, and the offer opens again.

### 19.8 Boosters: general rules

**AT-56. Cost table.** Type: Unit. Setup: boards with H = 16, 128, 256, 4096 and 131072. Action: read B and every cost. Expected:

| H | B | Hammer | Swap | Shuffle | Double | Undo |
|---|---|---|---|---|---|---|
| 16 | 128 | 128 | 128 | 128 | 256 | 64 |
| 128 | 128 | 128 | 128 | 128 | 256 | 64 |
| 256 | 256 | 256 | 256 | 256 | 512 | 128 |
| 4096 | 4096 | 4096 | 4096 | 4096 | 8192 | 2048 |
| 131072 | 131072 | 131072 | 131072 | 131072 | 262144 | 65536 |

**AT-57. Unaffordable boosters are visibly disabled.** Type: Both. Setup: Board D, no snapshot. Action: set the score to 127, then 128, then 256. Expected: at 127 all five are disabled and tapping them does nothing. At 128 Hammer, Swap and Shuffle are enabled, Double and Undo disabled. At 256 Double is enabled too. Undo stays disabled (no snapshot).

**AT-58. Spending down to exactly zero.** Type: Unit. Setup: Board D, score 128. Action: Hammer on any tile. Expected: score 0. All five boosters are now disabled.

**AT-59. The rules model refuses what is not usable.** Type: Unit. Setup: Board D, score 100, no snapshot. Action: call Hammer, Swap, Shuffle, Double and Undo on the rules model directly. Expected: every call is refused. Board, score and snapshot are unchanged and the random generator was not used.

**AT-60. Costs follow H at once.** Type: Unit. Setup: Board D with (0,7) = 1024 and (1,7) = 1024. Action: read the costs, commit (0,7), (1,7), read them again. Expected: before, Hammer 1,024 and Double 2,048. After, Hammer 2,048, Swap 2,048, Shuffle 2,048, Double 4,096, Undo 1,024.

**AT-61. Entering and cancelling targeting charges nothing.** Type: Both. Setup: Board P, score 5,000. Action: tap Hammer, tap Hammer again, then drag (1,6) to (2,6). Expected: targeting turns on and off, the score stays 5,000, and the drag then builds the chain 2, 2 normally.

**AT-62. No chains while targeting.** Type: Both. Setup: Board P, score 5,000, Double active. Action: drag from (1,6) to (2,6) and lift. Expected: no chain, no preview, nothing doubled, nothing charged. Double is still active.

**AT-63. Switching boosters.** Type: Both. Setup: Board P, score 5,000. Action: tap Hammer, then Double, then Shuffle. Expected: after Double, Double is active, Hammer is not, score 5,000. After Shuffle, Double is no longer active, the board is shuffled and the score is 4,872.

**AT-64. Back cancels targeting.** Type: Play. Setup: Swap active with one tile selected. Action: press the Android back button once. Expected: targeting ends, nothing is charged, and the game stays on the board (no pause, no exit).

**AT-65. Targeting is not saved.** Type: Both. Setup: Swap active with (0,0) selected, score 5,000. Action: close the app fully and reopen it. Expected: no booster active, no tile selected, score 5,000.

**AT-66. Taps elsewhere do nothing while targeting.** Type: Play. Setup: Hammer active. Action: tap the score area and other empty screen space. Expected: Hammer stays active and nothing is charged.

### 19.9 Each booster

**AT-67. Hammer.** Type: Unit. Setup: Board D with (2,0) = 1024 and column 3 set to 2, 8, 4, 16, 64, 8, 32, 2 (rows 0 to 7). Score 3,000. Scripted spawn 4. Action: Hammer on (3,4). Expected: column 3 reads 4, 2, 8, 4, 16, 8, 32, 2. Score 1,976. No other column changed. The Undo snapshot (none) is unchanged.

**AT-68. Swap.** Type: Both. Setup: Board D with (2,0) = 2048 and (0,0) = 32. Score 10,000. Action: tap Swap, tap (0,0), tap (4,7). Expected: (0,0) = 8 and (4,7) = 32. Every other cell unchanged, no new tiles. Score 7,952.

**AT-69. Swap ignores equal values and can deselect.** Type: Both. Setup: Board D with (0,0) = 32 and (4,7) = 32. Score 5,000. Action: tap Swap, tap (0,0), tap (4,7), tap (0,0), tap Swap. Expected: tapping (4,7) does nothing and (0,0) stays selected. Tapping (0,0) again deselects it. Tapping Swap ends targeting. Board unchanged, score 5,000 throughout.

**AT-70. Shuffle keeps the values and leaves a move.** Type: Unit. Setup: Board D1024, score 5,000. Seeds 1 to 1,000. Action: Shuffle. Expected: the sorted list of the 40 values is unchanged, the board has a valid move, and the score is 3,976.

**AT-71. Shuffle with only one equal pair.** Type: Unit. Setup: a board holding 2, 4, 8 and so on up to 2^39 (39 tiles) plus a second 2. Score 2^41. Seeds 1 to 1,000. Action: Shuffle. Expected: the two 2s touch every time. Score 2^41 minus 2^39.

**AT-72. Shuffle fallback.** Type: Unit. Setup: Board D, score 1,000. Every arrangement is forced to come out as Board D. Action: Shuffle. Expected: exactly 100 arrangements are tried. The final board is Board D with (1,0) = 2 and (2,0) = 4. It has a valid move. Score 872.

**AT-73. Shuffle with no equal pair.** Type: Unit. Setup: a board holding 2, 4, 8 and so on up to 2^40 (40 different values). Score 2^41. Action: Shuffle. Expected: score 2^40, the same 40 values in new places, no valid move, and the no moves offer opens.

**AT-74. Double makes a pair.** Type: Both. Setup: Board D with (2,0) = 4096 and (0,0) = 32. Score 30,000. Action: Double on (1,1) (16). Expected: (1,1) = 32. Score 21,808. The board has a valid move ((0,0) and (1,1)).

**AT-75. Double on the highest tile.** Type: Unit. Setup: as AT-74, Best Tile 4096. Action: Double on (2,0). Expected: (2,0) = 8192. Score 21,808 (the cost was read before the effect). Hammer now costs 8,192. Best Tile 8192.

**AT-76. Undo after a chain.** Type: Both. Setup: Board D with (2,0) = 512, (1,7) = 8 and (2,7) = 16. Score 1,000. Action: commit (0,7), (1,7), (2,7) (8, 8, 16), then Undo. Expected: after the commit, score 1,032 and Undo enabled at cost 256. After Undo, the board equals the setup board exactly, score 744, and Undo is disabled.

**AT-77. Undo after a chain and a Hammer.** Type: Unit. Setup: as AT-76. Action: commit the same chain, Hammer on (4,0), Undo. Expected: after the Hammer, score 520 and Undo enabled. After Undo, the board equals the setup board (the hammered tile is back) and the score is 232.

**AT-78. Undo is one step and needs a chain.** Type: Unit. Setup: a new run. Action: check Undo; commit any chain; Undo; check Undo; commit another chain; check Undo. Expected: disabled at the start, disabled right after the Undo, enabled again after the next chain.

**AT-79. Undo affordability uses the score without the chain's points.** Type: Unit. Setup: Board D with (0,7) = 2, (1,7) = 2, (2,7) = 4, (3,7) = 8, (4,7) = 16, (4,6) = 32, (3,6) = 32. Score 30. Action: commit that path in that order, then call Undo on the rules model. Expected: after the commit, score 126, H = 64, Undo cost 64, Undo disabled. The call is refused and the score stays 126.

**AT-80. Undo cost comes from the current board, and records stay.** Type: Unit. Setup: Board D with (0,7) = 1024 and (1,7) = 1024. Score 20,000. Best Tile 1024. Action: commit (0,7), (1,7), then Undo. Expected: after the commit, score 22,048 and Undo cost 1,024. After Undo, the board equals the setup board, score 18,976, Best Tile 2048 and Best Score 22,048.

**AT-81. Undo after a Shuffle.** Type: Unit. Setup: Board D with (2,0) = 1024 and (1,7) = 8, so row 7 reads 8, 8, 8, 16, 8. Score 5,000. Action: commit (0,7), (1,7), (2,7), (3,7) (8, 8, 8, 16, worth 40), Shuffle, Undo. Expected: after the commit 5,040, after Shuffle 4,016, after Undo the board equals the setup board (unshuffled) and the score is 3,464.

**AT-82. Undo does not rewind the random generator.** Type: Unit. Setup: AT-76 with seed 7, just before the Undo. Action: record the generator state, Undo, read the state again. Expected: the two states are equal.

**AT-83. The Undo snapshot survives a restart.** Type: Both. Setup: right after a chain, Undo enabled. Action: close the app fully, reopen, Undo. Expected: Undo is enabled with the same cost as before closing, and Undo gives the board from before that chain and the expected score.

### 19.10 Score never below zero

**AT-84. Random play never goes below zero.** Type: Unit. Setup: seeds 1 to 20, a new run each. Action: 10,000 random actions per run: valid chain commits, and calls to all five boosters with random targets whether or not they are usable. Expected: the score is never below zero. Every refused call changed nothing. Every accepted booster lowered the score by exactly its cost (Undo: by the chain's points plus its cost).

### 19.11 Number display

**AT-85. Tile labels.** Type: Unit. Action: format every value in the table of section 14.1. Expected: exactly the labels listed (for example 1024 gives "1024", 2048 gives "2K", 131072 gives "128K", 1048576 gives "1M", 2^40 gives "1T").

**AT-86. Labels are short.** Type: Unit. Action: format every power of two from 2 to 2^49. Expected: every label is 4 characters or fewer. 2^50 gives "1024T".

**AT-87. Labels are readable on the smallest tile.** Type: Play. Setup: a 360 dp wide portrait screen (phone or emulator) and a test board holding 1024, 512K and 128K tiles. Action: look at the board. Expected: tiles are at least 56 dp wide. Every label sits fully inside its tile with no clipping, and its digits are at least 12 dp tall.

**AT-88. Score format.** Type: Both. Action: format 0, 999, 1000, 75000 and 1234567, and show a score of 9,999,999,999 on a 360 dp wide screen. Expected: "0", "999", "1,000", "75,000", "1,234,567". The long score shows in full with no clipping.

**AT-89. Costs, preview and Best Tile use tile labels.** Type: Both. Action: drag the chain 512, 512, 1024, 1024; view the booster bar with H = 131072; view a Best Tile of 16384. Expected: preview "2K". Undo shows "64K", Double "256K", Hammer "128K". Best Tile shows "16K".

**AT-90. Preview life cycle.** Type: Both. Setup: a board where chain M8 (2, 2, 4, 4, 4, 8, 8, 16) can be dragged. Action: drag it one tile at a time, backtrack off the 16, lift. Expected previews: none, 4, 8, 8, 16, 16, 32, 32, then 32 after the backtrack. No preview after the lift.

### 19.12 Saving and flow

**AT-91. Resume after the app is killed.** Type: Play. Setup: a run in progress with an Undo snapshot. Note the board, score, Best Score, Best Tile and Undo cost. Action: swipe the app away from recent apps, reopen it. Expected: the same board and score, the same records, Undo enabled at the same cost.

**AT-92. Killed during an animation.** Type: Play. Setup: a run in progress. Action: commit a long chain and kill the app before its animation ends. Reopen. Expected: the chain's result and points are there.

**AT-93. Killed during a drag.** Type: Play. Setup: a 3 tile chain being dragged. Action: kill the app while the finger is still down. Reopen. Expected: no chain was committed. Board and score are as before the drag.

**AT-94. Settings persist and sound starts on.** Type: Play. Setup: a fresh install. Action: check the sound setting; turn sound off and pick a different skin; close the app fully and reopen. Expected: sound is on at first launch. After reopening, sound is off and the chosen skin is shown.

**AT-95. A broken saved run is discarded.** Type: Unit. Setup: valid records (Best Score 5,000, Best Tile 512), and in turn each of these saved runs: 39 values; a value of 3; a value of 0; a score of minus 1; a snapshot with 40 valid values and points 2. Action: load. Expected: each time the run is discarded and a new run starts. Best Score 5,000 and Best Tile 512 are kept.

**AT-96. New game asks first.** Type: Play. Setup: a run in progress. Action: choose New game, cancel; choose New game, confirm. Expected: after cancel the run is unchanged. After confirm a new run starts with score 0 and Undo disabled, and Best Score still holds the old run's highest score.

**AT-97. One move at a time.** Type: Play. Setup: a run in progress. Action: commit a chain and, while its animation plays, try to drag another chain and tap a booster. Expected: both are ignored. Once the animation ends, both work.

**AT-98. Click sound triggers.** Type: Both (unit test by counting calls to the audio service). Action: (a) drag 2, 2, 4, backtrack off the 4, move onto the 4 again, lift; (b) touch one tile and lift; (c) use Shuffle; (d) repeat (a) with sound off. Expected: (a) 5 clicks; (b) 1 click; (c) none; (d) none.

### 19.13 Coverage

| Decision or rule | Tests |
|---|---|
| D-01 Board size | AT-01 |
| D-02 Rounding down | AT-26, AT-27, AT-28 |
| D-03 Preview | AT-07, AT-14, AT-89, AT-90 |
| D-04 Joining rule | AT-06, AT-08, AT-09, AT-10, AT-11, AT-12, AT-13 |
| D-05 Backtracking | AT-14, AT-15, AT-16 |
| D-06 Path, leaving, lifting | AT-18, AT-19, AT-20, AT-25 |
| D-07 Hit radius | AT-21 |
| D-08 One finger | AT-22, AT-23, AT-24 |
| D-09 Resolution order | AT-17, AT-29 to AT-33 |
| D-10 Spawn window and weights | AT-04, AT-34, AT-35 |
| D-11 Window timing | AT-36, AT-37 |
| D-12 Fill order | AT-31, AT-32 |
| D-13 Tiles below the window | AT-38 |
| D-14 Starting board | AT-01 to AT-03 |
| D-15 Valid move | AT-45 |
| D-16 Best Score | AT-41, AT-42, AT-80 |
| D-17 Best Tile | AT-05, AT-37, AT-43, AT-75, AT-80 |
| D-18 Only chains add points | AT-39, AT-40 |
| D-19 No moves offer | AT-46 to AT-55, AT-73 |
| D-20 Costs | AT-56, AT-60 |
| D-21 Cost read at use, charged with effect | AT-37, AT-60, AT-61, AT-75 |
| D-22 Targeting | AT-61 to AT-66 |
| D-23 Hammer | AT-37, AT-53, AT-67 |
| D-24 Swap | AT-52, AT-68, AT-69 |
| D-25 Shuffle | AT-48, AT-70 to AT-73 |
| D-26 Double | AT-74, AT-75 |
| D-27 Undo | AT-49, AT-76, AT-77, AT-78, AT-81 |
| D-28 Undo affordability | AT-79 |
| D-29 Undo keeps records and generator | AT-42, AT-80, AT-82 |
| D-30 Never below zero | AT-57, AT-58, AT-59, AT-84 |
| D-31 Tile labels | AT-85, AT-86, AT-87 |
| D-32 Score and cost formats | AT-88, AT-89 |
| D-33 Saving | AT-55, AT-65, AT-83, AT-91 to AT-93, AT-95 |
| D-34 New game | AT-96 |
| D-35 One move at a time | AT-97 |
| D-36 Click triggers | AT-98 |
| D-37 64-bit values | AT-28, AT-71, AT-73 |
| Confirmed: chain rules | AT-06 to AT-16 |
| Confirmed: merge and after merge | AT-17, AT-26, AT-29 to AT-31 |
| Confirmed: score, Best Score and Best Tile kept separately | AT-39 to AT-44 |
| Confirmed: game over | AT-45 to AT-55 |
| Confirmed: boosters, disabled when unaffordable, score never below zero | AT-56 to AT-84 |
| Confirmed: number display | AT-85 to AT-89 |
| Confirmed: persistence | AT-44, AT-83, AT-91 to AT-95 |

