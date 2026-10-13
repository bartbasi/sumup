extends "res://tests/base_test.gd"
## Random play. AT-84 on the rules model (D-30: the score never goes below
## zero, refused calls change nothing, accepted boosters take exactly their
## charge: the cost, or 0 when they use a free booster, D-46), and random
## intents on GameSession checking its flow rules hold at every step.

const F := preload("res://tests/core/core_fixtures.gd")
const BF := preload("res://tests/boosters/booster_fixtures.gd")

var config: GameConfig


func before_each() -> void:
	config = GameConfig.new()


## A random chain that follows the joining rule, 2 to 5 tiles long, or an
## empty chain when the board has no valid move. It starts on the first
## touching equal pair found from a random cell, then grows through
## CoreRules.joinable_cells.
func _random_chain(cells: PackedInt64Array, pick: RandomNumberGenerator) -> Array[Vector2i]:
	var chain: Array[Vector2i] = []
	var columns: int = config.columns
	var size: int = cells.size()
	var offset: int = pick.randi_range(0, size - 1)
	for step: int in size:
		var index: int = (offset + step) % size
		var column: int = index % columns
		var value: int = cells[index]
		var partner: int = -1
		if column + 1 < columns and cells[index + 1] == value:
			partner = index + 1
		elif index + columns < size:
			if cells[index + columns] == value:
				partner = index + columns
			elif column > 0 and cells[index + columns - 1] == value:
				partner = index + columns - 1
			elif column + 1 < columns and cells[index + columns + 1] == value:
				partner = index + columns + 1
		if partner >= 0:
			chain = [CoreRules.cell_of(index, columns), CoreRules.cell_of(partner, columns)]
			if pick.randi_range(0, 1) == 0:
				chain.reverse()
			break
	if chain.is_empty():
		return chain
	var length: int = pick.randi_range(2, 5)
	while chain.size() < length:
		var options: Array[Vector2i] = CoreRules.joinable_cells(cells, chain, config)
		if options.is_empty():
			break
		chain.append(options[pick.randi_range(0, options.size() - 1)])
	return chain


## A random cell, now and then just off the board.
func _random_cell(pick: RandomNumberGenerator) -> Vector2i:
	if pick.randi_range(0, 9) == 0:
		return Vector2i(pick.randi_range(-1, config.columns), pick.randi_range(-1, config.rows))
	return Vector2i(pick.randi_range(0, config.columns - 1), pick.randi_range(0, config.rows - 1))


## Random targets: usually the right count for the booster, sometimes not.
func _random_targets(id: StringName, pick: RandomNumberGenerator) -> Array[Vector2i]:
	var count: int = BoosterRules.target_count(id)
	if pick.randi_range(0, 9) == 0:
		count = pick.randi_range(0, 2)
	var targets: Array[Vector2i] = []
	for position: int in count:
		targets.append(_random_cell(pick))
	return targets


## Every cell a power of two from 2 up, none below the window floor (D-38,
## D-39), the run highest tile and Best Tile at least H.
func _board_problem(state: RunState, records: Records) -> String:
	if state.cells.size() != config.cell_count():
		return "the board has %d cells" % state.cells.size()
	var floor_value: int = CoreRules.window_floor(state.highest(), config)
	for value: int in state.cells:
		if value < 2 or not CoreRules.is_power_of_two(value):
			return "a cell holds %d" % value
		if value < floor_value:
			return "a %d is below the floor %d" % [value, floor_value]
	if state.run_highest < state.highest() or records.best_tile < state.run_highest:
		return "H %d, run highest %d, Best Tile %d" % [state.highest(), state.run_highest, records.best_tile]
	if records.best_score < state.score:
		return "Best Score %d below the score %d" % [records.best_score, state.score]
	return ""


## One random action on the rules model, checked (AT-84): a chain when valid
## and the roll allows it, else a booster with random targets whether or not
## it is usable. Returns the problem found, or "" when every check holds.
## tally counts "accepted", "refused" and "free" (accepted free boosters).
## result receives the move's result as its only element.
func _random_action(state: RunState, records: Records, rng: RunRandom, pick: RandomNumberGenerator, valid: bool, tally: Dictionary[String, int], result: Array[MoveResult]) -> String:
	var before: RunState = state.copy()
	var records_before: Records = records.copy()
	var rng_before: int = rng.get_state()
	var label: String = ""
	var moved: MoveResult = null
	var price: int = 0
	var was_free: bool = false
	if valid and pick.randi_range(0, 2) == 0:
		label = "chain"
		moved = RunRules.commit_chain(state, records, _random_chain(state.cells, pick), rng, config)
	else:
		var id: StringName = BoosterRules.ALL[pick.randi_range(0, BoosterRules.ALL.size() - 1)]
		label = String(id)
		price = BoosterRules.charge(id, state, config)
		was_free = BoosterRules.is_free(state, config)
		if was_free and price != 0:
			return "%s would charge %d while free" % [label, price]
		moved = BoosterRules.apply(id, state, records, _random_targets(id, pick), rng, config)
	result.clear()
	result.append(moved)
	if state.score < 0:
		return "score %d" % state.score
	if CoreRules.free_held(state, config) < 0:
		return "free boosters held %d" % CoreRules.free_held(state, config)
	if not moved.accepted:
		tally["refused"] += 1
		if not state.equals(before) or rng.get_state() != rng_before:
			return "a refused %s changed the run" % label
		if records.best_score != records_before.best_score or records.best_tile != records_before.best_tile:
			return "a refused %s changed the records" % label
		if moved.cost != 0 or moved.free_used:
			return "a refused %s reports a charge" % label
		return ""
	if label == "chain":
		if state.score != before.score + moved.points:
			return "a chain added %d, not its points %d" % [state.score - before.score, moved.points]
		if state.free_used != before.free_used:
			return "a chain used a free booster"
	else:
		tally["accepted"] += 1
		var expected: int = before.score - price
		if label == "undo":
			expected = before.score - before.snapshot_points - price
		if moved.cost != price or state.score != expected:
			return "%s took the score from %d to %d at charge %d" % [label, before.score, state.score, price]
		var used: int = 1 if was_free else 0
		if moved.free_used != was_free or state.free_used != before.free_used + used:
			return "%s used %d free boosters with %d held" % [label, state.free_used - before.free_used, CoreRules.free_held(before, config)]
		tally["free"] += used
	return _board_problem(state, records)


func _new_tally() -> Dictionary[String, int]:
	var tally: Dictionary[String, int] = {"accepted": 0, "refused": 0, "free": 0}
	return tally


func test_at_84_random_play_never_goes_below_zero() -> void:
	var tally: Dictionary[String, int] = _new_tally()
	var result: Array[MoveResult] = []
	for seed_value: int in range(1, 21):
		var rng: RunRandom = F.seeded(seed_value)
		var pick: RandomNumberGenerator = RandomNumberGenerator.new()
		pick.seed = seed_value * 7919
		var records: Records = Records.new()
		var state: RunState = RunRules.new_run(rng, records, config)
		# Every result reports the move check on the board it leaves, so the
		# board is not checked again here.
		var valid: bool = true
		for action: int in 10000:
			if not valid and BoosterRules.outcome(state, config) == BoosterRules.Outcome.END:
				state = RunRules.new_run(rng, records, config)
				valid = true
			var problem: String = _random_action(state, records, rng, pick, valid, tally, result)
			if not problem.is_empty():
				fail("seed %d, action %d: %s" % [seed_value, action, problem])
				return
			valid = result[0].has_valid_move
	assert_true(tally["accepted"] > 1000, "boosters were really used (%d)" % tally["accepted"])
	assert_true(tally["refused"] > 1000, "refusals were really tried (%d)" % tally["refused"])
	assert_true(tally["free"] > 0, "free boosters were really used (%d)" % tally["free"])


## AT-84 again from runs that hold free boosters (D-46): tight boards, a
## run highest tile from 8K to 2^40, a random count already used and a small
## score, so free boosters, the offer and refusals all come up often.
func test_random_play_with_free_boosters_held() -> void:
	var tally: Dictionary[String, int] = _new_tally()
	var result: Array[MoveResult] = []
	for seed_value: int in range(1, 41):
		var rng: RunRandom = F.seeded(seed_value)
		var pick: RandomNumberGenerator = RandomNumberGenerator.new()
		pick.seed = seed_value * 6271
		var records: Records = Records.new()
		var boards: Array[PackedInt64Array] = [F.board_d(), F.board_e(), BF.board_d1024(), F.board_p()]
		var board: PackedInt64Array = boards[pick.randi_range(0, boards.size() - 1)]
		var snapshot: PackedInt64Array = F.board_p() if pick.randi_range(0, 1) == 0 else PackedInt64Array()
		var run_highest: int = 1 << pick.randi_range(13, 40)
		var state: RunState = RunState.create(board, pick.randi_range(0, 3000), snapshot, pick.randi_range(4, 64), run_highest)
		state.free_used = pick.randi_range(0, CoreRules.free_earned(run_highest, config))
		records.update_from(state)
		records.best_tile = run_highest
		var valid: bool = CoreRules.has_valid_move(state.cells, config)
		for action: int in 400:
			if not valid and BoosterRules.outcome(state, config) == BoosterRules.Outcome.END:
				break
			var problem: String = _random_action(state, records, rng, pick, valid, tally, result)
			if not problem.is_empty():
				fail("seed %d, action %d: %s" % [seed_value, action, problem])
				return
			valid = result[0].has_valid_move
	assert_true(tally["free"] > 100, "free boosters were really used (%d)" % tally["free"])
	assert_true(tally["accepted"] > tally["free"], "paid boosters too (%d)" % (tally["accepted"] - tally["free"]))
	assert_true(tally["refused"] > 100, "refusals were really tried (%d)" % tally["refused"])


## Random intents on GameSession, checking after each one that the flow state
## is consistent (flow rules 1 to 8) and the signals came in the right order.
func test_random_session_intents_keep_the_flow_rules() -> void:
	var visits: Dictionary[GameSession.Phase, int] = {}
	var offer_targeting: int = 0
	for seed_value: int in range(1, 11):
		var pick: RandomNumberGenerator = RandomNumberGenerator.new()
		pick.seed = seed_value * 104729
		var session: GameSession = GameSession.new()
		var recorder: BF.Recorder = BF.Recorder.new()
		recorder.watch(session)
		session.rng.force_start_board(RunRules.new_run(F.seeded(seed_value), Records.new(), config).cells)
		_restart(session, pick, seed_value)
		for intent: int in 1500:
			var before: RunState = session.state.copy()
			var signal_count: int = recorder.names.size()
			var roll: int = pick.randi_range(0, 99)
			var result: MoveResult = null
			var label: String = ""
			if session.phase() == GameSession.Phase.ENDED or (intent > 0 and intent % 100 == 0):
				label = "restart"
				_restart(session, pick, seed_value * 1000 + intent)
			elif roll < 30:
				label = "move_shown"
				session.move_shown()
			elif roll < 45:
				label = "commit_chain"
				session.begin_drag()
				result = session.commit_chain(_random_chain(session.state.cells, pick))
			elif roll < 50:
				label = "drag"
				session.begin_drag()
				if pick.randi_range(0, 1) == 0:
					session.end_drag()
			elif roll < 70:
				var id: StringName = BoosterRules.ALL[pick.randi_range(0, BoosterRules.ALL.size() - 1)]
				label = "press %s" % id
				result = session.press_booster(id)
			elif roll < 90:
				label = "tap"
				result = session.tap_cell(_random_cell(pick))
			elif roll < 97:
				label = "cancel_targeting"
				session.cancel_targeting()
			else:
				label = "end_run"
				session.end_run()
			var problem: String = _session_problem(session, recorder, signal_count, before, result)
			if problem.is_empty() and label != "restart" and session.state.best_at_start != before.best_at_start:
				problem = "best_at_start changed from %d to %d without a new run or resume" % [before.best_at_start, session.state.best_at_start]
			if not problem.is_empty():
				fail("seed %d, intent %d (%s): %s" % [seed_value, intent, label, problem])
				return
			visits[session.phase()] = visits.get(session.phase(), 0) + 1
			if session.phase() == GameSession.Phase.TARGETING and session.is_offer_open():
				offer_targeting += 1
	for phase: GameSession.Phase in [GameSession.Phase.PLAYING, GameSession.Phase.TARGETING, GameSession.Phase.OFFER, GameSession.Phase.ENDED]:
		assert_true(visits.get(phase, 0) > 0, "phase %d was reached" % phase)
	assert_true(offer_targeting > 0, "targeting from the offer was reached")


## Starts the next run: half the time a new run, half the time a resumed
## tight board (Board D or E with a few cells changed, a small score and
## sometimes a snapshot), so the offer and the end of a run come up often.
## A third of the resumed runs reached 8K, so they hold one free booster.
func _restart(session: GameSession, pick: RandomNumberGenerator, seed_value: int) -> void:
	if pick.randi_range(0, 1) == 0:
		session.start_new_run()
	else:
		var board: PackedInt64Array = F.board_d() if pick.randi_range(0, 1) == 0 else F.board_e()
		var values: PackedInt64Array = PackedInt64Array([2, 4, 8, 16, 32, 64, 512, 1024])
		for change: int in pick.randi_range(0, 3):
			var cell: Vector2i = Vector2i(pick.randi_range(0, config.columns - 1), pick.randi_range(0, config.rows - 1))
			board[CoreRules.index_of(cell, config.columns)] = values[pick.randi_range(0, values.size() - 1)]
		var snapshot: PackedInt64Array = F.board_p() if pick.randi_range(0, 1) == 0 else PackedInt64Array()
		var run_highest: int = 8192 if pick.randi_range(0, 2) == 0 else 0
		session.resume(RunState.create(board, pick.randi_range(0, 1500), snapshot, pick.randi_range(4, 64), run_highest))
	session.rng.set_seed(seed_value)


func _session_problem(session: GameSession, recorder: BF.Recorder, signal_count: int, before: RunState, result: MoveResult) -> String:
	var phase: GameSession.Phase = session.phase()
	if session.state.score < 0:
		return "score %d" % session.state.score
	if session.free_held() < 0:
		return "free boosters held %d" % session.free_held()
	if session.state.best_at_start < 0:
		return "best_at_start %d, which SaveCodec refuses to write" % session.state.best_at_start
	for status: BoosterStatus in session.booster_statuses():
		if status.free != (session.free_held() > 0):
			return "%s reads free %s with %d held" % [status.id, status.free, session.free_held()]
	if session.is_run_in_progress() != (phase == GameSession.Phase.PLAYING or phase == GameSession.Phase.TARGETING or phase == GameSession.Phase.OFFER):
		return "is_run_in_progress disagrees with the phase"
	if session.is_offer_open() and phase != GameSession.Phase.OFFER and phase != GameSession.Phase.TARGETING:
		return "the offer is open in phase %d" % phase
	if phase == GameSession.Phase.OFFER and not session.is_offer_open():
		return "phase OFFER with the offer closed"
	if (session.targeting_booster() != &"") != (phase == GameSession.Phase.TARGETING):
		return "targeting %s in phase %d" % [session.targeting_booster(), phase]
	if session.swap_first() != BF.NO_CELL and session.targeting_booster() != BoosterRules.SWAP:
		return "a Swap selection without Swap targeting"
	if session.is_waiting_for_view() and phase != GameSession.Phase.PLAYING and phase != GameSession.Phase.OFFER:
		return "waiting in phase %d" % phase
	if session.is_dragging() and (phase != GameSession.Phase.PLAYING or session.is_waiting_for_view()):
		return "a drag outside play"
	if not session.is_waiting_for_view():
		var valid: bool = CoreRules.has_valid_move(session.state.cells, session.config)
		if phase == GameSession.Phase.PLAYING and not valid:
			return "PLAYING with no valid move after the move check"
		if phase == GameSession.Phase.OFFER and (valid or BoosterRules.outcome(session.state, session.config) != BoosterRules.Outcome.OFFER):
			return "OFFER that the move check would not open"
	if result != null and not result.accepted and result.kind != MoveResult.Kind.CHAIN:
		return "a booster intent returned a refused result"
	if result != null and not result.accepted and not session.state.equals(before):
		return "a refused move changed the run"
	var names: PackedStringArray = recorder.names
	for position: int in range(signal_count, names.size()):
		if names[position] == "move_resolved":
			if position + 2 >= names.size() or names[position + 1] != "status_changed" or names[position + 2] != "save_requested":
				return "move_resolved not followed by status_changed and save_requested"
		if names[position] == "save_requested" and phase == GameSession.Phase.ENDED:
			return "save_requested in a run that ended"
	var last_end: int = -1
	var last_start: int = -1
	for position: int in names.size():
		if names[position] == "run_ended":
			last_end = position
		elif names[position] == "run_started":
			last_start = position
	if last_end > last_start:
		for position: int in range(last_end + 1, names.size()):
			if names[position] == "save_requested":
				return "save_requested after run_ended"
	return ""
