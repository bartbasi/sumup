extends "res://tests/base_test.gd"
## The reading screens on their own (DESIGN_SYSTEM.md 7.11 to 7.14): How to
## play (GDD D-44, TH21, AT-115, AT-116), About (TH22, AT-141) and the license
## texts (AT-142), and the rows that open a screen.

const U := preload("res://tests/ui/ui_fixtures.gd")
const Copy := preload("res://src/ui/screen_copy.gd")
const LicenseTexts := preload("res://src/ui/license_texts.gd")
const OpenRow := preload("res://src/ui/open_row.gd")

const GDD_PATH: String = "res://docs/GDD.md"

var _hosts: Array[Control] = []
var _stages: Array[Control] = []
var _taps: int = 0
var _dir: String = ""


func before_each() -> void:
	_hosts = []
	_stages = []
	_taps = 0
	_dir = ""
	SafeArea.simulated_insets = Vector2(120.0, 66.0)


func after_each() -> void:
	for host: Control in _hosts:
		if is_instance_valid(host):
			host.get_parent().remove_child(host)
			host.free()
	for host: Control in _stages:
		U.free_stage(host)
	SafeArea.simulated_insets = Vector2(-1.0, -1.0)
	if not _dir.is_empty():
		U.remove_temp_dir(_dir)


func _host(skin_id: StringName) -> Control:
	var host: Control = Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.theme = UiKit.build_theme(SkinCatalog.get_skin(skin_id))
	U.root().add_child(host)
	_hosts.append(host)
	return host


func _how_to_play(skin_id: StringName) -> HowToPlayPanel:
	var panel: HowToPlayPanel = (load("res://scenes/ui/how_to_play_panel.tscn") as PackedScene).instantiate() as HowToPlayPanel
	_host(skin_id).add_child(panel)
	panel.setup(SkinCatalog.get_skin(skin_id))
	return panel


func _about(skin_id: StringName) -> AboutPanel:
	var panel: AboutPanel = (load("res://scenes/ui/about_panel.tscn") as PackedScene).instantiate() as AboutPanel
	_host(skin_id).add_child(panel)
	panel.setup(SkinCatalog.get_skin(skin_id))
	return panel


func _count_tap() -> void:
	_taps += 1


## GDD 21.2's table rows, read from the GDD itself: [title, text, example,
## result] per row, the example as values and "none" as empty / 0.
func _gdd_sections() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var text: String = FileAccess.get_file_as_string(GDD_PATH)
	var row_name: RegEx = RegEx.create_from_string("^HP[1-7]$")
	for line: String in text.split("\n"):
		var cells: PackedStringArray = line.split("|")
		# The 21.2 table: | HP1 | title | text | example | result |
		if cells.size() != 7 or row_name.search(cells[1].strip_edges()) == null:
			continue
		var example: PackedInt64Array = PackedInt64Array()
		var example_text: String = cells[4].strip_edges()
		if example_text != "none":
			for value: String in example_text.split(","):
				example.append(int(value.strip_edges()))
		var result_text: String = cells[5].strip_edges()
		var result: int = 0
		if result_text == "2K":
			result = 2048
		elif result_text != "none":
			result = int(result_text)
		rows.append({"title": cells[2].strip_edges(), "text": cells[3].strip_edges(), "example": example, "result": result})
	return rows


# How to play: TH21 and AT-116

func test_at_116_th21_content_is_gdd_21_2_word_for_word() -> void:
	var expected: Array[Dictionary] = _gdd_sections()
	assert_eq(expected.size(), 7, "the GDD lists seven sections")
	var panel: HowToPlayPanel = _how_to_play(&"gumdrop")
	var content: Array[Dictionary] = panel.content()
	assert_eq(content.size(), 7, "seven sections")
	for index: int in mini(content.size(), expected.size()):
		var section: Dictionary = content[index]
		var gdd: Dictionary = expected[index]
		assert_eq(section["title"], gdd["title"], "HP%d title" % (index + 1))
		assert_eq(section["text"], gdd["text"], "HP%d text, word for word" % (index + 1))
		assert_eq(section["example"], gdd["example"], "HP%d example row" % (index + 1))
		assert_eq(section["result"], gdd["result"], "HP%d result tile" % (index + 1))
		var words: int = String(section["title"]).split(" ", false).size()
		assert_true(words >= 1 and words <= 4, "HP%d title is 1 to 4 words" % (index + 1))
		assert_eq(String(section["text"]).count(". "), 1, "HP%d text is 2 sentences" % (index + 1))
		assert_true(String(section["text"]).ends_with("."), "HP%d text ends a sentence" % (index + 1))
	assert_eq(panel.title_text(), "How to play", "the screen title")


func test_at_116_example_rows_check_out_on_the_rules_model() -> void:
	var config: GameConfig = GameConfig.new()
	var rows: int = 0
	for section: Dictionary in Copy.how_to_play_sections():
		var example: PackedInt64Array = section["example"]
		if example.is_empty():
			assert_eq(section["result"], 0, "no row, no result")
			continue
		rows += 1
		# Laid out as touching cells along the top row of a board of 2s.
		var cells: PackedInt64Array = PackedInt64Array()
		cells.resize(config.cell_count())
		cells.fill(2)
		var chain: Array[Vector2i] = []
		for index: int in example.size():
			cells[index] = example[index]
			chain.append(Vector2i(index, 0))
		assert_true(CoreRules.is_valid_chain(cells, chain, config), "%s: a valid chain" % str(example))
		assert_eq(CoreRules.merge_result(example), section["result"], "%s: its result is the merge result" % str(example))
	assert_eq(rows, 3, "three example rows")
	assert_eq(NumberFormat.tile_label(1024), "1024", "the label 1024")
	assert_eq(NumberFormat.tile_label(2048), "2K", "the label 2K")


func test_content_is_a_copy() -> void:
	var panel: HowToPlayPanel = _how_to_play(&"slate")
	var content: Array[Dictionary] = panel.content()
	content[0]["title"] = "Changed"
	assert_eq(panel.content()[0]["title"], "Make a chain", "changing the copy changes nothing")


# How to play: AT-115 (the UI half)

func test_at_115_rows_are_real_tiles_in_each_skin() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var skin: SkinData = SkinCatalog.get_skin(skin_id)
		var panel: HowToPlayPanel = _how_to_play(skin_id)
		var rows: Array[HBoxContainer] = panel.example_rows()
		assert_eq(rows.size(), 3, "%s: three example rows" % skin_id)
		var expected: Array[PackedInt64Array] = [PackedInt64Array([2, 2, 4]), PackedInt64Array([2, 2, 2]), PackedInt64Array([1024, 1024])]
		for index: int in rows.size():
			var row: HBoxContainer = rows[index]
			var board: SkinBoardView = row.get_child(0) as SkinBoardView
			assert_not_null(board, "%s row %d: the chain is the skin's own board view" % [skin_id, index])
			var script: Script = board.get_script() as Script
			assert_true(script.resource_path.contains(String(skin_id)), "%s row %d: drawn by %s's board view" % [skin_id, index, skin_id])
			assert_near(board.custom_minimum_size.y, board.preferred_height(board.custom_minimum_size.x), 0.01, "%s row %d: sized by its own height" % [skin_id, index])
			var arrow: SkinIcon = row.get_node("Arrow") as SkinIcon
			assert_not_null(arrow, "%s row %d: the arrow" % [skin_id, index])
			assert_eq(arrow.custom_minimum_size, Vector2(56.0, 56.0), "%s: a 56 px arrow" % skin_id)
			var result: SkinTileView = row.get_node("Result") as SkinTileView
			assert_not_null(result, "%s row %d: the result is the skin's tile view" % [skin_id, index])
			assert_eq(result.custom_minimum_size, Vector2(112.0, 112.0), "%s: a 112 px result tile" % skin_id)
			assert_true(result.get_index() > arrow.get_index() and arrow.get_index() > board.get_index(), "%s row %d: chain, arrow, then the result, set apart" % [skin_id, index])
			assert_eq(row.get_child(1).custom_minimum_size.x, skin.num(&"space_m"), "%s: space_m before the arrow" % skin_id)
			assert_eq(expected[index].size(), int(board.get(&"columns")), "%s row %d: one tile per chain value" % [skin_id, index])
			assert_eq(int(board.get(&"rows")), 1, "%s row %d: a one row board" % [skin_id, index])
		_assert_takes_no_input(panel.sections(), skin_id)


func _assert_takes_no_input(node: Node, label: String) -> void:
	for child: Node in node.find_children("*", "Control", true, false):
		if child is OpenRow:
			assert_eq((child as Control).mouse_filter, Control.MOUSE_FILTER_PASS, "%s: rows pass drags on" % label)
		elif not (child.get_parent() is OpenRow) and not _inside_row(child):
			assert_eq((child as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s: %s ignores the mouse" % [label, child.name])


func _inside_row(node: Node) -> bool:
	var parent: Node = node.get_parent()
	while parent != null:
		if parent is OpenRow:
			return true
		parent = parent.get_parent()
	return false


func test_reading_screen_frame() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var skin: SkinData = SkinCatalog.get_skin(skin_id)
		var panel: HowToPlayPanel = _how_to_play(skin_id)
		var scroll: ScrollContainer = panel.scroll()
		assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED, "%s: vertical only" % skin_id)
		assert_eq(scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_RESERVE, "%s: the indicator's room is kept" % skin_id)
		assert_eq(scroll.scroll_deadzone, 24, "%s: the 24 px deadzone" % skin_id)
		assert_false(scroll.follow_focus, "%s: no follow focus" % skin_id)
		assert_eq(panel.mouse_filter, Control.MOUSE_FILTER_STOP, "%s: opaque to touch" % skin_id)
		var header: HBoxContainer = panel.find_child("Header", true, false) as HBoxContainer
		assert_eq(header.custom_minimum_size.y, skin.num(&"touch_min"), "%s: the header is touch_min tall" % skin_id)
		var hairlines: int = panel.find_child("Page", true, false).get_child(1).find_children("*", "HSeparator", true, false).size()
		assert_eq(hairlines > 0, skin_id == &"slate", "%s: a hairline under the header only in Slate" % skin_id)
		var sections: VBoxContainer = panel.sections()
		var expected_gap: int = 0 if skin_id == &"slate" else roundi(skin.num(&"space_l") if skin_id == &"nova" else skin.num(&"space_s"))
		assert_eq(sections.get_theme_constant(&"separation"), expected_gap, "%s: the section gap" % skin_id)
		for label: Node in panel.find_children("*", "Label", true, false):
			var made: Label = label as Label
			assert_eq(made.custom_minimum_size.x, 0.0, "%s: %s sets no minimum width" % [skin_id, made.name])
			if made.get_parent().get_parent() is PanelContainer and made.theme_type_variation in [&"HeadingLabel", &"ReadingLabel"]:
				assert_eq(made.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "%s: %s wraps" % [skin_id, made.name])
	var slate: HowToPlayPanel = _how_to_play(&"slate")
	var heading: Label = slate.sections().find_children("*", "Label", true, false)[0] as Label
	assert_eq(heading.text, SkinCatalog.get_skin(&"slate").cased(&"heading", "Make a chain"), "headings take the heading role's case")


## A reading screen on a stage of size_px, laid out.
func _staged(scene: String, skin_id: StringName, size_px: Vector2i) -> Control:
	var host: Control = U.stage(size_px, skin_id)
	_stages.append(host)
	var panel: Control = (load(scene) as PackedScene).instantiate() as Control
	host.add_child(panel)
	U.fit(panel, Vector2(size_px))
	var skin: SkinData = SkinCatalog.get_skin(skin_id)
	panel.call(&"setup", skin)
	var safe: Rect2 = U.safe_rect(size_px)
	panel.call(&"layout_in", Rect2(Vector2.ZERO, Vector2(size_px)), safe, SafeArea.column_in(safe, skin))
	return panel


func test_reading_screen_fits_the_content_column() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var skin: SkinData = SkinCatalog.get_skin(skin_id)
		for size_px: Vector2i in [Vector2i(1080, 2400), Vector2i(1998, 2400)]:
			var panel: HowToPlayPanel = _staged("res://scenes/ui/how_to_play_panel.tscn", skin_id, size_px) as HowToPlayPanel
			var page: Control = panel.find_child("Page", true, false) as Control
			var column: Rect2 = SafeArea.column_in(U.safe_rect(size_px), skin)
			var label: String = "%s %s" % [skin_id, size_px]
			assert_eq(page.position.y, 120.0, "%s: the header starts at the safe area's top" % label)
			assert_eq(page.position.y + page.size.y, float(size_px.y), "%s: the page runs to the screen's bottom edge" % label)
			assert_eq(page.position.x, column.position.x, "%s: in the content column" % label)
			assert_eq(page.size.x, column.size.x, "%s: as wide as it" % label)
			if size_px.x == 1080:
				assert_eq(page.size.x, 1080.0, "%s: a phone's column is the whole width" % label)
			else:
				assert_true(page.size.x < float(size_px.x), "%s: a wide screen gets a centered column" % label)
				assert_near(page.position.x * 2.0 + page.size.x, float(size_px.x), 0.01, "%s: centered" % label)
			var pad: MarginContainer = panel.find_child("Pad", true, false) as MarginContainer
			assert_eq(pad.get_theme_constant(&"margin_bottom"), roundi(skin.num(&"space_xl") + 66.0), "%s: the end clears the gesture bar" % label)
	var gumdrop: HowToPlayPanel = _how_to_play(&"gumdrop")
	var pad_left: MarginContainer = gumdrop.find_child("Pad", true, false) as MarginContainer
	var skin_g: SkinData = SkinCatalog.get_skin(&"gumdrop")
	assert_eq(pad_left.get_theme_constant(&"margin_left"), roundi(skin_g.num(&"board_margin")), "board_margin on the left")
	assert_eq(pad_left.get_theme_constant(&"margin_right"), 0, "the indicator fills the right margin")
	assert_eq(pad_left.get_theme_constant(&"margin_top"), roundi(skin_g.num(&"space_s")), "space_s on top")


func test_close_button_reports_and_close_stops_input() -> void:
	var panel: HowToPlayPanel = _how_to_play(&"nova")
	panel.closed.connect(_count_tap)
	panel.close_button().pressed.emit()
	assert_eq(_taps, 1, "the close control reports")
	panel.close()
	assert_true(panel.is_closing(), "closing")
	panel.close_button().pressed.emit()
	assert_eq(_taps, 1, "a closing screen takes no input")
	assert_eq(panel.mouse_filter, Control.MOUSE_FILTER_IGNORE, "and lets touches through while it fades")


# About: TH22 and AT-141

func test_at_141_about_shows_what_it_is_and_who_made_it() -> void:
	for skin_id: StringName in SkinCatalog.IDS:
		var panel: AboutPanel = _about(skin_id)
		var info: String = panel.info_text()
		assert_true(info.contains("Copyright 2026 Bart Basi"), "%s: the exact attribution" % skin_id)
		assert_true(info.begins_with("SumUp"), "%s: the game's name first" % skin_id)
		assert_true(info.contains("Made by Bart Basi"), "%s: who made it" % skin_id)
		assert_true(info.contains("works fully offline") and info.contains("collects no data"), "%s: offline and no data" % skin_id)
		var version: String = str(ProjectSettings.get_setting("application/config/version", ""))
		assert_false(version.is_empty(), "the project sets a version")
		assert_true(Copy.version_line().ends_with(version), "the Settings line shows it")
		assert_true(info.to_lower().contains("version %s" % version), "%s: About shows the same version" % skin_id)
		var copyright: Label = panel.copyright_label()
		assert_eq(copyright.text, "Copyright 2026 Bart Basi", "%s: never cased" % skin_id)
		assert_eq(copyright.theme_type_variation, &"BodyLabel", "%s: in the body role, never muted" % skin_id)
		assert_eq(copyright.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING, "%s: never truncated" % skin_id)
		assert_false(copyright.has_theme_font_size_override(&"font_size"), "%s: never shrunk" % skin_id)


func test_at_141_attribution_is_in_the_first_screenful() -> void:
	# Headless tests cannot lay containers out, so this adds up the line
	# heights above the attribution's last line: the safe top, the header, the
	# page's top padding, a section's top padding, the wordmark, the version,
	# space_m, "Made by Bart Basi" and the attribution itself. On a 16:9 phone
	# (the shortest screen, 2400 px tall like every canvas) that must end well
	# inside the scroll area (DESIGN_SYSTEM.md 7.13: about 700 px down).
	for skin_id: StringName in SkinCatalog.IDS:
		var skin: SkinData = SkinCatalog.get_skin(skin_id)
		var panel: AboutPanel = _about(skin_id)
		var brand: Control = panel.find_child("Brand", true, false) as Control
		assert_eq(brand.get_parent(), panel.sections(), "%s: the brand block is the first thing in the scroll area" % skin_id)
		assert_eq(brand.get_index(), 0, "%s: first" % skin_id)
		var lines: Array[Label] = []
		for label: Node in brand.find_children("*", "Label", true, false):
			lines.append(label as Label)
		assert_eq(lines.back(), panel.copyright_label(), "%s: the attribution ends the brand block" % skin_id)
		var bottom: float = 120.0 + skin.num(&"touch_min") + skin.num(&"space_s") * 2.0 + skin.num(&"space_m") * 2.0
		for label: Label in lines:
			var role: StringName = &"display" if label.theme_type_variation == &"DisplayLabel" else (&"label" if label.theme_type_variation == &"CaptionLabel" else &"body")
			var line_height: float = skin.font(role).get_height(skin.font_size(role))
			if label.get_parent().name == &"Wordmark" and label.get_index() > 0:
				continue
			bottom += line_height + skin.num(&"space_xs")
		assert_true(bottom < 1000.0, "%s: the attribution ends about %d px down, in the first screenful" % [skin_id, roundi(bottom)])
		assert_true(bottom < 2400.0 - 66.0 - 400.0, "%s: well inside the scroll area" % skin_id)


func test_about_wordmark_and_rows() -> void:
	var nova: AboutPanel = _about(&"nova")
	var parts: Array[Node] = nova.find_child("Wordmark", true, false).get_children()
	assert_eq(parts.size(), 2, "two labels")
	assert_eq((parts[0] as Label).text, "Sum", "Sum")
	assert_eq((parts[1] as Label).text, "Up", "Up")
	var skin: SkinData = SkinCatalog.get_skin(&"nova")
	assert_eq((parts[0] as Label).get_theme_color(&"font_color"), skin.color(&"ink"), "Sum in ink")
	assert_eq((parts[1] as Label).get_theme_color(&"font_color"), skin.color(&"accent"), "Up in accent")
	assert_false((parts[0] as Label).has_theme_font_size_override(&"font_size"), "at the display size, not fitted")
	var rows: Dictionary[StringName, Control] = nova.license_rows()
	assert_eq(rows.keys(), [&"game", &"godot", &"outfit"], "three license rows in order")
	assert_eq(rows[&"godot"].call(&"detail_text"), "MIT license and its parts", "Nova keeps the names' capitals")
	var slate: AboutPanel = _about(&"slate")
	assert_eq(slate.license_rows()[&"game"].call(&"detail_text"), "GNU GPL VERSION 3, TWO ADDED TERMS", "Slate capitals may apply")
	for id: StringName in rows:
		var row: Control = rows[id]
		assert_true(row.custom_minimum_size.y >= skin.num(&"touch_min"), "%s: at least touch_min tall" % id)


# License texts: AT-142

func test_at_142_game_license_matches_its_sources() -> void:
	var panel: AboutPanel = _about(&"gumdrop")
	var notice: String = FileAccess.get_file_as_string("res://NOTICE")
	var copying: String = FileAccess.get_file_as_string("res://COPYING")
	assert_true(notice.length() > 100 and copying.length() > 30000, "both files are there")
	var expected: String = "Notice\n" + notice + "\nGNU General Public License\n" + copying
	assert_eq(LicenseTexts.squeeze(panel.license_text(&"game")), LicenseTexts.squeeze(expected), "NOTICE then COPYING, whitespace normalized")


func test_at_142_outfit_license_matches_its_source() -> void:
	var panel: AboutPanel = _about(&"gumdrop")
	var ofl: String = FileAccess.get_file_as_string("res://src/design/fonts/OFL.txt")
	assert_true(ofl.contains("SIL OPEN FONT LICENSE"), "OFL.txt is there")
	assert_eq(LicenseTexts.squeeze(panel.license_text(&"outfit")), LicenseTexts.squeeze(ofl), "OFL.txt, whitespace normalized")


func test_at_142_godot_license_matches_the_engine() -> void:
	var panel: AboutPanel = _about(&"slate")
	var skin: SkinData = SkinCatalog.get_skin(&"slate")
	var parts: PackedStringArray = PackedStringArray([skin.cased(&"heading", "Godot Engine license"), Engine.get_license_text(), skin.cased(&"heading", "Third party parts")])
	var components: int = 0
	for component: Dictionary in Engine.get_copyright_info():
		components += 1
		parts.append(String(component["name"]))
		for part: Dictionary in component["parts"]:
			for line: String in part["copyright"]:
				parts.append("Copyright " + line)
			parts.append("License: " + String(part["license"]))
	parts.append(skin.cased(&"heading", "License texts"))
	var licenses: Dictionary = Engine.get_license_info()
	for license_name: String in licenses:
		parts.append(license_name)
		parts.append(String(licenses[license_name]))
	assert_true(components > 10 and licenses.size() > 5, "the engine lists its parts and licenses")
	var shown: String = panel.license_text(&"godot")
	assert_eq(LicenseTexts.squeeze(shown), LicenseTexts.squeeze(" ".join(parts)), "every part and license text, whitespace normalized")
	assert_true(shown.contains("GODOT ENGINE LICENSE"), "Slate's headings in capitals")


func test_reflow_rules() -> void:
	var text: String = "Line one\nstill one  with   spaces.\n\n  Two\r\n\r\nThree\n   \nFour\n"
	assert_eq(LicenseTexts.reflow(text), PackedStringArray(["Line one still one with spaces.", "Two", "Three", "Four"]), "blank lines split, every other break and run of spaces is one space")
	assert_eq(LicenseTexts.squeeze("  a\t\nb  "), "a b", "squeeze")


func test_a_damaged_license_file_shows_a_plain_message() -> void:
	_dir = U.make_temp_dir()
	var wrong: String = _dir.path_join("COPYING")
	U.SaveFixtures.write_text(wrong, "x".repeat(35149))
	assert_eq(LicenseTexts.read_checked(wrong, "GNU GENERAL PUBLIC LICENSE", "Version 3"), "", "the right length with the wrong contents is refused")
	var with_nul: PackedByteArray = "GNU GENERAL PUBLIC LICENSE Version 3".to_utf8_buffer()
	with_nul.append(0)
	U.SaveFixtures.write_bytes(_dir.path_join("with_zero.txt"), with_nul)
	assert_eq(LicenseTexts.read_checked(_dir.path_join("with_zero.txt"), "GNU GENERAL PUBLIC LICENSE", "Version 3"), "", "a NUL byte is refused")
	assert_eq(LicenseTexts.read_checked(_dir.path_join("missing"), "", ""), "", "a missing file gives nothing")
	U.SaveFixtures.write_text(_dir.path_join("good"), "  GNU GENERAL PUBLIC LICENSE\n Version 3, 29 June 2007")
	assert_ne(LicenseTexts.read_checked(_dir.path_join("good"), "GNU GENERAL PUBLIC LICENSE", "Version 3"), "", "the right text reads")
	for path: String in [LicenseTexts.NOTICE_PATH, LicenseTexts.COPYING_PATH, LicenseTexts.OFL_PATH]:
		assert_ne(LicenseTexts.read_license_file(path), "", "%s reads and looks like itself" % path)
	assert_false(Copy.TEXT_MISSING.contains("--"), "the message is plain")


func test_license_view_opens_inside_about_one_label_per_paragraph() -> void:
	var panel: AboutPanel = _about(&"gumdrop")
	panel.license_rows()[&"outfit"].emit_signal(&"tapped")
	var view: Control = panel.license_view()
	assert_not_null(view, "the row opens the text")
	assert_eq(view.get_parent(), panel, "inside About")
	assert_eq(view.call(&"title_text"), "Outfit font", "titled")
	view.call(&"finish")
	assert_true(view.call(&"is_built"), "built")
	var paragraphs: int = LicenseTexts.reflow(FileAccess.get_file_as_string("res://src/design/fonts/OFL.txt")).size()
	assert_eq(int(view.call(&"label_count")), paragraphs, "one label per paragraph")
	assert_eq(view.call(&"shown_text"), panel.license_text(&"outfit"), "what it shows is the license text")
	assert_true(panel.close_license(), "closing the text")
	assert_null(panel.license_view(), "it is gone")
	assert_false(panel.close_license(), "a second close finds none")


func test_godot_license_view_builds_in_batches() -> void:
	var panel: AboutPanel = _about(&"nova")
	panel.open_license(&"godot")
	var view: Control = panel.license_view()
	assert_eq(view.call(&"title_text"), "Godot Engine", "the header at once")
	assert_false(view.call(&"is_built"), "the paragraphs follow frame by frame, never all in the opening frame")
	view.call(&"finish")
	assert_true(view.call(&"is_built"), "then complete")
	assert_eq(int(view.call(&"label_count")), LicenseTexts.blocks(&"godot").size(), "one label per block")


# Rows that open a screen (7.11)

func _press(row: Control, at: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.global_position = at
	event.position = at
	row._gui_input(event)


func _move(row: Control, at: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.global_position = at
	event.position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	row._gui_input(event)


func test_a_row_opens_only_on_a_tap() -> void:
	var panel: AboutPanel = _about(&"gumdrop")
	var row: Control = panel.license_rows()[&"game"]
	row.connect(&"tapped", _count_tap)
	_press(row, Vector2(100, 100), true)
	assert_true(row.call(&"is_held"), "pressed look while held")
	_press(row, Vector2(110, 108), false)
	assert_eq(_taps, 1, "down and up within the deadzone: a tap")
	assert_false(row.call(&"is_held"), "released")

	_press(row, Vector2(100, 100), true)
	_move(row, Vector2(100, 140))
	assert_false(row.call(&"is_held"), "a drag past 24 px cancels the press")
	_press(row, Vector2(100, 101), false)
	assert_eq(_taps, 1, "a drag that starts on a row never opens it")

	_press(row, Vector2(100, 100), true)
	panel.scroll().scroll_vertical = 30
	_press(row, Vector2(100, 100), false)
	assert_eq(_taps, 1, "a scroll in between: no tap")

	_press(row, Vector2(100, 100), false)
	assert_eq(_taps, 1, "a release without a press does nothing")
	assert_eq(row.mouse_filter, Control.MOUSE_FILTER_PASS, "it passes events on to the scroll area")


func test_a_row_ignores_other_buttons() -> void:
	var panel: AboutPanel = _about(&"slate")
	var row: Control = panel.license_rows()[&"godot"]
	row.connect(&"tapped", _count_tap)
	var right: InputEventMouseButton = InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	row._gui_input(right)
	right.pressed = false
	row._gui_input(right)
	assert_eq(_taps, 0, "only the left button or a touch")
