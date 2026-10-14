extends SceneTree
## Tile label size check for the skins that ship.
##
## Run from the repo root:
##     godot --headless --path . --script res://tools/label_check.gd
##
## docs/GDD.md section 14.1 (with assumption A-1) asks that on full spec
## phones every label fits inside the tile and its digits are at least 12 dp
## tall. For every skin in SkinCatalog.IDS this script loads the SkinData
## resource the game uses (through SkinCatalog.get_skin), takes its tile font
## (skin.font("tile")), and on that skin's own smallest full spec tile
## (DESIGN_SYSTEM.md 2.4: 18:9 and taller) checks every label from 2 to 2^49:
##   - sizes the label exactly as the game does (skin.tile_font_size, which
##     shrinks a label until it is no wider than label_fit of the side)
##   - checks the sized label fits within label_fit of the side
##   - checks its digits are at least 12 dp tall, from the real digit height
##     of the glyph outlines (the shortest of the ten digits)
## Prints the smallest result for each label length. Exits with code 0 when
## all pass and 1 otherwise.
##
## Labels come from NumberFormat.tile_label, the format the game shows.
##
## Each skin is measured in its own font: Outfit from its font file for
## Gumdrop and Nova, the system font for Slate. Here the system font resolves
## to Segoe UI (Windows). Roboto, the Android system font, has slightly taller
## digits (cap height 0.711 of the size against Segoe UI's 0.700), so a pass
## here holds on Android too.

## GDD section 18: MIN_LABEL_DIGIT_HEIGHT_DP.
const MIN_DIGIT_DP: float = 12.0
## Each skin's smallest full spec tile in dp, DESIGN_SYSTEM.md 2.4 (the
## smallest of 20:9, 18:9 and the Fold5 cover screen). Nova: the orb diameter.
const SMALLEST_TILE_DP: Dictionary[StringName, float] = {
	&"gumdrop": 56.9,
	&"slate": 59.6,
	&"nova": 56.3,
}
## Pixels per dp: the game renders at 1080 px wide on a 360 dp screen.
const DENSITY: float = 3.0
## Font size the measurements are taken at, then scaled.
const MEASURE_SIZE: int = 400
## Labels are checked for every value from 2^1 to 2^49 (4 characters at most).
const HIGHEST_POWER: int = 49

var _failed: int = 0
var _checked: int = 0


func _initialize() -> void:
	print("Label size check. On each skin's smallest full spec tile, digits need %d dp or more and every label must fit." % int(MIN_DIGIT_DP))
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
	if not SMALLEST_TILE_DP.has(skin_id):
		_fail_skin(skin_id, "no smallest full spec tile size for this skin")
		return
	var font: Font = skin.font(&"tile")
	# A variable font reports its default instance name ("Outfit Thin"), so
	# name the file instead; for the system font, name what it resolved to.
	var source: String = skin.font_path
	if source.is_empty():
		source = "system font, here %s" % font.get_font_name()
	var tile_dp: float = SMALLEST_TILE_DP[skin_id]
	var side_px: float = tile_dp * DENSITY
	var fit: float = skin.num(&"label_fit")
	print("%s: %s, tile weight %d, %.1f dp tile, labels fit within %d%% of the side" % [
		skin.display_name, source, int(skin.type_roles[&"tile"].get("weight", 0)),
		tile_dp, roundi(fit * 100.0)])
	var digit_share: float = _digit_height(font) / float(MEASURE_SIZE)
	for length_index: int in 4:
		var labels: PackedStringArray = labels_by_length[length_index]
		if labels.is_empty():
			continue
		# The label with the smallest digits, and the widest label, of this length.
		var smallest: String = ""
		var smallest_digit_dp: float = INF
		var smallest_size_dp: float = 0.0
		var widest: String = ""
		var widest_share: float = 0.0
		var shrunk: PackedStringArray = PackedStringArray()
		var full_size: int = maxi(1, roundi(side_px * skin.tile_number_scale[length_index]))
		for label: String in labels:
			var size_px: int = skin.tile_font_size(side_px, label)
			if size_px < full_size:
				shrunk.append(label)
			var digit_dp: float = float(size_px) / DENSITY * digit_share
			if digit_dp < smallest_digit_dp:
				smallest_digit_dp = digit_dp
				smallest_size_dp = float(size_px) / DENSITY
				smallest = label
			var share: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x / side_px
			if share > widest_share:
				widest_share = share
				widest = label
		var digit_ok: bool = smallest_digit_dp >= MIN_DIGIT_DP
		var fit_ok: bool = widest_share <= fit + 0.0001
		_checked += 2
		if not digit_ok:
			_failed += 1
		if not fit_ok:
			_failed += 1
		var shrunk_note: String = ""
		if not shrunk.is_empty():
			shrunk_note = "; shrunk to fit: %s" % ", ".join(shrunk)
		print("  %s %d characters: smallest '%s' size %.1f dp, digits %.1f dp; widest '%s' is %d%% of the side%s%s" % [
			"PASS" if digit_ok and fit_ok else "FAIL", length_index + 1, smallest, smallest_size_dp,
			smallest_digit_dp, widest, roundi(widest_share * 100.0), "" if fit_ok else " (too wide)",
			shrunk_note])


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
