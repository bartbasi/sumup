extends SkinHud
## Slate HUD (DESIGN_SYSTEM.md 5.7), hud_height tall, left aligned:
## - "SCORE" in the label role over the score in the display role, from
##   board_margin. The score's digits start space_xs under the caption.
## - On the right: the pause icon (no container, full touch area) at the top,
##   and "BEST" over the Best Score in the body role, the number on the
##   score's baseline, right edge on board_margin.
## - A hairline under the header, then the context row, hint_height tall, at
##   the bottom:
##     while dragging, "CHAIN n" on the left and the preview slot on the right
##     (a square hint_height tall, the preview tile at preview_scale of the
##     board tile: 112 px at the full spec size);
##     in targeting, a full width badge bar with the hint;
##     otherwise empty, or the clear notice.
## The score fits the width left of the BEST column (2.6).
## Text pairs: ink and ink_muted on bg, badge_ink on badge.
##
## The clear notice takes the context row for its hold time: a full width
## badge bar, the struck mini tiles from space_m, then the copy in the label
## role. It cuts in and out with clear_notice. While the context row is busy
## (a chain being dragged, a targeting hint), the notice waits, and its hold
## time only runs while it shows.

const ThemeKit: GDScript = preload("res://src/design/shared/theme_kit.gd")
const PauseButton: GDScript = preload("res://src/design/slate/slate_pause_button.gd")
const ClearNotice: GDScript = preload("res://src/design/shared/clear_notice.gd")

## Cap height and comma depth (DESIGN_SYSTEM.md 3.4), defined once.
const FontMetrics: GDScript = preload("res://src/design/shared/font_metrics.gd")

var _skin: SkinData = null
var _pause: PauseButton = null
var _score: Label = null
var _slot: Control = null
var _notice: ClearNotice = null
var _notice_tween: Tween = null
var _score_text: String = ""
var _best_text: String = ""
var _score_caption: String = ""
var _best_caption: String = ""
var _context: String = ""
var _highlight: bool = false
var _label_font: Font = null
var _label_size: int = 1
var _body_font: Font = null
var _body_size: int = 1
var _score_baseline: float = 0.0
var _score_caption_origin: Vector2 = Vector2.ZERO
var _best_caption_origin: Vector2 = Vector2.ZERO
var _best_origin: Vector2 = Vector2.ZERO
var _rule_rect: Rect2 = Rect2()
var _row_rect: Rect2 = Rect2()
var _context_origin: Vector2 = Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(skin: SkinData) -> void:
	_skin = skin
	if _pause == null:
		_pause = PauseButton.new()
		_pause.name = "Pause"
		_pause.tapped.connect(_on_pause_tapped)
		add_child(_pause)
		_score = Label.new()
		_score.name = "Score"
		_score.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_score)
		_slot = Control.new()
		_slot.name = "PreviewSlot"
		_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_slot)
	_pause.setup(skin)
	_score.add_theme_font_override(&"font", skin.font(&"display"))
	_score.add_theme_color_override(&"font_color", skin.color(&"ink"))
	_label_font = skin.font(&"label")
	_label_size = skin.font_size(&"label")
	_body_font = skin.font(&"body")
	_body_size = skin.font_size(&"body")
	_score_caption = skin.cased(&"label", "Score")
	_best_caption = skin.cased(&"label", "Best")
	if _score_text.is_empty():
		set_scores(0, 0)
	_layout()


func set_scores(score: int, best_score: int) -> void:
	_score_text = NumberFormat.score(score)
	_best_text = NumberFormat.score(best_score)
	_score.text = _score_text
	_layout()


func set_context(text: String, highlight: bool) -> void:
	_context = _skin.cased(&"label", text) if _skin != null else text
	_highlight = highlight
	_update_notice_wait()
	queue_redraw()


func preview_slot() -> Control:
	return _slot


func score_label() -> Label:
	return _score


func preferred_height() -> float:
	return _skin.num(&"hud_height") if _skin != null else 0.0


func show_clear_notice(cleared_values: PackedInt64Array, _board_rect: Rect2) -> void:
	if _skin == null or cleared_values.is_empty():
		return
	_drop_notice()
	var height: float = _skin.num(&"hint_height")
	var pad: float = _skin.num(&"space_m")
	_notice = ClearNotice.new()
	_notice.name = "ClearNotice"
	add_child(_notice)
	var bar: StyleBoxFlat = ThemeKit.box(_skin.color(&"badge"), 0.0)
	_notice.build(_skin, cleared_values, &"label", bar, height, 0.0, pad, pad, size.x)
	_place_notice()
	var spec: Dictionary = _skin.motion_spec(&"clear_notice")
	_notice.modulate.a = 0.0
	_notice_tween = Motion.tween_for(_notice, _skin, &"clear_notice")
	_notice_tween.tween_property(_notice, "modulate:a", 1.0, _skin.duration(&"clear_notice"))
	_notice_tween.tween_interval(float(spec.get("hold", 0.0)))
	_notice_tween.tween_property(_notice, "modulate:a", 0.0, float(spec.get("out", 0.0)))
	_notice_tween.tween_callback(_on_notice_done)
	_update_notice_wait()


## The notice in the context row now (waiting or showing), or null. For tests.
func clear_notice() -> Control:
	return _notice


## The context text as shown, cased. For tests.
func context_text() -> String:
	return _context


## The notice waits while the context row is busy and runs while it is free.
func _update_notice_wait() -> void:
	if _notice == null:
		if _slot != null:
			_slot.visible = true
		return
	var busy: bool = not _context.is_empty()
	_notice.visible = not busy
	_slot.visible = busy
	if _notice_tween != null and _notice_tween.is_valid():
		if busy:
			_notice_tween.pause()
		else:
			_notice_tween.play()


func _place_notice() -> void:
	if _notice == null:
		return
	_notice.position = _row_rect.position
	_notice.size = Vector2(maxf(_row_rect.size.x, _notice.content_width()), _row_rect.size.y)


func _on_notice_done() -> void:
	_notice_tween = null
	_drop_notice()


func _drop_notice() -> void:
	if _notice_tween != null and _notice_tween.is_valid():
		_notice_tween.kill()
	_notice_tween = null
	if _notice != null:
		remove_child(_notice)
		_notice.queue_free()
		_notice = null
	if _slot != null:
		_slot.visible = true


func _on_pause_tapped() -> void:
	pause_pressed.emit()


func _notification(what: int) -> void:
	# Also lay out on entering the tree: a control sized outside the tree gets
	# no resize notification.
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_POST_ENTER_TREE:
		_layout()


func _layout() -> void:
	if _skin == null or _pause == null:
		return
	var margin: float = _skin.num(&"board_margin")
	var touch: float = _skin.num(&"touch_min")
	var icon: float = _skin.num(&"icon_hud")
	var hairline: float = _skin.num(&"hairline")
	var row_height: float = _skin.num(&"hint_height")

	# The icon's box lines up with the right margin; its touch area reaches past it.
	_pause.position = Vector2(size.x - margin - (touch + icon) * 0.5, 0.0)
	_pause.size = Vector2(touch, touch)

	# SCORE caption, then the score's digits space_xs under it.
	var caption_line: float = _label_font.get_height(_label_size)
	_score_caption_origin = Vector2(margin, _label_font.get_ascent(_label_size))
	var display_size: int = _skin.font_size(&"display")
	_score_baseline = caption_line + _skin.num(&"space_xs") + FontMetrics.CAP_HEIGHT * float(display_size)

	# BEST column on the right: the number on the score's baseline, the
	# caption's line right above the number's line.
	var best_width: float = _body_font.get_string_size(_best_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _body_size).x
	var best_caption_width: float = _label_font.get_string_size(_best_caption, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _label_size).x
	_best_origin = Vector2(size.x - margin - best_width, _score_baseline)
	var number_top: float = _score_baseline - _body_font.get_ascent(_body_size)
	_best_caption_origin = Vector2(size.x - margin - best_caption_width, number_top - _label_font.get_descent(_label_size))

	# The score fits the width left of the BEST column.
	var column: float = maxf(best_width, best_caption_width)
	var slot_width: float = size.x - margin * 2.0 - column - _skin.num(&"space_s")
	var fitted: int = display_size
	if slot_width > 0.0:
		fitted = _skin.score_font_size(_score_text, slot_width)
	_score.add_theme_font_size_override(&"font_size", fitted)
	var display: Font = _skin.font(&"display")
	_score.position = Vector2(margin, _score_baseline - display.get_ascent(fitted))
	_score.size = Vector2(maxf(slot_width, 0.0), display.get_height(fitted))

	# The context row at the bottom, the hairline right above it.
	var row_top: float = _skin.num(&"hud_height") - row_height
	_rule_rect = Rect2(margin, row_top - hairline, size.x - margin * 2.0, hairline)
	_row_rect = Rect2(0.0, row_top, size.x, row_height)
	_slot.position = Vector2(size.x - margin - row_height, row_top)
	_slot.size = Vector2(row_height, row_height)
	var line: float = _label_font.get_height(_label_size)
	_context_origin = Vector2(margin, row_top + (row_height - line) * 0.5 + _label_font.get_ascent(_label_size))
	_place_notice()
	queue_redraw()


func _draw() -> void:
	if _skin == null:
		return
	var muted: Color = _skin.color(&"ink_muted")
	draw_string(_label_font, _score_caption_origin, _score_caption, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _label_size, muted)
	draw_string(_label_font, _best_caption_origin, _best_caption, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _label_size, muted)
	draw_string(_body_font, _best_origin, _best_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _body_size, _skin.color(&"ink"))
	draw_rect(_rule_rect, _skin.color(&"line"))
	if _context.is_empty():
		return
	if _highlight:
		draw_rect(_row_rect, _skin.color(&"badge"))
		draw_string(_label_font, _context_origin, _context, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _label_size, _skin.color(&"badge_ink"))
	else:
		draw_string(_label_font, _context_origin, _context, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _label_size, _skin.color(&"ink"))
