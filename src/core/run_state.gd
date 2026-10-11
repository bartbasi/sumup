class_name RunState extends RefCounted
## The current run (GDD 15.1): the board, the score, the Undo snapshot and this
## run's highest tile. Plain data with small helpers. Only RunRules,
## BoosterRules and SaveCodec create or change one.
##
## Packed arrays are shared by reference in GDScript, so code that changes a
## board works on a duplicate and assigns it back.

var columns: int = 5
var cells: PackedInt64Array = PackedInt64Array()             # the board, row by row
var score: int = 0
var snapshot_cells: PackedInt64Array = PackedInt64Array()    # Undo snapshot board; empty when there is no snapshot
var snapshot_points: int = 0                                 # the snapshot chain's points
var run_highest: int = 0                                     # D-41


## TH1. Builds a state directly. run_highest 0 means "the highest value on cells".
## The arrays are copied, so the caller may keep changing its own.
@warning_ignore("shadowed_variable")
static func create(cells: PackedInt64Array, score: int, snapshot_cells: PackedInt64Array = PackedInt64Array(), snapshot_points: int = 0, run_highest: int = 0, columns: int = 5) -> RunState:
	var state: RunState = RunState.new()
	state.columns = columns
	state.cells = cells.duplicate()
	state.score = score
	state.snapshot_cells = snapshot_cells.duplicate()
	state.snapshot_points = snapshot_points
	state.run_highest = run_highest if run_highest != 0 else CoreRules.highest(cells)
	return state


func has_snapshot() -> bool:
	return not snapshot_cells.is_empty()


## The value on cell, or 0 when the cell is off the board.
func value_at(cell: Vector2i) -> int:
	if cell.x < 0 or cell.x >= columns or cell.y < 0:
		return 0
	var index: int = CoreRules.index_of(cell, columns)
	if index >= cells.size():
		return 0
	return cells[index]


## H: the highest value on the board.
func highest() -> int:
	return CoreRules.highest(cells)


## A deep copy that shares no arrays with this state.
func copy() -> RunState:
	var other: RunState = RunState.new()
	other.columns = columns
	other.cells = cells.duplicate()
	other.score = score
	other.snapshot_cells = snapshot_cells.duplicate()
	other.snapshot_points = snapshot_points
	other.run_highest = run_highest
	return other


## TH2. True when every field matches.
func equals(other: RunState) -> bool:
	if other == null:
		return false
	return (columns == other.columns
		and cells == other.cells
		and score == other.score
		and snapshot_cells == other.snapshot_cells
		and snapshot_points == other.snapshot_points
		and run_highest == other.run_highest)
