extends RefCounted
## The interface words the design components show on their own
## (DESIGN_SYSTEM.md 7.10 and the booster names of GDD section 13). Screens
## write their own copy and pass it in (hints, context text).

const NOTICE_ONE: String = "No more {a}s"
const NOTICE_TWO: String = "No more {a}s or {b}s"
const NOTICE_RANGE: String = "No more {a}s to {b}s"
const SUGGESTED: String = "Suggested"

const BOOSTER_NAMES: Dictionary[StringName, String] = {
	&"hammer": "Hammer",
	&"swap": "Swap",
	&"shuffle": "Shuffle",
	&"double": "Double",
	&"undo": "Undo",
}


## The clear notice copy for the cleared values (ascending), cased with the
## skin's rule for role. Only the words take the case rule: the values keep
## the tile label format exactly, so 2K never becomes 2k (DESIGN_SYSTEM.md
## 2.5). "" for no values.
static func clear_notice(skin: SkinData, role: StringName, values: PackedInt64Array) -> String:
	if values.is_empty():
		return ""
	var low: String = NumberFormat.tile_label(values[0])
	var high: String = NumberFormat.tile_label(values[values.size() - 1])
	var template: String = NOTICE_RANGE
	if values.size() == 1:
		template = NOTICE_ONE
	elif values.size() == 2:
		template = NOTICE_TWO
	return _fill(skin, role, template, low, high)


## A booster's name, cased with role.
static func booster_name(skin: SkinData, role: StringName, booster_id: StringName) -> String:
	return skin.cased(role, BOOSTER_NAMES.get(booster_id, String(booster_id)))


## The template with {a} and {b} replaced by the labels and every other part
## cased.
static func _fill(skin: SkinData, role: StringName, template: String, a: String, b: String) -> String:
	var out: String = ""
	var rest: String = template
	while not rest.is_empty():
		var start: int = rest.find("{")
		if start < 0:
			out += skin.cased(role, rest)
			break
		var finish: int = rest.find("}", start)
		out += skin.cased(role, rest.substr(0, start))
		var key: String = rest.substr(start + 1, finish - start - 1)
		out += a if key == "a" else b
		rest = rest.substr(finish + 1)
	return out
