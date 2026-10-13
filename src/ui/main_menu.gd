class_name MainMenu extends Control
## The main menu (DESIGN_SYSTEM.md 7.2). Shown at first launch (no valid
## saved run) and after a run ends, so it never offers Continue. Over the
## skin's backdrop, inside the safe area and the content column (2.8), top to
## bottom:
## - the settings icon button, top right;
## - the brand block, centered (Slate left aligns it): the two tone wordmark
##   "SumUp" ("Sum" in ink, "Up" in accent) sized so it is as wide as the
##   tile row, then space_m and a decorative row of tiles 2, 4, 8 and 16 drawn
##   by the skin's tile component, space_s apart;
## - the records, space_l above the buttons: Best score with the number, then
##   Best tile with a mini tile once there is one;
## - New game (primary), space_s, How to play (secondary), full width less
##   board_margin each side; How to play on the bottom of the safe area.
## The free height between the settings button and the records splits 2 to 3
## above and below the brand block (7.2). The backdrop's clear rects cover
## the brand block, the records and all three buttons. setup must run with
## the menu in the tree.

signal new_game_chosen()
signal settings_chosen()
signal how_to_play_chosen()

const UiParts: GDScript = preload("res://src/ui/ui_parts.gd")
const Copy: GDScript = preload("res://src/ui/screen_copy.gd")

## DESIGN_SYSTEM.md 7.9: the decorative tiles' side.
const DECOR_TILE: float = 160.0
const DECOR_VALUES: Array[int] = [2, 4, 8, 16]
## Side of the Best tile mini tile in the record rows (DESIGN_SYSTEM.md 7.9).
const MINI_TILE: float = 72.0
## DESIGN_SYSTEM.md 7.2: the free height splits 2 to 3 above and below the
## brand block, so the brand sits near the upper golden section.
const SPLIT_ABOVE_BRAND: float = 2.0
const SPLIT_BELOW_BRAND: float = 3.0

var _skin: SkinData = null
var _records: Records = null
var _backdrop: SkinBackdrop = null
var _layout_root: VBoxContainer = null
var _brand: VBoxContainer = null
var _wordmark: HBoxContainer = null
var _records_box: VBoxContainer = null
var _settings_button: BaseButton = null
var _new_game: Button = null
var _how_to_play: Button = null
var _best_score: Label = null


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(skin: SkinData, records: Records) -> void:
	_skin = skin
	_records = records
	UiParts.clear(self)
	_backdrop = UiKit.make_backdrop(skin)
	_backdrop.name = "Backdrop"
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	var margin: float = skin.num(&"board_margin")
	var start: bool = UiParts.align_start(skin)
	_layout_root = UiParts.vbox(0.0)
	_layout_root.name = "Layout"
	add_child(_layout_root)

	var top_margin: MarginContainer = _margins(_layout_root, UiParts.icon_button_inset(skin))
	var top_row: HBoxContainer = UiParts.hbox(0.0)
	top_row.alignment = BoxContainer.ALIGNMENT_END
	top_margin.add_child(top_row)
	_settings_button = UiParts.icon_button(skin, &"settings")
	_settings_button.name = "Settings"
	_settings_button.pressed.connect(_on_settings)
	top_row.add_child(_settings_button)

	# The brand block, with the free height split 2 to 3 above and below it.
	_layout_root.add_child(_spacer(SPLIT_ABOVE_BRAND))
	var brand_margin: MarginContainer = _margins(_layout_root, margin)
	_brand = UiParts.vbox(skin.num(&"space_m"))
	_brand.name = "Brand"
	brand_margin.add_child(_brand)
	_brand.resized.connect(_update_clear_rects)
	var row_width: float = float(DECOR_VALUES.size()) * DECOR_TILE + float(DECOR_VALUES.size() - 1) * skin.num(&"space_s")
	_wordmark = UiParts.wordmark(skin, UiParts.fitted_wordmark_size(skin, row_width), start)
	_brand.add_child(_wordmark)
	var tiles: HBoxContainer = UiParts.hbox(skin.num(&"space_s"))
	tiles.alignment = BoxContainer.ALIGNMENT_BEGIN if start else BoxContainer.ALIGNMENT_CENTER
	_brand.add_child(tiles)
	for value: int in DECOR_VALUES:
		tiles.add_child(UiParts.tile(skin, value, DECOR_TILE))
	_layout_root.add_child(_spacer(SPLIT_BELOW_BRAND))

	# The records and the button, one group in the thumb zone.
	var records_margin: MarginContainer = _margins(_layout_root, margin)
	_records_box = UiParts.vbox(0.0)
	_records_box.name = "Records"
	records_margin.add_child(_records_box)
	_records_box.resized.connect(_update_clear_rects)
	_best_score = UiParts.label(skin, &"BodyLabel", NumberFormat.score(records.best_score if records != null else 0))
	_best_score.name = "BestScore"
	_records_box.add_child(UiParts.record_row(skin, Copy.BEST_SCORE, _best_score))
	if records != null and records.best_tile > 0:
		_records_box.add_child(UiParts.divider())
		_records_box.add_child(UiParts.record_row(skin, Copy.BEST_TILE, UiParts.tile(skin, records.best_tile, MINI_TILE)))
	var gap: Control = Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.custom_minimum_size = Vector2(0.0, skin.num(&"space_l"))
	_layout_root.add_child(gap)
	var bottom: MarginContainer = _margins(_layout_root, margin)
	var buttons: VBoxContainer = UiParts.vbox(skin.num(&"space_s"))
	buttons.name = "Buttons"
	bottom.add_child(buttons)
	_new_game = UiParts.button(skin, &"PrimaryButton", Copy.NEW_GAME)
	_new_game.name = "NewGame"
	_new_game.pressed.connect(_on_new_game)
	buttons.add_child(_new_game)
	_how_to_play = UiParts.button(skin, &"SecondaryButton", Copy.HOW_TO_PLAY)
	_how_to_play.name = "HowToPlay"
	_how_to_play.pressed.connect(_on_how_to_play)
	buttons.add_child(_how_to_play)
	_layout()


## Rebuilds the menu in a new skin.
func apply_skin(skin: SkinData) -> void:
	setup(skin, _records)


## The Best score as shown. For tests.
func best_score_text() -> String:
	return _best_score.text if _best_score != null else ""


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_ENTER_TREE:
		_layout()


## The brand block's global rect, for layout checks.
func brand_rect() -> Rect2:
	return _brand.get_global_rect() if _brand != null else Rect2()


## The wordmark as built. For tests.
func wordmark() -> HBoxContainer:
	return _wordmark


## The layout fills the content column; the backdrop fills the screen.
func _layout() -> void:
	if _layout_root == null or not is_inside_tree():
		return
	layout_in(get_global_rect(), SafeArea.content_column(get_viewport(), _skin))
	_update_clear_rects()


## Lays the menu out for its own rect and the content column, both in the
## same (global) coordinates. _layout calls it; tests call it with rects of
## their own, since headless tests never enter the scene tree.
func layout_in(screen: Rect2, column: Rect2) -> void:
	if _layout_root == null:
		return
	_layout_root.position = column.position - screen.position
	_layout_root.size = column.size


## Keeps the backdrop's decoration clear of the brand block, the records and
## all three buttons.
func _update_clear_rects() -> void:
	if _backdrop == null or _brand == null or not is_inside_tree():
		return
	var clear: Array[Rect2] = [_brand.get_global_rect(), _records_box.get_global_rect(), _new_game.get_global_rect(), _how_to_play.get_global_rect(), _settings_button.get_global_rect()]
	_backdrop.set_clear_rects(clear)


## A spacer that takes ratio shares of the free height.
func _spacer(ratio: float) -> Control:
	var gap: Control = Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.size_flags_stretch_ratio = ratio
	return gap


func _margins(parent: Node, side: float) -> MarginContainer:
	var box: MarginContainer = MarginContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"margin_left", roundi(side))
	box.add_theme_constant_override(&"margin_right", roundi(side))
	parent.add_child(box)
	return box


func _on_new_game() -> void:
	new_game_chosen.emit()


func _on_settings() -> void:
	settings_chosen.emit()


func _on_how_to_play() -> void:
	how_to_play_chosen.emit()
