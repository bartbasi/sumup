extends "res://tests/base_test.gd"
## The App's flow for the 2026-10-13 additions (docs/ARCHITECTURE.md section
## 11, flow 4 and 10 to 12), with a real App and a temp save folder: How to
## play (AT-112 to AT-114), About and its license texts (AT-140), the back
## button order, the free offer (AT-135), New best after a restart (AT-145),
## the show gate (AT-146) and the clear notice rules (GDD 11.5).

const U := preload("res://tests/ui/ui_fixtures.gd")
const Copy := preload("res://src/ui/screen_copy.gd")

var _dir: String = ""
var _app: App = null
var _quits: Array[int] = []


func before_each() -> void:
	_dir = U.make_temp_dir()
	_quits = []
	_app = null
	Motion.bind_tweens = false


func after_each() -> void:
	if _app != null and is_instance_valid(_app) and _app.save != null:
		_app.save.set_hold(false)
	U.stop_app(_app)
	U.remove_temp_dir(_dir)
	Motion.bind_tweens = true


func _start() -> App:
	_app = U.start_app(_dir, _quits)
	return _app


func _restart() -> App:
	U.stop_app(_app)
	return _start()


func _back(app: App) -> void:
	app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)


func _how_to_play_open(app: App) -> bool:
	for panel: Control in app.open_panels():
		if panel is HowToPlayPanel:
			return true
	return false


# How to play (D-44)

func test_at_112_how_to_play_opens_from_the_main_menu() -> void:
	U.save_game(_dir, null, 96520, 8192)
	var app: App = _start()
	app.main_menu().how_to_play_chosen.emit()
	var panel: HowToPlayPanel = app.top_panel() as HowToPlayPanel
	assert_not_null(panel, "How to play opens")
	assert_eq(panel.title_text(), "How to play", "titled")
	assert_eq(panel.content().size(), 7, "HP1 to HP7")
	_back(app)
	assert_true(app.open_panels().is_empty(), "back closes it")
	assert_not_null(app.main_menu(), "back on the main menu")
	assert_true(_quits.is_empty(), "back closed the screen, it did not quit")
	app.main_menu().how_to_play_chosen.emit()
	(app.top_panel() as HowToPlayPanel).close_button().pressed.emit()
	assert_true(app.open_panels().is_empty(), "its close control returns to the menu too")
	assert_eq(app.records.best_score, 96520, "Best Score unchanged")
	assert_eq(app.records.best_tile, 8192, "Best Tile unchanged")
	assert_eq(app.main_menu().best_score_text(), "96,520", "and shown as before")


func test_at_113_how_to_play_from_pause_leaves_the_run_untouched() -> void:
	U.save_game(_dir, RunState.create(U.board_p(), 5000))
	var app: App = _start()
	U.shown(app)
	var chain: Array[Vector2i] = [Vector2i(1, 6), Vector2i(2, 6)]
	assert_true(app.session.commit_chain(chain).accepted, "a chain")
	U.shown(app)
	var before: RunState = app.session.state.copy()
	var stars: int = app.session.stars()
	var free: int = app.session.free_held()
	var undo: BoosterStatus = app.session.booster_statuses()[4]
	assert_true(undo.usable, "Undo enabled")
	app.open_pause()
	(app.top_panel() as PausePanel).how_to_play_chosen.emit()
	assert_true(app.top_panel() is HowToPlayPanel, "How to play opens")
	assert_eq(app.open_panels().size(), 2, "over Pause, which stays open")
	_back(app)
	assert_true(app.top_panel() is PausePanel, "back returns to Pause, not to the board")
	(app.top_panel() as PausePanel).resume_chosen.emit()
	assert_true(app.open_panels().is_empty(), "Resume")
	assert_true(app.session.state.equals(before), "the board and score exactly as noted")
	assert_eq(app.session.stars(), stars, "the stars")
	assert_eq(app.session.free_held(), free, "the free boosters held")
	var undo_after: BoosterStatus = app.session.booster_statuses()[4]
	assert_eq(undo_after.cost, undo.cost, "the Undo cost")
	assert_true(undo_after.usable, "Undo still enabled")


func test_at_114_how_to_play_never_opens_by_itself() -> void:
	var app: App = _start()
	assert_false(_how_to_play_open(app), "not at first launch")
	app.main_menu().new_game_chosen.emit()
	U.shown(app)
	assert_false(_how_to_play_open(app), "not when a run starts")
	U.settle(app)
	U.save_game(_dir, RunState.create(U.board_d1024(), 300))
	var ended: App = _restart()
	U.shown(ended)
	assert_true(ended.top_panel() is EndPanel, "the run ends")
	assert_false(_how_to_play_open(ended), "not when a run ends")
	(ended.top_panel() as EndPanel).new_game_chosen.emit()
	U.shown(ended)
	assert_false(_how_to_play_open(ended), "not on the next run")
	var reopened: App = _restart()
	U.shown(reopened)
	assert_false(_how_to_play_open(reopened), "not after reopening")


func test_how_to_play_opens_only_once() -> void:
	var app: App = _start()
	app.main_menu().how_to_play_chosen.emit()
	app.open_how_to_play()
	assert_eq(app.open_panels().size(), 1, "a second open while it shows does nothing")


# About (AT-140) and the back order (flow 10)

func test_at_140_about_opens_from_settings_and_back_closes_it() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var settings: Settings = Settings.new()
		settings.set_skin_id(skin_id)
		U.save_game(_dir, null, 0, 0, settings)
		var app: App = _restart() if _app != null else _start()
		app.main_menu().settings_chosen.emit()
		(app.top_panel() as SettingsPanel).about_row().emit_signal(&"tapped")
		assert_true(app.top_panel() is AboutPanel, "%s: About opens from Settings" % skin_id)
		_back(app)
		assert_true(app.top_panel() is SettingsPanel, "%s: back returns to Settings, still open" % skin_id)
		(app.top_panel() as SettingsPanel).about_chosen.emit()
		(app.top_panel() as AboutPanel).close_button().pressed.emit()
		assert_true(app.top_panel() is SettingsPanel, "%s: the close control returns to Settings" % skin_id)
		_back(app)
		assert_true(app.open_panels().is_empty(), "%s: a second back closes Settings" % skin_id)
		assert_true(_quits.is_empty(), "%s: no exit" % skin_id)


func test_back_order_from_a_license_text_down_to_the_board() -> void:
	U.save_game(_dir, RunState.create(U.board_p(), 5000))
	var app: App = _start()
	U.shown(app)
	app.open_pause()
	(app.top_panel() as PausePanel).settings_chosen.emit()
	(app.top_panel() as SettingsPanel).about_chosen.emit()
	var about: AboutPanel = app.top_panel() as AboutPanel
	about.license_rows()[&"godot"].emit_signal(&"tapped")
	assert_not_null(about.license_view(), "a license text inside About")
	_back(app)
	assert_null(about.license_view(), "back closes the license text first")
	assert_true(app.top_panel() == about, "About stays")
	_back(app)
	assert_true(app.top_panel() is SettingsPanel, "then About")
	_back(app)
	assert_true(app.top_panel() is PausePanel, "then Settings")
	_back(app)
	assert_true(app.open_panels().is_empty(), "then Pause, which resumes")
	_back(app)
	assert_true(app.top_panel() is PausePanel, "back on the board opens Pause")
	(app.top_panel() as PausePanel).how_to_play_chosen.emit()
	_back(app)
	assert_true(app.top_panel() is PausePanel, "back closes How to play before Pause")
	assert_true(_quits.is_empty(), "never an exit on the board")


func test_back_cancels_targeting_before_any_panel() -> void:
	U.save_game(_dir, RunState.create(U.board_p(), 5000))
	var app: App = _start()
	U.shown(app)
	app.session.press_booster(&"hammer")
	_back(app)
	assert_eq(app.session.targeting_booster(), &"", "targeting ends")
	assert_true(app.open_panels().is_empty(), "no panel opened")


func test_skin_switch_rebuilds_open_reading_screens() -> void:
	var app: App = _start()
	app.main_menu().settings_chosen.emit()
	(app.top_panel() as SettingsPanel).about_chosen.emit()
	var about: AboutPanel = app.top_panel() as AboutPanel
	about.open_license(&"outfit")
	app.settings.set_skin_id(&"slate")
	assert_eq(about.title_text(), SkinCatalog.get_skin(&"slate").cased(&"title", "About"), "About rebuilt in the new skin")
	assert_not_null(about.license_view(), "with its license text still open")
	assert_eq(about.license_view().call(&"license_id"), &"outfit", "the same text")


# The offer with a free booster (AT-135, DESIGN_SYSTEM.md 7.5)

func test_at_135_a_the_offer_reads_shuffle_for_free() -> void:
	U.save_game(_dir, RunState.create(U.board_d1024(), 0, PackedInt64Array(), 0, 8192))
	var app: App = _start()
	U.shown(app)
	assert_true(app.session.is_offer_open(), "the offer opens instead of ending the run")
	assert_eq(app.session.free_held(), 1, "1 free booster held")
	var offer: OfferPanel = app.game_screen().offer_panel()
	assert_eq(offer.buy_button().text, "Shuffle for free", "the buy button")
	offer.buy_button().pressed.emit()
	assert_eq(app.session.state.score, 0, "free: the score stays 0")
	assert_eq(app.session.free_held(), 0, "the free booster is used")


# New best after a restart (AT-145, the UI half)

func _at_145_end(best_at_start: int, format_1: bool) -> bool:
	U.save_game(_dir, null, 5000, 1024)
	var state: RunState = RunState.create(U.board_d1024(), 5000, PackedInt64Array(), 0, 0, 5, 0, best_at_start)
	if format_1:
		U.SaveFixtures.write_text(_dir.path_join("run.json"), U.SaveFixtures.to_text(U.SaveFixtures.format_1_data(state)))
	else:
		SaveService.new(_dir).save_run(state)
	var app: App = _restart() if _app != null else _start()
	U.shown(app)
	assert_true(app.session.is_offer_open(), "the offer opens (Board D1024 has no valid move)")
	app.game_screen().offer_panel().end_run_button().pressed.emit()
	var panel: EndPanel = app.top_panel() as EndPanel
	assert_not_null(panel, "the end of run screen")
	return panel != null and panel.shows_new_best()


func test_at_145_new_best_survives_a_restart() -> void:
	assert_true(_at_145_end(4000, false), "(a) began at 4,000: New best")
	assert_false(_at_145_end(5000, false), "(b) began at 5,000: it only equalled the record")
	assert_false(_at_145_end(4000, true), "(c) a file from before the rule: the old behaviour, no badge")


# The show gate (AT-146, the App half)

func test_at_146_a_held_save_keeps_the_hud_and_the_board_as_at_the_lift() -> void:
	U.save_game(_dir, RunState.create(U.board_p(), 5000))
	var app: App = _start()
	U.shown(app)
	var game: GameScreen = app.game_screen()
	var statuses: Array[BoosterStatus] = game.shown_statuses()
	assert_eq(game.shown_score(), 5000, "the score before the move")
	app.save.set_hold(true)
	var chain: Array[Vector2i] = [Vector2i(1, 6), Vector2i(2, 6)]
	assert_true(app.session.commit_chain(chain).accepted, "the chain commits in the rules model")
	assert_eq(app.session.state.score, 5004, "with its points")
	game.board()._check_gate()
	assert_true(game.board().is_waiting_for_save(), "the save is held, so the board has not started the move")
	assert_eq(game.shown_score(), 5000, "the HUD score is as at the lift")
	assert_eq(game.hud().score_label().text, "5,000", "on screen")
	assert_true(game.shown_statuses() == statuses, "the booster bar is as at the lift")
	app.save.set_hold(false)
	U.gate(app)
	assert_false(game.board().is_waiting_for_save(), "once the save lands the move starts")
	assert_eq(game.shown_score(), 5004, "and the HUD shows its score")
	assert_false(game.shown_statuses() == statuses, "and the bar its statuses")


func test_the_app_gates_every_board_it_shows() -> void:
	var app: App = _start()
	app.main_menu().new_game_chosen.emit()
	assert_true(app.game_screen().board().is_waiting_for_save(), "the new run's board waits for its save")
	U.gate(app)
	assert_false(app.game_screen().board().is_waiting_for_save(), "and shows once it landed")


# The clear notice (GDD 11.5, D-45, AT-104, AT-123, QA6-04)

func test_notice_rules() -> void:
	var star_only: MoveResult = MoveResult.new()
	star_only.stars_earned = 1
	assert_true(GameScreen.wants_notice(star_only), "a star with nothing cleared shows the notice (SC7)")
	var clear_only: MoveResult = MoveResult.new()
	clear_only.cleared_small = [Vector2i(0, 0)] as Array[Vector2i]
	assert_true(GameScreen.wants_notice(clear_only), "a clear with no star shows the notice (CL4)")
	var neither: MoveResult = MoveResult.new()
	neither.notice_values = PackedInt64Array([2])
	assert_false(GameScreen.wants_notice(neither), "a floor rise with no clear and no star shows none")
	assert_false(GameScreen.wants_notice(null), "no move, no notice")


func _board_e() -> PackedInt64Array:
	var cells: PackedInt64Array = PackedInt64Array()
	for row: int in 8:
		for column: int in 5:
			if row % 2 == 0:
				cells.append(4 if column % 2 == 0 else 16)
			else:
				cells.append(8 if column % 2 == 0 else 32)
	return cells


func test_at_123_a_star_with_nothing_cleared_shows_the_notice() -> void:
	var board: PackedInt64Array = U.with_cell(U.with_cell(_board_e(), Vector2i(4, 6), 1024), Vector2i(4, 7), 1024)
	U.save_game(_dir, RunState.create(board, 10000))
	var app: App = _start()
	U.shown(app)
	var result: MoveResult = app.session.commit_chain([Vector2i(4, 6), Vector2i(4, 7)] as Array[Vector2i])
	assert_eq(result.stars_earned, 1, "one star")
	assert_true(result.cleared_small.is_empty(), "nothing cleared")
	assert_eq(result.notice_values, PackedInt64Array([2]), "the 2s left the window")
	var hud: SkinHud = app.game_screen().hud()
	assert_null(hud.call(&"clear_notice"), "the notice waits with the move at the gate")
	assert_eq(hud.call(&"shown_stars"), Vector2i(0, 0), "and so does the counter")
	U.gate(app)
	var notice: Control = hud.call(&"clear_notice")
	assert_not_null(notice, "then the notice shows")
	assert_eq(notice.get_parent(), app.game_screen().notice_layer(), "on the play screen's notice layer")
	assert_eq(app.session.stars(), 1, "1 star")
	assert_true(hud.call(&"star_moment") != null, "with the star earned effect")
	hud.call(&"seek_star_moment", 10.0)
	assert_eq(hud.call(&"shown_stars"), Vector2i(1, 0), "the counter lands on 1")


func test_at_125_a_loaded_run_shows_its_stars_and_no_notice() -> void:
	var state: RunState = RunState.create(U.with_cell(U.board_p(), Vector2i(0, 0), 131072), 2400000, PackedInt64Array(), 0, 0, 5, 1)
	U.save_game(_dir, state, 2400000, 131072)
	var app: App = _start()
	U.shown(app)
	var hud: SkinHud = app.game_screen().hud()
	assert_eq(hud.call(&"shown_stars"), Vector2i(7, 1), "7 stars and 1 free booster held, at once")
	assert_null(hud.call(&"clear_notice"), "loading shows no notice")
	assert_null(hud.call(&"star_moment"), "and earns no star")


func test_stars_follow_a_skin_switch_and_a_new_run() -> void:
	var state: RunState = RunState.create(U.with_cell(U.board_p(), Vector2i(0, 0), 8192), 9000)
	U.save_game(_dir, state, 9000, 8192)
	var app: App = _start()
	U.shown(app)
	assert_eq(app.game_screen().hud().call(&"shown_stars"), Vector2i(3, 1), "3 stars, 1 free booster")
	app.settings.set_skin_id(&"nova")
	var hud: SkinHud = app.game_screen().hud()
	assert_true((hud.get_script() as Script).resource_path.contains("nova"), "a new HUD")
	assert_eq(hud.call(&"shown_stars"), Vector2i(3, 1), "with the same counter")
	assert_true(hud.call(&"clear_notice") == null, "no notice from the switch")
	app.open_pause()
	(app.top_panel() as PausePanel).new_game_chosen.emit()
	(app.top_panel() as ConfirmDialog).confirmed.emit()
	U.gate(app)
	assert_eq(app.game_screen().hud().call(&"shown_stars"), Vector2i(0, 0), "a new run starts at 0")


func test_the_end_of_run_screen_has_no_stars_row() -> void:
	var state: RunState = RunState.create(U.board_d1024(), 300, PackedInt64Array(), 0, 8192, 5, 1)
	U.save_game(_dir, state, 300, 8192)
	var app: App = _start()
	U.shown(app)
	var panel: EndPanel = app.top_panel() as EndPanel
	assert_not_null(panel, "the run ends (no valid move, nothing usable)")
	for label: Node in panel.find_children("*", "Label", true, false):
		assert_false((label as Label).text.to_lower().contains("star"), "no stars row (DESIGN_SYSTEM.md 7.6)")


func test_qa6_04_a_clear_from_the_offer_still_shows_the_notice() -> void:
	# AT-101: Double on the 1024 from the offer makes 2048, clears the 2 and
	# earns a star while the offer has the HUD's place.
	var board: PackedInt64Array = U.with_cell(U.with_cell(_board_e(), Vector2i(0, 3), 2), Vector2i(2, 0), 1024)
	U.save_game(_dir, RunState.create(board, 5000))
	var app: App = _start()
	U.shown(app)
	assert_true(app.session.is_offer_open(), "the offer is open")
	app.session.press_booster(&"double")
	var result: MoveResult = app.session.tap_cell(Vector2i(2, 0))
	assert_true(result != null and result.accepted, "the Double applies")
	assert_eq(result.stars_earned, 1, "a star")
	assert_false(app.game_screen().hud().visible, "the offer has the HUD's place")
	U.gate(app)
	var notice: Control = app.game_screen().hud().call(&"clear_notice")
	assert_not_null(notice, "the notice is shown, offer or not")
	var layer: Control = app.game_screen().notice_layer()
	assert_eq(notice.get_parent(), layer, "on the notice layer, not inside the hidden HUD")
	var game: GameScreen = app.game_screen()
	assert_true(layer.get_index() > game.offer_panel().get_index(), "above the offer panel")
	assert_true(layer.get_index() > game.board().get_index(), "and the board")
