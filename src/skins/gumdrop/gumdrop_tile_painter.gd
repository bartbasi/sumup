extends "res://src/skins/common/tile_painter.gd"
## Gumdrop tile painter (DESIGN_SYSTEM.md 4.7): squircle candy tiles with a
## darker lip underneath, a shine on tier 3 and up, a candy rim on specials,
## and the chained, joinable, press and selected looks.
##
## The lip is the full tile shape in the fill darkened by lip_darken. The face
## sits on top of it, raised by the tier's lip depth, so the lip shows along
## the bottom. Pressing sinks the face (lip_pressed), lifting raises it.
## The chained press_scale and the selected wobble are the tile item's own
## transform, set by the board.

## Corner smoothness of every squircle (DESIGN_SYSTEM.md 1.5: 12 or more).
const CORNER_DETAIL: int = 16
## Points sampled round the candy rim, and along the shine arc.
const RIM_POINTS: int = 192
const SHINE_POINTS: int = 24

var _lip_box: StyleBoxFlat = null
var _face_box: StyleBoxFlat = null
var _slot_box: StyleBoxFlat = null
var _ring_box: StyleBoxFlat = null

## Per label index: lip depth (share of the side), lip color, shine color
## (the shine laid over the fill), and whether the tile has a shine.
var _lips: PackedFloat32Array = PackedFloat32Array()
var _lip_colors: PackedColorArray = PackedColorArray()
var _shine_colors: PackedColorArray = PackedColorArray()
var _has_shine: PackedByteArray = PackedByteArray()
## The tier 1 and 2 fills the candy rim cycles through.
var _rim_colors: PackedColorArray = PackedColorArray()
var _rim_segments: Array[PackedVector2Array] = []
var _rim_face: Vector2 = Vector2.ZERO
var _special_index: int = 0
var _shine_points: PackedVector2Array = PackedVector2Array()
## One color array per shine color and per rim color, made once, so drawing
## never writes to an array the renderer still holds.
var _shine_arrays: Array[PackedColorArray] = []
var _rim_arrays: Array[PackedColorArray] = []

var _radius_share: float = 0.0
var _lip_pressed: float = 0.0
var _joinable_lift: float = 0.0
var _target_lift: float = 0.0
var _shine_inset: float = 0.0
var _shine_width: float = 0.0
var _press_scale: float = 1.0
var _chain_ring: float = 0.0
var _joinable_ring: float = 0.0
var _target_ring: float = 0.0
var _edge_width: float = 0.0
var _rim_width: float = 0.0
var _rim_count: int = 0
var _chain_color: Color = Color.MAGENTA
var _joinable_color: Color = Color.MAGENTA
var _target_color: Color = Color.MAGENTA
var _edge_color: Color = Color.MAGENTA


func _setup() -> void:
	_lip_box = make_box(CORNER_DETAIL)
	_face_box = make_box(CORNER_DETAIL)
	_slot_box = make_box(CORNER_DETAIL)
	_ring_box = make_ring(CORNER_DETAIL)
	_radius_share = skin.num(&"tile_radius")
	_lip_pressed = skin.num(&"lip_pressed")
	_joinable_lift = skin.num(&"joinable_lift")
	_target_lift = skin.num(&"target_lift")
	_shine_inset = skin.num(&"shine_inset")
	_shine_width = skin.num(&"shine_width")
	_press_scale = MotionMath.extra(skin, &"chain_add", "press_scale")
	_chain_ring = skin.num(&"chain_ring")
	_joinable_ring = skin.num(&"joinable_ring")
	_target_ring = skin.num(&"target_ring")
	_edge_width = skin.num(&"target_edge_width")
	_rim_width = skin.num(&"special_rim_width")
	_rim_count = maxi(1, roundi(skin.num(&"special_rim_segments")))
	_chain_color = skin.color(&"chain")
	_joinable_color = skin.color(&"joinable")
	_target_color = skin.color(&"target")
	_edge_color = skin.color(&"target_edge")
	_slot_box.bg_color = skin.color(&"slot")
	var lip_darken: float = skin.num(&"lip_darken")
	var shine: Color = skin.color(&"shine")
	var shine_alpha: float = skin.num(&"shine_alpha")
	var shine_from: int = int(skin.num(&"shine_from_tier"))
	var count: int = fills.size()
	_lips.resize(count)
	_lip_colors.resize(count)
	_shine_colors.resize(count)
	_has_shine.resize(count)
	for index: int in count:
		_lips[index] = skin.num(StringName("lip_t%d" % tiers[index]))
		_lip_colors[index] = fills[index].darkened(lip_darken)
		# The shine sits wholly on the flat face, so laying it over the fill
		# once gives the same color as drawing it at shine_alpha.
		_shine_colors[index] = fills[index].lerp(shine, shine_alpha)
		_has_shine[index] = 1 if tiers[index] >= shine_from else 0
	_rim_colors.clear()
	for index: int in SkinData.RAMP_SIZE:
		if tiers[index] == 1 or tiers[index] == 2:
			_rim_colors.append(fills[index])
	if _rim_colors.is_empty():
		_rim_colors.append(fills[0])
	_shine_arrays.clear()
	for index: int in count:
		_shine_arrays.append(PackedColorArray([_shine_colors[index]]))
	_rim_arrays.clear()
	for rim_color: Color in _rim_colors:
		_rim_arrays.append(PackedColorArray([rim_color]))
	_special_index = maxi(0, index_of(special_from))


func _on_side() -> void:
	var radius: int = roundi(_radius_share * side)
	_lip_box.set_corner_radius_all(radius)
	_face_box.set_corner_radius_all(radius)
	_slot_box.set_corner_radius_all(radius)
	_build_rim(Vector2(side, side * (1.0 - _lips[_special_index])))
	var arc_radius: float = maxf(0.0, _radius_share * side - _shine_inset * side)
	_shine_points = arc_points(arc_radius, PI, PI * 1.5, SHINE_POINTS)


## The chained tile's scale (press_scale), for the tile item's transform.
func chain_scale(chain: float) -> float:
	return lerpf(1.0, _press_scale, chain)


## An empty cell: a flat squircle in slot.
func draw_slot(canvas: RID, rect: Rect2) -> void:
	_slot_box.draw(canvas, rect)


## One tile in tile space, placed by base.
##   chain: 0 to 1, pressed into the chain with the chain ring
##   join: 0 to 1, lifted with the joinable ring (D-40)
##   press: 0 to 1, press feedback in targeting (D-43)
##   select: 0 to 1, Swap's selected tile, lifted with the target ring
func draw_tile(canvas: RID, base: Transform2D, value: int, chain: float, join: float, press: float, select: float) -> void:
	var index: int = index_of(value)
	if index < 0:
		return
	var half: float = side * 0.5
	var lip_full: float = _lips[index] * side
	var pressed: float = maxf(chain, press)
	var lip: float = lerpf(lip_full, _lip_pressed * side, pressed) + (_joinable_lift * join + _target_lift * select) * side
	var face_top: float = -half + lip_full - lip
	var face: Rect2 = Rect2(-half, face_top, side, side - lip_full)
	var body: Rect2 = Rect2(-half, face_top, side, half - face_top)
	var radius: float = _radius_share * side
	begin(canvas, base)
	_lip_box.bg_color = _lip_colors[index]
	_lip_box.draw(canvas, body)
	_face_box.bg_color = fills[index]
	_face_box.draw(canvas, face)
	var outside: float = 0.0
	if value >= special_from:
		_draw_rim(canvas, base, face)
		outside = _rim_width * unit
	if _has_shine[index] != 0:
		_draw_shine(canvas, base, face.position + Vector2(radius, radius), index)
	if chain > 0.0:
		var width: float = _chain_ring * unit
		_ring(canvas, face, radius, outside + width, width, faded(_chain_color, chain))
	if join > 0.0:
		_double_ring(canvas, body, radius, outside, _joinable_ring * unit, _joinable_color, join)
	var target: float = maxf(press, select)
	if target > 0.0:
		_double_ring(canvas, body, radius, outside, _target_ring * unit, _target_color, target)
	labels.draw_centered(canvas, face.get_center(), index, inks[index])
	end(canvas)


## The merge preview: the result as a resting tile with a ring_width ring in
## chain just outside it, lip included, centered on center.
func draw_preview(canvas: RID, center: Vector2, value: int, ring_width: float) -> void:
	if index_of(value) < 0:
		return
	var radius: float = _radius_share * side
	var body: Rect2 = Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side))
	_ring(canvas, body, radius, ring_width, ring_width, _chain_color)
	draw_tile(canvas, at(center), value, 0.0, 0.0, 0.0, 0.0)


func draw_single(canvas: RID, center: Vector2, value: int) -> void:
	draw_tile(canvas, at(center), value, 0.0, 0.0, 0.0, 0.0)


## A ring width px wide whose outer edge sits grow px outside rect, keeping
## the squircle.
func _ring(canvas: RID, rect: Rect2, radius: float, grow: float, width: float, ring_color: Color) -> void:
	_ring_box.set_border_width_all(maxi(1, roundi(width)))
	_ring_box.border_color = ring_color
	_ring_box.set_corner_radius_all(roundi(radius + grow))
	_ring_box.draw(canvas, rect.grow(grow))


## A ring in ring_color with a target_edge outline outside it, both outside
## rect by outside px.
func _double_ring(canvas: RID, rect: Rect2, radius: float, outside: float, width: float, ring_color: Color, alpha: float) -> void:
	var edge: float = _edge_width * unit
	_ring(canvas, rect, radius, outside + width + edge, width + edge, faded(_edge_color, alpha))
	_ring(canvas, rect, radius, outside + width, width, faded(ring_color, alpha))


## The shine: a quarter circle arc with round caps following the face's top
## left corner, centered on the corner's radius center.
func _draw_shine(canvas: RID, base: Transform2D, corner_center: Vector2, index: int) -> void:
	var width: float = _shine_width * side
	if _shine_points.size() < 2 or width <= 0.0:
		return
	var shine: Color = _shine_colors[index]
	begin(canvas, base * at(corner_center))
	RenderingServer.canvas_item_add_polyline(canvas, _shine_points, _shine_arrays[index], width, true)
	RenderingServer.canvas_item_add_circle(canvas, _shine_points[0], width * 0.5, shine, true)
	RenderingServer.canvas_item_add_circle(canvas, _shine_points[_shine_points.size() - 1], width * 0.5, shine, true)
	begin(canvas, base)


## The candy rim round the face, just outside its edge, in segments cycling
## the tier 1 and 2 fills.
func _draw_rim(canvas: RID, base: Transform2D, face: Rect2) -> void:
	if not _rim_face.is_equal_approx(face.size):
		_build_rim(face.size)
	begin(canvas, base * at(face.get_center()))
	var width: float = _rim_width * unit
	for segment: int in _rim_segments.size():
		RenderingServer.canvas_item_add_polyline(canvas, _rim_segments[segment], _rim_arrays[segment % _rim_arrays.size()], width, true)
	begin(canvas, base)


## Splits the rim path round a face of face_size into its colored segments.
@warning_ignore("integer_division")
func _build_rim(face_size: Vector2) -> void:
	_rim_face = face_size
	var rim: float = _rim_width * unit
	var path_size: Vector2 = face_size + Vector2(rim, rim)
	var path_radius: float = minf(_radius_share * side + rim * 0.5, minf(path_size.x, path_size.y) * 0.5)
	var path: PackedVector2Array = _rounded_rect_path(path_size, path_radius, RIM_POINTS)
	_rim_segments.clear()
	for segment: int in _rim_count:
		var first: int = segment * RIM_POINTS / _rim_count
		var last: int = (segment + 1) * RIM_POINTS / _rim_count
		_rim_segments.append(path.slice(first, last + 1))


## Closed path round a rounded rect centered on (0, 0), clockwise from the
## top left, count points plus the first point again at the end.
static func _rounded_rect_path(rect_size: Vector2, radius: float, count: int) -> PackedVector2Array:
	var straight_x: float = maxf(0.0, rect_size.x - 2.0 * radius)
	var straight_y: float = maxf(0.0, rect_size.y - 2.0 * radius)
	var arc: float = PI * 0.5 * radius
	var perimeter: float = 2.0 * straight_x + 2.0 * straight_y + 4.0 * arc
	var half: Vector2 = rect_size * 0.5
	var corners: PackedVector2Array = PackedVector2Array([
		Vector2(half.x - radius, -half.y + radius), Vector2(half.x - radius, half.y - radius),
		Vector2(-half.x + radius, half.y - radius), Vector2(-half.x + radius, -half.y + radius),
	])
	var arc_starts: PackedFloat32Array = PackedFloat32Array([-PI * 0.5, 0.0, PI * 0.5, PI])
	var edge_lengths: PackedFloat32Array = PackedFloat32Array([straight_x, straight_y, straight_x, straight_y])
	var edge_starts: PackedVector2Array = PackedVector2Array([
		Vector2(-half.x + radius, -half.y), Vector2(half.x, -half.y + radius),
		Vector2(half.x - radius, half.y), Vector2(-half.x, half.y - radius),
	])
	var edge_dirs: PackedVector2Array = PackedVector2Array([Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP])
	var points: PackedVector2Array = PackedVector2Array()
	points.resize(count + 1)
	for i: int in count:
		var distance: float = perimeter * float(i) / float(count)
		var point: Vector2 = Vector2.ZERO
		var edge: int = 0
		while edge < 4:
			if distance <= edge_lengths[edge]:
				point = edge_starts[edge] + edge_dirs[edge] * distance
				break
			distance -= edge_lengths[edge]
			if distance <= arc:
				var angle: float = arc_starts[edge] + distance / maxf(radius, 0.001)
				point = corners[edge] + Vector2(cos(angle), sin(angle)) * radius
				break
			distance -= arc
			edge += 1
		points[i] = point
	points[count] = points[0]
	return points
