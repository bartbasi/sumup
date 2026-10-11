extends Control
## The clear notice's content (D-38, AT-104): a mini tile of each cleared
## value with a strike line across it, then the copy, on a badge box. The
## skin's HUD builds it, places it and animates it; this only lays out and
## draws. It never takes input.
##
## Layout, left to right: pad_left, the tiles space_xs apart, space_xs, the
## text, pad_right. The box fills the whole control, so a HUD can stretch it
## (Slate's full width bar); the content keeps its place on the left.

const UiCopy: GDScript = preload("res://src/design/shared/ui_copy.gd")

## The copy shown, cased. For tests and for screens' accessibility.
var text: String = ""

var _skin: SkinData = null
var _box: StyleBox = null
var _font: Font = null
var _font_size: int = 1
var _ink: Color = Color.BLACK
var _tiles: Array[Control] = []
var _strikes: Control = null
var _text_origin: Vector2 = Vector2.ZERO
var _strike_width: float = 1.0
## Strike lines, two points each, in this control's space.
var _strike_points: PackedVector2Array = PackedVector2Array()
## Height of the box's face: the part above any lip.
var _face_height: float = 0.0
var _content_width: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Builds the notice for values (ascending) with the skin's tokens.
##   role: the type role of the copy (body for Gumdrop, label for the others)
##   box: the badge box, drawn over the whole control
##   height: notice_height; lip: the part of it under the face (0 for none)
##   pad_left, pad_right: space before the first tile and after the text
##   max_width: widest the content may be; with too many values to fit, only
##     the lowest and the highest get a tile
func build(skin: SkinData, values: PackedInt64Array, role: StringName, box: StyleBox, height: float, lip: float, pad_left: float, pad_right: float, max_width: float) -> void:
	_skin = skin
	_box = box
	_font = skin.font(role)
	_font_size = skin.font_size(role)
	_ink = skin.color(&"badge_ink")
	_strike_width = skin.num(&"notice_strike")
	_face_height = height - lip
	text = UiCopy.clear_notice(skin, role, values)
	for tile: Control in _tiles:
		remove_child(tile)
		tile.queue_free()
	_tiles.clear()
	if _strikes == null:
		_strikes = Control.new()
		_strikes.name = "Strikes"
		_strikes.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_strikes.draw.connect(_draw_strikes)
		add_child(_strikes)

	var gap: float = skin.num(&"space_xs")
	var side: float = skin.num(&"notice_tile_scale") * height
	var text_width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _font_size).x
	var shown: PackedInt64Array = values
	var fixed: float = pad_left + text_width + pad_right
	if values.size() > 2 and fixed + (side + gap) * float(values.size()) > max_width:
		shown = PackedInt64Array([values[0], values[values.size() - 1]])
	var x: float = pad_left
	var tile_top: float = (_face_height - side) * 0.5
	_strike_points.clear()
	for value: int in shown:
		var tile: Control = _make_tile(skin, value)
		tile.position = Vector2(x, tile_top)
		tile.size = Vector2(side, side)
		add_child(tile)
		_tiles.append(tile)
		# The strike runs corner to corner, bottom left to top right.
		_strike_points.append(Vector2(x, tile_top + side))
		_strike_points.append(Vector2(x + side, tile_top))
		x += side + gap
	move_child(_strikes, get_child_count() - 1)
	var line_height: float = _font.get_height(_font_size)
	_text_origin = Vector2(x, (_face_height - line_height) * 0.5 + _font.get_ascent(_font_size))
	_content_width = x + text_width + pad_right
	size = Vector2(_content_width, height)
	queue_redraw()


## Width the content needs.
func content_width() -> float:
	return _content_width


## The mini tiles, for tests.
func tiles() -> Array[Control]:
	return _tiles


## A mini tile from the skin's own tile view (already set up by the factory).
func _make_tile(skin: SkinData, value: int) -> SkinTileView:
	var tile: SkinTileView = SkinCatalog.make_tile_view(skin)
	tile.set_value(value)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tile


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _strikes != null:
		_strikes.size = size


func _draw() -> void:
	if _skin == null:
		return
	draw_style_box(_box, Rect2(Vector2.ZERO, size))
	# Text pair: badge_ink on badge.
	draw_string(_font, _text_origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _font_size, _ink)


func _draw_strikes() -> void:
	for i: int in range(0, _strike_points.size(), 2):
		_strikes.draw_line(_strike_points[i], _strike_points[i + 1], _ink, _strike_width, true)
