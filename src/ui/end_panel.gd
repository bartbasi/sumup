class_name EndPanel extends "res://src/ui/dialog_base.gd"
## End of run (DESIGN_SYSTEM.md 7.6, GDD 12.3 and D-41), a panel over the
## scrim with the final board dimmed behind it:
## - "Run over" (the signal label);
## - the final score in the display role, fitted to the panel (2.6);
## - the New best badge when this run set the Best Score;
## - rows split by the skin's divider: Best score with the number, Best tile
##   and This run's highest tile, each with a mini tile;
## - New game (primary) and Main menu (secondary).
## Back on this panel quits the app after saving (the App handles it).

signal new_game_chosen()
signal main_menu_chosen()

## Side of the mini tiles in the record rows: the skin choice preview tile
## size of DESIGN_SYSTEM.md 7.9, which gives no other size for them.
const MINI_TILE: float = 72.0

var _summary: RunSummary = null
var _score_label: Label = null
var _badge: Control = null


func setup(skin: SkinData) -> void:
	_frame(skin)
	if _summary != null:
		_fill(skin, _summary)


func show_summary(summary: RunSummary) -> void:
	_summary = summary
	if _skin != null:
		_frame(_skin)
		_fill(_skin, summary)


## Rebuilds the panel in a new skin, still open.
func apply_skin(skin: SkinData) -> void:
	setup(skin)


## The final score as shown. For tests.
func score_text() -> String:
	return _score_label.text if _score_label != null else ""


## True when the New best badge shows. For tests.
func shows_new_best() -> bool:
	return _badge != null


## The values of the mini tiles: Best tile, then this run's highest tile. For tests.
func tile_values() -> PackedInt64Array:
	var values: PackedInt64Array = PackedInt64Array()
	if _summary != null:
		values.append(_summary.best_tile)
		values.append(_summary.run_highest)
	return values


func _fill(skin: SkinData, summary: RunSummary) -> void:
	var align: HorizontalAlignment = UiParts.block_alignment(skin)
	_content.add_child(UiParts.label(skin, &"SignalLabel", Copy.RUN_OVER, align))
	_score_label = UiParts.label(skin, &"DisplayLabel", NumberFormat.score(summary.final_score), align)
	_score_label.name = "FinalScore"
	if is_inside_tree():
		_score_label.add_theme_font_size_override(&"font_size", skin.score_font_size(_score_label.text, _text_width(skin)))
	_content.add_child(_score_label)
	_badge = null
	if summary.new_best_score:
		var holder: HBoxContainer = UiParts.hbox(0.0)
		holder.alignment = BoxContainer.ALIGNMENT_BEGIN if UiParts.align_start(skin) else BoxContainer.ALIGNMENT_CENTER
		_badge = UiParts.badge(skin, Copy.NEW_BEST)
		_badge.name = "NewBest"
		holder.add_child(_badge)
		_content.add_child(holder)

	var rows: VBoxContainer = UiParts.vbox(0.0)
	_content.add_child(rows)
	rows.add_child(UiParts.divider())
	rows.add_child(UiParts.record_row(skin, Copy.BEST_SCORE, UiParts.label(skin, &"BodyLabel", NumberFormat.score(summary.best_score))))
	rows.add_child(UiParts.divider())
	rows.add_child(UiParts.record_row(skin, Copy.BEST_TILE, UiParts.tile(skin, summary.best_tile, MINI_TILE)))
	rows.add_child(UiParts.divider())
	rows.add_child(UiParts.record_row(skin, Copy.RUN_HIGHEST, UiParts.tile(skin, summary.run_highest, MINI_TILE)))
	rows.add_child(UiParts.divider())

	var buttons: HBoxContainer = UiParts.hbox(skin.num(&"space_s"))
	_content.add_child(buttons)
	var again: Button = UiParts.button(skin, &"PrimaryButton", Copy.NEW_GAME)
	again.name = "NewGame"
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(_on_new_game)
	buttons.add_child(again)
	var menu: Button = UiParts.button(skin, &"SecondaryButton", Copy.MAIN_MENU)
	menu.name = "MainMenu"
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.pressed.connect(_on_main_menu)
	buttons.add_child(menu)


## The width the score may take: the screen less the panel's margins and
## padding.
func _text_width(skin: SkinData) -> float:
	return get_viewport_rect().size.x - 2.0 * (skin.num(&"board_margin") + skin.num(&"space_m"))


func _on_new_game() -> void:
	if not _closing:
		new_game_chosen.emit()


func _on_main_menu() -> void:
	if not _closing:
		main_menu_chosen.emit()
