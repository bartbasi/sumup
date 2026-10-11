class_name SaveCodec extends RefCounted
## Turns the run and the profile into JSON shaped data and back
## (docs/ARCHITECTURE.md section 10, GDD 15.1). Pure: no files. SaveService
## does the reading and writing.
##
## Godot's JSON parser returns every number as a float, which cannot hold a 64
## bit integer exactly. So tile values are stored as exponents (2 is 1, 1024 is
## 10, 2^62 is 62) and scores and points as strings of decimal digits.
##
## Loading trusts nothing. The input is only ever plain JSON values
## (Dictionary, Array, String, float, bool, null), and nothing here turns data
## into objects or code. Every field is checked for type, exact keys and range.
## Numbers may arrive as float (from the JSON parser) or int (from code); both
## must be whole and in range.

const FORMAT: int = 1

const _RUN_KEYS: Array[String] = ["format", "columns", "rows", "cells", "score", "run_highest", "snapshot"]
const _SNAPSHOT_KEYS: Array[String] = ["cells", "points"]
const _PROFILE_KEYS: Array[String] = ["format", "settings", "records"]
const _SETTINGS_KEYS: Array[String] = ["sound_on", "skin"]
const _RECORDS_KEYS: Array[String] = ["best_score", "best_tile"]

const _MAX_EXPONENT: int = 62              # the largest tile is 2^62 (D-37)
const _MIN_SNAPSHOT_POINTS: int = 4        # the smallest chain, 2 + 2 (GDD 15.1)
const _MAX_DIGITS: int = 19
const _INT64_MAX_TEXT: String = "9223372036854775807"
const _SKIN_ID_MAX_LENGTH: int = 32
const _CHAR_ZERO: int = 48
const _CHAR_NINE: int = 57
const _CHAR_A: int = 97
const _CHAR_Z: int = 122
const _CHAR_UNDERSCORE: int = 95


## The run in the save format. A state that breaks a rule (a value that is not
## a power of two, a negative score) still encodes, but data_to_run refuses the
## result, and SaveService checks that before it writes.
@warning_ignore("integer_division")
static func run_to_data(state: RunState) -> Dictionary:
	if state == null:
		return {}
	var rows: int = 0
	if state.columns > 0:
		rows = state.cells.size() / state.columns
	var snapshot: Variant = null
	if state.has_snapshot():
		snapshot = {
			"cells": _exponents_of(state.snapshot_cells),
			"points": str(state.snapshot_points),
		}
	return {
		"format": FORMAT,
		"columns": state.columns,
		"rows": rows,
		"cells": _exponents_of(state.cells),
		"score": str(state.score),
		"run_highest": _exponent_of(state.run_highest),
		"snapshot": snapshot,
	}


## TH18. The run in data, or null when anything about it is invalid. Follows
## GDD 15.1 exactly: format 1, the board size of config, every value a power of
## two from 2 to 2^62, a score of 0 or more, a run highest tile at least the
## highest value on the board and on the snapshot board, and a snapshot that is
## null or a full board plus points of 4 or more.
static func data_to_run(data: Variant, config: GameConfig) -> RunState:
	if config == null or config.columns < 1 or config.rows < 1:
		return null
	if typeof(data) != TYPE_DICTIONARY:
		return null
	var run: Dictionary = data
	if not _has_exact_keys(run, _RUN_KEYS):
		return null
	if _read_whole(run["format"], FORMAT, FORMAT) < 0:
		return null
	if _read_whole(run["columns"], config.columns, config.columns) < 0:
		return null
	if _read_whole(run["rows"], config.rows, config.rows) < 0:
		return null
	var cells: PackedInt64Array = _read_board(run["cells"], config.cell_count())
	if cells.is_empty():
		return null
	var score: int = _read_digits(run["score"])
	if score < 0:
		return null
	var highest_exponent: int = _read_whole(run["run_highest"], 1, _MAX_EXPONENT)
	if highest_exponent < 0:
		return null
	var run_highest: int = 1 << highest_exponent
	var snapshot_cells: PackedInt64Array = PackedInt64Array()
	var snapshot_points: int = 0
	var snapshot_data: Variant = run["snapshot"]
	if typeof(snapshot_data) != TYPE_NIL:
		if typeof(snapshot_data) != TYPE_DICTIONARY:
			return null
		var snapshot: Dictionary = snapshot_data
		if not _has_exact_keys(snapshot, _SNAPSHOT_KEYS):
			return null
		snapshot_cells = _read_board(snapshot["cells"], config.cell_count())
		if snapshot_cells.is_empty():
			return null
		snapshot_points = _read_digits(snapshot["points"])
		if snapshot_points < _MIN_SNAPSHOT_POINTS:
			return null
	if run_highest < CoreRules.highest(cells) or run_highest < CoreRules.highest(snapshot_cells):
		return null
	return RunState.create(cells, score, snapshot_cells, snapshot_points, run_highest, config.columns)


## The profile in the save format. best_tile is 0 for no tile yet, else an
## exponent.
static func profile_to_data(settings: Settings, records: Records) -> Dictionary:
	var source_settings: Settings = settings if settings != null else Settings.new()
	var source_records: Records = records if records != null else Records.new()
	var best_tile: int = 0
	if source_records.best_tile != 0:
		best_tile = _exponent_of(source_records.best_tile)
	return {
		"format": FORMAT,
		"settings": {
			"sound_on": source_settings.sound_on,
			"skin": String(source_settings.skin_id),
		},
		"records": {
			"best_score": str(source_records.best_score),
			"best_tile": best_tile,
		},
	}


## Applies every valid part of a profile and returns the problems found
## (empty when the profile is fully valid).
##
## The data must be an object with format 1, or nothing is applied. After that
## each of the four fields (settings.sound_on, settings.skin,
## records.best_score, records.best_tile) is checked on its own: a valid one is
## applied, a missing or invalid one leaves the value the object already holds
## (the default for a fresh object). Keys outside the format are reported and
## never read. Settings change through their setters, so their signals fire
## only for values that really change.
static func data_to_profile(data: Variant, settings: Settings, records: Records) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	if typeof(data) != TYPE_DICTIONARY:
		problems.append("profile is not an object")
		return problems
	var profile: Dictionary = data
	if not profile.has("format") or _read_whole(profile["format"], FORMAT, FORMAT) < 0:
		problems.append("profile format is not %d" % FORMAT)
		return problems
	_report_unknown_keys(profile, _PROFILE_KEYS, "profile", problems)
	var settings_data: Dictionary = _read_part(profile, "settings", _SETTINGS_KEYS, problems)
	var records_data: Dictionary = _read_part(profile, "records", _RECORDS_KEYS, problems)

	if settings_data.has("sound_on") and typeof(settings_data["sound_on"]) == TYPE_BOOL:
		if settings != null:
			settings.set_sound_on(settings_data["sound_on"])
	else:
		problems.append("settings.sound_on is missing or invalid")

	var skin: String = ""
	if settings_data.has("skin"):
		skin = _read_skin_id(settings_data["skin"])
	if not skin.is_empty():
		if settings != null:
			settings.set_skin_id(StringName(skin))
	else:
		problems.append("settings.skin is missing or invalid")

	var best_score: int = -1
	if records_data.has("best_score"):
		best_score = _read_digits(records_data["best_score"])
	if best_score >= 0:
		if records != null:
			records.best_score = best_score
	else:
		problems.append("records.best_score is missing or invalid")

	var best_tile_exponent: int = -1
	if records_data.has("best_tile"):
		best_tile_exponent = _read_whole(records_data["best_tile"], 0, _MAX_EXPONENT)
	if best_tile_exponent >= 0:
		if records != null:
			records.best_tile = 0 if best_tile_exponent == 0 else 1 << best_tile_exponent
	else:
		problems.append("records.best_tile is missing or invalid")
	return problems


## The exponent k of value 2^k for k from 1 to 62, or -1 for anything else.
static func _exponent_of(value: int) -> int:
	if not CoreRules.is_power_of_two(value) or value < 2:
		return -1
	var exponent: int = 0
	while (value >> exponent) > 1:
		exponent += 1
	return exponent


static func _exponents_of(values: PackedInt64Array) -> Array:
	var exponents: Array = []
	for value: int in values:
		exponents.append(_exponent_of(value))
	return exponents


## A whole number from low to high (low is 0 or more), or -1 when value is not
## one. Accepts an int, or a finite float with no fraction. Rejects everything
## else, including bool, NaN, infinity and strings.
static func _read_whole(value: Variant, low: int, high: int) -> int:
	match typeof(value):
		TYPE_INT:
			var whole: int = value
			if whole >= low and whole <= high:
				return whole
		TYPE_FLOAT:
			var number: float = value
			if is_finite(number) and number == floorf(number) and number >= low and number <= high:
				return int(number)
	return -1


## A board of exactly count exponents, as tile values, or an empty array when
## the data is not one.
static func _read_board(value: Variant, count: int) -> PackedInt64Array:
	var cells: PackedInt64Array = PackedInt64Array()
	if typeof(value) != TYPE_ARRAY:
		return cells
	var list: Array = value
	if list.size() != count:
		return cells
	for item: Variant in list:
		var exponent: int = _read_whole(item, 1, _MAX_EXPONENT)
		if exponent < 0:
			return PackedInt64Array()
		cells.append(1 << exponent)
	return cells


## A string of 1 to 19 ASCII digits with no leading zero (unless it is "0")
## that fits in a signed 64 bit integer, as its value, or -1 when value is not
## one. Signs, spaces, exponents and non ASCII digits are all refused.
static func _read_digits(value: Variant) -> int:
	if typeof(value) != TYPE_STRING:
		return -1
	var text: String = value
	var length: int = text.length()
	if length < 1 or length > _MAX_DIGITS:
		return -1
	if length > 1 and text.unicode_at(0) == _CHAR_ZERO:
		return -1
	for index: int in length:
		var code: int = text.unicode_at(index)
		if code < _CHAR_ZERO or code > _CHAR_NINE:
			return -1
	# Same length strings of digits compare in numeric order.
	if length == _MAX_DIGITS and text > _INT64_MAX_TEXT:
		return -1
	var result: int = 0
	for index: int in length:
		result = result * 10 + (text.unicode_at(index) - _CHAR_ZERO)
	return result


## A skin id of 1 to 32 characters from a to z and underscore, or "" when
## value is not one.
static func _read_skin_id(value: Variant) -> String:
	if typeof(value) != TYPE_STRING:
		return ""
	var text: String = value
	if text.is_empty() or text.length() > _SKIN_ID_MAX_LENGTH:
		return ""
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		if not ((code >= _CHAR_A and code <= _CHAR_Z) or code == _CHAR_UNDERSCORE):
			return ""
	return text


## True when every key is a String from keys and every one of keys is there.
static func _has_exact_keys(data: Dictionary, keys: Array[String]) -> bool:
	if data.size() != keys.size():
		return false
	for key: Variant in data:
		if typeof(key) != TYPE_STRING or not keys.has(key):
			return false
	return true


## The object under key in profile, or an empty one (after noting the
## problem) when it is missing or not an object. Unknown keys inside it are
## reported too.
static func _read_part(profile: Dictionary, key: String, keys: Array[String], problems: PackedStringArray) -> Dictionary:
	if not profile.has(key) or typeof(profile[key]) != TYPE_DICTIONARY:
		problems.append("%s is missing or not an object" % key)
		return {}
	var part: Dictionary = profile[key]
	_report_unknown_keys(part, keys, key, problems)
	return part


static func _report_unknown_keys(data: Dictionary, keys: Array[String], where: String, problems: PackedStringArray) -> void:
	for key: Variant in data:
		if typeof(key) != TYPE_STRING or not keys.has(key):
			problems.append("%s has an unknown key" % where)
			return
