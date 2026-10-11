extends Control
## A pressable control drawn by a skin: the HUD pause buttons and the booster
## buttons. It presses with Motion.press while held and springs back with
## Motion.release, and emits tapped when the finger lifts inside it. A
## disabled one takes the touch and does nothing. Touches reach it as mouse
## events (Godot emulates the mouse from touch).

signal tapped()

## Whether a touch is down on it now.
var held: bool = false
## Whether it reacts to touch.
var enabled: bool = true

var _skin: SkinData = null


func _init() -> void:
	focus_mode = Control.FOCUS_NONE


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT or _skin == null:
		return
	accept_event()
	if not enabled:
		return
	if button.pressed:
		_set_held(true)
		Motion.press(self, _skin)
	elif held:
		_set_held(false)
		Motion.release(self, _skin)
		if Rect2(Vector2.ZERO, size).has_point(button.position):
			tapped.emit()


func _notification(what: int) -> void:
	# A button hidden while held would otherwise stay pressed.
	if what == NOTIFICATION_VISIBILITY_CHANGED and held and not is_visible_in_tree():
		_set_held(false)
		scale = Vector2.ONE


func _set_held(on: bool) -> void:
	held = on
	_held_changed()


## Called when held changes, for the skin to redraw its pressed look.
func _held_changed() -> void:
	queue_redraw()
