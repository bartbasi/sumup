extends "res://tests/base_test.gd"
## Screens and panels on their own (docs/ARCHITECTURE.md section 11,
## DESIGN_SYSTEM.md section 7), each in a host Control that carries the skin's
## Theme, as the App's root does.

const U := preload("res://tests/ui/ui_fixtures.gd")
const Copy := preload("res://src/ui/screen_copy.gd")
const UiParts := preload("res://src/ui/ui_parts.gd")

var _hosts: Array[Control] = []
var _events: Array[String] = []


func before_each() -> void:
	_hosts = []
	_events = []
	SafeArea.simulated_insets = Vector2(-1.0, -1.0)


func after_each() -> void:
	for host: Control in _hosts:
		if is_instance_valid(host):
			host.get_parent().remove_child(host)
			host.free()
	SafeArea.simulated_insets = Vector2(-1.0, -1.0)


func _host(skin_id: StringName) -> Control:
	var host: Control = Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.theme = UiKit.build_theme(SkinCatalog.get_skin(skin_id))
	U.root().add_child(host)
	_hosts.append(host)
	return host


func _record(event: String) -> void:
	_events.append(event)


func _record_id(booster_id: StringName) -> void:
	_events.append("buy " + String(booster_id))


## A session showing the offer for this state.
func _offer_session(state: RunState, config: GameConfig = null) -> GameSession:
	var session: GameSession = GameSession.new(config)
	session.resume(state)
	session.move_shown()
	return session


func _offer_panel(skin_id: StringName, session: GameSession) -> OfferPanel:
	var panel: OfferPanel = (load("res://scenes/ui/offer_panel.tscn") as PackedScene).instantiate() as OfferPanel
	_host(skin_id).add_child(panel)
	panel.setup(SkinCatalog.get_skin(skin_id))
	panel.show_offer(session.booster_statuses(), session.state.score)
	panel.booster_chosen.connect(_record_id)
	panel.end_run_chosen.connect(_record.bind("end run"))
	return panel


# OfferPanel, D-42 (AT-47, AT-49, AT-109)

func test_at_47_offer_marks_shuffle() -> void:
	var session: GameSession = _offer_session(RunState.create(U.board_d1024(), 5000, U.snapshot_board(), 40))
	assert_true(session.is_offer_open(), "the offer is open")
	var panel: OfferPanel = _offer_panel(&"gumdrop", session)
	assert_not_null(panel.buy_button(), "a buy button")
	assert_eq(panel.buy_button().text, "Shuffle for 1024", "for the suggested Shuffle, cost as a tile label")
	assert_eq(panel.buy_button().theme_type_variation, &"PrimaryButton", "primary")
	assert_eq(panel.end_run_button().theme_type_variation, &"SecondaryButton", "End run is secondary")
	assert_eq(panel.body_text(), Copy.OFFER_BODY, "the offer text")
	assert_eq(panel.score_text(), "5,000", "the current score")
	panel.buy_button().pressed.emit()
	panel.end_run_button().pressed.emit()
	assert_eq(_events, ["buy shuffle", "end run"] as Array[String], "both buttons report")


func test_at_49_offer_marks_undo() -> void:
	var session: GameSession = _offer_session(RunState.create(U.board_d1024(), 600, U.snapshot_board(), 40))
	var panel: OfferPanel = _offer_panel(&"gumdrop", session)
	assert_eq(panel.buy_button().text, "Undo for 512", "Undo is the rescue")
	panel.buy_button().pressed.emit()
	assert_eq(_events, ["buy undo"] as Array[String], "buys Undo")


func test_at_109_d_offer_with_nothing_marked() -> void:
	var config: GameConfig = GameConfig.new()
	config.cost_shift[&"shuffle"] = 2
	config.cost_shift[&"undo"] = 2
	var session: GameSession = _offer_session(RunState.create(U.board_d1024(), 1500, U.snapshot_board(), 40), config)
	assert_true(session.is_offer_open(), "Hammer and Swap keep the offer open")
	var panel: OfferPanel = _offer_panel(&"gumdrop", session)
	assert_null(panel.buy_button(), "no buy button")
	assert_eq(panel.end_run_button().theme_type_variation, &"PrimaryButton", "End run alone, as the primary button")
	assert_eq(panel.body_text(), Copy.OFFER_NO_RESCUE, "the no rescue text")


func test_offer_rebuilds_only_when_it_changes() -> void:
	var session: GameSession = _offer_session(RunState.create(U.board_d1024(), 5000, U.snapshot_board(), 40))
	var panel: OfferPanel = _offer_panel(&"gumdrop", session)
	var first: Button = panel.buy_button()
	panel.show_offer(session.booster_statuses(), session.state.score)
	assert_true(panel.buy_button() == first, "the same offer keeps its buttons")
	panel.show_offer(session.booster_statuses(), 4000)
	assert_eq(panel.score_text(), "4,000", "a new score shows")


func test_offer_signal_label_follows_the_skin_case() -> void:
	var session: GameSession = _offer_session(RunState.create(U.board_d1024(), 5000, U.snapshot_board(), 40))
	var slate: OfferPanel = _offer_panel(&"slate", session)
	assert_true(_has_text(slate, "OUT OF MOVES"), "Slate's signal label is in capitals")
	assert_eq(slate.theme_type_variation, &"", "Slate's offer has no card")
	var gumdrop: OfferPanel = _offer_panel(&"gumdrop", session)
	assert_true(_has_text(gumdrop, "Out of moves"), "Gumdrop's is as written")
	assert_eq(gumdrop.theme_type_variation, &"CardPanel", "Gumdrop's offer is a card")


# EndPanel (AT-50, AT-54, D-41)

func _summary(new_best: bool) -> RunSummary:
	var summary: RunSummary = RunSummary.new()
	summary.final_score = 76410
	summary.best_score = 96520 if not new_best else 76410
	summary.best_tile = 8192
	summary.run_highest = 2048
	summary.new_best_score = new_best
	return summary


func _end_panel(skin_id: StringName, summary: RunSummary) -> EndPanel:
	var panel: EndPanel = (load("res://scenes/ui/end_panel.tscn") as PackedScene).instantiate() as EndPanel
	_host(skin_id).add_child(panel)
	panel.setup(SkinCatalog.get_skin(skin_id))
	panel.show_summary(summary)
	return panel


func test_end_panel_shows_the_run_highest_tile_and_new_best() -> void:
	var panel: EndPanel = _end_panel(&"gumdrop", _summary(true))
	assert_eq(panel.score_text(), "76,410", "final score")
	assert_true(panel.shows_new_best(), "New best badge")
	assert_eq(panel.tile_values(), PackedInt64Array([8192, 2048]), "Best Tile and this run's highest tile")
	assert_true(_has_text(panel, "New best"), "the badge text")
	assert_true(_has_text(panel, "This run's highest tile"), "the row caption")


func test_end_panel_without_a_new_best() -> void:
	var panel: EndPanel = _end_panel(&"nova", _summary(false))
	assert_false(panel.shows_new_best(), "no badge")
	assert_true(_has_text(panel, "96,520"), "Best Score shown")
	assert_true(_has_text(panel, "Run over"), "Nova's signal label takes the title role, as written")
	assert_true(_has_text(panel, "best score"), "Nova's captions are lowercase")


func test_qa4_01_end_panel_says_no_moves_left() -> void:
	var summary: RunSummary = _summary(false)
	summary.no_moves_left = true
	for skin_id: StringName in SkinCatalog.IDS:
		var panel: EndPanel = _end_panel(skin_id, summary)
		assert_eq(panel.reason_text(), SkinCatalog.get_skin(skin_id).cased(&"body", "No moves left."), "%s: the reason, cased" % skin_id)
		var reason: Label = panel.find_child("Reason", true, false) as Label
		assert_eq(reason.theme_type_variation, &"MutedLabel", "%s: muted body style" % skin_id)
		var expected: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT if skin_id == &"slate" else HORIZONTAL_ALIGNMENT_CENTER
		assert_eq(reason.horizontal_alignment, expected, "%s: aligned like the title" % skin_id)
		var content: Node = reason.get_parent()
		assert_eq(reason.get_index(), 1, "%s: right under the title" % skin_id)
		assert_true(content.get_child(0) is Label, "%s: the title first" % skin_id)


func test_qa4_01_no_reason_after_end_run() -> void:
	var panel: EndPanel = _end_panel(&"gumdrop", _summary(true))
	assert_eq(panel.reason_text(), "", "End run ends with something usable: no reason line")
	assert_null(panel.find_child("Reason", true, false), "and no label")


func test_qa4_04_new_best_sits_on_the_best_score_row() -> void:
	var panel: EndPanel = _end_panel(&"gumdrop", _summary(true))
	var badge: Control = panel.new_best_badge()
	assert_not_null(badge, "the badge shows")
	assert_eq(badge.get_parent().name, &"BestScore", "on the Best score row")
	var row: Node = badge.get_parent()
	assert_true(_has_text(row, "76,410"), "beside the Best Score")
	var score: Label = panel.find_child("FinalScore", true, false) as Label
	assert_false(score.get_parent() == row, "not with the final score")


func test_end_panel_buttons() -> void:
	var panel: EndPanel = _end_panel(&"slate", _summary(false))
	panel.new_game_chosen.connect(_record.bind("new game"))
	panel.main_menu_chosen.connect(_record.bind("menu"))
	(panel.find_child("NewGame", true, false) as Button).pressed.emit()
	(panel.find_child("MainMenu", true, false) as Button).pressed.emit()
	assert_eq(_events, ["new game", "menu"] as Array[String], "both report")
	assert_true(_has_text(panel, "RUN OVER"), "Slate's signal label in capitals")
	panel.close()
	(panel.find_child("NewGame", true, false) as Button).pressed.emit()
	assert_eq(_events.size(), 2, "a closing panel takes no input")


# Pause and the confirmation (7.3, 7.4)

func test_pause_panel_buttons() -> void:
	var panel: PausePanel = (load("res://scenes/ui/pause_panel.tscn") as PackedScene).instantiate() as PausePanel
	_host(&"gumdrop").add_child(panel)
	panel.setup(SkinCatalog.get_skin(&"gumdrop"))
	panel.resume_chosen.connect(_record.bind("resume"))
	panel.new_game_chosen.connect(_record.bind("new game"))
	panel.settings_chosen.connect(_record.bind("settings"))
	for button_name: String in ["Resume", "Newgame", "Settings"]:
		(panel.find_child(button_name, true, false) as Button).pressed.emit()
	assert_eq(_events, ["resume", "new game", "settings"] as Array[String], "every choice reports")
	assert_true(_has_text(panel, "Paused"), "the title")


func test_confirm_dialog() -> void:
	var dialog: ConfirmDialog = (load("res://scenes/ui/confirm_dialog.tscn") as PackedScene).instantiate() as ConfirmDialog
	_host(&"nova").add_child(dialog)
	dialog.setup(SkinCatalog.get_skin(&"nova"), Copy.CONFIRM_TITLE, Copy.CONFIRM_BODY, Copy.NEW_GAME, Copy.CANCEL)
	dialog.confirmed.connect(_record.bind("yes"))
	dialog.cancelled.connect(_record.bind("no"))
	(dialog.find_child("Confirm", true, false) as Button).pressed.emit()
	(dialog.find_child("Cancel", true, false) as Button).pressed.emit()
	assert_eq(_events, ["yes", "no"] as Array[String], "both report")
	assert_true(_has_text(dialog, Copy.CONFIRM_BODY), "the body")


# Settings (7.7)

func test_settings_panel_controls() -> void:
	var settings: Settings = Settings.new()
	settings.set_skin_id(&"slate")
	var panel: SettingsPanel = (load("res://scenes/ui/settings_panel.tscn") as PackedScene).instantiate() as SettingsPanel
	_host(&"slate").add_child(panel)
	panel.setup(SkinCatalog.get_skin(&"slate"), settings)
	panel.closed.connect(_record.bind("closed"))
	var chips: Dictionary[StringName, Button] = panel.skin_chips()
	assert_eq(chips.keys(), [&"gumdrop", &"slate", &"nova"], "three choices in settings order")
	assert_true(chips[&"slate"].button_pressed, "the current skin is selected")
	assert_false(chips[&"gumdrop"].button_pressed, "the others are not")
	assert_eq(chips[&"nova"].text, "Nova", "named")
	panel.sound_toggle().toggled.emit(false)
	assert_false(settings.sound_on, "the toggle sets sound")
	chips[&"gumdrop"].pressed.emit()
	assert_eq(settings.skin_id, &"gumdrop", "a chip sets the skin")
	(panel.find_child("Close", true, false) as BaseButton).pressed.emit()
	assert_eq(_events, ["closed"] as Array[String], "close reports")


func test_settings_swatch_edge_only_when_it_matches_the_panel() -> void:
	var settings: Settings = Settings.new()
	settings.set_skin_id(&"slate")
	var panel: SettingsPanel = (load("res://scenes/ui/settings_panel.tscn") as PackedScene).instantiate() as SettingsPanel
	_host(&"slate").add_child(panel)
	panel.setup(SkinCatalog.get_skin(&"slate"), settings)
	var slate_swatch: PanelContainer = panel.find_child("Swatch_slate", true, false) as PanelContainer
	var nova_swatch: PanelContainer = panel.find_child("Swatch_nova", true, false) as PanelContainer
	var slate_style: StyleBoxFlat = slate_swatch.get_theme_stylebox(&"panel") as StyleBoxFlat
	var nova_style: StyleBoxFlat = nova_swatch.get_theme_stylebox(&"panel") as StyleBoxFlat
	assert_eq(slate_style.border_width_top, 2, "Slate's swatch matches Slate's sheet, so it gets the edge")
	assert_eq(nova_style.border_width_top, 0, "Nova's does not")
	assert_eq(slate_style.bg_color, SkinCatalog.get_skin(&"slate").color(&"bg"), "each swatch in its own skin's bg")
	assert_eq(nova_style.bg_color, SkinCatalog.get_skin(&"nova").color(&"bg"), "Nova's bg")


# Main menu (7.2)

func test_main_menu() -> void:
	var records: Records = Records.new()
	records.best_score = 96520
	records.best_tile = 8192
	var menu: MainMenu = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	_host(&"gumdrop").add_child(menu)
	menu.setup(SkinCatalog.get_skin(&"gumdrop"), records)
	menu.new_game_chosen.connect(_record.bind("new game"))
	menu.settings_chosen.connect(_record.bind("settings"))
	assert_eq(menu.best_score_text(), "96,520", "Best Score")
	assert_true(_has_text(menu, "numbersgame"), "the wordmark")
	assert_eq(_tile_count(menu), 5, "the four decorative tiles, then Best Tile")
	assert_true(_has_text(menu, "Best tile"), "the Best tile row")
	(menu.find_child("NewGame", true, false) as Button).pressed.emit()
	(menu.find_child("Settings", true, false) as BaseButton).pressed.emit()
	assert_eq(_events, ["new game", "settings"] as Array[String], "both report")


func test_main_menu_hides_best_tile_before_the_first_run() -> void:
	var menu: MainMenu = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	_host(&"slate").add_child(menu)
	menu.setup(SkinCatalog.get_skin(&"slate"), Records.new())
	assert_eq(menu.best_score_text(), "0", "Best Score 0")
	assert_eq(_tile_count(menu), 4, "only the decorative tiles")
	assert_false(_has_text(menu, "BEST TILE"), "no Best Tile row yet")
	assert_true(_has_text(menu, "BEST SCORE"), "Slate captions in capitals")


# Shared rules

func test_panel_shape_follows_the_skin() -> void:
	assert_true(UiParts.panel_floats(_host(&"gumdrop")), "Gumdrop's panel is a floating card")
	assert_false(UiParts.panel_floats(_host(&"slate")), "Slate's is a sheet")
	assert_false(UiParts.panel_floats(_host(&"nova")), "Nova's is a sheet")


func test_slate_rules() -> void:
	var slate: SkinData = SkinCatalog.get_skin(&"slate")
	var nova: SkinData = SkinCatalog.get_skin(&"nova")
	assert_eq(UiParts.role(slate, &"SignalLabel"), &"label", "Slate's signal label is the label role")
	assert_eq(UiParts.role(nova, &"SignalLabel"), &"title", "elsewhere the title role")
	var made: Array[Button] = []
	for variation: StringName in [&"PrimaryButton", &"SecondaryButton"]:
		var slate_button: Button = UiParts.button(slate, variation, "Go")
		var nova_button: Button = UiParts.button(nova, variation, "Go")
		assert_eq(slate_button.alignment, HORIZONTAL_ALIGNMENT_LEFT, "Slate left aligns %s text" % variation)
		assert_eq(nova_button.alignment, HORIZONTAL_ALIGNMENT_CENTER, "others center %s text" % variation)
		made.append_array([slate_button, nova_button])
	var chip: Button = UiParts.button(slate, &"ChipButton", "Go")
	assert_eq(chip.alignment, HORIZONTAL_ALIGNMENT_CENTER, "Slate chips keep centered text")
	made.append(chip)
	for button: Button in made:
		button.free()


func test_safe_area() -> void:
	assert_eq(SafeArea.viewport_safe_rect(null), Rect2(), "no viewport, no rect")
	var viewport: Viewport = U.root()
	var visible: Rect2 = viewport.get_visible_rect()
	assert_eq(SafeArea.viewport_safe_rect(viewport), visible, "headless: the whole visible rect")
	SafeArea.simulated_insets = Vector2(120.0, 66.0)
	var simulated: Rect2 = SafeArea.viewport_safe_rect(viewport)
	assert_eq(simulated.position.y, visible.position.y + 120.0, "top inset")
	assert_eq(simulated.end.y, visible.end.y - 66.0, "bottom inset")
	assert_eq(simulated.size.x, visible.size.x, "full width")


func _has_text(node: Node, text: String) -> bool:
	for child: Node in node.find_children("*", "Label", true, false):
		if (child as Label).text == text:
			return true
	return false


func _tile_count(node: Node) -> int:
	var count: int = 0
	for child: Node in node.find_children("*", "", true, false):
		if child is SkinTileView:
			count += 1
	return count
