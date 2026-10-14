class_name InfoPanel extends "res://src/ui/reading_screen.gd"
## Info (GDD D-44 and section 21, DESIGN_SYSTEM.md 7.11 and 7.12): a reading
## screen titled "Info" with the sixteen sections IN1 to IN16, each title and
## text word for word, always opened scrolled to the top. Example rows sit
## under the text after space_m, left aligned on one line, vertically centered:
## - a chain row: the chain drawn by the skin's own board view as a one row
##   board, every tile in the chain, no preview and no highlight, sized for
##   112 px tiles; space_m, the arrow icon (56 px, ink_muted), space_m; the
##   result, the skin's tile view at 112 px, resting;
## - a change row (Double's 8 then 16): the tile before as a tile view, the
##   arrow, the tile after, with no board and no chain line.
## A booster section (IN9 to IN13) leads with that booster's icon in an
## icon_hud box, in ink with no face: two columns, the icon on the left
## centered on the heading's first line, space_s, then the heading, text and
## any row on the right.
## Nothing in a row takes input, so a drag on it scrolls. It changes nothing
## in the game and holds no live numbers. Opened only by Info on the splash
## or in Pause; its close button and Android back return there.

## DESIGN_SYSTEM.md 7.9 fixed component constants.
const EXAMPLE_TILE: float = 112.0
const EXAMPLE_ARROW: float = 56.0


func setup(skin: SkinData) -> void:
	_frame(skin, Copy.INFO)
	for section: Dictionary in Copy.info_sections():
		var column: VBoxContainer = _add_section()
		var icon_name: StringName = section["icon"]
		var text_column: VBoxContainer = column
		if icon_name != &"":
			text_column = _icon_columns(skin, column, icon_name)
		text_column.add_child(_heading(String(section["title"])))
		text_column.add_child(_reading(String(section["text"])))
		var example: PackedInt64Array = section["example"]
		if not example.is_empty():
			text_column.add_child(UiParts.spacer(skin.num(&"space_m") - skin.num(&"space_xs")))
			text_column.add_child(_example_row(skin, example, int(section["result"]), section["row"]))
	_quiet(_sections)
	_scroll.scroll_vertical = 0


## Rebuilds the screen in a new skin, still open.
func apply_skin(skin: SkinData) -> void:
	setup(skin)


## TH21. One Dictionary per section IN1 to IN16, in order: {"title": String,
## "text": String, "example": PackedInt64Array (the joined tiles, or the one
## changed tile for a change row; empty for none), "result": int (0 for
## none), "row": &"chain", &"change" or &"", "icon": the booster icon name for
## IN9 to IN13 or &""}. A copy: changing it changes nothing shown.
func content() -> Array[Dictionary]:
	var copied: Array[Dictionary] = []
	for section: Dictionary in Copy.info_sections():
		copied.append(section.duplicate(true))
	return copied


## The example rows as built, in section order. For tests.
func example_rows() -> Array[HBoxContainer]:
	var rows: Array[HBoxContainer] = []
	for node: Node in _sections.find_children("Example", "HBoxContainer", true, false):
		rows.append(node as HBoxContainer)
	return rows


## The booster icons as built, in section order. For tests.
func section_icons() -> Array[SkinIcon]:
	var icons: Array[SkinIcon] = []
	for node: Node in _sections.find_children("BoosterIcon", "", true, false):
		icons.append(node as SkinIcon)
	return icons


## Splits a section into the icon column and the text column (7.12) and
## returns the text column. The icon is centered on the heading's first line:
## whichever of the two is shorter gets a top spacer of half the difference.
func _icon_columns(skin: SkinData, column: VBoxContainer, icon_name: StringName) -> VBoxContainer:
	var columns: HBoxContainer = UiParts.hbox(skin.num(&"space_s"))
	columns.name = "Columns"
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(columns)
	var side: float = skin.num(&"icon_hud")
	var line: float = skin.font(&"heading").get_height(skin.font_size(&"heading"))
	var icon_column: VBoxContainer = UiParts.vbox(0.0)
	icon_column.name = "IconColumn"
	icon_column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	columns.add_child(icon_column)
	if line > side:
		icon_column.add_child(UiParts.spacer(roundf((line - side) * 0.5)))
	var icon: SkinIcon = UiKit.make_icon(skin)
	icon.name = "BoosterIcon"
	icon.custom_minimum_size = Vector2(side, side)
	icon.size = Vector2(side, side)
	icon.set_icon(icon_name)
	icon.set_look(SkinIcon.LOOK_NORMAL)
	icon.set_color(skin.color(&"ink"))
	icon_column.add_child(icon)
	var text_column: VBoxContainer = UiParts.vbox(skin.num(&"space_xs"))
	text_column.name = "TextColumn"
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(text_column)
	if side > line:
		# The spacer's own separation counts toward the drop.
		var drop: float = roundf((side - line) * 0.5)
		text_column.add_theme_constant_override(&"separation", 0)
		var inner: VBoxContainer = UiParts.vbox(skin.num(&"space_xs"))
		inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_column.add_child(UiParts.spacer(drop))
		text_column.add_child(inner)
		return inner
	return text_column


func _example_row(skin: SkinData, values: PackedInt64Array, result: int, kind: StringName) -> HBoxContainer:
	var row: HBoxContainer = UiParts.hbox(0.0)
	row.name = "Example"
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	if kind == &"change":
		var before: SkinTileView = UiParts.tile(skin, values[0], EXAMPLE_TILE)
		before.name = "Before"
		before.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(before)
	else:
		row.add_child(UiParts.chain_board(skin, values, EXAMPLE_TILE))
	row.add_child(UiParts.spacer(0.0, skin.num(&"space_m")))
	row.add_child(UiParts.arrow(skin, EXAMPLE_ARROW))
	row.add_child(UiParts.spacer(0.0, skin.num(&"space_m")))
	var tile: SkinTileView = UiParts.tile(skin, result, EXAMPLE_TILE)
	tile.name = "Result"
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tile)
	return row
