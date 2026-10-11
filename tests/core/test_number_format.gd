extends "res://tests/base_test.gd"
## Tile labels (D-31) and score text (D-32) through NumberFormat.


func test_at_85_tile_labels() -> void:
	var table: Array[Array] = [
		[2, "2"],
		[512, "512"],
		[1024, "1024"],
		[2048, "2K"],
		[4096, "4K"],
		[65536, "64K"],
		[131072, "128K"],
		[524288, "512K"],
		[1048576, "1M"],
		[2097152, "2M"],
		[1073741824, "1B"],
		[1 << 40, "1T"],
		[1 << 49, "512T"],
		[1 << 50, "1024T"],
	]
	for row: Array in table:
		assert_eq(NumberFormat.tile_label(row[0]), row[1], "label for %d" % row[0])


func test_at_86_labels_are_short() -> void:
	for power: int in range(1, 50):
		var label: String = NumberFormat.tile_label(1 << power)
		assert_true(label.length() <= 4, "2^%d gives %s" % [power, label])
	assert_eq(NumberFormat.tile_label(1 << 50), "1024T", "2^50")


func test_tile_label_follows_the_gdd_formula() -> void:
	var suffixes: PackedStringArray = PackedStringArray(["K", "M", "B", "T"])
	for power: int in range(1, 63):
		var expected: String
		if power <= 10:
			expected = str(1 << power)
		else:
			var step: int = mini(power / 10, 4)
			expected = str(1 << (power - 10 * step)) + suffixes[step - 1]
		assert_eq(NumberFormat.tile_label(1 << power), expected, "2^%d" % power)


func test_at_88_score_format() -> void:
	assert_eq(NumberFormat.score(0), "0", "0")
	assert_eq(NumberFormat.score(999), "999", "999")
	assert_eq(NumberFormat.score(1000), "1,000", "1000")
	assert_eq(NumberFormat.score(75000), "75,000", "75000")
	assert_eq(NumberFormat.score(1234567), "1,234,567", "1234567")
	assert_eq(NumberFormat.score(9999999999), "9,999,999,999", "the 13 character score")


func test_score_format_edges() -> void:
	assert_eq(NumberFormat.score(7), "7", "one digit")
	assert_eq(NumberFormat.score(12), "12", "two digits")
	assert_eq(NumberFormat.score(100000), "100,000", "six digits")
	assert_eq(NumberFormat.score(1000000), "1,000,000", "seven digits")
	assert_eq(NumberFormat.score(1 << 61), "2,305,843,009,213,693,952", "2^61")
	assert_eq(NumberFormat.score(9223372036854775807), "9,223,372,036,854,775,807", "the largest 64 bit score")
	assert_eq(NumberFormat.score(-1234), "-1,234", "a negative number keeps its sign (scores never go below zero)")


func test_at_89_labels_for_preview_costs_and_best_tile() -> void:
	var preview: int = CoreRules.merge_result(PackedInt64Array([512, 512, 1024, 1024]))
	assert_eq(NumberFormat.tile_label(preview), "2K", "preview 2K")
	assert_eq(NumberFormat.tile_label(65536), "64K", "Undo at H 131072")
	assert_eq(NumberFormat.tile_label(262144), "256K", "Double at H 131072")
	assert_eq(NumberFormat.tile_label(131072), "128K", "Hammer at H 131072")
	assert_eq(NumberFormat.tile_label(16384), "16K", "Best Tile 16384")
	assert_eq(NumberFormat.tile_label(2048), "2K", "Double at H 1024 (AT-47)")
	assert_eq(NumberFormat.tile_label(1024), "1024", "Hammer at H 1024 (AT-47)")


func test_tile_label_follows_config_overrides() -> void:
	var config: GameConfig = GameConfig.new()
	config.label_full_max = 4096
	assert_eq(NumberFormat.tile_label(4096, config), "4096", "LABEL_FULL_MAX 4096")
	assert_eq(NumberFormat.tile_label(8192, config), "8K", "above it")
	config.label_suffixes = PackedStringArray(["k", "m"])
	assert_eq(NumberFormat.tile_label(1 << 30, config), "1024m", "only two suffixes")
	assert_eq(NumberFormat.tile_label(2048, null), "2K", "null means the GDD values")
