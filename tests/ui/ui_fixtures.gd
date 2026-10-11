extends RefCounted
## Helpers for the ui tests. Each test gets a fresh temp save folder inside
## user:// (never the real save files) and a real App in the scene tree.
##
## Headless tests run before the first frame, so no tween or board animation
## ever finishes. Tests stand in for the board by calling
## session.move_shown(), the call the board makes when a move has been shown.

const SaveFixtures: GDScript = preload("res://tests/save/save_fixtures.gd")
const APP_SCENE: PackedScene = preload("res://scenes/ui/app.tscn")

const NO_CELL: Vector2i = Vector2i(-1, -1)


static func make_temp_dir() -> String:
	return SaveFixtures.make_temp_dir()


static func remove_temp_dir(path: String) -> void:
	SaveFixtures.remove_temp_dir(path)


static func root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


## A started App saving into folder, with quits recorded in quits instead of
## ending the test run. Headless tests run before the scene tree starts, so
## the App is started by hand rather than by _ready.
static func start_app(folder: String, quits: Array[int]) -> App:
	var app: App = APP_SCENE.instantiate() as App
	app.save_folder = folder
	app.quit_handler = func() -> void: quits.append(1)
	app.start()
	return app


## Frees the App. Its queued saves are flushed first, as on a real exit.
static func stop_app(app: App) -> void:
	if app == null or not is_instance_valid(app):
		return
	settle(app)
	if app.get_parent() != null:
		app.get_parent().remove_child(app)
	app.free()


## Writes a saved run and a profile into folder, as a previous session would.
static func save_game(folder: String, state: RunState, best_score: int = 0, best_tile: int = 0, settings: Settings = null) -> void:
	var service: SaveService = SaveService.new(folder)
	if state != null:
		service.save_run(state)
	var records: Records = Records.new()
	records.best_score = best_score
	records.best_tile = best_tile
	service.save_profile(settings if settings != null else Settings.new(), records)


static func board_d() -> PackedInt64Array:
	return SaveFixtures.board_d()


static func with_cell(board: PackedInt64Array, cell: Vector2i, value: int) -> PackedInt64Array:
	return SaveFixtures.with_cell(board, cell, value)


## Board D1024 (GDD 19.0): no valid move, H = 1024.
static func board_d1024() -> PackedInt64Array:
	return with_cell(board_d(), Vector2i(2, 0), 1024)


## Board P (GDD 19.0), H = 32.
static func board_p() -> PackedInt64Array:
	var rows: Array[PackedInt64Array] = [
		PackedInt64Array([2, 4, 2, 4, 2]),
		PackedInt64Array([8, 16, 8, 16, 8]),
		PackedInt64Array([2, 4, 2, 4, 2]),
		PackedInt64Array([8, 16, 8, 16, 8]),
		PackedInt64Array([2, 4, 2, 4, 2]),
		PackedInt64Array([8, 4, 8, 16, 8]),
		PackedInt64Array([2, 2, 2, 4, 2]),
		PackedInt64Array([8, 8, 32, 8, 8]),
	]
	var cells: PackedInt64Array = PackedInt64Array()
	for row: PackedInt64Array in rows:
		cells.append_array(row)
	return cells


## A snapshot board with a valid move, for states that need Undo.
static func snapshot_board() -> PackedInt64Array:
	return with_cell(board_d(), Vector2i(1, 7), 8)


## Waits for the App's queued saves, before a test reads the files through
## another SaveService or writes to them itself.
static func settle(app: App) -> void:
	if app != null and is_instance_valid(app) and app.save != null:
		app.save.flush()


## Lets the session finish showing the last move, as the board would.
static func shown(app: App) -> void:
	app.session.move_shown()
