class_name SkinTileView extends Control
## One tile on its own, as one skin draws it (docs/ARCHITECTURE.md section 6):
## the settings skin chips, the merge preview in a HUD slot, the main menu
## and the end of run screen.
##
## The tile is a square of side min(size.x, size.y), centered in the rect.
## Rings, rims and glows may reach a little outside it. Each skin subclasses
## this and implements both methods; the methods here only report a subclass
## that forgot one. Create a view through SkinCatalog.make_tile_view(skin).


func _init() -> void:
	# The tile draws only. Whatever holds it handles input.
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(_skin: SkinData) -> void:
	_missing("setup")


## The tile value. 0 shows nothing.
func set_value(_value: int) -> void:
	_missing("set_value")


func _missing(method_name: String) -> void:
	var script_path: String = ""
	var own_script: Script = get_script() as Script
	if own_script != null:
		script_path = own_script.resource_path
	push_error("%s does not implement SkinTileView.%s()" % [script_path, method_name])
