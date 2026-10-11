extends RefCounted
## Shared helpers for the three theme builders. They only save typing; every
## color, size and font comes from the skin passed in.

## Every type variation each skin's Theme defines, with its base type:
## docs/ARCHITECTURE.md section 7, then the ones DESIGN_SYSTEM.md adds
## (IconButton for the settings and close icon buttons of 7.2 and 7.7,
## BadgePanel and BadgeLabel for the badges of 7.8, SignalLabel for Slate's
## accent signal label of 7.5 and 7.6, HintLabel for text in a HintPanel).
const VARIATIONS: Dictionary[StringName, StringName] = {
	&"DisplayLabel": &"Label",
	&"TitleLabel": &"Label",
	&"BodyLabel": &"Label",
	&"MutedLabel": &"Label",
	&"CaptionLabel": &"Label",
	&"PrimaryButton": &"Button",
	&"SecondaryButton": &"Button",
	&"ChipButton": &"Button",
	&"CardPanel": &"PanelContainer",
	&"PillPanel": &"PanelContainer",
	&"HintPanel": &"PanelContainer",
	&"Hairline": &"HSeparator",
	&"IconButton": &"Button",
	&"BadgePanel": &"PanelContainer",
	&"BadgeLabel": &"Label",
	&"SignalLabel": &"Label",
	&"HintLabel": &"Label",
}

## The style names every button type defines. Hover matches normal and
## hover_pressed matches pressed: this is a touch game.
const BUTTON_STYLES: Array[StringName] = [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus"]

## Corner smoothness for every rounded box (DESIGN_SYSTEM.md 1.5).
const CORNER_DETAIL: int = 12


## A new Theme with the default font, every variation registered on its base
## type, and plain Label, PanelContainer and HSeparator defaults.
static func new_theme(skin: SkinData) -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font = skin.font(&"body")
	theme.default_font_size = skin.font_size(&"body")
	for type_name: StringName in VARIATIONS:
		theme.add_type(type_name)
		theme.set_type_variation(type_name, VARIATIONS[type_name])
	label_type(theme, &"Label", skin, &"body", skin.color(&"ink"))
	theme.set_stylebox(&"panel", &"PanelContainer", StyleBoxEmpty.new())
	return theme


## A flat, antialiased box.
static func box(fill: Color, radius: float) -> StyleBoxFlat:
	var made: StyleBoxFlat = StyleBoxFlat.new()
	made.bg_color = fill
	made.set_corner_radius_all(roundi(radius))
	made.corner_detail = CORNER_DETAIL
	made.anti_aliasing = true
	return made


## An outline only box.
static func outline(color: Color, width: float, radius: float) -> StyleBoxFlat:
	var made: StyleBoxFlat = box(Color(color, 0.0), radius)
	made.draw_center = false
	made.border_color = color
	made.set_border_width_all(roundi(width))
	return made


## An outline width wide, gap outside the box it surrounds. inset moves it in
## when the drawn shape is smaller than the control (IconButton).
static func focus_ring(color: Color, width: float, radius: float, gap: float, inset: Vector4 = Vector4.ZERO) -> StyleBoxFlat:
	var made: StyleBoxFlat = outline(color, width, radius + gap + width)
	made.expand_margin_left = gap + width - inset.x
	made.expand_margin_top = gap + width - inset.y
	made.expand_margin_right = gap + width - inset.z
	made.expand_margin_bottom = gap + width - inset.w
	return made


## Sets all four content margins.
static func pad(target: StyleBox, left: float, top: float, right: float, bottom: float) -> void:
	target.content_margin_left = left
	target.content_margin_top = top
	target.content_margin_right = right
	target.content_margin_bottom = bottom


## A Label type in a role's font and size, in color.
static func label_type(theme: Theme, type_name: StringName, skin: SkinData, role: StringName, color: Color) -> void:
	theme.set_font(&"font", type_name, skin.font(role))
	theme.set_font_size(&"font_size", type_name, skin.font_size(role))
	theme.set_color(&"font_color", type_name, color)


## A Button type: its styles (keyed by BUTTON_STYLES), the body font, and the
## text colors for normal, pressed and disabled.
static func button_type(theme: Theme, type_name: StringName, styles: Dictionary[StringName, StyleBox], skin: SkinData, ink: Color, pressed_ink: Color, disabled_ink: Color) -> void:
	for style_name: StringName in BUTTON_STYLES:
		theme.set_stylebox(style_name, type_name, styles[style_name])
	theme.set_font(&"font", type_name, skin.font(&"body"))
	theme.set_font_size(&"font_size", type_name, skin.font_size(&"body"))
	theme.set_color(&"font_color", type_name, ink)
	theme.set_color(&"font_hover_color", type_name, ink)
	theme.set_color(&"font_focus_color", type_name, ink)
	theme.set_color(&"font_pressed_color", type_name, pressed_ink)
	theme.set_color(&"font_hover_pressed_color", type_name, pressed_ink)
	theme.set_color(&"font_disabled_color", type_name, disabled_ink)


## The style dictionary button_type wants, from the four distinct looks.
static func styles(normal: StyleBox, pressed: StyleBox, disabled: StyleBox, focus: StyleBox) -> Dictionary[StringName, StyleBox]:
	return {
		&"normal": normal,
		&"hover": normal,
		&"pressed": pressed,
		&"hover_pressed": pressed,
		&"disabled": disabled,
		&"focus": focus,
	}


## A divider: a line thick px tall in color, drawn by an HSeparator type.
## A separator draws its style at the style's minimum height, so the content
## margins set the line's thickness.
static func divider(theme: Theme, type_name: StringName, color: Color, thick: float, rounded: bool) -> void:
	var line: StyleBoxFlat = box(color, thick * 0.5 if rounded else 0.0)
	pad(line, 0.0, thick * 0.5, 0.0, thick * 0.5)
	theme.set_stylebox(&"separator", type_name, line)
	theme.set_constant(&"separation", type_name, roundi(thick))


## Height in px of one line of text in a type role.
static func line_height(skin: SkinData, role: StringName) -> float:
	return skin.font(role).get_height(skin.font_size(role))
