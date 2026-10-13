extends "res://tests/base_test.gd"
## SaveCodec, run half (docs/ARCHITECTURE.md section 10, GDD 15.1, TH18).
## Data goes through JSON text first, so numbers arrive as floats exactly as
## they do from a real file.

const F := preload("res://tests/save/save_fixtures.gd")
const INT64_MAX: int = 9223372036854775807

var _config: GameConfig = GameConfig.new()


func before_each() -> void:
	_config = GameConfig.new()


## data written as JSON text and parsed back, as a file would give it.
func _through_json(data: Variant) -> Variant:
	return JSON.parse_string(F.to_text(data))


## The AT-95 control run as parsed file data. A fresh copy every call.
func _control_data() -> Dictionary:
	return _through_json(SaveCodec.run_to_data(F.control_run()))


func _load(data: Variant) -> RunState:
	return SaveCodec.data_to_run(data, _config)


func _exponents(values: PackedInt64Array) -> Array:
	var result: Array = []
	for value: int in values:
		var exponent: int = 0
		while (value >> exponent) > 1:
			exponent += 1
		result.append(exponent)
	return result


# Writing

func test_run_to_data_uses_the_documented_format() -> void:
	var state: RunState = F.control_run()
	var data: Dictionary = SaveCodec.run_to_data(state)
	assert_eq(data.keys(), ["format", "columns", "rows", "cells", "score", "run_highest", "free_used", "best_at_start", "snapshot"], "exact keys in order")
	assert_eq(data["format"], 2, "format")
	assert_eq(data["columns"], 5, "columns")
	assert_eq(data["rows"], 8, "rows")
	assert_eq(data["cells"], _exponents(state.cells), "cells as exponents")
	assert_eq((data["cells"] as Array)[2], 10, "the 1024 on (2,0) is exponent 10")
	assert_eq((data["cells"] as Array)[0], 1, "a 2 is exponent 1")
	assert_eq(data["score"], "41286", "score as a digit string")
	assert_eq(data["run_highest"], 11, "run highest 2048 as exponent 11")
	assert_eq(data["free_used"], 0, "free boosters used as a whole number")
	assert_eq(typeof(data["free_used"]), TYPE_INT, "written as an int")
	assert_eq(data["best_at_start"], "38500", "Best Score when the run began as a digit string")
	var snapshot: Dictionary = data["snapshot"]
	assert_eq(snapshot.keys(), ["cells", "points"], "snapshot keys")
	assert_eq(snapshot["cells"], _exponents(F.board_d()), "snapshot cells as exponents")
	assert_eq(snapshot["points"], "96", "snapshot points as a digit string")
	assert_eq(SaveCodec.RUN_FORMAT, 2, "RUN_FORMAT constant")
	assert_eq(SaveCodec.PROFILE_FORMAT, 1, "PROFILE_FORMAT constant")


func test_run_to_data_without_snapshot_writes_null() -> void:
	var data: Dictionary = SaveCodec.run_to_data(F.plain_run())
	assert_true(data.has("snapshot"), "the key is always there")
	assert_eq(typeof(data["snapshot"]), TYPE_NIL, "no snapshot is null")


func test_run_to_data_of_null_is_empty_and_refused() -> void:
	var data: Dictionary = SaveCodec.run_to_data(null)
	assert_true(data.is_empty(), "nothing to write")
	assert_true(_load(data) == null, "and nothing loads from it")


func test_run_to_data_marks_values_the_format_cannot_hold() -> void:
	var cells: PackedInt64Array = F.with_cell(F.board_d(), Vector2i(3, 3), 12)
	var data: Dictionary = SaveCodec.run_to_data(F.run(cells, 10))
	assert_eq((data["cells"] as Array)[18], -1, "12 is not a power of two")
	assert_true(_load(_through_json(data)) == null, "so the run is refused")
	var negative: Dictionary = SaveCodec.run_to_data(F.run(F.board_d(), -5))
	assert_eq(negative["score"], "-5", "a negative score is written as is")
	assert_true(_load(_through_json(negative)) == null, "and refused on load")


func test_an_unknown_best_at_start_is_never_written() -> void:
	# RunState.create leaves best_at_start at -1 (unknown, as from a format 1
	# file). GameSession replaces it before any save; if it ever did not, the
	# file would hold a value that is not true, so the save is refused instead.
	var state: RunState = RunState.create(F.board_d(), 10)
	assert_eq(state.best_at_start, -1, "unknown")
	var data: Dictionary = SaveCodec.run_to_data(state)
	assert_eq(data["best_at_start"], "-1", "encoded as is")
	assert_true(_load(data) == null, "and refused, so SaveService never writes it")
	assert_true(_load(_through_json(data)) == null, "through a file too")


# Round trips

func test_round_trip_with_snapshot() -> void:
	var state: RunState = F.control_run()
	var loaded: RunState = _load(_through_json(SaveCodec.run_to_data(state)))
	assert_true(loaded != null, "loads")
	assert_true(state.equals(loaded), "equals the saved run exactly")
	assert_true(loaded.has_snapshot(), "snapshot kept")
	assert_eq(loaded.snapshot_points, 96, "snapshot points")
	assert_eq(loaded.run_highest, 2048, "run highest")


func test_round_trip_without_snapshot() -> void:
	var state: RunState = F.plain_run()
	var loaded: RunState = _load(_through_json(SaveCodec.run_to_data(state)))
	assert_true(loaded != null and state.equals(loaded), "equals the saved run")
	assert_false(loaded.has_snapshot(), "still no snapshot")


func test_round_trip_values_up_to_2_62() -> void:
	var board: PackedInt64Array = F.board_huge()
	# 2^62 gives 52 stars, so 17 free boosters earned; all of them used.
	var state: RunState = F.run(board, INT64_MAX, board, INT64_MAX, 1 << 62, 17, INT64_MAX)
	var loaded: RunState = _load(_through_json(SaveCodec.run_to_data(state)))
	assert_true(loaded != null, "loads")
	assert_true(state.equals(loaded), "every 64 bit value exact")
	assert_eq(loaded.cells[0], 4611686018427387904, "2^62 exactly")
	assert_eq(loaded.cells[1], 2305843009213693952, "2^61 exactly")
	assert_eq(loaded.score, INT64_MAX, "score 2^63 minus 1 exactly")
	assert_eq(loaded.snapshot_points, INT64_MAX, "points 2^63 minus 1 exactly")
	assert_eq(loaded.run_highest, 4611686018427387904, "run highest 2^62 exactly")
	assert_eq(loaded.free_used, 17, "every free booster earned can be used")
	assert_eq(loaded.best_at_start, INT64_MAX, "Best Score when the run began 2^63 minus 1 exactly")


func test_round_trip_score_zero() -> void:
	var state: RunState = F.run(F.board_d(), 0)
	var loaded: RunState = _load(_through_json(SaveCodec.run_to_data(state)))
	assert_true(loaded != null and loaded.score == 0, "score 0 is \"0\" and loads")
	assert_true(loaded != null and loaded.best_at_start == 0, "Best Score 0 when the run began is \"0\" and loads")


func test_round_trip_free_used_and_best_at_start() -> void:
	# Board D with a 131072 (exponent 17): 7 stars, 2 free boosters earned.
	var cells: PackedInt64Array = F.with_cell(F.board_d(), Vector2i(2, 0), 131072)
	for used: int in [0, 1, 2]:
		var state: RunState = F.run(cells, 5000, PackedInt64Array(), 0, 0, used, 4000)
		var loaded: RunState = _load(_through_json(SaveCodec.run_to_data(state)))
		assert_true(loaded != null and state.equals(loaded), "%d used: equals the saved run" % used)
		if loaded != null:
			assert_eq(loaded.free_used, used, "%d used: free_used kept" % used)
			assert_eq(loaded.best_at_start, 4000, "%d used: best_at_start kept" % used)
			assert_eq(CoreRules.free_held(loaded, _config), 2 - used, "%d used: free boosters held" % used)


func test_documented_example_loads() -> void:
	# Written by hand from docs/ARCHITECTURE.md section 10, not by run_to_data.
	var text: String = """{
	"format": 2,
	"columns": 5,
	"rows": 8,
	"cells": [1, 2, 10, 2, 1, 3, 4, 3, 4, 3, 1, 2, 1, 2, 1, 3, 4, 3, 4, 3,
	          1, 2, 1, 2, 1, 3, 4, 3, 4, 3, 1, 2, 1, 2, 1, 3, 4, 3, 4, 3],
	"score": "41286",
	"run_highest": 11,
	"free_used": 0,
	"best_at_start": "38500",
	"snapshot": {"cells": [1, 2, 1, 2, 1, 3, 4, 3, 4, 3, 1, 2, 1, 2, 1, 3, 4, 3, 4, 3,
	                       1, 2, 1, 2, 1, 3, 4, 3, 4, 3, 1, 2, 1, 2, 1, 3, 4, 3, 4, 3], "points": "96"}
}"""
	var loaded: RunState = _load(JSON.parse_string(text))
	assert_true(loaded != null, "the documented format loads")
	assert_true(F.control_run().equals(loaded), "to the expected run")


func test_a_format_1_file_still_loads() -> void:
	# As a build before D-46 wrote it, by hand: no free_used, no best_at_start.
	var text: String = """{
	"format": 1,
	"columns": 5,
	"rows": 8,
	"cells": [1, 2, 10, 2, 1, 3, 4, 3, 4, 3, 1, 2, 1, 2, 1, 3, 4, 3, 4, 3,
	          1, 2, 1, 2, 1, 3, 4, 3, 4, 3, 1, 2, 1, 2, 1, 3, 4, 3, 4, 3],
	"score": "41286",
	"run_highest": 11,
	"snapshot": {"cells": [1, 2, 1, 2, 1, 3, 4, 3, 4, 3, 1, 2, 1, 2, 1, 3, 4, 3, 4, 3,
	                       1, 2, 1, 2, 1, 3, 4, 3, 4, 3, 1, 2, 1, 2, 1, 3, 4, 3, 4, 3], "points": "96"}
}"""
	var loaded: RunState = _load(JSON.parse_string(text))
	assert_true(loaded != null, "a format 1 file loads")
	assert_true(F.as_format_1(F.control_run()).equals(loaded), "to the same run")
	if loaded != null:
		assert_eq(loaded.free_used, 0, "with no free booster used")
		assert_eq(loaded.best_at_start, -1, "and the starting Best Score unknown")
	var from_code: RunState = _load(F.format_1_data(F.plain_run()))
	assert_true(F.as_format_1(F.plain_run()).equals(from_code), "format 1 data with ints loads too")


func test_format_and_keys_must_match() -> void:
	var format_1: Dictionary = _through_json(F.format_1_data(F.control_run()))
	assert_true(_load(format_1) != null, "format 1 with exactly the format 1 keys")
	var relabelled_2: Dictionary = format_1.duplicate(true)
	relabelled_2["format"] = 2
	assert_true(_load(relabelled_2) == null, "format 2 without the two new keys")
	var relabelled_1: Dictionary = _control_data()
	relabelled_1["format"] = 1
	assert_true(_load(relabelled_1) == null, "format 1 with the two new keys")
	for key: String in ["free_used", "best_at_start"]:
		var one_new_key: Dictionary = format_1.duplicate(true)
		one_new_key[key] = _control_data()[key]
		assert_true(_load(one_new_key) == null, "format 1 with only %s added" % key)
		var one_missing: Dictionary = _control_data()
		one_missing.erase(key)
		assert_true(_load(one_missing) == null, "format 2 with %s missing" % key)
	for format: Variant in [0, 3, -1, 1.5, 2.0000001, "2", true, null, INF, NAN]:
		var data: Dictionary = _control_data()
		data["format"] = format
		assert_true(_load(data) == null, "format %s with format 2 keys" % str(format))
		var old: Dictionary = format_1.duplicate(true)
		old["format"] = format
		assert_true(_load(old) == null, "format %s with format 1 keys" % str(format))


func test_whole_numbers_load_as_float_or_int() -> void:
	var from_code: Dictionary = SaveCodec.run_to_data(F.control_run())
	assert_eq(typeof(from_code["format"]), TYPE_INT, "run_to_data writes ints")
	assert_true(_load(from_code) != null, "ints load")
	var from_file: Dictionary = _control_data()
	assert_eq(typeof(from_file["format"]), TYPE_FLOAT, "the JSON parser gives floats")
	assert_true(_load(from_file) != null, "whole floats load")


# Refusals: shape

func test_refuses_anything_but_an_object() -> void:
	var cases: Array = [null, [], [1, 2], "run", 1, 1.0, true, {}, PackedInt64Array([1, 2]), Vector2i(1, 1)]
	for value: Variant in cases:
		assert_true(_load(value) == null, "refused: %s" % type_string(typeof(value)))


func test_refuses_each_missing_key() -> void:
	for key: String in ["format", "columns", "rows", "cells", "score", "run_highest", "free_used", "best_at_start", "snapshot"]:
		var data: Dictionary = _control_data()
		data.erase(key)
		assert_true(_load(data) == null, "missing %s" % key)
	for key: String in ["format", "columns", "rows", "cells", "score", "run_highest", "snapshot"]:
		var data: Dictionary = _through_json(F.format_1_data(F.control_run()))
		data.erase(key)
		assert_true(_load(data) == null, "format 1 missing %s" % key)


func test_refuses_extra_keys() -> void:
	var data: Dictionary = _control_data()
	data["targeting"] = "swap"
	assert_true(_load(data) == null, "extra top level key")
	var with_snapshot_extra: Dictionary = _control_data()
	(with_snapshot_extra["snapshot"] as Dictionary)["score"] = "1"
	assert_true(_load(with_snapshot_extra) == null, "extra snapshot key")
	var missing_points: Dictionary = _control_data()
	(missing_points["snapshot"] as Dictionary).erase("points")
	assert_true(_load(missing_points) == null, "missing snapshot key")
	var renamed: Dictionary = _control_data()
	renamed.erase("score")
	renamed["Score"] = "41286"
	assert_true(_load(renamed) == null, "a key in the wrong case")


func test_refuses_wrong_types_in_every_field() -> void:
	var wrong: Dictionary = {
		"format": ["2", true, null, [], {}, 1.5, 2.5, 1, 3, 0],
		"columns": ["5", true, null, [], {}, 5.5],
		"rows": ["8", true, null, [], {}, 8.5],
		"cells": ["1", 1, true, null, {}, [], [[1]]],
		"score": [41286, 41286.0, true, null, [], {}],
		"run_highest": ["11", true, null, [], {}, 11.5],
		"free_used": ["0", true, false, null, [], {}, [0], 0.5],
		"best_at_start": [38500, 38500.0, true, null, [], {}, ["38500"]],
		"snapshot": ["none", 0, false, [], {}],
	}
	for key: String in wrong:
		for value: Variant in wrong[key]:
			var data: Dictionary = _control_data()
			data[key] = value
			assert_true(_load(data) == null, "%s = %s (%s)" % [key, str(value), type_string(typeof(value))])
	for value: Variant in ["1", 1, true, null, {}, []]:
		var data: Dictionary = _control_data()
		(data["snapshot"] as Dictionary)["cells"] = value
		assert_true(_load(data) == null, "snapshot.cells = %s" % str(value))
	for value: Variant in [96, 96.0, true, null, [], {}]:
		var data: Dictionary = _control_data()
		(data["snapshot"] as Dictionary)["points"] = value
		assert_true(_load(data) == null, "snapshot.points = %s" % str(value))


func test_refuses_bad_cell_exponents() -> void:
	var bad: Array = [0, 63, 64, -1, -62, 1.5, -0.5, 2.0000001, 62.5, INF, -INF, NAN, 1e20, 1e308, 9007199254740993.0,
		true, false, "1", "", null, [], [1], {}]
	for value: Variant in bad:
		var data: Dictionary = _control_data()
		(data["cells"] as Array)[7] = value
		assert_true(_load(data) == null, "cell exponent %s (%s)" % [str(value), type_string(typeof(value))])
		var in_snapshot: Dictionary = _control_data()
		((in_snapshot["snapshot"] as Dictionary)["cells"] as Array)[7] = value
		assert_true(_load(in_snapshot) == null, "snapshot exponent %s" % str(value))


func test_refuses_bad_run_highest() -> void:
	for value: Variant in [0, -1, 63, 1.5, INF, NAN, -0.0]:
		var data: Dictionary = _control_data()
		data["run_highest"] = value
		assert_true(_load(data) == null, "run_highest %s" % str(value))


func test_refuses_wrong_board_size() -> void:
	for size: int in [0, 1, 39, 41, 80]:
		var data: Dictionary = _control_data()
		(data["cells"] as Array).resize(size)
		(data["cells"] as Array).fill(1)
		assert_true(_load(data) == null, "%d cells" % size)
		var snapshot_data: Dictionary = _control_data()
		((snapshot_data["snapshot"] as Dictionary)["cells"] as Array).resize(size)
		((snapshot_data["snapshot"] as Dictionary)["cells"] as Array).fill(1)
		assert_true(_load(snapshot_data) == null, "%d snapshot cells" % size)
	for pair: Vector2i in [Vector2i(6, 8), Vector2i(4, 8), Vector2i(5, 7), Vector2i(5, 9), Vector2i(8, 5)]:
		var data: Dictionary = _control_data()
		data["columns"] = pair.x
		data["rows"] = pair.y
		assert_true(_load(data) == null, "%d columns, %d rows" % [pair.x, pair.y])
	for format: Variant in [0, 1, 3, -1, 1.0000001, 2.0000001]:
		var data: Dictionary = _control_data()
		data["format"] = format
		assert_true(_load(data) == null, "format %s" % str(format))


func test_board_size_follows_the_game_config() -> void:
	var small: GameConfig = GameConfig.new()
	small.rows = 6
	assert_true(SaveCodec.data_to_run(_control_data(), small) == null, "a 5 x 8 file does not load into a 5 x 6 game")
	assert_true(SaveCodec.data_to_run(_control_data(), null) == null, "no config, no run")


# Refusals: digit strings

func test_refuses_bad_digit_strings() -> void:
	var bad: Array[String] = ["", "-1", "-0", "+1", " 1", "1 ", "12a", "a12", "007", "00", "01", "1e3", "0x10", "1.0", "1,000",
		"9223372036854775808", "9999999999999999999", "18446744073709551616", "99999999999999999999",
		"1".repeat(20), "9".repeat(1000), "1".repeat(65000),
		"1\t", "\n1", "Infinity", "NaN", "null", "true",
		String.chr(0x0661) + String.chr(0x0662),    # Arabic Indic digits one and two
		String.chr(0xFF11) + String.chr(0xFF12),    # full width digits one and two
		String.chr(0x00B2)]                         # superscript two
	for text: String in bad:
		var data: Dictionary = _control_data()
		data["score"] = text
		assert_true(_load(data) == null, "score \"%s\"" % text.left(30))
		var points_data: Dictionary = _control_data()
		(points_data["snapshot"] as Dictionary)["points"] = text
		assert_true(_load(points_data) == null, "points \"%s\"" % text.left(30))
		var best_data: Dictionary = _control_data()
		best_data["best_at_start"] = text
		assert_true(_load(best_data) == null, "best_at_start \"%s\"" % text.left(30))


func test_digit_reader_refuses_overflow_instead_of_wrapping() -> void:
	# Integer math wraps silently, so a 19 digit value above 2^63 minus 1 must
	# be caught before it is added up, not left to come out negative.
	assert_eq(SaveCodec._read_digits("9223372036854775807"), INT64_MAX, "the largest value")
	assert_eq(SaveCodec._read_digits("9223372036854775808"), -1, "one more is invalid, not wrapped")
	assert_eq(SaveCodec._read_digits("9999999999999999999"), -1, "the largest 19 digits are invalid")
	assert_eq(SaveCodec._read_digits("0"), 0, "zero")


func test_accepts_digit_strings_at_the_limits() -> void:
	var cases: Dictionary = {"0": 0, "7": 7, "1000000000000000000": 1000000000000000000,
		"9223372036854775806": 9223372036854775806, "9223372036854775807": INT64_MAX}
	for text: String in cases:
		var data: Dictionary = _control_data()
		data["score"] = text
		var loaded: RunState = _load(data)
		assert_true(loaded != null, "score \"%s\" loads" % text)
		if loaded != null:
			assert_eq(loaded.score, cases[text], "score \"%s\" exact" % text)
		var best_data: Dictionary = _control_data()
		best_data["best_at_start"] = text
		var best_loaded: RunState = _load(best_data)
		assert_true(best_loaded != null, "best_at_start \"%s\" loads" % text)
		if best_loaded != null:
			assert_eq(best_loaded.best_at_start, cases[text], "best_at_start \"%s\" exact" % text)


func test_best_at_start_is_not_checked_against_the_score() -> void:
	# GDD 15.1: 0 or more, and nothing else; the records live in another file.
	for text: String in ["0", "1", "41285", "41286", "41287", "9223372036854775807"]:
		var data: Dictionary = _control_data()
		data["best_at_start"] = text
		assert_true(_load(data) != null, "best_at_start \"%s\" with score 41,286" % text)


# Refusals: free boosters used (D-46)

## Board D with a 131072 on (2,0): run highest exponent 17, 7 stars, 2 free
## boosters earned. As parsed file data.
func _earned_two_data() -> Dictionary:
	var state: RunState = F.run(F.with_cell(F.board_d(), Vector2i(2, 0), 131072), 5000)
	return _through_json(SaveCodec.run_to_data(state))


func test_free_used_from_0_up_to_the_free_boosters_earned() -> void:
	for used: int in [0, 1, 2]:
		var data: Dictionary = _earned_two_data()
		data["free_used"] = used
		var loaded: RunState = _load(data)
		assert_true(loaded != null and loaded.free_used == used, "%d of 2 earned loads" % used)
	for used: Variant in [3, 4, 17, 1000, 1e20, -1, -2, 1.5, 0.5, 2.0000001, -0.5, INF, -INF, NAN, "1", "0", true, false, null, [], [1], {}]:
		var data: Dictionary = _earned_two_data()
		data["free_used"] = used
		assert_true(_load(data) == null, "free_used %s (%s) refused" % [str(used), type_string(typeof(used))])


func test_free_used_follows_the_run_highest_tile() -> void:
	# The control run's highest tile is 2048: 1 star, no free booster earned.
	var data: Dictionary = _control_data()
	data["free_used"] = 1
	assert_true(_load(data) == null, "1 used with none earned")
	# Raising the run highest tile to 8192 earns 1 (3 stars).
	data["run_highest"] = 13
	assert_true(_load(data) != null, "1 used with 1 earned")
	data["free_used"] = 2
	assert_true(_load(data) == null, "2 used with 1 earned")
	# The limit uses the game's config (TH4): 1 star per free booster.
	var generous: GameConfig = GameConfig.new()
	generous.stars_per_free_booster = 1
	data["free_used"] = 3
	assert_true(SaveCodec.data_to_run(data, generous) != null, "3 used with 3 earned at 1 star each")
	data["free_used"] = 4
	assert_true(SaveCodec.data_to_run(data, generous) == null, "4 used with 3 earned at 1 star each")


# Refusals: GDD 15.1 rules

func test_refuses_run_highest_below_the_board() -> void:
	var data: Dictionary = _control_data()
	data["run_highest"] = 9
	assert_true(_load(data) == null, "512 is below the 1024 on the board")
	data["run_highest"] = 10
	assert_true(_load(data) != null, "1024 equals the highest tile")


func test_refuses_run_highest_below_the_snapshot_board() -> void:
	var state: RunState = F.run(F.board_d(), 500, F.with_cell(F.board_d(), Vector2i(4, 7), 4096), 40, 4096)
	var data: Dictionary = _through_json(SaveCodec.run_to_data(state))
	assert_true(_load(data) != null, "4096 covers the snapshot board")
	data["run_highest"] = 11
	assert_true(_load(data) == null, "2048 is below the 4096 on the snapshot board")


func test_snapshot_points_must_be_at_least_4() -> void:
	for points: String in ["0", "2", "3"]:
		var data: Dictionary = _control_data()
		(data["snapshot"] as Dictionary)["points"] = points
		assert_true(_load(data) == null, "points %s refused" % points)
	var data_four: Dictionary = _control_data()
	(data_four["snapshot"] as Dictionary)["points"] = "4"
	var loaded: RunState = _load(data_four)
	assert_true(loaded != null and loaded.snapshot_points == 4, "points 4 loads")


func test_loaded_state_does_not_share_the_input() -> void:
	var data: Dictionary = _control_data()
	var loaded: RunState = _load(data)
	(data["cells"] as Array)[0] = 5
	assert_eq(loaded.cells[0], 2, "the loaded board is its own")
