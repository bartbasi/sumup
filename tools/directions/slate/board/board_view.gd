extends "res://tools/directions/board_common/board_base.gd"
## The Slate board: flat tiles on the bare background, no tray. The chain is
## a straight paper line with a dark edge and square nodes, drawn over the
## fills and under the numbers. Where the line would cross a number it breaks
## around it, the way a rule stops short of type, so no line ever passes
## through a number's box. No preview on the board: the header shows it.
## Fast, exact motion: wipes and cuts, nothing bounces.
##
## Effect functions (see board_base.gd for the players):
##   spawn_frame(fx, progress)        wipe down from the top edge, expo ease
##   pop_frame(fx, progress)          paper flash, then a cut to the color
##   fall_frame(fx, progress, drop)   quart ease out, no bounce
##   play_spawn(), play_chain_to(), play_merge(), play_fall()
##
## Phase 1 prototype code. Nothing under tools/ ships with the game.

const TilePainter: GDScript = preload("res://tools/directions/slate/board/tile_painter.gd")

# Proposed token: the merge result shows paper while the flash level, flash
# times (1 minus the eased merge_pop progress), is at least this; below it the
# tile cuts to its color. With expo ease out this holds paper about 70 ms.
const FLASH_CUT_LEVEL: float = 0.05
## Most line breaks one segment can have.
const MAX_CUTS: int = 16

var _painter: TilePainter = null
var _cut_from: PackedFloat32Array = PackedFloat32Array()
var _cut_to: PackedFloat32Array = PackedFloat32Array()
var _cut_count: int = 0


func spawn_frame(fx: TileFx, progress: float) -> void:
	fx.reset()
	var amount: float = MotionMath.eased(tokens, "spawn", progress)
	var from_scale_y: float = MotionMath.extra(tokens, "spawn", "from_scale_y")
	fx.scale = Vector2(1.0, lerpf(from_scale_y, 1.0, amount))
	fx.pivot = Vector2(0.0, -0.5)


func pop_frame(fx: TileFx, progress: float) -> void:
	fx.reset()
	var amount: float = MotionMath.eased(tokens, "merge_pop", progress)
	var level: float = MotionMath.extra(tokens, "merge_pop", "flash") * (1.0 - amount)
	fx.flash = progress < 1.0 and level >= FLASH_CUT_LEVEL
	fx.layer = TileFx.LAYER_TOP


func fall_frame(fx: TileFx, progress: float, drop: float) -> void:
	fx.reset()
	var amount: float = MotionMath.eased(tokens, "fall", progress)
	fx.offset.y = -drop * (1.0 - amount)
	fx.layer = TileFx.LAYER_MOVING


func _reference_metrics() -> Vector3:
	return TilePainter.reference_metrics(tokens)


func _setup_painters() -> void:
	_painter = TilePainter.new()
	_painter.setup(tokens)
	_cut_from.resize(MAX_CUTS)
	_cut_to.resize(MAX_CUTS)


func _on_layout() -> void:
	_painter.set_side(_side)


func _travel_follows_path() -> bool:
	return false


func _line_cuts_on_merge() -> bool:
	return true


func _draw() -> void:
	if tokens == null:
		return
	# Empty cells, and the cells under tiles that are moving or wiping in.
	for index: int in CELL_COUNT:
		var fx: TileFx = _fx[index]
		if _cells[index] == 0 or fx.offset != Vector2.ZERO or fx.scale.y < 1.0 or fx.hidden:
			_painter.draw_empty(self, _center_of(index))
	# Resting tiles: fills and frames, then the line and nodes, then numbers.
	for index: int in CELL_COUNT:
		if _cells[index] != 0 and _fx[index].layer == TileFx.LAYER_REST:
			_painter.draw_body(self, _center_of(index), _cells[index], _chain_of(index), _fx[index])
	_draw_chain_line()
	for i: int in _chain.size():
		var index: int = _index(_chain[i])
		if not _line_hidden and _fx[index].layer == TileFx.LAYER_REST:
			_painter.draw_node(self, _center_of(index), _chain_amount[index])
	for index: int in CELL_COUNT:
		if _cells[index] != 0 and _fx[index].layer == TileFx.LAYER_REST:
			_painter.draw_number(self, _center_of(index), _cells[index], _fx[index])
	# Moving tiles over the rest, the tile a merge lands on over everything.
	for layer: int in range(TileFx.LAYER_MOVING, TileFx.LAYER_TOP + 1):
		for index: int in CELL_COUNT:
			if _cells[index] != 0 and _fx[index].layer == layer:
				_painter.draw_body(self, _center_of(index), _cells[index], _chain_of(index), _fx[index])
				_painter.draw_number(self, _center_of(index), _cells[index], _fx[index])
	if _target != NO_CELL:
		_painter.draw_brackets(self, cell_center(_target))


func _chain_of(index: int) -> float:
	return _chain_amount[index] if _chain_index[index] >= 0 else 0.0


## The chain line: the dark edge line first, then the paper line on top,
## straight segments with square ends, broken around every number.
func _draw_chain_line() -> void:
	_build_line()
	if _line_count < 2:
		return
	var core: float = tokens.num("line_width") * _scale
	var edge: float = tokens.num("line_edge") * _scale
	var outer: float = core + 2.0 * edge
	# Breaks clear the number by one edge width beyond the edge line.
	var clearance: float = outer * 0.5 + edge
	var node_reach: float = tokens.num("node_size") * _scale + 2.0 * edge
	for pass_index: int in 2:
		var width: float = outer if pass_index == 0 else core
		var line_color: Color = tokens.color("chain_edge") if pass_index == 0 else tokens.color("chain")
		for i: int in _line_count - 1:
			var a: Vector2 = _line_points[i]
			var b: Vector2 = _line_points[i + 1]
			var direction: Vector2 = (b - a).normalized()
			# Square ends: the line runs on half its width past each end.
			if i == 0:
				a -= direction * width * 0.5
			if i == _line_count - 2:
				b += direction * width * 0.5
			_collect_cuts(a, b, clearance)
			# A piece that would barely show past a node reads as a speck, so
			# pieces shorter than a node plus the edge line width are left out.
			var shortest: float = (outer + node_reach) / maxf(a.distance_to(b), 0.001)
			var start: float = 0.0
			for cut: int in _cut_count:
				if _cut_from[cut] - start >= shortest:
					draw_line(a.lerp(b, start), a.lerp(b, _cut_from[cut]), line_color, width, true)
				start = maxf(start, _cut_to[cut])
			if 1.0 - start >= shortest:
				draw_line(a.lerp(b, start), b, line_color, width, true)


## Finds where segment a to b crosses any resting number box grown by
## clearance, as sorted parameter ranges in _cut_from and _cut_to.
func _collect_cuts(a: Vector2, b: Vector2, clearance: float) -> void:
	_cut_count = 0
	var span: Rect2 = Rect2(a, Vector2.ZERO).expand(b).grow(clearance)
	for index: int in CELL_COUNT:
		if _cells[index] == 0 or _fx[index].layer != TileFx.LAYER_REST or _cut_count >= MAX_CUTS:
			continue
		var box: Rect2 = _painter.number_box(_center_of(index), _cells[index]).grow(clearance)
		if not span.intersects(box):
			continue
		var hit: Vector2 = _clip(a, b, box)
		if hit.x > hit.y:
			continue
		# Insert sorted by start.
		var slot: int = _cut_count
		while slot > 0 and _cut_from[slot - 1] > hit.x:
			_cut_from[slot] = _cut_from[slot - 1]
			_cut_to[slot] = _cut_to[slot - 1]
			slot -= 1
		_cut_from[slot] = hit.x
		_cut_to[slot] = hit.y
		_cut_count += 1


## Parameter range (x to y) of segment a to b inside box. x > y means no hit.
static func _clip(a: Vector2, b: Vector2, box: Rect2) -> Vector2:
	var delta: Vector2 = b - a
	var hit: Vector2 = Vector2(0.0, 1.0)
	hit = _clip_edge(hit, -delta.x, a.x - box.position.x)
	hit = _clip_edge(hit, delta.x, box.end.x - a.x)
	hit = _clip_edge(hit, -delta.y, a.y - box.position.y)
	hit = _clip_edge(hit, delta.y, box.end.y - a.y)
	return hit


## One edge of the Liang and Barsky clip.
static func _clip_edge(hit: Vector2, p: float, q: float) -> Vector2:
	if is_zero_approx(p):
		return hit if q >= 0.0 else Vector2(1.0, 0.0)
	var t: float = q / p
	if p < 0.0:
		return Vector2(maxf(hit.x, t), hit.y)
	return Vector2(hit.x, minf(hit.y, t))
