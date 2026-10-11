class_name PausePanel extends "res://src/ui/dialog_base.gd"
## Pause (DESIGN_SYSTEM.md 7.3): "Paused", then Resume (primary), New game
## and Settings (secondary). Opened by the HUD's pause button or Android back
## during play; back resumes. The App cancels the drag and targeting before it
## opens this panel (docs/ARCHITECTURE.md section 11, flow 9).

signal resume_chosen()
signal new_game_chosen()
signal settings_chosen()


func setup(skin: SkinData) -> void:
	_frame(skin)
	_content.add_theme_constant_override(&"separation", roundi(skin.num(&"space_s")))
	_content.add_child(UiParts.label(skin, &"TitleLabel", Copy.PAUSED, UiParts.block_alignment(skin)))
	_content.add_child(_choice(skin, &"PrimaryButton", Copy.RESUME, resume_chosen))
	_content.add_child(_choice(skin, &"SecondaryButton", Copy.NEW_GAME, new_game_chosen))
	_content.add_child(_choice(skin, &"SecondaryButton", Copy.SETTINGS, settings_chosen))


## Rebuilds the panel in a new skin, still open.
func apply_skin(skin: SkinData) -> void:
	setup(skin)


func _choice(skin: SkinData, variation: StringName, text: String, chosen: Signal) -> Button:
	var made: Button = UiParts.button(skin, variation, text)
	made.name = text.replace(" ", "")
	made.pressed.connect(_emit.bind(chosen))
	return made


func _emit(chosen: Signal) -> void:
	if not _closing:
		chosen.emit()
