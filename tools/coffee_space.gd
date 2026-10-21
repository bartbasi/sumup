extends SceneTree
## Free space on the play screen for the Buy me a coffee button
## (DESIGN_SYSTEM.md 7.15). Run from the repo root:
##     godot --headless --path . --script res://tools/coffee_space.gd
##
## For each phone shape and skin it lays the play screen out the way
## GameScreen.layout_in does (DESIGN_SYSTEM.md 2.3 and 2.8): the safe area,
## the content column (SafeArea.column_in), the HUD and the bar at their
## preferred heights, and the board centered in the region between them,
## sized by the skin's real board view. It prints, in logical px: the slack
## above and below the board, the side gutters outside the column, and
## whether the button fits below the board (the slack is at least touch_min)
## or in a side gutter. It only measures; it always exits with 0.

## One phone: its canvas in logical px (2.1: 2400 tall, or 1080 wide when
## the screen is narrower than 9:20) and its safe insets in logical px.
## Insets come from dp at the canvas's px per dp. Assumed system bars, as in
## DESIGN_SYSTEM.md 2.4: 40 dp status bar with a camera cutout and a 22 dp
## gesture bar, except the 16:9 phone (24 dp status bar, 48 dp button bar).
const PHONES: Array[Dictionary] = [
	{"name": "20:9 phone, 1080 x 2400 px at 3.0 (360 x 800 dp)", "px": Vector2(1080, 2400), "density": 3.0, "top_dp": 40.0, "bottom_dp": 22.0},
	{"name": "Fold5 cover, 904 x 2316 px at 2.625 (344 x 882 dp)", "px": Vector2(904, 2316), "density": 2.625, "top_dp": 40.0, "bottom_dp": 22.0},
	{"name": "Fold5 inner, 1812 x 2176 px at 2.625 (690 x 829 dp)", "px": Vector2(1812, 2176), "density": 2.625, "top_dp": 40.0, "bottom_dp": 22.0},
	{"name": "16:9 phone, 1080 x 1920 px at 3.0 (360 x 640 dp), button bar", "px": Vector2(1080, 1920), "density": 3.0, "top_dp": 24.0, "bottom_dp": 48.0},
]
const BASE: Vector2 = Vector2(1080, 2400)


func _initialize() -> void:
	for phone: Dictionary in PHONES:
		var px: Vector2 = phone["px"]
		# Logical canvas: keep 2400 tall when wider than 9:20, else 1080 wide.
		var scale: float = px.y / BASE.y
		if px.x / px.y < BASE.x / BASE.y:
			scale = px.x / BASE.x
		var canvas: Vector2 = px / scale
		var per_dp: float = float(phone["density"]) / scale
		var safe: Rect2 = Rect2(0.0, float(phone["top_dp"]) * per_dp, canvas.x, canvas.y - (float(phone["top_dp"]) + float(phone["bottom_dp"])) * per_dp)
		print("")
		print("%s: canvas %d x %d logical px, %.3f px per dp, safe area y %d to %d" % [
			phone["name"], roundi(canvas.x), roundi(canvas.y), per_dp, roundi(safe.position.y), roundi(safe.end.y)])
		for skin_id: StringName in SkinCatalog.IDS:
			_measure(SkinCatalog.get_skin(skin_id), canvas, safe, per_dp)
	quit(0)


func _measure(skin: SkinData, canvas: Vector2, safe: Rect2, per_dp: float) -> void:
	var column: Rect2 = SafeArea.column_in(safe, skin)
	var margin: float = skin.num(&"board_margin")
	var gap: float = skin.num(&"space_s")
	var hud: float = skin.num(&"hud_height")
	var bar: float = skin.num(&"bar_height")
	var board: SkinBoardView = SkinCatalog.make_board_view(skin)
	board.setup(skin, 5, 8)
	var region_top: float = column.position.y + hud + gap
	var bar_top: float = column.end.y - bar
	var region_height: float = maxf(0.0, bar_top - gap - region_top)
	var width: float = maxf(0.0, column.size.x - margin * 2.0)
	var height: float = board.preferred_height(width)
	if height > region_height:
		width = SafeArea.board_width_for_height(skin, region_height)
		height = board.preferred_height(width)
	var slack: float = maxf(0.0, region_height - height) * 0.5
	var gutter: float = column.position.x
	var tile: float = (width - 4.0 * skin.num(&"board_gap") - 2.0 * skin.num(&"board_padding")) / 5.0
	if skin.numbers.has(&"orb_scale"):
		tile = width / 5.0 * skin.num(&"orb_scale")
	board.free()
	var touch: float = skin.num(&"touch_min")
	print("  %-7s board %d x %d (tile %.1f dp), slack above and below %d px (%.1f dp) each, side gutters %d px; below the board: %s; in a gutter: %s" % [
		skin.display_name, roundi(width), roundi(height), tile / per_dp, roundi(slack), slack / per_dp, roundi(gutter),
		"fits" if slack >= touch else "no room", "fits" if gutter >= touch + 2.0 * gap else "no room"])
