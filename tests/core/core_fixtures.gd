extends RefCounted
## Test boards from GDD section 19.0 and small helpers for the core tests.
## Not a test file: the runner only loads files named test_*.gd.
## Every board function returns a new array, so tests never share one.

const COLUMNS: int = 5
const ROWS: int = 8


## Board D: no valid move, H = 16.
static func board_d() -> PackedInt64Array:
	return PackedInt64Array([
		2, 4, 2, 4, 2,
		8, 16, 8, 16, 8,
		2, 4, 2, 4, 2,
		8, 16, 8, 16, 8,
		2, 4, 2, 4, 2,
		8, 16, 8, 16, 8,
		2, 4, 2, 4, 2,
		8, 16, 8, 16, 8,
	])


## Board P: the example board of GDD 6.6, H = 32.
static func board_p() -> PackedInt64Array:
	return PackedInt64Array([
		2, 4, 2, 4, 2,
		8, 16, 8, 16, 8,
		2, 4, 2, 4, 2,
		8, 16, 8, 16, 8,
		2, 4, 2, 4, 2,
		8, 4, 8, 16, 8,
		2, 2, 2, 4, 2,
		8, 8, 32, 8, 8,
	])


## Board E: no valid move, H = 32, no 2s.
static func board_e() -> PackedInt64Array:
	return PackedInt64Array([
		4, 16, 4, 16, 4,
		8, 32, 8, 32, 8,
		4, 16, 4, 16, 4,
		8, 32, 8, 32, 8,
		4, 16, 4, 16, 4,
		8, 32, 8, 32, 8,
		4, 16, 4, 16, 4,
		8, 32, 8, 32, 8,
	])


## Board A2 (value 2) or Board A4 (value 4): every cell holds value.
static func board_all(value: int) -> PackedInt64Array:
	var board: PackedInt64Array = PackedInt64Array()
	board.resize(COLUMNS * ROWS)
	board.fill(value)
	return board


## A copy of board with the listed cells changed. changes maps Vector2i to int.
static func changed(board: PackedInt64Array, changes: Dictionary) -> PackedInt64Array:
	var result: PackedInt64Array = board.duplicate()
	for cell: Vector2i in changes:
		var value: int = changes[cell]
		result[cell.y * COLUMNS + cell.x] = value
	return result


## A copy of board with one column replaced, values listed top to bottom.
static func with_column(board: PackedInt64Array, column: int, values: PackedInt64Array) -> PackedInt64Array:
	var result: PackedInt64Array = board.duplicate()
	for row: int in ROWS:
		result[row * COLUMNS + column] = values[row]
	return result


## The values of one column, top to bottom.
static func column_of(board: PackedInt64Array, column: int) -> PackedInt64Array:
	var values: PackedInt64Array = PackedInt64Array()
	for row: int in ROWS:
		values.append(board[row * COLUMNS + column])
	return values


static func at(board: PackedInt64Array, cell: Vector2i) -> int:
	return board[cell.y * COLUMNS + cell.x]


static func values_of(board: PackedInt64Array, chain: Array[Vector2i]) -> PackedInt64Array:
	var values: PackedInt64Array = PackedInt64Array()
	for cell: Vector2i in chain:
		values.append(at(board, cell))
	return values


## A copy of board with values written along path, in order.
static func placed(board: PackedInt64Array, path: Array[Vector2i], values: PackedInt64Array) -> PackedInt64Array:
	var result: PackedInt64Array = board.duplicate()
	for position: int in path.size():
		var cell: Vector2i = path[position]
		result[cell.y * COLUMNS + cell.x] = values[position]
	return result


## The first count cells of a snake that runs row 0 left to right, row 1
## right to left, and so on down the board.
static func snake_from_top(count: int) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	for row: int in ROWS:
		for step: int in COLUMNS:
			var column: int = step if row % 2 == 0 else COLUMNS - 1 - step
			if path.size() < count:
				path.append(Vector2i(column, row))
	return path


## The first count cells of a snake that runs row 7 left to right, row 6
## right to left, and so on up the board.
static func snake_from_bottom(count: int) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	for climb: int in ROWS:
		var row: int = ROWS - 1 - climb
		for step: int in COLUMNS:
			var column: int = step if climb % 2 == 0 else COLUMNS - 1 - step
			if path.size() < count:
				path.append(Vector2i(column, row))
	return path


## Every touching pair of equal tiles, worked out by brute force without
## CoreRules. Pairs are flattened: [a0, b0, a1, b1, ...], a before b in index order.
@warning_ignore("integer_division")
static func equal_pairs(board: PackedInt64Array) -> Array[Vector2i]:
	var pairs: Array[Vector2i] = []
	for first: int in board.size():
		for second: int in range(first + 1, board.size()):
			var a: Vector2i = Vector2i(first % COLUMNS, first / COLUMNS)
			var b: Vector2i = Vector2i(second % COLUMNS, second / COLUMNS)
			if absi(a.x - b.x) <= 1 and absi(a.y - b.y) <= 1 and board[first] == board[second] and board[first] > 0:
				pairs.append(a)
				pairs.append(b)
	return pairs


static func state(board: PackedInt64Array, score: int) -> RunState:
	return RunState.create(board, score)


static func records(best_score: int, best_tile: int) -> Records:
	var result: Records = Records.new()
	result.best_score = best_score
	result.best_tile = best_tile
	return result


static func seeded(seed_value: int) -> RunRandom:
	var rng: RunRandom = RunRandom.new()
	rng.set_seed(seed_value)
	return rng


## True when every value in board is one of allowed.
static func all_in(values: PackedInt64Array, allowed: PackedInt64Array) -> bool:
	for value: int in values:
		if not allowed.has(value):
			return false
	return true
