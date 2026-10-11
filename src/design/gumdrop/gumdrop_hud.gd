extends SkinHud
## Gumdrop HUD (DESIGN_SYSTEM.md 4.7), hud_height tall:
## - the top row, hud_top_row tall: the pause button on the left (a raised
##   squircle face hud_button_face wide at board_margin, touch area
##   touch_min), and a Best pill on the right (surface with a surface_lip lip,
##   pill_height tall, pill_radius corners, sides padded space_s; "Best" in
##   the label role ink_muted, the number in the body role ink);
## - under it, the score centered in the display role, auto fitting the width
##   inside board_margin (2.6), its comma tail space_xs above the top of the
##   clear notice. No caption.
## Text pairs: ink on bg, ink_muted and ink on surface.
##
## The clear notice is a lemon badge pill with a badge_lip lip, notice_height
## tall, centered on the board's top edge. It springs in from from_scale,
## holds, and fades out over out with the skin's screen_fade curve.

const Candy: GDScript = preload("res://src/design/gumdrop/gumdrop_candy.gd")
const PauseButton: GDScript = preload("res://src/design/gumdrop/gumdrop_pause_button.gd")
const ClearNotice: GDScript = preload("res://src/design/shared/clear_notice.gd")
## Cap height and comma depth (DESIGN_SYSTEM.md 3.4), defined once.
const FontMetrics: GDScript = preload("res://src/design/shared/font_metrics.gd")

## Draw order above the board, so the notice shows over the board's top edge.
const NOTICE_Z_INDEX: int = 10

var _skin: SkinData = null
var _pause: PauseButton = null
var _score: Label = null
var _notice: ClearNotice = null
var _notice_tween: Tween = null
var _pill: StyleBoxFlat = null
var _best_caption: String = ""
var _best_text: String = ""
var _score_text: String = ""
var _caption_font: Font = null
var _caption_size: int = 1
var _number_font: Font = null
var _number_size: int = 1
var _pill_rect: Rect2 = Rect2()
var _caption_origin: Vector2 = Vector2.ZERO
var _number_origin: Vector2 = Vector2.ZERO


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
		_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(_score)
	_pause.setup(skin)
	_score.add_theme_font_override(&"font", skin.font(&"display"))
	_score.add_theme_color_override(&"font_color", skin.color(&"ink"))
	_pill = Candy.raised(skin.color(&"surface"), skin.color(&"surface_lip"), skin.num(&"pill_radius"), skin.num(&"button_lip"))
	_caption_font = skin.font(&"label")
	_caption_size = skin.font_size(&"label")
	_number_font = skin.font(&"body")
	_number_size = skin.font_size(&"body")
	_best_caption = skin.cased(&"label", "Best")
	if _score_text.is_empty():
		set_scores(0, 0)
	_layout()


func set_scores(score: int, best_score: int) -> void:
	_score_text = NumberFormat.score(score)
	_best_text = NumberFormat.score(best_score)
	_score.text = _score_text
	_layout()


## Gumdrop has no context row.
func set_context(_text: String, _highlight: bool) -> void:
	pass


## Gumdrop shows the merge preview on the board.
func preview_slot() -> Control:
	return null


func score_label() -> Label:
	return _score


func preferred_height() -> float:
	return _skin.num(&"hud_height") if _skin != null else 0.0


func show_clear_notice(cleared_values: PackedInt64Array, board_rect: Rect2) -> void:
	if _skin == null or cleared_values.is_empty():
		return
	_drop_notice()
	var height: float = _skin.num(&"notice_height")
	var lip: float = _skin.num(&"button_lip")
	_notice = ClearNotice.new()
	_notice.name = "ClearNotice"
	_notice.top_level = true
	_notice.z_index = NOTICE_Z_INDEX
	add_child(_notice)
	var pad: float = _skin.num(&"space_s")
	_notice.build(_skin, cleared_values, &"body", Candy.badge(_skin, height - lip), height, lip, pad, pad, board_rect.size.x)
	_notice.global_position = Vector2(board_rect.get_center().x - _notice.size.x * 0.5, board_rect.position.y - height * 0.5)
	_notice.pivot_offset = _notice.size * 0.5
	var spec: Dictionary = _skin.motion_spec(&"clear_notice")
	var from_scale: float = maxf(float(spec.get("from_scale", 1.0)), Motion.MIN_SCALE)
	_notice.scale = Vector2(from_scale, from_scale)
	_notice_tween = Motion.tween_for(_notice, _skin, &"clear_notice")
	_notice_tween.tween_property(_notice, "scale", Vector2.ONE, _skin.duration(&"clear_notice"))
	_notice_tween.tween_interval(float(spec.get("hold", 0.0)))
	var fade: Dictionary = _skin.motion_spec(&"screen_fade")
	_notice_tween.tween_property(_notice, "modulate:a", 0.0, float(spec.get("out", 0.0))) \
		.set_trans(int(fade.get("trans", Tween.TRANS_LINEAR)) as Tween.TransitionType) \
		.set_ease(int(fade.get("ease", Tween.EASE_IN_OUT)) as Tween.EaseType)
	_notice_tween.tween_callback(_on_notice_done)


## The notice showing now, or null. For tests.
func clear_notice() -> Control:
	return _notice


func _drop_notice() -> void:
	if _notice_tween != null and _notice_tween.is_valid():
		_notice_tween.kill()
	_notice_tween = null
	if _notice != null:
		remove_child(_notice)
		_notice.queue_free()
		_notice = null


func _on_notice_done() -> void:
	_notice_tween = null
	_drop_notice()


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
	var face: float = _skin.num(&"hud_button_face")
	var touch: float = _skin.num(&"touch_min")
	var lip: float = _skin.num(&"button_lip")
	# The face's left edge on the margin; the touch area centered across it.
	_pause.position = Vector2(margin + face * 0.5 - touch * 0.5, 0.0)
	_pause.size = Vector2(touch, touch)

	# Best pill, its face centered on the pause face, right edge on the margin.
	var pad: float = _skin.num(&"space_s")
	var gap: float = _skin.num(&"space_xs")
	var caption_width: float = _caption_font.get_string_size(_best_caption, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _caption_size).x
	var number_width: float = _number_font.get_string_size(_best_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _number_size).x
	var pill_height: float = _skin.num(&"pill_height")
	var pill_face: float = pill_height - lip
	var pill_width: float = pad + caption_width + gap + number_width + pad
	_pill_rect = Rect2(size.x - margin - pill_width, face * 0.5 - pill_face * 0.5, pill_width, pill_height)
	# Both texts share one baseline, the digits centered on the face.
	var baseline: float = _pill_rect.position.y + pill_face * 0.5 + _number_font.get_ascent(_number_size) * 0.5 \
		- _number_font.get_descent(_number_size) * 0.5
	_caption_origin = Vector2(_pill_rect.position.x + pad, baseline)
	_number_origin = Vector2(_caption_origin.x + caption_width + gap, baseline)

	# Score: centered, fitted to the width inside the margins. Its comma tail
	# ends space_xs above the top of the clear notice, which is centered on the
	# board's top edge space_s under the HUD; it stays put with or without one.
	var width: float = size.x - margin * 2.0
	var fitted: int = _skin.font_size(&"display")
	if width > 0.0:
		fitted = _skin.score_font_size(_score_text, width)
	_score.add_theme_font_size_override(&"font_size", fitted)
	var display: Font = _skin.font(&"display")
	var notice_top: float = _skin.num(&"hud_height") + _skin.num(&"space_s") - _skin.num(&"notice_height") * 0.5
	var score_baseline: float = notice_top - _skin.num(&"space_xs") - FontMetrics.COMMA_DEPTH * float(fitted)
	_score.position = Vector2(margin, score_baseline - display.get_ascent(fitted))
	_score.size = Vector2(maxf(width, 0.0), display.get_height(fitted))
	queue_redraw()


func _draw() -> void:
	if _skin == null:
		return
	draw_style_box(_pill, _pill_rect)
	draw_string(_caption_font, _caption_origin, _best_caption, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _caption_size, _skin.color(&"ink_muted"))
	draw_string(_number_font, _number_origin, _best_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _number_size, _skin.color(&"ink"))
