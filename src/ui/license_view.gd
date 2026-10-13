extends "res://src/ui/reading_screen.gd"
## One license text (DESIGN_SYSTEM.md 7.14), opened from an About row inside
## AboutPanel: a reading screen titled "SumUp license", "Godot Engine" or
## "Outfit font". The text sits straight on the backdrop in every skin, no
## card: paragraphs in the reading role space_s apart, headings in the
## heading role with space_m above, part and license names in the body role.
## The texts are reflowed for the phone (license_texts.gd).
##
## One label per paragraph, never one label for the whole text. Laying out a
## wrapped label shapes its whole text, and these texts run to tens of
## kilobytes, so each label is shaped once only: it joins the page first (so
## it has its final font), takes the page's width, and only then gets its
## text. The header shows at once; the paragraphs follow from the next frame,
## when the page has its width, as many per frame as fit in a few
## milliseconds, so opening never stalls a frame.

const LicenseTexts: GDScript = preload("res://src/ui/license_texts.gd")
## Time spent building labels in one frame, in microseconds.
const FRAME_BUDGET_USEC: int = 6000

var _id: StringName = &""
var _blocks: Array[Dictionary] = []
var _built: int = 0
var _labels: int = 0
var _body: VBoxContainer = null
## Time from setup to the last label, in microseconds; 0 while building.
var build_usec: int = 0
var _started_usec: int = 0


func setup(skin: SkinData, id: StringName) -> void:
	_id = id
	_started_usec = Time.get_ticks_usec()
	build_usec = 0
	_frame(skin, String(Copy.LICENSE_TITLES.get(id, "")))
	_body = UiParts.vbox(skin.num(&"space_s"))
	_body.name = "Text"
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sections.add_child(_body)
	_blocks = LicenseTexts.blocks(id)
	_built = 0
	_labels = 0
	if is_inside_tree() and not get_tree().process_frame.is_connected(_next_batch):
		get_tree().process_frame.connect(_next_batch)


## Rebuilds the view in a new skin, still open.
func apply_skin(skin: SkinData) -> void:
	setup(skin, _id)


## The license shown.
func license_id() -> StringName:
	return _id


## True once every paragraph has its label.
func is_built() -> bool:
	return _built >= _blocks.size()


## Builds every label left now. For tests and captures.
func finish() -> void:
	_build(-1, _body.size.x if _body != null else 0.0)


## Everything the view shows, label by label, blank lines between.
func shown_text() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for block: Dictionary in _blocks:
		parts.append(_shown(block))
	return "\n\n".join(parts)


## The labels built so far. For tests.
func label_count() -> int:
	return _labels


func _next_batch() -> void:
	if _closing or not is_inside_tree():
		_stop_batches()
		return
	# Wait for the page's first layout: a label shaped before it has its
	# width would be shaped again.
	if _body.size.x <= 0.0:
		return
	_build(FRAME_BUDGET_USEC, _body.size.x)


## Builds labels until budget_usec is spent (-1 for all), each given width
## before its text so its text is shaped once. Each call's labels go in a
## column of their own, so laying out the page later sorts a few columns
## rather than every label built so far.
func _build(budget_usec: int, width: float) -> void:
	if _built >= _blocks.size():
		return
	var start: int = Time.get_ticks_usec()
	var batch: VBoxContainer = UiParts.vbox(_skin.num(&"space_s"))
	batch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(batch)
	if width > 0.0:
		batch.size = Vector2(width, batch.size.y)
	while _built < _blocks.size():
		if budget_usec >= 0 and Time.get_ticks_usec() - start >= budget_usec:
			break
		var block: Dictionary = _blocks[_built]
		var kind: int = int(block["kind"])
		if kind == LicenseTexts.Kind.HEADING and _built > 0:
			batch.add_child(UiParts.spacer(_skin.num(&"space_m") - _skin.num(&"space_s")))
		var variation: StringName = &"ReadingLabel"
		if kind == LicenseTexts.Kind.HEADING:
			variation = &"HeadingLabel"
		elif kind == LicenseTexts.Kind.NAME:
			variation = &"BodyLabel"
		var made: Label = UiParts.paragraph(_skin, variation, "", HORIZONTAL_ALIGNMENT_LEFT)
		made.mouse_filter = Control.MOUSE_FILTER_IGNORE
		batch.add_child(made)
		if width > 0.0:
			made.size = Vector2(width, made.size.y)
		made.text = _shown(block)
		if budget_usec >= 0:
			# Shape it now, inside the budget, rather than all at once later.
			made.get_minimum_size()
		_built += 1
		_labels += 1
	if is_built():
		_stop_batches()
		if build_usec == 0:
			build_usec = Time.get_ticks_usec() - _started_usec


func _stop_batches() -> void:
	if is_inside_tree() and get_tree().process_frame.is_connected(_next_batch):
		get_tree().process_frame.disconnect(_next_batch)


## The text a block shows: headings take the heading role's case rule;
## names, paragraphs and the missing text message show as written.
func _shown(block: Dictionary) -> String:
	if int(block["kind"]) == LicenseTexts.Kind.HEADING:
		return _skin.cased(&"heading", String(block["text"]))
	return String(block["text"])


func _exit_tree() -> void:
	_stop_batches()
