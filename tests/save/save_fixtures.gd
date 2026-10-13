extends RefCounted
## Shared helpers for the save tests: boards, states, and a temp folder inside
## user:// that each test creates and removes. No test touches the real save
## files (user://run.json and user://profile.json).

const TEMP_ROOT: String = "user://test_save_tmp"
## Placeholder that raw_text swaps for a literal the JSON writer cannot make.
const RAW: String = "@RAW@"

static var _made: int = 0


## A fresh empty folder for one test.
static func make_temp_dir() -> String:
	_made += 1
	var path: String = TEMP_ROOT.path_join("%d_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec(), _made])
	DirAccess.make_dir_recursive_absolute(path)
	return path


## Deletes a folder made by make_temp_dir and everything in it, then the
## shared root when it is empty. Refuses any path outside TEMP_ROOT.
static func remove_temp_dir(path: String) -> void:
	if not path.begins_with(TEMP_ROOT + "/"):
		return
	_remove_tree(path)
	if DirAccess.dir_exists_absolute(TEMP_ROOT) and DirAccess.get_files_at(TEMP_ROOT).is_empty() and DirAccess.get_directories_at(TEMP_ROOT).is_empty():
		DirAccess.remove_absolute(TEMP_ROOT)


static func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub_dir: String in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(sub_dir))
	for file_name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)


static func write_text(path: String, text: String) -> void:
	write_bytes(path, text.to_utf8_buffer())


static func write_bytes(path: String, bytes: PackedByteArray) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


## The file's bytes, or an empty array when it cannot be read.
static func read_bytes(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	return bytes


static func read_text(path: String) -> String:
	return read_bytes(path).get_string_from_utf8()


## data as JSON text, the way SaveService writes it.
static func to_text(data: Variant) -> String:
	return JSON.stringify(data, "\t", false)


## data as JSON text with the string "@RAW@" replaced by raw, unquoted. Used
## for literals the JSON writer never makes, such as 1e400.
static func raw_text(data: Variant, raw: String) -> String:
	return to_text(data).replace("\"%s\"" % RAW, raw)


## text followed by spaces until it is size bytes long. Trailing spaces are
## valid JSON, so only the size changes.
static func padded(text: String, size: int) -> String:
	var bytes: int = text.to_utf8_buffer().size()
	return text + " ".repeat(maxi(0, size - bytes))


## GDD 19.0 Board D: no valid move, H = 16.
static func board_d() -> PackedInt64Array:
	var cells: PackedInt64Array = PackedInt64Array()
	for row: int in 8:
		for column: int in 5:
			if row % 2 == 0:
				cells.append(2 if column % 2 == 0 else 4)
			else:
				cells.append(8 if column % 2 == 0 else 16)
	return cells


## board with one cell changed. The board passed in is not changed.
static func with_cell(board: PackedInt64Array, cell: Vector2i, value: int) -> PackedInt64Array:
	var cells: PackedInt64Array = board.duplicate()
	cells[cell.y * 5 + cell.x] = value
	return cells


## A board of 40 different values from 2^62 down to 2^24, then a 2 in the
## last cell: the largest values the save format allows.
static func board_huge() -> PackedInt64Array:
	var cells: PackedInt64Array = PackedInt64Array()
	for index: int in 39:
		cells.append(1 << (62 - index))
	cells.append(2)
	return cells


## A run state that can be saved: like RunState.create, but the Best Score
## when the run began defaults to 0 (known) instead of -1 (unknown), as
## GameSession sets it for every live run. A state with -1 is never written.
static func run(cells: PackedInt64Array, score: int, snapshot_cells: PackedInt64Array = PackedInt64Array(), snapshot_points: int = 0, run_highest: int = 0, free_used: int = 0, best_at_start: int = 0) -> RunState:
	return RunState.create(cells, score, snapshot_cells, snapshot_points, run_highest, 5, free_used, best_at_start)


## The AT-95 control run: Board D with a 1024 on (2,0), score 41,286, run
## highest 2048, an Undo snapshot of Board D worth 96 points, no free booster
## used, and a Best Score of 38,500 when the run began.
static func control_run() -> RunState:
	return run(with_cell(board_d(), Vector2i(2, 0), 1024), 41286, board_d(), 96, 2048, 0, 38500)


## A run with no snapshot.
static func plain_run() -> RunState:
	return run(with_cell(board_d(), Vector2i(0, 0), 32), 1500, PackedInt64Array(), 0, 0, 0, 1000)


## A run file as a build before D-46 wrote it: format 1, without free_used and
## best_at_start. Built from state's format 2 data, with ints as from code.
static func format_1_data(state: RunState) -> Dictionary:
	var data: Dictionary = SaveCodec.run_to_data(state)
	data["format"] = 1
	data.erase("free_used")
	data.erase("best_at_start")
	return data


## state as it loads from a format 1 file: free_used 0, best_at_start -1.
static func as_format_1(state: RunState) -> RunState:
	var loaded: RunState = state.copy()
	loaded.free_used = 0
	loaded.best_at_start = -1
	return loaded
