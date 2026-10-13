# SumUp: Game Design Document

Owner: lead-game-designer. Status: approved by Bart at Hard Stop 1 on 2026-10-10. Decisions D-38 to D-43 were added after Hard Stop 1: they write out the three additions Bart made to v1 scope and close two gaps found in the design review. Decisions D-44 to D-46 were added on 2026-10-13 at Bart's request: How to play, stars and free boosters.

This document turns section 3 of docs/BRIEF.md into exact rules. The rules Bart confirmed are copied unchanged in section 4. Every gap the brief leaves open is settled here as a numbered designer decision (D-01, D-02, ...) with its reasoning and worked examples. Every tunable number lives in one table in section 18. Section 19 is the acceptance test list (AT-01, AT-02, ...) that QA walks and developers turn into unit tests. Section 20 lists the test hooks those tests need from the code. Section 21 holds the exact How to play text.

All rules here describe the rules model only. They do not depend on any screen, so level goals could be added later. Nothing here is designed for level goals.

## 1. Decision summary

One line per designer decision. Bart signed off on D-01 to D-37 at Hard Stop 1. D-38 to D-46 were added afterwards (section 1.1).

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
| D-09 | A committed chain resolves in a fixed order: score, place result, clear the chain, clear small tiles (D-38), gravity, spawn, records, save, move check. | 8 |
| D-10 | Spawn window: four values in a row, the top one is the larger of 16 and highest tile divided by 64. Weights 40, 30, 20, 10 from smallest to largest. | 9 |
| D-11 | The spawn window is worked out from the board at the moment of spawning, after gravity. A merge or Hammer that changes the highest tile changes the window at once. | 9 |
| D-12 | Empty cells fill column by column from the left, and from the top row down inside each column. | 9 |
| D-13 | Replaced by D-38 at Hard Stop 1. (It said tiles smaller than the spawn window stay on the board.) | 9.4 |
| D-14 | Starting board: 40 tiles drawn from the starting spawn window, redrawn until it has a valid chain, with a fixed fallback after 100 tries. | 10 |
| D-15 | A board has a valid move if and only if two touching tiles (eight directions) have the same value and their sum fits in a 64 bit integer. Only a hand edited save can fail the second part (SEC-01). | 12 |
| D-16 | Best Score updates live whenever the current score goes above it. Confirmed by Bart at Hard Stop 1. | 11 |
| D-17 | Best Tile is the highest value ever on the board, from any source (merge, Double, spawn). It never goes down. | 11 |
| D-18 | Only committed chains add points. Boosters never add points. | 11 |
| D-19 | No moves left: the run pauses on an offer of every booster the player can afford and use, with one suggested rescue marked (D-42). The run ends only when the player taps End run, or at once if nothing is usable. | 12 |
| D-20 | Cost basis B is the larger of the highest tile on the board and 128. Hammer costs B, Swap B, Shuffle B, Double 2 times B, Undo half of B. | 13.2 |
| D-21 | A cost is read from the board when the booster is used and charged only when its effect applies. | 13.1 |
| D-22 | Targeting: tap the booster to enter, tap it again to cancel, tap another booster to switch. Nothing is charged until the effect applies. | 13.1 |
| D-23 | Hammer removes the tile, the tiles above fall one cell, and one new tile spawns at the top of that column. | 13.3 |
| D-24 | Swap works on any two tiles anywhere. Tapping the selected tile again deselects it. A tile with the same value as the selected one cannot be picked. | 13.4 |
| D-25 | Shuffle always leaves at least one valid chain when the board holds two tiles of equal value whose sum fits (D-15), which is always true while the highest tile is below 2^40. | 13.5 |
| D-26 | Double doubles one tile in place. No gravity and no spawn, unless the Double raises the spawn window and small tiles clear (D-38). | 13.6 |
| D-27 | Undo goes back one step only. It restores the board from before the last chain and takes that chain's points off the score. Every cost paid since then stays spent, including Undo's own cost. | 13.7 |
| D-28 | Undo is affordable only when the score minus the last chain's points is at least the Undo cost. | 13.7 |
| D-29 | Undo does not lower Best Score or Best Tile and does not rewind the random number generator. | 13.7 |
| D-30 | Score never goes below zero: the rules model refuses any booster the player cannot afford. It never clamps a negative score to zero. | 13.8 |
| D-31 | Tile labels: the full number up to 1024. From 2048 up, a number from 1 to 512 plus K, M, B or T (2K, 512K, 1M). Never more than 4 characters. | 14 |
| D-32 | The score shows in full with commas (1,234,567). Booster costs and the merge preview use the tile label format. | 14 |
| D-33 | The run (including this run's highest tile) saves as soon as each move resolves, and when the app is paused. The board starts showing a move only once its save has finished, so the player never sees a result that was not saved. A drag in progress and targeting mode are not saved. | 15 |
| D-34 | Starting a new game while a run is in progress asks for confirmation, then discards the saved run. | 15 |
| D-35 | One move at a time: no new chain or booster is accepted until the previous move has finished on screen. | 15 |
| D-36 | The click plays for every tile added to a chain, including the first, and once on commit. Never on backtrack or cancel. | 16 |
| D-37 | Tile values and the score are 64-bit integers with no cap. At the limit, which only a hand edited save can reach, every rule is set so the run can always go on or end, and a booster that could do nothing is not usable. | 5, 13.1 |
| D-38 | Small tile clearing: when a chain or a Double raises the spawn window's smallest value, every tile below the new smallest value clears at once, scores nothing, and the board refills (gravity, then spawns) before the move check. Replaces D-13. | 9.4 |
| D-39 | Hammer, Swap, Shuffle and Undo never trigger clearing. Undo brings back tiles the undone chain cleared. Clearing never touches Best Tile or this run's highest tile. A Hammer that lowers the highest tile lets smaller values spawn again until the window rises again. | 9.4 |
| D-40 | While dragging, exactly the tiles that would join if the finger moved onto them now are highlighted (D-04). Tiles already in the chain, including the backtrack tile, are never highlighted. | 6.7 |
| D-41 | This run's highest tile is the highest value on the board at any time this run, from any source. Hammer and Undo never lower it. It is saved with the run and shown on the end of run screen with the final score, Best Score, Best Tile and New game. | 11.4, 12.3 |
| D-42 | The no moves offer marks Shuffle as the suggested rescue when it is usable, otherwise Undo when it is usable, otherwise nothing. | 12.2 |
| D-43 | Hammer and Double act on one tap, and Swap acts on the tap of its second tile. There is no select then confirm step. A highlight under a pressed finger is press feedback only. | 13.1 |
| D-44 | How to play: seven short sections of fixed text, three with an example row of real tiles in the current skin. It opens only from its button on the main menu or in Pause, and back closes it. | 21 |
| D-45 | Stars: one star for each value that leaves the spawn window for the first time in a run, from the first 2K tile on. The count is worked out from this run's highest tile and never stored, so Hammer, Undo and loading can never add one twice (128K gives 7 stars). A floor rise that removes no tile still earns its star. Every star move shows the clear notice with the stars earned. | 11.5 |
| D-46 | Free boosters: every 3 stars earn one, with no cap. While one is held, the next booster used is free whatever the score, and other conditions still apply. Cancelling targeting keeps it, Undo never gives one back, unused ones end with the run. The run saves how many were used. | 13.9 |

### 1.1 Sign-off

- Bart approved every rule in this document as recommended at Hard Stop 1 on 2026-10-10.
- **Q1 resolved:** Best Score updates live (D-16 stands).
- Bart added three things to v1 scope: small tiles clear automatically as the game moves up, as in 2248 (D-38 and D-39, replacing D-13); tiles that could join next are highlighted while dragging (D-40); the end of run screen shows this run's highest tile (D-41).
- Not added: a confirm step before Shuffle and Undo.
- D-42 and D-43 settle two gaps found in the Phase 1 design review.
- On 2026-10-13 Bart approved fixing security finding SEC-01 (two touching 2^62 tiles in a hand edited save could never end the run). D-37 now lists every rule at the 64 bit limit, and D-04, D-15, D-25, the 13.1 usability rule and Double's targets follow it. Tests AT-143 and AT-144.
- On 2026-10-13 Bart approved fixing every QA Phase 6 finding. In this document: AT-57 now uses Board P (QA Q1); the run saves the Best Score when it began, for the New best badge (12.3, 15.1, QA6-03, AT-145); and a move shows only once its save has finished (D-33, 15.1, QA6-06, AT-146).
- On 2026-10-13 Bart added three more things to v1 scope: a How to play screen (D-44), stars (D-45) and free boosters (D-46). He also added an About screen in Settings. It holds no game rules, so it has no D number; its acceptance tests are AT-140 to AT-142. D-44 to D-46 go to Bart for review through the DM.

### 1.2 Decisions highlighted for Hard Stop 1

These settled gaps the brief left open and shape how the game feels, so they were pointed out to Bart at Hard Stop 1:

- D-02 (round down): makes progress steadier and the late game tenser than rounding up.
- D-20 (costs scale with the highest tile): a booster costs about the same share of a typical score all run.
- D-27 (Undo after a booster): Undo also reverts any booster used after the last chain, and that booster's cost stays spent. This stops "booster then Undo" from being free.
- A-1 (screen sizes, changed after the design review): full spec (56 dp tiles, 12 dp digits) on 18:9 phones (360 x 720 dp) and taller, nearly every phone sold since about 2018. 16:9 phones still work, with smaller tiles of about 45 to 53 dp and labels scaled to fit.

## 2. Assumptions

| ID | Assumption | Why it matters |
|---|---|---|
| A-1 | Full spec on 18:9 phones (360 x 720 dp) and taller, which is nearly every phone sold since about 2018: tiles at least 56 dp and label digits at least 12 dp tall. 16:9 phones (360 x 640 dp) are still supported with smaller tiles, about 45 to 53 dp depending on the direction and on whether the phone shows on-screen buttons. There, labels follow the same rule scaled to the tile (section 14.1). If the chosen direction misses 56 dp at 18:9, its HUD and booster bar are slimmed in Phase 2. | Number labels (section 14) must be readable at these sizes. |
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
| Window floor | The smallest value in the spawn window: the larger of 16 and H / 64, divided by 8. It is 2 until H reaches 2048, then H / 512. |
| Joinable tile | A tile that would join the chain if the finger moved onto it now (section 6.1). |
| Run highest tile | The highest value that has been on the board at any time during this run (section 11.4). |
| Stars | How many values have left the spawn window for the first time this run, worked out from the run highest tile (section 11.5). |
| Free booster | One booster use that charges nothing. Every 3 stars earn one (section 13.9). |
| Charge | What a booster use takes from the score: its cost (section 13.2), or 0 when a free booster is used. |
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
- On an 18:9 or taller phone 360 dp wide, a tile is at least 56 dp (assumption A-1), above the 48 dp Android touch target, so diagonal drags stay accurate. On 16:9 phones tiles drop to about 45 to 53 dp; the hit radius (D-07) scales with the tile.
- 40 cells hold the full late game spread: four spawn values plus about seven levels of larger tiles up to the highest tile (section 9), with room left to maneuver. Fewer cells would end runs too early. More columns would push tiles under 56 dp.

Rules:

- Every cell holds exactly one tile whenever no move is resolving. Empty cells exist only inside a resolving move (between clearing and spawning).
- Every value is a power of two, 2 or more.

**D-37. Values and score are 64-bit integers with no cap.** Developers must not use floats for values, sums or the score. A run would need billions of moves to get near the 64-bit limit, so no cap rule is needed.

Only a hand edited save can come near the limit, because a save may hold tiles up to 2^62 (section 15.1). No value, sum, cost or score may pass 2^63 minus 1 (9,223,372,036,854,775,807). Each rule at that edge leaves the run able to go on or end:

- A tile that would take the chain's sum past the limit does not join (D-04). A touching equal pair whose sum would pass it is not a valid move (D-15). So two touching 2^62 tiles are not a move.
- A Double on a 2^62 tile is not a valid target (section 13.6).
- A cost that would pass the limit is not affordable, for example Double when B is 2^62. A held free booster still makes it affordable, because it charges 0 (D-46).
- A booster that could do nothing on the current board is not usable, even when affordable or free (section 13.1). On an all 2^62 board only Hammer can act.
- A chain whose points would push the score past the limit is refused and changes nothing. If that blocks every chain on the board, even the smallest touching pair, the score must be at least 2^62. Hammer, Swap and Shuffle (at most 2^62) are then affordable, and each use lowers the score until a chain fits. So the run is never stuck.

Reasoning: the rules model already refuses these moves (docs/ARCHITECTURE.md, the overflow rule). The joining rule, the move check and usability must agree with those refusals. Otherwise a loaded run can sit in a state the rules call playable while nothing can be played. That was security finding SEC-01: two touching 2^62 tiles counted as a move, so the out of moves offer never opened and the run could never end. Bart approved the fix on 2026-10-13.

## 6. Making a chain

### 6.1 Joining rule (D-04)

The chain starts at the first tile the finger is over: the tile under the touch down point, or, if the touch lands in a gap, the first tile the finger then enters. That tile is the chain's first tile (length 1).

As the finger moves, a tile T joins the chain only if all of these hold:

1. T touches the chain's last tile (eight directions).
2. T is not already in the chain.
3. If the chain has 1 tile: T's value equals the last tile's value.
4. If the chain has 2 or more tiles: T's value equals the last tile's value, or is exactly double it.
5. The chain's sum with T added fits in a 64 bit integer (D-37). Only a chain holding tiles of 2^58 or more can fail this (40 tiles of 2^57 still fit), and only a hand edited save holds such tiles.

If any condition fails, nothing happens. The finger may pass over T, and the chain stays as it was. Because a breaking tile can never join, the chain is valid at every moment once it has 2 tiles. The only "invalid chain" the player can lift on is a chain of 1 tile, which cancels with no penalty: board, score and Undo state stay exactly as they were.

Reasoning: refusing a bad tile is easier to read than letting it join and then failing the whole chain on lift. The player never loses a long chain to one slip.

The rules model also checks any chain handed to it before committing. A list of cells is a valid chain if and only if:

- it has 2 or more cells, all different;
- each cell touches the one before it;
- the second value equals the first;
- every later value equals the value before it or is double it;
- the sum of its values fits in a 64 bit integer (D-37).

An invalid list is refused and changes nothing. A valid chain whose points would push the score past the 64 bit limit is refused too (D-37).

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

### 6.7 Joinable highlight (D-40)

While a chain is being dragged, every joinable tile is highlighted, and no other tile. A tile is joinable when the joining rule (6.1) would let it join if the finger moved onto it now:

1. It touches the chain's last tile (eight directions).
2. It is not already in the chain.
3. Chain of 1 tile: its value equals the first tile's value.
4. Chain of 2 or more tiles: its value equals the last tile's value or is exactly double it.

Further rules:

- The set is worked out again every time the chain changes: a tile joins, or a backtrack removes one. Finger movement that changes nothing (passing over a tile that cannot join, or the dead zones of D-07) does not change it.
- Tiles already in the chain are never highlighted as joinable. That includes the tile just before the last one, which a backtrack would return to (D-05). The look of chain tiles is unchanged by this rule.
- After a backtrack, the set comes from the new last tile. The tile that just left the chain is highlighted again if it is joinable from there.
- If no tile is joinable, nothing is highlighted. The player can backtrack or lift.
- No highlight before the first tile is touched, after the finger lifts, in targeting mode, or during the no moves offer.
- The highlight is only a display. It does not change hit testing: a tile still joins only when the finger is within the D-07 radius.
- The player can rely on it both ways: a highlighted tile always joins when the finger reaches it, and a tile that is not highlighted never does.
- How the highlight looks is a design system choice.

Worked examples on Board P (section 19.0):

| # | Chain so far (cells) | Last tile | Highlighted | Why the other touching tiles are not |
|---|---|---|---|---|
| HL1 | (1,6) | 2 | (0,6), (2,6) | The other neighbors are 4, 8 or 32. A double does not count yet at 1 tile. |
| HL2 | (1,6), (2,6) | 2 | (1,5), (3,6) (both 4) | (1,6) is in the chain (it is the backtrack tile). 8, 16 and 32 are more than double. |
| HL3 | (1,6), (2,6), (3,6) | 4 | (2,5), (4,5), (3,7), (4,7) (all 8) | (4,6) = 2 is half. (3,5) = 16 and (2,7) = 32 are too big. |
| HL4 | (1,6), (2,6), (3,6), (2,5) | 8 | (3,5) (16) | Its free neighbors are 2s and 4s. Three neighbors are in the chain. |
| HL5 | (1,6), (2,6), (3,6), (2,5), (3,5) | 16 | none | No free neighbor is 16 or 32. |
| HL6 | backtrack from HL5 onto (2,5) | 8 | (3,5) | Same as HL4: the 16 that just left is joinable again. |
| HL7 | (2,7) | 32 | none | No neighbor is 32. |

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
4. Empty every other cell of the chain. Then small tile clearing (D-38, section 9.4): if this chain raised the window floor, also empty every cell whose value is below the new window floor.
5. Gravity: in each column, tiles move straight down to fill the empty cells below them, keeping their order. The result tile falls too if cells below it were emptied.
6. Spawn: fill every empty cell (section 9). After gravity all empty cells are at the top of their columns.
7. Records: Best Score becomes the larger of Best Score and the score. Best Tile becomes the larger of Best Tile and H. The run highest tile updates here too (D-41), and with it the stars and the free boosters earned (D-45, D-46).
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

### 9.4 Small tile clearing (D-38 and D-39, replacing D-13)

D-13 (small tiles stay) was replaced at Hard Stop 1. Bart asked for small tiles to clear automatically as the game moves up, as in 2248.

**D-38. Trigger and effect.**

- The window floor (section 3) is worked out from the board before a move and again right after the move's result is in place: after the chain's result is placed and its other cells emptied, or after a Double.
- If the floor went up, every tile on the board whose value is below the new floor is removed at once. A big jump can clear several values in one go (example CL3).
- Only a committed chain or a Double triggers it. Undo can also raise H, when it brings back a tile that was hammered after the chain, but Undo never triggers clearing (D-39).
- Cleared tiles score no points (D-18 stands: only chains add points).
- The clear happens inside the move, before gravity (step 4 of section 8). Then gravity, spawns, records, save and the move check run as usual. H does not change during clearing or gravity, so the spawn window for the refill is the new one. New tiles are never below the floor.
- Clearing never removes the result tile or the doubled tile. They are the new H, and after a rise the floor is H / 512.
- The move check runs after the refill, so clearing can create a valid move (CL1, CL2) or leave the board with none.
- The player must see which values were cleared and that they no longer spawn. How this is shown is a design system choice. It is part of the move's animation, so D-35 applies.

**D-39. Interaction with other rules.**

| Rule | What happens |
|---|---|
| Hammer | Never triggers clearing: removing a tile cannot raise H. Hammering the highest tile can lower the floor, so smaller values can spawn again. They clear again when the floor rises again (CL4). |
| Swap, Shuffle | Never trigger clearing. Values do not change. |
| Double | Triggers clearing when it raises the floor, which happens only when it doubles the highest tile past a step. The Double then gets gravity and spawns (CL2). |
| Undo | Never triggers clearing. It restores the snapshot board exactly, so tiles that the undone chain cleared come back (CL5). The restored board's own floor is the floor it had before. |
| Best Tile, run highest tile | Never affected. Cleared tiles are always far below H. |
| Score | Not affected. Cleared tiles add no points and cost nothing. |
| Starting board, loading a saved run | No clearing. Neither is a move that raises the floor. |

In real play the board therefore never holds a tile below the current window floor. After a Hammer lowers the floor, smaller values may spawn again, but they are inside the new window.

**How this compares with 2248.** In 2248, when the player reaches a new top tile, the smallest value on the board is removed, stops spawning, and the board refills. D-38 does the same. Differences, and why:

1. When it happens. 2248 does not document its exact milestones, so we cannot copy them. D-38 ties the clear to our spawn window (D-10), so a value clears at the very moment it stops spawning: each time H doubles from 2048 on. One rule covers both.
2. Points. Cleared tiles score nothing, so the score still counts only the chains the player made (D-18). We do not know for sure whether 2248 awards anything here.
3. Hammer. Our window follows the current board (D-11), so hammering the highest tile lets the smaller value back until the highest tile climbs again. Every rule stays a function of the board alone, so Undo and saving need no extra state.
4. Presentation. The game does not stop for an announcement. The player sees the clear as part of the move.

None of this conflicts with the brief.

Worked examples. Boards D and E are defined in section 19.0.

- **CL1. Clearing creates the only valid move.** Board E with (0,3) = 2, (4,6) = 1024 and (4,7) = 1024. Score 10,000. H = 1024, floor 2. The only valid move is the 1024 pair. The player merges (4,6), (4,7):
  1. Score 12,048. The result 2048 goes on (4,7), and (4,6) is emptied.
  2. H is now 2048, so the floor rises from 2 to 4. The 2 on (0,3) is cleared.
  3. Gravity: column 0 rows 0 to 2 fall one row, and column 4 rows 0 to 5 fall one row.
  4. Spawn (0,0), then (4,0), from 4, 8, 16, 32 (say 8 and 8).
  5. Column 0 now reads 8, 4, 8, 4, 4, 8, 4, 8, so (0,3) and (0,4) are both 4. That is the only valid move. Without the clear, the board would have none.
- **CL2. Clearing after a Double.** Board E with (0,3) = 2 and (2,0) = 1024. Score 5,000. The board has no valid move, so the no moves offer is open. The player uses Double on (2,0):
  1. Cost 2,048, so the score is 2,952. The tile becomes 2048.
  2. The floor rises from 2 to 4 and the 2 on (0,3) is cleared.
  3. Column 0 falls one row and (0,0) refills (say 8).
  4. (0,3) and (0,4) are both 4. The board has a valid move and the offer closes.
- **CL3. Two values at once.** Board D with (0,7), (1,7), (2,7) and (3,7) all 1024. Score 0. H = 1024, floor 2. The player merges the four 1024s (sum 4,096). Result 4096 on (3,7), score 4,096. The floor rises from 2 to 8, so all twelve 2s and all eight 4s of Board D clear. With the three emptied chain cells, 23 cells refill from 8, 16, 32, 64.
- **CL4. Hammer lowers the floor, then a chain raises it again.** Board E with (2,7) = 2048, (4,6) = 1024 and (4,7) = 1024. Score 10,000.
  1. The player hammers the 2048 (cost 2,048, score 7,952). H drops to 1024 and the floor to 2. Column 2 falls one row, and the new tile at (2,0) can be a 2 (say it is).
  2. The player merges the 1024 pair. H is 2048 again and the floor rises to 4, so the 2 on (2,0) clears. Score 10,000.
- **CL5. Undo after a clear.** Right after CL1, the player uses Undo. Cost 1,024 (B = 2048). The board returns to the CL1 setup, including the 2 on (0,3). Score 12,048 minus 2,048 minus 1,024 = 8,976.

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

Bart confirmed the live rule at Hard Stop 1 (Q1). The table compares it with the alternative he considered, where Best Score updates only when a run ends, from the final score.

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

### 11.4 This run's highest tile (D-41)

- The run highest tile is the highest value that has been on the board at any time during this run, from any source: starting board, spawn, merge or Double.
- It is set from the starting board when a run begins. After that it is updated at the same moments as Best Tile (step 7 of section 8, after every resolved move): if H is higher, it becomes H.
- It never goes down. Hammer (even on the highest tile) and Undo do not lower it. Small tile clearing never touches it (D-39).
- It belongs to the run. It is saved with the run (section 15.1), restored on resume, and replaced when a new run starts. Best Tile is always at least as high.
- The end of run screen shows it (section 12.3). Showing it anywhere else is not required.

Reasoning: it uses the same rule as Best Tile, limited to one run, so the player sees how far this run got even after a Hammer or an Undo took the tile away.

| # | Situation | Run highest tile after | Best Tile after (was 8192) |
|---|---|---|---|
| RH1 | A new run starts. The starting board's highest tile is 16. | 16 | 8192 |
| RH2 | Merges make a 2048. | 2048 | 8192 |
| RH3 | Double turns the 2048 into 4096. | 4096 | 8192 |
| RH4 | The player hammers the 4096. H drops to 1024. | 4096 | 8192 |
| RH5 | Later a chain makes 16384, then the player uses Undo. | 16384 | 16384 |
| RH6 | The run ends. The end of run screen shows final score, Best Score, Best Tile 16K and run highest tile 16K. | 16384 | 16384 |
| RH7 | New game. The new starting board's highest tile is 8. | 8 | 16384 |

### 11.5 Stars (D-45)

Bart's request (2026-10-13): a star each time a low number is removed for the first time in a run. Hammer and Undo can never earn a star twice. The HUD shows the stars.

**D-45. The star count.**

- A value leaves the spawn window when the window floor rises above it (D-38). From the first 2K tile on, each doubling of the highest tile moves the floor up one step, so one more value leaves: 2 at 2K, 4 at 4K, 8 at 8K, and so on.
- Stars = how many times the window floor of the run highest tile has doubled above its starting value of 2. With the values in section 18: 0 while the run highest tile is 1024 or less, otherwise log2(run highest tile) minus 10.
- The count depends on the run highest tile alone (D-41). It is worked out whenever it is needed and never stored.

| Run highest tile | Its window floor | Stars | Free boosters earned (D-46) |
|---|---|---|---|
| 1024 or less | 2 | 0 | 0 |
| 2048 (2K) | 4 | 1 | 0 |
| 4096 (4K) | 8 | 2 | 0 |
| 8192 (8K) | 16 | 3 | 1 |
| 16384 (16K) | 32 | 4 | 1 |
| 32768 (32K) | 64 | 5 | 1 |
| 65536 (64K) | 128 | 6 | 2 |
| 131072 (128K) | 256 | 7 | 2 |
| 262144 (256K) | 512 | 8 | 2 |
| 524288 (512K) | 1024 | 9 | 3 |
| 1048576 (1M) | 2048 | 10 | 3 |
| 2^62 (the largest value a save can hold) | 2^53 | 52 | 17 |

**When a star is earned.**

- A move earns stars when it raises the run highest tile far enough that the count goes up. The stars earned by that move are the count after it minus the count before it. This is worked out at step 7 of section 8, with the other records.
- Only a committed chain or a Double can do this:
  - A spawn is never above the larger of 16 and H / 64, so it can never add a star.
  - Hammer only removes a tile. Swap and Shuffle keep every value.
  - Undo restores a board from earlier in the run, so it never holds a tile above the run highest tile (the save check in 15.1 holds this for loaded runs too).
- A move that earns a star always raises the window floor, because the new floor is above the floor of every earlier board in the run. So a star always comes with that move's D-38 clear: the moment a low number is removed, as Bart described.

**Every case.**

| Case | Stars | Why |
|---|---|---|
| Two values at once (CL3: four 1024s make 4096) | 2 in one move | The floor jumps from 2 to 8, so 2 and 4 both leave. |
| Hammer lowers the floor, then a chain raises it again (CL4) | No new star | Hammer never lowers the run highest tile, so the count stays. The chain only brings H back to a level the run already had. It still clears small tiles and shows the clear notice, without a star. |
| Undo after a chain that earned a star (CL5) | The star stays | Undo never lowers the run highest tile (D-29, D-41). Making the same chain again earns nothing. |
| A Double that raises the floor (CL2, DB2) | 1 | The doubled tile is the new run highest tile. A Double raises it one step at most. |
| The starting board | 0 | Its highest tile is 16 at most. |
| Loading a saved run | No new star | The count comes from the saved run highest tile. Loading is not a move, so nothing is earned and no notice shows. |
| A floor rise that removes no tile | 1 all the same | See below. |
| A new run highest tile of 1024 or less | 0 | The floor stays 2 until the first 2K. |

**A floor rise that removes no tile still earns its star.** Sometimes the board holds no tile of the value that leaves the window (example SC7). The star is earned all the same:

1. The value is gone from the game either way: it no longer spawns. That is what the star marks.
2. Missing a star because the board happened to hold none of that value would feel random, and the player could not see why.
3. The count stays a function of the run highest tile, so it needs no saved state of its own and cannot be gamed.

**The star moment: what the player sees.**

- A move that earns at least one star always shows the clear notice (AT-104), even when it removed no tile.
- The notice names every value that left the spawn window in that move: each value from the floor before the move up to half the new floor. For CL3 that is 2 and 4 ("No more 2s or 4s"). For SC7 it is 2, although no 2 was on the board. It also shows how many stars the move earned.
- A move that clears small tiles but earns no star (CL4, or a chain made again after an Undo) shows the notice with the same values rule and no star.
- A move that raised the floor but removed no tile and earned no star shows no notice. This can only happen after a Hammer or an Undo lowered the floor.
- The HUD shows this run's star count during play, in every skin. It shows the new count by the time input reopens after the move (D-35). Neither the notice nor the count ever holds input.
- No sound (the brief allows only the click), no pause and no extra screen.
- How the stars and the notice look is a design system choice.

**Reasoning: the count comes from the run highest tile.** The DM suggested this. I checked it and adopted it:

- The run highest tile never goes down. Hammer and Undo cannot lower it (D-41), so no level can be counted twice.
- It only rises through a chain or a Double, the same two moves that trigger clearing (D-38). A star and a clear always come together.
- It is already saved with the run and checked on load. Stars need no new saved field, cannot drift from the board, and a reopened run shows the same stars.
- Counting stars as events and saving the count would give the same numbers in every case above, but needs one more saved value and one more check.

**Worked examples.** Boards D and E are in section 19.0, and CL1 to CL5 in section 9.4.

| # | Situation | Run highest tile | Stars | Notice |
|---|---|---|---|---|
| SC1 | A new run starts. Its highest tile is 16 at most. | 16 at most | 0 | none |
| SC2 | CL1: the 1024 pair makes the first 2048 and clears the 2 on (0,3). | 1024, then 2048 | 0, then 1 | "No more 2s", one star |
| SC3 | CL3: four 1024s make 4096. | 1024, then 4096 | 0, then 2 | "No more 2s or 4s", two stars |
| SC4 | CL4 step 1: Hammer on the 2048. H drops to 1024. | 2048, stays 2048 | 1, stays 1 | none |
| SC5 | CL4 step 2: the 1024 pair makes 2048 again and clears the 2 on (2,0). | stays 2048 | stays 1 | "No more 2s", no star |
| SC6 | CL5: Undo right after CL1, then the same chain again. | stays 2048 | stays 1 | The Undo: none. The chain: "No more 2s", no star |
| SC7 | Board E with (4,6) = 1024 and (4,7) = 1024. Board E has no 2s. The pair makes 2048 and clears nothing. | 1024, then 2048 | 0, then 1 | "No more 2s", one star |
| SC8 | CL2: Double on the 1024 makes 2048 and clears the 2. | 1024, then 2048 | 0, then 1 | "No more 2s", one star |
| SC9 | A 512 pair makes the run's first 1024. | 512, then 1024 | 0 | none |
| SC10 | The app reopens a saved run whose run highest tile is 131072. | 131072 | 7 on load | none |

**Bart's phone run** reached a highest tile of 131072 (128K). Under D-45 that gives 7 stars:

| Run highest tile reached | 2K | 4K | 8K | 16K | 32K | 64K | 128K |
|---|---|---|---|---|---|---|---|
| Value that left the window | 2 | 4 | 8 | 16 | 32 | 64 | 128 |
| Stars | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
| Free boosters earned (D-46) | 0 | 0 | 1 | 1 | 1 | 2 | 2 |

The next star would have come at 256K. The third free booster would have come at 512K (9 stars).

## 12. Game over

### 12.1 What counts as a valid move (D-15)

A board has a valid move if and only if two touching tiles (eight directions) have the same value, and their sum fits in a 64 bit integer (D-37). The sum of two equal tiles of value v fits when v is 2^61 or less, so only a pair of 2^62 tiles fails, and only a hand edited save can hold one.

Reason: every valid chain starts with two touching equal tiles, and any two such tiles whose sum fits are already a valid chain. A longer chain from the same pair has a larger sum, so if the pair does not fit, no chain from it does. So the move check never needs to search for longer chains. Checking each cell against its right, lower left, lower and lower right neighbors covers every touching pair once. The fit test is the one the rules model already applies before committing (6.1). Without it, two touching 2^62 tiles counted as a move that could never be committed, so the offer never opened and the run could never end (SEC-01).

| # | Board | Valid move? |
|---|---|---|
| V1 | Board D (section 19) | No |
| V2 | Board D with (2,0) changed to 4 | Yes: (1,0) and (2,0) are both 4, side by side |
| V3 | Board D with (1,1) changed to 2 | Yes: (0,0) and (1,1) are both 2, diagonal |
| V4 | Board D with (0,0) changed to 8 | Yes: (0,0) and (0,1) are both 8, one above the other |
| V5 | Board D with (0,0) and (2,0) changed to 4096 | No: the two 4096 tiles are two cells apart |
| V6 | Board D with (0,7) and (1,7) changed to 2^62 | No: they touch, but 2^62 + 2^62 = 2^63 does not fit (SEC-01) |
| V7 | Board D with (0,7) and (1,7) changed to 2^61 | Yes: 2^61 + 2^61 = 2^62 fits |

### 12.2 The no moves offer (D-19)

When the move check after a move, or after loading a saved run, finds no valid move:

1. Chain input stops. The board stays visible so the player can judge which booster would help.
2. The game works out which boosters are usable now. A booster is usable when it is affordable and could act on this board (section 13.1). Undo also needs a snapshot (section 13.7). A held free booster makes every booster affordable (D-46). Hammer can always act, so while a free booster is held the run never ends at once.
3. If none is usable, the run ends at once (12.3). The player sees that it ended because no moves were left.
4. Otherwise the player sees: that no moves are left; every booster with its cost, usable ones enabled and the rest visibly disabled; the suggested rescue marked (D-42, below); and an End run choice.
5. Choosing Shuffle or Undo applies it at once. Choosing Hammer, Swap or Double enters targeting on the board. Cancelling targeting (tapping the booster again) returns to the offer with nothing charged.
6. After any booster resolves, the move check runs again. If a valid move exists, play goes on normally. If not, the offer opens again with costs and usability worked out afresh.
7. End run ends the run.

The offer has no time limit. The run never ends without the player choosing End run, unless nothing is usable.

The offer cannot repeat forever. End run is always there. Every booster it allows does something to the board (13.1), and every use either lowers the score by at least 64 or spends a free booster. Only chains raise the score, and a booster earns at most one star (a Double on the highest tile), a third of a free booster. So a run of boosters with no chain in between always runs out.

Which boosters can rescue:

| Booster | Can it make a valid move? |
|---|---|
| Shuffle | Always, while two tiles share a value whose pair fits (D-15, section 13.5). This is why it is the suggested rescue: it needs no planning at a tense moment. |
| Swap | Yes, whenever two tiles share a value whose pair fits (2^61 or less): swap one of them next to the other. Needs the player to spot it. |
| Undo | Yes: the board before the last chain had a valid move, the chain itself. |
| Double | If some tile touches a tile of double its value and that pair fits (doubling a 2^61 next to a 2^62 makes no move). Or if doubling the highest tile raises the window floor, and the clear and refill make a pair (D-38, example CL2). |
| Hammer | Sometimes, through the fall and the new tile. Not guaranteed. |

All usable boosters are offered, because the brief says any booster the player can still afford. The game does not judge whether a choice will help. It only leaves out a booster that could do nothing at all (13.1), which only happens on a hand edited board.

**D-42. The suggested rescue.** The offer marks at most one booster as the suggested rescue:

1. Shuffle, if it is usable.
2. Otherwise Undo, if it is usable.
3. Otherwise none. Any other usable booster is still offered, just not marked.

Reasoning: these are the two rescues that always produce a valid move without the player having to plan anything. Shuffle comes first because it keeps the last chain's points. With the costs in section 13.2, Shuffle is unusable only when the score is below B and no free booster is held (D-46). Hammer and Swap (B) and Double (2B) are then unusable too, so Undo (B / 2) is the only booster that can still be offered, and case 3 means the run ends at once. Case 3 only matters if the costs are retuned, or on a hand edited board where every tile is equal: there Shuffle cannot act (13.1), Hammer may still be usable, and nothing is marked (AT-144).

| # | Usable boosters | Marked |
|---|---|---|
| SR1 | All five (GO1) | Shuffle |
| SR2 | Undo only (GO2) | Undo |
| SR3 | Hammer, Swap, Shuffle (GO4, no Undo snapshot) | Shuffle |
| SR4 | None (GO3) | No offer, the run ends |

### 12.3 When the run ends

- The saved run is deleted. Best Score and Best Tile are already up to date and stay saved.
- The end of run screen shows the final score, Best Score, Best Tile, this run's highest tile (D-41) and New game.
- It also shows the New best badge when this run set a new Best Score: the Best Score now is higher than the Best Score when this run began. The run saves that starting value (section 15.1), so closing and reopening the app mid run does not lose the badge. A run whose score only equalled the old record gets no badge.
- Nothing more can be done with that run.

### 12.4 Worked examples

All examples have H = 1024, so B = 1024. Costs: Hammer 1,024, Swap 1,024, Shuffle 1,024, Double 2,048, Undo 512. No free booster is held in any of them. With one held, GO3 and GO6 would open the offer instead (example FB8).

| # | Situation | What the player sees and does | Result |
|---|---|---|---|
| GO1 | Score 5,000. Last chain gave 40 points. No moves. | All five usable. Shuffle marked as the suggested rescue. Taps Shuffle. | Score 3,976. Board has a valid move. Play goes on. |
| GO2 | Score 600. Last chain gave 40 points. No moves. | Hammer, Swap, Shuffle and Double disabled. Undo usable (600 minus 40 is 560, at least 512) and marked as the suggested rescue (D-42). Taps Undo. | Board from before the last chain. Score 600 minus 40 minus 512 = 48. Play goes on. |
| GO3 | Score 300. Last chain gave 40 points. No moves. | Nothing usable (300 minus 40 is 260, below 512). | Run ends at once. Final score 300. |
| GO4 | Score 1,500. No Undo snapshot (Undo was just used). No moves. | Hammer, Swap, Shuffle usable. Double and Undo disabled. Picks Hammer, then taps Hammer again. | Back at the offer. Score still 1,500. |
| GO5 | Same as GO4, after the cancel. | Picks Swap, then taps a 32 and a 4 that touches another 32. | The two 32s now touch. Score 476. Play goes on. |
| GO6 | Same as GO4, but the player hammers a 4 and the board still has no move. | Offer opens again. Every cost is at least 512, score is 476. | Nothing usable, so the run ends at once. Final score 476. |
| GO7 | The app is closed while the offer is open. | On reopening, the run loads, the move check finds no move. | The offer opens again, unchanged. |

## 13. Boosters

### 13.1 General rules (D-21, D-22, D-43)

- Each booster always shows its current cost, or Free while a free booster is held (D-46).
- A booster is usable when it is affordable: the score is at least its cost, or a free booster is held (D-46). Undo has its own check (13.7). A booster that is not usable is visibly disabled, and tapping it does nothing.
- A booster must also be able to act on the current board. Swap and Shuffle need two tiles of different value: otherwise Swap has no legal pair (D-24) and every arrangement is the same board. Double needs a tile of 2^61 or less (13.6). Hammer can always act. Every real board passes this; only a hand edited board, such as all 40 tiles at 2^62, can fail it (D-37). Reason: a booster the player can tap always does something, and a free booster is never spent on nothing.
- The cost is read from the board at the moment of use (D-21). It is charged in the same step as the effect, never before. A free booster charges 0 instead (D-46).
- Boosters can be used any time during play when no chain is being dragged and no move is still finishing on screen (D-35), and during the no moves offer.
- Shuffle and Undo have no target. Tapping them applies them at once.
- Hammer and Double need one tile. Swap needs two tiles. Tapping one of them enters targeting mode:
  - Nothing is charged. The player sees which booster is active.
  - While targeting, dragging does not build a chain. A tap on a tile (finger down and up on the same tile) picks it as a target. A drag that ends on a different tile picks nothing.
  - D-43: the effect applies on the tap itself, when the finger lifts. Hammer and Double act on their one tap. Swap acts on the tap of its second tile. There is no select then confirm step.
  - Swap's first tile is the only selection state in targeting. It stays selected until the second tile is tapped, the selected tile is tapped again, or targeting is cancelled (13.4).
  - While a finger is down on a tile in targeting mode, the tile may be highlighted as press feedback. It means only "this is the tile under your finger". Lifting on that tile applies the booster. Lifting anywhere else does nothing.
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

The Undo snapshot is not changed (13.7). Hammer never triggers small tile clearing, because removing a tile cannot raise H (D-39).

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

Fallback: read the cells in reading order (row 0 left to right, then row 1, and so on). Find the first cell P whose value is 2^61 or less (so its pair fits, D-15) and appears again later in reading order, and let Q be the first later cell with that value. Swap the tile in Q with the tile in the cell to the right of P, or, if P is in column 4, the cell below P. P and its twin now touch. (That neighbor cell is never Q itself, because then the board would already have had a valid move. When P is in column 4, a cell below it always exists: P has a later twin, so P cannot be the last cell, (4,7).)

Reasoning: a paid rescue must not fail by bad luck. With only one equal pair on the board (the worst real case), a random arrangement puts it touching about 16 percent of the time (123 touching cell pairs out of 780), so 100 straight failures happen about 3 times in 100 million. The fallback makes the guarantee exact and testable.

If no two tiles share a value of 2^61 or less, no arrangement can help. Shuffle still runs and is charged, then the move check follows. This needs 40 different values (so a tile of at least 2^40), or equal values only at 2^62, both far beyond any real run. Shuffle is not blocked for it, as long as it can change the board: on a board where every tile is equal it is not usable (13.1).

Worked examples:

- SH1: score 20,000, H = 4096. Shuffle costs 4,096. Score 15,904. Same 40 values, new places, at least one valid move.
- SH2: a test forces every arrangement to come out as Board D. Fallback: P = (0,0) (value 2), Q = (2,0) (the next 2 in reading order). Swap Q with the cell right of P, (1,0), which holds 4. Now (1,0) = 2 and (2,0) = 4. Cells (0,0) and (1,0) are both 2 and touch.

### 13.6 Double (D-26)

Target: any one tile, including the highest, whose doubled value fits in a 64 bit integer (2^61 or less, D-37). A 2^62 tile is not a target: tapping it does nothing, nothing is charged, no free booster is used and Double stays active, as with Swap's equal value tap (D-24). A forced call to the rules model is refused. When no tile on the board is a target, Double is not usable (13.1).

Effect, in order:

1. Charge 2 x B.
2. The tile's value doubles in place. No points.
3. Small tile clearing (D-38): if the Double raised the window floor, empty every cell whose value is below the new floor. This can only happen when the doubled tile becomes the new H.
4. Only if step 3 emptied cells: gravity and spawn, as steps 5 and 6 of section 8. Otherwise nothing moves and nothing spawns.
5. Records (Best Tile and the run highest tile can rise), save and move check, as steps 7 to 9 of section 8.

Worked examples:

- DB1: score 30,000, H = 4096. Double a 16 that touches a 32. Cost 8,192. Score 21,808. The two 32s now touch.
- DB2: score 30,000, H = 4096. Double the 4096. Cost 8,192 (read before the effect). Score 21,808. H is now 8192, so every price doubles right after. Best Tile becomes 8192 if it was lower. The window floor rises from 8 to 16, so every 8 on the board clears and the board refills from 16, 32, 64, 128 (D-38). If 4096 was the run highest tile, this is the run's third star, so one free booster is now held for the next booster (D-45, D-46). The Double itself was paid.
- DB3: CL2 in section 9.4. A Double on the highest tile clears a 2, and the refill creates the only valid move.

### 13.7 Undo (D-27, D-28, D-29)

Snapshot: every committed chain stores the board from just before it and its points (step 1 of section 8). There is only ever one snapshot.

Undo is usable when both hold:

- a snapshot exists, and
- score minus the snapshot's points is at least the Undo cost (B / 2, from the current board, or 0 while a free booster is held, D-46).

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
- Best Score, Best Tile and the run highest tile are not lowered.
- Undo never triggers small tile clearing. Tiles that the undone chain cleared come back, because they are part of the snapshot board (D-39, example CL5).

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
- Chains only add points. A booster runs only when usable, and then the new score is the old score minus its charge (the cost, or 0 for a free booster), which is zero or more. For Undo, D-28 gives the same guarantee, free or not.
- The rules model itself must refuse a booster that is not usable: it returns a failure and changes nothing, even if the screen asks for it. It never clamps a negative score to zero, because clamping would hide a bug.

| # | Situation | Result |
|---|---|---|
| Z1 | Score 100, Hammer costs 128. | Hammer disabled. A forced call to the rules model is refused. Score stays 100, board unchanged. |
| Z2 | Score 128, Hammer costs 128. | Hammer usable. After use the score is 0, and every booster is disabled (the cheapest possible cost is 64). |
| Z3 | Score 0 and no moves. | Nothing usable. The run ends at once. |
| Z4 | Undo in U5. | Refused. It would have left minus 34. |

Z1 to Z4 assume no free booster is held. With one held, Z1 to Z3 change (D-46): Hammer is usable and free at any score, and in Z3 the offer opens with Shuffle marked. Z4 does not change: a free Undo is still refused when the score is below the chain's points (FB4).

### 13.9 Free boosters (D-46)

Bart's request (2026-10-13): every 3 stars give one free booster. The player's next booster costs nothing.

**D-46. Free boosters.**

**Earning and holding.**

- Free boosters earned = stars (D-45) divided by 3, rounded down. The 3 is STARS_PER_FREE_BOOSTER (section 18). The first comes at 3 stars (run highest tile 8K), then 6 (64K), 9 (512K), and so on.
- Free boosters held = earned minus used. "Used" counts the free boosters spent this run. It only ever goes up, and the run saves it.
- There is no cap. Any number can be held.
- A free booster is earned at step 7 of section 8, in the move that earns the third star (or sixth, and so on). The move check right after already counts it. So a chain that earns a free booster and leaves no valid move opens the offer with every booster free.

**How a free booster is used: automatically, on the next booster.**

- Whenever a booster's effect applies while at least one free booster is held, that use charges 0 instead of its cost, and exactly one free booster is used.
- This applies to every booster, Undo included, and whatever the score. A player who could pay still gets it free. There is no way to save it for later or to pay instead.
- A booster that earns a free booster is charged as normal. Example: a Double that makes the third star is paid, and the new free booster goes to the next booster (DB2, FB9).

Reasoning: Bart's own words are "the player's next booster costs nothing", and this is the plain reading. It is also the easiest to understand: while the bar says Free, the next booster is free. Letting the player choose would need an extra control on every booster and a new state to explain and save. The cost of the automatic rule is small: a player who wants the free booster for a Double just makes the Double their next booster.

**Affordability.**

- While a free booster is held, every booster counts as affordable.
- Every other condition still applies:
  - Undo needs a snapshot, and the score minus the snapshot's points must be at least the Undo cost, which is now 0 (D-28). So a free Undo is refused when boosters since the chain have taken the score below that chain's points. Otherwise the score would go below zero (FB4).
  - The booster must be able to act on this board (13.1), and Hammer, Swap and Double still need valid targets (D-24, 13.6).
  - Boosters still cannot be used during a drag or while a move is finishing on screen (D-08, D-35).
- A refused call uses nothing and changes nothing.

**Targeting and cancel.** Entering targeting uses nothing. The free booster is used only when the effect applies: the Hammer or Double tap, or Swap's second tile (D-21, D-43). Cancelling (tapping the booster again, Android back, pause, focus loss, closing the app) and switching to another booster keep it. So does selecting and deselecting Swap's first tile.

**Undo.**

- A free booster used on any booster stays used, Undo included. Undo never gives one back, just as "the Undo cost stays spent" (D-27).
- Undoing the chain that earned a free booster does not take it back, because the stars stay (D-45). If that Undo is the next booster, it is the Undo that uses the free booster (FB6).
- The count of free boosters used is not part of the Undo snapshot.

**The out of moves offer (D-19, D-42).**

- While a free booster is held, every booster is affordable. Undo still needs its own checks, and each booster must be able to act on this board (13.1).
- Hammer can always act, so the run never ends at once. On a real board Shuffle can always act too, so it is the marked rescue.
- Every use spends a free booster and End run is always there, so the offer can never repeat forever (12.2). On an all 2^62 board only Hammer is usable (AT-144).
- The buy button reads "Shuffle for free" in place of "Shuffle for 4K".

**What the player sees.**

- While at least one free booster is held, every booster's cost reads "Free" (4 characters, like the longest cost label). Disabled boosters read Free too and stay visibly disabled, for example Undo with no snapshot.
- The player can see how many free boosters are held whenever there is at least one. Where and how is a design system choice, as is the star display.
- When the last one is used, the costs come back at once.

**End of the run.** Unused free boosters end with the run, like the stars. Nothing carries over: a new run starts with 0 stars and 0 free boosters, and New game during a run (D-34) discards them too.

**Score and records.** A free booster charges 0, so the score does not change, and it adds no points (D-18). Best Score is never changed by it. Best Tile and the run highest tile follow the booster's own effect exactly as when paid: a free Double on the highest tile raises them (FB10).

**Saving.** The run file keeps one more number: the free boosters used this run, a whole number from 0 up to the free boosters earned. Stars, free boosters earned and free boosters held are worked out from it and the run highest tile on load (section 15.1). Reopening a run therefore shows the same stars and the same free boosters.

**Balance.** A free booster is worth one booster's cost at the moment it is used. The costs and typical scores come from sections 13.2 and 17.

| Stage | H | Stars | Free boosters earned | Free Hammer, Swap or Shuffle worth | Free Double worth | Free Undo worth | Typical score |
|---|---|---|---|---|---|---|---|
| First minutes | 32 | 0 | 0 | none yet | none yet | none yet | about 200 |
| Early | 256 | 0 | 0 | none yet | none yet | none yet | about 3,500 |
| Mid | 4096 (4K) | 2 | 0 | none yet (the first comes at 8K) | none yet | none yet | about 75,000 |
| First free booster | 8192 (8K) | 3 | 1 | 8,192 (8K) | 16,384 (16K) | 4,096 (4K) | about 150,000 |
| Second | 65536 (64K) | 6 | 2 | 65,536 (64K) | 131,072 (128K) | 32,768 (32K) | about 1,200,000 |
| Late (Bart's run) | 131072 (128K) | 7 | 2 | 131,072 (128K) | 262,144 (256K) | 65,536 (64K) | about 2,400,000 |
| Third | 524288 (512K) | 9 | 3 | 524,288 (512K) | 1,048,576 (1M) | 262,144 (256K) | about 9,600,000 |

Typical scores from 8K on use section 17's late game rule, about 18.3 times H.

What that means:

- In moves of income (late game, about H / 10 per move, section 17), a free Hammer, Swap or Shuffle saves about 10 moves, a free Double about 20 and a free Undo about 5.
- Between two free boosters H grows eightfold, which takes about 570 moves (about 190 per doubling) and earns about 128 times H in points (18.3 x 8H minus 18.3 x H). A free booster used at the price it had when earned is then a small share of that income: about 0.4 percent as Undo, 0.8 percent as Hammer, Swap or Shuffle, and 1.6 percent as Double. It is a real reward but does not change the economy.
- Its biggest value is as a sure rescue: while one is held, the run cannot end at once, whatever the score.
- It cannot pay for itself. A free Double on the highest tile adds at most one star, and a free booster needs three.
- With one per 2 stars, the first would come at 4K. H would grow fourfold between two of them, about 55 times H of income, so each would be about 0.9 to 3.6 percent of it. Either rate is safe for the economy. The difference is only how often the reward comes, so Bart's choice of 3 stands: it keeps a free booster a rarer event, and a player who reaches 8K gets the first one.

**Worked examples.** The default setup notes in section 19 apply: the run highest tile equals the board's highest tile unless stated.

| # | Situation | Result |
|---|---|---|
| FB1 | Board D with (0,7) = 4096 and (1,7) = 4096. Score 50,000. Run highest tile 4096, so 2 stars and nothing held. The player commits the pair. | 8192 on (1,7). Score 58,192. 3 stars, 1 free booster held. Every booster reads Free. |
| FB2 | Right after FB1, Hammer on (4,0). Then Hammer on (4,0) again. | The first Hammer is free: score 58,192, nothing held, and the costs show again (Hammer 8K). The second is charged 8,192: score 50,000. |
| FB3 | Board P, score 0, run highest tile 8192, no free booster used yet (1 held), no snapshot. | Hammer, Swap, Shuffle and Double are usable and read Free. Undo reads Free but is disabled (no snapshot). A Double on (0,0) makes it 4, score stays 0, nothing held, and all five are disabled. |
| FB4 | Board D with (2,0) = 4096, (1,7) = 8 and (2,7) = 16. Score 8,160. The player commits 8, 8, 16 (+32, score 8,192), then Doubles the 4096 (cost 8,192, score 0). | The Double makes the third star: 1 free booster held. Undo would be free, but 0 minus the chain's 32 points is below zero, so Undo is disabled and a call to it is refused. Hammer, Swap, Shuffle and Double are usable for free. |
| FB5 | Board P, score 5,000, run highest tile 8192, 1 free booster held. The player taps Hammer, taps it again; taps Swap, taps (0,0), taps Swap; taps Double, then Hammer, then presses back. | Nothing is used: still 1 held, score 5,000. A Shuffle then is free: score 5,000, nothing held, and Hammer costs 128 again. |
| FB6 | Right after FB1, the player uses Undo. | Undo is free: the board goes back to the FB1 setup and the score to 50,000. The run highest tile stays 8192, so 3 stars stay, and the free booster stays used: nothing held. Making the same chain again gives score 58,192, still 3 stars, no new free booster. |
| FB7 | Board D with (0,7) = 32768 and (1,7) = 32768. Score 1,000,000. Run highest tile 32768 (5 stars, 1 earned, none used, so 1 held). The player commits the pair, then uses Shuffle, then Double on a tile other than the 65536, then Hammer on a tile other than the 65536. | After the chain: score 1,065,536, 6 stars, 2 held. Shuffle and Double are free: score 1,065,536, nothing held. Hammer is charged 65,536: score 1,000,000. |
| FB8 | Board D1024 (no valid move), score 0, no snapshot, run highest tile 8192, 1 free booster held. | The offer opens instead of ending the run. Hammer, Swap, Shuffle and Double are usable, Undo is disabled, Shuffle is marked and the button reads "Shuffle for free". After the Shuffle: score 0, a valid move, nothing held. |
| FB9 | Board D with (2,0) = 4096. Score 30,000. Run highest tile 4096, nothing held. Double on (2,0), then Shuffle. | The Double is paid: score 21,808. It makes the third star, so 1 is held. The Shuffle is free: score 21,808, nothing held. |
| FB10 | Board D with (2,0) = 8192. Score 1,000, Best Score 1,000, Best Tile 8192. Run highest tile 8192, 1 held. Double on (2,0). | Free: score and Best Score stay 1,000. The tile becomes 16384, so Best Tile and the run highest tile become 16384 (4 stars). Nothing held. |
| FB11 | The offer is open with 1 free booster held. The player taps End run, then New game. | The free booster is lost with the run. The new run has 0 stars and 0 free boosters, and Hammer costs 128. |
| FB12 | Bart's phone run: run highest tile 131072, 7 stars. | Under D-46 that run earns 2 free boosters, at 8K and at 64K. Each goes to the first booster used after it is earned. One still held when the run ends is lost with it. |

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

Readability requirement (assumption A-1): on 18:9 phones (360 x 720 dp) and taller, tiles are at least 56 dp, and a 4 character label sits fully inside the tile with no clipping, with digits at least 12 dp tall. On 16:9 phones, where tiles are smaller (about 45 to 53 dp), the label still sits fully inside the tile with no clipping, and its digits keep the same share of the tile side (12 / 56, about 21 percent, so about 10 dp on a 47 dp tile). The design system picks the text sizes. It may use smaller text for 4 character labels than for shorter ones, but never below these minimums. QA checks both screen shapes.

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
| Current run | Until the run ends or a new game replaces it | The 40 tile values, the score, the run highest tile (D-41), the free boosters used this run (D-46), the Best Score when this run began (for the New best badge, 12.3), and the Undo snapshot (40 values and the chain's points) or none. Stars and free boosters held are not saved: they are worked out from the run highest tile and the free boosters used. |
| Settings | Always | Sound on or off (default on), selected skin (default: the approved direction) |
| Records | Always | Best Score, Best Tile |

Not saved: a drag in progress, targeting mode and a Swap selection, the no moves offer (worked out again on load), the random generator state (9.5) and animations.

When the run is saved:

- As soon as each move resolves in the rules model, before any of it shows on screen.
- When a new run's starting board is made.
- When the app is paused, loses focus or is closed.

The board starts showing a move only once its save has finished. That takes at most a few frames (25 ms at most in QA's measurements), too short to notice. Until then the board, score and booster bar look exactly as they did at the lift or tap. The chain line and the commit click may stay as they are, because neither shows the result. So the player never sees a result that was not saved, a spawn included. A kill or close at any moment reopens either the run before the move, with nothing of it ever shown, or the run after it. Closing the app during an animation therefore cannot undo or reroll a move. If a save fails, the move shows anyway, so the game never freezes.

On load: show the saved board and score exactly, update the records (step 7 of section 8), then run the move check. If there is no valid move, open the no moves offer (12.2). The stars and free boosters held come from the saved run highest tile and free boosters used. Loading earns no star and shows no clear notice (D-45).

What a valid saved run looks like, for the save code's validation: exactly 40 values, each a power of two from 2 to 2^62; a score of 0 or more; a run highest tile that is a power of two and at least the highest value on the saved board and on the snapshot board; free boosters used, a whole number from 0 up to the free boosters earned from that run highest tile (D-46); a Best Score when the run began of 0 or more (not checked against the records, which live in another file); an Undo snapshot that is either none or 40 values of the same kind plus points of 4 or more. A run saved before D-46 existed has no count of free boosters used: it loads as 0 used, so its stars and free boosters appear on load, with no notice. A run saved before the starting Best Score existed takes the Best Score loaded with it instead. Its New best badge then shows only if the run beats the record again after reopening, which is the old behaviour. Best Score is 0 or more. Best Tile is 0 or a power of two. If the saved run fails validation, it is discarded and a new run starts. Valid settings and records are kept.

### 15.2 New game during a run (D-34)

Starting a new game while a run is in progress asks the player to confirm. On confirm, the saved run is discarded and a new run starts. The discarded run's score already counted toward Best Score (D-16).

### 15.3 One move at a time (D-35)

After a move resolves, a new chain or booster tap is accepted only when that move's animation has finished. The short wait for its save before the animation starts (15.1) is part of the move. Input in the meantime is ignored, not queued. The player always acts on the board they can see. This rule does not set how long animations are; the design system keeps them short.

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

Effect of small tile clearing (D-38): almost none on scores, so the table and the booster prices stand.

- Each time H doubles to a new value, the tiles of the old window floor clear. Their value is H / 1024 each.
- A board typically holds a handful of them, say up to 10, so at most about 10 x H / 1024, roughly H / 100, of value is removed.
- That value would have earned about H / 100 x 7.62, roughly 0.08 x H, in later merges.
- Going from H / 2 to H earns about 18.3 x H / 2, roughly 9.2 x H. So the loss is under 1 percent of income.

The real effect is on survival: stray small tiles no longer clog the board, so long runs last longer. If playtests show runs that practically never end, raise the costs in section 18.

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
| SMALLEST_TILE_DP | 56 | Smallest tile size on 18:9 phones (360 x 720 dp) and taller. 16:9 phones get smaller tiles (assumption A-1) | 2, 14.1 |
| MIN_LABEL_DIGIT_HEIGHT_DP | 12 | Smallest digit height on a tile label at SMALLEST_TILE_DP. On smaller tiles, the same share of the tile side (12 / 56) | 14.1 |
| SCORE_MIN_CHARACTERS | 13 | Characters the score display must fit | 14.2 |
| SOUND_DEFAULT | On | Sound setting on first launch | 15.1, 16 |
| STARS_PER_FREE_BOOSTER | 3 | Stars needed for each free booster | 13.9 |

D-38 to D-43 add no new constants. Small tile clearing uses the window floor, which comes from SPAWN_TOP_MIN, SPAWN_TOP_DIVISOR and SPAWN_WINDOW_SIZE. Changing those moves the clear too. D-45 adds none either: the star count is how many times the window floor of the run highest tile has doubled above the floor of an empty board (2 with these values), so it moves with the same three constants. D-46 adds STARS_PER_FREE_BOOSTER.

The rules already require every tile to be a power of two of 2 or more (section 5), so the spawn constants must keep every window value one. SPAWN_TOP_MIN and SPAWN_TOP_DIVISOR must stay powers of two, and SPAWN_TOP_MIN at least 2 to the power SPAWN_WINDOW_SIZE (16 with these values), so the smallest window value is at least 2. The star count (D-45) relies on this too.

## 19. Acceptance tests

Each test gives the setup, the action and the exact expected result. The Type says who runs it:

- **Unit**: the core logic or boosters developer builds the state directly in the rules model and turns the test into a unit test. QA checks the test exists and passes.
- **Play**: QA walks it in the running game (editor or phone).
- **Both**: a unit test for the rule, plus a QA check of what the player sees.

"Scripted spawn" means the test replaces the random draws with listed values, in fill order (9.3). A test that says "seeds 1 to N" repeats with each seed. Unless a test says otherwise, there is no Undo snapshot, Best Score is 0, Best Tile is 0, and the run highest tile equals the setup board's highest tile. The stars follow from the run highest tile (D-45), and every free booster those stars have earned counts as already used, so none is held at the start (D-46). A test that holds free boosters says so.

Some setups hold tiles below the window floor (for example Board D with a 4096 in it). Real play cannot reach such boards after D-38, but they isolate one rule. Small tile clearing only runs when a move raises the floor (D-38), so those tiles stay unless the test's own move raises it. Where a move does raise it, the expected result includes the clear. The hooks these tests need from the rules model are listed in section 20.

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

**Board E** (no valid move, H = 32, no 2s):

```
row 0:   4  16   4  16   4
row 1:   8  32   8  32   8
row 2:   4  16   4  16   4
row 3:   8  32   8  32   8
row 4:   4  16   4  16   4
row 5:   8  32   8  32   8
row 6:   4  16   4  16   4
row 7:   8  32   8  32   8
```

**Board A4**: every cell is 4. **Board A2**: every cell is 2.

"Board D with (c,r) = v" means Board D with only the listed cells changed. The same goes for Boards E and P.

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

**AT-17. Lifting commits.** Type: Both. Setup: Board P, score 1,000. Action: drag (1,6), (2,6), (3,6), (2,5), lift. Expected:
- Score 1,016. The result 16 lands on (2,5) and falls to (2,6).
- Column 2, rows 1 to 7: 2, 8, 2, 8, 2, 16, 32.
- Cells (1,0), (2,0) and (3,0) hold new tiles from 2, 4, 8, 16.
- The Undo snapshot is Board P with 16 points.
- Undo is usable at cost 64, because 1,016 minus 16 is 1,000, which is at least 64 (D-28).

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

**AT-36. A merge that raises H raises the window at once.** Type: Unit. Setup: Board D with (0,7) = 1024 and (1,7) = 1024. Seeds 1 to 200. Action: commit (0,7), (1,7). Expected: the floor rises from 2 to 4, so all twelve 2s of Board D clear (D-38). Thirteen cells refill (the twelve cleared cells and (0,7)). Every new tile is 4, 8, 16 or 32 every time, and no 2 is left on the board. (Updated at Hard Stop 1: before D-38 only one new tile was expected.)

**AT-37. A Hammer that lowers H lowers the window at once.** Type: Unit. Setup: Board D with (0,7) = 4096 and (4,7) = 1024, score 10,000, Best Tile 4096. Seeds 1 to 200. Action: Hammer on (0,7). Expected: score 5,904. The new tile at (0,0) is 2, 4, 8 or 16. Hammer now costs 1,024. Best Tile stays 4096.

**AT-38. Hammer lowers the floor, then a chain raises it again (example CL4).** Type: Unit. Rewritten at Hard Stop 1: the old test checked D-13, which D-38 replaced. Setup: Board E with (2,7) = 2048, (4,6) = 1024 and (4,7) = 1024. Score 10,000. Scripted spawn 2, then 8, 8. Action: Hammer on (2,7); then commit (4,6), (4,7). Expected:
- After the Hammer: score 7,952, H = 1024, (2,0) = 2, and nothing was cleared.
- After the chain: score 10,000, (4,7) = 2048, and the 2 on (2,0) was cleared. (2,0) = 8, (4,0) = 8, and no 2 is left on the board.

### 19.6 Score and records

**AT-39. Points are the sum, not the result.** Type: Unit. Setup: Board D with (1,0) = 2, so row 0 starts 2, 2, 2. Score 0. Action: commit (0,0), (1,0), (2,0). Expected: score 6. (2,0) = 4.

**AT-40. Boosters add no points.** Type: Unit. Setup: Board D1024, score 10,000. Action, in order: Hammer on (4,7); Swap (0,0) with (1,0); Double on (0,2); Shuffle. Expected: score after each step: 8,976; 7,952; 5,904; 4,880.

**AT-41. Best Score updates live and never drops.** Type: Both. Setup: Board D with (0,0) = 8, score 9,990, Best Score 10,000. Action: commit (0,0), (0,1) (8, 8), then Hammer on any tile. Expected: right after the commit, score and Best Score are both 10,006. After the Hammer (cost 128), score 9,878 and Best Score still 10,006.

**AT-42. Undo does not lower Best Score.** Type: Unit. Setup: the state right after the commit in AT-41 (score 10,006, Best Score 10,006). Action: Undo (cost 64). Expected: score 9,926. Best Score stays 10,006.

**AT-43. Best Tile counts Double and is not lowered by Hammer.** Type: Unit. Setup: Board D with (0,7) = 4096 and (1,7) = 4096, score 50,000, Best Tile 4096. Action: commit (0,7), (1,7); then Double on the 8192; then Hammer on the 16384. Expected: after the commit Best Tile 8192 and score 58,192. The 8192 is this run's third star, so one free booster is held (D-46). After Double (free): score 58,192, Best Tile 16384, no free booster held. After Hammer (cost 16,384): score 41,808, H is below 16384, Best Tile still 16384. (The commit and the Double each raise the floor and clear small tiles, D-38. That does not change these numbers.) Updated on 2026-10-13 for D-46: before it, the Double cost 16,384.

**AT-44. Records persist.** Type: Play. Setup: finish a run that set a new Best Score and Best Tile. Action: close the app fully, reopen it, start a new run. Expected: Best Score and Best Tile show the values from the finished run.

### 19.7 Game over

**AT-45. Move check.** Type: Unit. Setup and expected, from section 12.1: Board D has no valid move. Board D with (2,0) = 4 has one. Board D with (1,1) = 2 has one. Board D with (0,0) = 8 has one. Board D with (0,0) = 4096 and (2,0) = 4096 has none.

**AT-46. A move that leaves no valid move opens the offer.** Type: Both. Setup: Board D with (0,0) = 4 and (1,0) = 2, score 5,000. Action: Swap (0,0) and (1,0). Expected: the board is now Board D, score 4,872, the no moves offer opens and dragging builds no chain.

**AT-47. What the offer shows.** Type: Both. Setup: Board D1024, score 5,000, an Undo snapshot worth 40 points whose board has a valid move. Action: run the move check. Expected: the offer opens. All five boosters are enabled with costs Hammer 1,024 (shown 1024), Swap 1,024, Shuffle 1,024, Double 2,048 (shown 2K), Undo 512. Shuffle is marked as suggested. End run is present. The board stays visible. In Play, the offer is still open after 60 seconds without input.

**AT-48. Shuffle rescues.** Type: Both. Setup: AT-47. Action: tap Shuffle. Expected: score 3,976. The board has a valid move. The offer closes and chains can be dragged.

**AT-49. Only Undo is usable.** Type: Both. Setup: Board D1024, score 600, an Undo snapshot worth 40 points whose board has a valid move. Action: open the offer, tap Undo. Expected: only Undo is enabled, and it is marked as the suggested rescue (D-42). After the tap, the board equals the snapshot board, score 48, and the offer closes.

**AT-50. Nothing usable ends the run at once.** Type: Both. Setup: Board D1024, score 300, an Undo snapshot worth 40 points. Action: run the move check. Expected: no offer. The run ends at once. The end of run screen shows final score 300, Best Score, Best Tile, this run's highest tile (1024) and New game. The saved run is deleted.

**AT-51. Cancelling targeting returns to the offer.** Type: Both. Setup: Board D1024, score 1,500, no snapshot. Action: open the offer, tap Hammer, tap Hammer again. Expected: before the taps, Hammer, Swap and Shuffle are enabled and Double and Undo disabled. After the second tap the offer is back and the score is still 1,500.

**AT-52. Swap rescues.** Type: Both. Setup: Board D1024 with (0,0) = 32 and (4,7) = 32, score 1,500. Action: from the offer, Swap (4,7) with (1,0). Expected: (1,0) = 32 and (4,7) = 4. Score 476. The board has a valid move and play goes on.

**AT-53. The offer repeats, then the run ends.** Type: Unit. Setup: Board D1024, score 1,500, no snapshot, scripted spawn 8. Action: Hammer on (4,7). Expected: column 4 reads 8, 2, 8, 2, 8, 2, 8, 2. Score 476. Still no valid move. Every cost is at least 512, so nothing is usable and the run ends at once with final score 476.

**AT-54. End run.** Type: Play. Setup: the offer is open with something usable. Action: tap End run. Expected: the end of run screen shows the final score, Best Score, Best Tile, this run's highest tile and New game. Closing and reopening the app does not resume that run.

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

**AT-57. Unaffordable boosters are visibly disabled.** Type: Both. Setup: Board P, no snapshot. Board P has a valid move, so no offer opens and the bar can be tapped at every score. (Changed from Board D on 2026-10-13, QA Q1: on Board D the run ends at once at 127. The costs are the same.) Action: set the score to 127, then 128, then 256. Expected: at 127 all five are disabled and tapping them does nothing. At 128 Hammer, Swap and Shuffle are enabled, Double and Undo disabled. At 256 Double is enabled too. Undo stays disabled (no snapshot).

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

**AT-75. Double on the highest tile.** Type: Unit. Setup: as AT-74, Best Tile 4096. Action: Double on (2,0). Expected:
- The tile becomes 8192. Score 21,808 (the cost was read before the effect).
- The floor rises from 8 to 16, so all 30 tiles of value 2, 4 and 8 clear (D-38). Column 2 below the 8192 is now empty, so the 8192 falls to (2,7).
- The 30 cells refill from 16, 32, 64, 128.
- Hammer now costs 8,192. Best Tile 8192.
- The 8192 is this run's third star (D-45), so one free booster is now held and every booster reads Free (D-46). The Double itself was paid.

(Updated at Hard Stop 1: before D-38 the tile stayed on (2,0). Updated on 2026-10-13 with the star and free booster line.)

**AT-76. Undo after a chain.** Type: Both. Setup: Board D with (2,0) = 512, (1,7) = 8 and (2,7) = 16. Score 1,000. Action: commit (0,7), (1,7), (2,7) (8, 8, 16), then Undo. Expected: after the commit, score 1,032 and Undo enabled at cost 256. After Undo, the board equals the setup board exactly, score 744, and Undo is disabled.

**AT-77. Undo after a chain and a Hammer.** Type: Unit. Setup: as AT-76. Action: commit the same chain, Hammer on (4,0), Undo. Expected: after the Hammer, score 520 and Undo enabled. After Undo, the board equals the setup board (the hammered tile is back) and the score is 232.

**AT-78. Undo is one step and needs a chain.** Type: Unit. Setup: a new run with seed 1, then set the score to 1,000 (TH1), so the score is never what blocks Undo. Action: check Undo; commit any two tile chain; Undo; check Undo; commit another chain; check Undo. Expected:
- Undo is disabled at the start, because there is no snapshot.
- After the two tile chain, Undo is accepted at cost 64. A two tile chain on a starting board makes at most 32, so B is 128. The score becomes 936.
- Undo is disabled right after the Undo, because there is no snapshot.
- Undo is enabled again after the next chain.

**AT-79. Undo affordability uses the score without the chain's points.** Type: Unit. Setup: Board D with (0,7) = 2, (1,7) = 2, (2,7) = 4, (3,7) = 8, (4,7) = 16, (4,6) = 32, (3,6) = 32. Score 30. Action: commit that path in that order, then call Undo on the rules model. Expected: after the commit, score 126, H = 64, Undo cost 64, Undo disabled. The call is refused and the score stays 126.

**AT-80. Undo cost comes from the current board, and records stay.** Type: Unit. Setup: Board D with (0,7) = 1024 and (1,7) = 1024. Score 20,000. Best Tile 1024. Action: commit (0,7), (1,7), then Undo. Expected: after the commit, score 22,048 and Undo cost 1,024. After Undo, the board equals the setup board (including the twelve 2s the chain cleared, D-39), score 18,976, Best Tile 2048 and Best Score 22,048.

**AT-81. Undo after a Shuffle.** Type: Unit. Setup: Board D with (2,0) = 1024 and (1,7) = 8, so row 7 reads 8, 8, 8, 16, 8. Score 5,000. Action: commit (0,7), (1,7), (2,7), (3,7) (8, 8, 8, 16, worth 40), Shuffle, Undo. Expected: after the commit 5,040, after Shuffle 4,016, after Undo the board equals the setup board (unshuffled) and the score is 3,464.

**AT-82. Undo does not rewind the random generator.** Type: Unit. Setup: AT-76 with seed 7, just before the Undo. Action: record the generator state, Undo, read the state again. Expected: the two states are equal.

**AT-83. The Undo snapshot survives a restart.** Type: Both. Setup: right after a chain, Undo enabled. Action: close the app fully, reopen, Undo. Expected: Undo is enabled with the same cost as before closing, and Undo gives the board from before that chain and the expected score.

### 19.10 Score never below zero

**AT-84. Random play never goes below zero.** Type: Unit. Setup: seeds 1 to 20, a new run each. Action: 10,000 random actions per run: valid chain commits, and calls to all five boosters with random targets whether or not they are usable. Expected: the score is never below zero. Every refused call changed nothing, free boosters included. Every accepted booster lowered the score by exactly its charge: its cost, or 0 when it used a free booster (Undo: by the chain's points plus its charge). Free boosters held never go below zero. (Updated on 2026-10-13 for D-46.)

### 19.11 Number display

**AT-85. Tile labels.** Type: Unit. Action: format every value in the table of section 14.1. Expected: exactly the labels listed (for example 1024 gives "1024", 2048 gives "2K", 131072 gives "128K", 1048576 gives "1M", 2^40 gives "1T").

**AT-86. Labels are short.** Type: Unit. Action: format every power of two from 2 to 2^49. Expected: every label is 4 characters or fewer. 2^50 gives "1024T".

**AT-87. Labels are readable on the smallest tile.** Type: Play. Setup: a test board holding 1024, 512K and 128K tiles, shown on (a) a 360 x 720 dp portrait screen and (b) a 360 x 640 dp portrait screen with on-screen buttons (phone or emulator). Action: look at the board. Expected: (a) tiles are at least 56 dp wide, every label sits fully inside its tile with no clipping, and its digits are at least 12 dp tall. (b) Every label sits fully inside its tile with no clipping, and its digits are at least 12 / 56 of the tile side tall.

**AT-88. Score format.** Type: Both. Action: format 0, 999, 1000, 75000 and 1234567, and show a score of 9,999,999,999 on a 360 dp wide screen. Expected: "0", "999", "1,000", "75,000", "1,234,567". The long score shows in full with no clipping.

**AT-89. Costs, preview and Best Tile use tile labels.** Type: Both. Action: drag the chain 512, 512, 1024, 1024; view the booster bar with H = 131072; view a Best Tile of 16384. Expected: preview "2K". Undo shows "64K", Double "256K", Hammer "128K". Best Tile shows "16K".

**AT-90. Preview life cycle.** Type: Both. Setup: a board where chain M8 (2, 2, 4, 4, 4, 8, 8, 16) can be dragged. Action: drag it one tile at a time, backtrack off the 16, lift. Expected previews: none, 4, 8, 8, 16, 16, 32, 32, then 32 after the backtrack. No preview after the lift.

### 19.12 Saving and flow

**AT-91. Resume after the app is killed.** Type: Play. Setup: a run in progress right after a chain, with Undo enabled (score minus that chain's points is at least the Undo cost, D-28). Note the board, score, Best Score, Best Tile, run highest tile and Undo cost. Action: swipe the app away from recent apps, reopen it. Expected: the same board and score, the same records, the same run highest tile, Undo enabled at the same cost.

**AT-92. Killed during an animation.** Type: Play. Setup: a run in progress. Action: commit a long chain and kill the app before its animation ends. Reopen. Expected: the chain's result and points are there.

**AT-93. Killed during a drag.** Type: Play. Setup: a 3 tile chain being dragged. Action: kill the app while the finger is still down. Reopen. Expected: no chain was committed. Board and score are as before the drag.

**AT-94. Settings persist and sound starts on.** Type: Play. Setup: a fresh install. Action: check the sound setting; turn sound off and pick a different skin; close the app fully and reopen. Expected: sound is on at first launch. After reopening, sound is off and the chosen skin is shown.

**AT-95. A broken saved run is discarded.** Type: Unit (TH18, save format of docs/ARCHITECTURE.md section 10: tile values as exponents, scores and points as digit strings). Setup: a valid profile file with records `"best_score": "5000"` and `"best_tile": 9` (Best Score 5,000, Best Tile 512), plus a valid run file. First load that valid run file unchanged as a control. Then, in turn, replace the run file with a copy of it that has exactly one of these faults:
- (a) `"cells"` holds 39 exponents.
- (b) One cell exponent is 1.5.
- (c) One cell exponent is 0.
- (d) One cell exponent is 63.
- (e) `"score": "-1"`.
- (f) `"score": "12a"`.
- (g) `"score": "007"`.
- (h) `"run_highest": 9` while the cells include exponent 10 (a 1024).
- (i) A snapshot with 40 valid exponents and `"points": "2"`.
- (j) `"columns": 6`.
- (k) The file is larger than 64 KB.
- (l) The file is malformed JSON, for example cut off part way through.

Action: load each file.

Expected:
- The control loads and equals the saved run exactly.
- Each faulty file is refused: the run loader returns no run, and nothing crashes or shows a raw error.
- The run is discarded, Continue is not offered, and the next game is a new run.
- Every time, the profile is untouched: Best Score 5,000 and Best Tile 512 are kept.

**AT-96. New game asks first.** Type: Play. Setup: a run in progress. Action: choose New game, cancel; choose New game, confirm. Expected: after cancel the run is unchanged. After confirm a new run starts with score 0 and Undo disabled, and Best Score still holds the old run's highest score.

**AT-97. One move at a time.** Type: Play. Setup: a run in progress. Action: commit a chain and, while its animation plays, try to drag another chain and tap a booster. Expected: both are ignored. Once the animation ends, both work.

**AT-98. Click sound triggers.** Type: Both (unit test by counting calls to the audio service). Action: (a) drag 2, 2, 4, backtrack off the 4, move onto the 4 again, lift; (b) touch one tile and lift; (c) use Shuffle; (d) repeat (a) with sound off. Expected: (a) 5 clicks; (b) 1 click; (c) none; (d) none.

### 19.13 Added after Hard Stop 1

**AT-99. Clearing creates the only valid move (example CL1).** Type: Unit. Setup: Board E with (0,3) = 2, (4,6) = 1024 and (4,7) = 1024. Score 10,000. Scripted spawn 8, 8. Action: commit (4,6), (4,7). Expected:
- Score 12,048. The cleared 2 adds nothing.
- (4,7) = 2048. The rules model reports exactly one cleared tile: (0,3), value 2.
- Column 0 reads 8, 4, 8, 4, 4, 8, 4, 8. Column 4 reads 8, 4, 8, 4, 8, 4, 8, 2048.
- The only valid move is (0,3) with (0,4). No offer opens.
- Best Tile and the run highest tile are 2048.

**AT-100. Two values clear at once (example CL3).** Type: Unit. Setup: Board D with (0,7), (1,7), (2,7) and (3,7) all 1024. Score 0. Seeds 1 to 200. Action: commit (0,7), (1,7), (2,7), (3,7). Expected:
- Score 4,096, and (3,7) = 4096.
- The rules model reports 20 cleared tiles: twelve 2s and eight 4s.
- 23 new tiles, each 8, 16, 32 or 64. No tile below 8 is left on the board.

**AT-101. A Double clears small tiles and rescues (example CL2).** Type: Both. Setup: Board E with (0,3) = 2 and (2,0) = 1024. Score 5,000. Scripted spawn 8. The no moves offer is open. Action: Double on (2,0). Expected:
- Score 2,952. (2,0) = 2048, and the 2 on (0,3) was cleared.
- (0,0) = 8, and (0,3) and (0,4) are both 4.
- The board has a valid move and the offer closes.

**AT-102. Undo brings cleared tiles back (example CL5).** Type: Unit. Setup: the state right after AT-99. Action: Undo. Expected: Undo cost 1,024. The board equals the AT-99 setup, including the 2 on (0,3) and both 1024s. Score 8,976. Best Tile and the run highest tile stay 2048.

**AT-103. Only a raised floor clears.** Type: Unit. Setup: Board E with (0,3) = 2 and (2,0) = 2048. Real play cannot reach this board: the 2 is below the floor of 4. Score 20,000. Scripted spawn 4. Action, in order: Hammer on (4,7); Swap (0,0) with (1,0); Double on (0,0); Shuffle. Expected: score after each step: 17,952; 15,904; 11,808; 9,760. After every step exactly one 2 is still on the board, and the rules model reports no cleared tiles.

**AT-104. The player sees the clear.** Type: Play. Setup: a real run where H is 1024 and the board holds some 2s. Action: make the first 2048. Expected: the 2s clear as part of that move's animation. The player is shown that 2s were cleared and no longer appear. No 2 spawns afterwards while H stays 2048 or more.

**AT-105. Joinable highlight examples.** Type: Both. Setup: Board P. Action: build HL1 to HL6 of section 6.7 in order, then HL7 as a separate drag. Expected: at each step exactly the cells listed in the 6.7 table are highlighted, and no others.

**AT-106. The highlight always matches joining.** Type: Unit. Setup: seeds 1 to 100. Each seed gives a random board from the starting window and a random drag of up to 15 finger moves onto touching cells, including backtracks. Expected, at every step:
- The highlighted set equals the set of tiles the joining rule (6.1) would accept.
- A move onto a highlighted tile adds it.
- A move onto any other tile that is not the previous chain tile leaves the chain unchanged.
- The previous chain tile is never highlighted.

**AT-107. No highlight outside a drag.** Type: Play. Action: look at the board before touching it, after lifting a chain, with Hammer in targeting mode, and with the no moves offer open. Expected: no joinable highlight in any of these.

**AT-108. This run's highest tile.** Type: Unit. Setup: Board D with (0,7) = 1024 and (1,7) = 1024. Score 50,000. Best Tile 8192. Run highest tile 1024. Action, in order: commit (0,7), (1,7); Double on (1,7); Hammer on (1,7); Undo; then start a new run. Expected:

| After | Score | Run highest tile | Best Tile |
|---|---|---|---|
| The commit | 52,048 | 2048 | 8192 |
| Double (cost 4,096) | 47,952 | 4096 | 8192 |
| Hammer (cost 4,096) | 43,856 | 4096 | 8192 |
| Undo (cost 64: B is 128 because only tiles up to 64 remain) | 41,744 | 4096 | 8192 |
| New run | 0 | The new starting board's highest tile (16 at most) | 8192 |

**AT-109. The suggested rescue (D-42).** Type: Unit. Setup: Board D1024 in each case below. Action: open the offer. Expected:
- (a) Score 5,000, snapshot worth 40: Shuffle is marked.
- (b) Score 600, snapshot worth 40: Undo is marked.
- (c) Score 1,500, no snapshot: Shuffle is marked.
- (d) Constants overridden for the test to COST_SHUFFLE = 4 x B and COST_UNDO = 4 x B; score 1,500, snapshot worth 40: Hammer and Swap are usable, Shuffle, Double and Undo are not, and nothing is marked.

**AT-110. Hammer and Double act on one tap.** Type: Both. Setup: Board P, score 5,000. Action:
- (a) Tap Hammer, put a finger down on (2,7) and hold.
- (b) Lift on (2,7).
- (c) Tap Double, put a finger down on (0,0), slide to (1,0), lift.

Expected:
- (a) Nothing is charged and the board is unchanged. (2,7) may show press feedback.
- (b) Hammer applies at once, with no confirm step: (2,7) is removed, score 4,872, targeting ends.
- (c) Nothing is doubled or charged, and Double stays active.

**AT-111. Swap selects on its first tap and acts on its second.** Type: Both. Setup: Board P, score 5,000. Action: tap Swap, tap (0,0), then tap (2,7). Expected: after the first tile tap, (0,0) is selected and nothing is charged. On the second tap the swap applies at once: (0,0) = 32, (2,7) = 2, score 4,872, targeting ends.

### 19.14 Added on 2026-10-13

Play setups that need stars or free boosters can use a run file written by hand in the save format (docs/ARCHITECTURE.md section 10), or a run played that far.

**How to play (D-44)**

**AT-112. How to play opens from the main menu.** Type: Play. Setup: the main menu (first launch, or after a run ends). Note Best Score and Best Tile. Action: tap How to play; scroll to the end; press Android back. Open it again and close it with its own close control. Expected: the screen opens titled "How to play" with sections HP1 to HP7 of section 21.2 in order, every title and text exactly as written there. Both back and the close control return to the main menu. Best Score and Best Tile are unchanged.

**AT-113. How to play opens from Pause and leaves the run untouched.** Type: Play. Setup: a run in progress right after a chain, with Undo enabled. Note the board, score, stars and Undo cost. Action: open Pause, tap How to play, press back, then tap Resume. Expected: How to play opens from Pause. Back returns to Pause, not to the board. After Resume the board, score, stars, free boosters held and Undo cost are exactly as noted.

**AT-114. How to play never opens by itself.** Type: Play. Setup: a fresh install. Action: launch the app; start a new game; play until the run ends; start another game; close the app and reopen it. Expected: How to play never appears unless its button is tapped.

**AT-115. Real tiles in the current skin, and the screen fits.** Type: Play. Setup: 360 x 720 dp and 360 x 640 dp portrait screens. Action: for each skin (Gumdrop, Slate, Nova), select it in Settings, then open How to play from the main menu and from Pause. Expected:
- The rows HP1 (2, 2, 4 then 8), HP2 (2, 2, 2 then 4) and HP5 (1024, 1024 then 2K) are drawn by that skin's own tile component, with its colors and font. The labels read "1024" and "2K".
- The result tile in each row is set apart from the chain tiles.
- Titles and text use that skin's fonts, colors and casing.
- On 360 x 720 dp the whole content scrolls in at most about two screen heights. Nothing is clipped on either screen.
- Tapping or dragging the example tiles does nothing.

**AT-116. The How to play content checks out.** Type: Unit. Setup: the content the screen shows (TH21). Action: read it, and check each example row on the rules model. Expected:
- Seven sections, titles and texts exactly as in section 21.2. Each title is 1 to 4 words and each text 2 sentences.
- Each example row, laid out as touching cells on a test board, is a valid chain (D-04), and its result tile equals the merge result (TH15): 2, 2, 4 gives 8; 2, 2, 2 gives 4; 1024, 1024 gives 2048.
- Each label equals NumberFormat's tile label (TH17): "1024" and "2K".

**Stars (D-45)**

**AT-117. Star count and free boosters earned.** Type: Unit. Setup: run states with the run highest tile 16, 1024, 2048, 4096, 8192, 65536, 131072, 1048576 and 2^62. Action: read the stars and free boosters earned (TH3). Expected, in the same order: stars 0, 0, 1, 2, 3, 6, 7, 10, 52; free boosters earned 0, 0, 0, 0, 1, 2, 2, 3, 17. The 131072 case is Bart's phone run: 7 stars, 2 free boosters earned.

**AT-118. The first 2K earns a star (example SC2).** Type: Unit. Setup: as AT-99. Action: commit (4,6), (4,7). Expected: everything in AT-99, plus: stars 0 before and 1 after. The move result reports 1 star earned and 0 free boosters earned.

**AT-119. Two stars in one move (example SC3).** Type: Unit. Setup: as AT-100. Action: commit (0,7), (1,7), (2,7), (3,7). Expected: everything in AT-100, plus: stars 0 before and 2 after. The move result reports 2 stars earned. The notice values (TH12) are 2 and 4.

**AT-120. Hammer, then a chain back to the same level, earns no star (examples SC4 and SC5).** Type: Both. Setup: as AT-38 (run highest tile 2048, so 1 star). Action: as AT-38. Expected: everything in AT-38, plus:
- After the Hammer: 1 star, 0 earned. No notice.
- After the chain: 1 star, 0 earned. The move result still reports the 2 on (2,0) as cleared, and the notice values are 2.
- Play: the clear notice shows "No more 2s" with no star. The HUD star count stays at 1.

**AT-121. Undo keeps the star, and the same chain again earns none (example SC6).** Type: Unit. Setup: as AT-80. Action: commit (0,7), (1,7); Undo; commit (0,7), (1,7) again. Expected:
- After the first commit: 1 star, 1 earned, score 22,048.
- After Undo: still 1 star, score 18,976. The run highest tile stays 2048.
- After the second commit: score 21,024, still 1 star, 0 earned. The twelve 2s are cleared again.

**AT-122. A Double that raises the floor earns a star (example SC8).** Type: Unit. Setup: as AT-101. Action: Double on (2,0). Expected: everything in AT-101, plus: stars 0 before and 1 after, and the move result reports 1 star earned.

**AT-123. A floor rise that removes no tile still earns its star (example SC7).** Type: Both. Setup: Board E with (4,6) = 1024 and (4,7) = 1024. Score 10,000. Scripted spawn 4. Action: commit (4,6), (4,7). Expected:
- Score 12,048. (4,7) = 2048. (4,0) = 4, so (4,0) and (4,1) are both 4 and the board has a valid move.
- The window floor rose from 2 to 4. The move result reports no cleared tiles, 1 star earned and notice values 2.
- Stars 1.
- Play: the clear notice shows "No more 2s" with one star, although no tile cleared.

**AT-124. A new highest tile below 2K earns no star (example SC9).** Type: Unit. Setup: Board D with (0,7) = 512 and (1,7) = 512. Score 0. Action: commit (0,7), (1,7). Expected: score 1,024 and (1,7) = 1024. The run highest tile is 1024, the floor stays 2, nothing is cleared, and the move result reports 0 stars earned. Stars 0.

**AT-125. The starting board and a loaded run earn no star (examples SC1 and SC10).** Type: Unit. Setup and action: (a) start new runs with seeds 1 to 100. (b) Load a saved run (TH18) with a valid board, run highest tile 131072 and 1 free booster used. Expected: (a) every new run has 0 stars and 0 free boosters. (b) The loaded run has 7 stars and 1 free booster held. The load reports no star earned and nothing that would show a clear notice.

**AT-126. The player sees the star.** Type: Play. Setup: a real run where H is 1024, with the score high enough to Undo after the next chain. Action: make the first 2048; then use Undo; then make the same chain again. Expected:
- The first chain: the clear notice shows with one star, and the HUD star count reads 1 no later than when the board can be played again.
- After Undo the HUD still reads 1.
- The chain again: the notice shows with no star, and the count stays 1.
- In every skin the star count is visible on the play screen. Nothing about the stars holds input or plays a sound.

**Free boosters (D-46)**

**AT-127. The third star earns a free booster (example FB1).** Type: Both. Setup: Board D with (0,7) = 4096 and (1,7) = 4096. Score 50,000. Run highest tile 4096 (2 stars). Action: commit (0,7), (1,7). Expected:
- Score 58,192. 3 stars. The move result reports 1 free booster earned. 1 free booster held.
- Every booster status shows it as free (TH3), with its cost unchanged: Hammer 8,192, Double 16,384, Undo 4,096. All five are usable, Undo because a snapshot exists and 58,192 minus 8,192 is at least 0.
- Play: every booster on the bar reads Free, and the number of free boosters held is shown.

**AT-128. The next booster is free, automatically, one at a time (example FB2).** Type: Unit. Setup: the state right after AT-127. Action: Hammer on (4,0); then Hammer on (4,0) again. Expected: the first Hammer is accepted, charges 0 and is reported as using a free booster. Score 58,192, 0 free boosters held, every booster no longer free. The second Hammer charges 8,192: score 50,000.

**AT-129. A free booster makes an unaffordable booster usable (example FB3).** Type: Both. Setup: Board P. Score 0. Run highest tile 8192. Free boosters used 0, so 1 held. No snapshot. Action: read the booster statuses; then Double on (0,0). Expected:
- Before: Hammer, Swap, Shuffle and Double are usable and free. Undo is free but not usable (no snapshot).
- After: (0,0) = 4, score 0, 0 free boosters held. All five boosters are disabled (score 0, cheapest cost 64).
- Play: before the Double all five read Free and only Undo looks disabled. After it they all read their costs and look disabled.

**AT-130. A free Undo still follows D-28 (example FB4).** Type: Unit. Setup: Board D with (2,0) = 4096, (1,7) = 8 and (2,7) = 16. Score 8,160. Run highest tile 4096. Action: commit (0,7), (1,7), (2,7); Double on (2,0); then call Undo on the rules model. Expected:
- After the commit: score 8,192.
- After the Double (cost 8,192): score 0, 3 stars, 1 free booster held.
- Undo is not usable (cannot afford: 0 minus 32 is below 0) and the call is refused. Score 0, board unchanged, still 1 free booster held.
- Hammer, Swap, Shuffle and Double are usable.

**AT-131. Cancelling targeting keeps the free booster (example FB5).** Type: Both. Setup: Board P. Score 5,000. Run highest tile 8192. Free boosters used 0, so 1 held. Action: tap Hammer, tap Hammer; tap Swap, tap (0,0), tap (0,0), tap Swap; tap Double, tap Hammer, press back; tap Double, open Pause, resume; then tap Shuffle. Expected:
- Through every cancel, deselect, switch and the pause: still 1 free booster held, score 5,000, all five read Free.
- The Shuffle is free: score 5,000, 0 held. Hammer costs 128 again.

**AT-132. A free booster used on Undo stays used (example FB6).** Type: Unit. Setup: the state right after AT-127. Action: Undo; then commit (0,7), (1,7) again. Expected:
- Undo is accepted, charges 0 and uses the free booster. The board equals the AT-127 setup and the score is 50,000. Still 3 stars (the run highest tile stays 8192). 0 free boosters held.
- After the second commit: score 58,192, 3 stars, 0 stars and 0 free boosters earned, 0 held.

**AT-133. Two free boosters held (example FB7).** Type: Unit. Setup: Board D with (0,7) = 32768 and (1,7) = 32768. Score 1,000,000. Run highest tile 32768 (5 stars). Free boosters used 0, so 1 held. Action: commit (0,7), (1,7); Shuffle; Double on any tile that is not the 65536; Hammer on any tile that is not the 65536. Expected:

| After | Score | Stars | Free boosters held |
|---|---|---|---|
| The commit | 1,065,536 | 6 | 2 |
| Shuffle (free) | 1,065,536 | 6 | 1 |
| Double (free) | 1,065,536 | 6 | 0 |
| Hammer (cost 65,536) | 1,000,000 | 6 | 0 |

**AT-134. A Double that earns a free booster is itself paid (example FB9).** Type: Unit. Setup: as AT-75. Action: Double on (2,0); then Shuffle. Expected: after the Double, score 21,808, 3 stars and 1 free booster held. The Shuffle charges 0: score 21,808, 0 held.

**AT-135. The out of moves offer with a free booster (example FB8).** Type: Both. Setup: Board D1024. Score 0. No snapshot. Run highest tile 8192. (a) Free boosters used 0, so 1 held. (b) Free boosters used 1, so none held. Action: run the move check; in (a) then tap Shuffle. Expected:
- (a) The offer opens. Hammer, Swap, Shuffle and Double are usable and read Free. Undo is disabled. Shuffle is marked as the suggested rescue, and the buy button reads "Shuffle for free". After the tap: score 0, the board has a valid move, 0 free boosters held, and the offer closes.
- (b) Nothing is usable, so the run ends at once with final score 0, as in AT-50.

**AT-136. A free booster never touches score or Best Score (example FB10).** Type: Unit. Setup: Board D with (2,0) = 8192. Score 1,000. Best Score 1,000. Best Tile 8192. Run highest tile 8192. Free boosters used 0, so 1 held. Action: Double on (2,0). Expected: the Double charges 0. Score 1,000 and Best Score 1,000. The tile becomes 16384, so Best Tile and the run highest tile are 16384 and the stars 4. 0 free boosters held.

**AT-137. Unused free boosters end with the run (example FB11).** Type: Both. Setup: Board D1024. Score 5,000. Run highest tile 8192. Free boosters used 0, so 1 held. The offer is open. Action: tap End run, then New game. Expected: the end of run screen shows this run's highest tile 8K. The new run has 0 stars and 0 free boosters held, and its boosters show costs (Hammer 128), not Free.

**AT-138. Stars and free boosters survive a restart.** Type: Both. Setup: (Unit) a run state with a valid board, run highest tile 131072 and 1 free booster used. (Play) a run with at least 3 stars and 1 free booster held. Action: (Unit) save it and load it again (TH18). (Play) note the stars, close the app fully and reopen it, then use any booster. Expected: (Unit) the loaded state equals the saved one: 7 stars, 1 free booster held. (Play) the run reopens with the same stars and every booster still reads Free. The booster used next charges nothing.

**AT-139. Checking the saved count of free boosters used.** Type: Unit (TH18, save format of docs/ARCHITECTURE.md section 10). Setup: a valid run file with run highest tile 131072 (exponent 17, so 2 free boosters earned) and a valid profile. Action: load copies with free boosters used set to (a) 0, (b) 2, (c) 3, (d) minus 1, (e) 1.5, (f) the text "1", and (g) a copy with no such entry at all. Expected:
- (a) and (b) load, with 2 and 0 free boosters held.
- (c) to (f) are refused as in AT-95: the run is discarded, nothing crashes, and the profile is untouched.
- (g) loads as 0 used, so 2 free boosters held (section 15.1).

**About screen (no D number)**

**AT-140. About opens from Settings and back closes it.** Type: Play. Setup: Settings open, once from the main menu and once from Pause. Action: tap About, press Android back; tap About again, use its own close control. Then open About, open a license row, press back; open the row again and use the license view's close control. Expected: About opens from Settings. Back and the close control each return to Settings, which is still open. A second back closes Settings as before. From a license view, back and its close control each return to About. It works in every skin.

**AT-141. About shows what it is and who made it.** Type: Both. Setup: none. Action: open About in each skin, and compare it with the Settings version line. Expected (copy from DESIGN_SYSTEM.md 7.10 and 7.13):
- The brand block shows the wordmark "SumUp", "Version {version}", "Made by Bart Basi" and "Copyright 2026 Bart Basi".
- The version is the same as on the Settings version line. When no version is set, both leave it out.
- "Copyright 2026 Bart Basi" reads exactly so in every skin, never cased (Slate included), and is visible in the first screenful without scrolling.
- The sections "What it is", "Offline, no data" and "Licenses" follow, with their copy. The second says the game works fully offline and collects no data. The Licenses section ends in three rows: SumUp, Godot Engine and Outfit font.
- Unit (TH22): the About text contains "Copyright 2026 Bart Basi" exactly, and its version equals the project's version setting.

**AT-142. Every license can be read in full.** Type: Both. Setup: none. Action: from About, open each license row in turn: "SumUp license", "Godot Engine" and "Outfit font". Scroll each from its first line to its last. Expected:
- Unit: each view's text equals its sources with whitespace normalized, in both the view and the source:
  - every run of spaces and line breaks inside a paragraph counts as one space;
  - blank lines mark the paragraph breaks;
  - spaces at the start and end of a paragraph do not count;
  - the headings and the "Copyright" and "License:" labels the view adds (DESIGN_SYSTEM.md 7.10) are left out of the comparison.
  Nothing else may differ, not one character.
- The sources, in order:
  - SumUp license: the NOTICE file, then the unchanged COPYING file (GNU GPL version 3), both as shipped in the package.
  - Godot Engine: the engine's license text; every entry of its copyright info, with each part's copyright lines and license name; and every entry of its license info, with its full text.
  - Outfit font: the shipped OFL.txt.
- Unit, completeness: each view has the same number of paragraphs as its sources, and its first and last paragraphs equal theirs.
- Play: on a 360 x 640 dp screen each view scrolls from its first line to its last, which is visible. No line is clipped or cut short.

**The 64 bit edge (SEC-01, D-37)**

**AT-143. Two touching 2^62 tiles do not block the run.** Type: Unit. Setup: Board D with (0,7) = 2^62 and (1,7) = 2^62. This is the board of security finding SEC-01 (cells 35 and 36 at exponent 62). Score 0. Run highest tile 2^62, so 52 stars and 17 free boosters earned. No snapshot.

(a) All 17 free boosters used, so none held. Action: read the valid move check (TH13) and the joinable cells for the chain [(0,7)] (TH14); commit [(0,7), (1,7)]; run the move check. Expected:
- No valid move. (1,7) is not joinable.
- The commit is refused and changes nothing.
- Nothing is usable: Hammer, Swap and Shuffle cost 2^62, Double's 2^63 does not fit, and Undo has no snapshot.
- The run ends at once with final score 0. It does not stay in play.

(b) 16 free boosters used, so 1 held. Action: run the move check; Double on (0,7); Double on (2,7). Expected:
- The offer opens. Hammer, Swap, Shuffle and Double are usable and free, Undo is not, and Shuffle is marked.
- Double on (0,7) is refused as a bad target. Nothing changes and 1 free booster is still held.
- Double on (2,7) is accepted and charges 0. (2,7) = 16, which touches (3,7) = 16, so the board has a valid move and play goes on. 0 held.

**AT-144. An all 2^62 board with a free booster held cannot loop.** Type: Unit. Setup: all 40 cells 2^62. Run highest tile 2^62. No snapshot. Scripted spawn 2^53.

(a) Score 0. 16 free boosters used, so 1 held. Action: run the move check; call Swap on (0,0) and (1,0), Shuffle, and Double on (0,0) on the rules model; then Hammer on (0,0). Expected:
- No valid move. The offer opens with only Hammer usable, and free. Swap and Shuffle are not usable (every tile is equal), Double is not (no tile of 2^61 or less) and Undo is not (no snapshot). Nothing is marked. End run is offered.
- The Swap, Shuffle and Double calls are refused and change nothing. 1 free booster is still held.
- The Hammer is accepted and charges 0: (0,0) = 2^53, score 0, 0 held.
- Still no valid move and nothing usable, so the run ends at once.

(b) The finding's variant: score 2^63 minus 1 (9,223,372,036,854,775,807), no free booster held. Action: run the move check, then Hammer on (0,0). Expected:
- The offer opens with only Hammer usable (cost 2^62). Swap and Shuffle are not usable (every tile is equal), Double is not (its cost does not fit and it has no target), and Undo is not.
- After the Hammer: score 2^62 minus 1 (4,611,686,018,427,387,903) and (0,0) = 2^53. No valid move, nothing usable, and the run ends at once.

**From QA's Phase 6 report (2026-10-13)**

**AT-145. New best survives a restart (QA6-03).** Type: Both. Setup: a profile with Best Score 5,000, and a saved run file: Board D1024, score 5,000, no snapshot, Best Score when the run began 4,000. So this run raised the record from 4,000 to 5,000 before the app closed. Action: open the app (the run resumes and the offer opens, because Board D1024 has no valid move), then tap End run. Repeat with two changed copies of the run file: (b) Best Score when the run began 5,000; (c) no starting Best Score in the file at all, as saved before this rule. Expected:
- (a) The end of run screen shows the New best badge.
- (b) No badge: the run only equalled the record.
- (c) No badge, the old behaviour (section 15.1).
- Unit: the same three files through TH18 and the session give a run summary with New best true, false and false.
- Play, in a real run as well: set a new Best Score, use a booster so the score drops below it, close the app fully and reopen it, then play to the out of moves offer without passing the Best Score again and tap End run. The badge shows.

**AT-146. A kill right after the lift never shows an unsaved move (QA6-06).** Type: Both. Setup: a run in progress. Action:
- Unit (TH23): hold back the save writer, commit a chain, check the view, then release the writer.
- Play: 20 times, commit a chain and hard kill the process in the first frame after the lift (as QA's r_f), and also inside the save request (as r_g). Capture the last frame shown before each kill, then reopen.

Expected:
- Unit: while the save is held back, the board view has not started the move. The board, score and booster bar are as at the lift. Once the save finishes, the move's animation starts.
- Play: each reopen gives one of two results. Either the run from before the move, and the captured frame shows nothing of the move: no merged tile, no score change, no clear and no spawn. Or the run after the move, with its result and points. A result that was on screen is never missing after reopening.

### 19.15 Coverage

| Decision or rule | Tests |
|---|---|
| D-01 Board size | AT-01 |
| D-02 Rounding down | AT-26, AT-27, AT-28 |
| D-03 Preview | AT-07, AT-14, AT-89, AT-90 |
| D-04 Joining rule | AT-06, AT-08, AT-09, AT-10, AT-11, AT-12, AT-13, AT-143 |
| D-05 Backtracking | AT-14, AT-15, AT-16 |
| D-06 Path, leaving, lifting | AT-18, AT-19, AT-20, AT-25 |
| D-07 Hit radius | AT-21 |
| D-08 One finger | AT-22, AT-23, AT-24 |
| D-09 Resolution order | AT-17, AT-29 to AT-33, AT-99 |
| D-10 Spawn window and weights | AT-04, AT-34, AT-35 |
| D-11 Window timing | AT-36, AT-37 |
| D-12 Fill order | AT-31, AT-32 |
| D-13 Tiles below the window | Replaced by D-38. AT-38 was rewritten for D-38 and D-39 |
| D-14 Starting board | AT-01 to AT-03 |
| D-15 Valid move | AT-45, AT-143, AT-144 |
| D-16 Best Score | AT-41, AT-42, AT-80, AT-136 |
| D-17 Best Tile | AT-05, AT-37, AT-43, AT-75, AT-80, AT-136 |
| D-18 Only chains add points | AT-39, AT-40 |
| D-19 No moves offer | AT-46 to AT-55, AT-73, AT-101, AT-109, AT-135, AT-143, AT-144 |
| D-20 Costs | AT-56, AT-60 |
| D-21 Cost read at use, charged with effect | AT-37, AT-60, AT-61, AT-75 |
| D-22 Targeting | AT-61 to AT-66 |
| D-23 Hammer | AT-37, AT-53, AT-67 |
| D-24 Swap | AT-52, AT-68, AT-69 |
| D-25 Shuffle | AT-48, AT-70 to AT-73, AT-144 |
| D-26 Double | AT-74, AT-75, AT-101, AT-143, AT-144 |
| D-27 Undo | AT-49, AT-76, AT-77, AT-78, AT-81 |
| D-28 Undo affordability | AT-79, AT-130 |
| D-29 Undo keeps records and generator | AT-42, AT-80, AT-82 |
| D-30 Never below zero | AT-57, AT-58, AT-59, AT-84, AT-130 |
| D-31 Tile labels | AT-85, AT-86, AT-87 |
| D-32 Score and cost formats | AT-88, AT-89 |
| D-33 Saving | AT-55, AT-65, AT-83, AT-91 to AT-93, AT-95, AT-138, AT-139, AT-145, AT-146 |
| D-34 New game | AT-96 |
| D-35 One move at a time | AT-97, AT-146 |
| D-36 Click triggers | AT-98 |
| D-37 64-bit values and the limit (SEC-01) | AT-28, AT-71, AT-73, AT-143, AT-144 |
| D-38 Small tile clearing | AT-36, AT-38, AT-75, AT-99, AT-100, AT-101, AT-104 |
| D-39 Clearing and other rules | AT-38, AT-80, AT-102, AT-103 |
| D-40 Joinable highlight | AT-105, AT-106, AT-107 |
| D-41 Run highest tile | AT-50, AT-54, AT-91, AT-95, AT-99, AT-108 |
| D-42 Suggested rescue | AT-47, AT-49, AT-109 |
| D-43 Targeting acts on tap | AT-62, AT-110, AT-111 |
| D-44 How to play | AT-112 to AT-116 |
| D-45 Stars | AT-75, AT-117 to AT-126, AT-138 |
| D-46 Free boosters | AT-43, AT-75, AT-84, AT-127 to AT-139, AT-143, AT-144 |
| About screen (no D number) | AT-140 to AT-142 |
| Confirmed: chain rules | AT-06 to AT-16 |
| Confirmed: merge and after merge | AT-17, AT-26, AT-29 to AT-31 |
| Confirmed: score, Best Score and Best Tile kept separately | AT-39 to AT-44 |
| Confirmed: game over | AT-45 to AT-55 |
| Confirmed: boosters, disabled when unaffordable, score never below zero | AT-56 to AT-84 |
| Confirmed: number display | AT-85 to AT-89 |
| Confirmed: persistence | AT-44, AT-83, AT-91 to AT-95 |
| Hard Stop 1 additions (Bart) | AT-99 to AT-108 |
| 2026-10-13 additions (Bart) | AT-112 to AT-142 |
| SEC-01 fix (Bart, 2026-10-13) | AT-143, AT-144 |
| End of run New best badge (12.3) | AT-145 |
| QA Phase 6 fixes (Bart, 2026-10-13) | AT-57, AT-145, AT-146 |

## 20. Test hooks the acceptance tests need

For the contract in docs/ARCHITECTURE.md. The rules model (core and boosters) must offer these to tests. How they are shaped is the contract's choice.

**Setting up and reading state**

| # | Hook | Used by |
|---|---|---|
| TH1 | Build a run state directly: 40 values, score, Undo snapshot (40 values and points) or none, Best Score, Best Tile, run highest tile, free boosters used (D-46). | Most Unit tests |
| TH2 | Read the full state back: everything in TH1. | Most Unit tests |
| TH3 | Read derived values for the current board: H, B, the spawn window and floor, each booster's cost, whether each booster is free now, each booster's usability with the reason it is unusable (cannot afford, no snapshot, or nothing it could act on, 13.1), the stars, and the free boosters earned and held. | AT-34, AT-47, AT-49, AT-56, AT-57, AT-60, AT-109, AT-117, AT-125, AT-127 to AT-137, AT-143, AT-144 |
| TH4 | Override the section 18 constants for one test (for example the costs). | AT-109 (d) |

**Controlling randomness**

| # | Hook | Used by |
|---|---|---|
| TH5 | A seedable random number generator, one per run. Its state can be read, and restored. | AT-02, AT-04, AT-35, AT-36, AT-82, AT-84 |
| TH6 | Scripted spawns: a list of values used instead of random draws, in fill order (9.3). Every spawn path uses it: chain refill, Hammer refill, Double refill after a clear. | AT-31, AT-32, AT-38, AT-53, AT-67, AT-99, AT-101, AT-103, AT-144 |
| TH7 | Forced starting boards: the generator returns a given board on every attempt, and the attempt count can be read. | AT-03 |
| TH8 | Forced Shuffle arrangements: Shuffle returns a given arrangement on every attempt, and the attempt count can be read. | AT-72 |
| TH9 | The weighted draw on its own: draw number (0 to 99) plus window gives a value. | AT-35 |

**Acting and reading the result**

| # | Hook | Used by |
|---|---|---|
| TH10 | Commit any list of cells as a chain. The answer says accepted or refused, and a refusal changes nothing. | AT-12, AT-13, AT-25 to AT-30, AT-143 |
| TH11 | Call any booster with its targets, whether or not it is usable. The answer says accepted or refused, and a refusal changes nothing. | AT-40, AT-59, AT-79, AT-84, AT-103, AT-143, AT-144 |
| TH12 | A move result that lists: points added; the charge, and whether a free booster was used (D-46); the result cell and value; the cleared chain cells; the small tiles cleared by D-38 (cells and values); the notice values, every value that left the spawn window in this move (D-45); the stars and free boosters this move earned; tile moves from gravity; spawned cells and values; whether the no moves offer opens; whether the run ended. The board view, the HUD and the clear notice (AT-104) need this too. | AT-17, AT-29 to AT-31, AT-36, AT-38, AT-99 to AT-103, AT-118 to AT-124, AT-127, AT-128, AT-132, AT-136 |

**Queries**

| # | Hook | Used by |
|---|---|---|
| TH13 | Has a valid move (D-15). | AT-02, AT-45, AT-70, AT-71, AT-143, AT-144 |
| TH14 | Joinable cells for a given chain (D-40). | AT-105, AT-106, AT-143 |
| TH15 | Merge result (preview value) for a given list of values. | AT-26, AT-27, AT-90 |
| TH16 | The suggested rescue for the current state (D-42). | AT-47, AT-49, AT-109, AT-143, AT-144 |
| TH17 | Label format for a value, and score format. | AT-85, AT-86, AT-88 |

**Outside the rules model**

| # | Hook | Area | Used by |
|---|---|---|---|
| TH18 | Save a run and records to the save format, and load from given data, with the validation result. | save | AT-95, AT-125, AT-138, AT-139, AT-145 |
| TH19 | Hit test: finger position and tile pitch give a tile or none. | board | AT-21 |
| TH20 | A count of click requests made to the audio service. | audio | AT-98 |
| TH21 | Read the How to play content the screen shows: section titles, texts, example rows and result tiles. | ui | AT-116 |
| TH22 | Read the About screen's text and each license text it shows. | ui | AT-141, AT-142 |
| TH23 | Hold back the save writer and release it, and read whether the board view has started showing the last move. | save, ui | AT-146 |

## 21. How to play screen (D-44)

Bart's request (2026-10-13): a How to play button on the main menu and in Pause opens a screen explaining how the game works and how points are scored, in short sections, each with a small row of real tiles drawn in the current skin. It opens only when tapped, never by itself.

**D-44. How to play.**

### 21.1 Rules for the screen

- Only a "How to play" button opens it: one on the main menu and one in Pause. It never opens by itself, not at first launch and not when a run starts or ends.
- Android back and the screen's own close control both close it and return to where it was opened. From Pause it returns to Pause, so the run stays paused until the player taps Resume.
- It changes nothing. Board, score, stars, free boosters, Undo, records and settings stay exactly as they were. It is not a move.
- It follows the shared arrangement for menus and dialogs, drawn in the current skin's style: fonts, colors, panels and casing (Bart, 2026-10-10).
- Example rows are real tiles drawn by the current skin's tile component, with tile labels (D-31), never pictures. Each row shows the chain tiles in drag order, then the result tile, set apart so the player can tell it is the result. The tiles are only an illustration: tapping or dragging them does nothing.
- The text is fixed. It holds no live numbers such as current prices or the score.
- On a 360 x 720 dp screen it takes at most about two screen heights, and it scrolls when it is longer than the screen.
- The layout is a design system choice.

### 21.2 The text

Screen title: "How to play". Seven sections, in this order. The brief asked for about six: the seven topics it lists each need their own section to stay within two short sentences.

| # | Title | Text | Example row | Result tile |
|---|---|---|---|---|
| HP1 | Make a chain | Slide across touching tiles, diagonals too, starting with two equal ones. Each next tile must match the last one or double it. | 2, 2, 4 | 8 |
| HP2 | What it makes | Lift to merge, or lift on one tile to cancel. The tiles add up and round down to a tile number, so 6 becomes 4. | 2, 2, 2 | 4 |
| HP3 | After a merge | The merged tile lands where your chain ended, tiles above fall and new ones drop in. While you drag, highlighted tiles can join next. | none | none |
| HP4 | Score | A chain scores the sum of its tiles. Boosters cost points, your score never drops below zero, and best score and best tile are saved. | none | none |
| HP5 | Move up, earn stars | Each new highest tile from 2K up removes the smallest number and earns a star. Every 3 stars make your next booster free. | 1024, 1024 | 2K |
| HP6 | Boosters | Hammer smashes a tile, Swap swaps two, Shuffle mixes the board, Double doubles one, Undo takes back your last chain. Prices grow as you go. | none | none |
| HP7 | Out of moves | When no two touching tiles match, you can pick a booster to keep going. If you can't, or you tap End run, the run ends. | none | none |

Sizes: titles of 3, 3, 3, 1, 4, 1 and 3 words (the comma in "Move up, earn stars" is part of the title). Each text is two sentences of 22, 25, 24, 25, 23, 25 and 25 words, 169 in all. Three example rows, each of 2 or 3 tiles plus the result. Booster names are those on the booster bar, and "End run" and "Out of moves" match the offer (DESIGN_SYSTEM.md 7.5).

### 21.3 Checks against the rules

| Item | Check | Rules |
|---|---|---|
| HP1 row: 2, 2, 4 makes 8 | 2 equals 2, so the chain can start. 4 is double 2, so it joins. The sum, 8, is already a power of two, so the result is 8. | D-04, D-02 |
| HP2 row: 2, 2, 2 makes 4 | 2 equals 2, and the third 2 equals the last tile. The sum is 6, and the largest power of two not above 6 is 4. Same as M2. | D-04, D-02 |
| HP2 "6 becomes 4" | The HP2 row's sum and result. | D-02 |
| HP2 "lift on one tile to cancel" | A tile that breaks the rules never joins, so a chain of 1 tile is the only one that cancels. | D-04, D-06 |
| HP3 | The result goes in the last cell of the chain, tiles above fall, new tiles fill from the top, and the highlight marks exactly the tiles that would join. | D-09, D-40 |
| HP4 | Points are the sum of the tiles, not the result (2, 2, 2 scores 6). Boosters are paid from the score, which never goes below zero. Best Score and Best Tile are kept. | D-18, D-30, D-16, D-17 |
| HP5 row: 1024, 1024 makes 2K | An equal pair. The sum, 2048, is already a power of two. 1024 shows in full and 2048 as "2K". | D-04, D-02, D-31 |
| HP5 "from 2K up" | The first star comes when the run highest tile reaches 2048 and 2 leaves the spawn window. | D-45 |
| HP5 "Every 3 stars make your next booster free" | STARS_PER_FREE_BOOSTER is 3, and the free booster goes to the next booster used. | D-46 |
| HP6 | The five booster names. Costs follow the highest tile. | D-20 |
| HP7 | No valid move means no two touching tiles are equal. The offer follows, and the run ends when nothing is usable or on End run. | D-15, D-19 |

Simplified on purpose. Each of these lines is true but leaves out a rare case:

- HP3 does not say that the merged tile itself can fall (G2).
- HP5 says "a star" for each new highest tile. A jump of two steps at once removes two numbers and earns two stars (CL3). The clear notice shows exactly what happened.
- HP6 "Prices grow as you go": costs follow the highest tile on the board, so hammering the highest tile lowers them again.
- HP7 "If you can't" means no booster is usable.

Reasoning:

- The sections follow the order the player meets the rules: chain, merge, refill, score, moving up, boosters, out of moves.
- Real tiles in the current skin show the player the exact tiles they will play with, including a label like "2K".
- Each example is the simplest one that shows its rule: HP1 a sum that is already a power of two, HP2 the rounding case, HP5 the first star.
- No live numbers, so the text is always right, whatever the state of the run.

