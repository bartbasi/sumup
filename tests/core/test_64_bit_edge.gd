extends "res://tests/base_test.gd"
## The 64 bit edge (D-37, SEC-01): joining (D-04 condition 5), the full chain
## check (6.1), the joinable highlight (TH14) and the move check (D-15, TH13)
## use the same fit test as commit_chain, so they always agree. The booster
## side of AT-143 and AT-144 (usability, the offer, Double's bad target, the
## run ending) is a boosters test.

const F := preload("res://tests/core/core_fixtures.gd")
const INT64_MAX: int = 9223372036854775807
const BIG: int = 1 << 62
const HALF: int = 1 << 61

var config: GameConfig


func before_each() -> void:
	config = GameConfig.new()


func _drag(board: PackedInt64Array, cells: Array[Vector2i]) -> Array[Vector2i]:
	var chain: Array[Vector2i] = []
	for cell: Vector2i in cells:
		chain = CoreRules.step_chain(board, chain, cell, config)
	return chain


## Commits chain on a copy of state and checks that a refusal changed nothing.
func _assert_refused_and_unchanged(state: RunState, chain: Array[Vector2i], label: String) -> void:
	var before: RunState = state.copy()
	var records: Records = F.records(77, 64)
	var rng: RunRandom = F.seeded(63)
	rng.script_spawns(PackedInt64Array([1024]))
	var rng_state: int = rng.get_state()
	var result: MoveResult = RunRules.commit_chain(state, records, chain, rng, config)
	assert_false(result.accepted, "%s: refused" % label)
	assert_eq(result.refusal, &"invalid_chain", "%s: as an invalid chain" % label)
	assert_true(state.equals(before), "%s: the state is unchanged" % label)
	assert_true(records.best_score == 77 and records.best_tile == 64, "%s: the records are unchanged" % label)
	assert_eq(rng.get_state(), rng_state, "%s: the generator is unchanged" % label)
	assert_eq(rng.next_spawn(PackedInt64Array([2, 4, 8, 16]), config), 1024, "%s: no scripted spawn was used" % label)
	assert_eq(result.has_valid_move, CoreRules.has_valid_move(state.cells, config), "%s: the result's move check" % label)


# AT-143 and AT-144, the core halves

## The board of security finding SEC-01: cells 35 and 36 at exponent 62.
func test_at_143_two_touching_2_62_tiles_are_not_a_move() -> void:
	var board: PackedInt64Array = F.changed(F.board_d(), {Vector2i(0, 7): BIG, Vector2i(1, 7): BIG})
	var state: RunState = RunState.create(board, 0, PackedInt64Array(), 0, BIG, 5, 17)
	assert_eq(CoreRules.stars(state.run_highest, config), 52, "52 stars")
	assert_eq(CoreRules.free_earned(state.run_highest, config), 17, "17 free boosters earned")
	assert_eq(CoreRules.free_held(state, config), 0, "(a) all 17 used, none held")
	assert_false(CoreRules.has_valid_move(state.cells, config), "no valid move")
	var start: Array[Vector2i] = [Vector2i(0, 7)]
	assert_false(CoreRules.joinable_cells(state.cells, start, config).has(Vector2i(1, 7)), "(1,7) is not joinable")
	assert_true(CoreRules.joinable_cells(state.cells, start, config).is_empty(), "nothing is joinable from (0,7)")
	assert_false(CoreRules.can_join(state.cells, start, Vector2i(1, 7), config), "can_join agrees")
	assert_eq(CoreRules.step_chain(state.cells, start, Vector2i(1, 7), config), start, "the finger over (1,7) changes nothing")
	var pair: Array[Vector2i] = [Vector2i(0, 7), Vector2i(1, 7)]
	assert_false(CoreRules.is_valid_chain(state.cells, pair, config), "the pair is not a valid chain")
	_assert_refused_and_unchanged(state, pair, "AT-143 commit")
	state.free_used = 16
	assert_eq(CoreRules.free_held(state, config), 1, "(b) 16 used, 1 held")
	var doubled: PackedInt64Array = F.changed(board, {Vector2i(2, 7): 16})
	assert_true(CoreRules.has_valid_move(doubled, config), "(b) with (2,7) doubled to 16 next to (3,7) = 16, the board has a move")


func test_at_144_an_all_2_62_board_has_no_move() -> void:
	var board: PackedInt64Array = F.board_all(BIG)
	var state: RunState = RunState.create(board, 0, PackedInt64Array(), 0, BIG, 5, 16)
	assert_false(CoreRules.has_valid_move(board, config), "no valid move")
	assert_eq(CoreRules.free_held(state, config), 1, "(a) 1 free booster held")
	for index: int in board.size():
		var cell: Vector2i = CoreRules.cell_of(index, F.COLUMNS)
		var chain: Array[Vector2i] = [cell]
		if not CoreRules.joinable_cells(board, chain, config).is_empty():
			fail("%s has a joinable neighbor" % cell)
			return
	var pair: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	_assert_refused_and_unchanged(state, pair, "AT-144 pair")
	var rich: RunState = RunState.create(board, INT64_MAX, PackedInt64Array(), 0, BIG)
	_assert_refused_and_unchanged(rich, pair, "AT-144 (b) at the largest score")
	# What Hammer on (0,0) leaves (scripted spawn 2^53): still no move.
	var empty_top: RunState = RunState.create(F.changed(board, {Vector2i(0, 0): 0}), 0, PackedInt64Array(), 0, BIG)
	var rng: RunRandom = F.seeded(144)
	rng.script_spawns(PackedInt64Array([1 << 53]))
	var settled: MoveResult = MoveResult.new()
	RunRules.settle(empty_top, settled, rng, config)
	assert_eq(empty_top.value_at(Vector2i(0, 0)), 1 << 53, "(0,0) = 2^53")
	assert_eq(CoreRules.spawn_window(BIG, config), PackedInt64Array([1 << 53, 1 << 54, 1 << 55, 1 << 56]), "the window at H 2^62")
	assert_false(CoreRules.has_valid_move(empty_top.cells, config), "still no valid move after the Hammer")


# The move check

func test_pair_fits_at_the_edges() -> void:
	assert_true(CoreRules.pair_fits(2), "2")
	assert_true(CoreRules.pair_fits(1024), "1024")
	assert_true(CoreRules.pair_fits(HALF), "2^61: 2^62 fits")
	assert_false(CoreRules.pair_fits(BIG), "2^62: 2^63 does not fit")
	assert_true(CoreRules.pair_fits((INT64_MAX >> 1)), "2^62 - 1: the largest value whose double fits")
	assert_false(CoreRules.pair_fits((INT64_MAX >> 1) + 1), "2^62, written another way")
	assert_false(CoreRules.pair_fits(INT64_MAX), "the largest int")
	assert_false(CoreRules.pair_fits(0), "0 is no tile")
	assert_false(CoreRules.pair_fits(-2), "a negative value")
	assert_false(CoreRules.pair_fits(-9223372036854775807 - 1), "the lowest int")
	for power: int in range(1, 63):
		assert_eq(CoreRules.pair_fits(1 << power), CoreRules._sum_of(PackedInt64Array([1 << power, 1 << power])) > 0, "2^%d agrees with the chain sum" % power)
		var board: PackedInt64Array = F.changed(F.board_d(), {Vector2i(0, 7): 1 << power, Vector2i(1, 7): 1 << power})
		assert_eq(CoreRules.pair_fits(1 << power), CoreRules.has_valid_move(board, config), "2^%d agrees with the move check" % power)


func test_move_check_needs_a_pair_that_fits_in_every_direction() -> void:
	var pairs: Array[Array] = [
		["right", Vector2i(1, 2), Vector2i(2, 2)],
		["below", Vector2i(3, 4), Vector2i(3, 5)],
		["lower right", Vector2i(0, 6), Vector2i(1, 7)],
		["lower left", Vector2i(1, 0), Vector2i(0, 1)],
		["bottom right corner", Vector2i(4, 7), Vector2i(3, 6)],
		["top right corner", Vector2i(4, 0), Vector2i(3, 1)],
	]
	for pair: Array in pairs:
		var a: Vector2i = pair[1]
		var b: Vector2i = pair[2]
		assert_false(CoreRules.has_valid_move(F.changed(F.board_d(), {a: BIG, b: BIG}), config), "%s: a 2^62 pair is no move" % pair[0])
		assert_true(CoreRules.has_valid_move(F.changed(F.board_d(), {a: HALF, b: HALF}), config), "%s: a 2^61 pair is a move" % pair[0])


func test_an_overflowing_pair_does_not_hide_a_real_one() -> void:
	var board: PackedInt64Array = F.changed(F.board_d(), {Vector2i(0, 7): BIG, Vector2i(1, 7): BIG, Vector2i(3, 3): 64, Vector2i(4, 4): 64})
	assert_true(CoreRules.has_valid_move(board, config), "the 64 pair is still found")
	var many: PackedInt64Array = F.changed(F.board_all(BIG), {Vector2i(4, 7): HALF, Vector2i(3, 7): HALF})
	assert_true(CoreRules.has_valid_move(many, config), "one 2^61 pair on a board of 2^62 tiles")


# Joining and the full chain check

func test_a_single_huge_tile_can_start_a_chain() -> void:
	var board: PackedInt64Array = F.changed(F.board_d(), {Vector2i(0, 7): BIG})
	var empty: Array[Vector2i] = []
	assert_true(CoreRules.can_join(board, empty, Vector2i(0, 7), config), "a lone tile always fits")
	assert_eq(_drag(board, [Vector2i(0, 7)]), [Vector2i(0, 7)] as Array[Vector2i], "the drag starts on it")


## 2^61, 2^61 fits (2^62). Adding the 2^62 that doubles it would make 2^63.
func test_a_double_that_would_pass_the_limit_does_not_join() -> void:
	var board: PackedInt64Array = F.changed(F.board_d(), {Vector2i(0, 7): HALF, Vector2i(1, 7): HALF, Vector2i(2, 7): BIG})
	var pair: Array[Vector2i] = _drag(board, [Vector2i(0, 7), Vector2i(1, 7)])
	assert_eq(pair.size(), 2, "the 2^61 pair joins")
	assert_false(CoreRules.joinable_cells(board, pair, config).has(Vector2i(2, 7)), "the 2^62 is not highlighted")
	assert_false(CoreRules.can_join(board, pair, Vector2i(2, 7), config), "and does not join")
	assert_eq(CoreRules.step_chain(board, pair, Vector2i(2, 7), config), pair, "the finger over it changes nothing")
	var triple: Array[Vector2i] = [Vector2i(0, 7), Vector2i(1, 7), Vector2i(2, 7)]
	assert_false(CoreRules.is_valid_chain(board, triple, config), "the three tiles are not a valid chain")
	_assert_refused_and_unchanged(F.state(board, 0), triple, "the triple")
	var state: RunState = F.state(board, 0)
	var result: MoveResult = RunRules.commit_chain(state, Records.new(), pair, F.seeded(61), config)
	assert_true(result.accepted, "the pair commits")
	assert_eq(result.result_value, BIG, "making 2^62")
	assert_eq(state.score, BIG, "score 2^62")


## Three 2^61 tiles sum to 3 x 2^61, which fits. A fourth would make 2^63.
func test_three_2_61_tiles_fit_and_a_fourth_does_not() -> void:
	var row: Array[Vector2i] = [Vector2i(0, 7), Vector2i(1, 7), Vector2i(2, 7), Vector2i(3, 7)]
	var board: PackedInt64Array = F.placed(F.board_d(), row, PackedInt64Array([HALF, HALF, HALF, HALF]))
	var chain: Array[Vector2i] = _drag(board, row)
	assert_eq(chain.size(), 3, "the fourth 2^61 does not join")
	assert_true(CoreRules.joinable_cells(board, chain, config).is_empty(), "nothing is highlighted after three")
	assert_false(CoreRules.is_valid_chain(board, row, config), "four is not a valid chain")
	_assert_refused_and_unchanged(F.state(board, 0), row, "four 2^61 tiles")
	var state: RunState = F.state(board, 0)
	var result: MoveResult = RunRules.commit_chain(state, Records.new(), chain, F.seeded(3), config)
	assert_true(result.accepted, "three commit")
	assert_eq(result.points, 3 * HALF, "points 3 x 2^61")
	assert_eq(result.result_value, BIG, "rounded down to 2^62")


## GDD 6.1 condition 5: 40 tiles of 2^57 still fit; with 2^58 tiles the chain stops at 31.
func test_40_tiles_of_2_57_fit_and_2_58_tiles_stop_at_31() -> void:
	var path: Array[Vector2i] = F.snake_from_top(40)
	var low: PackedInt64Array = F.board_all(1 << 57)
	var whole: Array[Vector2i] = _drag(low, path)
	assert_eq(whole.size(), 40, "all 40 tiles of 2^57 join")
	assert_true(CoreRules.is_valid_chain(low, whole, config), "a valid chain")
	var low_state: RunState = F.state(low, 0)
	assert_true(RunRules.commit_chain(low_state, Records.new(), whole, F.seeded(57), config).accepted, "and it commits")
	assert_eq(low_state.score, 40 * (1 << 57), "score 40 x 2^57")
	var high: PackedInt64Array = F.board_all(1 << 58)
	var chain: Array[Vector2i] = _drag(high, path)
	assert_eq(chain.size(), 31, "31 tiles of 2^58 join, the 32nd would make 2^63")
	assert_true(CoreRules.joinable_cells(high, chain, config).is_empty(), "nothing is highlighted after 31")
	var too_long: Array[Vector2i] = path.slice(0, 32)
	assert_false(CoreRules.is_valid_chain(high, too_long, config), "32 is not a valid chain")
	_assert_refused_and_unchanged(F.state(high, 0), too_long, "32 tiles of 2^58")
	assert_true(RunRules.commit_chain(F.state(high, 0), Records.new(), chain, F.seeded(58), config).accepted, "31 commit")


## One fit test: on boards of one huge value, how far a drag gets, the move
## check, the full chain check and the commit all agree, just below and at
## the limit. Chain lengths: 40 up to 2^57, then 31, 15, 7, 3 and 1.
func test_joining_the_move_check_and_commit_agree_at_the_limit() -> void:
	var path: Array[Vector2i] = F.snake_from_top(40)
	var lengths: Dictionary[int, int] = {55: 40, 56: 40, 57: 40, 58: 31, 59: 15, 60: 7, 61: 3, 62: 1}
	for power: int in lengths:
		var board: PackedInt64Array = F.board_all(1 << power)
		var label: String = "all 2^%d" % power
		var chain: Array[Vector2i] = _drag(board, path)
		assert_eq(chain.size(), lengths[power], "%s: the drag joins %d tiles" % [label, lengths[power]])
		assert_eq(CoreRules.has_valid_move(board, config), chain.size() >= 2, "%s: the move check agrees with joining" % label)
		if chain.size() >= 2:
			assert_true(CoreRules.is_valid_chain(board, chain, config), "%s: the dragged chain is valid" % label)
			var state: RunState = F.state(board, 0)
			assert_true(RunRules.commit_chain(state, Records.new(), chain, F.seeded(power), config).accepted, "%s: and commits" % label)
		if chain.size() < 40:
			var longer: Array[Vector2i] = path.slice(0, chain.size() + 1)
			assert_false(CoreRules.can_join(board, chain, path[chain.size()], config), "%s: the next tile does not join" % label)
			assert_false(CoreRules.is_valid_chain(board, longer, config), "%s: one more is not valid" % label)
			_assert_refused_and_unchanged(F.state(board, 0), longer, "%s, one more" % label)


## The score part of the limit stays in commit_chain alone: joining only
## looks at the chain's sum, so a chain that fits joins even when the score
## would not take its points.
func test_the_score_limit_refuses_the_commit_but_not_the_drag() -> void:
	var board: PackedInt64Array = F.changed(F.board_d(), {Vector2i(0, 7): HALF, Vector2i(1, 7): HALF})
	var pair: Array[Vector2i] = _drag(board, [Vector2i(0, 7), Vector2i(1, 7)])
	assert_eq(pair.size(), 2, "the pair joins")
	assert_true(CoreRules.has_valid_move(board, config), "and is a move")
	_assert_refused_and_unchanged(F.state(board, INT64_MAX - BIG + 1), pair, "a score that would pass the limit")
	var edge: RunState = F.state(board, INT64_MAX - BIG)
	assert_true(RunRules.commit_chain(edge, Records.new(), pair, F.seeded(1), config).accepted, "a score that lands on 2^63 - 1 commits")
	assert_eq(edge.score, INT64_MAX, "the largest score")


## A negative score is never trusted: the commit is refused.
func test_a_negative_score_refuses_the_commit() -> void:
	_assert_refused_and_unchanged(F.state(F.board_p(), -1), [Vector2i(1, 6), Vector2i(2, 6)] as Array[Vector2i], "score -1")
