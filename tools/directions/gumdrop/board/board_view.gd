extends "res://tools/directions/board_common/board_base.gd"
## The Gumdrop board: candy tiles in a rounded tray, a white rope under the
## tiles that shows in the gaps like beads on a string, and a white preview
## bubble above the last chain tile. Springy motion with overshoot.
##
## Effect functions (see board_base.gd for the players):
##   spawn_frame(fx, progress)        pop in from from_scale, back ease
##   pop_frame(fx, progress)          merge result at peak_scale, elastic settle
##   fall_frame(fx, progress, drop)   back ease with a squash on landing
##   play_spawn(), play_chain_to(), play_merge(), play_fall()
##
## Phase 1 prototype code. Nothing under tools/ ships with the game.

const TilePainter: GDScript = preload("res://tools/directions/gumdrop/board/tile_painter.gd")

# Proposed token: preview bubble padding round the mini tile, fraction of the tile side.
const PREVIEW_PADDING: float = 0.08
# Proposed token: preview bubble pointer height, fraction of the tile side.
const POINTER_HEIGHT: float = 0.09
# Proposed token: preview bubble pointer base width, fraction of the tile side.
const POINTER_WIDTH: float = 0.18
# Proposed token: space between the pointer tip and the tile, fraction of the tile side.
const BUBBLE_GAP: float = 0.03
## Peak overshoot of Godot's back ease out (it overshoots by 10 percent).
## The squash grows with the overshoot and is full at this point.
const BACK_OVERSHOOT: float = 0.1

var _painter: TilePainter = null
var _preview_painter: TilePainter = null
var _rest_fx: TileFx = TileFx.new()
var _tray_box: StyleBoxFlat = null
var _bubble_box: StyleBoxFlat = null
var _pointer: PackedVector2Array = PackedVector2Array()
var _pointer_outline: PackedVector2Array = PackedVector2Array()


func spawn_frame(fx: TileFx, progress: float) -> void:
	fx.reset()
	var amount: float = MotionMath.eased(tokens, "spawn", progress)
	var from_scale: float = MotionMath.extra(tokens, "spawn", "from_scale")
	fx.scale = Vector2.ONE * lerpf(from_scale, 1.0, amount)


func pop_frame(fx: TileFx, progress: float) -> void:
	fx.reset()
	var amount: float = MotionMath.eased(tokens, "merge_pop", progress)
	var peak: float = MotionMath.extra(tokens, "merge_pop", "peak_scale")
	fx.scale = Vector2.ONE * lerpf(peak, 1.0, amount)
	fx.layer = TileFx.LAYER_TOP


func fall_frame(fx: TileFx, progress: float, drop: float) -> void:
	fx.reset()
	var amount: float = MotionMath.eased(tokens, "fall", progress)
	fx.offset.y = -drop * (1.0 - amount)
	var squash: float = MotionMath.extra(tokens, "fall", "squash") * clampf((amount - 1.0) / BACK_OVERSHOOT, 0.0, 1.0)
	fx.scale = Vector2(1.0 + squash, 1.0 - squash)
	fx.pivot = Vector2(0.0, 0.5)
	fx.layer = TileFx.LAYER_MOVING


func _reference_metrics() -> Vector3:
	return TilePainter.reference_metrics(tokens)


func _setup_painters() -> void:
	_painter = TilePainter.new()
	_painter.setup(tokens)
	_preview_painter = TilePainter.new()
	_preview_painter.setup(tokens)
	_tray_box = StyleBoxFlat.new()
	_tray_box.bg_color = tokens.color("tray")
	_tray_box.anti_aliasing = true
	_tray_box.corner_detail = TilePainter.CORNER_DETAIL
	_bubble_box = StyleBoxFlat.new()
	_bubble_box.bg_color = tokens.color("ink")
	_bubble_box.anti_aliasing = true
	_bubble_box.corner_detail = TilePainter.CORNER_DETAIL
	_pointer.resize(3)
	_pointer_outline.resize(4)


func _on_layout() -> void:
	_painter.set_side(_side)
	_preview_painter.set_side(tokens.num("preview_scale") * _side)
	_tray_box.set_corner_radius_all(roundi(tokens.num("tray_radius") * _scale))
	var bubble_side: float = _bubble_side()
	_bubble_box.set_corner_radius_all(roundi(tokens.num("tile_radius") * bubble_side))


func _draw() -> void:
	if tokens == null:
		return
	_tray_box.draw(get_canvas_item(), _board_rect)
	for index: int in CELL_COUNT:
		var fx: TileFx = _fx[index]
		if _cells[index] == 0 or fx.offset != Vector2.ZERO or fx.scale.x < 1.0 or fx.hidden:
			_painter.draw_slot(self, _center_of(index))
	_draw_rope()
	var target_index: int = _index(_target) if _target != NO_CELL else -1
	for layer: int in TileFx.LAYER_TOP + 1:
		for index: int in CELL_COUNT:
			if _cells[index] == 0 or index == target_index:
				continue
			if _fx[index].layer != layer:
				continue
			var chain: float = _chain_amount[index] if _chain_index[index] >= 0 else 0.0
			_painter.draw_tile(self, _center_of(index), _cells[index], chain, false, _fx[index])
	if target_index >= 0 and _cells[target_index] != 0:
		_painter.draw_tile(self, _center_of(target_index), _cells[target_index], 0.0, true, _fx[target_index], _wobble())
	_draw_preview()


## The rope: round capped and round jointed, under the tiles.
func _draw_rope() -> void:
	_build_line()
	if _line_count == 0:
		return
	var rope_color: Color = tokens.color("chain")
	var width: float = tokens.num("rope_width") * _scale
	for i: int in _line_count - 1:
		draw_line(_line_points[i], _line_points[i + 1], rope_color, width, true)
	for i: int in _line_count:
		draw_circle(_line_points[i], width * 0.5, rope_color, true, -1.0, true)


## Target wobble angle on the target_pulse loop, 0 at the start of the loop.
func _wobble() -> float:
	if not _targeting:
		return 0.0
	var quarter: float = tokens.duration("target_pulse") * 0.25
	var wave: float = MotionMath.loop_wave(tokens, "target_pulse", _pulse_time + quarter)
	return deg_to_rad(MotionMath.extra(tokens, "target_pulse", "wobble_degrees")) * (wave * 2.0 - 1.0)


func _bubble_side() -> float:
	return (tokens.num("preview_scale") + 2.0 * PREVIEW_PADDING) * _side


## The preview bubble with its pointer and the mini tile of the result.
func _draw_preview() -> void:
	if _preview <= 0 or _chain.is_empty():
		return
	var last: Vector2i = _chain.back()
	var tile: Rect2 = cell_rect(last)
	var bubble_side: float = _bubble_side()
	var pointer_height: float = POINTER_HEIGHT * _side
	var gap: float = BUBBLE_GAP * _side
	var above: bool = last.y > 0
	var center_x: float = clampf(tile.get_center().x, _board_rect.position.x + bubble_side * 0.5, _board_rect.end.x - bubble_side * 0.5)
	var tip: Vector2 = Vector2(tile.get_center().x, tile.position.y - gap if above else tile.end.y + gap)
	var bubble_top: float = tip.y - pointer_height - bubble_side if above else tip.y + pointer_height
	var bubble: Rect2 = Rect2(center_x - bubble_side * 0.5, bubble_top, bubble_side, bubble_side)
	var base_y: float = bubble.end.y if above else bubble.position.y
	var half_base: float = POINTER_WIDTH * _side * 0.5
	var ink: Color = tokens.color("ink")
	_pointer[0] = Vector2(tip.x - half_base, base_y)
	_pointer[1] = Vector2(tip.x + half_base, base_y)
	_pointer[2] = tip
	_pointer_outline[0] = _pointer[0]
	_pointer_outline[1] = _pointer[2]
	_pointer_outline[2] = _pointer[1]
	_pointer_outline[3] = _pointer[0]
	draw_colored_polygon(_pointer, ink)
	draw_polyline(_pointer_outline, ink, 1.0, true)
	_bubble_box.draw(get_canvas_item(), bubble)
	_preview_painter.draw_tile(self, bubble.get_center(), _preview, 0.0, false, _rest_fx)
