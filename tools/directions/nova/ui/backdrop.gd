extends Control
## Nova backdrop: deep space. A soft round glow of bg_glow in the upper
## middle fades to bg at the edges and the bottom, made once with a
## GradientTexture2D in code, plus star_count star dust dots from a fixed
## seed, 1.5 to 3.5 px across, alpha up to star_alpha_max. Fills the
## control's rect. The stars are placed once per size, never per frame.
##
## Phase 1 prototype code. Nothing under tools/ ships with the game.

const DirectionTokens: GDScript = preload("res://tools/directions/shared/direction_tokens.gd")

## Center of the glow as a share of the rect, and its radius as a share of
## the rect width.
const GLOW_CENTER: Vector2 = Vector2(0.5, 0.26) # Proposed token: backdrop_glow_center
const GLOW_RADIUS: float = 0.95 # Proposed token: backdrop_glow_radius
## Fixed seed for the star dust, so every run and capture looks the same.
const STAR_SEED: int = 20261010 # Proposed token: star_seed
## Star dot diameter range, px, and the faintest star's alpha.
const STAR_MIN: float = 1.5
const STAR_MAX: float = 3.5
const STAR_ALPHA_MIN: float = 0.08 # Proposed token: star_alpha_min

const _TEXTURE_SIZE: int = 256

var _tokens: DirectionTokens = null
var _glow: GradientTexture2D = null
var _bg: Color = Color.BLACK
var _star_points: PackedVector2Array = PackedVector2Array()
var _star_radii: PackedFloat32Array = PackedFloat32Array()
var _star_colors: PackedColorArray = PackedColorArray()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(tokens: DirectionTokens) -> void:
	_tokens = tokens
	_bg = tokens.color("bg")
	var gradient: Gradient = Gradient.new()
	var glow: Color = tokens.color("bg_glow")
	# A smooth falloff, so the glow has no visible edge.
	gradient.offsets = PackedFloat32Array([0.0, 0.3, 0.6, 1.0])
	gradient.colors = PackedColorArray([glow, glow.lerp(_bg, 0.3), glow.lerp(_bg, 0.75), _bg])
	_glow = GradientTexture2D.new()
	_glow.gradient = gradient
	_glow.width = _TEXTURE_SIZE
	_glow.height = _TEXTURE_SIZE
	_glow.fill = GradientTexture2D.FILL_RADIAL
	_glow.fill_from = Vector2(0.5, 0.5)
	_glow.fill_to = Vector2(1.0, 0.5)
	_place_stars()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place_stars()


func _place_stars() -> void:
	if _tokens == null:
		return
	var count: int = int(_tokens.num("star_count"))
	var alpha_max: float = _tokens.num("star_alpha_max")
	var star: Color = _tokens.color("star")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = STAR_SEED
	_star_points.resize(count)
	_star_radii.resize(count)
	_star_colors.resize(count)
	for i: int in count:
		_star_points[i] = Vector2(rng.randf() * size.x, rng.randf() * size.y)
		_star_radii[i] = rng.randf_range(STAR_MIN, STAR_MAX) * 0.5
		_star_colors[i] = Color(star, rng.randf_range(STAR_ALPHA_MIN, alpha_max))
	queue_redraw()


func _draw() -> void:
	if _tokens == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), _bg)
	var radius: float = size.x * GLOW_RADIUS
	var center: Vector2 = size * GLOW_CENTER
	draw_texture_rect(_glow, Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false)
	for i: int in _star_points.size():
		draw_circle(_star_points[i], _star_radii[i], _star_colors[i], true, -1.0, true)
