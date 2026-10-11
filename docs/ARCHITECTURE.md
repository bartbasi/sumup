# numbersgame: Architecture

Owner: Development Manager. Status: Phase 2 contract, 2026-10-11.

This is the contract every agent builds against in Phase 3. It names every class each area exposes, every public method and signal with its arguments, the data model, the save format, and how skins and the theme are read. If you need something here changed, stop and ask the Development Manager. Do not change another area's code, and do not invent a public method another area must call.

Sources: docs/BRIEF.md, docs/GDD.md (the rules, approved at Hard Stop 1), docs/DESIGN_SYSTEM.md (the look), CLAUDE.md (ownership and Bart's decisions). Where this document and the GDD disagree on a rule, the GDD wins and this document is a bug: report it.

## 1. Principles

1. **Rules are pure.** Everything in src/core/ and src/boosters/ extends RefCounted, never Node. No scene tree, no Input, no rendering, no files, no timers. Every GDD rule and every test hook (GDD section 20) runs headless in tests/.
2. **The model resolves first, the view catches up.** A move is applied to the model in one call and saved at once (GDD D-09, D-33). Animations play afterwards and never change the outcome. Input waits until the view has shown the move (D-35).
3. **One run, one owner.** GameSession owns the current run, the records, the random generator and the flow state (playing, targeting, offer, ended). Screens read from it and send it intents. Nothing else edits a RunState.
4. **Skins are swappable sets of components.** A SkinData is data. Each skin also has its own board view and its own interface components, all built on shared base classes, so a screen asks for "the HUD for this skin" and gets one with the same methods and signals whatever the skin.
5. **No globals.** No autoloads. The App creates every service once and passes it down through `setup()` calls. This keeps project.godot untouched by feature work and keeps every class testable.
6. **Statically typed GDScript everywhere.** Untyped declarations are compile errors in this project.

## 2. Areas and dependencies

```
            ui (App, screens, panels)
              |        |         |         |
            board    design    audio     save (Settings, SaveCodec, SaveService)
              |        |                   |
            skins -----+                   |
              |                            |
           boosters (BoosterRules, GameSession)
              |                            |
            core (RunState, RunRules, CoreRules, RunRandom, NumberFormat, GameConfig, Records, MoveResult)
```

A line down means "may use". core uses nothing else. boosters uses core. save uses core only. skins uses core (NumberFormat, MoveResult types). design uses core (including BoosterStatus) and skins (SkinData). board uses core, boosters, skins, design (Motion) and audio. ui uses everything. Nothing below may use anything above it, so there are no cycles.

## 3. Conventions

- **Cells.** A cell is `Vector2i(column, row)`. Column 0 is the left, row 0 the top, gravity pulls toward the last row (GDD section 3). `Vector2i(-1, -1)` means "no cell".
- **Board storage.** A board is a `PackedInt64Array` of `columns * rows` values, index `row * columns + column`. Values are powers of two from 2 up. 0 means empty and only exists inside a move, never in a resolved state.
- **Integers are 64 bit** (D-37): tile values, scores, costs and points are `int`.
- **Booster ids** are StringNames, in bar order: `&"hammer"`, `&"swap"`, `&"shuffle"`, `&"double"`, `&"undo"`. Skin ids: `&"gumdrop"` (default), `&"slate"`, `&"nova"`.
- **Global class names.** Every public class below has the listed `class_name`. After adding or renaming a class_name, run `godot --headless --path . --import` once. If another agent runs import at the same moment and you then see "could not find type" errors, run import again. Phase 1 prototype code in tools/ keeps using preload and adds no class names.
- **Signals** are listed with typed arguments. Emit only the signals listed. Connect with typed callables.
- **Errors.** Rules refuse bad input by returning a refused result and changing nothing. They never clamp, never crash, never `assert` on player input. `push_error` is for programming errors only.
- **Overflow.** Real play never comes near 2^63, but a hand edited save can hold tiles up to 2^62. Any move whose tile value, score or points would pass 2^63 minus 1 is refused and changes nothing (core uses `&"invalid_chain"`, boosters `&"bad_target"`). A booster whose cost would pass that limit counts as not affordable. `merge_result` returns 0 for such a sum.
- **Packed arrays are shared.** In Godot 4.7, `var b: PackedInt64Array = a` makes b share a's data, so writing `b[0]` changes `a`. Call `duplicate()` before changing an array you did not create, and assign the result back.

## 4. Data model (src/core/, core-logic-dev)

### GameConfig

Every tunable from GDD section 18. Tests make their own instance to override values (TH4). Everything that needs a constant takes a GameConfig.

```gdscript
class_name GameConfig extends RefCounted
var columns: int = 5                    # BOARD_COLUMNS
var rows: int = 8                       # BOARD_ROWS
var min_chain_length: int = 2           # MIN_CHAIN_LENGTH
var join_radius: float = 0.42           # JOIN_RADIUS, share of the tile pitch (D-07)
var spawn_window_size: int = 4          # SPAWN_WINDOW_SIZE
var spawn_weights: PackedInt32Array = PackedInt32Array([40, 30, 20, 10])   # smallest value first, total 100
var spawn_top_min: int = 16             # SPAWN_TOP_MIN
var spawn_top_divisor: int = 64         # SPAWN_TOP_DIVISOR
var start_board_max_attempts: int = 100 # START_BOARD_MAX_ATTEMPTS
var shuffle_max_attempts: int = 100     # SHUFFLE_MAX_ATTEMPTS
var cost_basis_min: int = 128           # COST_BASIS_MIN
## Each cost is B shifted by this many bits: 0 is B, 1 is 2B, -1 is B/2. Keeps every cost a power of two.
var cost_shift: Dictionary[StringName, int] = {&"hammer": 0, &"swap": 0, &"shuffle": 0, &"double": 1, &"undo": -1}
var label_full_max: int = 1024          # LABEL_FULL_MAX
var label_step: int = 1024              # LABEL_STEP
var label_suffixes: PackedStringArray = PackedStringArray(["K", "M", "B", "T"])   # LABEL_SUFFIXES
func cell_count() -> int                # columns * rows
```

The other section 18 values live elsewhere: SMALLEST_TILE_DP, MIN_LABEL_DIGIT_HEIGHT_DP and SCORE_MIN_CHARACTERS are design values in docs/DESIGN_SYSTEM.md and the SkinData resources, and SOUND_DEFAULT is `Settings.sound_on = true` (section 10). UNDO_DEPTH is 1 and is not configurable.

### RunState

The current run (GDD 15.1). Plain data with small helpers. Only RunRules, BoosterRules and SaveCodec create or change one.

```gdscript
class_name RunState extends RefCounted
var columns: int = 5
var cells: PackedInt64Array             # the board
var score: int = 0
var snapshot_cells: PackedInt64Array    # Undo snapshot board; empty when there is no snapshot
var snapshot_points: int = 0            # the snapshot chain's points
var run_highest: int = 0                # D-41
## TH1. Builds a state directly. run_highest 0 means "the highest value on cells".
static func create(cells: PackedInt64Array, score: int, snapshot_cells: PackedInt64Array = PackedInt64Array(), snapshot_points: int = 0, run_highest: int = 0, columns: int = 5) -> RunState
func has_snapshot() -> bool
func value_at(cell: Vector2i) -> int
func highest() -> int                   # H
func copy() -> RunState                 # deep copy
func equals(other: RunState) -> bool    # TH2 comparisons in tests
```

### Records

Best Score and Best Tile (D-16, D-17). They outlive runs.

```gdscript
class_name Records extends RefCounted
var best_score: int = 0
var best_tile: int = 0
## Step 7 of D-09. Returns true when either record rose.
func update_from(state: RunState) -> bool
func copy() -> Records
```

### MoveResult

What one move did, for tests (TH12) and for the board view's animations. Every move returns one, accepted or refused.

```gdscript
class_name MoveResult extends RefCounted
enum Kind { NEW_RUN, CHAIN, HAMMER, SWAP, SHUFFLE, DOUBLE, UNDO }
var kind: Kind
var accepted: bool = false
var refusal: StringName = &""           # &"" when accepted, else for example &"invalid_chain", &"cannot_afford", &"no_snapshot", &"bad_target", &"not_now"
var booster_id: StringName = &""
var points: int = 0                     # added by a chain (0 for boosters)
var cost: int = 0                       # charged by a booster
var cells_before: PackedInt64Array
var cells_after: PackedInt64Array
var chain: Array[Vector2i] = []         # chain in drag order
var targets: Array[Vector2i] = []       # booster targets as given
var result_cell: Vector2i = Vector2i(-1, -1)   # chain result, or the doubled tile
var result_value: int = 0
var emptied: Array[Vector2i] = []       # chain cells other than the result, or the hammered cell
var floor_before: int = 0
var floor_after: int = 0
var cleared_small: Array[Vector2i] = [] # D-38: cells cleared, in index order
var cleared_values: PackedInt64Array    # D-38: distinct values cleared, ascending (for the clear notice, AT-104)
var fall_from: Array[Vector2i] = []     # gravity: tile at fall_from[i] moved to fall_to[i]
var fall_to: Array[Vector2i] = []
var spawn_cells: Array[Vector2i] = []   # in fill order (D-12)
var spawn_values: PackedInt64Array
var new_best_score: bool = false
var new_best_tile: bool = false
var has_valid_move: bool = true         # after the move (D-15)
var offer_opens: bool = false           # set by GameSession: the no moves offer opens after this move
var run_ends: bool = false              # set by GameSession: the run ends after this move
```

For Swap, `targets` holds both cells. For Shuffle and Undo, the view animates from `cells_before` to `cells_after`.

### BoosterStatus and RunSummary

Value objects GameSession hands to the interface. They live in core so the design and ui areas depend on core only, not on boosters.

```gdscript
class_name BoosterStatus extends RefCounted                 # src/core/booster_status.gd
enum Usability { USABLE, CANNOT_AFFORD, NO_SNAPSHOT }
var id: StringName
var cost: int
var usable: bool
var reason: Usability
var active: bool          # this booster is in targeting mode
var suggested: bool       # marked as the suggested rescue in the no moves offer (D-42)

class_name RunSummary extends RefCounted                    # src/core/run_summary.gd
var final_score: int
var best_score: int
var best_tile: int
var run_highest: int
var new_best_score: bool  # this run set the Best Score (the New best badge)
var no_moves_left: bool   # the run ended because nothing was usable (12.2 step 3)
```

### CoreRules

Pure queries. All static.

```gdscript
class_name CoreRules extends RefCounted
static func index_of(cell: Vector2i, columns: int) -> int
static func cell_of(index: int, columns: int) -> Vector2i
static func in_bounds(cell: Vector2i, config: GameConfig) -> bool
static func touching(a: Vector2i, b: Vector2i) -> bool                       # eight directions, a != b
static func is_power_of_two(value: int) -> bool
static func highest(cells: PackedInt64Array) -> int                          # H
static func merge_result(values: PackedInt64Array) -> int                    # TH15, D-02. 0 for fewer than 2 values
static func spawn_window(h: int, config: GameConfig) -> PackedInt64Array     # D-10, smallest first
static func window_floor(h: int, config: GameConfig) -> int                 # smallest window value
static func draw_value(draw: int, window: PackedInt64Array, config: GameConfig) -> int   # TH9, draw 0 to 99
static func has_valid_move(cells: PackedInt64Array, config: GameConfig) -> bool          # TH13, D-15
static func can_join(cells: PackedInt64Array, chain: Array[Vector2i], next: Vector2i, config: GameConfig) -> bool  # D-04
static func is_valid_chain(cells: PackedInt64Array, chain: Array[Vector2i], config: GameConfig) -> bool  # full check before commit
static func joinable_cells(cells: PackedInt64Array, chain: Array[Vector2i], config: GameConfig) -> Array[Vector2i]  # TH14, D-40
## The chain after the finger reaches cell: a joinable cell is added (D-04), the previous cell backtracks (D-05),
## anything else leaves the chain unchanged. An empty chain starts on any tile. Returns a new array.
static func step_chain(cells: PackedInt64Array, chain: Array[Vector2i], cell: Vector2i, config: GameConfig) -> Array[Vector2i]
```

BoardController builds every chain through `step_chain`, so the joining and backtracking rules (AT-14 to AT-16, AT-106) are tested headless in tests/core/.

### NumberFormat

```gdscript
class_name NumberFormat extends RefCounted
static func tile_label(value: int, config: GameConfig = null) -> String   # TH17, D-31: 1024, 2K, 128K, 1M
static func score(value: int) -> String                                    # TH17, D-32: 1,234,567
```

Costs, the merge preview, Best Tile and the run's highest tile use `tile_label`. Score and Best Score use `score`.

### RunRandom

The run's one generator (GDD 9.5) plus every test override (TH5 to TH8).

```gdscript
class_name RunRandom extends RefCounted
var start_attempts: int = 0             # TH7: attempts the last new_run used
var shuffle_attempts: int = 0           # TH8: attempts the last Shuffle used
func set_seed(new_seed: int) -> void    # TH5
func use_random_seed() -> void          # fresh random seed for a real run
func get_state() -> int                 # TH5
func set_state(state: int) -> void      # TH5
func script_spawns(values: PackedInt64Array) -> void      # TH6: next_spawn uses these before any random draw, in fill order, on every spawn path. start_board_attempt and shuffle_attempt never use them.
func force_start_board(cells: PackedInt64Array) -> void   # TH7: every start attempt returns this board
func force_shuffle(cells: PackedInt64Array) -> void       # TH8: every Shuffle attempt returns this arrangement
func next_spawn(window: PackedInt64Array, config: GameConfig) -> int          # one spawn value
func start_board_attempt(config: GameConfig) -> PackedInt64Array              # one full random board from the starting window
func shuffle_attempt(cells: PackedInt64Array) -> PackedInt64Array             # one random arrangement of the same values
```

### RunRules

The moves that change a RunState. All static. Each returns a MoveResult; a refused move changes nothing.

```gdscript
class_name RunRules extends RefCounted
## D-14. New run: score 0, no snapshot, records updated from the board. Sets rng.start_attempts.
static func new_run(rng: RunRandom, records: Records, config: GameConfig) -> RunState
## D-09 steps 1 to 7 and the valid move check. Refuses with &"invalid_chain" if the chain breaks any rule (TH10).
static func commit_chain(state: RunState, records: Records, chain: Array[Vector2i], rng: RunRandom, config: GameConfig) -> MoveResult
## D-38. Empties every cell below the new floor and records them in result. Used by commit_chain and by Double.
static func clear_small(state: RunState, floor_before: int, result: MoveResult, config: GameConfig) -> void
## Gravity, then spawns into every empty cell (D-11, D-12), recorded in result. Used by chains, Hammer and Double.
static func settle(state: RunState, result: MoveResult, rng: RunRandom, config: GameConfig) -> void
## Step 7 plus D-41: records and run_highest. Sets result.new_best_score and result.new_best_tile.
static func update_records(state: RunState, records: Records, result: MoveResult) -> void
```

`new_run` returns the state; GameSession wraps it in a MoveResult of kind NEW_RUN for the view's spawn animation.

## 5. Boosters and the run flow (src/boosters/, boosters-dev)

### BoosterRules

All static, all pure (GDD section 13).

```gdscript
class_name BoosterRules extends RefCounted
const HAMMER: StringName = &"hammer"
const SWAP: StringName = &"swap"
const SHUFFLE: StringName = &"shuffle"
const DOUBLE: StringName = &"double"
const UNDO: StringName = &"undo"
const ALL: Array[StringName] = [HAMMER, SWAP, SHUFFLE, DOUBLE, UNDO]
enum Outcome { PLAY, OFFER, END }
static func cost_basis(cells: PackedInt64Array, config: GameConfig) -> int          # B (D-20), TH3
static func cost(id: StringName, state: RunState, config: GameConfig) -> int        # TH3
static func usability(id: StringName, state: RunState, config: GameConfig) -> BoosterStatus.Usability   # TH3, D-28 for Undo
static func target_count(id: StringName) -> int                                     # 0, 1 or 2
static func can_pick_second(state: RunState, first: Vector2i, second: Vector2i) -> bool   # D-24 Swap
static func suggested_rescue(state: RunState, config: GameConfig) -> StringName      # TH16, D-42. &"" for none
static func outcome(state: RunState, config: GameConfig) -> Outcome                 # D-19: PLAY if a valid move, else OFFER if anything is usable, else END
## TH11. Applies a booster with its targets. Refuses (&"cannot_afford", &"no_snapshot", &"bad_target") and changes nothing when it may not run.
static func apply(id: StringName, state: RunState, records: Records, targets: Array[Vector2i], rng: RunRandom, config: GameConfig) -> MoveResult
```

Hammer, Swap, Shuffle and Double never touch the snapshot. Undo restores it and clears it (13.7). Shuffle uses `rng.shuffle_attempt` and sets `rng.shuffle_attempts`.

BoosterStatus and RunSummary, the value objects GameSession hands to the interface, live in core (section 4).

### GameSession

The one object that runs a game. RefCounted with signals, so it is fully testable headless.

```gdscript
class_name GameSession extends RefCounted
enum Phase { NONE, PLAYING, TARGETING, OFFER, ENDED }

signal run_started(result: MoveResult)                  # a new run's board exists (kind NEW_RUN)
signal move_resolved(result: MoveResult)                # a chain or booster was applied; the view animates it
signal status_changed()                                 # score, records, costs, usability or phase changed: re-read
signal targeting_changed(booster_id: StringName, swap_first: Vector2i)   # &"" when targeting ends
signal offer_changed(is_open: bool, suggested: StringName)
signal run_ended(summary: RunSummary)
signal save_requested()                                 # save state and records now (D-33)

var config: GameConfig
var rng: RunRandom
var state: RunState                                     # read only outside this class
var records: Records                                    # read only outside this class

func _init(config: GameConfig = null, rng: RunRandom = null, records: Records = null) -> void
func start_new_run() -> void                            # D-14; fresh random seed; emits run_started, status_changed, save_requested
func resume(saved: RunState) -> void                    # D-33 on load; see flow rule 7
func phase() -> Phase
func is_run_in_progress() -> bool                       # phase is PLAYING, TARGETING or OFFER
func is_offer_open() -> bool                            # phase OFFER, or TARGETING entered from the offer
func is_waiting_for_view() -> bool                      # D-35: true from a resolved move until move_shown()
func can_start_chain() -> bool                          # PLAYING, not waiting for the view, no drag open
func begin_drag() -> bool                               # a finger started a chain; false (and no drag) unless can_start_chain()
func end_drag() -> void                                 # the drag ended by commit, cancel, pause or focus loss
func is_dragging() -> bool
func preview_value(chain: Array[Vector2i]) -> int       # D-03, 0 hides the preview
func joinable_cells(chain: Array[Vector2i]) -> Array[Vector2i]   # D-40
func commit_chain(chain: Array[Vector2i]) -> MoveResult # refused with &"not_now" outside PLAYING or while waiting
func press_booster(id: StringName) -> MoveResult        # see below; null when no move happened
func tap_cell(cell: Vector2i) -> MoveResult             # targeting taps (D-43); null when no move happened
func cancel_targeting() -> void                         # back button, pause, focus loss (13.1)
func end_run() -> void                                  # End run in the offer (D-19 step 7)
func move_shown() -> void                               # the view finished showing the last move
func booster_statuses() -> Array[BoosterStatus]         # in bar order, fresh every call
func targeting_booster() -> StringName
func swap_first() -> Vector2i
```

Flow rules GameSession must follow:

1. **When input counts.** While `is_waiting_for_view()` is true, while a drag is open, and in phases NONE and ENDED, `commit_chain` is refused with `&"not_now"` and `press_booster` and `tap_cell` return null and change nothing (D-08, D-35, 13.1). `commit_chain` also needs PLAYING. `commit_chain` ends the open drag itself, so the board calls it while dragging.
2. **Resolve and save at once.** `commit_chain`, an instant booster and a targeting tap apply the move through RunRules or BoosterRules, set the session to waiting, emit `move_resolved`, `status_changed` and `save_requested` in that order, and return the result. The save happens before any animation (D-33).
3. **Outcome after the view.** `move_shown()` clears the waiting flag and runs `BoosterRules.outcome`:
   - PLAY: phase PLAYING. If the offer was open, emit `offer_changed(false, &"")`.
   - OFFER: phase OFFER, emit `offer_changed(true, suggested)` with usability and the suggested rescue worked out afresh (12.2 step 6).
   - END: phase ENDED, emit `offer_changed(false, &"")` if it was open, then `run_ended(summary)`. Do not emit `save_requested`: the run is over and must never be written again.
   - `move_resolved` results already carry `offer_opens` and `run_ends`, so tests can read the outcome without a view.
4. **Booster taps (13.1).** `press_booster` on an unusable booster does nothing.
   - Shuffle or Undo applies at once. If another booster is targeting, that targeting is cancelled first with nothing charged (AT-63).
   - Hammer, Swap or Double enters TARGETING and emits `targeting_changed(id, Vector2i(-1, -1))`. The same booster again cancels; a different usable targeting booster switches (nothing charged).
   - From OFFER: Shuffle and Undo apply at once. Hammer, Swap and Double enter TARGETING with the offer still open (`is_offer_open()` stays true, no `offer_changed`). The offer panel replaces the HUD, not the board, so the board stays tappable (DESIGN_SYSTEM.md 7.5).
5. **Leaving targeting.** Cancelling (`cancel_targeting`, the same booster again) emits `targeting_changed(&"", Vector2i(-1, -1))`. If the offer is open, the phase returns to OFFER and emits `offer_changed(true, suggested)` worked out afresh; otherwise it returns to PLAYING. A booster that resolves from targeting goes through rules 2 and 3, which close the offer (PLAY), refresh it (OFFER) or end the run (END).
6. **Targeting taps (D-43).** In TARGETING, `tap_cell` applies Hammer or Double to that cell, or records Swap's first cell (emits `targeting_changed` with it), deselects it when tapped again, or applies Swap on a valid second cell. A refused second Swap pick does nothing.
7. **Resume (D-33, 9.5).** `resume(saved)` takes a fresh random seed (`rng.use_random_seed()`), updates the records from the board (step 7), and emits `run_started` with a NEW_RUN result whose `cells_before` and `cells_after` are the loaded board and whose `spawn_cells` is empty, so the view shows it without a spawn animation. It then sets the session waiting like any move, so `move_shown()` runs the move check and opens the offer if there is no valid move (GO7). `start_new_run()` does the same with `spawn_cells` holding all 40 cells.
8. **Run end.** On `run_ended` the App deletes the saved run and saves the profile (12.3). Records were already saved with the last move.
9. GameSession never reads or writes files, never plays sounds, never touches nodes.

## 6. Skins (src/skins/, tile-board-artist)

### SkinData

Godot already has a native class named Skin (for skeletons), so the skin resource class is SkinData.

One Resource class, one `.tres` per skin, values exactly as docs/DESIGN_SYSTEM.md specifies (Bart's decision: the senior-graphic-designer specifies, the tile-board-artist writes the files, the senior-graphic-designer reviews). The token names and meanings come from the DESIGN_SYSTEM.md shared schema; skin only extras live in the same dictionaries under their own names.

```gdscript
class_name SkinData extends Resource
@export var id: StringName
@export var display_name: String
@export var palette: Dictionary[StringName, Color]          # named colors
@export var tile_fill: PackedColorArray                     # values 2 to 131072, 17 entries
@export var tile_ink: PackedColorArray                      # number color for each fill
@export var beyond_fill: Color                              # rule above 131072, as DESIGN_SYSTEM.md defines it
@export var beyond_ink: Color
@export var tile_tier: PackedInt32Array                     # tier per value 2 to 131072, 17 entries; what a tier changes is per skin
@export var beyond_tier: int
@export var text_pairs: Array[Dictionary]                   # every text color on background pair the screens may use
@export var font_path: String                               # "" for the system font, else a res:// font file
@export var system_font_names: PackedStringArray            # used when font_path is ""
@export var type_roles: Dictionary[StringName, Dictionary]  # display, title, body, label, tile: size, weight, tracking, case
@export var tile_number_scale: PackedFloat32Array           # tile label size by label length, share of the tile side
@export var numbers: Dictionary[StringName, float]          # spacing, radii, sizes, shares
@export var motion: Dictionary[StringName, Dictionary]      # name to {duration, trans, ease, plus extras}
func fill_for(value: int) -> Color
func ink_for(value: int) -> Color
func tier_for(value: int) -> int
func color(token: StringName) -> Color
func num(token: StringName) -> float
func motion_spec(motion_name: StringName) -> Dictionary
func duration(motion_name: StringName) -> float
func font(role: StringName) -> Font                         # cached FontVariation; weight applied through the wght axis tag
func font_size(role: StringName) -> int
func tile_font_size(tile_side: float, label: String) -> int  # by label length, then shrunk until the label fits label_fit of the side (DESIGN_SYSTEM.md 2.5)
func score_font_size(text: String, max_width: float) -> int # display size, shrunk to fit max_width, never below display_fit_min (2.6)
func cased(role: StringName, text: String) -> String
func validate() -> PackedStringArray                        # every schema token present; empty when valid
```

A missing token is a bug: the getter calls `push_error` once and returns a visible fallback (magenta for colors, 0 for numbers). `validate()` lets tests catch it first.

Fonts: Gumdrop and Nova point `font_path` at `res://src/design/fonts/Outfit[wght].ttf`. Slate leaves it empty and uses `system_font_names` (Roboto first). The variable weight axis is set by its integer tag (`TextServerManager.get_primary_interface().name_to_tag("wght")`), because the string key is ignored in Godot 4.7 (found in Phase 1).

### SkinCatalog

```gdscript
class_name SkinCatalog extends RefCounted
const DEFAULT_ID: StringName = &"gumdrop"
const IDS: Array[StringName] = [&"gumdrop", &"slate", &"nova"]   # settings order
static func get_skin(id: StringName) -> SkinData                     # unknown id returns the default
static func make_board_view(skin: SkinData) -> SkinBoardView
static func make_tile_view(skin: SkinData) -> SkinTileView
```

Files: `src/skins/skin.gd`, `src/skins/skin_catalog.gd`, `src/skins/skin_board_view.gd`, `src/skins/skin_tile_view.gd`, and per skin `src/skins/<id>/<id>.tres` plus `src/skins/<id>/<id>_board_view.gd`, `<id>_tile_view.gd` and any helpers.

### SkinBoardView (base class) and per skin board views

Draws the board, tiles, chain line, preview, highlights and effects. Holds no rules: the board controller tells it everything. Each skin subclasses it and implements every method.

```gdscript
class_name SkinBoardView extends Control
func setup(skin: SkinData, columns: int, rows: int) -> void
func set_board(cells: PackedInt64Array) -> void                 # static look, complete in the first frame
func set_chain(chain: Array[Vector2i], drag_point: Vector2) -> void   # drag_point in local pixels; Vector2(-1, -1) for none; empty chain clears
func set_preview(value: int) -> void                            # 0 hides it; a skin that shows the preview in the HUD draws nothing
func set_joinable(cells: Array[Vector2i]) -> void               # D-40 highlight
func set_targeting(booster_id: StringName) -> void              # &"" ends targeting
func set_pressed_cell(cell: Vector2i) -> void                   # D-43 press feedback; (-1, -1) for none
func set_swap_selected(cell: Vector2i) -> void                  # Swap's first tile; (-1, -1) for none
func cell_rect(cell: Vector2i) -> Rect2                         # local rect of a tile
func grid_origin() -> Vector2                                   # local top left corner of cell (0, 0)'s pitch box
func cell_pitch() -> Vector2                                    # distance between neighboring cell centers
func preferred_height(width: float) -> float
## Effects. Each starts at once and returns its length in seconds. After the last one, the controller calls set_board(cells_after).
func play_spawn(cells: Array[Vector2i], values: PackedInt64Array) -> float
func play_merge(chain: Array[Vector2i], result_cell: Vector2i, result_value: int) -> float
func play_clear(cells: Array[Vector2i]) -> float                # D-38 small tiles, and the Hammer
func play_fall(from_cells: Array[Vector2i], to_cells: Array[Vector2i]) -> float
func play_value_change(cell: Vector2i, value: int) -> float     # Double
func play_swap(a: Vector2i, b: Vector2i) -> float
func play_rearrange(cells_after: PackedInt64Array) -> float     # Shuffle and Undo
```

### SkinTileView (base class)

One tile on its own, for the settings skin chips, the merge preview in a HUD slot, and the end of run screen.

```gdscript
class_name SkinTileView extends Control
func setup(skin: SkinData) -> void
func set_value(value: int) -> void
```

## 7. Theme, icons and motion (src/design/, ui-motion-artist)

Every interface component exists once per skin, in `src/design/<id>/`, subclassing a shared base class in `src/design/`. Screens create them only through UiKit.

```gdscript
class_name UiKit extends RefCounted
static func build_theme(skin: SkinData) -> Theme
static func make_hud(skin: SkinData) -> SkinHud
static func make_booster_bar(skin: SkinData) -> SkinBoosterBar
static func make_icon(skin: SkinData) -> SkinIcon
static func make_toggle(skin: SkinData) -> SkinToggle
static func make_backdrop(skin: SkinData) -> SkinBackdrop
static func make_icon_button(skin: SkinData, icon_name: StringName) -> BaseButton   # a touch_min square button with the skin icon drawn on its face; emits pressed
```

**Theme.** `build_theme` sets the default font to the body role and defines these type variations in every skin: DisplayLabel, TitleLabel, BodyLabel, MutedLabel, CaptionLabel, PrimaryButton, SecondaryButton, ChipButton, CardPanel, PillPanel, HintPanel, Hairline, IconButton, BadgePanel, BadgeLabel, SignalLabel, HintLabel. SignalLabel takes the title role case, except Slate, where it takes the label role. A Theme cannot set text case or alignment, so screens apply `skin.cased()` themselves and left align Slate's primary buttons. UiKit factories return components already set up. Buttons have normal, hover, pressed, disabled and focus styles. The App sets the theme on its root Control, so every screen and panel inherits it.

```gdscript
class_name SkinHud extends Control
signal pause_pressed()                                    # the HUD's pause button
func setup(skin: SkinData) -> void
func set_scores(score: int, best_score: int) -> void
func set_context(text: String, highlight: bool) -> void   # a skin that has no context row ignores it
func preview_slot() -> Control                            # where the screen puts a SkinTileView preview; null when the skin previews on the board
func score_label() -> Label                               # for Motion.count_up
## D-38 clear notice (AT-104). Builds its own copy from DESIGN_SYSTEM.md 7.10 and places itself:
## Gumdrop and Nova on the board's top edge (board_rect is global), Slate in its context row.
## Never blocks input; a later call replaces a notice still showing.
func show_clear_notice(cleared_values: PackedInt64Array, board_rect: Rect2) -> void
func preferred_height() -> float

class_name SkinBoosterBar extends Control
signal booster_pressed(booster_id: StringName)
func setup(skin: SkinData) -> void
func show_boosters(statuses: Array[BoosterStatus]) -> void
func set_hint(text: String) -> void                       # targeting hint; "" hides it; a skin that shows the hint in the HUD ignores it
func content_top() -> float
func preferred_height() -> float

class_name SkinIcon extends Control
const LOOK_NORMAL: int = 0
const LOOK_ACTIVE: int = 1
const LOOK_DISABLED: int = 2
func setup(skin: SkinData) -> void
func set_icon(icon_name: StringName) -> void              # names listed in DESIGN_SYSTEM.md
func set_look(look: int) -> void
func set_color(color: Color) -> void

class_name SkinToggle extends Control
signal toggled(on: bool)
func setup(skin: SkinData) -> void
func set_on(on: bool, animate: bool = false) -> void

class_name SkinBackdrop extends Control
func setup(skin: SkinData) -> void
func set_clear_rects(rects: Array[Rect2]) -> void         # global rects kept clear of decoration behind text
```

**Motion.** Static helpers that read every duration, transition and ease from the skin, so nobody hardcodes a timing.

```gdscript
class_name Motion extends RefCounted
static func tween_for(node: Node, skin: SkinData, motion_name: StringName) -> Tween
static func press(control: Control, skin: SkinData) -> Tween
static func release(control: Control, skin: SkinData) -> Tween
static func dialog_in(control: Control, skin: SkinData) -> Tween
static func dialog_out(control: Control, skin: SkinData) -> Tween
static func fade(item: CanvasItem, skin: SkinData, to_alpha: float) -> Tween
static func count_up(label: Label, skin: SkinData, from_value: int, to_value: int) -> Tween   # formats with NumberFormat.score
static func pulse(item: CanvasItem, skin: SkinData) -> Tween        # null when the skin has no pulse
static func stop_pulse(item: CanvasItem) -> void
```

**Font files.** `src/design/fonts/Outfit[wght].ttf` and `src/design/fonts/OFL.txt`, unmodified, from the official Google Fonts repository. They are the only third party files in the repo (Bart's decision) and are logged in docs/ASSETS.md.

## 8. Board and input (src/board/, scenes/board/, board-input-dev)

```gdscript
class_name BoardGeometry extends RefCounted
## TH19, D-07. The cell whose center is within join_radius * min(pitch.x, pitch.y) of point, else (-1, -1).
## Skins keep tiles square, so the two pitches are normally equal.
static func cell_at(point: Vector2, grid_origin: Vector2, pitch: Vector2, columns: int, rows: int, join_radius: float) -> Vector2i
static func cell_center(cell: Vector2i, grid_origin: Vector2, pitch: Vector2) -> Vector2

class_name BoardController extends Control                 # root of scenes/board/board.tscn
signal chain_changed(chain: Array[Vector2i], preview_value: int)   # every add, backtrack, commit and cancel
signal animation_finished()                                 # after the last effect of a move
func setup(session: GameSession, skin: SkinData, audio: AudioService) -> void
func set_skin(skin: SkinData) -> void                           # live switch: rebuild the skin board view, keep the board
func cancel_drag() -> void                                  # drop a chain in progress with no penalty; calls session.end_drag()
func preferred_height(width: float) -> float
func is_animating() -> bool
```

What BoardController does:

- **Input.** Touch and mouse through one code path. Handle InputEventScreenTouch and InputEventScreenDrag, and InputEventMouseButton and InputEventMouseMotion only when they are not emulated from touch (`event.device != InputEvent.DEVICE_ID_EMULATION`), so a phone never sees each touch twice. Only the first finger counts (D-08).
- **Chains.** A finger down outside targeting calls `session.begin_drag()`; if that returns false, the touch is ignored. The chain grows through `CoreRules.step_chain` with hit tests from `BoardGeometry.cell_at` (D-04 to D-07). The board shows the preview from `session.preview_value`, the joinable highlight from `session.joinable_cells`, and emits `chain_changed`. On release it calls `session.commit_chain` with a chain of 2 or more (D-06), or clears the chain and calls `session.end_drag()`. `cancel_drag()` does the same clearing; the App calls it when Pause opens and on focus loss. Chain input is ignored while targeting.
- **Click sound (D-36).** `audio.play_click()` for every tile added to a chain, including the first, and once when a commit is accepted. Never on backtrack or cancel.
- **Targeting (D-43).** In TARGETING, a finger down shows `set_pressed_cell`; lifting on the same tile calls `session.tap_cell`; lifting elsewhere does nothing. Mirrors `targeting_changed` into `set_targeting` and `set_swap_selected`.
- **Animation sequencing.** On `run_started` and `move_resolved`, plays the effects in GDD order (merge, clear, fall, spawn; or the booster's effect, then fall and spawn), waits for their returned lengths, calls `set_board(result.cells_after)`, then `session.move_shown()` and emits `animation_finished`. Uses the skin's motion timings only.
- **Layout.** Fills the rect the screen gives it. The skin board view works out tile size and gaps from its own tokens; the controller never hardcodes colors, sizes or timings.

## 9. Audio (src/audio/, audio-dev)

```gdscript
class_name ClickSynth extends RefCounted
static func build(mix_rate: int = 44100) -> AudioStreamWAV  # 16 bit mono, 50 to 90 ms, soft attack, quick decay, peak below full scale

class_name AudioService extends Node
var click_requests: int = 0                                 # TH20: every play_click call, on or off
func set_enabled(on: bool) -> void
func is_enabled() -> bool
func play_click() -> void                                   # does nothing audible when disabled
```

The App adds one AudioService node and passes it to whoever needs it. The App sets `set_enabled` from Settings at start and on every change. No other sounds in v1.

## 10. Save and settings (src/save/, ui-systems-dev)

### Settings

Settings lives in src/save/ so the save code depends on nothing above it.

```gdscript
class_name Settings extends RefCounted                      # src/save/settings.gd
signal sound_changed(on: bool)
signal skin_changed(skin_id: StringName)
var sound_on: bool = true
var skin_id: StringName = &"gumdrop"
func set_sound_on(on: bool) -> void                         # emits only on change
func set_skin_id(id: StringName) -> void                    # emits only on change
```

### Save format

Two JSON files in `user://`. JSON only, written and read with Godot's JSON class. Godot's JSON parser returns every number as a float, which cannot hold 64 bit integers exactly, so:

- Tile values are stored as exponents (2 is 1, 1024 is 10, 2^62 is 62).
- Scores, points and Best Score are stored as strings of decimal digits.

`user://run.json`, deleted when the run ends:

```json
{
  "format": 1,
  "columns": 5,
  "rows": 8,
  "cells": [1, 4, 2, "... 40 exponents ..."],
  "score": "41286",
  "run_highest": 11,
  "snapshot": null
}
```

`snapshot` is null or `{"cells": [40 exponents], "points": "96"}`.

`user://profile.json`, kept forever:

```json
{
  "format": 1,
  "settings": {"sound_on": true, "skin": "gumdrop"},
  "records": {"best_score": "96520", "best_tile": 12}
}
```

`best_tile` is 0 for no tile yet, else an exponent.

### Validation and safety rules

- Never use str_to_var, bytes_to_var, bytes_to_var_with_objects, FileAccess.get_var, ConfigFile, ResourceLoader, load() or anything else that can create objects from file data.
- Read at most 64 KB; a larger file is invalid. Parse with `JSON.new().parse(text)`; any parse error is invalid.
- Check every field: type, exact keys, ranges. `format` is 1. `columns` and `rows` equal the GameConfig (5 and 8). Exponents are whole numbers from 1 to 62 (best_tile 0 to 62); a float like 1.5 is invalid. Digit strings are 1 to 19 characters of 0 to 9, with no leading zero unless the string is "0", and fit in a signed 64 bit int. The run follows GDD 15.1 exactly: 40 cells, score of 0 or more, run_highest at least the highest value on the board and on the snapshot board, snapshot points of 4 or more. The skin id must be 1 to 32 characters of a to z and underscore; the App turns an unknown id into the default through `SkinCatalog.get_skin`, so save code never depends on skins.
- An invalid run file: discard the run, start a new one, keep valid settings and records. An invalid profile: use defaults for the invalid part, keep the valid part. Never crash, never show a raw error.
- Atomic writes: write the whole file to `<name>.tmp` in user://, close it, then rename it over the real file. Check what rename does on Windows and Android when the target exists, and handle it so a kill at any moment leaves either the old file or the new one.

```gdscript
class_name SaveCodec extends RefCounted
const FORMAT: int = 1
static func run_to_data(state: RunState) -> Dictionary
static func data_to_run(data: Variant, config: GameConfig) -> RunState           # TH18; null when invalid
static func profile_to_data(settings: Settings, records: Records) -> Dictionary
static func data_to_profile(data: Variant, settings: Settings, records: Records) -> PackedStringArray   # applies valid parts, returns problems

class_name SaveService extends RefCounted
func _init(directory: String = "user://") -> void           # tests pass a temp folder
func save_run(state: RunState) -> bool
func load_run(config: GameConfig) -> RunState                # null when missing or invalid
func delete_run() -> void
func has_run() -> bool
func save_profile(settings: Settings, records: Records) -> bool
func load_profile(settings: Settings, records: Records) -> void
```

## 11. Screens and app flow (src/ui/, scenes/ui/, ui-systems-dev)

### Scenes

- `scenes/main.tscn` (DM): the project's main scene. It only instances `scenes/ui/app.tscn`.
- `scenes/ui/app.tscn`: App, the root. Everything else is created under it.
- `scenes/ui/game_screen.tscn`, `main_menu.tscn`, `pause_panel.tscn`, `settings_panel.tscn`, `offer_panel.tscn`, `end_panel.tscn`, `confirm_dialog.tscn`.
- `scenes/board/board.tscn`: BoardController.

### Classes

```gdscript
class_name App extends Control
## Creates GameConfig, Records, Settings, SaveService, AudioService and GameSession once.
## Loads the profile and the saved run, routes between screens, applies the skin theme,
## saves on save_requested and on lifecycle events, and handles the back button.

class_name GameScreen extends Control
func setup(session: GameSession, settings: Settings, audio: AudioService, skin: SkinData) -> void
func apply_skin(skin: SkinData) -> void                          # live switch: rebuild backdrop, HUD, booster bar, board view
func board() -> BoardController
signal pause_requested()                                     # HUD pause button

class_name MainMenu extends Control
signal new_game_chosen()
signal settings_chosen()
func setup(skin: SkinData, records: Records) -> void

class_name PausePanel extends Control
signal resume_chosen()
signal new_game_chosen()
signal settings_chosen()
func setup(skin: SkinData) -> void

class_name SettingsPanel extends Control
signal closed()
func setup(skin: SkinData, settings: Settings) -> void           # sound toggle and skin picker with live preview chips

class_name OfferPanel extends Control
signal booster_chosen(booster_id: StringName)
signal end_run_chosen()
func setup(skin: SkinData) -> void
func show_offer(statuses: Array[BoosterStatus], score: int) -> void   # D-19, suggested marked per D-42

class_name EndPanel extends Control
signal new_game_chosen()
signal main_menu_chosen()
func setup(skin: SkinData) -> void
func show_summary(summary: RunSummary) -> void               # final score, Best Score, Best Tile, this run's highest tile, New game

class_name ConfirmDialog extends Control
signal confirmed()
signal cancelled()
func setup(skin: SkinData, title: String, body: String, confirm_text: String, cancel_text: String) -> void

class_name SafeArea extends RefCounted
static func viewport_safe_rect(viewport: Viewport) -> Rect2  # display safe area mapped into viewport coordinates
```

### Flow

1. **Start (Bart's decision).** App loads the profile and sets the theme for `settings.skin_id`. If a valid run is saved, it goes straight to GameScreen and calls `session.resume(saved)`. Otherwise it shows MainMenu. MainMenu also follows a finished run (EndPanel's Main menu), so it never sees a saved run.
2. **New game** calls `session.start_new_run()`. From Pause, while a run is in progress, it asks through ConfirmDialog first (D-34).
3. **Play.** GameScreen shows Backdrop, HUD, BoardController and BoosterBar for the current skin, laid out inside the safe area as DESIGN_SYSTEM.md arranges it. It re-reads `session.booster_statuses()` on `status_changed`, mirrors scores into the HUD, and passes `chain_changed` to the HUD context row and preview slot for skins that use them.
4. **Clear notice.** When a `move_resolved` result has `cleared_values`, GameScreen calls `hud.show_clear_notice(result.cleared_values, board_global_rect)` (AT-104).
5. **Offer.** While `session.is_offer_open()`, OfferPanel takes the HUD's place (DESIGN_SYSTEM.md 7.5); the board and booster bar stay visible and usable. Its buy button and the booster bar both call `session.press_booster`. End run calls `session.end_run()`. GameScreen shows the panel on `offer_changed(true, ...)`, refreshes it on every `status_changed`, and restores the HUD on `offer_changed(false, ...)`.
6. **End.** On `run_ended` the App deletes the saved run, saves the profile and shows EndPanel. It never saves a run unless `session.is_run_in_progress()` is true.
7. **Settings.** Reached from MainMenu and PausePanel. Sound calls `settings.set_sound_on`; a skin chip calls `settings.set_skin_id`. The App listens: sound goes to `audio.set_enabled`; a skin change rebuilds the theme and calls `apply_skin` on every live screen and panel. Both save the profile.
8. **Saving.** On `save_requested` the App saves the run (only while `session.is_run_in_progress()`) and the profile at once. It also saves on NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT and NOTIFICATION_WM_CLOSE_REQUEST, after calling `board.cancel_drag()` and `session.cancel_targeting()` (13.1).
9. **Pause.** Opening PausePanel by any route (the HUD pause button or the back button) first calls `board.cancel_drag()` and `session.cancel_targeting()` (13.1). Pause offers Resume, New game and Settings (DESIGN_SYSTEM.md 7.3). The main menu is reached at launch and from the end of run screen.
10. **Back button.** The App sets `get_tree().quit_on_go_back = false` and handles NOTIFICATION_WM_GO_BACK_REQUEST in this order: cancel targeting; else close the top panel (ConfirmDialog, SettingsPanel, PausePanel, where closing Pause resumes); else on GameScreen (offer included) open PausePanel; else on MainMenu or EndPanel quit after saving.

## 12. How skins and the theme are read

- **Which skin.** `settings.skin_id`, default `SkinCatalog.DEFAULT_ID`. `SkinCatalog.get_skin(id)` returns the SkinData.
- **Board.** BoardController asks `SkinCatalog.make_board_view(skin)` and talks to it only through SkinBoardView.
- **Interface components.** Screens ask UiKit for the HUD, booster bar, icons, toggle and backdrop of the current skin and use only the base class methods.
- **Theme.** App sets `UiKit.build_theme(skin)` on its root Control. Panels use the Theme's type variations and never set colors or sizes themselves.
- **Tokens elsewhere.** Anything else reads `skin.color()`, `skin.num()`, `skin.font()`, `skin.font_size()`, `skin.cased()` and `Motion`. No literal color, size or timing appears outside src/skins/ and src/design/.
- **Live switch.** On `settings.skin_changed`, the App rebuilds the theme and every screen calls `apply_skin`, which frees the old skinned components and creates new ones. The board keeps its state; only its look changes. The App cross-fades: before rebuilding it shows a still of the current frame (from the viewport texture) in a full screen TextureRect on top, then fades that still out over the new skin's `skin_switch` motion (DESIGN_SYSTEM.md 7.7).
- **Checks.** In Phase 3 the contrast and label checks in tools/ move from the Phase 1 token files to the SkinData resources, so they prove what ships.

## 13. Test hooks (GDD section 20)

| Hook | Where |
|---|---|
| TH1 build a state | `RunState.create`, `Records` fields |
| TH2 read it back | RunState and Records fields, `RunState.equals` |
| TH3 derived values | `CoreRules.highest`, `BoosterRules.cost_basis`, `CoreRules.spawn_window`, `CoreRules.window_floor`, `BoosterRules.cost`, `BoosterRules.usability` |
| TH4 override constants | a GameConfig instance passed to every call |
| TH5 seed and state | `RunRandom.set_seed`, `get_state`, `set_state` |
| TH6 scripted spawns | `RunRandom.script_spawns` |
| TH7 forced starting boards | `RunRandom.force_start_board`, `start_attempts` |
| TH8 forced Shuffle | `RunRandom.force_shuffle`, `shuffle_attempts` |
| TH9 weighted draw | `CoreRules.draw_value` |
| TH10 commit any chain | `RunRules.commit_chain` (refused result changes nothing) |
| TH11 call any booster | `BoosterRules.apply` (refused result changes nothing) |
| TH12 move result | MoveResult |
| TH13 valid move | `CoreRules.has_valid_move` |
| TH14 joinable cells | `CoreRules.joinable_cells` |
| TH15 merge result | `CoreRules.merge_result` |
| TH16 suggested rescue | `BoosterRules.suggested_rescue` |
| TH17 formats | `NumberFormat.tile_label`, `NumberFormat.score` |
| TH18 save and load | `SaveCodec`, `SaveService` with a temp directory |
| TH19 hit test | `BoardGeometry.cell_at` |
| TH20 click count | `AudioService.click_requests` |

Each area's tests live in `tests/<area>/` and extend `res://tests/base_test.gd`. Name a test after the acceptance test it covers where one exists, for example `test_at_36_twelve_twos_clear_and_refill`.

## 14. Project settings and platform

- No autoloads. No input map entries: the board reads touch and mouse events directly, and the back button arrives as a notification.
- platform-dev owns display, stretch and Android settings, the export preset named `Android` (excluding tools/, tests/ and docs/), and the build and install scripts. Release builds request no permissions.
- The launcher icon: `tools/launcher_icon.gd` (senior-graphic-designer) draws it from the Gumdrop SkinData values and writes the four PNGs of DESIGN_SYSTEM.md 9.1 to `launcher/` at the repo root. Only that tool writes there. The PNGs are committed, so a build never depends on running the tool, and docs/ASSETS.md logs them as generated by code. platform-dev points the export preset's launcher icon settings and the project icon at them.

## 15. Phase 3 order

Everyone builds against this contract, in three waves, so each agent can run its own tests against real code below it:

1. **Wave 1:** core-logic-dev (all of src/core/, including BoosterStatus and RunSummary), audio-dev, and the senior-graphic-designer (the checks move to the SkinData resources; the launcher icon tool).
2. **Wave 2, once core is committed:** boosters-dev (BoosterRules, GameSession), tile-board-artist (per skin board and tile views, SkinCatalog factories), ui-motion-artist (UiKit, Theme, icons, Motion), and ui-systems-dev (Settings, SaveCodec, SaveService).
3. **Wave 3, once boosters is committed:** board-input-dev (BoardController, BoardGeometry) and ui-systems-dev (App, screens and panels).

Core logic and boosters must reach full unit test coverage of the GDD rules before they are integrated. Integration in Phase 4 follows the same order, and the DM wires scenes/main.tscn last.
