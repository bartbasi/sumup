extends SceneTree
## Contrast checker for the skins that ship.
##
## Run from the repo root:
##     godot --headless --path . --script res://tools/contrast_check.gd
##
## For every skin in SkinCatalog.IDS it loads the SkinData resource the game
## uses (src/skins/<id>/<id>.tres, through SkinCatalog.get_skin) and checks:
##   1. every tile fill against its number color, for each value from 2 to
##      131072, plus the rule for values above 131072
##   2. every text pair the skin lists (text color on background)
## using the WCAG 2 contrast ratio and relative luminance formula. A color
## with alpha is first composited over what sits behind it. Every pair is
## printed with its ratio. Exits with code 0 when every pair reaches its
## minimum (4.5:1 for all text), and 1 when any pair fails or a skin is
## missing or incomplete.

## Minimum contrast for tile numbers and all text (WCAG 2 level AA, normal text).
const MIN_RATIO: float = 4.5
## A value above the ramp, used to check the rule for values above 131072.
const BEYOND_SAMPLE: int = 262144

var _checked: int = 0
var _failed: int = 0


func _initialize() -> void:
	print("Contrast check, WCAG 2 relative luminance. Tile numbers and text need %.1f:1 or better." % MIN_RATIO)
	for skin_id: StringName in SkinCatalog.IDS:
		_check_skin(skin_id)
	print("")
	var verdict: String = "PASS" if _failed == 0 else "FAIL"
	print("%s: %d pairs checked in %d skins, %d failed." % [verdict, _checked, SkinCatalog.IDS.size(), _failed])
	quit(0 if _failed == 0 else 1)


func _check_skin(skin_id: StringName) -> void:
	print("")
	var skin: SkinData = SkinCatalog.get_skin(skin_id)
	if skin == null:
		_report_problem(skin_id, "skin resource missing or broken")
		return
	print("%s (%s)" % [skin.display_name, skin.resource_path])
	var before: int = _failed
	var count_before: int = _checked
	if skin.id != skin_id:
		_report_problem(skin_id, "the resource says its id is '%s'" % skin.id)
	for problem: String in skin.validate():
		_report_problem(skin_id, problem)
	# Tile numbers on tile fills.
	if skin.tile_fill.size() == SkinData.RAMP_SIZE and skin.tile_ink.size() == SkinData.RAMP_SIZE:
		var value: int = SkinData.RAMP_LOW
		for index: int in SkinData.RAMP_SIZE:
			_check_pair("tile %d" % value, skin.tile_ink[index], skin.tile_fill[index], MIN_RATIO)
			value *= 2
		_check_pair("tiles above 131072 (%d)" % BEYOND_SAMPLE, skin.ink_for(BEYOND_SAMPLE), skin.fill_for(BEYOND_SAMPLE), MIN_RATIO)
	# Text on backgrounds.
	for entry: Dictionary in skin.text_pairs:
		_check_text_pair(skin, entry)
	print("  %s: %d pairs, %d failed" % [skin_id, _checked - count_before, _failed - before])


func _check_text_pair(skin: SkinData, entry: Dictionary) -> void:
	var pair_name: String = String(entry.get("name", ""))
	var fg_name: String = String(entry.get("fg", ""))
	var bg_name: String = String(entry.get("bg", ""))
	if pair_name.is_empty() or not entry.has("min"):
		_report_problem(skin.id, "a text pair has no name or no minimum: %s" % entry)
		return
	var fg_ref: Dictionary = resolve(skin, fg_name)
	var bg_ref: Dictionary = resolve(skin, bg_name)
	if not bool(fg_ref["ok"]) or not bool(bg_ref["ok"]):
		_report_problem(skin.id, "pair '%s' has an unknown token" % pair_name)
		return
	var bg: Color = bg_ref["color"]
	if bg.a < 1.0:
		var over_name: String = String(entry.get("over", ""))
		if over_name.is_empty():
			_report_problem(skin.id, "pair '%s': background has alpha, so it needs an 'over' token" % pair_name)
			return
		var over_ref: Dictionary = resolve(skin, over_name)
		var under: Color = over_ref["color"]
		if not bool(over_ref["ok"]) or under.a < 1.0:
			_report_problem(skin.id, "pair '%s': the 'over' token must exist and be opaque" % pair_name)
			return
		bg = composite(bg, under)
	var fg: Color = fg_ref["color"]
	if fg.a < 1.0:
		fg = composite(fg, bg)
	var label: String = "%s (%s on %s)" % [pair_name, fg_name, bg_name]
	_check_pair(label, fg, bg, float(entry["min"]))


func _check_pair(label: String, fg: Color, bg: Color, minimum: float) -> void:
	_checked += 1
	var value: float = contrast_ratio(fg, bg)
	var ok: bool = value >= minimum
	if not ok:
		_failed += 1
	print("  %s %6.2f:1  %s  #%s on #%s" % ["PASS" if ok else "FAIL", value, label, fg.to_html(false).to_upper(), bg.to_html(false).to_upper()])


func _report_problem(skin_id: StringName, problem: String) -> void:
	_checked += 1
	_failed += 1
	print("  FAIL  %s: %s" % [skin_id, problem])


## Resolves a color reference in a skin: a palette token, "tile:<value>" for
## a tile fill, or "ink:<value>" for a tile number color. Returns ok = false
## for an unknown reference.
static func resolve(skin: SkinData, ref: String) -> Dictionary:
	if ref.begins_with("tile:") or ref.begins_with("ink:"):
		var parts: PackedStringArray = ref.split(":")
		var value: int = parts[1].to_int()
		if SkinData.ramp_index(value) < 0:
			return {"ok": false, "color": Color.MAGENTA}
		var picked: Color = skin.fill_for(value) if parts[0] == "tile" else skin.ink_for(value)
		return {"ok": true, "color": picked}
	if skin.palette.has(StringName(ref)):
		return {"ok": true, "color": skin.palette[StringName(ref)]}
	return {"ok": false, "color": Color.MAGENTA}


## WCAG 2 contrast ratio between two opaque colors, from 1 to 21.
static func contrast_ratio(a: Color, b: Color) -> float:
	var la: float = relative_luminance(a)
	var lb: float = relative_luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## WCAG 2 relative luminance of an sRGB color (alpha ignored).
static func relative_luminance(c: Color) -> float:
	return 0.2126 * _linear(c.r) + 0.7152 * _linear(c.g) + 0.0722 * _linear(c.b)


## sRGB channel value (0 to 1) to linear light.
static func _linear(channel: float) -> float:
	if channel <= 0.04045:
		return channel / 12.92
	return pow((channel + 0.055) / 1.055, 2.4)


## Source over blend of a color with alpha onto an opaque color, in sRGB
## space, the way Godot blends 2D drawing.
static func composite(top: Color, under: Color) -> Color:
	var a: float = top.a
	return Color(
		top.r * a + under.r * (1.0 - a),
		top.g * a + under.g * (1.0 - a),
		top.b * a + under.b * (1.0 - a),
		1.0)
