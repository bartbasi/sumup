class_name GameScreen extends Control
## The play screen (docs/ARCHITECTURE.md section 11, DESIGN_SYSTEM.md 2.3 and
## 7.1). Top to bottom inside the safe area and the content column (2.8): the
## HUD, space_s, the board, space_s, the booster bar. The backdrop fills the
## whole screen. The board takes the widest size inside board_margin whose
## preferred height fits between the HUD and the bar, centered in the column;
## if it does not fit it shrinks evenly and stays centered.
##
## While the no moves offer is open, OfferPanel takes the HUD's place and the
## board shrinks to fit under it; the board and the bar stay usable (7.5).
##
## It mirrors the session into the components: scores into the HUD (counting
## up when a chain adds points), statuses into the bar and the offer, the
## targeting hint into the bar (Gumdrop, Nova) and the HUD context row
## (Slate), the chain into the context row and preview slot (Slate), and the
## clear notice (AT-104, D-45). Every color, size and timing comes from the
## skin.
##
## A move shows only once its save has landed (QA6-06, GDD 15.1). While the
## board holds a move at its show gate, the HUD score, the booster bar, the
## offer and the clear notice stay as they were at the lift; the newest
## status and the newest move's notice show at the board's next
## move_started. A held move that a newer one replaces gets no move_started of
## its own, so this keeps only the latest, never a count.

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
## QA6-04, DESIGN_SYSTEM.md 7.1: the clear notice and the flying stars draw
## here, above the board and the offer panel and below every dialog (the
## App's panels sit above the whole screen), so they show while the offer
## hides the HUD.
var _notice_layer: Control = null
var _preview: SkinTileView = null
var _chain_context: String = ""
var _chain_preview: int = 0
var _shown_score: int = -1
## True from a chain's move_resolved to the status_changed that follows it.
var _chain_points_pending: bool = false
## A status_changed came while the board held a move at the gate.
var _status_held: bool = false
## The newest move whose clear notice waits for the board's move_started.
var _notice_held: MoveResult = null
## What the HUD, the bar and the offer show now, for a rebuild while a move
## is held: score, Best Score, booster statuses.
var _shown_best: int = 0
var _shown_statuses: Array[BoosterStatus] = []
var _shown_stars: int = 0
var _shown_free: int = 0


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
	_board.move_started.connect(_on_move_started)
	_offer = OFFER_SCENE.instantiate() as OfferPanel
	_offer.name = "Offer"
	_offer.visible = false
	add_child(_offer)
	_offer.booster_chosen.connect(_on_booster_pressed)
	_offer.end_run_chosen.connect(_on_end_run)
	_offer.minimum_size_changed.connect(_layout)
	_notice_layer = Control.new()
	_notice_layer.name = "NoticeLayer"
	_notice_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_notice_layer)
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


## The score last given to the HUD (its final value, before any count up).
## For tests.
func shown_score() -> int:
	return _shown_score


## The booster statuses last given to the bar and the offer. For tests.
func shown_statuses() -> Array[BoosterStatus]:
	return _shown_statuses


## The notice layer, above the board and the offer. For tests.
func notice_layer() -> Control:
	return _notice_layer


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
	move_child(_notice_layer, get_child_count() - 1)
	_offer.setup(skin)
	_hud.set_notice_layer(_notice_layer)
	_hud.set_stars(_shown_stars, _shown_free)
	_shown_score = -1
	_layout()


## Re-reads everything from the session, or, while the board holds a move at
## its gate, shows again what was shown at the lift.
func _refresh() -> void:
	if _held() and _shown_score >= 0:
		_present(_shown_score, _shown_best, _shown_statuses, _shown_stars, _shown_free, false)
	else:
		_show_status(false)
	_set_offer_open(_session.is_offer_open())
	_show_context()


## True while the board holds a move at its show gate (TH23).
func _held() -> bool:
	return _board != null and _board.is_waiting_for_save()


## Shows the session's status now. Clears a held status: this is the newest.
func _show_status(count: bool) -> void:
	if _session == null or _hud == null:
		return
	_status_held = false
	_present(_session.state.score, _session.records.best_score, _session.booster_statuses(), _session.stars(), _session.free_held(), count)


## Shows a status: the scores and the star counter in the HUD (D-45, D-46),
## the statuses in the bar and the offer.
func _present(score: int, best_score: int, statuses: Array[BoosterStatus], stars: int, free_held: int, count: bool) -> void:
	_hud.set_scores(score, best_score)
	_hud.set_stars(stars, free_held)
	_shown_stars = stars
	_shown_free = free_held
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
	_shown_best = best_score
	_shown_statuses = statuses
	_bar.show_boosters(statuses)
	if _offer.visible or _session.is_offer_open():
		_offer.show_offer(statuses, score)


func _set_offer_open(is_open: bool) -> void:
	if is_open:
		if _shown_score >= 0:
			_offer.show_offer(_shown_statuses, _shown_score)
		else:
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
	if _held():
		_status_held = true
		return
	_show_status(true)


func _on_targeting_changed(_booster_id: StringName, _swap_first: Vector2i) -> void:
	_show_context()


## Comes from move_shown(), once the move has been shown: never held.
func _on_offer_changed(is_open: bool, _suggested: StringName) -> void:
	_set_offer_open(is_open)
	_show_status(false)


func _on_run_started(_result: MoveResult) -> void:
	_chain_context = ""
	_chain_preview = 0
	_notice_held = null
	_show_context()
	if _held():
		_status_held = true
		return
	_shown_score = -1
	_show_status(false)


## The clear notice (AT-104, D-45) shows when the move earned a star or
## cleared small tiles, naming every value that left the spawn window. It
## waits with the move at the board's gate.
func _on_move_resolved(result: MoveResult) -> void:
	_chain_points_pending = result.kind == MoveResult.Kind.CHAIN
	if _held():
		_notice_held = result
		return
	_show_notice(result)


## The board's gate opened and the move's effects begin: show what was held,
## the notice first so its star leaves before the counter takes the count.
func _on_move_started() -> void:
	var result: MoveResult = _notice_held
	_notice_held = null
	if result != null:
		_show_notice(result)
	if _status_held:
		_show_status(true)


## GDD 11.5: a move shows the notice when it earned a star or cleared small
## tiles (a floor that rose with neither shows none, ARCHITECTURE.md
## section 4).
static func wants_notice(result: MoveResult) -> bool:
	return result != null and (result.stars_earned > 0 or not result.cleared_small.is_empty())


## Flow 4: the notice with the values that left the window and the stars the
## move earned, then the counter with the session's new count, which the
## star moment lands on (DESIGN_SYSTEM.md 3.6).
func _show_notice(result: MoveResult) -> void:
	if not wants_notice(result):
		return
	_hud.show_clear_notice(result.notice_values, _board_rect(), result.stars_earned)
	_hud.set_stars(_session.stars(), _session.free_held())


## The board's rect in global coordinates (the HUD places the notice by it).
func _board_rect() -> Rect2:
	if _board.is_inside_tree():
		return _board.get_global_rect()
	return Rect2(_board.position, _board.size)


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
	var screen: Rect2 = get_global_rect()
	layout_in(screen, SafeArea.content_column(get_viewport(), _skin))
	var clear: Array[Rect2] = [_bar.get_global_rect()]
	clear.append(_offer.get_global_rect() if _offer.visible else _hud.get_global_rect())
	_backdrop.set_clear_rects(clear)


## Lays the screen out for its own rect and the content column, both in the
## same (global) coordinates: the HUD, the offer and the bar in the column,
## the board centered in it. _layout calls it; tests call it with rects of
## their own, since headless tests never enter the scene tree.
func layout_in(screen: Rect2, column: Rect2) -> void:
	if _skin == null or _hud == null:
		return
	var inner: Rect2 = Rect2(column.position - screen.position, column.size)
	var margin: float = _skin.num(&"board_margin")
	var gap: float = _skin.num(&"space_s")

	var top: float = inner.position.y
	if _offer.visible:
		_offer.position = Vector2(inner.position.x + margin, inner.position.y)
		_offer.fit_width(inner.size.x - margin * 2.0)
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
		width = _width_for_height(width, region_height)
		height = _board.preferred_height(width)
	_board.position = Vector2(inner.position.x + (inner.size.x - width) * 0.5, region_top + maxf(0.0, region_height - height) * 0.5)
	_board.size = Vector2(width, height)


## The board width whose preferred height is height, at most width. A board's
## preferred height is linear in its width, so two samples give it exactly.
func _width_for_height(width: float, height: float) -> float:
	if width <= 0.0:
		return 0.0
	var half: float = width * 0.5
	var at_width: float = _board.preferred_height(width)
	var at_half: float = _board.preferred_height(half)
	var slope: float = (at_width - at_half) / (width - half)
	if slope <= 0.0:
		return 0.0
	return clampf(half + (height - at_half) / slope, 0.0, width)
