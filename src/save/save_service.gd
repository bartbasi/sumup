class_name SaveService extends RefCounted
## Reads and writes the two save files (docs/ARCHITECTURE.md section 10):
## run.json holds the current run and is deleted when the run ends;
## profile.json holds the settings and records and is kept forever. Both live
## in user://, or in a test folder inside user://.
##
## Reading. A file over 64 KB is refused before any of it is read. A NUL byte
## (the UTF-8 decoder would silently stop there) or nesting deeper than
## _MAX_NESTING (our files nest 3 deep) is refused before parsing. Then
## Godot's JSON class parses the text into plain values and SaveCodec checks
## every field. Nothing here can turn file data into an object or code.
##
## Writing. The whole file goes to <name>.tmp, is closed, read back and
## compared byte for byte, and only then renamed over the real file. On
## Windows, Godot's rename deletes the old file before it moves the new one in
## (measured in Phase 3: a missing source still deletes the target, and a
## second process sees the target missing between the two steps), so a kill
## at that moment leaves only <name>.tmp. On Android, Godot uses POSIX rename,
## which replaces the file in one step. Loading covers both: it uses the real
## file when it is good,
## else a good <name>.tmp, which it then renames into place. So a kill at any
## moment leaves the old save or the new one.

const RUN_FILE: String = "run.json"
const PROFILE_FILE: String = "profile.json"
const TEMP_SUFFIX: String = ".tmp"
const MAX_BYTES: int = 65536

const _MAX_NESTING: int = 16    # our files nest 3 deep; a wrong typed field may add a little
const _ROOT: String = "user://"
const _BYTE_NUL: int = 0
const _BYTE_QUOTE: int = 0x22
const _BYTE_BACKSLASH: int = 0x5C
const _BYTE_OPEN_SQUARE: int = 0x5B
const _BYTE_CLOSE_SQUARE: int = 0x5D
const _BYTE_OPEN_CURLY: int = 0x7B
const _BYTE_CLOSE_CURLY: int = 0x7D

enum _Status { MISSING, UNREADABLE, BROKEN, PARSED }


## What reading one file found. data is set only when status is PARSED.
class FileRead extends RefCounted:
	var status: int = 0    # a _Status value
	var data: Variant = null


var _directory: String = ""


## directory must be inside user://. Tests pass a temp folder there. Any other
## folder is a programming error: the service then refuses every call and
## touches nothing.
func _init(directory: String = _ROOT) -> void:
	if directory.begins_with(_ROOT) and not directory.contains(".."):
		_directory = directory
	else:
		push_error("SaveService: refusing a save folder outside user://: %s" % directory)


## Writes the run. Returns false, and leaves the last good save in place, when
## the state would not load back (SaveCodec refuses it) or the write fails.
@warning_ignore("integer_division")
func save_run(state: RunState) -> bool:
	if _directory.is_empty() or state == null or state.columns < 1:
		return false
	var data: Dictionary = SaveCodec.run_to_data(state)
	var shape: GameConfig = GameConfig.new()
	shape.columns = state.columns
	shape.rows = state.cells.size() / state.columns
	if SaveCodec.data_to_run(data, shape) == null:
		return false
	return _write_atomic(RUN_FILE, data)


## The saved run, or null when there is none or it is invalid. A file whose
## content is invalid is discarded (deleted), so the next game is a new run. A
## file that exists but cannot be opened is left alone, because the cause may
## not last.
func load_run(config: GameConfig) -> RunState:
	if _directory.is_empty():
		return null
	var main_path: String = _path(RUN_FILE)
	var temp_path: String = main_path + TEMP_SUFFIX
	var main: FileRead = _read_json(main_path)
	if main.status == _Status.PARSED:
		var state: RunState = SaveCodec.data_to_run(main.data, config)
		if state != null:
			_remove(temp_path)    # a later write that never finished
			return state
	var temp: FileRead = _read_json(temp_path)
	if temp.status == _Status.PARSED:
		var recovered: RunState = SaveCodec.data_to_run(temp.data, config)
		if recovered != null:
			_promote(temp_path, main_path)
			return recovered
	if main.status == _Status.PARSED or main.status == _Status.BROKEN:
		_remove(main_path)
	if temp.status == _Status.PARSED or temp.status == _Status.BROKEN:
		_remove(temp_path)
	return null


## Deletes the saved run. The temp file goes first, so a kill between the two
## steps can never leave a lone temp file that would bring an ended run back.
func delete_run() -> void:
	if _directory.is_empty():
		return
	var main_path: String = _path(RUN_FILE)
	_remove(main_path + TEMP_SUFFIX)
	_remove(main_path)


## True when a run file is on disk, including a temp file that load_run could
## recover. load_run decides whether it is valid.
func has_run() -> bool:
	if _directory.is_empty():
		return false
	var main_path: String = _path(RUN_FILE)
	return FileAccess.file_exists(main_path) or FileAccess.file_exists(main_path + TEMP_SUFFIX)


func save_profile(settings: Settings, records: Records) -> bool:
	if _directory.is_empty() or settings == null or records == null:
		return false
	return _write_atomic(PROFILE_FILE, SaveCodec.profile_to_data(settings, records))


## Applies the saved profile to settings and records. Each part that is
## missing or invalid keeps the value the objects already hold, which is the
## default for fresh objects (SaveCodec.data_to_profile). A broken profile is
## not deleted: the next save_profile replaces it.
func load_profile(settings: Settings, records: Records) -> void:
	if _directory.is_empty():
		return
	var main_path: String = _path(PROFILE_FILE)
	var temp_path: String = main_path + TEMP_SUFFIX
	var data: Variant = null
	var main: FileRead = _read_json(main_path)
	if main.status == _Status.PARSED and typeof(main.data) == TYPE_DICTIONARY:
		data = main.data
		_remove(temp_path)
	else:
		var temp: FileRead = _read_json(temp_path)
		if temp.status == _Status.PARSED and typeof(temp.data) == TYPE_DICTIONARY:
			data = temp.data
			_promote(temp_path, main_path)
	SaveCodec.data_to_profile(data, settings, records)


func _path(file_name: String) -> String:
	return _directory.path_join(file_name)


## Reads and parses one file with every limit applied before parsing.
func _read_json(path: String) -> FileRead:
	var result: FileRead = FileRead.new()
	if not FileAccess.file_exists(path):
		result.status = _Status.MISSING
		return result
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		result.status = _Status.UNREADABLE
		return result
	var length: int = file.get_length()
	if length < 1 or length > MAX_BYTES:
		file.close()
		result.status = _Status.BROKEN
		return result
	var bytes: PackedByteArray = file.get_buffer(length)
	file.close()
	if bytes.size() != length:
		result.status = _Status.UNREADABLE
		return result
	result.status = _Status.BROKEN
	if bytes.has(_BYTE_NUL) or not _nesting_within(bytes, _MAX_NESTING):
		return result
	var json: JSON = JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK:
		return result
	result.status = _Status.PARSED
	result.data = json.data
	return result


## True when no array or object in the JSON text nests deeper than max_depth.
## Brackets inside strings do not count. Malformed text is left for the parser
## to refuse.
static func _nesting_within(bytes: PackedByteArray, max_depth: int) -> bool:
	var depth: int = 0
	var in_string: bool = false
	var escaped: bool = false
	for byte: int in bytes:
		if in_string:
			if escaped:
				escaped = false
			elif byte == _BYTE_BACKSLASH:
				escaped = true
			elif byte == _BYTE_QUOTE:
				in_string = false
		elif byte == _BYTE_QUOTE:
			in_string = true
		elif byte == _BYTE_OPEN_SQUARE or byte == _BYTE_OPEN_CURLY:
			depth += 1
			if depth > max_depth:
				return false
		elif byte == _BYTE_CLOSE_SQUARE or byte == _BYTE_CLOSE_CURLY:
			depth -= 1
	return true


## Writes data to <file_name>.tmp, checks it, then renames it over the real
## file. A failed write or check deletes the broken temp file. A failed rename
## keeps it, because on Windows the real file may already be gone and the temp
## file is then the newest good copy.
func _write_atomic(file_name: String, data: Dictionary) -> bool:
	var bytes: PackedByteArray = JSON.stringify(data, "\t", false).to_utf8_buffer()
	if bytes.size() > MAX_BYTES:
		return false
	if not DirAccess.dir_exists_absolute(_directory):
		if DirAccess.make_dir_recursive_absolute(_directory) != OK:
			return false
	var main_path: String = _path(file_name)
	var temp_path: String = main_path + TEMP_SUFFIX
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	var stored: bool = file.store_buffer(bytes)
	file.close()
	if not stored or not _file_holds(temp_path, bytes):
		_remove(temp_path)
		return false
	return DirAccess.rename_absolute(temp_path, main_path) == OK


## True when the file at path holds exactly bytes.
func _file_holds(path: String, bytes: PackedByteArray) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var same: bool = file.get_length() == bytes.size() and file.get_buffer(bytes.size()) == bytes
	file.close()
	return same


## Finishes a rename that a kill interrupted. If it fails, the temp file stays
## and the next load finds it again.
func _promote(temp_path: String, main_path: String) -> void:
	DirAccess.rename_absolute(temp_path, main_path)


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
