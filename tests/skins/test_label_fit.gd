extends "res://tests/base_test.gd"
## Tile labels never grow wider than label_fit times the tile side
## (DESIGN_SYSTEM.md 2.5), for the largest values a save can hold, at the
## 72 px mini tile of the end of run panel and at each skin's board tile.
## Labels are measured through each skin's own painter, the path the board,
## the tile view and the How to play rows all draw with.

const PAINTERS: Dictionary[StringName, String] = {
	&"gumdrop": "res://src/skins/gumdrop/gumdrop_tile_painter.gd",
	&"slate": "res://src/skins/slate/slate_tile_painter.gd",
	&"nova": "res://src/skins/nova/nova_tile_painter.gd",
}
## The end of run panel's mini tile, a 48 px chip, and the smallest board
## tile (56 dp at 3x).
const SMALL_SIDES: PackedFloat32Array = [72.0, 48.0, 168.0]
## Large powers of two, up to 2^62, the largest tile a save may hold.
const POWERS: PackedInt32Array = [40, 49, 50, 55, 60, 62]


func _painter(skin_id: StringName) -> RefCounted:
	var script: GDScript = load(PAINTERS[skin_id]) as GDScript
	var painter: RefCounted = script.new() as RefCounted
	painter.call(&"setup", SkinCatalog.get_skin(skin_id))
	return painter


func _sides(painter: RefCounted) -> PackedFloat32Array:
	var sides: PackedFloat32Array = SMALL_SIDES.duplicate()
	sides.append(float(painter.call(&"reference_side")))
	return sides


func _check(skin_id: StringName, power: int, side: float) -> void:
	var painter: RefCounted = _painter(skin_id)
	var reference: float = float(painter.call(&"reference_side"))
	painter.call(&"set_side", side, side / reference)
	var labels: RefCounted = painter.get(&"labels") as RefCounted
	var index: int = power - 1
	var label: String = String(labels.call(&"label", index))
	var width: float = float(labels.call(&"width", index))
	var limit: float = SkinCatalog.get_skin(skin_id).num(&"label_fit") * side
	assert_true(width > 0.0, "%s 2^%d at %.1f px has a width" % [skin_id, power, side])
	assert_true(width <= limit, "%s '%s' at %.1f px: width %.1f, limit %.1f" % [skin_id, label, side, width, limit])


func test_largest_labels_fit_in_every_skin_at_every_size() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var painter: RefCounted = _painter(skin_id)
		for side: float in _sides(painter):
			for power: int in POWERS:
				_check(skin_id, power, side)


func test_the_2_to_62_label_is_the_long_form() -> void:
	var labels: GDScript = load("res://src/skins/common/tile_labels.gd") as GDScript
	assert_eq(String(labels.call(&"label", 61)), "4194304T")


func test_every_label_fits_the_mini_tile() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var painter: RefCounted = _painter(skin_id)
		var reference: float = float(painter.call(&"reference_side"))
		painter.call(&"set_side", 72.0, 72.0 / reference)
		var labels: RefCounted = painter.get(&"labels") as RefCounted
		var limit: float = SkinCatalog.get_skin(skin_id).num(&"label_fit") * 72.0
		for index: int in 62:
			var width: float = float(labels.call(&"width", index))
			assert_true(width <= limit, "%s 2^%d at 72 px: width %.1f, limit %.1f" % [skin_id, index + 1, width, limit])


## Slate sets its label top left, number_inset from the left edge, so its
## label_fit (0.78) is 1 minus twice number_inset: the widest labels keep the
## same 0.11 margin on the right and stay clear of the special frame
## (DESIGN_SYSTEM.md 5.4).
func test_slate_label_right_edge_stays_clear_of_the_special_frame() -> void:
	var skin: SkinData = SkinCatalog.get_skin(&"slate")
	assert_near(skin.num(&"label_fit"), 0.78, 0.0001, "Slate label_fit")
	var painter: RefCounted = _painter(&"slate")
	var reference: float = float(painter.call(&"reference_side"))
	var inset: float = skin.num(&"number_inset")
	var special_inset: float = skin.num(&"special_inset")
	var hairline: float = skin.num(&"hairline")
	# 128M is 2^27, the widest label up to 2^49; 4194304T is 2^62.
	for index: int in [26, 61]:
		for side: float in [72.0, reference]:
			var unit: float = side / reference
			painter.call(&"set_side", side, unit)
			var labels: RefCounted = painter.get(&"labels") as RefCounted
			var label: String = String(labels.call(&"label", index))
			var right: float = inset * side + float(labels.call(&"width", index))
			var frame_inner: float = (1.0 - special_inset) * side - maxf(1.0, hairline * unit)
			assert_true(right <= 0.89 * side + 0.001, "Slate '%s' at %.1f px: right edge %.1f, at most %.1f" % [label, side, right, 0.89 * side])
			assert_true(right < frame_inner, "Slate '%s' at %.1f px: right edge %.1f clear of the frame at %.1f" % [label, side, right, frame_inner])
