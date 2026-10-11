class_name SkinCatalog extends RefCounted
## The built in skins. Gumdrop is the default; Slate and Nova are the
## alternates, in settings order. There is no skin import of any kind.
##
## make_board_view(skin) and make_tile_view(skin) arrive in Phase 3 together
## with SkinBoardView, SkinTileView and the per skin views
## (docs/ARCHITECTURE.md section 6).

const DEFAULT_ID: StringName = &"gumdrop"
## Settings order.
const IDS: Array[StringName] = [&"gumdrop", &"slate", &"nova"]
const SKIN_PATH: String = "res://src/skins/%s/%s.tres"


## The skin with this id. An unknown id, for example from an old or damaged
## save, returns the default skin.
static func get_skin(id: StringName) -> SkinData:
	var skin_id: StringName = id if IDS.has(id) else DEFAULT_ID
	var skin: SkinData = load(SKIN_PATH % [skin_id, skin_id]) as SkinData
	if skin == null:
		push_error("could not load skin '%s'" % skin_id)
	return skin
