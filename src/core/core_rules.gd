class_name CoreRules extends RefCounted
## Pure queries on boards and chains. All static.
##
## Covers adjacency, the joining and backtracking rules (GDD 6.1, 6.2), the
## joinable highlight (6.7), the merge result (7.1), the spawn window and the
## weighted draw (9.1) and the move check (12.1). A board is a PackedInt64Array
## in row order (docs/ARCHITECTURE.md section 3). Off board cells and empty
## cells (0) never take part in a chain or a pair.

## Steps from a cell to the four neighbors that cover every touching pair
## exactly once (GDD 12.1): right, lower left, below and lower right.
const _PAIR_STEPS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]

const _INT64_MAX: int = 9223372036854775807


static func index_of(cell: Vector2i, columns: int) -> int:
	return cell.y * columns + cell.x


@warning_ignore("integer_division")
static func cell_of(index: int, columns: int) -> Vector2i:
	return Vector2i(index % columns, index / columns)


static func in_bounds(cell: Vector2i, config: GameConfig) -> bool:
	return cell.x >= 0 and cell.x < config.columns and cell.y >= 0 and cell.y < config.rows


## Two different cells whose column and row each differ by at most 1 (eight directions).
static func touching(a: Vector2i, b: Vector2i) -> bool:
	return a != b and absi(a.x - b.x) <= 1 and absi(a.y - b.y) <= 1


static func is_power_of_two(value: int) -> bool:
	return value > 0 and (value & (value - 1)) == 0


## H: the highest value on the board, 0 for an empty board.
static func highest(cells: PackedInt64Array) -> int:
	var top: int = 0
	for value: int in cells:
		if value > top:
			top = value
	return top


## TH15, D-02. The largest power of two that is not more than the sum of
## values, worked out with integer bit operations. 0 for fewer than 2 values.
## Also 0 when the sum does not fit in a signed 64 bit integer, because no
## tile could hold the result (D-37 says real play never gets there).
static func merge_result(values: PackedInt64Array) -> int:
	if values.size() < 2:
		return 0
	return _round_down_to_power_of_two(_sum_of(values))


## The sum of values, or -1 when a value is not positive or the sum does not
## fit in a signed 64 bit integer. Internal to core: RunRules uses it too.
static func _sum_of(values: PackedInt64Array) -> int:
	var total: int = 0
	for value: int in values:
		if value <= 0 or total > _INT64_MAX - value:
			return -1
		total += value
	return total


## D-10. The spawn window for highest tile h, smallest value first. Top is the
## larger of SPAWN_TOP_MIN and h / SPAWN_TOP_DIVISOR, and each value below it
## is half the next. An empty board (h of 0) gets the starting window.
@warning_ignore("integer_division")
static func spawn_window(h: int, config: GameConfig) -> PackedInt64Array:
	var top: int = config.spawn_top_min
	if config.spawn_top_divisor > 0:
		top = maxi(top, h / config.spawn_top_divisor)
	var size: int = maxi(1, config.spawn_window_size)
	var window: PackedInt64Array = PackedInt64Array()
	for position: int in size:
		window.append(top >> (size - 1 - position))
	return window


## The window floor: the smallest value in the spawn window for h.
static func window_floor(h: int, config: GameConfig) -> int:
	return spawn_window(h, config)[0]


## TH9. Maps one draw (0 to 99 with the default weights) to a window value:
## the first value whose running weight total is above the draw.
static func draw_value(draw: int, window: PackedInt64Array, config: GameConfig) -> int:
	var count: int = mini(window.size(), config.spawn_weights.size())
	if count == 0:
		return 0
	var limit: int = 0
	for position: int in count:
		limit += config.spawn_weights[position]
		if draw < limit:
			return window[position]
	return window[count - 1]


## TH13, D-15. True when two touching tiles have the same value.
static func has_valid_move(cells: PackedInt64Array, config: GameConfig) -> bool:
	if cells.size() != config.cell_count():
		return false
	for row: int in config.rows:
		for column: int in config.columns:
			var cell: Vector2i = Vector2i(column, row)
			var value: int = cells[index_of(cell, config.columns)]
			if value <= 0:
				continue
			for step: Vector2i in _PAIR_STEPS:
				if _value(cells, cell + step, config) == value:
					return true
	return false


## D-04. True when next would join chain if the finger reached it now. An
## empty chain accepts any tile.
static func can_join(cells: PackedInt64Array, chain: Array[Vector2i], next: Vector2i, config: GameConfig) -> bool:
	var value: int = _value(cells, next, config)
	if value <= 0:
		return false
	if chain.is_empty():
		return true
	var last: Vector2i = chain[chain.size() - 1]
	if not touching(last, next) or chain.has(next):
		return false
	var last_value: int = _value(cells, last, config)
	if chain.size() == 1:
		return value == last_value
	return value == last_value or value == last_value * 2


## The full check before a commit (GDD 6.1): at least MIN_CHAIN_LENGTH and 2
## cells, all on the board and all different, each touching the one before,
## the second value equal to the first, every later value equal to the one
## before it or double it.
static func is_valid_chain(cells: PackedInt64Array, chain: Array[Vector2i], config: GameConfig) -> bool:
	if cells.size() != config.cell_count():
		return false
	if chain.size() < 2 or chain.size() < config.min_chain_length:
		return false
	var seen: Dictionary[Vector2i, bool] = {}
	var previous_value: int = 0
	for position: int in chain.size():
		var cell: Vector2i = chain[position]
		var value: int = _value(cells, cell, config)
		if value <= 0 or seen.has(cell):
			return false
		seen[cell] = true
		if position == 1 and value != previous_value:
			return false
		if position > 1 and value != previous_value and value != previous_value * 2:
			return false
		if position > 0 and not touching(chain[position - 1], cell):
			return false
		previous_value = value
	return true


## TH14, D-40. Every tile that would join the chain if the finger moved onto
## it now, in index order. Empty for an empty chain.
static func joinable_cells(cells: PackedInt64Array, chain: Array[Vector2i], config: GameConfig) -> Array[Vector2i]:
	var joinable: Array[Vector2i] = []
	if chain.is_empty():
		return joinable
	var last: Vector2i = chain[chain.size() - 1]
	for row: int in range(last.y - 1, last.y + 2):
		for column: int in range(last.x - 1, last.x + 2):
			var cell: Vector2i = Vector2i(column, row)
			if can_join(cells, chain, cell, config):
				joinable.append(cell)
	return joinable


## The chain after the finger reaches cell: a joinable cell is added (D-04), the previous cell backtracks (D-05),
## anything else leaves the chain unchanged. An empty chain starts on any tile. Returns a new array.
static func step_chain(cells: PackedInt64Array, chain: Array[Vector2i], cell: Vector2i, config: GameConfig) -> Array[Vector2i]:
	var stepped: Array[Vector2i] = chain.duplicate()
	if stepped.size() >= 2 and cell == stepped[stepped.size() - 2]:
		stepped.pop_back()
	elif can_join(cells, stepped, cell, config):
		stepped.append(cell)
	return stepped


## The value on cell, or 0 when the cell is off the board or the board is short.
static func _value(cells: PackedInt64Array, cell: Vector2i, config: GameConfig) -> int:
	if not in_bounds(cell, config):
		return 0
	var index: int = index_of(cell, config.columns)
	if index >= cells.size():
		return 0
	return cells[index]


## The largest power of two that is not more than value, or 0 when value is not positive.
static func _round_down_to_power_of_two(value: int) -> int:
	if value <= 0:
		return 0
	var power: int = 1
	while power <= (value >> 1):
		power <<= 1
	return power
