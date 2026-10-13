extends "res://tests/base_test.gd"
## The 64 bit edge for boosters (SEC-01, D-37, GDD 13.1, 13.5, 13.6): a
## booster is usable only when it can act on the board (NO_TARGET), a 2^62
## tile is never a Double target, the Shuffle fallback only pairs values that
## fit, and the booster halves of AT-143 and AT-144. The move check and
## joining halves are core tests (tests/core/test_64_bit_edge.gd).

const F := preload("res://tests/core/core_fixtures.gd")
const BF := preload("res://tests/boosters/booster_fixtures.gd")
const USABLE: BoosterStatus.Usability = BoosterStatus.Usability.USABLE
const CANNOT_AFFORD: BoosterStatus.Usability = BoosterStatus.Usability.CANNOT_AFFORD
const NO_SNAPSHOT: BoosterStatus.Usability = BoosterStatus.Usability.NO_SNAPSHOT
const NO_TARGET: BoosterStatus.Usability = BoosterStatus.Usability.NO_TARGET
const BIG: int = 1 << 62
const INT64_MAX: int = 9223372036854775807

var config: GameConfig
var recorder: BF.Recorder


func before_each() -> void:
	config = GameConfig.new()
	recorder = BF.Recorder.new()


func _usabilities(state: RunState) -> Array[BoosterStatus.Usability]:
	var list: Array[BoosterStatus.Usability] = []
	for id: StringName in BoosterRules.ALL:
		list.append(BoosterRules.usability(id, state, config))
	return list


func _reasons(session: GameSession) -> Array[BoosterStatus.Usability]:
	var list: Array[BoosterStatus.Usability] = []
	for status: BoosterStatus in session.booster_statuses():
		list.append(status.reason)
	return list


## The SEC-01 board: Board D with (0,7) = 2^62 and (1,7) = 2^62.
func _sec_01_board() -> PackedInt64Array:
	return F.changed(F.board_d(), {Vector2i(0, 7): BIG, Vector2i(1, 7): BIG})


## Every value different except two 2^62 tiles on (0,0) and (2,0), which do
## not touch. With small_twins, also two 2s on (0,2) and (2,2), which do not
## touch either. No valid move either way.
func _twins_board(small_twins: bool) -> PackedInt64Array:
	var board: PackedInt64Array = PackedInt64Array()
	var power: int = 2 if small_twins else 1
	for index: int in 40:
		if index == 0 or index == 2:
			board.append(BIG)
		elif small_twins and (index == 10 or index == 12):
			board.append(2)
		else:
			board.append(1 << power)
			power += 1
	return board


# Usability: something to act on (13.1)

func test_usability_needs_something_to_act_on() -> void:
	var a4: RunState = F.state(F.board_all(4), 5000)
	assert_eq(_usabilities(a4), [USABLE, NO_TARGET, NO_TARGET, USABLE, NO_SNAPSHOT] as Array[BoosterStatus.Usability], "Board A4: Swap and Shuffle have nothing to act on")
	var paid: RunState = BF.none_held(F.state(F.board_all(BIG), INT64_MAX))
	assert_eq(_usabilities(paid), [USABLE, NO_TARGET, NO_TARGET, CANNOT_AFFORD, NO_SNAPSHOT] as Array[BoosterStatus.Usability], "all 2^62 at the largest score: Hammer only, Double's cost does not fit")
	var free: RunState = BF.holding(1, F.board_all(BIG), 0, BIG)
	assert_eq(_usabilities(free), [USABLE, NO_TARGET, NO_TARGET, NO_TARGET, NO_SNAPSHOT] as Array[BoosterStatus.Usability], "all 2^62 with a free booster: Hammer only, Double has no tile")
	var one_fits: RunState = BF.holding(1, F.changed(F.board_all(BIG), {Vector2i(4, 7): 1 << 61}), 0, BIG)
	assert_eq(_usabilities(one_fits), [USABLE, USABLE, USABLE, USABLE, NO_SNAPSHOT] as Array[BoosterStatus.Usability], "one 2^61 tile is enough for Swap, Shuffle and Double")
	var undo: RunState = BF.holding(1, F.board_all(BIG), 4, BIG, F.board_p(), 4)
	assert_eq(BoosterRules.usability(BoosterRules.UNDO, undo, config), USABLE, "Undo can always act")


func test_affordability_is_checked_before_the_target() -> void:
	var state: RunState = BF.none_held(F.state(F.board_all(BIG), 0))
	assert_eq(_usabilities(state), [CANNOT_AFFORD, CANNOT_AFFORD, CANNOT_AFFORD, CANNOT_AFFORD, NO_SNAPSHOT] as Array[BoosterStatus.Usability], "a booster that is unaffordable and has no target reads CANNOT_AFFORD")


func test_no_target_is_refused_as_a_bad_target_and_spends_nothing() -> void:
	var cases: Array[Array] = [
		[F.state(F.board_all(4), 5000), BoosterRules.SWAP, [Vector2i(0, 0), Vector2i(1, 0)]],
		[F.state(F.board_all(4), 5000), BoosterRules.SHUFFLE, []],
		[BF.holding(1, F.board_all(BIG), 0, BIG), BoosterRules.SWAP, [Vector2i(0, 0), Vector2i(1, 0)]],
		[BF.holding(1, F.board_all(BIG), 0, BIG), BoosterRules.SHUFFLE, []],
		[BF.holding(1, F.board_all(BIG), 0, BIG), BoosterRules.DOUBLE, [Vector2i(0, 0)]],
	]
	for each: Array in cases:
		var state: RunState = each[0]
		var id: StringName = each[1]
		var before: RunState = state.copy()
		var rng: RunRandom = F.seeded(1)
		var rng_before: int = rng.get_state()
		var result: MoveResult = BoosterRules.apply(id, state, Records.new(), BF.targets(each[2]), rng, config)
		var label: String = "%s on all %d" % [id, state.cells[0]]
		assert_eq(result.refusal, &"bad_target", "%s: refused as a bad target" % label)
		assert_true(state.equals(before), "%s: nothing changed, no free booster used" % label)
		assert_eq(rng.get_state(), rng_before, "%s: no draw" % label)
		assert_eq(rng.shuffle_attempts, 0, "%s: no Shuffle attempt" % label)


# Double (13.6)

func test_a_double_on_2_62_while_free_is_a_bad_target_that_keeps_the_free_booster() -> void:
	var state: RunState = BF.holding(1, _sec_01_board(), 0, BIG)
	var before: RunState = state.copy()
	var result: MoveResult = BoosterRules.apply(BoosterRules.DOUBLE, state, Records.new(), BF.targets([Vector2i(0, 7)]), F.seeded(1), config)
	assert_eq(result.refusal, &"bad_target", "refused as a bad target")
	assert_false(result.free_used, "no free booster used")
	assert_true(state.equals(before), "nothing changed")
	assert_eq(CoreRules.free_held(state, config), 1, "1 free booster still held")


# The Shuffle fallback (13.5)

func test_shuffle_fallback_skips_twins_whose_pair_does_not_fit() -> void:
	var board: PackedInt64Array = _twins_board(true)
	assert_false(CoreRules.has_valid_move(board, config), "the setup has no move")
	var state: RunState = BF.none_held(F.state(board, BIG))
	var rng: RunRandom = F.seeded(1)
	rng.force_shuffle(board)
	var result: MoveResult = BoosterRules.apply(BoosterRules.SHUFFLE, state, Records.new(), BF.no_targets(), rng, config)
	assert_true(result.accepted, "accepted")
	assert_eq(rng.shuffle_attempts, 100, "every arrangement was tried")
	var expected: PackedInt64Array = F.changed(board, {Vector2i(1, 2): 2, Vector2i(2, 2): F.at(board, Vector2i(1, 2))})
	assert_eq(state.cells, expected, "P is the first 2 on (0,2), not the 2^62 on (0,0): its twin moves to (1,2)")
	assert_true(result.has_valid_move, "so the board has a valid move")
	assert_eq(state.score, 0, "charged B = 2^62")


func test_shuffle_fallback_with_only_twins_that_do_not_fit_changes_nothing() -> void:
	var board: PackedInt64Array = _twins_board(false)
	assert_false(CoreRules.has_valid_move(board, config), "the setup has no move")
	var state: RunState = BF.none_held(F.state(board, BIG))
	var rng: RunRandom = F.seeded(1)
	rng.force_shuffle(board)
	var result: MoveResult = BoosterRules.apply(BoosterRules.SHUFFLE, state, Records.new(), BF.no_targets(), rng, config)
	assert_true(result.accepted, "Shuffle still runs and is charged")
	assert_eq(state.cells, board, "no value of 2^61 or less repeats, so the fallback leaves the last arrangement")
	assert_false(result.has_valid_move, "no valid move: the 2^62 twins never touch for nothing")
	assert_eq(state.score, 0, "charged B = 2^62")


# AT-143 and AT-144, the booster halves

func test_at_143_a_nothing_usable_ends_the_run_at_once() -> void:
	var state: RunState = BF.none_held(RunState.create(_sec_01_board(), 0))
	assert_eq([CoreRules.stars(state.run_highest, config), CoreRules.free_earned(state.run_highest, config)], [52, 17], "52 stars, 17 free boosters earned")
	assert_eq(CoreRules.free_held(state, config), 0, "all 17 used")
	assert_eq(BoosterRules.cost(BoosterRules.HAMMER, state, config), BIG, "Hammer, Swap and Shuffle cost 2^62")
	assert_eq(BoosterRules.cost(BoosterRules.DOUBLE, state, config), 0, "Double's 2^63 does not fit")
	assert_eq(_usabilities(state), [CANNOT_AFFORD, CANNOT_AFFORD, CANNOT_AFFORD, CANNOT_AFFORD, NO_SNAPSHOT] as Array[BoosterStatus.Usability], "nothing is usable")
	assert_eq(BoosterRules.outcome(state, config), BoosterRules.Outcome.END, "the move check ends the run")
	var session: GameSession = GameSession.new()
	recorder.watch(session)
	session.resume(state)
	session.move_shown()
	assert_eq(session.phase(), GameSession.Phase.ENDED, "the run ends at once; it does not stay in play")
	assert_eq(recorder.count("offer_changed"), 0, "no offer")
	assert_eq(recorder.summaries[0].final_score, 0, "final score 0")
	assert_true(recorder.summaries[0].no_moves_left, "no moves left")
	assert_eq(recorder.summaries[0].stars, 52, "the summary carries the 52 stars")


func test_at_143_b_a_free_booster_rescues() -> void:
	var session: GameSession = BF.ready_session(BF.holding(1, _sec_01_board(), 0, BIG))
	recorder.watch(session)
	assert_eq(session.phase(), GameSession.Phase.OFFER, "the offer opens")
	assert_eq(BF.usable_ids(session), [&"hammer", &"swap", &"shuffle", &"double"] as Array[StringName], "Hammer, Swap, Shuffle and Double are usable")
	assert_eq(BF.free_ids(session), BoosterRules.ALL, "and free")
	assert_eq(BF.status_of(session, BoosterRules.UNDO).reason, NO_SNAPSHOT, "Undo is not")
	assert_eq(BF.suggested_id(session), BoosterRules.SHUFFLE, "Shuffle is marked")
	session.press_booster(BoosterRules.DOUBLE)
	var before: RunState = session.state.copy()
	recorder.clear()
	assert_true(null == session.tap_cell(Vector2i(0, 7)), "Double on (0,7) is refused as a bad target")
	assert_true(session.state.equals(before), "nothing changes")
	assert_eq(session.free_held(), 1, "1 free booster still held")
	assert_eq(session.targeting_booster(), BoosterRules.DOUBLE, "Double stays active")
	assert_eq(recorder.names, PackedStringArray(), "no signal")
	var result: MoveResult = session.tap_cell(Vector2i(2, 7))
	assert_true(result != null and result.accepted, "Double on (2,7) is accepted")
	assert_eq(result.cost, 0, "and charges 0")
	assert_true(result.free_used, "using the free booster")
	assert_eq(session.state.value_at(Vector2i(2, 7)), 16, "(2,7) = 16, touching (3,7) = 16")
	assert_true(result.has_valid_move, "so the board has a valid move")
	assert_eq(session.free_held(), 0, "0 held")
	session.move_shown()
	assert_eq(session.phase(), GameSession.Phase.PLAYING, "play goes on")
	assert_false(session.is_offer_open(), "the offer closed")


func test_at_144_a_an_all_2_62_board_with_a_free_booster_cannot_loop() -> void:
	var session: GameSession = BF.ready_session(BF.holding(1, F.board_all(BIG), 0, BIG))
	recorder.watch(session)
	session.rng.script_spawns(PackedInt64Array([1 << 53]))
	assert_eq(session.phase(), GameSession.Phase.OFFER, "no valid move: the offer opens")
	assert_true(session.is_offer_open(), "End run is offered")
	assert_eq(BF.usable_ids(session), [BoosterRules.HAMMER] as Array[StringName], "only Hammer is usable")
	assert_eq(BF.free_ids(session), BoosterRules.ALL, "and free")
	assert_eq(_reasons(session), [USABLE, NO_TARGET, NO_TARGET, NO_TARGET, NO_SNAPSHOT] as Array[BoosterStatus.Usability], "Swap and Shuffle: every tile equal; Double: no tile of 2^61 or less; Undo: no snapshot")
	assert_eq(BF.suggested_id(session), &"", "nothing is marked")
	var before: RunState = session.state.copy()
	var rng_before: int = session.rng.get_state()
	var calls: Array[Array] = [
		[BoosterRules.SWAP, [Vector2i(0, 0), Vector2i(1, 0)]],
		[BoosterRules.SHUFFLE, []],
		[BoosterRules.DOUBLE, [Vector2i(0, 0)]],
	]
	for each: Array in calls:
		var refused: MoveResult = BoosterRules.apply(each[0], session.state, session.records, BF.targets(each[1]), session.rng, session.config)
		assert_eq(refused.refusal, &"bad_target", "%s is refused as a bad target" % each[0])
	assert_true(session.state.equals(before), "the calls change nothing")
	assert_eq(session.rng.get_state(), rng_before, "and draw nothing")
	assert_eq(session.free_held(), 1, "1 free booster still held")
	session.press_booster(BoosterRules.HAMMER)
	var result: MoveResult = session.tap_cell(Vector2i(0, 0))
	assert_true(result != null and result.accepted, "the Hammer is accepted")
	assert_eq(result.cost, 0, "and charges 0")
	assert_eq(session.state.value_at(Vector2i(0, 0)), 1 << 53, "(0,0) = 2^53")
	assert_eq(session.state.score, 0, "score 0")
	assert_eq(session.free_held(), 0, "0 held")
	assert_false(result.has_valid_move, "still no valid move")
	assert_true(result.run_ends, "and nothing usable")
	session.move_shown()
	assert_eq(session.phase(), GameSession.Phase.ENDED, "the run ends at once")
	assert_eq(recorder.summaries[0].final_score, 0, "final score 0")


func test_at_144_b_an_all_2_62_board_at_the_largest_score() -> void:
	var session: GameSession = BF.ready_session(BF.none_held(RunState.create(F.board_all(BIG), INT64_MAX)))
	recorder.watch(session)
	session.rng.script_spawns(PackedInt64Array([1 << 53]))
	assert_eq(session.phase(), GameSession.Phase.OFFER, "the offer opens")
	assert_eq(BF.usable_ids(session), [BoosterRules.HAMMER] as Array[StringName], "only Hammer is usable")
	assert_eq(BF.status_of(session, BoosterRules.HAMMER).cost, BIG, "at a cost of 2^62")
	assert_true(BF.free_ids(session).is_empty(), "nothing is free")
	assert_eq(_reasons(session), [USABLE, NO_TARGET, NO_TARGET, CANNOT_AFFORD, NO_SNAPSHOT] as Array[BoosterStatus.Usability], "Swap and Shuffle: every tile equal; Double: its cost does not fit; Undo: no snapshot")
	session.press_booster(BoosterRules.HAMMER)
	var result: MoveResult = session.tap_cell(Vector2i(0, 0))
	assert_eq(result.cost, BIG, "charged 2^62")
	assert_eq(session.state.score, 4611686018427387903, "score 2^62 minus 1")
	assert_eq(session.state.value_at(Vector2i(0, 0)), 1 << 53, "(0,0) = 2^53")
	assert_true(result.run_ends, "no valid move and nothing usable")
	session.move_shown()
	assert_eq(session.phase(), GameSession.Phase.ENDED, "the run ends at once")
	assert_eq(recorder.summaries[0].final_score, 4611686018427387903, "final score 2^62 minus 1")
