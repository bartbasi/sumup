extends "res://src/ui/open_row.gd"
## The Buy me a coffee button (DESIGN_SYSTEM.md 7.2, GDD 15.5), the same on
## the splash and in About's "Supporting SumUp" section.
## - Content on one line, vertically centered: the coffee icon in ink_muted,
##   in a square box the body role's font size, centered on the label's cap
##   middle; a gap of 0.25 of that size; then "Buy me a coffee" in MutedLabel,
##   as written in every skin. Children ignore the mouse.
## - touch_min tall and only as wide as its content (it never expands). The
##   touch area reaches space_s past the content on both sides, the same
##   reach as the RowButton pressed fill, so the whole fill is the target.
## - The RowButton look and the tap rule of a row that opens a screen
##   (open_row.gd): down and up on it, moving less than the deadzone, with no
##   scroll in between; a drag that starts on it reaches the ScrollContainer.
## - Never disabled, no chevron, no scale, no motion of its own.
## Every tap hands Copy.COFFEE_URL to the system exactly once (hand_off). On
## failure nothing happens: no message, and the screen stays as it was (BC6).

const Copy: GDScript = preload("res://src/ui/screen_copy.gd")
const FontMetrics: GDScript = preload("res://src/design/shared/font_metrics.gd")
## DESIGN_SYSTEM.md 7.9: the gap between the icon and the label, as a share
## of the body role's font size.
const ICON_GAP: float = 0.25

## How the address reaches the system: OS.shell_open by default. Tests set a
## capture here (TH24) so no browser opens, and put the default back with
## use_system_opener(). It takes the address and returns an Error.
static var opener: Callable = Callable(OS, &"shell_open")

var _icon: SkinIcon = null
var _reach: float = 0.0


## Hands the one fixed address to the system. True when the system took it;
## anything other than OK counts as "could not open", and then nothing else
## happens (GDD BC6). Nothing is ever added to the address.
static func hand_off() -> bool:
	if not opener.is_valid():
		return false
	var result: Variant = opener.call(Copy.COFFEE_URL)
	return typeof(result) == TYPE_INT and int(result) == OK


## Puts the real hand off back (OS.shell_open). For tests.
static func use_system_opener() -> void:
	opener = Callable(OS, &"shell_open")


## Builds the button for skin. The title is the button's copy; there is no
## detail line.
func setup(skin: SkinData, title: String = Copy.COFFEE, _no_detail: String = "") -> void:
	_skin = skin
	UiParts.clear(self)
	name = "Coffee"
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	custom_minimum_size = Vector2(0.0, skin.num(&"touch_min"))
	_reach = skin.num(&"space_s")
	var font_px: int = skin.font_size(&"body")
	var line: HBoxContainer = UiParts.hbox(float(roundi(ICON_GAP * float(font_px))))
	line.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(line)
	# Line the icon's middle up with the label's cap middle, not the middle
	# of its line box: shift it by the gap between the two.
	var font: Font = skin.font(&"body")
	var offset: float = 0.5 * (font.get_ascent(font_px) - font.get_descent(font_px) - FontMetrics.CAP_HEIGHT * float(font_px))
	var icon_box: MarginContainer = MarginContainer.new()
	icon_box.name = "IconBox"
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_box.add_theme_constant_override(&"margin_top", maxi(0, roundi(2.0 * offset)))
	icon_box.add_theme_constant_override(&"margin_bottom", maxi(0, roundi(-2.0 * offset)))
	line.add_child(icon_box)
	_icon = UiKit.make_icon(skin)
	_icon.name = "Icon"
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.custom_minimum_size = Vector2(float(font_px), float(font_px))
	_icon.size = Vector2(float(font_px), float(font_px))
	_icon.set_icon(&"coffee")
	_icon.set_color(skin.color(&"ink_muted"))
	icon_box.add_child(_icon)
	_title = UiParts.label(skin, &"MutedLabel", title)
	_title.name = "Title"
	_title.text = skin.cased(&"body", title)
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(_title)
	_detail = null
	_chevron = null
	if not tapped.is_connected(_on_tapped):
		tapped.connect(_on_tapped)
	_apply_look()


## The button's size where no container sizes it (the play screen, 7.15):
## its minimum size, but never less wide than the icon, the gap and the label
## measured in the skin's body font, and never less than touch_min tall. A
## label measures nothing until its theme reaches it in the tree, so the
## width is worked out from the font too and a layout before that is right.
func content_size() -> Vector2:
	var size_now: Vector2 = get_combined_minimum_size()
	if _skin == null or _title == null:
		return size_now
	var font_px: int = _skin.font_size(&"body")
	var text: float = UiParts.text_width(_skin, &"MutedLabel", _title.text, font_px)
	var width: float = float(font_px) + float(roundi(ICON_GAP * float(font_px))) + text
	return Vector2(maxf(size_now.x, width), maxf(size_now.y, _skin.num(&"touch_min")))


## The coffee icon. For tests.
func icon() -> SkinIcon:
	return _icon


## The label. For tests.
func label() -> Label:
	return _title


## The touch area reaches space_s past the content on both sides, where the
## pressed fill reaches (the Theme's RowButton expand margin).
func _has_point(point: Vector2) -> bool:
	return point.x >= -_reach and point.x < size.x + _reach and point.y >= 0.0 and point.y < size.y


func _on_tapped() -> void:
	hand_off()
