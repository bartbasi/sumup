extends RefCounted
## Gumdrop's raised candy surface in its three looks, shared by the booster
## buttons, the icon buttons and the HUD. A surface is laid out in a rect
## that holds the face and the lip under it at rest:
##   normal: surface_raised face on a surface_lip lip
##   active: accent face on an accent_lip lip, raised ACTIVE_RAISE higher
##   disabled: disabled_surface, flat with no lip, sitting at the bottom
##
## Phase 1 prototype code. Nothing under tools/ ships with the game.

const DirectionTokens: GDScript = preload("res://tools/directions/shared/direction_tokens.gd")
const ThemeKit: GDScript = preload("res://tools/directions/ui_common/theme_kit.gd")

const LOOK_NORMAL: int = 0
const LOOK_ACTIVE: int = 1
const LOOK_DISABLED: int = 2

## How much higher an active surface stands than a normal one, px.
const ACTIVE_RAISE: float = 6.0 # Proposed token: active_raise


## A new StyleBoxFlat for a look. Build these once and keep them.
static func style(tokens: DirectionTokens, look: int, radius: float) -> StyleBoxFlat:
	var lip: float = tokens.num("button_lip")
	var made: StyleBoxFlat
	match look:
		LOOK_ACTIVE:
			made = ThemeKit.box(tokens.color("accent"), radius)
			made.border_color = tokens.color("accent_lip")
			made.border_width_bottom = roundi(lip + ACTIVE_RAISE)
		LOOK_DISABLED:
			made = ThemeKit.box(tokens.color("disabled_surface"), radius)
		_:
			made = ThemeKit.box(tokens.color("surface_raised"), radius)
			made.border_color = tokens.color("surface_lip")
			made.border_width_bottom = roundi(lip)
	return made


## Where to draw the style for a look, given the rest rect (face and lip).
static func style_rect(rest: Rect2, look: int, lip: float) -> Rect2:
	match look:
		LOOK_ACTIVE:
			return Rect2(rest.position.x, rest.position.y - ACTIVE_RAISE, rest.size.x, rest.size.y + ACTIVE_RAISE)
		LOOK_DISABLED:
			return Rect2(rest.position.x, rest.position.y + lip, rest.size.x, rest.size.y - lip)
	return rest


## The top face for a look, where icons and text sit.
static func face_rect(rest: Rect2, look: int, lip: float) -> Rect2:
	var face: Rect2 = Rect2(rest.position, Vector2(rest.size.x, rest.size.y - lip))
	match look:
		LOOK_ACTIVE:
			face.position.y -= ACTIVE_RAISE
		LOOK_DISABLED:
			face.position.y += lip
	return face
