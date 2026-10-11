extends Control
## Review sheet for one skin's production interface layer, 1080 by 2400 at
## true scale, built only through UiKit and the base classes, like a screen.
## Two pages per skin:
##   play: the HUD with the clear notice over the board's top edge (Slate: in
##     its context row, plus the context row while dragging and in
##     targeting), then the booster bar normal, targeting, in the out of
##     moves offer (disabled boosters and the Suggested badge), and targeting
##     from the offer (the badge hides while a booster is active).
##   parts: every icon in every look on the fill it sits on, the buttons and
##     icon buttons in every state, the chips, the sound toggle on and off,
##     and a card with every label type, a badge and a divider.
## Small captions in the skin's CaptionLabel name each sample. Every text,
## icon and button rect is kept clear of Nova's star dust.
##
## Capture with:
##   godot --path . res://tools/capture.tscn -- --scene res://scenes/design/ui_<id>_<page>.tscn --out docs/design/review/prod-ui-<id>-<page>.png

@export var skin_id: StringName = &"gumdrop"
@export var page: String = "play"

const CANVAS: Vector2 = Vector2(1080.0, 2400.0)
## Top of the content, like a status bar inset.
const TOP: float = 72.0
## The mock board: rows shown under the HUD, and the values on it.
const BOARD_ROWS_SHOWN: float = 2.4
const BOARD_VALUES: Array[int] = [
	4, 16, 4, 2, 8, 2, 1024, 64, 8, 2, 16, 128, 2, 32, 4, 4, 8, 512, 16, 64,
	32, 8, 8, 2, 16, 4, 2048, 16, 4, 4, 8, 4, 32, 256, 8, 64, 4, 4, 8, 4,
]
const BOOSTERS: Array[StringName] = [&"hammer", &"swap", &"shuffle", &"double", &"undo"]

var _skin: SkinData = null
var _margin: float = 0.0
var _gap: float = 0.0
var _y: float = TOP
var _texts: Array[Control] = []
var _backdrop: SkinBackdrop = null


func _ready() -> void:
	_skin = SkinCatalog.get_skin(skin_id)
	position = Vector2.ZERO
	size = CANVAS
	theme = UiKit.build_theme(_skin)
	_margin = _skin.num(&"board_margin")
	_gap = _skin.num(&"space_s")
	_backdrop = UiKit.make_backdrop(_skin)
	_place(_backdrop, Vector2.ZERO, CANVAS)
	if page == "parts":
		_parts_page()
	else:
		_play_page()
	# Containers lay out on the next frames; then the text rects are final.
	await get_tree().process_frame
	await get_tree().process_frame
	var rects: Array[Rect2] = []
	for holder: Control in _texts:
		rects.append(holder.get_global_rect())
	_backdrop.set_clear_rects(rects)


# Play page

func _play_page() -> void:
	var hud: SkinHud = _hud()
	hud.set_scores(41286, 96520)
	if skin_id == &"slate":
		hud.show_clear_notice(PackedInt64Array([2, 4]), Rect2())
		_y += _gap
		_caption("context row while dragging, with the preview tile")
		var dragging: SkinHud = _hud()
		dragging.set_scores(41286, 96520)
		dragging.set_context("Chain 6", false)
		_tile_in(dragging.preview_slot(), 256)
		_y += _gap
		_caption("context row in targeting")
		var targeting: SkinHud = _hud()
		targeting.set_scores(41286, 96520)
		targeting.set_context("Hammer: Tap a tile to smash it", true)
	else:
		var board: Rect2 = _board_strip(_y + _gap)
		hud.show_clear_notice(PackedInt64Array([2, 4]), board)
	_y += _gap
	_caption("booster bar: normal")
	_bar(_statuses(-1, [], -1), "")
	_caption("targeting: hammer active, undo has no snapshot")
	_bar(_statuses(0, [4], -1), "Tap a tile to smash it")
	_caption("out of moves offer: shuffle suggested")
	if skin_id == &"slate":
		# Slate's badge straddles the strip's top hairline; leave it room.
		_y += _gap
	_bar(_statuses(-1, [0, 1, 3], 2), "")
	_caption("targeting from the offer: no badge")
	_bar(_statuses(0, [1, 3], 2), "Tap a tile to smash it")


func _hud() -> SkinHud:
	var hud: SkinHud = UiKit.make_hud(_skin)
	_place(hud, Vector2(0.0, _y), Vector2(CANVAS.x, hud.preferred_height()))
	_texts.append(hud)
	_y += hud.preferred_height()
	return hud


## The top rows of a real board view for this skin, clipped, at _y. Returns
## the board's full global rect, as a screen would pass it.
func _board_strip(top: float) -> Rect2:
	var width: float = CANVAS.x - _margin * 2.0
	var clip: Control = Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view: SkinBoardView = SkinCatalog.make_board_view(_skin)
	view.setup(_skin, 5, 8)
	var full: float = view.preferred_height(width)
	var shown: float = full * BOARD_ROWS_SHOWN / 8.0
	_place(clip, Vector2(_margin, top), Vector2(width, shown))
	clip.add_child(view)
	view.position = Vector2.ZERO
	view.size = Vector2(width, full)
	view.set_board(PackedInt64Array(BOARD_VALUES))
	_y = top + shown
	return Rect2(_margin, top, width, full)


func _tile_in(slot: Control, value: int) -> void:
	if slot == null:
		return
	var tile: SkinTileView = SkinCatalog.make_tile_view(_skin)
	slot.add_child(tile)
	tile.position = Vector2.ZERO
	tile.size = slot.size
	tile.set_value(value)


## Statuses in bar order: active is the index targeting (-1 none), disabled
## the indexes not usable, suggested the suggested index (-1 none).
func _statuses(active: int, disabled: Array[int], suggested: int) -> Array[BoosterStatus]:
	var costs: Array[int] = [2048, 2048, 2048, 4096, 1024]
	var statuses: Array[BoosterStatus] = []
	for i: int in BOOSTERS.size():
		var status: BoosterStatus = BoosterStatus.new()
		status.id = BOOSTERS[i]
		status.cost = costs[i]
		status.usable = not disabled.has(i)
		status.reason = BoosterStatus.Usability.USABLE if status.usable else BoosterStatus.Usability.CANNOT_AFFORD
		status.active = i == active
		status.suggested = i == suggested
		statuses.append(status)
	return statuses


func _bar(statuses: Array[BoosterStatus], hint: String) -> void:
	var bar: SkinBoosterBar = UiKit.make_booster_bar(_skin)
	bar.show_boosters(statuses)
	bar.set_hint(hint)
	_place(bar, Vector2(0.0, _y), Vector2(CANVAS.x, bar.preferred_height()))
	_texts.append(bar)
	_y += bar.preferred_height() + _gap


# Parts page

func _parts_page() -> void:
	_caption("icons: normal, active (on the active fill), disabled")
	_icons()
	_caption("buttons: normal, pressed, disabled, focus")
	_buttons(&"PrimaryButton", "Shuffle for 4K")
	_buttons(&"SecondaryButton", "End run")
	_caption("icon buttons (make_icon_button); toggle on, off")
	_icon_buttons_and_toggles()
	_caption("chips: selected, normal, disabled, focus")
	_chips()
	_caption("card with every label type")
	_card()


func _icons() -> void:
	var count: int = SkinIcon.ICON_NAMES.size()
	var cell: float = floorf((CANVAS.x - _margin * 2.0) / float(count))
	var side: float = _skin.num(&"icon_hud")
	var pad: float = _skin.num(&"space_xs") * 0.5
	for look: int in [SkinIcon.LOOK_NORMAL, SkinIcon.LOOK_ACTIVE, SkinIcon.LOOK_DISABLED]:
		for i: int in count:
			var box: Rect2 = Rect2(_margin + cell * float(i) + (cell - side) * 0.5 - pad, _y, side + pad * 2.0, side + pad * 2.0)
			var fill: Color = _look_fill(look)
			if fill.a > 0.0:
				var swatch: ColorRect = ColorRect.new()
				swatch.color = fill
				swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_place(swatch, box.position, box.size)
			var icon: SkinIcon = UiKit.make_icon(_skin)
			icon.set_icon(SkinIcon.ICON_NAMES[i])
			icon.set_look(look)
			_place(icon, box.position + Vector2(pad, pad), Vector2(side, side))
			_texts.append(icon)
		_y += side + pad * 2.0 + _skin.num(&"space_xs")
	_y += _gap - _skin.num(&"space_xs")


## The fill an icon in a look sits on: the active fill of each skin's
## booster, the disabled face for Gumdrop, the page for the rest.
func _look_fill(look: int) -> Color:
	if look == SkinIcon.LOOK_ACTIVE:
		return _skin.color(&"ink") if skin_id == &"slate" else _skin.color(&"accent")
	if look == SkinIcon.LOOK_DISABLED and skin_id == &"gumdrop":
		return _skin.color(&"disabled_surface")
	if look == SkinIcon.LOOK_NORMAL and skin_id == &"gumdrop":
		return _skin.color(&"surface_raised")
	return Color.TRANSPARENT


func _buttons(variation: StringName, text: String) -> void:
	var width: float = (CANVAS.x - _margin * 2.0 - _gap) / 2.0
	var height: float = _skin.num(&"button_height")
	for state: int in 4:
		var button: Button = Button.new()
		button.theme_type_variation = variation
		button.text = _skin.cased(&"body", text)
		button.focus_mode = Control.FOCUS_NONE
		button.clip_text = true
		if skin_id == &"slate":
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = state == 1
		button.button_pressed = state == 1
		button.disabled = state == 2
		var at: Vector2 = Vector2(_margin + (width + _gap) * float(state % 2), _y + (height + _skin.num(&"space_xs")) * (1.0 if state >= 2 else 0.0))
		_place(button, at, Vector2(width, height))
		_texts.append(button)
		if state == 3:
			_focus_over(button, variation)
	_y += height * 2.0 + _skin.num(&"space_xs") + _gap


## Draws a type's focus style over a control, so the focus look shows next
## to the others (only one control can hold focus).
func _focus_over(target: Control, variation: StringName) -> void:
	var overlay: Control = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBox = theme.get_stylebox(&"focus", variation)
	overlay.draw.connect(func() -> void: overlay.draw_style_box(style, Rect2(Vector2.ZERO, overlay.size)))
	_place(overlay, target.position, target.size)


func _icon_buttons_and_toggles() -> void:
	var touch: float = _skin.num(&"touch_min")
	var icons: Array[StringName] = [&"settings", &"close", &"sound_on", &"check"]
	var x: float = _margin
	for state: int in 4:
		var button: BaseButton = UiKit.make_icon_button(_skin, icons[state])
		button.toggle_mode = state == 1
		button.button_pressed = state == 1
		button.disabled = state == 2
		_place(button, Vector2(x, _y), Vector2(touch, touch))
		_texts.append(button)
		if state == 3:
			_focus_over(button, &"IconButton")
		x += touch + _skin.num(&"space_xs")
	x += _gap
	for on: bool in [true, false]:
		var toggle: SkinToggle = UiKit.make_toggle(_skin)
		toggle.set_on(on)
		_place(toggle, Vector2(x, _y), toggle.custom_minimum_size)
		_texts.append(toggle)
		x += toggle.custom_minimum_size.x + _gap
	_y += touch + _gap


func _chips() -> void:
	var names: PackedStringArray = PackedStringArray(["Gumdrop", "Slate", "Nova", "Locked"])
	var width: float = (CANVAS.x - _margin * 2.0 - _gap * 3.0) / 4.0
	var height: float = _skin.num(&"button_height")
	for i: int in 4:
		var chip: Button = Button.new()
		chip.theme_type_variation = &"ChipButton"
		chip.text = _skin.cased(&"body", names[i])
		chip.focus_mode = Control.FOCUS_NONE
		chip.toggle_mode = true
		chip.button_pressed = i == 0
		chip.disabled = i == 3
		_place(chip, Vector2(_margin + (width + _gap) * float(i), _y), Vector2(width, height))
		_texts.append(chip)
		if i == 2:
			_focus_over(chip, &"ChipButton")
	_y += height + _gap


func _card() -> void:
	var card: PanelContainer = PanelContainer.new()
	card.theme_type_variation = &"CardPanel"
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override(&"separation", roundi(_skin.num(&"space_xs")))
	card.add_child(stack)
	var signal_role: StringName = &"label" if skin_id == &"slate" else &"title"
	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.add_theme_constant_override(&"separation", roundi(_gap))
	top_row.add_child(_label(&"SignalLabel", _skin.cased(signal_role, "Run over"), false))
	var badge: PanelContainer = PanelContainer.new()
	badge.theme_type_variation = &"BadgePanel"
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_child(_label(&"BadgeLabel", _skin.cased(&"label", "New best"), false))
	top_row.add_child(badge)
	stack.add_child(top_row)
	stack.add_child(_label(&"DisplayLabel", NumberFormat.score(41286), false))
	stack.add_child(_label(&"TitleLabel", _skin.cased(&"title", "Settings"), false))
	var rule: HSeparator = HSeparator.new()
	rule.theme_type_variation = &"Hairline"
	stack.add_child(rule)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", roundi(_gap))
	row.add_child(_label(&"BodyLabel", _skin.cased(&"body", "Best score 96,520"), false))
	var caption: Label = _label(&"CaptionLabel", _skin.cased(&"label", "Skin"), false)
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caption)
	stack.add_child(row)
	stack.add_child(_label(&"MutedLabel", _skin.cased(&"body", "Pick a booster to keep this run going."), false))
	var x: float = 0.0 if skin_id == &"slate" else _margin
	_place(card, Vector2(x, _y), Vector2(CANVAS.x - x * 2.0, 0.0))
	_texts.append(card)


func _label(variation: StringName, text: String, wrap: bool) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


# Shared

## A small caption naming the next sample, in CaptionLabel (ink_muted on the
## page, a listed pair in every skin).
func _caption(text: String) -> void:
	var label: Label = Label.new()
	label.theme_type_variation = &"CaptionLabel"
	label.text = _skin.cased(&"label", text)
	var height: float = _skin.font(&"label").get_height(_skin.font_size(&"label"))
	_place(label, Vector2(_margin, _y), Vector2(CANVAS.x - _margin * 2.0, height))
	_texts.append(label)
	_y += height + _skin.num(&"space_xs")


func _place(control: Control, at: Vector2, extent: Vector2) -> void:
	add_child(control)
	control.position = at
	control.size = extent
