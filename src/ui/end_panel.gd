class_name EndPanel extends "res://src/ui/dialog_base.gd"
## End of run (DESIGN_SYSTEM.md 7.6, GDD 12.3 and D-41), a panel over the
## scrim with the final board dimmed behind it:
## - "Run over" (the signal label);
## - "No moves left." (muted) when the run ended at once because nothing was
##   usable (GDD 12.2 step 3, RunSummary.no_moves_left);
## - the final score in the display role, fitted to the panel (2.6);
## - rows split by the skin's divider: Best score with the number, and the
##   New best badge beside it when this run set the Best Score; Best tile and
##   This run's highest tile, each with a mini tile;
## - New game (primary) and Main menu (secondary).
## Back on this panel quits the app after saving (the App handles it).

signal new_game_chosen()
signal main_menu_chosen()

## Side of the mini tiles in the record rows (DESIGN_SYSTEM.md 7.9).
const MINI_TILE: float = 72.0

var _summary: RunSummary = null
var _score_label: Label = null
var _badge: Control = null
var _reason: Label = null


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


## The New best badge, on the Best score row, or null. For tests.
func new_best_badge() -> Control:
	return _badge


## "No moves left." as shown when the run ended with nothing usable, else
## "". For tests.
func reason_text() -> String:
	return _reason.text if _reason != null else ""


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
	_reason = null
	if summary.no_moves_left:
		_reason = UiParts.paragraph(skin, &"MutedLabel", Copy.NO_MOVES_LEFT, align)
		_reason.name = "Reason"
		_content.add_child(_reason)
	_score_label = UiParts.label(skin, &"DisplayLabel", NumberFormat.score(summary.final_score), align)
	_score_label.name = "FinalScore"
	if is_inside_tree():
		_score_label.add_theme_font_size_override(&"font_size", skin.score_font_size(_score_label.text, _text_width(skin)))
	_content.add_child(_score_label)

	var rows: VBoxContainer = UiParts.vbox(0.0)
	_content.add_child(rows)
	rows.add_child(UiParts.divider())
	# The New best badge sits on the Best score row, by the record it names,
	# not under a final score that spending may have left lower (QA4-04).
	var best: HBoxContainer = UiParts.hbox(skin.num(&"space_s"))
	best.name = "BestScore"
	_badge = null
	if summary.new_best_score:
		_badge = UiParts.badge(skin, Copy.NEW_BEST)
		_badge.name = "NewBest"
		_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		best.add_child(_badge)
	best.add_child(UiParts.label(skin, &"BodyLabel", NumberFormat.score(summary.best_score)))
	rows.add_child(UiParts.record_row(skin, Copy.BEST_SCORE, best))
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


## The width the score may take: the content column less the panel's margins
## and padding.
func _text_width(skin: SkinData) -> float:
	return SafeArea.content_column(get_viewport(), skin).size.x - 2.0 * (skin.num(&"board_margin") + skin.num(&"space_m"))


func _on_new_game() -> void:
	if not _closing:
		new_game_chosen.emit()


func _on_main_menu() -> void:
	if not _closing:
		main_menu_chosen.emit()
