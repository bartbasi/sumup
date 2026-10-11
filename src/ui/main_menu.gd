class_name MainMenu extends Control
## The main menu (DESIGN_SYSTEM.md 7.2). Shown at first launch (no valid
## saved run) and after a run ends, so it never offers Continue. Over the
## skin's backdrop, inside the safe area, top to bottom:
## - the settings icon button, top right;
## - the wordmark in the title role (Slate left aligns it, and the blocks
##   under it);
## - a decorative row of tiles 2, 4, 8 and 16 drawn by the skin's tile
##   component, space_s apart;
## - the records: Best score with the number, Best tile with a mini tile
##   (once there is one);
## - New game, the only button, full width less board_margin each side, on
##   the bottom of the safe area.
## setup must run with the menu in the tree.

signal new_game_chosen()
signal settings_chosen()

const UiParts: GDScript = preload("res://src/ui/ui_parts.gd")
const Copy: GDScript = preload("res://src/ui/screen_copy.gd")

## DESIGN_SYSTEM.md 7.9: the decorative tiles' side.
const DECOR_TILE: float = 112.0
const DECOR_VALUES: Array[int] = [2, 4, 8, 16]
## Side of the Best tile mini tile: the skin choice preview size of 7.9, the
## design gives no other.
const MINI_TILE: float = 72.0

var _skin: SkinData = null
var _records: Records = null
var _backdrop: SkinBackdrop = null
var _layout_root: VBoxContainer = null
var _blocks: VBoxContainer = null
var _settings_button: BaseButton = null
var _new_game: Button = null
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
	var align: HorizontalAlignment = UiParts.block_alignment(skin)
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

	_layout_root.add_child(_spacer())
	var inner: MarginContainer = _margins(_layout_root, margin)
	var blocks: VBoxContainer = UiParts.vbox(skin.num(&"space_l"))
	blocks.name = "Blocks"
	inner.add_child(blocks)
	_blocks = blocks
	blocks.resized.connect(_update_clear_rects)

	blocks.add_child(UiParts.label(skin, &"TitleLabel", Copy.WORDMARK, align))
	var tiles: HBoxContainer = UiParts.hbox(skin.num(&"space_s"))
	tiles.alignment = BoxContainer.ALIGNMENT_BEGIN if start else BoxContainer.ALIGNMENT_CENTER
	blocks.add_child(tiles)
	for value: int in DECOR_VALUES:
		tiles.add_child(UiParts.tile(skin, value, DECOR_TILE))

	var rows: VBoxContainer = UiParts.vbox(0.0)
	blocks.add_child(rows)
	_best_score = UiParts.label(skin, &"BodyLabel", NumberFormat.score(records.best_score if records != null else 0))
	_best_score.name = "BestScore"
	rows.add_child(UiParts.record_row(skin, Copy.BEST_SCORE, _best_score))
	if records != null and records.best_tile > 0:
		rows.add_child(UiParts.divider())
		rows.add_child(UiParts.record_row(skin, Copy.BEST_TILE, UiParts.tile(skin, records.best_tile, MINI_TILE)))

	_layout_root.add_child(_spacer())
	var bottom: MarginContainer = _margins(_layout_root, margin)
	_new_game = UiParts.button(skin, &"PrimaryButton", Copy.NEW_GAME)
	_new_game.name = "NewGame"
	_new_game.pressed.connect(_on_new_game)
	bottom.add_child(_new_game)
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


## The layout fills the safe area; the backdrop fills the screen.
func _layout() -> void:
	if _layout_root == null or not is_inside_tree():
		return
	var safe: Rect2 = SafeArea.viewport_safe_rect(get_viewport())
	_layout_root.position = safe.position - get_global_rect().position
	_layout_root.size = safe.size
	_update_clear_rects()


## Keeps the backdrop's decoration clear of the text blocks and buttons.
func _update_clear_rects() -> void:
	if _backdrop == null or _blocks == null or not is_inside_tree():
		return
	var clear: Array[Rect2] = [_blocks.get_global_rect(), _new_game.get_global_rect(), _settings_button.get_global_rect()]
	_backdrop.set_clear_rects(clear)


func _spacer() -> Control:
	var gap: Control = Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
