class_name SafeArea extends RefCounted
## The device safe area in a viewport's own coordinates (DESIGN_SYSTEM.md
## 2.2): the part of the screen clear of the notch, punch hole, rounded
## corners and the gesture or button bar. No text and no touch target sits
## outside it; backgrounds, the board tray, the scrim and sheets reach the
## screen edges.

## Review scenes and tests set this to simulate a phone: x is the top inset
## and y the bottom inset, in viewport px. Negative (the default) reads the
## real display.
static var simulated_insets: Vector2 = Vector2(-1.0, -1.0)


## The display safe area mapped into viewport coordinates, inside the
## viewport's visible rect. The whole visible rect when there is no display
## to ask (headless, or a SubViewport) or the answer makes no sense.
static func viewport_safe_rect(viewport: Viewport) -> Rect2:
	if viewport == null:
		return Rect2()
	var visible: Rect2 = viewport.get_visible_rect()
	if simulated_insets.x >= 0.0 and simulated_insets.y >= 0.0:
		var height: float = maxf(0.0, visible.size.y - simulated_insets.x - simulated_insets.y)
		return Rect2(visible.position.x, visible.position.y + simulated_insets.x, visible.size.x, height)
	if not (viewport is Window) or DisplayServer.get_name() == "headless":
		return visible
	var window: Window = viewport as Window
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	if safe.size.x <= 0 or safe.size.y <= 0:
		return visible
	# The safe area is in screen pixels: move it into the window, then undo
	# the stretch transform to reach viewport coordinates.
	var window_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(window.size))
	var in_window: Rect2 = Rect2(Vector2(safe.position - window.position), Vector2(safe.size)).intersection(window_rect)
	if in_window.size.x <= 0.0 or in_window.size.y <= 0.0:
		return visible
	var mapped: Rect2 = viewport.get_final_transform().affine_inverse() * in_window
	mapped = mapped.intersection(visible)
	if mapped.size.x <= 0.0 or mapped.size.y <= 0.0:
		return visible
	return mapped
