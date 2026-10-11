extends Control
## Review page for the production screens, 1080 by 2400, for the
## senior-graphic-designer. Each scene in scenes/ui/review/ sets the skin and
## the page:
##   menu        the main menu with records
##   play        the play screen mid game
##   pause       Pause over the play screen
##   settings    Settings over the play screen
##   offer       the out of moves offer, Shuffle suggested
##   offer_none  the offer with nothing suggested (costs overridden as in
##               GDD AT-109 (d): with the GDD 18 costs this state never
##               shows, because whenever Shuffle and Undo are unusable
##               nothing else is either and the run ends)
##   end         the end of run panel with the New best badge
##   end_no_moves  the end of run panel after a run that ended at once with
##               nothing usable, so it says "No moves left."
##   confirm     the New game confirmation over Pause
##   first_launch  the real App on first launch with an empty save folder and
##               no simulated insets; prints where the brand block sits
## Capture with tools/capture.tscn, for example:
##   godot --path . res://tools/capture.tscn -- --scene res://scenes/ui/review/review_gumdrop_menu.tscn --out docs/design/review/prod-screens-gumdrop-menu.png
##
## Everything here is the real screen and panel code fed a crafted session;
## nothing is saved. Panels show at rest (no dialog_in), so a capture after a
## few frames shows their final look. The safe area is simulated as the
## capture tool's default phone: 120 px on top, 66 px at the bottom.

const GAME_SCENE: PackedScene = preload("res://scenes/ui/game_screen.tscn")
const MENU_SCENE: PackedScene = preload("res://scenes/ui/main_menu.tscn")
const PAUSE_SCENE: PackedScene = preload("res://scenes/ui/pause_panel.tscn")
const SETTINGS_SCENE: PackedScene = preload("res://scenes/ui/settings_panel.tscn")
const CONFIRM_SCENE: PackedScene = preload("res://scenes/ui/confirm_dialog.tscn")
const END_SCENE: PackedScene = preload("res://scenes/ui/end_panel.tscn")
const Copy: GDScript = preload("res://src/ui/screen_copy.gd")

const APP_SCENE: PackedScene = preload("res://scenes/ui/app.tscn")
## Where the first launch page keeps its throwaway save folder.
const FIRST_LAUNCH_ROOT: String = "user://review_first_launch"
## Frames to wait for the containers to settle before measuring.
const REPORT_AFTER_FRAMES: int = 4

## The capture tool's default simulated safe area (tools/capture.gd).
const SAFE_INSETS: Vector2 = Vector2(120.0, 66.0)

## The Phase 1 mock moments (tools/directions/shared/mock_state.gd).
const MID_GAME: Array[int] = [
	2, 16, 4, 2, 8,
	4, 1024, 64, 8, 2,
	16, 128, 2, 32, 4,
	2, 4, 512, 16, 64,
	32, 8, 8, 2, 16,
	4, 2048, 16, 4, 2,
	8, 2, 32, 256, 8,
	64, 4, 2, 8, 4,
]
const NO_MOVES: Array[int] = [
	4, 32, 2, 16, 8,
	16, 8, 64, 4, 2,
	2, 128, 2, 512, 32,
	64, 16, 32, 8, 4,
	8, 4096, 2, 128, 16,
	2, 64, 16, 4, 256,
	32, 4, 1024, 64, 8,
	8, 16, 2, 32, 2,
]
const SCORE: int = 41286
const FINAL_SCORE: int = 76410
const BEST_SCORE: int = 96520
const BEST_TILE: int = 8192
## The Best Score before the run on the end page, below its final score.
const END_OLD_BEST: int = 70000
## A score below every cost on the no moves board (4096 is its highest tile).
const NO_MOVES_SCORE: int = 1200

@export var skin_id: StringName = &"gumdrop"
## menu, play, pause, settings, offer, offer_none, end or confirm.
@export var page: String = "menu"

var _skin: SkinData = null
var _app: App = null
var _folder: String = ""
var _frames: int = 0
var _best_score: int = BEST_SCORE
var _session: GameSession = null
var _audio: AudioService = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if page == "first_launch":
		_first_launch()
		return
	SafeArea.simulated_insets = SAFE_INSETS
	_skin = SkinCatalog.get_skin(skin_id)
	theme = UiKit.build_theme(_skin)
	_audio = AudioService.new()
	add_child(_audio)
	match page:
		"menu":
			var menu: MainMenu = MENU_SCENE.instantiate() as MainMenu
			add_child(menu)
			menu.setup(_skin, _records())
		"play":
			_game(_board(MID_GAME), SCORE, null)
		"pause":
			_game(_board(MID_GAME), SCORE, null)
			(_panel(PAUSE_SCENE) as PausePanel).setup(_skin)
		"settings":
			_game(_board(MID_GAME), SCORE, null)
			var settings: Settings = Settings.new()
			settings.set_skin_id(_skin.id)
			(_panel(SETTINGS_SCENE) as SettingsPanel).setup(_skin, settings)
		"offer":
			_game(_board(NO_MOVES), FINAL_SCORE, null)
		"offer_none":
			var config: GameConfig = GameConfig.new()
			config.cost_shift[&"shuffle"] = 2
			config.cost_shift[&"undo"] = 2
			_game(_board(NO_MOVES), 5000, config)
		"end":
			# A run that beat the old Best Score, so the New best badge shows,
			# ended from the offer with End run.
			_best_score = END_OLD_BEST
			_game(_board(NO_MOVES), FINAL_SCORE, null)
			_session.run_ended.connect(_show_end)
			_session.end_run()
		"end_no_moves":
			# No valid move and nothing affordable: the run ends at once, and
			# the panel says no moves were left (GDD 12.2 step 3, QA4-01).
			_best_score = END_OLD_BEST
			var rng: RunRandom = RunRandom.new()
			rng.set_seed(1)
			_session = GameSession.new(null, rng, _records())
			var game: GameScreen = GAME_SCENE.instantiate() as GameScreen
			add_child(game)
			game.setup(_session, Settings.new(), _audio, _skin)
			_session.run_ended.connect(_show_end)
			_session.resume(RunState.create(_board(NO_MOVES), NO_MOVES_SCORE))
			if _session.is_waiting_for_view():
				_session.move_shown()
		"confirm":
			_game(_board(MID_GAME), SCORE, null)
			(_panel(PAUSE_SCENE) as PausePanel).setup(_skin)
			(_panel(CONFIRM_SCENE) as ConfirmDialog).setup(_skin, Copy.CONFIRM_TITLE, Copy.CONFIRM_BODY, Copy.NEW_GAME, Copy.CANCEL)
		_:
			push_error("ui_review: unknown page '%s'" % page)


func _exit_tree() -> void:
	SafeArea.simulated_insets = Vector2(-1.0, -1.0)
	if not _folder.is_empty():
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)
		DirAccess.remove_absolute(FIRST_LAUNCH_ROOT)


## The real App on first launch: an empty save folder (only the chosen skin
## in the profile, for Slate and Nova), no simulated insets, like a capture
## of scenes/main.tscn. Prints where the brand block's center sits.
func _first_launch() -> void:
	_folder = FIRST_LAUNCH_ROOT.path_join(String(skin_id))
	DirAccess.make_dir_recursive_absolute(_folder)
	for file_name: String in DirAccess.get_files_at(_folder):
		DirAccess.remove_absolute(_folder.path_join(file_name))
	if skin_id != SkinCatalog.DEFAULT_ID:
		var settings: Settings = Settings.new()
		settings.set_skin_id(skin_id)
		SaveService.new(_folder).save_profile(settings, Records.new())
	_app = APP_SCENE.instantiate() as App
	_app.save_folder = _folder
	add_child(_app)
	get_tree().process_frame.connect(_report_brand)


func _report_brand() -> void:
	_frames += 1
	if _frames < REPORT_AFTER_FRAMES or _app.main_menu() == null:
		return
	get_tree().process_frame.disconnect(_report_brand)
	var brand: Rect2 = _app.main_menu().brand_rect()
	var height: float = get_viewport_rect().size.y
	print("ui_review: %s first launch, brand block %.0f to %.0f px, center %.1f%% of the screen height" % [skin_id, brand.position.y, brand.end.y, brand.get_center().y / height * 100.0])


func _records() -> Records:
	var records: Records = Records.new()
	records.best_score = _best_score
	records.best_tile = BEST_TILE
	return records


func _show_end(summary: RunSummary) -> void:
	var end: EndPanel = _panel(END_SCENE) as EndPanel
	end.setup(_skin)
	end.show_summary(summary)


func _board(values: Array[int]) -> PackedInt64Array:
	var cells: PackedInt64Array = PackedInt64Array()
	for value: int in values:
		cells.append(value)
	return cells


## The play screen showing a resumed run: the board appears at once and the
## move check opens the offer when there is no valid move.
func _game(cells: PackedInt64Array, score: int, config: GameConfig) -> void:
	var rng: RunRandom = RunRandom.new()
	rng.set_seed(1)
	_session = GameSession.new(config, rng, _records())
	var game: GameScreen = GAME_SCENE.instantiate() as GameScreen
	add_child(game)
	game.setup(_session, Settings.new(), _audio, _skin)
	_session.resume(RunState.create(cells, score))
	if _session.is_waiting_for_view():
		_session.move_shown()


func _panel(scene: PackedScene) -> Control:
	var panel: Control = scene.instantiate() as Control
	add_child(panel)
	return panel
