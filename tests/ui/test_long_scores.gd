extends "res://tests/base_test.gd"
## QA6-10 and AT-144 (b): a score longer than the 13 characters the design
## covers (only a hand edited save holds one) shrinks until it fits, even
## below display_fit_min, and no panel is ever wider than the screen column
## (DESIGN_SYSTEM.md 2.6). Up to 13 characters nothing changes.
##
## Headless tests never enter the scene tree, so theme lookups on nodes give
## Godot's defaults. These checks measure every text with the skin's own
## fonts and sizes and read the paddings from the skin's Theme resource.

const U := preload("res://tests/ui/ui_fixtures.gd")
const UiParts: GDScript = preload("res://src/ui/ui_parts.gd")

const PHONE: Vector2i = Vector2i(1080, 2400)
## AT-144 (b): the final score after the Hammer on 2^63 minus 1.
const FINAL_SCORE: int = 4611686018427387903
const MAX_SCORE: int = 9223372036854775807
const TOP_TILE: int = 4611686018427387904

var _stages: Array[Control] = []


func before_each() -> void:
	_stages = []


func after_each() -> void:
	for host: Control in _stages:
		U.free_stage(host)


func _stage(skin_id: StringName) -> Control:
	var host: Control = U.stage(PHONE, skin_id)
	_stages.append(host)
	return host


func _column(skin: SkinData) -> Rect2:
	return SafeArea.column_in(U.safe_rect(PHONE), skin)


## The font size a label shows at: its override, else its role's size.
func _size_of(skin: SkinData, label: Label) -> int:
	if label.has_theme_font_size_override(&"font_size"):
		return label.get_theme_font_size(&"font_size")
	return skin.font_size(UiParts.role(skin, label.theme_type_variation))


## A label's text width in the skin's font for its role, at the size it shows.
func _width_of(skin: SkinData, label: Label) -> float:
	var face: Font = skin.font(UiParts.role(skin, label.theme_type_variation))
	return face.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _size_of(skin, label)).x


func _style_width(theme: Theme, item: StringName, type: StringName, fallback: StringName) -> float:
	if theme.has_stylebox(item, type):
		return theme.get_stylebox(item, type).get_minimum_size().x
	if theme.has_stylebox(item, fallback):
		return theme.get_stylebox(item, fallback).get_minimum_size().x
	return 0.0


func _button_width(skin: SkinData, theme: Theme, button: Button) -> float:
	var face: Font = skin.font(UiParts.role(skin, button.theme_type_variation))
	var text: float = face.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, skin.font_size(UiParts.role(skin, button.theme_type_variation))).x
	return text + _style_width(theme, &"normal", button.theme_type_variation, &"Button")


func _summary() -> RunSummary:
	var summary: RunSummary = RunSummary.new()
	summary.final_score = FINAL_SCORE
	summary.best_score = MAX_SCORE
	summary.best_tile = TOP_TILE
	summary.run_highest = TOP_TILE
	summary.new_best_score = true
	summary.no_moves_left = true
	return summary


func _end_panel(skin_id: StringName, summary: RunSummary) -> EndPanel:
	var skin: SkinData = SkinCatalog.get_skin(skin_id)
	var host: Control = _stage(skin_id)
	var panel: EndPanel = (load("res://scenes/ui/end_panel.tscn") as PackedScene).instantiate() as EndPanel
	host.add_child(panel)
	U.fit(panel, Vector2(PHONE))
	panel.setup(skin)
	panel.show_summary(summary)
	panel.layout_in(Rect2(Vector2.ZERO, Vector2(PHONE)), _column(skin), skin_id == &"gumdrop")
	return panel


func test_qa6_10_end_panel_with_a_25_character_score_fits_the_screen() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var skin: SkinData = SkinCatalog.get_skin(skin_id)
		var theme: Theme = UiKit.build_theme(skin)
		var panel: EndPanel = _end_panel(skin_id, _summary())
		var column: Rect2 = _column(skin)
		var card: PanelContainer = panel.panel()
		var left: float = card.offset_left
		var right: float = float(PHONE.x) + card.offset_right
		assert_true(left >= column.position.x and right <= column.end.x, "%s: the panel's place is inside the column (%d to %d)" % [skin_id, roundi(left), roundi(right)])
		var content: float = right - left - _style_width(theme, &"panel", &"CardPanel", &"PanelContainer")
		assert_true(content > 0.0, "%s: room for content" % skin_id)

		var score: Label = panel.find_child("FinalScore", true, false) as Label
		assert_eq(score.text, "4,611,686,018,427,387,903", "%s: the whole score shows" % skin_id)
		assert_true(_width_of(skin, score) <= content, "%s: the score (%d px at %d px type) fits the panel's %d px" % [skin_id, roundi(_width_of(skin, score)), _size_of(skin, score), roundi(content)])
		var font_px: int = _size_of(skin, score)
		assert_true(font_px <= int(skin.num(&"display_fit_min")) or font_px == skin.score_font_size(score.text, content), "%s: it shrinks only as far as it must" % skin_id)

		# Every single line label fits on its own: "Run over", the captions,
		# the numbers.
		for node: Node in card.find_children("*", "Label", true, false):
			var label: Label = node as Label
			if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
				continue
			assert_true(_width_of(skin, label) <= content, "%s: \"%s\" fits the panel" % [skin_id, label.text])

		# The Best score row: caption, badge and number side by side.
		var gap: float = float(roundi(skin.num(&"space_s")))
		var row: HBoxContainer = panel.find_child("BestScore", true, false).get_parent() as HBoxContainer
		var caption: Label = row.get_child(0) as Label
		var badge: PanelContainer = panel.new_best_badge()
		assert_not_null(badge, "%s: the New best badge shows" % skin_id)
		var number: Label = panel.find_child("Number", true, false) as Label
		assert_eq(number.text, "9,223,372,036,854,775,807", "%s: the whole Best score shows" % skin_id)
		var badge_width: float = _width_of(skin, badge.get_child(0) as Label) + _style_width(theme, &"panel", &"BadgePanel", &"PanelContainer")
		var row_width: float = _width_of(skin, caption) + gap + badge_width + gap + _width_of(skin, number)
		assert_true(row_width <= content, "%s: the Best score row (%d px) fits the panel's %d px" % [skin_id, roundi(row_width), roundi(content)])

		# The buttons side by side.
		var buttons: float = _button_width(skin, theme, panel.find_child("NewGame", true, false) as Button) + gap + _button_width(skin, theme, panel.find_child("MainMenu", true, false) as Button)
		assert_true(buttons <= content, "%s: New game and Main menu fit" % skin_id)


func test_qa6_10_slate_goes_below_display_fit_min() -> void:
	# The case QA found: at display_fit_min Slate's score alone is wider than
	# the screen.
	var skin: SkinData = SkinCatalog.get_skin(&"slate")
	var panel: EndPanel = _end_panel(&"slate", _summary())
	var score: Label = panel.find_child("FinalScore", true, false) as Label
	var face: Font = skin.font(&"display")
	var at_min: float = face.get_string_size(score.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(skin.num(&"display_fit_min"))).x
	assert_true(at_min > float(PHONE.x) - 80.0, "at display_fit_min it would not fit (%d px)" % roundi(at_min))
	assert_true(_size_of(skin, score) < int(skin.num(&"display_fit_min")), "so it goes below display_fit_min")


func test_qa6_10_up_to_13_characters_nothing_changes() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var skin: SkinData = SkinCatalog.get_skin(skin_id)
		var summary: RunSummary = _summary()
		summary.final_score = 9999999999
		summary.best_score = 9999999999
		var panel: EndPanel = _end_panel(skin_id, summary)
		var score: Label = panel.find_child("FinalScore", true, false) as Label
		assert_eq(score.text, "9,999,999,999", skin_id)
		var slot: float = _column(skin).size.x - 2.0 * (skin.num(&"board_margin") + skin.num(&"space_m"))
		assert_eq(_size_of(skin, score), skin.score_font_size(score.text, slot), "%s: the score keeps the size 2.6 gives it" % skin_id)
		var number: Label = panel.find_child("Number", true, false) as Label
		assert_false(number.has_theme_font_size_override(&"font_size"), "%s: the Best score number keeps the body size" % skin_id)


func test_qa6_10_offer_with_the_largest_score_fits_its_width() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var skin: SkinData = SkinCatalog.get_skin(skin_id)
		var theme: Theme = UiKit.build_theme(skin)
		var host: Control = _stage(skin_id)
		var offer: OfferPanel = (load("res://scenes/ui/offer_panel.tscn") as PackedScene).instantiate() as OfferPanel
		host.add_child(offer)
		offer.setup(skin)
		var session: GameSession = GameSession.new()
		session.resume(RunState.create(U.board_d1024(), MAX_SCORE))
		session.move_shown()
		offer.show_offer(session.booster_statuses(), MAX_SCORE)
		var width: float = _column(skin).size.x - 2.0 * skin.num(&"board_margin")
		offer.fit_width(width)
		assert_eq(offer.score_text(), "9,223,372,036,854,775,807", "%s: the whole score shows" % skin_id)
		var variation: StringName = offer.theme_type_variation if offer.theme_type_variation != &"" else &"PanelContainer"
		var content: float = width - _style_width(theme, &"panel", variation, &"PanelContainer")
		var score: Label = offer.find_child("Score", true, false) as Label
		var top: HBoxContainer = score.get_parent().get_parent() as HBoxContainer
		var title: Label = top.get_child(0) as Label
		var row_width: float = _width_of(skin, title) + float(roundi(skin.num(&"space_s"))) + _width_of(skin, score)
		assert_true(row_width <= content, "%s: \"Out of moves\" and the score (%d px) fit the offer's %d px" % [skin_id, roundi(row_width), roundi(content)])


func test_qa6_10_menu_best_score_fits_the_column() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var skin: SkinData = SkinCatalog.get_skin(skin_id)
		var host: Control = _stage(skin_id)
		var menu: MainMenu = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate() as MainMenu
		host.add_child(menu)
		U.fit(menu, Vector2(PHONE))
		var records: Records = Records.new()
		records.best_score = MAX_SCORE
		records.best_tile = TOP_TILE
		menu.setup(skin, records)
		var column: Rect2 = _column(skin)
		menu.layout_in(Rect2(Vector2.ZERO, Vector2(PHONE)), column)
		assert_eq(menu.best_score_text(), "9,223,372,036,854,775,807", "%s: the whole Best score shows" % skin_id)
		var number: Label = menu.find_child("BestScore", true, false) as Label
		var caption: Label = number.get_parent().get_child(0) as Label
		var row_width: float = _width_of(skin, caption) + float(roundi(skin.num(&"space_s"))) + _width_of(skin, number)
		var room: float = column.size.x - 2.0 * float(roundi(skin.num(&"board_margin")))
		assert_true(row_width <= room, "%s: the Best score row (%d px) fits the column's %d px" % [skin_id, roundi(row_width), roundi(room)])
