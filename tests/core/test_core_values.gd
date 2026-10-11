extends "res://tests/base_test.gd"
## GameConfig, RunState, Records, MoveResult, BoosterStatus and RunSummary
## (docs/ARCHITECTURE.md section 4, GDD sections 11, 15.1 and 18).

const F := preload("res://tests/core/core_fixtures.gd")


func test_game_config_defaults_match_gdd_section_18() -> void:
	var config: GameConfig = GameConfig.new()
	assert_eq(config.columns, 5, "BOARD_COLUMNS")
	assert_eq(config.rows, 8, "BOARD_ROWS")
	assert_eq(config.cell_count(), 40, "cell count")
	assert_eq(config.min_chain_length, 2, "MIN_CHAIN_LENGTH")
	assert_near(config.join_radius, 0.42, 0.000001, "JOIN_RADIUS")
	assert_eq(config.spawn_window_size, 4, "SPAWN_WINDOW_SIZE")
	assert_eq(config.spawn_weights, PackedInt32Array([40, 30, 20, 10]), "SPAWN_WEIGHTS")
	assert_eq(config.spawn_top_min, 16, "SPAWN_TOP_MIN")
	assert_eq(config.spawn_top_divisor, 64, "SPAWN_TOP_DIVISOR")
	assert_eq(config.start_board_max_attempts, 100, "START_BOARD_MAX_ATTEMPTS")
	assert_eq(config.shuffle_max_attempts, 100, "SHUFFLE_MAX_ATTEMPTS")
	assert_eq(config.cost_basis_min, 128, "COST_BASIS_MIN")
	assert_eq(config.cost_shift[&"hammer"], 0, "COST_HAMMER is B")
	assert_eq(config.cost_shift[&"swap"], 0, "COST_SWAP is B")
	assert_eq(config.cost_shift[&"shuffle"], 0, "COST_SHUFFLE is B")
	assert_eq(config.cost_shift[&"double"], 1, "COST_DOUBLE is 2 x B")
	assert_eq(config.cost_shift[&"undo"], -1, "COST_UNDO is B / 2")
	assert_eq(config.cost_shift.size(), 5, "one cost per booster")
	assert_eq(config.label_full_max, 1024, "LABEL_FULL_MAX")
	assert_eq(config.label_step, 1024, "LABEL_STEP")
	assert_eq(config.label_suffixes, PackedStringArray(["K", "M", "B", "T"]), "LABEL_SUFFIXES")


func test_game_config_overrides_stay_in_their_instance() -> void:
	var changed: GameConfig = GameConfig.new()
	changed.rows = 6
	changed.cost_shift[&"undo"] = 2
	changed.spawn_weights[0] = 70
	var fresh: GameConfig = GameConfig.new()
	assert_eq(changed.cell_count(), 30, "cell count follows rows")
	assert_eq(fresh.rows, 8, "another instance keeps its rows")
	assert_eq(fresh.cost_shift[&"undo"], -1, "another instance keeps its costs")
	assert_eq(fresh.spawn_weights[0], 40, "another instance keeps its weights")


func test_run_state_create_fills_every_field() -> void:
	var board: PackedInt64Array = F.board_p()
	var snapshot: PackedInt64Array = F.board_d()
	var state: RunState = RunState.create(board, 1234, snapshot, 40, 4096, 5)
	assert_eq(state.cells, F.board_p(), "cells")
	assert_eq(state.score, 1234, "score")
	assert_eq(state.snapshot_cells, F.board_d(), "snapshot cells")
	assert_eq(state.snapshot_points, 40, "snapshot points")
	assert_eq(state.run_highest, 4096, "run highest as given")
	assert_eq(state.columns, 5, "columns")
	assert_true(state.has_snapshot(), "has a snapshot")


func test_run_state_create_defaults() -> void:
	var state: RunState = RunState.create(F.board_p(), 0)
	assert_false(state.has_snapshot(), "no snapshot by default")
	assert_eq(state.snapshot_points, 0, "no snapshot points")
	assert_eq(state.run_highest, 32, "run highest 0 means the board's highest tile")
	assert_eq(state.columns, 5, "five columns")
	assert_eq(state.highest(), 32, "H")


func test_run_state_create_copies_the_given_arrays() -> void:
	var board: PackedInt64Array = F.board_d()
	var snapshot: PackedInt64Array = F.board_e()
	var state: RunState = RunState.create(board, 0, snapshot, 8)
	board[0] = 1024
	snapshot[0] = 1024
	assert_eq(state.cells, F.board_d(), "later changes to the caller's board do not reach the state")
	assert_eq(state.snapshot_cells, F.board_e(), "later changes to the caller's snapshot do not reach the state")


func test_run_state_value_at_corners_and_off_board() -> void:
	var state: RunState = RunState.create(F.board_p(), 0)
	assert_eq(state.value_at(Vector2i(0, 0)), 2, "top left")
	assert_eq(state.value_at(Vector2i(4, 0)), 2, "top right")
	assert_eq(state.value_at(Vector2i(0, 7)), 8, "bottom left")
	assert_eq(state.value_at(Vector2i(4, 7)), 8, "bottom right")
	assert_eq(state.value_at(Vector2i(2, 7)), 32, "the 32")
	assert_eq(state.value_at(Vector2i(-1, 0)), 0, "left of the board")
	assert_eq(state.value_at(Vector2i(5, 0)), 0, "right of the board, not the next row")
	assert_eq(state.value_at(Vector2i(0, 8)), 0, "below the board")
	assert_eq(state.value_at(Vector2i(0, -1)), 0, "above the board")
	assert_eq(state.value_at(Vector2i(-1, -1)), 0, "no cell")


func test_run_state_copy_is_deep_and_equal() -> void:
	var state: RunState = RunState.create(F.board_p(), 500, F.board_d(), 16, 64)
	var other: RunState = state.copy()
	assert_true(other.equals(state), "a copy equals the original")
	assert_true(state.equals(other), "equality goes both ways")
	other.cells[0] = 1024
	other.snapshot_cells[0] = 1024
	assert_eq(state.cells, F.board_p(), "changing the copy's board leaves the original")
	assert_eq(state.snapshot_cells, F.board_d(), "changing the copy's snapshot leaves the original")
	assert_false(other.equals(state), "the changed copy is no longer equal")


func test_run_state_copy_keeps_a_zero_run_highest() -> void:
	var state: RunState = RunState.new()
	state.cells = F.board_d()
	var other: RunState = state.copy()
	assert_eq(other.run_highest, 0, "copy takes run_highest as it is")
	assert_true(other.equals(state), "and stays equal")


func test_run_state_equals_checks_every_field() -> void:
	var base: RunState = RunState.create(F.board_p(), 500, F.board_d(), 16, 64)
	assert_false(base.equals(null), "never equal to null")
	var other: RunState = base.copy()
	other.cells[39] = 16
	assert_false(base.equals(other), "a different cell")
	other = base.copy()
	other.score = 501
	assert_false(base.equals(other), "a different score")
	other = base.copy()
	other.snapshot_cells = PackedInt64Array()
	assert_false(base.equals(other), "no snapshot")
	other = base.copy()
	other.snapshot_cells[5] = 4
	assert_false(base.equals(other), "a different snapshot board")
	other = base.copy()
	other.snapshot_points = 17
	assert_false(base.equals(other), "different snapshot points")
	other = base.copy()
	other.run_highest = 128
	assert_false(base.equals(other), "a different run highest")
	other = base.copy()
	other.columns = 4
	assert_false(base.equals(other), "different columns")


func test_records_rise_and_never_drop() -> void:
	var records: Records = Records.new()
	assert_eq(records.best_score, 0, "Best Score starts at 0")
	assert_eq(records.best_tile, 0, "Best Tile starts at 0")
	assert_true(records.update_from(RunState.create(F.board_d(), 100)), "both rise")
	assert_eq(records.best_score, 100, "Best Score")
	assert_eq(records.best_tile, 16, "Best Tile is H")
	assert_false(records.update_from(RunState.create(F.board_d(), 50)), "a lower score changes nothing")
	assert_eq(records.best_score, 100, "Best Score never drops")
	assert_true(records.update_from(RunState.create(F.board_p(), 50)), "a higher tile alone rises")
	assert_eq(records.best_tile, 32, "Best Tile rose")
	assert_eq(records.best_score, 100, "Best Score kept")
	assert_true(records.update_from(RunState.create(F.board_d(), 101)), "a higher score alone rises")
	assert_eq(records.best_tile, 32, "Best Tile never drops when H is lower")


## GDD 11.2 example B1 and B2: Best Score follows the score live and stays when spending lowers the score.
func test_records_b1_b2_best_score_live() -> void:
	var records: Records = F.records(10000, 0)
	records.update_from(RunState.create(F.board_d(), 10500))
	assert_eq(records.best_score, 10500, "B1")
	records.update_from(RunState.create(F.board_d(), 8452))
	assert_eq(records.best_score, 10500, "B2")


func test_records_copy_is_independent() -> void:
	var records: Records = F.records(5000, 512)
	var other: Records = records.copy()
	assert_eq(other.best_score, 5000, "copied Best Score")
	assert_eq(other.best_tile, 512, "copied Best Tile")
	other.best_score = 1
	assert_eq(records.best_score, 5000, "the original is untouched")


func test_move_result_defaults() -> void:
	var result: MoveResult = MoveResult.new()
	assert_false(result.accepted, "not accepted")
	assert_eq(result.refusal, &"", "no refusal")
	assert_eq(result.result_cell, Vector2i(-1, -1), "no result cell")
	assert_true(result.has_valid_move, "has_valid_move defaults to true")
	assert_true(result.chain.is_empty(), "no chain")
	assert_true(result.spawn_values.is_empty(), "no spawns")
	assert_false(result.offer_opens, "no offer")
	assert_false(result.run_ends, "no run end")
	assert_eq(MoveResult.Kind.size(), 7, "seven kinds")


func test_booster_status_and_run_summary_hold_their_fields() -> void:
	var status: BoosterStatus = BoosterStatus.new()
	status.id = &"undo"
	status.cost = 64
	status.usable = false
	status.reason = BoosterStatus.Usability.NO_SNAPSHOT
	status.active = false
	status.suggested = true
	assert_eq(status.reason, BoosterStatus.Usability.NO_SNAPSHOT, "reason")
	assert_eq(BoosterStatus.Usability.size(), 3, "three usability values")
	var summary: RunSummary = RunSummary.new()
	summary.final_score = 476
	summary.run_highest = 1024
	summary.no_moves_left = true
	assert_eq(summary.final_score, 476, "final score")
	assert_eq(summary.best_score, 0, "best score defaults to 0")
	assert_false(summary.new_best_score, "no badge by default")
