class_name GameScreen extends Control
## The play screen (docs/ARCHITECTURE.md section 11, DESIGN_SYSTEM.md 2.3 and
## 7.1). Top to bottom inside the safe area: the HUD, space_s, the board,
## space_s, the booster bar. The backdrop fills the whole screen. The board
## takes the widest size inside board_margin whose preferred height fits
## between the HUD and the bar; if it does not fit it shrinks evenly and stays
## centered.
##
## While the no moves offer is open, OfferPanel takes the HUD's place and the
## board shrinks to fit under it; the board and the bar stay usable (7.5).
##
## It mirrors the session into the components: scores into the HUD (counting
## up when a chain adds points), statuses into the bar and the offer, the
## targeting hint into the bar (Gumdrop, Nova) and the HUD context row
## (Slate), the chain into the context row and preview slot (Slate), and the
## clear notice (AT-104). Every color, size and timing comes from the skin.

signal pause_requested()

const BOARD_SCENE: PackedScene = preload("res://scenes/board/board.tscn")
const OFFER_SCENE: PackedScene = preload("res://scenes/ui/offer_panel.tscn")
const Copy: GDScript = preload("res://src/ui/screen_copy.gd")

const _NO_CELL: Vector2i = Vector2i(-1, -1)

var _session: GameSession = null
var _settings: Settings = null
var _audio: AudioService = null
var _skin: SkinData = null
var _backdrop: SkinBackdrop = null
var _board: BoardController = null
var _hud: SkinHud = null
var _bar: SkinBoosterBar = null
var _offer: OfferPanel = null
var _preview: SkinTileView = null
var _chain_context: String = ""
var _chain_preview: int = 0
var _shown_score: int = -1
## True from a chain's move_resolved to the status_changed that follows it.
var _chain_points_pending: bool = false


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Builds the screen for session in skin. Call it with the screen in the tree.
func setup(session: GameSession, settings: Settings, audio: AudioService, skin: SkinData) -> void:
	_session = session
	_settings = settings
	_audio = audio
	_skin = skin
	_board = BOARD_SCENE.instantiate() as BoardController
	_board.name = "Board"
	# The board scene fills its parent; here _layout places it by hand.
	_board.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_child(_board)
	_board.setup(session, skin, audio)
	_board.chain_changed.connect(_on_chain_changed)
	_offer = OFFER_SCENE.instantiate() as OfferPanel
	_offer.name = "Offer"
	_offer.visible = false
	add_child(_offer)
	_offer.booster_chosen.connect(_on_booster_pressed)
	_offer.end_run_chosen.connect(_on_end_run)
	_offer.minimum_size_changed.connect(_layout)
	session.status_changed.connect(_on_status_changed)
	session.targeting_changed.connect(_on_targeting_changed)
	session.offer_changed.connect(_on_offer_changed)
	session.move_resolved.connect(_on_move_resolved)
	session.run_started.connect(_on_run_started)
	_build_skinned(skin)
	_refresh()


## Live skin switch: a new backdrop, HUD and booster bar, the board's new
## view and the offer in the new look. The board keeps its state.
func apply_skin(skin: SkinData) -> void:
	_skin = skin
	_board.set_skin(skin)
	_build_skinned(skin)
	_refresh()


func board() -> BoardController:
	return _board


## The HUD in use. For tests and the App.
func hud() -> SkinHud:
	return _hud


## The booster bar in use. For tests.
func booster_bar() -> SkinBoosterBar:
	return _bar


## The offer panel; visible while the offer is open. For tests.
func offer_panel() -> OfferPanel:
	return _offer


func _build_skinned(skin: SkinData) -> void:
	for old: Control in [_backdrop, _hud, _bar]:
		if old != null:
			remove_child(old)
			old.queue_free()
	_preview = null
	_backdrop = UiKit.make_backdrop(skin)
	_backdrop.name = "Backdrop"
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)
	move_child(_backdrop, 0)
	_hud = UiKit.make_hud(skin)
	_hud.name = "Hud"
	add_child(_hud)
	_hud.pause_pressed.connect(_on_pause_pressed)
	var slot: Control = _hud.preview_slot()
	if slot != null:
		_preview = SkinCatalog.make_tile_view(skin)
		_preview.name = "Preview"
		_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_preview.visible = false
		slot.add_child(_preview)
	_bar = UiKit.make_booster_bar(skin)
	_bar.name = "BoosterBar"
	add_child(_bar)
	_bar.booster_pressed.connect(_on_booster_pressed)
	move_child(_offer, get_child_count() - 1)
	_offer.setup(skin)
	_shown_score = -1
	_layout()


## Re-reads everything from the session.
func _refresh() -> void:
	_show_status(false)
	_set_offer_open(_session.is_offer_open())
	_show_context()


func _show_status(count: bool) -> void:
	if _session == null or _hud == null:
		return
	var score: int = _session.state.score
	_hud.set_scores(score, _session.records.best_score)
	# Count up only for the points a chain just added. Any other change shows
	# at once; that call also replaces a count still running, so a stale count
	# can never overwrite the score.
	var from: int = score
	if count and _chain_points_pending and _shown_score >= 0 and score > _shown_score:
		from = _shown_score
	_chain_points_pending = false
	if is_inside_tree():
		Motion.count_up(_hud.score_label(), _skin, from, score)
	_shown_score = score
	var statuses: Array[BoosterStatus] = _session.booster_statuses()
	_bar.show_boosters(statuses)
	if _session.is_offer_open():
		_offer.show_offer(statuses, score)


func _set_offer_open(is_open: bool) -> void:
	if is_open:
		_offer.show_offer(_session.booster_statuses(), _session.state.score)
	_offer.visible = is_open
	_hud.visible = not is_open
	_layout()


## The targeting hint goes to the bar (Gumdrop, Nova) and the HUD context row
## (Slate); each skin shows it in one place. Otherwise the context row shows
## the chain, with the preview tile, while one is dragged.
func _show_context() -> void:
	if _session == null or _hud == null:
		return
	var booster_id: StringName = _session.targeting_booster()
	if booster_id != &"":
		var chosen: bool = _session.swap_first() != _NO_CELL
		_bar.set_hint(Copy.hint(booster_id, chosen))
		_hud.set_context(Copy.targeting_context(booster_id, chosen), true)
		if _preview != null:
			_preview.visible = false
		return
	_bar.set_hint("")
	_hud.set_context(_chain_context, false)
	if _preview != null:
		_preview.visible = _chain_preview > 0
		_preview.set_value(_chain_preview)


func _on_status_changed() -> void:
	_show_status(true)


func _on_targeting_changed(_booster_id: StringName, _swap_first: Vector2i) -> void:
	_show_context()


func _on_offer_changed(is_open: bool, _suggested: StringName) -> void:
	_set_offer_open(is_open)
	_show_status(false)


func _on_run_started(_result: MoveResult) -> void:
	_chain_context = ""
	_chain_preview = 0
	_shown_score = -1
	_show_status(false)
	_show_context()


## AT-104: the HUD shows which values a move cleared.
func _on_move_resolved(result: MoveResult) -> void:
	_chain_points_pending = result.kind == MoveResult.Kind.CHAIN
	if not result.cleared_values.is_empty():
		_hud.show_clear_notice(result.cleared_values, _board.get_global_rect())


func _on_chain_changed(chain: Array[Vector2i], preview_value: int) -> void:
	_chain_preview = preview_value
	_chain_context = Copy.chain(chain.size()) if preview_value > 0 else ""
	_show_context()


func _on_booster_pressed(booster_id: StringName) -> void:
	_session.press_booster(booster_id)


func _on_end_run() -> void:
	_session.end_run()


func _on_pause_pressed() -> void:
	pause_requested.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_ENTER_TREE:
		_layout()


func _layout() -> void:
	if _skin == null or _hud == null or not is_inside_tree():
		return
	var safe: Rect2 = SafeArea.viewport_safe_rect(get_viewport())
	var inner: Rect2 = Rect2(safe.position - get_global_rect().position, safe.size)
	var margin: float = _skin.num(&"board_margin")
	var gap: float = _skin.num(&"space_s")

	var top: float = inner.position.y
	if _offer.visible:
		_offer.position = Vector2(inner.position.x + margin, inner.position.y)
		_offer.size = Vector2(inner.size.x - margin * 2.0, 0.0)
		top = inner.position.y + _offer.get_combined_minimum_size().y
	var hud_height: float = _hud.preferred_height()
	_hud.position = inner.position
	_hud.size = Vector2(inner.size.x, hud_height)
	if not _offer.visible:
		top = inner.position.y + hud_height

	var bar_height: float = _bar.preferred_height()
	_bar.position = Vector2(inner.position.x, inner.end.y - bar_height)
	_bar.size = Vector2(inner.size.x, bar_height)

	var region_top: float = top + gap
	var region_height: float = maxf(0.0, _bar.position.y - gap - region_top)
	var width: float = maxf(0.0, inner.size.x - margin * 2.0)
	var height: float = _board.preferred_height(width)
	if height > region_height and height > 0.0:
		width *= region_height / height
		height = _board.preferred_height(width)
	_board.position = Vector2(inner.position.x + (inner.size.x - width) * 0.5, region_top + maxf(0.0, region_height - height) * 0.5)
	_board.size = Vector2(width, height)

	var clear: Array[Rect2] = [_bar.get_global_rect()]
	clear.append(_offer.get_global_rect() if _offer.visible else _hud.get_global_rect())
	_backdrop.set_clear_rects(clear)
