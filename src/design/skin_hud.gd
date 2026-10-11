class_name SkinHud extends Control
## The play screen HUD of one skin (docs/ARCHITECTURE.md section 7). Each
## skin subclasses it in src/design/<id>/. Screens get one from
## UiKit.make_hud(), place it full width with its top on the safe area's top,
## height preferred_height(), and use only the signal and methods below.
##
## The HUD ignores the mouse except on its pause button.

## The HUD's pause button was tapped.
signal pause_pressed()


func setup(_skin: SkinData) -> void:
	_missing(&"setup")


## Shows the score and the Best Score, formatted with NumberFormat.score. The
## score's size fits its slot (DESIGN_SYSTEM.md 2.6). To count the score up,
## call set_scores with the new values first, so the size fits the final
## value, then Motion.count_up on score_label().
func set_scores(_score: int, _best_score: int) -> void:
	_missing(&"set_scores")


## The context row: "Chain 6" while dragging (highlight false), or the
## targeting hint (highlight true), in the screen's words; "" clears it. A
## skin with no context row ignores it.
func set_context(_text: String, _highlight: bool) -> void:
	_missing(&"set_context")


## Where the screen puts a SkinTileView merge preview, sized to fill it. null
## when the skin shows the preview on the board.
func preview_slot() -> Control:
	_missing(&"preview_slot")
	return null


## The score label, for Motion.count_up.
func score_label() -> Label:
	_missing(&"score_label")
	return null


## D-38 clear notice (AT-104). Builds its own copy (DESIGN_SYSTEM.md 7.10)
## from the cleared values, ascending, and places itself: Gumdrop and Nova on
## the board's top edge (board_rect is global), Slate in its context row. It
## never blocks input, and a later call replaces a notice still showing.
func show_clear_notice(_cleared_values: PackedInt64Array, _board_rect: Rect2) -> void:
	_missing(&"show_clear_notice")


## The HUD's height in px: the skin's hud_height.
func preferred_height() -> float:
	_missing(&"preferred_height")
	return 0.0


func _missing(method: StringName) -> void:
	var script: Script = get_script() as Script
	var path: String = script.resource_path if script != null else "?"
	push_error("%s does not implement SkinHud.%s()" % [path, method])
