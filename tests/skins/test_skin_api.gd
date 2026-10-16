extends "res://tests/base_test.gd"
## SkinData and SkinCatalog behave as docs/ARCHITECTURE.md section 6 and
## docs/DESIGN_SYSTEM.md sections 2.5 and 2.6 say.

## Tile sides to check labels on, px: a 48 px chip tile, the smallest board
## tile (56 dp at 3x), and the board tiles of the three skins.
const SIDES: PackedFloat32Array = [48.0, 168.0, 178.4, 190.4, 174.6]
## The highest power of two the label rule keeps to 4 characters.
const HIGHEST_POWER: int = 49
## The widest score the GDD allows (14.2).
const LONGEST_SCORE: String = "9,999,999,999"


func test_fill_ink_and_tier_cover_the_ramp() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var skin: SkinData = SkinCatalog.get_skin(skin_id)
		var value: int = SkinData.RAMP_LOW
		for index: int in SkinData.RAMP_SIZE:
			assert_eq(skin.fill_for(value), skin.tile_fill[index], "%s fill for %d" % [skin_id, value])
			assert_eq(skin.ink_for(value), skin.tile_ink[index], "%s ink for %d" % [skin_id, value])
			assert_eq(skin.tier_for(value), skin.tile_tier[index], "%s tier for %d" % [skin_id, value])
			assert_true(skin.tier_for(value) > 0, "%s tier for %d is set" % [skin_id, value])
			value *= 2
		assert_eq(value, SkinData.RAMP_HIGH * 2, "the ramp ends at 131072")


## The first values above the ramp, and where each cycle comes round again
## (DESIGN_SYSTEM.md 3.3): power of two to ramp position, per skin.
const CYCLE_TABLE: Dictionary = {
	&"gumdrop": {18: 0, 19: 1, 20: 4, 21: 5, 22: 6, 23: 7, 24: 8, 32: 16, 33: 0},
	&"slate": {18: 0, 19: 1, 20: 2, 21: 3, 22: 4, 23: 5, 24: 6, 34: 16, 35: 0},
	&"nova": {18: 0, 19: 2, 20: 3, 21: 4, 22: 5, 23: 6, 24: 7, 33: 16, 34: 0},
}
## The cycle lengths of 3.3.
const CYCLE_LENGTHS: Dictionary = {&"gumdrop": 15, &"slate": 17, &"nova": 16}
## Highest power of two a tile can hold (GDD D-37).
const MAX_POWER: int = 62
## Values on the board at once, at most (DESIGN_SYSTEM.md 3.3).
const WINDOW: int = 13


func test_values_above_the_ramp_walk_the_color_cycle() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var skin: SkinData = SkinCatalog.get_skin(skin_id)
		assert_eq(skin.tile_cycle.size(), CYCLE_LENGTHS[skin_id], "%s cycle length" % skin_id)
		var table: Dictionary = CYCLE_TABLE[skin_id]
		for power: int in table.keys():
			var value: int = 1 << power
			var position: int = table[power]
			assert_eq(skin.color_position(value), position, "%s color position of 2^%d" % [skin_id, power])
			assert_eq(skin.fill_for(value), skin.tile_fill[position], "%s fill for 2^%d" % [skin_id, power])
			assert_eq(skin.ink_for(value), skin.tile_ink[position], "%s ink for 2^%d" % [skin_id, power])
		# Size follows the value: every value above the ramp keeps beyond_tier.
		for power: int in range(18, MAX_POWER + 1):
			assert_eq(skin.tier_for(1 << power), skin.beyond_tier, "%s tier for 2^%d" % [skin_id, power])
		assert_true(skin.beyond_tier > 0, "%s beyond_tier is set" % skin_id)


func test_any_13_consecutive_values_have_distinct_fills() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var skin: SkinData = SkinCatalog.get_skin(skin_id)
		for first: int in range(18, MAX_POWER - WINDOW + 2):
			var seen: Dictionary[Color, int] = {}
			for power: int in range(first, first + WINDOW):
				var fill: Color = skin.fill_for(1 << power)
				if seen.has(fill):
					fail("%s 2^%d and 2^%d share a fill" % [skin_id, seen[fill], power])
				seen[fill] = power


func test_validate_checks_the_color_cycle() -> void:
	var skin: SkinData = SkinCatalog.get_skin(&"slate").duplicate(true) as SkinData
	skin.tile_cycle = PackedInt32Array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 11, 17])
	var problems: PackedStringArray = skin.validate()
	assert_true(problems.has("tile_cycle holds 11 twice"), "a repeat is reported")
	assert_true(problems.has("tile_cycle holds 17, needs 0 to 16"), "a position outside the ramp is reported")
	skin.tile_cycle = PackedInt32Array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11])
	assert_true(skin.validate().has("tile_cycle has 12 entries, needs at least 13"), "a short cycle is reported")


func test_ramp_index() -> void:
	assert_eq(SkinData.ramp_index(2), 0)
	assert_eq(SkinData.ramp_index(4), 1)
	assert_eq(SkinData.ramp_index(131072), 16)
	assert_eq(SkinData.ramp_index(262144), SkinData.RAMP_SIZE)
	assert_eq(SkinData.ramp_index(1 << 49), SkinData.RAMP_SIZE)
	assert_eq(SkinData.ramp_index(0), -1)
	assert_eq(SkinData.ramp_index(1), -1)
	assert_eq(SkinData.ramp_index(6), -1)
	assert_eq(SkinData.ramp_index(-4), -1)


func test_font_for_every_role() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var skin: SkinData = SkinCatalog.get_skin(skin_id)
		for role: StringName in SkinData.TYPE_ROLES:
			var role_font: Font = skin.font(role)
			assert_true(role_font is FontVariation, "%s %s font is a FontVariation" % [skin_id, role])
			assert_true(skin.font(role) == role_font, "%s %s font is cached" % [skin_id, role])


func test_outfit_skins_use_outfit_on_the_weight_axis() -> void:
	var weight_tag: int = TextServerManager.get_primary_interface().name_to_tag("wght")
	for skin_id: StringName in [&"gumdrop", &"nova"]:
		var skin: SkinData = SkinCatalog.get_skin(skin_id)
		assert_eq(skin.font_path, "res://src/design/fonts/Outfit[wght].ttf", "%s font_path" % skin_id)
		for role: StringName in SkinData.TYPE_ROLES:
			var variation: FontVariation = skin.font(role) as FontVariation
			var base: FontFile = variation.base_font as FontFile
			assert_true(base != null, "%s %s font is a font file" % [skin_id, role])
			if base != null:
				assert_eq(base.resource_path, skin.font_path, "%s %s font file" % [skin_id, role])
			var weight: int = int(skin.type_roles[role]["weight"])
			assert_eq(variation.variation_opentype.get(weight_tag, -1), weight, "%s %s weight on the wght axis" % [skin_id, role])
			assert_eq(variation.spacing_glyph, int(skin.type_roles[role]["tracking"]), "%s %s tracking" % [skin_id, role])


func test_slate_uses_the_system_font() -> void:
	var skin: SkinData = SkinCatalog.get_skin(&"slate")
	assert_eq(skin.font_path, "", "slate font_path")
	assert_eq(skin.system_font_names[0], "Roboto", "Roboto first")
	for role: StringName in SkinData.TYPE_ROLES:
		var variation: FontVariation = skin.font(role) as FontVariation
		var system: SystemFont = variation.base_font as SystemFont
		assert_true(system != null, "slate %s font is a SystemFont" % role)
		if system != null:
			assert_eq(system.font_names, skin.system_font_names, "slate %s font names" % role)
			assert_eq(system.font_weight, int(skin.type_roles[role]["weight"]), "slate %s weight" % role)


func test_tile_labels_never_exceed_label_fit() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var skin: SkinData = SkinCatalog.get_skin(skin_id)
		var tile_font: Font = skin.font(&"tile")
		var fit: float = skin.num(&"label_fit")
		for side: float in SIDES:
			for power: int in range(1, HIGHEST_POWER + 1):
				var label: String = _tile_label(1 << power)
				var size: int = skin.tile_font_size(side, label)
				var width: float = tile_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
				if width > fit * side:
					fail("%s label %s on a %.1f px tile is %.1f px wide at size %d, more than %.1f" % [skin_id, label, side, width, size, fit * side])
				assert_true(size <= roundi(side * skin.tile_number_scale[clampi(label.length(), 1, 4) - 1]), "%s label %s never grows" % [skin_id, label])


func test_tile_font_size_keeps_the_scale_when_the_label_fits() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var skin: SkinData = SkinCatalog.get_skin(skin_id)
		var side: float = 180.0
		assert_eq(skin.tile_font_size(side, "2"), roundi(side * skin.tile_number_scale[0]), "%s one character" % skin_id)


func test_tile_font_size_shrinks_a_label_that_does_not_fit() -> void:
	var skin: SkinData = SkinCatalog.get_skin(&"gumdrop")
	var side: float = 100.0
	var label: String = "88888888"
	var size: int = skin.tile_font_size(side, label)
	var width: float = skin.font(&"tile").get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	assert_true(size < roundi(side * skin.tile_number_scale[3]), "an over long label shrinks")
	assert_true(width <= skin.num(&"label_fit") * side, "and then fits")


func test_score_font_size_fits_and_never_goes_below_the_minimum() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var skin: SkinData = SkinCatalog.get_skin(skin_id)
		var display: int = skin.font_size(&"display")
		var smallest: int = int(skin.num(&"display_fit_min"))
		var display_font: Font = skin.font(&"display")
		assert_eq(skin.score_font_size("0", 2000.0), display, "%s a short score keeps the display size" % skin_id)
		assert_eq(skin.score_font_size(LONGEST_SCORE, 10.0), smallest, "%s an impossible width stops at display_fit_min" % skin_id)
		for max_width: float in [400.0, 600.0, 800.0, 1000.0]:
			var size: int = skin.score_font_size(LONGEST_SCORE, max_width)
			assert_true(size >= smallest and size <= display, "%s size %d within %d to %d" % [skin_id, size, smallest, display])
			var width: float = display_font.get_string_size(LONGEST_SCORE, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
			assert_true(width <= max_width or size == smallest, "%s score fits %.0f px or sits at the minimum" % [skin_id, max_width])


func test_cased_follows_the_role() -> void:
	assert_eq(SkinCatalog.get_skin(&"gumdrop").cased(&"label", "Best tile"), "Best tile")
	assert_eq(SkinCatalog.get_skin(&"slate").cased(&"label", "Best tile"), "BEST TILE")
	assert_eq(SkinCatalog.get_skin(&"slate").cased(&"body", "Best tile"), "Best tile")
	assert_eq(SkinCatalog.get_skin(&"nova").cased(&"label", "Best Tile"), "best tile")


func test_catalog_lists_the_skins_in_settings_order() -> void:
	assert_eq(SkinCatalog.DEFAULT_ID, &"gumdrop")
	assert_eq(SkinCatalog.IDS.size(), 3)
	assert_eq(SkinCatalog.IDS[0], &"gumdrop")
	assert_eq(SkinCatalog.IDS[1], &"slate")
	assert_eq(SkinCatalog.IDS[2], &"nova")
	for skin_id: StringName in SkinCatalog.IDS:
		assert_eq(SkinCatalog.get_skin(skin_id).id, skin_id, "get_skin(%s)" % skin_id)


func test_unknown_skin_id_returns_the_default() -> void:
	assert_eq(SkinCatalog.get_skin(&"plaid").id, SkinCatalog.DEFAULT_ID)
	assert_eq(SkinCatalog.get_skin(&"").id, SkinCatalog.DEFAULT_ID)


func test_validate_reports_a_missing_token() -> void:
	var skin: SkinData = SkinCatalog.get_skin(&"nova").duplicate(true) as SkinData
	skin.palette.erase(&"accent")
	skin.numbers.erase(&"label_fit")
	skin.numbers.erase(&"notice_strike")
	skin.motion.erase(&"spawn")
	var problems: PackedStringArray = skin.validate()
	assert_true(problems.has("missing palette role 'accent'"), "missing palette role")
	assert_true(problems.has("missing number 'label_fit'"), "missing number")
	assert_true(problems.has("missing number 'notice_strike'"), "notice_strike is a shared number")
	assert_true(problems.has("missing motion 'spawn'"), "missing motion")


## The tile label rule of DESIGN_SYSTEM.md 2.5 (GDD D-31), for the checks
## above: the full number up to 1024, then 1 to 512 with K, M, B or T.
static func _tile_label(value: int) -> String:
	var power: int = 0
	var v: int = value
	while v > 1:
		v = v >> 1
		power += 1
	if power <= 10:
		return str(value)
	@warning_ignore("integer_division")
	var unit: int = mini(power / 10, 4)
	var suffixes: PackedStringArray = ["K", "M", "B", "T"]
	return "%d%s" % [1 << (power - 10 * unit), suffixes[unit - 1]]
