extends Control
## One flying star of the star moment (DESIGN_SYSTEM.md 3.6, 4.7, 6.7): the
## skin's filled star icon in one color, with an optional soft glow behind it
## (Nova's spark). Its size is the star's box; the HUD that owns it moves,
## scales and fades it, centered on a point. It ignores the mouse.

const Glow: GDScript = preload("res://src/design/shared/glow.gd")

var _icon: SkinIcon = null
var _glow_color: Color = Color.TRANSPARENT
var _glow_reach: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## glow_reach: the glow's radius as a share of side; 0 for no glow.
func setup(skin: SkinData, color: Color, side: float, glow_color: Color, glow_reach: float) -> void:
	size = Vector2(side, side)
	pivot_offset = size * 0.5
	_glow_color = glow_color
	_glow_reach = glow_reach
	if _icon == null:
		_icon = UiKit.make_icon(skin)
		_icon.name = "Star"
		add_child(_icon)
		_icon.set_icon(&"star")
	_icon.set_color(color)
	_icon.position = Vector2.ZERO
	_icon.size = size
	queue_redraw()


## Centers the star on point, in its parent's space, at a scale.
func show_at(point: Vector2, at_scale: float, alpha: float) -> void:
	visible = alpha > 0.0
	position = point - size * 0.5
	scale = Vector2(at_scale, at_scale)
	modulate.a = alpha


func _draw() -> void:
	if _glow_reach > 0.0 and _glow_color.a > 0.0:
		Glow.draw(self, size * 0.5, minf(size.x, size.y) * _glow_reach, _glow_color)
