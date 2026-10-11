class_name BoosterRules extends RefCounted
## The five boosters (GDD section 13): costs, usability, targets, the no moves
## offer's outcome and suggested rescue (12.2), and applying a booster to a
## RunState. All static and pure: no files, nodes, sounds or timers.
##
## A refused booster returns a MoveResult with a refusal and changes nothing:
## not the state, not the records, not the random generator (D-30, TH11).

const HAMMER: StringName = &"hammer"
const SWAP: StringName = &"swap"
const SHUFFLE: StringName = &"shuffle"
const DOUBLE: StringName = &"double"
const UNDO: StringName = &"undo"
const ALL: Array[StringName] = [HAMMER, SWAP, SHUFFLE, DOUBLE, UNDO]

enum Outcome { PLAY, OFFER, END }

const _INT64_MAX: int = 9223372036854775807


## B (D-20, TH3): the larger of the highest tile on the board and COST_BASIS_MIN.
static func cost_basis(cells: PackedInt64Array, config: GameConfig) -> int:
	return maxi(CoreRules.highest(cells), config.cost_basis_min)


## TH3. The booster's cost on the current board: B shifted by its cost_shift
## (D-20). Returns 0 for an unknown id, and 0 for a cost that would pass
## 2^63 minus 1, like CoreRules.merge_result does for a sum that would. Such a
## booster is never affordable (docs/ARCHITECTURE.md section 3).
static func cost(id: StringName, state: RunState, config: GameConfig) -> int:
	return maxi(_raw_cost(id, state.cells, config), 0)


## TH3, D-28 for Undo. Usable when the score covers the cost. Undo also needs a
## snapshot, and the score minus the snapshot's points must cover its cost.
static func usability(id: StringName, state: RunState, config: GameConfig) -> BoosterStatus.Usability:
	var price: int = _raw_cost(id, state.cells, config)
	if id == UNDO:
		if not state.has_snapshot():
			return BoosterStatus.Usability.NO_SNAPSHOT
		if price < 0 or state.snapshot_points < 0 or state.score - state.snapshot_points < price:
			return BoosterStatus.Usability.CANNOT_AFFORD
		return BoosterStatus.Usability.USABLE
	if price < 0 or state.score < price:
		return BoosterStatus.Usability.CANNOT_AFFORD
	return BoosterStatus.Usability.USABLE


## How many tiles the booster needs: Hammer and Double 1, Swap 2, Shuffle and Undo 0.
static func target_count(id: StringName) -> int:
	if id == HAMMER or id == DOUBLE:
		return 1
	if id == SWAP:
		return 2
	return 0


## D-24. True when second may complete a Swap whose first tile is first: both
## are tiles on the board, they are different cells, and their values differ.
static func can_pick_second(state: RunState, first: Vector2i, second: Vector2i) -> bool:
	var first_value: int = state.value_at(first)
	var second_value: int = state.value_at(second)
	return first != second and first_value > 0 and second_value > 0 and first_value != second_value


## TH16, D-42. Shuffle when it is usable, otherwise Undo when it is usable,
## otherwise &"" for none.
static func suggested_rescue(state: RunState, config: GameConfig) -> StringName:
	if usability(SHUFFLE, state, config) == BoosterStatus.Usability.USABLE:
		return SHUFFLE
	if usability(UNDO, state, config) == BoosterStatus.Usability.USABLE:
		return UNDO
	return &""


## D-19, the move check: PLAY when the board has a valid move, else OFFER when
## any booster is usable, else END.
static func outcome(state: RunState, config: GameConfig) -> Outcome:
	if CoreRules.has_valid_move(state.cells, config):
		return Outcome.PLAY
	for id: StringName in ALL:
		if usability(id, state, config) == BoosterStatus.Usability.USABLE:
			return Outcome.OFFER
	return Outcome.END


## TH11. Applies a booster with its targets. Refuses (&"cannot_afford", &"no_snapshot", &"bad_target") and changes nothing when it may not run.
## Usability is checked first, then the targets: Hammer and Double need one
## tile, Swap two tiles of different value (D-24), Shuffle and Undo none. A
## Double whose new value would pass 2^63 minus 1 is a bad target. The cost is
## read from the board before the effect and charged with it (D-21). Hammer,
## Swap, Shuffle and Double leave the Undo snapshot alone; Undo restores it and
## clears it (13.7). Every accepted booster ends with records and this run's
## highest tile (step 7 of D-09, D-41).
static func apply(id: StringName, state: RunState, records: Records, targets: Array[Vector2i], rng: RunRandom, config: GameConfig) -> MoveResult:
	var result: MoveResult = MoveResult.new()
	result.kind = _kind_of(id)
	result.booster_id = id
	result.targets = targets.duplicate()
	result.cells_before = state.cells.duplicate()
	result.cells_after = state.cells.duplicate()
	var refusal: StringName = _refusal(id, state, targets, config)
	if refusal != &"":
		result.refusal = refusal
		result.has_valid_move = CoreRules.has_valid_move(state.cells, config)
		return result

	var price: int = cost(id, state, config)
	match id:
		HAMMER:
			_hammer(state, targets[0], price, result, rng, config)
		SWAP:
			_swap(state, targets[0], targets[1], price, config)
		SHUFFLE:
			_shuffle(state, price, rng, config)
		DOUBLE:
			_double(state, targets[0], price, result, rng, config)
		UNDO:
			_undo(state, price)
	RunRules.update_records(state, records, result)

	result.accepted = true
	result.cost = price
	result.cells_after = state.cells.duplicate()
	result.has_valid_move = CoreRules.has_valid_move(state.cells, config)
	return result


## D-23. Empty the cell, the tiles above fall one cell, one new tile spawns at
## the top of the column. Never clears small tiles (D-39).
static func _hammer(state: RunState, cell: Vector2i, price: int, result: MoveResult, rng: RunRandom, config: GameConfig) -> void:
	state.score -= price
	var board: PackedInt64Array = state.cells.duplicate()
	board[CoreRules.index_of(cell, config.columns)] = 0
	state.cells = board
	result.emptied.append(cell)
	RunRules.settle(state, result, rng, config)


## D-24. The two tiles change places. No gravity, no spawn.
static func _swap(state: RunState, first: Vector2i, second: Vector2i, price: int, config: GameConfig) -> void:
	state.score -= price
	var board: PackedInt64Array = state.cells.duplicate()
	var first_index: int = CoreRules.index_of(first, config.columns)
	var second_index: int = CoreRules.index_of(second, config.columns)
	var kept: int = board[first_index]
	board[first_index] = board[second_index]
	board[second_index] = kept
	state.cells = board


## D-25. Random arrangements until one has a valid move, at most
## SHUFFLE_MAX_ATTEMPTS, then the fallback on the last one. Sets
## rng.shuffle_attempts.
static func _shuffle(state: RunState, price: int, rng: RunRandom, config: GameConfig) -> void:
	state.score -= price
	var arranged: PackedInt64Array = state.cells.duplicate()
	var attempts: int = 0
	var found: bool = false
	while not found and (attempts == 0 or attempts < config.shuffle_max_attempts):
		arranged = rng.shuffle_attempt(state.cells)
		attempts += 1
		found = CoreRules.has_valid_move(arranged, config)
	rng.shuffle_attempts = attempts
	if not found:
		arranged = _shuffle_fallback(arranged, config)
	state.cells = arranged


## The fallback of GDD 13.5. In reading order, P is the first cell whose value
## appears again later and Q the first later cell with that value. Q's tile
## swaps with the tile right of P, or below P when P is in the last column, so
## P and its twin touch. A board with no repeated value is returned unchanged.
static func _shuffle_fallback(cells: PackedInt64Array, config: GameConfig) -> PackedInt64Array:
	var board: PackedInt64Array = cells.duplicate()
	for p: int in board.size():
		for q: int in range(p + 1, board.size()):
			if board[q] != board[p]:
				continue
			var p_cell: Vector2i = CoreRules.cell_of(p, config.columns)
			var neighbor: Vector2i = p_cell + Vector2i(1, 0)
			if p_cell.x == config.columns - 1:
				neighbor = p_cell + Vector2i(0, 1)
			if not CoreRules.in_bounds(neighbor, config):
				return board
			var n: int = CoreRules.index_of(neighbor, config.columns)
			var kept: int = board[n]
			board[n] = board[q]
			board[q] = kept
			return board
	return board


## D-26. The tile doubles in place. If that raised the window floor, small
## tiles clear (D-38) and only then gravity and spawns follow.
static func _double(state: RunState, cell: Vector2i, price: int, result: MoveResult, rng: RunRandom, config: GameConfig) -> void:
	var floor_before: int = CoreRules.window_floor(CoreRules.highest(state.cells), config)
	state.score -= price
	var board: PackedInt64Array = state.cells.duplicate()
	var index: int = CoreRules.index_of(cell, config.columns)
	board[index] = board[index] * 2
	state.cells = board
	result.result_cell = cell
	result.result_value = board[index]
	RunRules.clear_small(state, floor_before, result, config)
	if not result.cleared_small.is_empty():
		RunRules.settle(state, result, rng, config)


## D-27. The board becomes the snapshot board exactly, the score loses the
## snapshot's points and the Undo cost, and the snapshot is cleared. Never
## clears small tiles and never touches the random generator (D-29, D-39).
static func _undo(state: RunState, price: int) -> void:
	state.score = state.score - state.snapshot_points - price
	state.cells = state.snapshot_cells.duplicate()
	state.snapshot_cells = PackedInt64Array()
	state.snapshot_points = 0


## The refusal for this booster call, or &"" when it may run.
static func _refusal(id: StringName, state: RunState, targets: Array[Vector2i], config: GameConfig) -> StringName:
	if not ALL.has(id) or state.columns != config.columns or state.cells.size() != config.cell_count():
		return &"bad_target"
	var usable: BoosterStatus.Usability = usability(id, state, config)
	if usable == BoosterStatus.Usability.NO_SNAPSHOT:
		return &"no_snapshot"
	if usable != BoosterStatus.Usability.USABLE:
		return &"cannot_afford"
	if targets.size() != target_count(id):
		return &"bad_target"
	if id == HAMMER and state.value_at(targets[0]) <= 0:
		return &"bad_target"
	if id == DOUBLE:
		var value: int = state.value_at(targets[0])
		if value <= 0 or value > (_INT64_MAX >> 1):
			return &"bad_target"
	if id == SWAP and not can_pick_second(state, targets[0], targets[1]):
		return &"bad_target"
	return &""


## The cost, or -1 for an unknown id or a cost that would pass 2^63 minus 1.
static func _raw_cost(id: StringName, cells: PackedInt64Array, config: GameConfig) -> int:
	if not ALL.has(id):
		return -1
	var basis: int = cost_basis(cells, config)
	var shift: int = config.cost_shift.get(id, 0)
	if shift < 0:
		return basis >> mini(-shift, 63)
	if shift >= 63 or basis > (_INT64_MAX >> shift):
		return -1
	return basis << shift


static func _kind_of(id: StringName) -> MoveResult.Kind:
	match id:
		HAMMER:
			return MoveResult.Kind.HAMMER
		SWAP:
			return MoveResult.Kind.SWAP
		SHUFFLE:
			return MoveResult.Kind.SHUFFLE
		DOUBLE:
			return MoveResult.Kind.DOUBLE
		UNDO:
			return MoveResult.Kind.UNDO
	return MoveResult.Kind.NEW_RUN
