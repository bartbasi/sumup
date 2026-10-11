extends RefCounted
## Helpers for the boosters tests: boards from GDD 19.0 (through the core
## fixtures, read only), session builders and a signal recorder.
## Not a test file: the runner only loads files named test_*.gd.

const F := preload("res://tests/core/core_fixtures.gd")
const NO_CELL: Vector2i = Vector2i(-1, -1)


## Board D1024: Board D with (2,0) = 1024. No valid move, B = 1024.
static func board_d1024() -> PackedInt64Array:
	return F.changed(F.board_d(), {Vector2i(2, 0): 1024})


## The AT-81 setup board: Board D with (2,0) = 1024 and (1,7) = 8. It has a
## valid move (row 7 reads 8, 8, 8, 16, 8). Used as a snapshot worth 40.
static func snapshot_board() -> PackedInt64Array:
	return F.changed(F.board_d(), {Vector2i(2, 0): 1024, Vector2i(1, 7): 8})


static func targets(cells: Array) -> Array[Vector2i]:
	var list: Array[Vector2i] = []
	list.assign(cells)
	return list


static func no_targets() -> Array[Vector2i]:
	var list: Array[Vector2i] = []
	return list


## Every value of a board, sorted.
static func sorted(cells: PackedInt64Array) -> PackedInt64Array:
	var values: PackedInt64Array = cells.duplicate()
	values.sort()
	return values


static func count(cells: PackedInt64Array, value: int) -> int:
	var total: int = 0
	for each: int in cells:
		if each == value:
			total += 1
	return total


static func lowest(cells: PackedInt64Array) -> int:
	var low: int = cells[0]
	for each: int in cells:
		low = mini(low, each)
	return low


## The cell holding value, or (-1, -1).
static func find(cells: PackedInt64Array, value: int) -> Vector2i:
	for index: int in cells.size():
		if cells[index] == value:
			return CoreRules.cell_of(index, F.COLUMNS)
	return NO_CELL


## A session over a copy of the state, resumed and shown, so the move check
## has run. The generator is seeded after the resume so spawns repeat.
static func ready_session(state: RunState, records: Records = null, seed_value: int = 1, config: GameConfig = null) -> GameSession:
	var session: GameSession = GameSession.new(config, RunRandom.new(), records)
	session.resume(state)
	session.rng.set_seed(seed_value)
	session.move_shown()
	return session


static func status_of(session: GameSession, id: StringName) -> BoosterStatus:
	for status: BoosterStatus in session.booster_statuses():
		if status.id == id:
			return status
	return null


## The ids of the usable boosters, in bar order.
static func usable_ids(session: GameSession) -> Array[StringName]:
	var ids: Array[StringName] = []
	for status: BoosterStatus in session.booster_statuses():
		if status.usable:
			ids.append(status.id)
	return ids


## The id marked as suggested, or &"".
static func suggested_id(session: GameSession) -> StringName:
	for status: BoosterStatus in session.booster_statuses():
		if status.suggested:
			return status.id
	return &""


## Records every GameSession signal in order. It holds no reference to the
## session, so the two never keep each other alive.
class Recorder extends RefCounted:
	var names: PackedStringArray = PackedStringArray()
	var started: Array[MoveResult] = []
	var resolved: Array[MoveResult] = []
	var targeting: Array[Array] = []        # [booster_id, swap_first]
	var offers: Array[Array] = []           # [is_open, suggested]
	var summaries: Array[RunSummary] = []

	func watch(session: GameSession) -> void:
		session.run_started.connect(_on_run_started)
		session.move_resolved.connect(_on_move_resolved)
		session.status_changed.connect(_on_status_changed)
		session.targeting_changed.connect(_on_targeting_changed)
		session.offer_changed.connect(_on_offer_changed)
		session.run_ended.connect(_on_run_ended)
		session.save_requested.connect(_on_save_requested)

	func clear() -> void:
		names = PackedStringArray()
		started.clear()
		resolved.clear()
		targeting.clear()
		offers.clear()
		summaries.clear()

	func count(signal_name: String) -> int:
		var total: int = 0
		for each: String in names:
			if each == signal_name:
				total += 1
		return total

	func _on_run_started(result: MoveResult) -> void:
		names.append("run_started")
		started.append(result)

	func _on_move_resolved(result: MoveResult) -> void:
		names.append("move_resolved")
		resolved.append(result)

	func _on_status_changed() -> void:
		names.append("status_changed")

	func _on_targeting_changed(booster_id: StringName, first: Vector2i) -> void:
		names.append("targeting_changed")
		targeting.append([booster_id, first])

	func _on_offer_changed(is_open: bool, suggested: StringName) -> void:
		names.append("offer_changed")
		offers.append([is_open, suggested])

	func _on_run_ended(summary: RunSummary) -> void:
		names.append("run_ended")
		summaries.append(summary)

	func _on_save_requested() -> void:
		names.append("save_requested")
