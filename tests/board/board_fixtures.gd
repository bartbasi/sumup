extends RefCounted
## Helpers for the board tests: a rig of a real GameSession, a real
## AudioService and a BoardController on the recording stub view, plus
## synthetic input events. Boards come from the core fixtures (GDD 19.0),
## read only.
## Not a test file: the runner only loads files named test_*.gd.

const F := preload("res://tests/core/core_fixtures.gd")
const StubBoardController: GDScript = preload("res://tests/board/stub_board_controller.gd")
const StubBoardView: GDScript = preload("res://tests/board/stub_board_view.gd")
const NO_CELL: Vector2i = Vector2i(-1, -1)
const NO_DRAG: Vector2 = Vector2(-1.0, -1.0)
## The device id a real touch screen or mouse reports in these tests.
const REAL_DEVICE: int = 0
## Below the last row of the stub board, clear of every hit circle.
const BELOW_BOARD_Y: float = 1000.0


## A session, its board and its audio, wired as the game screen wires them.
class Rig extends RefCounted:
	var skin: SkinData
	var session: GameSession
	var audio: AudioService
	var board: StubBoardController
	## Every chain_changed: [chain, preview].
	var chain_events: Array = []
	var finished: int = 0

	func view() -> StubBoardView:
		return board.stub()

	## The center of a cell on the stub view, plus offset, in board pixels.
	func point(cell: Vector2i, offset: Vector2 = Vector2.ZERO) -> Vector2:
		return BoardGeometry.cell_center(cell, StubBoardView.ORIGIN, StubBoardView.PITCH) + offset

	func send(event: InputEvent) -> void:
		board._gui_input(event)

	func down(cell: Vector2i, index: int = 0) -> void:
		send(Events.touch(index, point(cell), true))

	func down_at(at: Vector2, index: int = 0) -> void:
		send(Events.touch(index, at, true))

	func move(cell: Vector2i, index: int = 0) -> void:
		send(Events.drag(index, point(cell)))

	func move_to(at: Vector2, index: int = 0) -> void:
		send(Events.drag(index, at))

	func up(cell: Vector2i, index: int = 0) -> void:
		send(Events.touch(index, point(cell), false))

	func up_at(at: Vector2, index: int = 0) -> void:
		send(Events.touch(index, at, false))

	## Finger down on the first cell, then moves onto each next one.
	func drag_cells(path: Array, index: int = 0) -> void:
		down(path[0], index)
		for i: int in range(1, path.size()):
			move(path[i], index)

	## drag_cells, then lift on the last cell.
	func play(path: Array, index: int = 0) -> void:
		drag_cells(path, index)
		up(path[path.size() - 1], index)

	## A tap on one cell: down and up.
	func tap(cell: Vector2i, index: int = 0) -> void:
		down(cell, index)
		up(cell, index)

	## Moves the board's clock on, as frames would.
	func advance(seconds: float) -> void:
		board._process(seconds)

	## Runs frames of frame seconds until the move has finished, at most
	## max_frames of them. Returns the time it took.
	func settle(frame: float = 1.0 / 60.0, max_frames: int = 600) -> float:
		var elapsed: float = 0.0
		var frames: int = 0
		while board.is_animating() and frames < max_frames:
			board._process(frame)
			elapsed += frame
			frames += 1
		return elapsed

	func clicks() -> int:
		return audio.click_requests

	func last_chain() -> Array:
		return chain_events.back()[0] if not chain_events.is_empty() else []

	func last_preview() -> int:
		return chain_events.back()[1] if not chain_events.is_empty() else -1

	func forget() -> void:
		view().clear_log()
		chain_events.clear()
		finished = 0

	func free_all() -> void:
		if is_instance_valid(board):
			board.free()
		if is_instance_valid(audio):
			audio.free()

	func _on_chain_changed(chain: Array[Vector2i], preview: int) -> void:
		chain_events.append([chain.duplicate(), preview])

	func _on_finished() -> void:
		finished += 1


## A rig over board and score, resumed and shown, with the generator seeded
## so spawns repeat, and every log cleared. durations are the stub's effect
## lengths (0 when missing).
static func rig(board_cells: PackedInt64Array, score: int, durations: Dictionary[StringName, float] = {}, seed_value: int = 1) -> Rig:
	var made: Rig = Rig.new()
	made.skin = SkinCatalog.get_skin(SkinCatalog.DEFAULT_ID)
	made.session = GameSession.new(GameConfig.new(), RunRandom.new(), Records.new())
	made.audio = AudioService.new()
	made.board = StubBoardController.new()
	made.board.durations = durations
	made.board.size = Vector2(540.0, 860.0)
	made.board.setup(made.session, made.skin, made.audio)
	made.board.chain_changed.connect(made._on_chain_changed)
	made.board.animation_finished.connect(made._on_finished)
	made.session.resume(RunState.create(board_cells, score))
	made.session.rng.set_seed(seed_value)
	made.forget()
	return made


## Synthetic input events.
class Events extends RefCounted:
	static func touch(index: int, at: Vector2, pressed: bool) -> InputEventScreenTouch:
		var event: InputEventScreenTouch = InputEventScreenTouch.new()
		event.device = REAL_DEVICE
		event.index = index
		event.position = at
		event.pressed = pressed
		return event

	static func drag(index: int, at: Vector2) -> InputEventScreenDrag:
		var event: InputEventScreenDrag = InputEventScreenDrag.new()
		event.device = REAL_DEVICE
		event.index = index
		event.position = at
		return event


static func touch(index: int, at: Vector2, pressed: bool) -> InputEventScreenTouch:
	return Events.touch(index, at, pressed)


static func drag(index: int, at: Vector2) -> InputEventScreenDrag:
	return Events.drag(index, at)


static func mouse_button(at: Vector2, pressed: bool, device: int = REAL_DEVICE, button: MouseButton = MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.device = device
	event.button_index = button
	event.position = at
	event.pressed = pressed
	return event


static func mouse_motion(at: Vector2, device: int = REAL_DEVICE) -> InputEventMouseMotion:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.device = device
	event.position = at
	return event


static func cells(list: Array) -> Array[Vector2i]:
	var typed: Array[Vector2i] = []
	typed.assign(list)
	return typed
