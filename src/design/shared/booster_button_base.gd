extends "res://src/design/shared/press_button.gd"
## What the three skins' booster buttons share: the booster a button shows
## and how a BoosterStatus maps to its look, cost label and Suggested badge.
## Each skin's button extends this and draws the looks.

## The booster this button shows.
var booster_id: StringName = &""
## SkinIcon.LOOK_NORMAL, LOOK_ACTIVE (targeting) or LOOK_DISABLED (not usable).
var look: int = SkinIcon.LOOK_NORMAL
## The cost as a tile label (D-32): 2K, never 2,048.
var cost_text: String = ""
## Marked as the suggested rescue (D-42).
var suggested: bool = false


func setup(skin: SkinData) -> void:
	_skin = skin
	_on_setup()
	_apply(look)


## Shows one status. The look follows the status: active while targeting,
## else disabled when not usable, else normal.
func show_status(status: BoosterStatus) -> void:
	var was: int = look
	var new_id: bool = status.id != booster_id
	booster_id = status.id
	cost_text = NumberFormat.tile_label(status.cost)
	suggested = status.suggested
	if status.active:
		look = SkinIcon.LOOK_ACTIVE
	elif not status.usable:
		look = SkinIcon.LOOK_DISABLED
	else:
		look = SkinIcon.LOOK_NORMAL
	enabled = look != SkinIcon.LOOK_DISABLED
	if not enabled and held:
		_set_held(false)
		scale = Vector2.ONE
	if new_id:
		_on_booster_changed()
	_apply(was)
	_layout()


## Called by setup(), for the skin to read its tokens and build its parts.
func _on_setup() -> void:
	pass


## Called when the button starts showing another booster.
func _on_booster_changed() -> void:
	pass


## Applies the current look, cost and suggested flag. was is the previous
## look, so a pulse starts only when a button becomes active.
func _apply(_was: int) -> void:
	queue_redraw()


## Places the parts in the current size.
func _layout() -> void:
	queue_redraw()


func _notification(what: int) -> void:
	# Also lay out on entering the tree: a control sized outside the tree gets
	# no resize notification.
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_POST_ENTER_TREE:
		_layout()
