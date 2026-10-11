extends RefCounted
## Base for the per skin tile painters. A painter draws tiles of one skin at
## one tile side into a canvas item; the board view and the tile view both
## draw through it, so a tile looks the same alone and on the board.
##
## Tiles are drawn in tile space: (0, 0) is the tile center, and base places
## that space in the canvas item. On the board every tile has its own canvas
## item and base is the identity: the item's own transform moves, scales and
## turns the tile, so effects never redraw it.
##
## It also owns the skin's board geometry rule (DESIGN_SYSTEM.md 2.3), since
## the tile side the px tokens were drawn for comes from it.
##
## Lengths the skin gives as a share of the tile side scale with the side.
## Lengths it gives in px are for the board tile on the base canvas; they are
## multiplied by unit, which is 1 on that tile and shrinks or grows with it.

const TileLabels: GDScript = preload("res://src/skins/common/tile_labels.gd")
const MotionMath: GDScript = preload("res://src/skins/common/motion_math.gd")

var skin: SkinData = null
var labels: TileLabels = null
## Tile side in px (Nova: the orb diameter), and px per token px.
var side: float = 0.0
var unit: float = 1.0

## Per label index (0 is value 2): fill, number color and tier.
var fills: PackedColorArray = PackedColorArray()
var inks: PackedColorArray = PackedColorArray()
var tiers: PackedInt32Array = PackedInt32Array()
var special_from: int = 0

var _reference_side: float = 0.0


func setup(p_skin: SkinData) -> void:
	skin = p_skin
	labels = TileLabels.new()
	labels.setup(skin)
	var count: int = TileLabels.MAX_INDEX + 1
	fills.resize(count)
	inks.resize(count)
	tiers.resize(count)
	for index: int in count:
		var value: int = TileLabels.value_of(index)
		fills[index] = skin.fill_for(value)
		inks[index] = skin.ink_for(value)
		tiers[index] = skin.tier_for(value)
	special_from = int(skin.num(&"special_from"))
	# The px tokens are drawn for the base canvas width and the game's column
	# count.
	var canvas_width: float = float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var reference_columns: int = GameConfig.new().columns
	_reference_side = board_metrics(canvas_width - 2.0 * skin.num(&"board_margin"), reference_columns).x
	side = 0.0
	_setup()


## Prepares everything that depends on the tile side. Returns at once when
## nothing changed, so callers may call it every draw.
func set_side(p_side: float, p_unit: float) -> void:
	if is_equal_approx(p_side, side) and is_equal_approx(p_unit, unit):
		return
	side = p_side
	unit = p_unit
	labels.set_side(side)
	_on_side()


## The board tile side the px tokens were drawn for: the board on the base
## canvas (DESIGN_SYSTEM.md 2.1), board_margin from each side.
func reference_side() -> float:
	return _reference_side


## Tile side, gap and padding (x, y, z) of a board of this width and column
## count with the skin's own gaps (DESIGN_SYSTEM.md 2.3). Gumdrop and Slate:
## board_gap between tiles and board_padding round them. Nova overrides it.
func board_metrics(width: float, columns: int) -> Vector3:
	var gap: float = skin.num(&"board_gap")
	var pad: float = skin.num(&"board_padding")
	var tile_side: float = (width - 2.0 * pad - float(columns - 1) * gap) / float(maxi(columns, 1))
	return Vector3(tile_side, gap, pad)


## Draws one resting tile centered on center, as the tile view shows it.
func draw_single(_canvas: RID, _center: Vector2, _value: int) -> void:
	push_error("tile painter does not implement draw_single()")


## Label index of a value, -1 when it is not a tile value.
static func index_of(value: int) -> int:
	return TileLabels.index_of(value)


## Places tile space in a canvas item with base.
static func begin(canvas: RID, base: Transform2D) -> void:
	RenderingServer.canvas_item_add_set_transform(canvas, base)


static func end(canvas: RID) -> void:
	RenderingServer.canvas_item_add_set_transform(canvas, Transform2D.IDENTITY)


## Tile space centered on a point.
static func at(center: Vector2) -> Transform2D:
	return Transform2D(0.0, center)


static func faded(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * alpha)


func _setup() -> void:
	pass


func _on_side() -> void:
	pass


static func make_box(corner_detail: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.anti_aliasing = true
	box.corner_detail = corner_detail
	return box


static func make_ring(corner_detail: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = make_box(corner_detail)
	box.draw_center = false
	return box


## Points round an arc of a circle centered on (0, 0), from one angle to
## another, for a polyline. Made once per size.
static func arc_points(radius: float, from_angle: float, to_angle: float, count: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	points.resize(count + 1)
	for i: int in count + 1:
		var angle: float = lerpf(from_angle, to_angle, float(i) / float(count))
		points[i] = Vector2(cos(angle), sin(angle)) * radius
	return points
