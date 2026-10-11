extends SkinHud
## Nova HUD (DESIGN_SYSTEM.md 6.7), hud_height tall, no containers:
## - the score centered in the display role (light), auto fitting a slot
##   kept clear of the pause ring on both sides (2.6);
## - under it, "best 96,520" in the label role, its letters starting space_xs
##   below the score's comma tail (the comma reaches below the baseline, so
##   space_xs under the baseline alone would let the two touch);
## - the best line sits space_xs above where the clear notice reaches into
##   the HUD (the notice is centered on the board's top edge, space_s below
##   the HUD), so the notice never covers it; the score sits above it;
## - the pause icon in a hud_ring ring at the top right, its edge on
##   board_margin, its touch area touch_min.
## Text pairs: ink and ink_muted on bg_glow.
##
## The clear notice is a badge pill (a full pill, no lip), notice_height tall,
## centered on the board's top edge, its copy in the label role. It fades in
## from from_alpha while rising from_offset px (clear_notice), holds, and
## fades out over out with the skin's screen_fade curve.

const ThemeKit: GDScript = preload("res://src/design/shared/theme_kit.gd")
const PauseButton: GDScript = preload("res://src/design/nova/nova_pause_button.gd")
const ClearNotice: GDScript = preload("res://src/design/shared/clear_notice.gd")

## Draw order above the board, so the notice shows over the board's top edge.
const NOTICE_Z_INDEX: int = 10
## Cap height and comma depth (DESIGN_SYSTEM.md 3.4), defined once.
const FontMetrics: GDScript = preload("res://src/design/shared/font_metrics.gd")

var _skin: SkinData = null
var _pause: PauseButton = null
var _score: Label = null
var _notice: ClearNotice = null
var _notice_tween: Tween = null
var _score_text: String = ""
var _best_text: String = ""
var _label_font: Font = null
var _label_size: int = 1
var _best_origin: Vector2 = Vector2.ZERO


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
	_label_font = skin.font(&"label")
	_label_size = skin.font_size(&"label")
	if _score_text.is_empty():
		set_scores(0, 0)
	_layout()


func set_scores(score: int, best_score: int) -> void:
	_score_text = NumberFormat.score(score)
	# The word takes the label case (lowercase); the number keeps its commas.
	_best_text = _skin.cased(&"label", "Best") + " " + NumberFormat.score(best_score) if _skin != null else ""
	_score.text = _score_text
	_layout()


## Nova has no context row.
func set_context(_text: String, _highlight: bool) -> void:
	pass


## Nova shows the merge preview on the board.
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
	_notice = ClearNotice.new()
	_notice.name = "ClearNotice"
	_notice.top_level = true
	_notice.z_index = NOTICE_Z_INDEX
	add_child(_notice)
	var pad: float = _skin.num(&"space_s")
	var pill: StyleBoxFlat = ThemeKit.box(_skin.color(&"badge"), height * 0.5)
	_notice.build(_skin, cleared_values, &"label", pill, height, 0.0, pad, pad, board_rect.size.x)
	var rest: Vector2 = Vector2(board_rect.get_center().x - _notice.size.x * 0.5, board_rect.position.y - height * 0.5)
	var spec: Dictionary = _skin.motion_spec(&"clear_notice")
	var seconds: float = _skin.duration(&"clear_notice")
	_notice.global_position = rest + Vector2(0.0, float(spec.get("from_offset", 0.0)))
	_notice.modulate.a = float(spec.get("from_alpha", 1.0))
	_notice_tween = Motion.tween_for(_notice, _skin, &"clear_notice")
	_notice_tween.set_parallel(true)
	_notice_tween.tween_property(_notice, "global_position", rest, seconds)
	_notice_tween.tween_property(_notice, "modulate:a", 1.0, seconds)
	_notice_tween.chain().tween_interval(float(spec.get("hold", 0.0)))
	var fade: Dictionary = _skin.motion_spec(&"screen_fade")
	_notice_tween.chain().tween_property(_notice, "modulate:a", 0.0, float(spec.get("out", 0.0))) \
		.set_trans(int(fade.get("trans", Tween.TRANS_LINEAR)) as Tween.TransitionType) \
		.set_ease(int(fade.get("ease", Tween.EASE_IN_OUT)) as Tween.EaseType)
	_notice_tween.chain().tween_callback(_on_notice_done)


## The notice showing now, or null. For tests.
func clear_notice() -> Control:
	return _notice


## The best line as shown. For tests.
func best_text() -> String:
	return _best_text


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
	var ring: float = _skin.num(&"hud_ring")
	# The ring's edge lines up with the right margin; its touch area reaches past it.
	_pause.position = Vector2(size.x - margin - (touch + ring) * 0.5, 0.0)
	_pause.size = Vector2(touch, touch)

	# The best line's baseline sits space_xs above the top of the clear notice,
	# which is centered on the board's top edge, space_s under the HUD.
	var gap: float = _skin.num(&"space_xs")
	var notice_top: float = _skin.num(&"hud_height") + _skin.num(&"space_s") - _skin.num(&"notice_height") * 0.5
	var best_baseline: float = minf(notice_top, _skin.num(&"hud_height")) - gap
	_best_origin = Vector2(0.0, best_baseline)
	# The score's comma tail ends space_xs above the best line's letters.
	var display_size: int = _skin.font_size(&"display")
	var letters_top: float = best_baseline - FontMetrics.CAP_HEIGHT * float(_label_size)
	var baseline: float = letters_top - gap - FontMetrics.COMMA_DEPTH * float(display_size)

	# The score, centered in a slot clear of the ring on both sides.
	var clear: float = margin + ring + _skin.num(&"space_xs")
	var slot_width: float = size.x - clear * 2.0
	var fitted: int = _skin.font_size(&"display")
	if slot_width > 0.0:
		fitted = _skin.score_font_size(_score_text, slot_width)
	_score.add_theme_font_size_override(&"font_size", fitted)
	var display: Font = _skin.font(&"display")
	_score.position = Vector2(clear, baseline - display.get_ascent(fitted))
	_score.size = Vector2(maxf(slot_width, 0.0), display.get_height(fitted))
	queue_redraw()


func _draw() -> void:
	if _skin == null:
		return
	draw_string(_label_font, _best_origin, _best_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, _label_size, _skin.color(&"ink_muted"))
