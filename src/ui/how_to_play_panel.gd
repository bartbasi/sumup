class_name HowToPlayPanel extends "res://src/ui/reading_screen.gd"
## How to play (GDD D-44 and section 21, DESIGN_SYSTEM.md 7.12): a reading
## screen titled "How to play" with the seven sections HP1 to HP7, each title
## and text word for word. HP1, HP2 and HP5 end in an example row, under the
## text after space_m, left aligned on one line, vertically centered:
## - the chain, drawn by the skin's own board view as a one row board, every
##   tile in the chain, no preview and no highlight, sized for 112 px tiles;
## - space_m, the skin's arrow icon (56 px, ink_muted), space_m;
## - the result, the skin's tile view at 112 px, resting.
## Nothing in a row takes input, so a drag on it scrolls. It changes nothing
## in the game and holds no live numbers. Opened only by its button on the
## main menu or in Pause; its close button and Android back return there.

## DESIGN_SYSTEM.md 7.9 fixed component constants.
const EXAMPLE_TILE: float = 112.0
const EXAMPLE_ARROW: float = 56.0

var _content: Array[Dictionary] = []


func setup(skin: SkinData) -> void:
	_content = Copy.how_to_play_sections()
	_frame(skin, Copy.HOW_TO_PLAY)
	for section: Dictionary in _content:
		var column: VBoxContainer = _add_section()
		column.add_child(_heading(String(section["title"])))
		column.add_child(_reading(String(section["text"])))
		var example: PackedInt64Array = section["example"]
		if not example.is_empty():
			column.add_child(UiParts.spacer(skin.num(&"space_m") - skin.num(&"space_xs")))
			column.add_child(_example_row(skin, example, int(section["result"])))
	_quiet(_sections)


## Rebuilds the screen in a new skin, still open.
func apply_skin(skin: SkinData) -> void:
	setup(skin)


## TH21. One Dictionary per section, in order: {"title": String, "text":
## String, "example": PackedInt64Array (the joined tiles, empty for none),
## "result": int (0 for none)}. A copy: changing it changes nothing shown.
func content() -> Array[Dictionary]:
	var copied: Array[Dictionary] = []
	for section: Dictionary in Copy.how_to_play_sections():
		copied.append(section.duplicate(true))
	return copied


## The example rows as built, in section order. For tests.
func example_rows() -> Array[HBoxContainer]:
	var rows: Array[HBoxContainer] = []
	for node: Node in _sections.find_children("Example", "HBoxContainer", true, false):
		rows.append(node as HBoxContainer)
	return rows


func _example_row(skin: SkinData, values: PackedInt64Array, result: int) -> HBoxContainer:
	var row: HBoxContainer = UiParts.hbox(0.0)
	row.name = "Example"
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	var count: int = values.size()
	var board: SkinBoardView = SkinCatalog.make_board_view(skin)
	board.name = "Chain"
	board.setup(skin, count, 1)
	var width: float = _chain_width(skin, count)
	board.custom_minimum_size = Vector2(width, board.preferred_height(width))
	board.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var chain: Array[Vector2i] = []
	for index: int in count:
		chain.append(Vector2i(index, 0))
	row.add_child(board)
	board.set_board(values)
	board.set_chain(chain, Vector2(-1.0, -1.0))
	row.add_child(UiParts.spacer(0.0, skin.num(&"space_m")))
	var arrow: SkinIcon = UiKit.make_icon(skin)
	arrow.name = "Arrow"
	arrow.custom_minimum_size = Vector2(EXAMPLE_ARROW, EXAMPLE_ARROW)
	arrow.size = Vector2(EXAMPLE_ARROW, EXAMPLE_ARROW)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arrow.set_icon(&"arrow")
	arrow.set_color(skin.color(&"ink_muted"))
	row.add_child(arrow)
	row.add_child(UiParts.spacer(0.0, skin.num(&"space_m")))
	var tile: SkinTileView = UiParts.tile(skin, result, EXAMPLE_TILE)
	tile.name = "Result"
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tile)
	return row


## The one row board's width for 112 px tiles (7.12): its tiles, the gaps
## and the tray padding, or for orbs the pitch (the tile over orb_scale).
static func _chain_width(skin: SkinData, count: int) -> float:
	if skin.numbers.has(&"orb_scale"):
		return float(count) * EXAMPLE_TILE / skin.num(&"orb_scale")
	var padding: float = skin.numbers.get(&"board_padding", 0.0)
	return float(count) * EXAMPLE_TILE + float(count - 1) * skin.num(&"board_gap") + 2.0 * padding
