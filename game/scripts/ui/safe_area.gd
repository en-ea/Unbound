extends RefCounted
## Where the HUD can go on phones with a notch, a Dynamic Island, a camera hole, rounded corners or
## a home indicator, in UI units (the 1280x720-based space the HUD is laid out in). On the PC and in
## the web build the OS reports no insets, so this is the whole screen and nothing moves.
## Left and right are made equal (the larger of the two): turning the phone round moves the notch
## to the other side, and this way nothing needs laying out again.

const HUD_MARGIN := Vector2(64, 24)   # hud.gd MARGIN: what the HUD keeps clear of the edges already


## The safe rectangle, in UI units.
static func rect(vp: Viewport) -> Rect2:
	var full := vp.get_visible_rect()
	if not OS.has_feature("mobile") or OS.has_feature("web"):
		return full
	return from_window(DisplayServer.window_get_size(), DisplayServer.get_display_safe_area(), full.size)


## The same from raw numbers, so it can be checked without a phone: the window and its safe area in
## pixels, and the UI's visible size in UI units.
static func from_window(window: Vector2i, safe: Rect2i, ui_size: Vector2) -> Rect2:
	if window.x <= 0 or window.y <= 0 or safe.size.x <= 0 or safe.size.y <= 0:
		return Rect2(Vector2.ZERO, ui_size)
	var k := ui_size.x / window.x   # UI units per pixel (canvas_items stretch scales evenly)
	var side := maxf(safe.position.x, window.x - safe.end.x) * k
	var top := safe.position.y * k
	var bottom := (window.y - safe.end.y) * k
	return Rect2(side, top, ui_size.x - 2.0 * side, ui_size.y - top - bottom)


## How much further in than its designed spot the HUD's top corners must sit (zero on the PC).
static func push(vp: Viewport) -> Vector2:
	var r := rect(vp)
	return Vector2(maxf(0.0, r.position.x - HUD_MARGIN.x), maxf(0.0, r.position.y - HUD_MARGIN.y))
