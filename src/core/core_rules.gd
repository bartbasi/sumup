class_name CoreRules extends RefCounted
## Pure queries on boards and chains. All static.
##
## Covers adjacency, the joining and backtracking rules (GDD 6.1, 6.2), the
## joinable highlight (6.7), the merge result (7.1), the spawn window and the
## weighted draw (9.1), the move check (12.1), and stars and free boosters
## (11.5, 13.9). A board is a PackedInt64Array in row order
## (docs/ARCHITECTURE.md section 3). Off board cells and empty cells (0) never
## take part in a chain or a pair.
##
## The 64 bit limit (D-37, SEC-01) has one fit test, _fits_sum. Joining, the
## full chain check, the move check and RunRules.commit_chain all use it, so
## what the player can drag, what counts as a move and what commits agree.

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
		if not _fits_sum(total, value):
			return -1
		total += value
	return total


## The one fit test (D-37, SEC-01): true when total is 0 or more, value is
## positive, and total plus value stays at or below 2^63 minus 1. Internal to
## core: RunRules uses it for the chain's sum and for the score after it.
static func _fits_sum(total: int, value: int) -> bool:
	return total >= 0 and value > 0 and total <= _INT64_MAX - value


## SEC-01. True when value + value fits in 64 bits: for powers of two, 2^61
## or less. False for 0 and negative values. It is _fits_sum, the same test
## joining, the move check and commit_chain use; boosters use it too.
static func pair_fits(value: int) -> bool:
	return _fits_sum(value, value)


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


## TH3, D-45. How many times the window floor of run_highest has doubled above
## the floor of an empty board (2 with the GDD 18 values). So 0 up to 1024,
## then log2(run_highest) minus 10: 2048 gives 1, 131072 gives 7, 2^62 gives
## 52. It follows the spawn constants, and never goes down as run_highest rises.
static func stars(run_highest: int, config: GameConfig) -> int:
	var base: int = window_floor(0, config)
	var reached: int = window_floor(run_highest, config)
	if base <= 0:
		return 0
	var count: int = 0
	var level: int = base
	while level <= (reached >> 1):
		level <<= 1
		count += 1
	return count


## TH3, D-46. Free boosters earned: stars divided by STARS_PER_FREE_BOOSTER,
## rounded down. 0 when that constant is not positive.
@warning_ignore("integer_division")
static func free_earned(run_highest: int, config: GameConfig) -> int:
	if config.stars_per_free_booster <= 0:
		return 0
	return stars(run_highest, config) / config.stars_per_free_booster


## TH3, D-46. Free boosters held: earned from state.run_highest minus
## state.free_used. A valid run never uses more than it earned (GDD 15.1), so
## this is 0 or more for every state the save code accepts.
static func free_held(state: RunState, config: GameConfig) -> int:
	return free_earned(state.run_highest, config) - state.free_used


## D-45. Every value that leaves the spawn window when the floor rises from
## floor_before to floor_after, ascending: floor_before, its double, and so on
## below floor_after. Empty when the floor did not rise. Internal to core:
## RunRules.clear_small fills MoveResult.notice_values with it.
static func _left_window(floor_before: int, floor_after: int) -> PackedInt64Array:
	var values: PackedInt64Array = PackedInt64Array()
	var value: int = floor_before
	while value > 0 and value < floor_after:
		values.append(value)
		if value > (_INT64_MAX >> 1):
			break
		value <<= 1
	return values


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


## TH13, D-15. True when two touching tiles have the same value and their sum
## fits in 64 bits (a value of 2^61 or less, SEC-01). A longer chain from a
## pair only adds to its sum, so a pair that does not fit is no move at all.
static func has_valid_move(cells: PackedInt64Array, config: GameConfig) -> bool:
	if cells.size() != config.cell_count():
		return false
	for row: int in config.rows:
		for column: int in config.columns:
			var cell: Vector2i = Vector2i(column, row)
			var value: int = cells[index_of(cell, config.columns)]
			if not pair_fits(value):
				continue
			for step: Vector2i in _PAIR_STEPS:
				if _value(cells, cell + step, config) == value:
					return true
	return false


## D-04. True when next would join chain if the finger reached it now. An
## empty chain accepts any tile. A tile that would take the chain's sum past
## 2^63 minus 1 never joins (condition 5, SEC-01).
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
		if value != last_value:
			return false
	elif value != last_value and value != last_value * 2:
		return false
	return _fits_sum(_sum_of(_chain_values(cells, chain, config)), value)


## The full check before a commit (GDD 6.1): at least MIN_CHAIN_LENGTH and 2
## cells, all on the board and all different, each touching the one before,
## the second value equal to the first, every later value equal to the one
## before it or double it, and a sum that fits in 64 bits (D-37).
static func is_valid_chain(cells: PackedInt64Array, chain: Array[Vector2i], config: GameConfig) -> bool:
	if cells.size() != config.cell_count():
		return false
	if chain.size() < 2 or chain.size() < config.min_chain_length:
		return false
	var seen: Dictionary[Vector2i, bool] = {}
	var previous_value: int = 0
	var total: int = 0
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
		if not _fits_sum(total, value):
			return false
		total += value
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


## The values on the chain's cells, in order. Off board cells give 0.
static func _chain_values(cells: PackedInt64Array, chain: Array[Vector2i], config: GameConfig) -> PackedInt64Array:
	var values: PackedInt64Array = PackedInt64Array()
	for cell: Vector2i in chain:
		values.append(_value(cells, cell, config))
	return values


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
