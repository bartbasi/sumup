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
##
## Queued writes (QA4-02). queue_run and queue_profile check and encode the
## data at once on the calling thread, which is cheap, and leave the file work
## to one WorkerThreadPool task, so a move's save never stalls its frame:
## - one write at a time, in one task that drains the queue;
## - the newest data for a file wins: a queued file not yet written is
##   replaced, never written twice;
## - a queued file whose bytes match what was last written is skipped;
## - every other call (the synchronous saves, delete_run and the reads) first
##   waits for the task, so nothing ever interleaves and reads see every
##   earlier save. flush() waits on its own, for app pause, focus loss and
##   close.
## Call the service from one thread only (the main thread in the game).

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

## The write queue, the only thing the writer task holds. The task never
## touches the service, so a service dropped mid write stays safe: it waits
## for its task when it is freed. mutex guards the other fields.
class WriteQueue extends RefCounted:
	var directory: String = ""
	var mutex: Mutex = Mutex.new()
	## Bytes waiting to be written, by file name.
	var pending: Dictionary[String, PackedByteArray] = {}
	## The bytes last handed to a write, by file name, dropped when that
	## write fails. Lets an unchanged file be skipped.
	var written: Dictionary[String, PackedByteArray] = {}
	## True while a writer is draining the queue.
	var writing: bool = false


var _q: WriteQueue = WriteQueue.new()
## The writer task started last; only the calling thread touches it.
var _task_id: int = -1


## directory must be inside user://. Tests pass a temp folder there. Any other
## folder is a programming error: the service then refuses every call and
## touches nothing.
func _init(directory: String = _ROOT) -> void:
	if directory.begins_with(_ROOT) and not directory.contains(".."):
		_directory = directory
		_q.directory = directory
	else:
		push_error("SaveService: refusing a save folder outside user://: %s" % directory)


## Writes the run now, after any queued write. Returns false, and leaves the
## last good save in place, when the state would not load back (SaveCodec
## refuses it) or the write fails.
func save_run(state: RunState) -> bool:
	flush()
	var bytes: PackedByteArray = _run_bytes(state)
	if bytes.is_empty():
		return false
	return _write_now(RUN_FILE, bytes)


## Checks and encodes the run now and queues the write. Returns false, and
## queues nothing, when the state would not load back. A write that fails
## later is reported with push_warning and leaves the last good save.
func queue_run(state: RunState) -> bool:
	var bytes: PackedByteArray = _run_bytes(state)
	if bytes.is_empty():
		return false
	_queue(RUN_FILE, bytes)
	return true


## Waits until every queued write is on disk (or has failed and been
## reported).
func flush() -> void:
	_reap()
	_q.mutex.lock()
	var left: bool = not _q.pending.is_empty() and not _q.writing
	if left:
		_q.writing = true
	_q.mutex.unlock()
	if left:
		_drain(_q)


## The saved run, or null when there is none or it is invalid. A file whose
## content is invalid is discarded (deleted), so the next game is a new run. A
## file that exists but cannot be opened is left alone, because the cause may
## not last.
func load_run(config: GameConfig) -> RunState:
	if _directory.is_empty():
		return null
	flush()
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


## Deletes the saved run, after any queued write, so a queued run can never
## land after the delete. The temp file goes first, so a kill between the two
## steps can never leave a lone temp file that would bring an ended run back.
func delete_run() -> void:
	if _directory.is_empty():
		return
	flush()
	_q.mutex.lock()
	_q.written.erase(RUN_FILE)
	_q.mutex.unlock()
	var main_path: String = _path(RUN_FILE)
	_remove(main_path + TEMP_SUFFIX)
	_remove(main_path)


## True when a run file is on disk, including a temp file that load_run could
## recover. load_run decides whether it is valid.
func has_run() -> bool:
	if _directory.is_empty():
		return false
	flush()
	var main_path: String = _path(RUN_FILE)
	return FileAccess.file_exists(main_path) or FileAccess.file_exists(main_path + TEMP_SUFFIX)


## Writes the profile now, after any queued write.
func save_profile(settings: Settings, records: Records) -> bool:
	if _directory.is_empty() or settings == null or records == null:
		return false
	flush()
	var bytes: PackedByteArray = _encode(SaveCodec.profile_to_data(settings, records))
	if bytes.is_empty():
		return false
	return _write_now(PROFILE_FILE, bytes)


## Encodes the profile now and queues the write, like queue_run.
func queue_profile(settings: Settings, records: Records) -> bool:
	if _directory.is_empty() or settings == null or records == null:
		return false
	var bytes: PackedByteArray = _encode(SaveCodec.profile_to_data(settings, records))
	if bytes.is_empty():
		return false
	_queue(PROFILE_FILE, bytes)
	return true


## Applies the saved profile to settings and records. Each part that is
## missing or invalid keeps the value the objects already hold, which is the
## default for fresh objects (SaveCodec.data_to_profile). A broken profile is
## not deleted: the next save_profile replaces it.
func load_profile(settings: Settings, records: Records) -> void:
	if _directory.is_empty():
		return
	flush()
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


## The run as file bytes, or empty when the state would not load back.
@warning_ignore("integer_division")
func _run_bytes(state: RunState) -> PackedByteArray:
	if _directory.is_empty() or state == null or state.columns < 1:
		return PackedByteArray()
	var data: Dictionary = SaveCodec.run_to_data(state)
	var shape: GameConfig = GameConfig.new()
	shape.columns = state.columns
	shape.rows = state.cells.size() / state.columns
	if SaveCodec.data_to_run(data, shape) == null:
		return PackedByteArray()
	return _encode(data)


## data as file bytes, or empty when it would pass the size limit and so
## never load back.
static func _encode(data: Dictionary) -> PackedByteArray:
	var bytes: PackedByteArray = JSON.stringify(data, "\t", false).to_utf8_buffer()
	if bytes.size() > MAX_BYTES:
		return PackedByteArray()
	return bytes


## Writes on the calling thread (the queue is empty: the caller flushed).
func _write_now(file_name: String, bytes: PackedByteArray) -> bool:
	var ok: bool = _write_file(_directory, file_name, bytes)
	_q.mutex.lock()
	if ok:
		_q.written[file_name] = bytes
	else:
		_q.written.erase(file_name)
	_q.mutex.unlock()
	return ok


## Queues bytes for file_name, replacing older bytes still waiting, and
## starts the writer task when none is running.
func _queue(file_name: String, bytes: PackedByteArray) -> void:
	_q.mutex.lock()
	if not _q.pending.has(file_name) and _q.written.has(file_name) and _q.written[file_name] == bytes:
		_q.mutex.unlock()
		return
	_q.pending[file_name] = bytes
	var start: bool = not _q.writing
	if start:
		_q.writing = true
	_q.mutex.unlock()
	if start:
		_reap()
		_task_id = WorkerThreadPool.add_task(_drain.bind(_q), false, "SaveService writes")


## The writer: takes one queued file at a time and writes it, until the
## queue is empty. Runs on a worker thread, or on the caller during flush.
## Static, and holding only the queue, so it never needs the service.
static func _drain(queue: WriteQueue) -> void:
	while true:
		queue.mutex.lock()
		if queue.pending.is_empty():
			queue.writing = false
			queue.mutex.unlock()
			return
		var file_name: String = queue.pending.keys()[0]
		var bytes: PackedByteArray = queue.pending[file_name]
		queue.pending.erase(file_name)
		queue.written[file_name] = bytes
		queue.mutex.unlock()
		if not _write_file(queue.directory, file_name, bytes):
			queue.mutex.lock()
			if queue.written.has(file_name) and queue.written[file_name] == bytes:
				queue.written.erase(file_name)
			queue.mutex.unlock()
			push_warning("SaveService: could not save %s; the last good save stays" % file_name)


## Waits for the writer task started last, which drains the whole queue.
func _reap() -> void:
	if _task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1


func _notification(what: int) -> void:
	# A service dropped with writes queued waits for its writer here, so
	# nothing queued is lost and the task is cleaned up. Inline, because
	# methods cannot be called on an object being deleted.
	if what == NOTIFICATION_PREDELETE and _task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1


## Writes bytes to <file_name>.tmp in directory, checks it, then renames it
## over the real file. A failed write or check deletes the broken temp file.
## A failed rename keeps it, because on Windows the real file may already be
## gone and the temp file is then the newest good copy. Safe on any thread.
static func _write_file(directory: String, file_name: String, bytes: PackedByteArray) -> bool:
	if directory.is_empty() or bytes.is_empty():
		return false
	if not DirAccess.dir_exists_absolute(directory):
		if DirAccess.make_dir_recursive_absolute(directory) != OK:
			return false
	var main_path: String = directory.path_join(file_name)
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
static func _file_holds(path: String, bytes: PackedByteArray) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var same: bool = file.get_length() == bytes.size() and file.get_buffer(bytes.size()) == bytes
	file.close()
	return same


## Finishes a rename that a kill interrupted. If it fails, the temp file stays
## and the next load finds it again.
static func _promote(temp_path: String, main_path: String) -> void:
	DirAccess.rename_absolute(temp_path, main_path)


static func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
