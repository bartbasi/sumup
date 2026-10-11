extends SceneTree
## Tile ramp distinctness check for the skins that ship.
##
## Run from the repo root:
##     godot --headless --path . --script res://tools/ramp_check.gd
##
## Small tile clearing (GDD D-38) keeps about ten consecutive values on the
## board, and the four values of the spawn window are the common ones. So any
## four consecutive tiles must look clearly different at a glance. For every
## skin in SkinCatalog.IDS this loads the SkinData resource the game uses
## (through SkinCatalog.get_skin) and measures the OKLab distance between
## tile fills:
##   - neighbors (one value and its double) at least 0.17
##   - two steps apart (times 4) at least 0.12
##   - three steps apart (times 8) at least 0.09
##   - every tile fill against the background at least 0.15
## OKLab distance is close to how different two colors look; 0.02 is about
## the smallest visible step. Prints every neighbor pair and every failure.
## Exits with code 0 when all pass and 1 otherwise.

const MockState: GDScript = preload("res://tools/directions/shared/mock_state.gd")

const MIN_BY_STEP: PackedFloat32Array = [0.17, 0.12, 0.09]
const MIN_AGAINST_BG: float = 0.15

var _checked: int = 0
var _failed: int = 0


func _initialize() -> void:
	print("Ramp distinctness check, OKLab distance between tile fills.")
	print("Needed: neighbors %.2f, times 4 %.2f, times 8 %.2f, against the background %.2f." % [MIN_BY_STEP[0], MIN_BY_STEP[1], MIN_BY_STEP[2], MIN_AGAINST_BG])
	for skin_id: StringName in SkinCatalog.IDS:
		_check(skin_id)
	print("")
	print("%s: %d pairs checked, %d failed." % ["PASS" if _failed == 0 else "FAIL", _checked, _failed])
	quit(0 if _failed == 0 else 1)


func _check(skin_id: StringName) -> void:
	print("")
	var skin: SkinData = SkinCatalog.get_skin(skin_id)
	if skin == null or skin.id != skin_id:
		_record(false, "  %s: skin resource missing, broken, or not this skin" % skin_id, true)
		return
	if skin.tile_fill.size() != SkinData.RAMP_SIZE or not skin.palette.has(&"bg"):
		_record(false, "  %s: tile_fill needs %d colors and the palette needs bg" % [skin_id, SkinData.RAMP_SIZE], true)
		return
	print("%s (%s)" % [skin.display_name, skin.resource_path])
	var bg: Vector3 = oklab(skin.color(&"bg"))
	var count: int = skin.tile_fill.size()
	var worst: PackedFloat32Array = [INF, INF, INF]
	for i: int in count:
		var a: Vector3 = oklab(skin.tile_fill[i])
		_record(a.distance_to(bg) >= MIN_AGAINST_BG, "  %s against the background: %.3f" % [MockState.tile_label(2 << i), a.distance_to(bg)], false)
		for step: int in [1, 2, 3]:
			var j: int = i + step
			if j >= count:
				continue
			var distance: float = a.distance_to(oklab(skin.tile_fill[j]))
			worst[step - 1] = minf(worst[step - 1], distance)
			var ok: bool = distance >= MIN_BY_STEP[step - 1]
			_record(ok, "  %s and %s (times %d): %.3f" % [MockState.tile_label(2 << i), MockState.tile_label(2 << j), 1 << step, distance], step == 1)
	print("  closest: neighbors %.3f, times 4 %.3f, times 8 %.3f" % [worst[0], worst[1], worst[2]])


## Counts a check. Neighbor pairs and failures are printed; the rest only count.
func _record(ok: bool, text: String, always_print: bool) -> void:
	_checked += 1
	if not ok:
		_failed += 1
	if always_print or not ok:
		print("%s%s" % ["PASS" if ok else "FAIL", text])


## sRGB color to OKLab (L, a, b).
static func oklab(c: Color) -> Vector3:
	var r: float = _linear(c.r)
	var g: float = _linear(c.g)
	var b: float = _linear(c.b)
	var l: float = pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1.0 / 3.0)
	var m: float = pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1.0 / 3.0)
	var s: float = pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1.0 / 3.0)
	return Vector3(
		0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


static func _linear(channel: float) -> float:
	if channel <= 0.04045:
		return channel / 12.92
	return pow((channel + 0.055) / 1.055, 2.4)
