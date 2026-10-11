extends "res://tests/base_test.gd"
## Merge result (D-02, D-03), spawn window and floor (D-10), the weighted draw
## (TH9) and the move check (D-15), through CoreRules and RunRandom.

const F := preload("res://tests/core/core_fixtures.gd")

var config: GameConfig


func before_each() -> void:
	config = GameConfig.new()


# Merge result

## GDD 7.2, M1 to M10: chain values, result, points.
const MERGE_EXAMPLES: Array[Array] = [
	["M1", [2, 2], 4, 4],
	["M2", [2, 2, 2], 4, 6],
	["M3", [4, 4, 8], 16, 16],
	["M4", [2, 2, 2, 2, 2], 8, 10],
	["M5", [2, 2, 4, 8, 16, 32], 64, 64],
	["M6", [8, 8, 8, 16, 16, 32], 64, 88],
	["M7", [2, 2, 2, 2, 2, 2, 2, 2, 4, 4, 8], 32, 32],
	["M8", [2, 2, 4, 4, 4, 8, 8, 16], 32, 48],
	["M9", [512, 512, 1024, 1024], 2048, 3072],
	["M10", [64, 64, 64, 64], 256, 256],
]


func test_merge_result_worked_examples_m1_to_m10() -> void:
	for example: Array in MERGE_EXAMPLES:
		var values: PackedInt64Array = PackedInt64Array(example[1])
		assert_eq(CoreRules.merge_result(values), example[2], "%s result" % example[0])


func test_merge_result_needs_two_values() -> void:
	assert_eq(CoreRules.merge_result(PackedInt64Array()), 0, "no values")
	assert_eq(CoreRules.merge_result(PackedInt64Array([2])), 0, "one value")
	assert_eq(CoreRules.merge_result(PackedInt64Array([1024])), 0, "one big value")


func test_merge_result_rounds_down_between_powers() -> void:
	assert_eq(CoreRules.merge_result(PackedInt64Array([2, 2, 2, 2, 2, 2, 2])), 8, "14 rounds down to 8")
	assert_eq(CoreRules.merge_result(PackedInt64Array([8, 8, 8, 8, 8, 8, 8, 8])), 64, "64 is already a power of two")
	assert_eq(CoreRules.merge_result(PackedInt64Array([16, 16, 32, 32])), 64, "96 rounds down to 64")
	assert_eq(CoreRules.merge_result(PackedInt64Array([16, 16, 32, 32, 32])), 128, "128 is already a power of two")
	assert_eq(CoreRules.merge_result(PackedInt64Array([16, 16, 32, 32, 32, 32, 64])), 128, "224 rounds down to 128")


func test_merge_result_large_values_stay_exact() -> void:
	assert_eq(CoreRules.merge_result(PackedInt64Array([131072, 131072])), 262144, "128K pair")
	assert_eq(CoreRules.merge_result(PackedInt64Array([131072, 131072, 262144, 262144])), 524288, "128K chain")
	assert_eq(CoreRules.merge_result(PackedInt64Array([1 << 60, 1 << 60])), 1 << 61, "2^60 pair")
	assert_eq(CoreRules.merge_result(PackedInt64Array([1 << 61, 1 << 61])), 1 << 62, "2^61 pair, the largest result that fits")
	assert_eq(CoreRules.merge_result(PackedInt64Array([1 << 60, 1 << 60, 1 << 61, 1 << 61])), 1 << 62, "6 x 2^60 rounds down to 2^62")


## Guard beyond D-37: a sum past the signed 64 bit range has no tile to hold it.
func test_merge_result_past_64_bits_gives_no_result() -> void:
	assert_eq(CoreRules.merge_result(PackedInt64Array([1 << 62, 1 << 62])), 0, "2^63 does not fit")
	assert_eq(CoreRules.merge_result(PackedInt64Array([1 << 62, 1 << 62, 1 << 62, 1 << 62, 1 << 62])), 0, "a wrapped sum is not trusted")


## GDD 7.3: the preview while dragging M8 one tile at a time.
func test_preview_table_for_m8() -> void:
	var values: PackedInt64Array = PackedInt64Array([2, 2, 4, 4, 4, 8, 8, 16])
	var expected: PackedInt64Array = PackedInt64Array([0, 4, 8, 8, 16, 16, 32, 32])
	for length: int in range(1, values.size() + 1):
		assert_eq(CoreRules.merge_result(values.slice(0, length)), expected[length - 1], "step %d" % length)
	assert_eq(CoreRules.merge_result(values.slice(0, 7)), 32, "after the backtrack off the 16")


func test_at_27_result_facts_for_random_chains() -> void:
	var checked: int = 0
	for seed_value: int in range(1, 10001):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_value
		var value: int = 1 << rng.randi_range(1, 20)
		var values: PackedInt64Array = PackedInt64Array([value, value])
		var length: int = rng.randi_range(2, 40)
		while values.size() < length:
			if rng.randi_range(0, 1) == 1:
				value *= 2
			values.append(value)
		var total: int = 0
		for each: int in values:
			total += each
		var result: int = CoreRules.merge_result(values)
		var last: int = values[values.size() - 1]
		if not CoreRules.is_power_of_two(result) or result > total or result * 2 <= total or result < last * 2:
			fail("seed %d: values %s sum %d gave %d" % [seed_value, values, total, result])
			return
		checked += 1
	assert_eq(checked, 10000, "every chain checked")


# Spawn window and floor

func test_at_34_spawn_window_by_highest_tile() -> void:
	var cases: Array[Array] = [
		[2, [2, 4, 8, 16]],
		[16, [2, 4, 8, 16]],
		[1024, [2, 4, 8, 16]],
		[2048, [4, 8, 16, 32]],
		[4096, [8, 16, 32, 64]],
		[131072, [256, 512, 1024, 2048]],
		[1048576, [2048, 4096, 8192, 16384]],
	]
	for case: Array in cases:
		var h: int = case[0]
		var expected: PackedInt64Array = PackedInt64Array(case[1])
		var board: PackedInt64Array = F.changed(F.board_d(), {Vector2i(2, 0): h}) if h > 16 else F.board_all(h)
		assert_eq(CoreRules.highest(board), h, "H %d" % h)
		assert_eq(CoreRules.spawn_window(CoreRules.highest(board), config), expected, "window for H %d" % h)
	var empty: PackedInt64Array = PackedInt64Array()
	empty.resize(40)
	assert_eq(CoreRules.highest(empty), 0, "an empty board has no H")
	assert_eq(CoreRules.spawn_window(CoreRules.highest(empty), config), PackedInt64Array([2, 4, 8, 16]), "empty board")


func test_spawn_window_table_of_gdd_9_1() -> void:
	var h: int = 2048
	var bottom: int = 4
	while h <= 1 << 40:
		var window: PackedInt64Array = CoreRules.spawn_window(h, config)
		assert_eq(window, PackedInt64Array([bottom, bottom * 2, bottom * 4, bottom * 8]), "window for H %d" % h)
		h *= 2
		bottom *= 2
	for low: int in [0, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024]:
		assert_eq(CoreRules.spawn_window(low, config), PackedInt64Array([2, 4, 8, 16]), "starting window for H %d" % low)


func test_window_floor_is_2_until_2048_then_h_over_512() -> void:
	for h: int in [0, 2, 16, 512, 1024]:
		assert_eq(CoreRules.window_floor(h, config), 2, "floor for H %d" % h)
	for power: int in range(11, 62):
		var h: int = 1 << power
		assert_eq(CoreRules.window_floor(h, config), h >> 9, "floor for H 2^%d" % power)


## GDD 9.2, S1 to S4: the window that applies when spawning, from H after the move.
func test_window_timing_examples_s1_to_s4() -> void:
	assert_eq(CoreRules.spawn_window(2048, config), PackedInt64Array([4, 8, 16, 32]), "S1")
	assert_eq(CoreRules.spawn_window(1024, config), PackedInt64Array([2, 4, 8, 16]), "S2")
	assert_eq(CoreRules.spawn_window(2048, config), PackedInt64Array([4, 8, 16, 32]), "S3")
	assert_eq(CoreRules.spawn_window(131072, config), PackedInt64Array([256, 512, 1024, 2048]), "S4")


func test_spawn_window_follows_config_overrides() -> void:
	config.spawn_top_min = 32
	assert_eq(CoreRules.spawn_window(0, config), PackedInt64Array([4, 8, 16, 32]), "SPAWN_TOP_MIN 32")
	config.spawn_top_divisor = 16
	assert_eq(CoreRules.spawn_window(1024, config), PackedInt64Array([8, 16, 32, 64]), "SPAWN_TOP_DIVISOR 16")
	config.spawn_window_size = 3
	assert_eq(CoreRules.spawn_window(1024, config), PackedInt64Array([16, 32, 64]), "SPAWN_WINDOW_SIZE 3")
	assert_eq(CoreRules.window_floor(1024, config), 16, "floor follows")


# Weighted draw

func test_at_35_spawn_weights() -> void:
	var window: PackedInt64Array = CoreRules.spawn_window(1024, config)
	var draws: PackedInt64Array = PackedInt64Array([0, 39, 40, 69, 70, 89, 90, 99])
	var mapped: PackedInt64Array = PackedInt64Array()
	for draw: int in draws:
		mapped.append(CoreRules.draw_value(draw, window, config))
	assert_eq(mapped, PackedInt64Array([2, 2, 4, 4, 8, 8, 16, 16]), "(a) draw numbers to values")
	var rng: RunRandom = F.seeded(35)
	var counts: Dictionary[int, int] = {2: 0, 4: 0, 8: 0, 16: 0}
	for draw: int in 100000:
		var value: int = rng.next_spawn(window, config)
		if not counts.has(value):
			fail("value %d is outside the window" % value)
			return
		counts[value] += 1
	var shares: Dictionary[int, float] = {2: 40.0, 4: 30.0, 8: 20.0, 16: 10.0}
	for value: int in shares:
		var share: float = counts[value] * 100.0 / 100000.0
		assert_near(share, shares[value], 1.0, "(b) share of %d" % value)


func test_draw_value_follows_weight_overrides() -> void:
	config.spawn_weights = PackedInt32Array([25, 25, 25, 25])
	var window: PackedInt64Array = PackedInt64Array([2, 4, 8, 16])
	assert_eq(CoreRules.draw_value(24, window, config), 2, "first quarter")
	assert_eq(CoreRules.draw_value(25, window, config), 4, "second quarter")
	assert_eq(CoreRules.draw_value(99, window, config), 16, "last quarter")


# Move check

func test_at_45_move_check() -> void:
	assert_false(CoreRules.has_valid_move(F.board_d(), config), "V1: Board D has none")
	assert_true(CoreRules.has_valid_move(F.changed(F.board_d(), {Vector2i(2, 0): 4}), config), "V2: side by side")
	assert_true(CoreRules.has_valid_move(F.changed(F.board_d(), {Vector2i(1, 1): 2}), config), "V3: diagonal")
	assert_true(CoreRules.has_valid_move(F.changed(F.board_d(), {Vector2i(0, 0): 8}), config), "V4: one above the other")
	assert_false(CoreRules.has_valid_move(F.changed(F.board_d(), {Vector2i(0, 0): 4096, Vector2i(2, 0): 4096}), config), "V5: two cells apart")


func test_move_check_boards_e_and_d1024_have_none() -> void:
	assert_false(CoreRules.has_valid_move(F.board_e(), config), "Board E")
	assert_false(CoreRules.has_valid_move(F.changed(F.board_d(), {Vector2i(2, 0): 1024}), config), "Board D1024")
	assert_true(CoreRules.has_valid_move(F.board_p(), config), "Board P")


func test_move_check_finds_each_direction_alone() -> void:
	var pairs: Array[Array] = [
		["right", Vector2i(1, 2), Vector2i(2, 2)],
		["below", Vector2i(3, 4), Vector2i(3, 5)],
		["lower right", Vector2i(0, 6), Vector2i(1, 7)],
		["lower left", Vector2i(1, 0), Vector2i(0, 1)],
		["corner diagonal", Vector2i(4, 7), Vector2i(3, 6)],
		["top right corner", Vector2i(4, 0), Vector2i(3, 1)],
	]
	for pair: Array in pairs:
		var a: Vector2i = pair[1]
		var b: Vector2i = pair[2]
		var board: PackedInt64Array = F.changed(F.board_d(), {a: 64, b: 64})
		assert_eq(F.equal_pairs(board).size(), 2, "%s: exactly one pair on the board" % pair[0])
		assert_true(CoreRules.has_valid_move(board, config), "%s: found" % pair[0])


func test_move_check_ignores_row_wrap() -> void:
	var board: PackedInt64Array = F.changed(F.board_d(), {Vector2i(4, 0): 64, Vector2i(0, 1): 64})
	assert_true(F.equal_pairs(board).is_empty(), "the two 64s do not touch")
	assert_false(CoreRules.has_valid_move(board, config), "no move across the row wrap")
	var bottom_wrap: PackedInt64Array = F.changed(F.board_d(), {Vector2i(4, 6): 64, Vector2i(0, 7): 64})
	assert_false(CoreRules.has_valid_move(bottom_wrap, config), "no move across the wrap near the bottom")


func test_move_check_full_boards_and_large_values() -> void:
	assert_true(CoreRules.has_valid_move(F.board_all(2), config), "Board A2")
	assert_true(CoreRules.has_valid_move(F.board_all(4), config), "Board A4")
	assert_true(CoreRules.has_valid_move(F.changed(F.board_d(), {Vector2i(0, 7): 131072, Vector2i(1, 7): 131072}), config), "a 128K pair")
	assert_true(CoreRules.has_valid_move(F.changed(F.board_d(), {Vector2i(2, 3): 1 << 62, Vector2i(3, 4): 1 << 62}), config), "a 2^62 pair")
	assert_false(CoreRules.has_valid_move(F.changed(F.board_d(), {Vector2i(2, 3): 1 << 62, Vector2i(3, 4): 1 << 61}), config), "2^62 next to 2^61")


func test_move_check_never_pairs_empty_cells() -> void:
	var board: PackedInt64Array = F.changed(F.board_d(), {Vector2i(0, 0): 0, Vector2i(1, 0): 0})
	assert_false(CoreRules.has_valid_move(board, config), "two empty cells are not a pair")
	assert_false(CoreRules.has_valid_move(PackedInt64Array([2, 2]), config), "a board of the wrong size has no move")


func test_highest_of_boards() -> void:
	assert_eq(CoreRules.highest(F.board_d()), 16, "Board D")
	assert_eq(CoreRules.highest(F.board_p()), 32, "Board P")
	assert_eq(CoreRules.highest(F.board_e()), 32, "Board E")
	assert_eq(CoreRules.highest(F.changed(F.board_d(), {Vector2i(4, 7): 1 << 62})), 1 << 62, "2^62")
	assert_eq(CoreRules.highest(PackedInt64Array()), 0, "no cells")
