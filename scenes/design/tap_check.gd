extends Control
## QA6-01 check through a live viewport: every pressable control the design
## area builds (UiKit.make_icon_button, the toggles, the HUD pause buttons and
## the booster buttons, in every skin) must react exactly once to one tap,
## whichever way the tap arrives.
##
## The test runner works before the scene tree starts, where no viewport
## routes input, so this runs as its own scene and pushes real events into
## the root viewport, as Godot does on a phone:
##   godot --headless --path . res://scenes/design/tap_check.tscn
## It prints one line per failure and exits with code 0 when every control
## reacted exactly once to every way of tapping, and 1 otherwise.
## tests/design/test_tap_input.gd runs it and checks the exit code.

## The ways a tap arrives. On a phone Godot sends the emulated mouse button
## (device DEVICE_ID_EMULATION) before each touch event; with the emulation
## off only the touch arrives; on Windows a real mouse; with touch emulated
## from the mouse, the mouse and an emulated touch; and a focused control
## gets ui_accept from Enter or, where the input map adds it, a gamepad's A
## button (Godot 4.7's default map has no gamepad event for ui_accept, so
## this check adds one while it runs).
const WAYS: PackedStringArray = [
	"touch with the emulated mouse", "touch alone", "mouse", "mouse with an emulated touch", "Enter key", "gamepad A",
]

var _failures: PackedStringArray = PackedStringArray()
var _heard: int = 0


func _ready() -> void:
	size = Vector2(1080.0, 2400.0)
	Input.emulate_mouse_from_touch = false
	Input.emulate_touch_from_mouse = false
	var pad_accept: InputEventJoypadButton = InputEventJoypadButton.new()
	pad_accept.button_index = JOY_BUTTON_A
	InputMap.action_add_event(&"ui_accept", pad_accept)
	# Let the tree and the viewport settle first.
	await get_tree().process_frame
	await get_tree().process_frame
	for skin_id: StringName in SkinCatalog.IDS:
		_check_skin(SkinCatalog.get_skin(skin_id))
	for failure: String in _failures:
		print("FAIL " + failure)
	print("tap check: %d failures" % _failures.size())
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _check_skin(skin: SkinData) -> void:
	var button: BaseButton = UiKit.make_icon_button(skin, &"settings")
	add_child(button)
	button.position = Vector2(100.0, 100.0)
	button.pressed.connect(_on_heard)
	_check(skin, "icon button", button)
	button.toggle_mode = true
	_check(skin, "icon button in toggle mode", button)
	button.queue_free()

	var toggle: SkinToggle = UiKit.make_toggle(skin)
	add_child(toggle)
	toggle.position = Vector2(100.0, 400.0)
	toggle.toggled.connect(func(_on: bool) -> void: _on_heard())
	_check(skin, "toggle", toggle)
	toggle.queue_free()

	var hud: SkinHud = UiKit.make_hud(skin)
	add_child(hud)
	hud.position = Vector2(0.0, 700.0)
	hud.size = Vector2(1080.0, hud.preferred_height())
	hud.pause_pressed.connect(_on_heard)
	_check(skin, "HUD pause", hud.get_node(^"Pause") as Control)
	hud.queue_free()

	var bar: SkinBoosterBar = UiKit.make_booster_bar(skin)
	add_child(bar)
	bar.position = Vector2(0.0, 1500.0)
	bar.size = Vector2(1080.0, bar.preferred_height())
	var statuses: Array[BoosterStatus] = []
	for id: StringName in [&"hammer", &"swap", &"shuffle", &"double", &"undo"]:
		var status: BoosterStatus = BoosterStatus.new()
		status.id = id
		status.cost = 128
		status.usable = true
		statuses.append(status)
	bar.show_boosters(statuses)
	bar.booster_pressed.connect(func(_id: StringName) -> void: _on_heard())
	var buttons: Array[Control] = bar.call(&"buttons") as Array[Control]
	_check(skin, "booster button", buttons[2])
	bar.queue_free()


## Taps control every way and checks it reacted exactly once each time.
func _check(skin: SkinData, what: String, control: Control) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	for way: String in WAYS:
		_heard = 0
		var keyed: bool = way == "Enter key" or way == "gamepad A"
		var old_focus: Control.FocusMode = control.focus_mode
		if keyed:
			control.focus_mode = Control.FOCUS_ALL
			control.grab_focus()
		for event: InputEvent in _tap_events(way, at):
			get_viewport().push_input(event, true)
		if keyed:
			control.release_focus()
			control.focus_mode = old_focus
		if _heard != 1:
			_failures.append("%s %s: %s reacted %d times" % [skin.id, what, way, _heard])


func _tap_events(way: String, at: Vector2) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	match way:
		"touch with the emulated mouse":
			for down: bool in [true, false]:
				events.append(_mouse(down, at, InputEvent.DEVICE_ID_EMULATION))
				events.append(_touch(down, at, 0))
		"touch alone":
			events.append(_touch(true, at, 0))
			events.append(_touch(false, at, 0))
		"mouse":
			events.append(_mouse(true, at, 0))
			events.append(_mouse(false, at, 0))
		"mouse with an emulated touch":
			for down: bool in [true, false]:
				events.append(_mouse(down, at, 0))
				events.append(_touch(down, at, InputEvent.DEVICE_ID_EMULATION))
		"Enter key":
			for down: bool in [true, false]:
				var key: InputEventKey = InputEventKey.new()
				key.keycode = KEY_ENTER
				key.physical_keycode = KEY_ENTER
				key.pressed = down
				events.append(key)
		"gamepad A":
			for down: bool in [true, false]:
				var pad: InputEventJoypadButton = InputEventJoypadButton.new()
				pad.button_index = JOY_BUTTON_A
				pad.pressed = down
				events.append(pad)
	return events


func _mouse(down: bool, at: Vector2, device: int) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.device = device
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.pressed = down
	event.position = at
	event.global_position = at
	return event


func _touch(down: bool, at: Vector2, device: int) -> InputEventScreenTouch:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.device = device
	event.index = 0
	event.pressed = down
	event.position = at
	return event


func _on_heard() -> void:
	_heard += 1
