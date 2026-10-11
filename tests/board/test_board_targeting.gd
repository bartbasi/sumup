extends "res://tests/base_test.gd"
## Targeting taps through the board (GDD 13.1, D-43): press feedback, a tap
## on one tile applies Hammer and Double (AT-110), Swap selects then swaps
## (AT-111, AT-69), lifting elsewhere picks nothing, taps off the tiles do
## nothing (AT-66), no chains while targeting (AT-62), and the view mirrors
## targeting_changed.

const F := preload("res://tests/core/core_fixtures.gd")
const BF := preload("res://tests/board/board_fixtures.gd")
const NO_CELL: Vector2i = Vector2i(-1, -1)

var rig: BF.Rig = null


func after_each() -> void:
	if rig != null:
		rig.free_all()


func _targeting(board: PackedInt64Array, booster: StringName) -> void:
	rig = BF.rig(board, 5000)
	rig.session.press_booster(booster)
	assert_eq(rig.session.targeting_booster(), booster, "%s is active" % booster)


func _last(list: Array) -> Variant:
	return list.back() if not list.is_empty() else null


# Hammer and Double act on one tap (AT-110).

func test_at_110_a_and_b_hammer_shows_press_feedback_then_acts_on_the_lift() -> void:
	_targeting(F.board_p(), BoosterRules.HAMMER)
	var before: RunState = rig.session.state.copy()
	rig.down(Vector2i(2, 7))
	assert_eq(_last(rig.view().pressed), Vector2i(2, 7), "(2,7) shows press feedback")
	assert_true(rig.session.state.equals(before), "a finger down charges nothing and changes nothing")
	rig.up(Vector2i(2, 7))
	assert_eq(rig.session.state.score, 4872, "Hammer applied at once: score 4,872")
	assert_eq(rig.view().clears, [BF.cells([Vector2i(2, 7)])], "(2,7) is removed")
	assert_eq(rig.session.targeting_booster(), &"", "targeting ends")
	assert_eq(_last(rig.view().targeting), &"", "the view leaves targeting")
	assert_eq(_last(rig.view().pressed), NO_CELL, "the press feedback is gone")
	assert_eq(rig.clicks(), 0, "boosters never click")


func test_at_110_c_double_lifted_on_another_tile_does_nothing() -> void:
	_targeting(F.board_p(), BoosterRules.DOUBLE)
	var before: RunState = rig.session.state.copy()
	rig.down(Vector2i(0, 0))
	rig.move(Vector2i(1, 0))
	assert_eq(_last(rig.view().pressed), NO_CELL, "no press feedback off the pressed tile")
	rig.up(Vector2i(1, 0))
	assert_true(rig.session.state.equals(before), "nothing doubled or charged")
	assert_eq(rig.session.targeting_booster(), BoosterRules.DOUBLE, "Double stays active")
	assert_eq(rig.view().value_changes.size(), 0, "no effect played")


func test_double_acts_on_one_tap() -> void:
	_targeting(F.board_p(), BoosterRules.DOUBLE)
	rig.tap(Vector2i(0, 0))
	assert_eq(rig.session.state.value_at(Vector2i(0, 0)), 4, "the 2 is doubled")
	assert_eq(rig.session.state.score, 4744, "cost 2 x 128")
	assert_eq(rig.view().value_changes, [[Vector2i(0, 0), 4]], "the view shows the new value")


func test_press_feedback_follows_the_finger_and_a_lift_back_on_the_tile_applies() -> void:
	_targeting(F.board_p(), BoosterRules.HAMMER)
	rig.down(Vector2i(1, 1))
	rig.move(Vector2i(2, 1))
	rig.move(Vector2i(1, 1))
	assert_eq(rig.view().pressed, BF.cells([Vector2i(1, 1), NO_CELL, Vector2i(1, 1)]), "on, off, on again")
	rig.up(Vector2i(1, 1))
	assert_eq(rig.session.state.score, 4872, "lifting on the pressed tile applies")


# Swap (AT-111, AT-69).

func test_at_111_swap_selects_on_its_first_tap_and_acts_on_its_second() -> void:
	_targeting(F.board_p(), BoosterRules.SWAP)
	rig.tap(Vector2i(0, 0))
	assert_eq(_last(rig.view().swap_selected), Vector2i(0, 0), "(0,0) is selected")
	assert_eq(rig.session.state.score, 5000, "nothing charged yet")
	rig.tap(Vector2i(2, 7))
	assert_eq(rig.session.state.value_at(Vector2i(0, 0)), 32, "(0,0) = 32")
	assert_eq(rig.session.state.value_at(Vector2i(2, 7)), 2, "(2,7) = 2")
	assert_eq(rig.session.state.score, 4872, "score 4,872")
	assert_eq(rig.view().swaps, [[Vector2i(0, 0), Vector2i(2, 7)]], "the view swaps the two tiles")
	assert_eq(_last(rig.view().swap_selected), NO_CELL, "the selection is gone")
	assert_eq(_last(rig.view().targeting), &"", "targeting ends")


func test_at_69_swap_ignores_equal_values_and_can_deselect() -> void:
	var board: PackedInt64Array = F.changed(F.board_d(), {Vector2i(0, 0): 32, Vector2i(4, 7): 32})
	_targeting(board, BoosterRules.SWAP)
	var before: RunState = rig.session.state.copy()
	rig.tap(Vector2i(0, 0))
	rig.tap(Vector2i(4, 7))
	assert_eq(_last(rig.view().swap_selected), Vector2i(0, 0), "tapping the other 32 does nothing; (0,0) stays selected")
	rig.tap(Vector2i(0, 0))
	assert_eq(_last(rig.view().swap_selected), NO_CELL, "tapping (0,0) again deselects it")
	rig.session.press_booster(BoosterRules.SWAP)
	assert_eq(_last(rig.view().targeting), &"", "tapping Swap ends targeting")
	assert_true(rig.session.state.equals(before), "board unchanged, score 5,000 throughout")


# Taps that pick nothing.

func test_at_66_taps_off_the_tiles_do_nothing_while_targeting() -> void:
	_targeting(F.board_p(), BoosterRules.HAMMER)
	var before: RunState = rig.session.state.copy()
	var gap: Vector2 = rig.point(Vector2i(1, 1), Vector2(50.0, 50.0))
	var off_board: Vector2 = Vector2(rig.point(Vector2i(2, 7)).x, BF.BELOW_BOARD_Y)
	rig.down_at(gap)
	rig.up_at(gap)
	rig.down_at(off_board)
	rig.up_at(off_board)
	assert_eq(rig.session.targeting_booster(), BoosterRules.HAMMER, "Hammer stays active")
	assert_true(rig.session.state.equals(before), "nothing charged")
	assert_eq(rig.view().pressed.size(), 0, "no press feedback")


func test_at_62_no_chains_while_targeting() -> void:
	_targeting(F.board_p(), BoosterRules.DOUBLE)
	var before: RunState = rig.session.state.copy()
	rig.drag_cells([Vector2i(1, 6), Vector2i(2, 6)])
	assert_false(rig.session.is_dragging(), "no drag")
	rig.up(Vector2i(2, 6))
	assert_eq(rig.chain_events.size(), 0, "no chain")
	assert_eq(rig.view().previews.size(), 0, "no preview")
	assert_eq(rig.clicks(), 0, "no click")
	assert_true(rig.session.state.equals(before), "nothing doubled, nothing charged")
	assert_eq(rig.session.targeting_booster(), BoosterRules.DOUBLE, "Double is still active")


func test_at_107_no_highlight_while_targeting() -> void:
	_targeting(F.board_p(), BoosterRules.HAMMER)
	rig.down(Vector2i(1, 6))
	rig.move(Vector2i(2, 6))
	assert_eq(rig.view().joinable_calls, 0, "no joinable highlight in targeting")


func test_a_booster_switch_under_the_finger_picks_nothing() -> void:
	_targeting(F.board_p(), BoosterRules.HAMMER)
	rig.down(Vector2i(1, 1))
	rig.session.press_booster(BoosterRules.DOUBLE)
	assert_eq(_last(rig.view().pressed), NO_CELL, "the press feedback goes")
	rig.up(Vector2i(1, 1))
	assert_eq(rig.session.state.score, 5000, "the lift applies neither booster")
	assert_eq(rig.session.targeting_booster(), BoosterRules.DOUBLE, "Double is active")


func test_a_second_finger_is_ignored_while_targeting() -> void:
	_targeting(F.board_p(), BoosterRules.HAMMER)
	rig.down(Vector2i(1, 1), 0)
	rig.tap(Vector2i(2, 2), 1)
	assert_eq(rig.session.state.score, 5000, "the second finger's tap picks nothing")
	rig.up(Vector2i(1, 1), 0)
	assert_eq(rig.session.state.score, 4872, "the first finger's tap applies")
	assert_eq(rig.view().clears, [BF.cells([Vector2i(1, 1)])], "on its own tile")


func test_cancel_drag_drops_a_targeting_press() -> void:
	_targeting(F.board_p(), BoosterRules.HAMMER)
	rig.down(Vector2i(1, 1))
	rig.board.cancel_drag()
	assert_eq(_last(rig.view().pressed), NO_CELL, "the press feedback goes")
	rig.up(Vector2i(1, 1))
	assert_eq(rig.session.state.score, 5000, "the lift picks nothing")
	assert_eq(rig.session.targeting_booster(), BoosterRules.HAMMER, "Hammer stays active")


func test_a_mouse_click_is_a_tap() -> void:
	_targeting(F.board_p(), BoosterRules.HAMMER)
	rig.send(BF.mouse_button(rig.point(Vector2i(3, 3)), true))
	rig.send(BF.mouse_button(rig.point(Vector2i(3, 3)), false))
	assert_eq(rig.session.state.score, 4872, "a click on a tile applies Hammer")


# The view mirrors targeting_changed.

func test_the_view_mirrors_targeting() -> void:
	rig = BF.rig(F.board_p(), 5000)
	rig.session.press_booster(BoosterRules.HAMMER)
	rig.session.press_booster(BoosterRules.SWAP)
	rig.tap(Vector2i(0, 0))
	rig.session.cancel_targeting()
	var expected: Array[StringName] = [BoosterRules.HAMMER, BoosterRules.SWAP, BoosterRules.SWAP, &""]
	assert_eq(rig.view().targeting, expected, "enter, switch, select, cancel")
	assert_eq(rig.view().swap_selected, BF.cells([NO_CELL, NO_CELL, Vector2i(0, 0), NO_CELL]), "the Swap selection follows")
