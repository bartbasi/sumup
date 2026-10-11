extends "res://tests/base_test.gd"
## The production board and tile views of every skin behave as
## docs/ARCHITECTURE.md section 6 and docs/DESIGN_SYSTEM.md sections 2 to 6
## say: the factories, the geometry, every setter at its edges, and every
## effect's length from the skin's motion tokens.
##
## Drawing itself is proven by the review captures in scenes/skins/, which
## the capture tool fails on any error.

const CommonBoardView: GDScript = preload("res://src/skins/common/common_board_view.gd")
const MotionMath: GDScript = preload("res://src/skins/common/motion_math.gd")
const SLATE_PAINTER: GDScript = preload("res://src/skins/slate/slate_tile_painter.gd")
const NOVA_PAINTER: GDScript = preload("res://src/skins/nova/nova_tile_painter.gd")
const BOARD_VIEWS: Dictionary = {
	&"gumdrop": preload("res://src/skins/gumdrop/gumdrop_board_view.gd"),
	&"slate": preload("res://src/skins/slate/slate_board_view.gd"),
	&"nova": preload("res://src/skins/nova/nova_board_view.gd"),
}
const TILE_VIEWS: Dictionary = {
	&"gumdrop": preload("res://src/skins/gumdrop/gumdrop_tile_view.gd"),
	&"slate": preload("res://src/skins/slate/slate_tile_view.gd"),
	&"nova": preload("res://src/skins/nova/nova_tile_view.gd"),
}
const COLUMNS: int = 5
const ROWS: int = 8
const NO_CELL: Vector2i = Vector2i(-1, -1)
const NO_DRAG: Vector2 = Vector2(-1.0, -1.0)
## The highest power of two the label rule keeps to 4 characters, and the
## highest a save can hold.
const HIGHEST_SHORT_POWER: int = 49
const HIGHEST_POWER: int = 62
const EPSILON: float = 0.001
## Whether the skin's merge_pop is a decorative tail that does not count in
## the merge's length (DESIGN_SYSTEM.md 6.6: Nova's bloom never blocks input).
const POP_IS_TAIL: Dictionary = {&"gumdrop": false, &"slate": false, &"nova": true}

var _nodes: Array[Node] = []


func after_each() -> void:
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


# Factories.

func test_make_board_view_returns_each_skins_view() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var view: SkinBoardView = SkinCatalog.make_board_view(SkinCatalog.get_skin(skin_id))
		_nodes.append(view)
		assert_true(view != null, "%s board view" % skin_id)
		assert_true(view is SkinBoardView, "%s board view is a SkinBoardView" % skin_id)
		assert_eq(view.get_script(), BOARD_VIEWS[skin_id], "%s board view script" % skin_id)


func test_make_tile_view_returns_each_skins_view_set_up() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var view: SkinTileView = SkinCatalog.make_tile_view(SkinCatalog.get_skin(skin_id))
		_nodes.append(view)
		assert_true(view != null, "%s tile view" % skin_id)
		assert_true(view is SkinTileView, "%s tile view is a SkinTileView" % skin_id)
		assert_eq(view.get_script(), TILE_VIEWS[skin_id], "%s tile view script" % skin_id)


func test_an_unknown_skin_id_gets_the_default_views() -> void:
	var other: SkinData = SkinCatalog.get_skin(SkinCatalog.DEFAULT_ID).duplicate() as SkinData
	other.id = &"no_such_skin"
	var board: SkinBoardView = SkinCatalog.make_board_view(other)
	var tile: SkinTileView = SkinCatalog.make_tile_view(other)
	_nodes.append(board)
	_nodes.append(tile)
	assert_eq(board.get_script(), BOARD_VIEWS[SkinCatalog.DEFAULT_ID], "default board view")
	assert_eq(tile.get_script(), TILE_VIEWS[SkinCatalog.DEFAULT_ID], "default tile view")


func test_views_never_take_input() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var board: CommonBoardView = _board(skin_id)
		var tile: SkinTileView = _tile(skin_id)
		assert_eq(board.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s board view ignores the mouse" % skin_id)
		assert_eq(tile.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s tile view ignores the mouse" % skin_id)
		for child: Node in board.get_children():
			assert_eq((child as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s board layers ignore the mouse" % skin_id)


# Board contents.

func test_setup_and_set_board_with_mixed_values_raise_no_errors() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var board: CommonBoardView = _board(skin_id)
		var cells: PackedInt64Array = _mixed_cells(HIGHEST_SHORT_POWER)
		board.set_board(cells)
		for index: int in cells.size():
			assert_eq(board.value_at(_cell(index)), cells[index], "%s cell %d" % [skin_id, index])
		board.set_board(_mixed_cells(HIGHEST_POWER))
		assert_eq(board.value_at(Vector2i(4, 7)), _mixed_cells(HIGHEST_POWER)[39], "%s up to 2^62" % skin_id)
		assert_false(board.has_running_effects(), "%s a set board is at rest" % skin_id)


func test_set_board_keeps_its_own_copy() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var board: CommonBoardView = _board(skin_id)
		var cells: PackedInt64Array = _filled(8)
		board.set_board(cells)
		cells[0] = 1024
		assert_eq(board.value_at(Vector2i(0, 0)), 8, "%s the board is not changed through the caller's array" % skin_id)
		var spawned: Array[Vector2i] = [Vector2i(1, 0)]
		board.play_spawn(spawned, PackedInt64Array([4]))
		assert_eq(cells[1], 8, "%s an effect does not change the caller's array" % skin_id)


func test_set_board_ends_every_effect_at_once() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var board: CommonBoardView = _board(skin_id)
		board.set_board(_filled(8))
		var cleared: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 1)]
		board.play_clear(cleared)
		var from: Array[Vector2i] = [Vector2i(2, 0)]
		var to: Array[Vector2i] = [Vector2i(2, 3)]
		board.play_fall(from, to)
		assert_true(board.has_running_effects(), "%s effects run" % skin_id)
		var after: PackedInt64Array = _filled(16)
		board.set_board(after)
		assert_false(board.has_running_effects(), "%s set_board ends them" % skin_id)
		for index: int in after.size():
			assert_eq(board.value_at(_cell(index)), 16, "%s cell %d shows the new board" % [skin_id, index])


# Geometry.

func test_cell_rect_grid_origin_and_pitch_agree_and_fit_the_preferred_height() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var skin: SkinData = SkinCatalog.get_skin(skin_id)
		for width: float in [_board_width(skin), 1000.0, 600.0, 1262.0]:
			var board: CommonBoardView = _board(skin_id)
			var height: float = board.preferred_height(width)
			board.size = Vector2(width, height)
			_check_geometry(board, "%s at %.0f px" % [skin_id, width])
			var first: Rect2 = board.cell_rect(Vector2i(0, 0))
			var last: Rect2 = board.cell_rect(Vector2i(COLUMNS - 1, ROWS - 1))
			assert_near(first.position.x, width - last.end.x, EPSILON, "%s at %.0f px is centered across" % [skin_id, width])
			assert_near(first.position.y, height - last.end.y, EPSILON, "%s at %.0f px fills its preferred height" % [skin_id, width])


func test_preferred_height_follows_the_design_system_formula() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var skin: SkinData = SkinCatalog.get_skin(skin_id)
		var board: CommonBoardView = _board(skin_id)
		var width: float = _board_width(skin)
		var expected: float = 0.0
		if skin_id == &"nova":
			# 8 x pitch, the pitch being the width over 5 (DESIGN_SYSTEM.md 2.3).
			expected = float(ROWS) * width / float(COLUMNS)
			assert_near(board.tile_side(), width / float(COLUMNS) * skin.num(&"orb_scale"), EPSILON, "nova orb is orb_scale of the pitch")
		else:
			var gap: float = skin.num(&"board_gap")
			var pad: float = skin.num(&"board_padding")
			var side: float = (width - float(COLUMNS - 1) * gap - 2.0 * pad) / float(COLUMNS)
			expected = float(ROWS) * side + float(ROWS - 1) * gap + 2.0 * pad
			assert_near(board.tile_side(), side, EPSILON, "%s tile side" % skin_id)
		assert_near(board.preferred_height(width), expected, EPSILON, "%s preferred height" % skin_id)


func test_a_rect_too_short_shrinks_the_board_evenly_and_centers_it() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var board: CommonBoardView = _board(skin_id)
		var width: float = _board_width(SkinCatalog.get_skin(skin_id))
		var full: float = board.preferred_height(width)
		var full_side: float = board.tile_side()
		var full_pitch: float = board.cell_pitch().x
		board.size = Vector2(width, full * 0.75)
		_check_geometry(board, "%s shrunk" % skin_id)
		assert_near(board.tile_side(), full_side * 0.75, EPSILON, "%s tiles shrink evenly" % skin_id)
		assert_near(board.cell_pitch().x, full_pitch * 0.75, EPSILON, "%s gaps shrink with them" % skin_id)
		var first: Rect2 = board.cell_rect(Vector2i(0, 0))
		var last: Rect2 = board.cell_rect(Vector2i(COLUMNS - 1, ROWS - 1))
		assert_near(first.position.x, width - last.end.x, EPSILON, "%s stays centered" % skin_id)


func test_preferred_height_of_nothing_is_nothing() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var board: CommonBoardView = _board(skin_id)
		assert_eq(board.preferred_height(0.0), 0.0, "%s zero width" % skin_id)


# Setters at their edges.

func test_set_chain_accepts_its_edge_values() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var board: CommonBoardView = _board(skin_id)
		board.set_board(_filled(2))
		var empty: Array[Vector2i] = []
		board.set_chain(empty, NO_DRAG)
		var one: Array[Vector2i] = [Vector2i(0, 0)]
		board.set_chain(one, NO_DRAG)
		var whole: Array[Vector2i] = []
		for index: int in COLUMNS * ROWS:
			whole.append(_cell(index))
		board.set_chain(whole, Vector2(-500.0, 99999.0))
		board.advance_effects(SkinCatalog.get_skin(skin_id).duration(&"chain_add"))
		var outside: Array[Vector2i] = [Vector2i(-3, 0), Vector2i(COLUMNS, ROWS), Vector2i(1, 1)]
		board.set_chain(outside, Vector2.ZERO)
		board.set_chain(empty, NO_DRAG)
		assert_false(board.has_running_effects(), "%s the chain is a look, not an effect" % skin_id)


func test_the_line_runs_to_the_finger_in_local_pixels_where_the_skin_has_a_tail() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var board: CommonBoardView = _board(skin_id)
		board.set_board(_filled(2))
		var chain: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 1)]
		var finger: Vector2 = Vector2(123.0, 456.0)
		board.set_chain(chain, finger)
		var count: int = board._build_line_points()
		if skin_id == &"slate":
			# Slate draws no tail toward the finger (DESIGN_SYSTEM.md 5.7).
			assert_eq(count, 2, "slate line ends at the last node")
		else:
			assert_eq(count, 3, "%s line runs on to the finger" % skin_id)
			assert_eq(board._line_points[2], finger, "%s the tail ends at the finger" % skin_id)
		assert_eq(board._line_points[0], board.cell_center(Vector2i(0, 0)), "%s line starts on the first tile" % skin_id)
		board.set_chain(chain, NO_DRAG)
		assert_eq(board._build_line_points(), 2, "%s no finger, no tail" % skin_id)


func test_the_preview_sits_on_the_gap_crossing() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var board: CommonBoardView = _board(skin_id)
		board.set_board(_filled(2))
		var origin: Vector2 = board.grid_origin()
		var pitch: Vector2 = board.cell_pitch()
		var chain: Array[Vector2i] = [Vector2i(3, 4), Vector2i(2, 3)]
		board.set_chain(chain, NO_DRAG)
		board.set_preview(4)
		assert_eq(board._preview_center(), origin + Vector2(2.0, 3.0) * pitch, "%s top left crossing" % skin_id)
		var left: Array[Vector2i] = [Vector2i(1, 5), Vector2i(0, 5)]
		board.set_chain(left, NO_DRAG)
		assert_eq(board._preview_center(), origin + Vector2(1.0, 5.0) * pitch, "%s top right crossing in column 0" % skin_id)


func test_set_preview_accepts_its_edge_values() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var board: CommonBoardView = _board(skin_id)
		board.set_board(_filled(2))
		var chain: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
		board.set_chain(chain, NO_DRAG)
		for value: int in [0, 2, 1 << HIGHEST_SHORT_POWER, 1 << HIGHEST_POWER, 0]:
			board.set_preview(value)
		board.set_preview(-8)
		assert_false(board._show_preview(), "%s a value below 1 hides the preview" % skin_id)


func test_joinable_highlight_is_never_on_a_chained_tile() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var board: CommonBoardView = _board(skin_id)
		board.set_board(_filled(2))
		var chain: Array[Vector2i] = [Vector2i(0, 0)]
		board.set_chain(chain, NO_DRAG)
		var joinable: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(9, 9)]
		board.set_joinable(joinable)
		assert_false(board._join_fade.is_on(0), "%s the chained tile is not highlighted" % skin_id)
		assert_true(board._join_fade.is_on(1), "%s the joinable tile is" % skin_id)
		var none: Array[Vector2i] = []
		board.set_joinable(none)
		assert_false(board._join_fade.is_on(1), "%s an empty set clears it" % skin_id)
		var all_cells: Array[Vector2i] = []
		for index: int in COLUMNS * ROWS:
			all_cells.append(_cell(index))
		board.set_joinable(all_cells)
		board.advance_effects(SkinCatalog.get_skin(skin_id).duration(&"joinable_in"))
		assert_near(board._join_fade.value[COLUMNS * ROWS - 1], 1.0, EPSILON, "%s eases fully in over joinable_in" % skin_id)


func test_targeting_press_and_swap_selection_accept_their_edge_values() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var board: CommonBoardView = _board(skin_id)
		board.set_board(_filled(4))
		for booster_id: StringName in [&"hammer", &"swap", &"double", &"shuffle", &"undo", &""]:
			board.set_targeting(booster_id)
		board.set_targeting(&"swap")
		for cell: Vector2i in [Vector2i(0, 0), Vector2i(COLUMNS - 1, ROWS - 1), NO_CELL, Vector2i(COLUMNS, 0), Vector2i(0, ROWS)]:
			board.set_pressed_cell(cell)
			board.set_swap_selected(cell)
		assert_eq(board._pressed, NO_CELL, "%s a cell off the board presses nothing" % skin_id)
		board.set_swap_selected(Vector2i(2, 2))
		board.set_pressed_cell(Vector2i(3, 3))
		board.advance_effects(SkinCatalog.get_skin(skin_id).duration(&"target_pulse") * 1.5)
		board.set_targeting(&"")
		assert_eq(board._pressed, NO_CELL, "%s ending targeting drops the press" % skin_id)
		assert_eq(board._selected, NO_CELL, "%s and the selection" % skin_id)


# Effects: lengths from the motion tokens, and the board they leave.

func test_play_spawn_lasts_spawn_plus_the_stagger() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var skin: SkinData = SkinCatalog.get_skin(skin_id)
		var board: CommonBoardView = _board(skin_id)
		board.set_board(_filled(2))
		var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
		var length: float = board.play_spawn(cells, PackedInt64Array([4, 8, 16]))
		var stagger: float = MotionMath.extra(skin, &"spawn", "stagger")
		assert_near(length, skin.duration(&"spawn") + 2.0 * stagger, EPSILON, "%s spawn length" % skin_id)
		assert_eq(board.value_at(Vector2i(2, 0)), 16, "%s spawned value" % skin_id)
		_settle(board, length, "%s spawn" % skin_id)
		var none: Array[Vector2i] = []
		assert_eq(board.play_spawn(none, PackedInt64Array()), 0.0, "%s spawning nothing takes no time" % skin_id)


func test_play_merge_lasts_travel_and_pop() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var skin: SkinData = SkinCatalog.get_skin(skin_id)
		var board: CommonBoardView = _board(skin_id)
		board.set_board(_filled(8))
		var chain: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 1)]
		board.set_chain(chain, Vector2(10.0, 10.0))
		board.set_preview(32)
		var length: float = board.play_merge(chain, Vector2i(2, 1), 32)
		var expected: float = skin.duration(&"merge_travel")
		if not POP_IS_TAIL[skin_id]:
			expected += skin.duration(&"merge_pop")
		assert_near(length, expected, EPSILON, "%s merge length" % skin_id)
		assert_eq(board.value_at(Vector2i(0, 0)), 0, "%s chain cells empty" % skin_id)
		assert_eq(board.value_at(Vector2i(2, 1)), 32, "%s result placed" % skin_id)
		assert_false(board._show_preview(), "%s the preview goes with the chain" % skin_id)
		_settle(board, length, "%s merge" % skin_id)
		assert_eq(board._build_line_points(), 0, "%s no line is left" % skin_id)


func test_play_clear_lasts_clear() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var skin: SkinData = SkinCatalog.get_skin(skin_id)
		var board: CommonBoardView = _board(skin_id)
		board.set_board(_filled(2))
		var cleared: Array[Vector2i] = [Vector2i(0, 7), Vector2i(4, 0)]
		var length: float = board.play_clear(cleared)
		assert_near(length, skin.duration(&"clear"), EPSILON, "%s clear length" % skin_id)
		assert_eq(board.value_at(Vector2i(0, 7)), 0, "%s cleared cell empty" % skin_id)
		_settle(board, length, "%s clear" % skin_id)
		var empty: Array[Vector2i] = [Vector2i(0, 7)]
		assert_eq(board.play_clear(empty), 0.0, "%s clearing an empty cell takes no time" % skin_id)


func test_play_fall_lasts_fall_and_moves_the_values() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var skin: SkinData = SkinCatalog.get_skin(skin_id)
		var board: CommonBoardView = _board(skin_id)
		var cells: PackedInt64Array = _filled(2)
		cells[CoreRules.index_of(Vector2i(1, 0), COLUMNS)] = 64
		cells[CoreRules.index_of(Vector2i(1, 1), COLUMNS)] = 128
		cells[CoreRules.index_of(Vector2i(1, 6), COLUMNS)] = 0
		cells[CoreRules.index_of(Vector2i(1, 7), COLUMNS)] = 0
		board.set_board(cells)
		var from: Array[Vector2i] = [Vector2i(1, 5), Vector2i(1, 4), Vector2i(1, 3), Vector2i(1, 2), Vector2i(1, 1), Vector2i(1, 0)]
		var to: Array[Vector2i] = [Vector2i(1, 7), Vector2i(1, 6), Vector2i(1, 5), Vector2i(1, 4), Vector2i(1, 3), Vector2i(1, 2)]
		var length: float = board.play_fall(from, to)
		assert_near(length, skin.duration(&"fall"), EPSILON, "%s fall length" % skin_id)
		assert_eq(board.value_at(Vector2i(1, 2)), 64, "%s the top tile fell two rows" % skin_id)
		assert_eq(board.value_at(Vector2i(1, 3)), 128, "%s the next one too" % skin_id)
		assert_eq(board.value_at(Vector2i(1, 0)), 0, "%s the top is empty" % skin_id)
		assert_eq(board.value_at(Vector2i(1, 1)), 0, "%s the row under it too" % skin_id)
		_settle(board, length, "%s fall" % skin_id)


func test_a_running_pop_falls_with_its_tile() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var board: CommonBoardView = _board(skin_id)
		var cells: PackedInt64Array = _filled(4)
		cells[CoreRules.index_of(Vector2i(0, 7), COLUMNS)] = 0
		board.set_board(cells)
		board.play_value_change(Vector2i(0, 6), 8)
		var from: Array[Vector2i] = [Vector2i(0, 6)]
		var to: Array[Vector2i] = [Vector2i(0, 7)]
		board.play_fall(from, to)
		for effect: RefCounted in board._effects:
			assert_ne(effect.get("index"), CoreRules.index_of(Vector2i(0, 6), COLUMNS), "%s no effect stays on the emptied cell" % skin_id)


func test_play_value_change_lasts_the_pop() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var skin: SkinData = SkinCatalog.get_skin(skin_id)
		var board: CommonBoardView = _board(skin_id)
		board.set_board(_filled(1024))
		var length: float = board.play_value_change(Vector2i(2, 2), 2048)
		var expected: float = 0.0 if POP_IS_TAIL[skin_id] else skin.duration(&"merge_pop")
		assert_near(length, expected, EPSILON, "%s Double length" % skin_id)
		assert_eq(board.value_at(Vector2i(2, 2)), 2048, "%s doubled" % skin_id)
		_settle(board, length, "%s Double" % skin_id)


func test_play_swap_lasts_a_fall_and_swaps_the_values() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var skin: SkinData = SkinCatalog.get_skin(skin_id)
		var board: CommonBoardView = _board(skin_id)
		var cells: PackedInt64Array = _filled(2)
		cells[0] = 512
		board.set_board(cells)
		var length: float = board.play_swap(Vector2i(0, 0), Vector2i(4, 7))
		assert_near(length, skin.duration(&"fall"), EPSILON, "%s Swap length" % skin_id)
		assert_eq(board.value_at(Vector2i(4, 7)), 512, "%s swapped" % skin_id)
		assert_eq(board.value_at(Vector2i(0, 0)), 2, "%s both ways" % skin_id)
		_settle(board, length, "%s Swap" % skin_id)
		assert_eq(board.play_swap(Vector2i(1, 1), Vector2i(1, 1)), 0.0, "%s a tile with itself does nothing" % skin_id)


func test_play_rearrange_slides_a_shuffle_and_spawns_what_is_new() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var skin: SkinData = SkinCatalog.get_skin(skin_id)
		var board: CommonBoardView = _board(skin_id)
		var before: PackedInt64Array = _mixed_cells(12)
		board.set_board(before)
		var shuffled: PackedInt64Array = before.duplicate()
		shuffled.reverse()
		var length: float = board.play_rearrange(shuffled)
		assert_near(length, skin.duration(&"fall"), EPSILON, "%s a Shuffle only slides" % skin_id)
		for index: int in shuffled.size():
			assert_eq(board.value_at(_cell(index)), shuffled[index], "%s cell %d after Shuffle" % [skin_id, index])
		_settle(board, length, "%s Shuffle" % skin_id)
		var undone: PackedInt64Array = shuffled.duplicate()
		undone[0] = 1 << 20
		length = board.play_rearrange(undone)
		var expected: float = maxf(skin.duration(&"spawn"), skin.duration(&"clear"))
		assert_near(length, expected, EPSILON, "%s a new value spawns and the old one leaves" % skin_id)
		_settle(board, length, "%s Undo" % skin_id)
		assert_eq(board.play_rearrange(undone), 0.0, "%s nothing to change takes no time" % skin_id)


func test_a_whole_move_ends_on_the_board_the_move_says() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var board: CommonBoardView = _board(skin_id)
		var cells: PackedInt64Array = _filled(4)
		cells[CoreRules.index_of(Vector2i(0, 7), COLUMNS)] = 2
		cells[CoreRules.index_of(Vector2i(1, 7), COLUMNS)] = 2
		board.set_board(cells)
		var chain: Array[Vector2i] = [Vector2i(0, 7), Vector2i(1, 7)]
		board.set_chain(chain, NO_DRAG)
		var total: float = board.play_merge(chain, Vector2i(1, 7), 4)
		board.advance_effects(total + EPSILON)
		var from: Array[Vector2i] = [Vector2i(0, 6), Vector2i(0, 5), Vector2i(0, 4), Vector2i(0, 3), Vector2i(0, 2), Vector2i(0, 1), Vector2i(0, 0)]
		var to: Array[Vector2i] = [Vector2i(0, 7), Vector2i(0, 6), Vector2i(0, 5), Vector2i(0, 4), Vector2i(0, 3), Vector2i(0, 2), Vector2i(0, 1)]
		total = board.play_fall(from, to)
		var spawned: Array[Vector2i] = [Vector2i(0, 0)]
		total = maxf(total, board.play_spawn(spawned, PackedInt64Array([8])))
		board.advance_effects(total + EPSILON)
		var after: PackedInt64Array = _filled(4)
		after[CoreRules.index_of(Vector2i(0, 0), COLUMNS)] = 8
		for index: int in after.size():
			assert_eq(board.value_at(_cell(index)), after[index], "%s cell %d" % [skin_id, index])
		assert_false(board.has_running_effects(), "%s at rest" % skin_id)


func test_effects_on_cells_off_the_board_do_nothing() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var board: CommonBoardView = _board(skin_id)
		board.set_board(_filled(2))
		assert_eq(board.play_value_change(Vector2i(COLUMNS, 0), 4), 0.0, "%s Double off the board" % skin_id)
		var off: Array[Vector2i] = [Vector2i(-1, 0)]
		assert_eq(board.play_clear(off), 0.0, "%s clear off the board" % skin_id)


# Design review fixes (docs/design/briefs/tile-board-artist-prod-fixes.md).

func test_slate_label_plate_clears_the_inset_chained_frame() -> void:
	# The chained frame sits frame_inset inside the edge (DESIGN_SYSTEM.md
	# 5.7). The plate over the number must stay inside the frame for every
	# label up to 64M, at the board tile and smaller ones. (128M to 512M are
	# wider than any real board reaches; reported to the designer.)
	var skin: SkinData = SkinCatalog.get_skin(&"slate")
	var painter: RefCounted = SLATE_PAINTER.new()
	painter.call("setup", skin)
	var highest_index: int = 25
	for side: float in [_reference_side(skin), 168.0, 148.0, 120.0]:
		var unit: float = side / float(painter.call("reference_side"))
		painter.call("set_side", side, unit)
		var tile: Rect2 = Rect2(Vector2(-side, -side) * 0.5, Vector2(side, side))
		var inner: Rect2 = tile.grow(-(skin.num(&"frame_inset") * side + skin.num(&"chain_ring") * unit))
		var top_left: Vector2 = tile.position + Vector2.ONE * skin.num(&"number_inset") * side
		var labels: RefCounted = painter.get("labels")
		for index: int in highest_index + 1:
			var box: Rect2 = labels.call("box_top_left", top_left, index)
			var plate: Rect2 = box.grow(skin.num(&"number_plate") * unit)
			if not inner.encloses(plate):
				fail("slate label %s at a %.0f px tile: plate %s crosses the frame %s" % [labels.call("label", index), side, plate, inner])


func test_nova_chained_rim_is_dark_on_the_white_hole() -> void:
	var skin: SkinData = SkinCatalog.get_skin(&"nova")
	var painter: RefCounted = NOVA_PAINTER.new()
	painter.call("setup", skin)
	var rims: PackedColorArray = painter.get("_chain_rims")
	var dark_from: int = int(skin.num(&"dark_rim_from"))
	for index: int in rims.size():
		var value: int = 2 << index
		var expected: Color = skin.color(&"ink_dark") if value >= dark_from else skin.color(&"chain")
		assert_eq(rims[index], expected, "nova chained rim for %d" % value)


func test_nova_sparks_take_the_lightened_fill() -> void:
	var skin: SkinData = SkinCatalog.get_skin(&"nova")
	var painter: RefCounted = NOVA_PAINTER.new()
	painter.call("setup", skin)
	var sparks: PackedColorArray = painter.get("_spark_colors")
	for index: int in SkinData.RAMP_SIZE + 1:
		var value: int = 2 << index
		assert_eq(sparks[index], skin.fill_for(value).lightened(skin.num(&"ray_lighten")), "nova spark color for %d" % value)
	assert_eq(MotionMath.extra(skin, &"clear", "spark_size"), 8.0, "nova spark size")


# Tile views.

func test_tile_view_accepts_its_edge_values() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var tile: SkinTileView = _tile(skin_id)
		for side: float in [0.0, 1.0, 72.0, 112.0, 400.0]:
			tile.size = Vector2(side, side * 2.0)
			for value: int in [0, 2, 3, -2, 131072, 1 << HIGHEST_SHORT_POWER, 1 << HIGHEST_POWER]:
				tile.set_value(value)
		assert_eq(tile.get("_value"), 1 << HIGHEST_POWER, "%s keeps the last value" % skin_id)


# Helpers.

func _board(skin_id: StringName) -> CommonBoardView:
	var skin: SkinData = SkinCatalog.get_skin(skin_id)
	var board: CommonBoardView = SkinCatalog.make_board_view(skin) as CommonBoardView
	board.effects_paused = true
	board.setup(skin, COLUMNS, ROWS)
	var width: float = _board_width(skin)
	board.size = Vector2(width, board.preferred_height(width))
	_nodes.append(board)
	return board


func _tile(skin_id: StringName) -> SkinTileView:
	var tile: SkinTileView = SkinCatalog.make_tile_view(SkinCatalog.get_skin(skin_id))
	_nodes.append(tile)
	return tile


func _board_width(skin: SkinData) -> float:
	return float(ProjectSettings.get_setting("display/window/size/viewport_width")) - 2.0 * skin.num(&"board_margin")


## The board tile side on the base canvas.
func _reference_side(skin: SkinData) -> float:
	var board: CommonBoardView = _board(skin.id)
	return board.tile_side()


func _cell(index: int) -> Vector2i:
	return CoreRules.cell_of(index, COLUMNS)


func _filled(value: int) -> PackedInt64Array:
	var cells: PackedInt64Array = PackedInt64Array()
	cells.resize(COLUMNS * ROWS)
	cells.fill(value)
	return cells


## Values from 2 up to 2^highest_power, repeating, one per cell.
func _mixed_cells(highest_power: int) -> PackedInt64Array:
	var cells: PackedInt64Array = PackedInt64Array()
	for index: int in COLUMNS * ROWS:
		cells.append(1 << (1 + (index * 7) % highest_power))
	cells[0] = 1 << highest_power
	return cells


## Steps the clock just past an effect's length; then no tile may still move.
func _settle(board: CommonBoardView, length: float, what: String) -> void:
	board.advance_effects(length + EPSILON)
	assert_false(board.has_running_effects(), "%s is at rest after its length" % what)


func _check_geometry(board: CommonBoardView, what: String) -> void:
	var origin: Vector2 = board.grid_origin()
	var pitch: Vector2 = board.cell_pitch()
	var bounds: Rect2 = Rect2(Vector2.ZERO, board.size).grow(EPSILON)
	assert_near(pitch.x, pitch.y, EPSILON, "%s pitch is square" % what)
	assert_true(pitch.x > 0.0, "%s pitch is set" % what)
	for index: int in COLUMNS * ROWS:
		var cell: Vector2i = _cell(index)
		var rect: Rect2 = board.cell_rect(cell)
		var center: Vector2 = origin + (Vector2(cell) + Vector2(0.5, 0.5)) * pitch
		if not rect.get_center().is_equal_approx(center):
			fail("%s cell %s: rect center %s, grid says %s" % [what, cell, rect.get_center(), center])
		assert_near(rect.size.x, rect.size.y, EPSILON, "%s tiles are square" % what)
		assert_true(rect.size.x <= pitch.x + EPSILON, "%s a tile fits its pitch" % what)
		if not bounds.encloses(rect):
			fail("%s cell %s rect %s leaves the view %s" % [what, cell, rect, board.size])
