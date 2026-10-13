class_name AboutPanel extends "res://src/ui/reading_screen.gd"
## About (DESIGN_SYSTEM.md 7.13, GDD AT-141), a reading screen opened from
## Settings' About row:
## - the brand block on the backdrop in every skin: the two tone wordmark at
##   the display size, "Version {version}" (the version the Settings line
##   shows), space_m, then "Made by Bart Basi" and "Copyright 2026 Bart Basi"
##   in the body role. The attribution is a license term: never cased, muted,
##   shrunk or truncated, and in the first screenful;
## - the sections "What it is", "Offline, no data" and "Licenses", the last
##   ending in three rows that open a license text, split by the divider.
## A license row opens that license's text inside this screen
## (license_view.gd). Android back closes the text first, then About.

const LicenseTexts: GDScript = preload("res://src/ui/license_texts.gd")
const LicenseView: GDScript = preload("res://src/ui/license_view.gd")

var _license: Control = null
var _rows: Dictionary[StringName, Control] = {}
var _copyright: Label = null


func setup(skin: SkinData) -> void:
	var open_id: StringName = (_license.call(&"license_id") as StringName) if _license != null else &""
	if _license != null:
		_license.queue_free()
		_license = null
	_frame(skin, Copy.ABOUT)
	_rows = {}
	_brand(skin)
	for index: int in Copy.ABOUT_SECTIONS.size():
		var section: Dictionary = Copy.ABOUT_SECTIONS[index]
		var column: VBoxContainer = _add_section()
		column.add_child(_heading(String(section["title"])))
		column.add_child(_reading(String(section["text"])))
		if index == Copy.ABOUT_SECTIONS.size() - 1:
			column.add_child(UiParts.spacer(skin.num(&"space_m") - skin.num(&"space_xs")))
			_license_rows(column)
	_quiet(_sections)
	if open_id != &"":
		open_license(open_id)


## Rebuilds the screen in a new skin, still open, with any open text.
func apply_skin(skin: SkinData) -> void:
	setup(skin)


## TH22. Everything the About screen shows above the license rows, one line
## per label, in order.
func info_text() -> String:
	var lines: PackedStringArray = PackedStringArray([UiParts.WORDMARK_PARTS[0] + UiParts.WORDMARK_PARTS[1]])
	var version: String = Copy.version_text()
	if not version.is_empty():
		lines.append(_skin.cased(UiParts.role(_skin, &"CaptionLabel"), version))
	lines.append(Copy.MADE_BY)
	lines.append(Copy.COPYRIGHT)
	for section: Dictionary in Copy.ABOUT_SECTIONS:
		lines.append(_skin.cased(&"heading", String(section["title"])))
		lines.append(String(section["text"]))
	return "\n".join(lines)


## TH22. The full text a license row opens: &"game" (NOTICE, then COPYING),
## &"godot" (the engine's license and every part with its license texts),
## &"outfit" (OFL.txt). Every label's text, blank lines between, as shown.
func license_text(id: StringName) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for block: Dictionary in LicenseTexts.blocks(id):
		if int(block["kind"]) == LicenseTexts.Kind.HEADING:
			parts.append(_skin.cased(&"heading", String(block["text"])))
		else:
			parts.append(String(block["text"]))
	return "\n\n".join(parts)


## Opens a license text over this screen. An unknown id does nothing.
func open_license(id: StringName) -> void:
	if _closing or not LicenseTexts.IDS.has(id):
		return
	close_license()
	var view: Control = LicenseView.new()
	view.name = "License"
	add_child(view)
	view.call(&"setup", _skin, id)
	view.connect(&"closed", close_license)
	view.call(&"play_in")
	_license = view


## Closes the open license text. False when none was open.
func close_license() -> bool:
	if _license == null:
		return false
	var view: Control = _license
	_license = null
	view.call(&"close")
	return true


## The open license text view, or null. For tests and the back button.
func license_view() -> Control:
	return _license


## The row that opens each license, by id. For tests.
func license_rows() -> Dictionary[StringName, Control]:
	return _rows


## The attribution label. For tests: never cased, in the first screenful.
func copyright_label() -> Label:
	return _copyright


## The brand block, on the backdrop, its text lined up with the sections'
## text: an unboxed panel padded like a section.
func _brand(skin: SkinData) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Brand"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(&"panel", _brand_box())
	_sections.add_child(panel)
	var column: VBoxContainer = UiParts.vbox(skin.num(&"space_xs"))
	panel.add_child(column)
	column.add_child(UiParts.wordmark(skin, 0, true))
	var version: String = Copy.version_text()
	if not version.is_empty():
		var version_label: Label = UiParts.paragraph(skin, &"CaptionLabel", version, HORIZONTAL_ALIGNMENT_LEFT)
		version_label.name = "Version"
		column.add_child(version_label)
	column.add_child(UiParts.spacer(skin.num(&"space_m") - skin.num(&"space_xs")))
	column.add_child(_statement("MadeBy", Copy.MADE_BY))
	_copyright = _statement("Copyright", Copy.COPYRIGHT)
	column.add_child(_copyright)


## A line in the body role exactly as written: never cased.
func _statement(node_name: String, text: String) -> Label:
	var made: Label = UiParts.paragraph(_skin, &"BodyLabel", "", HORIZONTAL_ALIGNMENT_LEFT)
	made.name = node_name
	made.text = text
	return made


## No box, padded like a section, so the brand's text starts where the
## sections' text does.
func _brand_box() -> StyleBox:
	var box: StyleBoxEmpty = StyleBoxEmpty.new()
	var section: StyleBox = get_theme_stylebox(&"panel", &"SectionPanel") if is_inside_tree() else null
	if section != null:
		box.content_margin_left = section.content_margin_left
		box.content_margin_right = section.content_margin_right
		box.content_margin_top = section.content_margin_top
		box.content_margin_bottom = section.content_margin_bottom
	return box


func _license_rows(column: VBoxContainer) -> void:
	for index: int in Copy.LICENSE_ROWS.size():
		var entry: Dictionary = Copy.LICENSE_ROWS[index]
		if index > 0:
			column.add_child(UiParts.divider())
		var row: Control = _open_row(String(entry["title"]), String(entry["detail"]))
		var id: StringName = entry["id"]
		row.name = "Row_%s" % id
		row.connect(&"tapped", open_license.bind(id))
		column.add_child(row)
		_rows[id] = row
