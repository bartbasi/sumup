extends RefCounted
## Small builders the screens and panels share. Every color, size and font
## comes from the Theme's type variations (docs/ARCHITECTURE.md section 7) or
## from SkinData tokens; nothing here holds a value of its own.
##
## A Theme cannot set text case or alignment, so the builders case text with
## the skin's rule for the variation's type role, and the two Slate rules of
## the contract live here: SignalLabel takes the label role in Slate (the title
## role elsewhere), and Slate left aligns the text of every button but a chip,
## and its text blocks (DESIGN_SYSTEM.md 5.7 and 7, Alignment).

## The type role behind each variation the screens use.
const ROLES: Dictionary[StringName, StringName] = {
	&"DisplayLabel": &"display",
	&"TitleLabel": &"title",
	&"BodyLabel": &"body",
	&"MutedLabel": &"body",
	&"CaptionLabel": &"label",
	&"BadgeLabel": &"label",
	&"HintLabel": &"label",
	&"PrimaryButton": &"body",
	&"SecondaryButton": &"body",
	&"ChipButton": &"body",
	&"HeadingLabel": &"heading",
	&"ReadingLabel": &"reading",
	&"RowDetailLabel": &"label",
}

const _LEFT_ALIGNED_SKIN: StringName = &"slate"
const _FREE_SECTIONS_SKIN: StringName = &"nova"
const _CASE_UPPER: String = "upper"
## DESIGN_SYSTEM.md 7.2: the wordmark, "Sum" in ink and "Up" in accent.
const WORDMARK_PARTS: Array[String] = ["Sum", "Up"]
const _WORDMARK_COLORS: Array[StringName] = [&"ink", &"accent"]


## The type role of a variation in this skin.
static func role(skin: SkinData, variation: StringName) -> StringName:
	if variation == &"SignalLabel":
		return &"label" if skin.id == _LEFT_ALIGNED_SKIN else &"title"
	return ROLES.get(variation, &"body")


## True for the skin that left aligns (Slate).
static func align_start(skin: SkinData) -> bool:
	return skin.id == _LEFT_ALIGNED_SKIN


## Centered, or left for Slate.
static func block_alignment(skin: SkinData) -> HorizontalAlignment:
	return HORIZONTAL_ALIGNMENT_LEFT if align_start(skin) else HORIZONTAL_ALIGNMENT_CENTER


## True for the skin that rules its screens with hairlines (Slate): under the
## reading screen header, and between reading screen sections with no gap
## (DESIGN_SYSTEM.md 7.11).
static func ruled(skin: SkinData) -> bool:
	return skin.id == _LEFT_ALIGNED_SKIN


## The gap between reading screen sections (DESIGN_SYSTEM.md 7.11): Gumdrop's
## cards space_s apart, Slate's ruled sections none, Nova's space_l apart.
static func section_gap(skin: SkinData) -> float:
	if ruled(skin):
		return 0.0
	return skin.num(&"space_l") if floats_free(skin) else skin.num(&"space_s")


## True for the skin whose reading screen sections stand free on the
## backdrop with no box and no rule (Nova).
static func floats_free(skin: SkinData) -> bool:
	return skin.id == _FREE_SECTIONS_SKIN


## A label in a variation, its text cased for the variation's role.
static func label(skin: SkinData, variation: StringName, text: String, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var made: Label = Label.new()
	made.theme_type_variation = variation
	made.text = skin.cased(role(skin, variation), text)
	made.horizontal_alignment = align
	made.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return made


## A label that wraps to the width it is given.
static func paragraph(skin: SkinData, variation: StringName, text: String, align: HorizontalAlignment) -> Label:
	var made: Label = label(skin, variation, text, align)
	made.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	made.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return made


## A label for a name in a role whose rule may be lowercase (DESIGN_SYSTEM.md
## 3.4: names keep their capitals). Capitals may apply; any other rule leaves
## the text as written.
static func name_label(skin: SkinData, variation: StringName, text: String) -> Label:
	var made: Label = label(skin, variation, text)
	made.text = text.to_upper() if case_rule(skin, role(skin, variation)) == _CASE_UPPER else text
	return made


## The case rule of a type role: "none", "upper" or "lower".
static func case_rule(skin: SkinData, type_role: StringName) -> String:
	if not skin.type_roles.has(type_role):
		return ""
	return String(skin.type_roles[type_role].get("case", ""))


## The two tone wordmark "SumUp" (DESIGN_SYSTEM.md 7.2): "Sum" in ink and
## "Up" in accent, two labels in the display role with no gap, never cased.
## font_px 0 keeps the display role's size.
static func wordmark(skin: SkinData, font_px: int, start: bool) -> HBoxContainer:
	var row: HBoxContainer = hbox(0.0)
	row.name = "Wordmark"
	row.alignment = BoxContainer.ALIGNMENT_BEGIN if start else BoxContainer.ALIGNMENT_CENTER
	for index: int in WORDMARK_PARTS.size():
		var part: Label = Label.new()
		part.theme_type_variation = &"DisplayLabel"
		part.text = WORDMARK_PARTS[index]
		part.mouse_filter = Control.MOUSE_FILTER_IGNORE
		part.add_theme_color_override(&"font_color", skin.color(_WORDMARK_COLORS[index]))
		if font_px > 0:
			part.add_theme_font_size_override(&"font_size", font_px)
		row.add_child(part)
	return row


## The menu wordmark's size: its advance width equals width. floor(display
## size x width / the width at the display size), then 1 px smaller until it
## fits, never below the display size (DESIGN_SYSTEM.md 7.2).
static func fitted_wordmark_size(skin: SkinData, width: float) -> int:
	var display: Font = skin.font(&"display")
	var base: int = skin.font_size(&"display")
	var at_base: float = wordmark_width(display, base)
	if at_base <= 0.0:
		return base
	var fitted: int = floori(float(base) * width / at_base)
	while fitted > base and wordmark_width(display, fitted) > width:
		fitted -= 1
	return maxi(base, fitted)


## The wordmark's advance width at font_px: its two parts side by side.
static func wordmark_width(display: Font, font_px: int) -> float:
	var total: float = 0.0
	for part: String in WORDMARK_PARTS:
		total += display.get_string_size(part, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_px).x
	return total


## An empty Control height px tall (and width px wide).
static func spacer(height: float, width: float = 0.0) -> Control:
	var gap: Control = Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.custom_minimum_size = Vector2(width, height)
	return gap


## A button in a variation. In Slate every button but a chip left aligns its
## text (DESIGN_SYSTEM.md 7, Alignment).
static func button(skin: SkinData, variation: StringName, text: String) -> Button:
	var made: Button = Button.new()
	made.theme_type_variation = variation
	made.text = skin.cased(role(skin, variation), text)
	made.focus_mode = Control.FOCUS_NONE
	made.custom_minimum_size = Vector2(0.0, skin.num(&"button_height"))
	if variation != &"ChipButton" and align_start(skin):
		made.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return made


## A touch_min square button with the skin's icon on its face, emitting
## pressed.
static func icon_button(skin: SkinData, icon_name: StringName) -> BaseButton:
	return UiKit.make_icon_button(skin, icon_name)


## The width of an icon button's visible face: Gumdrop's raised face
## (hud_button_face), Nova's ring (hud_ring), or Slate's bare icon (icon_hud).
static func icon_face(skin: SkinData) -> float:
	for token: StringName in [&"hud_button_face", &"hud_ring"]:
		if skin.numbers.has(token):
			return skin.numbers[token]
	return skin.num(&"icon_hud")


## How far an icon button's touch box sits from the screen side, so its
## visible face lines up with board_margin as the HUD's buttons do.
static func icon_button_inset(skin: SkinData) -> float:
	return maxf(0.0, skin.num(&"board_margin") - (skin.num(&"touch_min") - icon_face(skin)) * 0.5)


## One tile drawn by the skin's own tile component, side px square.
static func tile(skin: SkinData, value: int, side: float) -> SkinTileView:
	var view: SkinTileView = SkinCatalog.make_tile_view(skin)
	view.custom_minimum_size = Vector2(side, side)
	view.size = Vector2(side, side)
	view.set_value(value)
	return view


## A badge pill (DESIGN_SYSTEM.md 7.8): "New best", for example.
static func badge(skin: SkinData, text: String) -> PanelContainer:
	var pill: PanelContainer = PanelContainer.new()
	pill.theme_type_variation = &"BadgePanel"
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(label(skin, &"BadgeLabel", text))
	return pill


## The skin's divider.
static func divider() -> HSeparator:
	var line: HSeparator = HSeparator.new()
	line.theme_type_variation = &"Hairline"
	return line


static func vbox(separation: float) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", roundi(separation))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box


static func hbox(separation: float) -> HBoxContainer:
	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override(&"separation", roundi(separation))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box


## A row with a caption on the left and value on the right, row_height tall.
static func record_row(skin: SkinData, caption: String, value: Control) -> HBoxContainer:
	var row: HBoxContainer = hbox(skin.num(&"space_s"))
	row.custom_minimum_size = Vector2(0.0, skin.num(&"row_height"))
	var name_label: Label = label(skin, &"CaptionLabel", caption)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(value)
	return row


## True when the skin's dialog panel is a floating card (rounded bottom
## corners, Gumdrop), false when it is a sheet that runs to the screen edges
## (Slate, Nova). DESIGN_SYSTEM.md section 7. context must be in the tree.
static func panel_floats(context: Control) -> bool:
	var style: StyleBoxFlat = context.get_theme_stylebox(&"panel", &"CardPanel") as StyleBoxFlat
	return style != null and style.corner_radius_bottom_left > 0


## The fill of the skin's dialog panel. context must be in the tree.
static func panel_fill(context: Control, skin: SkinData) -> Color:
	var style: StyleBoxFlat = context.get_theme_stylebox(&"panel", &"CardPanel") as StyleBoxFlat
	return style.bg_color if style != null else skin.color(&"surface")


## Frees every child of node now, so a rebuild starts empty.
static func clear(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()
