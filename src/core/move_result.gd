class_name MoveResult extends RefCounted
## What one move did, for tests (TH12) and for the board view's animations.
## Every move returns one, accepted or refused. A refused move changes nothing.

enum Kind { NEW_RUN, CHAIN, HAMMER, SWAP, SHUFFLE, DOUBLE, UNDO }

var kind: Kind
var accepted: bool = false
var refusal: StringName = &""           # &"" when accepted, else for example &"invalid_chain", &"cannot_afford", &"no_snapshot", &"bad_target", &"not_now"
var booster_id: StringName = &""
var points: int = 0                     # added by a chain (0 for boosters)
var cost: int = 0                       # charged by a booster
var cells_before: PackedInt64Array = PackedInt64Array()
var cells_after: PackedInt64Array = PackedInt64Array()
var chain: Array[Vector2i] = []         # chain in drag order
var targets: Array[Vector2i] = []       # booster targets as given
var result_cell: Vector2i = Vector2i(-1, -1)   # chain result, or the doubled tile
var result_value: int = 0
var emptied: Array[Vector2i] = []       # chain cells other than the result, or the hammered cell
var floor_before: int = 0
var floor_after: int = 0
var cleared_small: Array[Vector2i] = [] # D-38: cells cleared, in index order
var cleared_values: PackedInt64Array = PackedInt64Array()    # D-38: distinct values cleared, ascending (for the clear notice, AT-104)
var fall_from: Array[Vector2i] = []     # gravity: tile at fall_from[i] moved to fall_to[i]
var fall_to: Array[Vector2i] = []
var spawn_cells: Array[Vector2i] = []   # in fill order (D-12)
var spawn_values: PackedInt64Array = PackedInt64Array()
var new_best_score: bool = false
var new_best_tile: bool = false
var has_valid_move: bool = true         # after the move (D-15)
var offer_opens: bool = false           # set by GameSession: the no moves offer opens after this move
var run_ends: bool = false              # set by GameSession: the run ends after this move
