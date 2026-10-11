extends RefCounted
## Tile number text for one skin at one tile side: the label, its font size,
## width and cap height for every tile value, so drawing a tile does no string
## work beyond the draw call itself.
##
## Labels come from NumberFormat.tile_label (GDD D-31), worked out once for
## every power of two a board can hold. Font and size come from the skin
## (SkinData.font(&"tile") and SkinData.tile_font_size). A label's size is
## measured the first time it is drawn at a side, then kept until the side
## changes.

## Highest label index: 2 to the power MAX_INDEX + 1, the largest tile a
## save may hold (docs/ARCHITECTURE.md section 3, 2^62).
const MAX_INDEX: int = 61
## Size the cap height is measured at, large so rounding does not matter.
const MEASURE_SIZE: int = 400
## Cap height as a share of the font size, used only if measuring fails.
## Roboto and Outfit both sit near this.
const FALLBACK_CAP_RATIO: float = 0.7

static var _labels: PackedStringArray = PackedStringArray()
## Cap ratio per font, measured once.
static var _cap_ratios: Dictionary[int, float] = {}

var font: Font = null
var _skin: SkinData = null
var _sizes: PackedInt32Array = PackedInt32Array()
var _widths: PackedFloat32Array = PackedFloat32Array()
var _cap_ratio: float = FALLBACK_CAP_RATIO
var _side: float = -1.0


func setup(skin: SkinData) -> void:
	_skin = skin
	font = skin.font(&"tile")
	_build_labels()
	_sizes.resize(MAX_INDEX + 1)
	_widths.resize(MAX_INDEX + 1)
	_sizes.fill(0)
	_cap_ratio = _cap_ratio_of(font)
	_side = -1.0


## Sets the tile side (Nova: the orb diameter). Sizes are measured again
## lazily. Returns at once when the side has not changed.
func set_side(side: float) -> void:
	if is_equal_approx(side, _side):
		return
	_side = side
	_sizes.fill(0)


## Index for a tile value: 0 for 2, 1 for 4, and so on. -1 when the value is
## not a power of two of at least 2.
static func index_of(value: int) -> int:
	if value < 2 or (value & (value - 1)) != 0:
		return -1
	var index: int = 0
	var v: int = value
	while v > 2:
		v = v >> 1
		index += 1
	return index if index <= MAX_INDEX else -1


## The tile value for a label index.
static func value_of(index: int) -> int:
	return 2 << index


static func label(index: int) -> String:
	_build_labels()
	return _labels[index]


func font_size(index: int) -> int:
	_measure(index)
	return _sizes[index]


func width(index: int) -> float:
	_measure(index)
	return _widths[index]


## Height of the digits above the baseline, in px.
func cap_height(index: int) -> float:
	_measure(index)
	return float(_sizes[index]) * _cap_ratio


## Draws a label into a canvas item so the middle of its digits sits on
## center.
func draw_centered(canvas: RID, center: Vector2, index: int, ink: Color) -> void:
	_measure(index)
	var baseline: Vector2 = Vector2(center.x - _widths[index] * 0.5, center.y + cap_height(index) * 0.5)
	font.draw_string(canvas, baseline, _labels[index], HORIZONTAL_ALIGNMENT_LEFT, -1.0, _sizes[index], ink)


## Draws a label into a canvas item with the top of its digits at
## top_left.y and its left edge at top_left.x.
func draw_top_left(canvas: RID, top_left: Vector2, index: int, ink: Color) -> void:
	_measure(index)
	var baseline: Vector2 = Vector2(top_left.x, top_left.y + cap_height(index))
	font.draw_string(canvas, baseline, _labels[index], HORIZONTAL_ALIGNMENT_LEFT, -1.0, _sizes[index], ink)


## The box a label drawn with draw_top_left() covers: its width by its cap
## height.
func box_top_left(top_left: Vector2, index: int) -> Rect2:
	_measure(index)
	return Rect2(top_left, Vector2(_widths[index], cap_height(index)))


func _measure(index: int) -> void:
	if _sizes[index] > 0:
		return
	var text: String = _labels[index]
	var size: int = _skin.tile_font_size(maxf(_side, 1.0), text)
	_sizes[index] = size
	_widths[index] = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x


static func _build_labels() -> void:
	if _labels.size() == MAX_INDEX + 1:
		return
	_labels.resize(MAX_INDEX + 1)
	for index: int in MAX_INDEX + 1:
		_labels[index] = NumberFormat.tile_label(value_of(index))


## Cap height of a font as a share of its size, read from the rendered glyph
## of "H". Measured once per font.
static func _cap_ratio_of(text_font: Font) -> float:
	var key: int = text_font.get_instance_id()
	if _cap_ratios.has(key):
		return _cap_ratios[key]
	var ratio: float = _measure_cap_ratio(text_font)
	_cap_ratios[key] = ratio
	return ratio


static func _measure_cap_ratio(text_font: Font) -> float:
	var text_server: TextServer = TextServerManager.get_primary_interface()
	var line: TextLine = TextLine.new()
	if not line.add_string("H", text_font, MEASURE_SIZE):
		return FALLBACK_CAP_RATIO
	var glyphs: Array[Dictionary] = text_server.shaped_text_get_glyphs(line.get_rid())
	if glyphs.is_empty():
		return FALLBACK_CAP_RATIO
	var glyph: Dictionary = glyphs[0]
	var font_rid: RID = glyph.get("font_rid", RID())
	var glyph_index: int = int(glyph.get("index", 0))
	if not font_rid.is_valid():
		return FALLBACK_CAP_RATIO
	var size_key: Vector2i = Vector2i(MEASURE_SIZE, 0)
	text_server.font_render_glyph(font_rid, size_key, glyph_index)
	var glyph_offset: Vector2 = text_server.font_get_glyph_offset(font_rid, size_key, glyph_index)
	var glyph_size: Vector2 = text_server.font_get_glyph_size(font_rid, size_key, glyph_index)
	if glyph_size.y <= 0.0 or glyph_offset.y >= 0.0:
		return FALLBACK_CAP_RATIO
	var ratio: float = -glyph_offset.y / float(MEASURE_SIZE)
	if ratio < 0.5 or ratio > 0.9:
		return FALLBACK_CAP_RATIO
	return ratio
