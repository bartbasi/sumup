extends SceneTree
## Tile label size check for the skins that ship.
##
## Run from the repo root:
##     godot --headless --path . --script res://tools/label_check.gd
##
## docs/GDD.md section 14.1 (with assumption A-1) asks that on the smallest
## tile, 56 dp, every label fits inside the tile and its digits are at least
## 12 dp tall. For every skin in SkinCatalog.IDS this script loads the SkinData
## resource the game uses (through SkinCatalog.get_skin), takes its tile font
## (skin.font("tile")) and label scale, and for each label length from 1 to 4
## characters:
##   - measures the real digit height from the glyph outlines (the shortest
##     of the ten digits), and checks it is at least 12 dp on a 56 dp tile
##   - measures the widest label of that length, over every value from 2 to
##     2^49, and checks it fits within the skin's label_fit share of the
##     tile side
## Prints every result. Exits with code 0 when all pass and 1 otherwise.
##
## Labels come from NumberFormat.tile_label, the format the game shows.
##
## Each skin is measured in its own font: Outfit from its font file for
## Gumdrop and Nova, the system font for Slate. Here the system font resolves
## to Segoe UI (Windows). Roboto, the Android system font, has slightly taller
## digits (cap height 0.711 of the size against Segoe UI's 0.700), so a pass
## here holds on Android too.

## GDD section 18: SMALLEST_TILE_DP and MIN_LABEL_DIGIT_HEIGHT_DP.
const SMALLEST_TILE_DP: float = 56.0
const MIN_DIGIT_DP: float = 12.0
## Font size the measurements are taken at, then scaled.
const MEASURE_SIZE: int = 400
## Labels are checked for every value from 2^1 to 2^49 (4 characters at most).
const HIGHEST_POWER: int = 49

var _failed: int = 0
var _checked: int = 0


func _initialize() -> void:
	print("Label size check. On a %d dp tile, digits need %d dp or more and every label must fit." % [int(SMALLEST_TILE_DP), int(MIN_DIGIT_DP)])
	var labels_by_length: Array[PackedStringArray] = [PackedStringArray(), PackedStringArray(), PackedStringArray(), PackedStringArray()]
	for power: int in range(1, HIGHEST_POWER + 1):
		var label: String = NumberFormat.tile_label(1 << power)
		if label.length() < 1 or label.length() > 4:
			print("  FAIL label for 2^%d is '%s', more than 4 characters" % [power, label])
			_checked += 1
			_failed += 1
			continue
		labels_by_length[label.length() - 1].append(label)
	for skin_id: StringName in SkinCatalog.IDS:
		_check_skin(skin_id, labels_by_length)
	print("")
	print("%s: %d checks, %d failed." % ["PASS" if _failed == 0 else "FAIL", _checked, _failed])
	quit(0 if _failed == 0 else 1)


func _check_skin(skin_id: StringName, labels_by_length: Array[PackedStringArray]) -> void:
	print("")
	var skin: SkinData = SkinCatalog.get_skin(skin_id)
	if skin == null or skin.id != skin_id:
		_fail_skin(skin_id, "skin resource missing, broken, or not this skin")
		return
	if not skin.type_roles.has(&"tile") or skin.tile_number_scale.size() != 4 or not skin.numbers.has(&"label_fit"):
		_fail_skin(skin_id, "the tile type role, tile_number_scale or label_fit is missing")
		return
	if not skin.font_path.is_empty() and not ResourceLoader.exists(skin.font_path):
		_fail_skin(skin_id, "font file %s is missing" % skin.font_path)
		return
	var font: Font = skin.font(&"tile")
	# A variable font reports its default instance name ("Outfit Thin"), so
	# name the file instead; for the system font, name what it resolved to.
	var source: String = skin.font_path
	if source.is_empty():
		source = "system font, here %s" % font.get_font_name()
	print("%s: %s, tile weight %d, labels fit within %d%% of the tile side" % [
		skin.display_name, source, int(skin.type_roles[&"tile"].get("weight", 0)),
		roundi(skin.num(&"label_fit") * 100.0)])
	var digit_share: float = _digit_height(font) / float(MEASURE_SIZE)
	for length_index: int in 4:
		var scale: float = skin.tile_number_scale[length_index]
		var size_dp: float = SMALLEST_TILE_DP * scale
		var digit_dp: float = size_dp * digit_share
		var widest: String = ""
		var widest_share: float = 0.0
		for label: String in labels_by_length[length_index]:
			var share: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, MEASURE_SIZE).x / float(MEASURE_SIZE) * scale
			if share > widest_share:
				widest_share = share
				widest = label
		var digit_ok: bool = digit_dp >= MIN_DIGIT_DP
		var fit_ok: bool = widest_share <= skin.num(&"label_fit")
		_checked += 2
		if not digit_ok:
			_failed += 1
		if not fit_ok:
			_failed += 1
		print("  %s %d characters: size %.1f dp, digits %.1f dp; widest '%s' is %d%% of the tile %s" % [
			"PASS" if digit_ok and fit_ok else "FAIL", length_index + 1, size_dp, digit_dp, widest,
			roundi(widest_share * 100.0), "" if fit_ok else "(too wide)"])


func _fail_skin(skin_id: StringName, problem: String) -> void:
	_checked += 1
	_failed += 1
	print("  FAIL %s: %s" % [skin_id, problem])


## Height of the shortest digit glyph at MEASURE_SIZE, from its outline.
## 0 when a digit cannot be measured, which fails every digit check.
func _digit_height(font: Font) -> float:
	var server: TextServer = TextServerManager.get_primary_interface()
	var shortest: float = INF
	for digit: String in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]:
		var best: float = 0.0
		for rid: RID in font.get_rids():
			var glyph: int = server.font_get_glyph_index(rid, MEASURE_SIZE, digit.unicode_at(0), 0)
			if glyph == 0:
				continue
			var outline: Dictionary = server.font_get_glyph_contours(rid, MEASURE_SIZE, glyph)
			var points: PackedVector3Array = outline.get("points", PackedVector3Array())
			if points.is_empty():
				continue
			var top: float = INF
			var bottom: float = -INF
			for point: Vector3 in points:
				top = minf(top, point.y)
				bottom = maxf(bottom, point.y)
			best = bottom - top
			break
		if best <= 0.0:
			push_error("could not measure digit '%s'" % digit)
			return 0.0
		shortest = minf(shortest, best)
	return shortest
