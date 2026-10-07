class_name ActionButton
extends Control
## A round touch button (Attack, Roll, Heavy, Parry, Sneak, the class abilities). It reads touches directly,
## by finger, so it works while the other thumb holds the joystick. Shows a drawn icon or the current verb
## (Chop / Mine / Pick), a stamina rim or a cooldown sweep, and its flicks while held.
## Where it sits and how big it is come from the player's layout (Settings.button_spot / button_scale).

signal pressed
signal released
signal swiped(dir: String)       # "up", "down", "left" or "right": a flick that starts on the button

static var editing := false      # the "Move buttons" screen is open: buttons don't act, they get dragged
static var _all: Array[ActionButton] = []   # every button on screen (sliding a thumb from one to another)

var id := ""                     # its name in the saved layout
var home_margin := Vector2(150, 150)   # default centre, measured from the bottom-right corner
var home_radius := 68.0
var swipes := {}                 # dir -> label; with any set, a tap acts on release and a flick acts instead

var radius := 68.0
var margin := Vector2(150, 150)
var font_size := 28
var _safe := Rect2()                 # where the whole button must stay (clear of notches and the home bar)

var verb := ""
var icon := ""                   # a drawn symbol: sword, heavy, shield, roll, sneak (the verb goes small underneath)
var sub := ""                    # small second line under the verb (a hint like "hold: sprint")
var meter := 1.0                 # 0..1: a thin arc round the rim while below 1 (stamina)
var meter_color := Color(0.62, 0.9, 0.38)
var sweep := false               # show the meter as a cooldown: a dark wedge and the seconds left
var seconds := 0                 # with sweep: the whole seconds still to wait
var lit := false                 # glows while its hold action is on (sprinting)
var lit_fill := Color(0.2, 0.3, 0.16, 0.75)     # its colour then
var accent := Color(0.8, 0.82, 0.9)  # its own colour: the ring and the glow inside (abilities: the class's)
var dim := false                 # can't be used right now
var studio_keep := false # studio: C1 - Hands: this finger armed an act here (a flick, a held draw or Heavy): it never slides away
var _studio_last := Vector2.INF # studio: C1 - the finger's last sampled point (a slide is sampled every STUDIO_STEP px)
const STUDIO_STEP := 8.0 # studio:
const STUDIO_HYSTERESIS := 1.15 # studio: past this many radii from its own centre before it hands over (was 1.1)
var _held := -1
var _held_for := 0.0
var _pulse := 0.0
var _shake := 0.0
var _ready_ring := 0.0           # a ring that flies outwards when a cooldown ends
var _start := Vector2.ZERO
var _finger := Vector2.ZERO
var _swiped := false
const SWIPE := 36.0              # pixels a finger must travel for a flick
const DIRS := {"up": Vector2(0, -1), "down": Vector2(0, 1), "left": Vector2(-1, 0), "right": Vector2(1, 0)}
const CREAM := Color(1, 0.97, 0.9)
const GOLD := Color(1.0, 0.82, 0.42)
const AbilityIcons := preload("res://scripts/ui/ability_icons.gd")
const Look := preload("res://scripts/ui/button_look.gd")


func is_held() -> bool:
	return _held != -1


func held_for() -> float:
	return _held_for if _held != -1 else 0.0


## A little shake: "not now" (e.g. out of stamina).
func refuse() -> void:
	_shake = 1.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_safe()
	get_viewport().size_changed.connect(_update_safe)
	_all.append(self)
	tree_exiting.connect(func() -> void: _all.erase(self))


## Slide mode (Settings): a thumb held on one button slides onto another and presses it, no lifting.
## The button it left lets go quietly (a roll or a tap doesn't fire on the way out).
func _slide(pos: Vector2) -> bool:
	if studio_keep: # studio: an armed finger never hands over
		return false # studio:
	if not Settings.slide_buttons or pos.distance_to(center()) < radius * STUDIO_HYSTERESIS: # studio: hysteresis 1.15
		return false
	for b in _all:
		if b != self and b.is_visible_in_tree() and b._held == -1 and pos.distance_to(b.center()) < b.radius:
			var finger := _held
			_held = -1
			queue_redraw()
			b._take(finger, pos)
			return true
	return false


## studio: C1 - the drag from the last sampled point to `pos`, tried every STUDIO_STEP px, so a fast slide that crosses a
## button between two events is still caught.
func _studio_slide(pos: Vector2) -> bool: # studio:
	var from := _studio_last if _studio_last != Vector2.INF else pos # studio:
	var steps := maxi(1, ceili(from.distance_to(pos) / STUDIO_STEP)) # studio:
	for k in range(1, steps + 1): # studio:
		if _slide(from.lerp(pos, float(k) / steps)): # studio:
			_studio_last = Vector2.INF # studio:
			return true # studio:
	_studio_last = pos # studio:
	return false # studio:


func _take(finger: int, pos: Vector2) -> void:
	_studio_last = pos # studio:
	studio_keep = false # studio:
	_held = finger
	_held_for = 0.0
	_start = pos
	_finger = pos
	_swiped = false
	if swipes.is_empty():
		_pulse = 1.0
		pressed.emit()
	queue_redraw()


## Its spot and size from the player's layout (or its default).
func place() -> void:
	margin = Settings.button_spot(id, home_margin)
	radius = home_radius * Settings.button_scale
	queue_redraw()


func set_verb(new_verb: String) -> void:
	verb = new_verb
	queue_redraw()


func center() -> Vector2:
	var c := get_viewport().get_visible_rect().size - margin
	var r := Vector2(radius, radius) * 1.15
	return c.clamp(_safe.position + r, _safe.end - r) # studio: notch-safe (29 Sep phone fix) on his public centre


func _update_safe() -> void: # studio:
	_safe = preload("res://scripts/ui/safe_area.gd").rect(get_viewport())
	queue_redraw()


## True if a touch here would press this button (the camera drag leaves those alone).
func covers(pos: Vector2) -> bool:
	return is_visible_in_tree() and pos.distance_to(center()) < radius * 1.25


## The flick a finger this far from the start would make ("" if none yet).
func _flick(moved: Vector2) -> String:
	if moved.length() <= SWIPE:
		return ""
	var dir := ("left" if moved.x < 0.0 else "right") if absf(moved.x) > absf(moved.y) else ("up" if moved.y < 0.0 else "down")
	return dir if swipes.has(dir) else ""


func _input(event: InputEvent) -> void:
	# studio: own the complete gesture even when pressing opens a panel and hides this button.
	# studio: touch emulation sends a mouse press afterwards; it must not hit the new panel.
	if _held != -1 and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT: # studio:
		get_viewport().set_input_as_handled() # studio:
		return # studio:
	if editing:
		return
	if event is InputEventScreenDrag and visible and event.index == _held and _studio_slide(event.position): # studio: sampled every 8 px
		return
	if event is InputEventScreenDrag and visible and event.index == _held and not swipes.is_empty() and not _swiped:
		_finger = event.position
		var dir := _flick(_finger - _start)
		if dir != "":
			_swiped = true
			_pulse = 1.0
			swiped.emit(dir)
		queue_redraw()
		return
	if not event is InputEventScreenTouch:
		return
	var touch := event as InputEventScreenTouch
	# studio: the release is ours even if the press opened a panel and hid the button (or it stays held for ever)
	if not touch.pressed and touch.index == _held:
		if visible and not swipes.is_empty() and not _swiped:
			_pulse = 1.0
			pressed.emit()        # a plain tap, now that it wasn't a flick
		released.emit()           # (held_for() still answers here)
		_held = -1
		get_viewport().set_input_as_handled() # studio:
		queue_redraw()
	elif visible and touch.pressed and touch.position.distance_to(center()) < radius * 1.25:
		_held = touch.index
		_held_for = 0.0
		_start = touch.position
		_finger = touch.position
		_swiped = false
		_studio_last = touch.position # studio:
		studio_keep = false # studio:
		if swipes.is_empty():
			_pulse = 1.0
			pressed.emit()
		get_viewport().set_input_as_handled()
		queue_redraw()


func _process(delta: float) -> void:
	if _held != -1:
		_held_for += delta
	if _pulse > 0.0 or _shake > 0.0 or _ready_ring > 0.0 or meter < 1.0 or lit:
		_pulse = maxf(_pulse - delta * 4.0, 0.0)
		_shake = maxf(_shake - delta * 3.0, 0.0)
		_ready_ring = maxf(_ready_ring - delta * 2.5, 0.0)
		queue_redraw()


func set_meter(value: float) -> void:
	if value != meter:
		if sweep and meter < 1.0 and value >= 1.0:
			_ready_ring = 1.0     # cooled down: a ring flies out
		meter = value
		queue_redraw()


func _draw() -> void:
	if preload("res://scripts/studio/player/button_skin.gd").draw(self, editing): # studio: C1 - the same look in about two draw calls (shapes from one shared texture, then the words); his drawing below stays as the fallback
		return # studio:
	var c := center() + Vector2(sin(_shake * 40.0) * 6.0 * _shake, 0)
	var active := (verb != "" or icon != "") and not dim
	var pressed := _held != -1 and not editing
	var r := radius * (1.0 - 0.08 * _pulse - (0.04 if pressed else 0.0))
	var big := home_radius >= 60.0          # the main action button gets the gold bezel
	var alpha := 1.0 if active else 0.55
	var hue := accent if not dim else accent.lerp(Color(0.5, 0.5, 0.55), 0.6)
	var cooling := sweep and meter < 1.0
	# Shadow underneath, and a soft glow in its colour while it's ready (abilities) or lit.
	_blob(c + Vector2(0, r * 0.1), Vector2.ONE * r * 1.32, Color(0, 0, 0, 0.42 * alpha))
	if (sweep and not cooling and active) or (lit and not sweep):
		var beat := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
		_blob(c, Vector2.ONE * r * (1.45 + 0.08 * beat), Color(hue, 0.3 + 0.2 * beat))
	# Body: dark glass with a glow of its colour in the middle, deeper at the edge.
	var body := Color(0.05, 0.06, 0.09, 0.9 if active else 0.7)
	if lit and not sweep:
		body = Color(lit_fill.darkened(0.2), 0.92)
	draw_circle(c, r, body, true, -1.0, true)
	_blob(c + Vector2(0, r * 0.12), Vector2.ONE * r * 0.98, Color(hue.darkened(0.15), (0.5 if active else 0.22) + (0.25 if pressed else 0.0)))
	_blob(c + Vector2(0, -r * 0.05), Vector2.ONE * r * 0.55, Color(hue.lightened(0.3), 0.18 if active else 0.05))
	# Gloss: a soft light across the top half.
	_blob(c + Vector2(0, -r * 0.5), Vector2(r * 0.7, r * 0.36), Color(1, 1, 1, 0.16 if active else 0.06))
	# The ring: a metal band lit from the top left (gold and thick on the main button).
	draw_arc(c, r + (4.5 if big else 2.5), 0.0, TAU, 72, Color(0, 0, 0, 0.55 * alpha), 2.0, true)
	if big:
		_metal_ring(c, r, 6.0, Color(1.0, 0.93, 0.66, alpha), Color(0.5, 0.31, 0.1, alpha))
		draw_arc(c, r - 3.5, 0.0, TAU, 72, Color(0.15, 0.08, 0.02, 0.6 * alpha), 1.5, true)
	else:
		_metal_ring(c, r, 3.5, Color(hue.lightened(0.55), 0.95 * alpha), Color(hue.darkened(0.55), 0.9 * alpha))
	draw_arc(c, r + (2.4 if big else 1.4), PI * 1.08, PI * 1.62, 20, Color(1, 1, 1, 0.45 * alpha), 1.2, true)
	if cooling:               # cooldown: a dark wedge over what's still to wait, the ring refilling in colour
		var pts := PackedVector2Array([c])
		var steps := maxi(int(48 * (1.0 - meter)), 2)
		for k in steps + 1:
			var a := -PI * 0.5 + TAU * meter + TAU * (1.0 - meter) * k / steps
			pts.append(c + Vector2(cos(a), sin(a)) * (r - 1.5))
		draw_colored_polygon(pts, Color(0.01, 0.02, 0.04, 0.62))
		if meter > 0.0:
			draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * meter, maxi(int(64 * meter), 2), accent.lightened(0.2), 4.0, true)
	elif meter < 1.0:         # stamina: the rim empties anticlockwise from the top
		draw_arc(c, r + 1.0, 0.0, TAU, 64, Color(0.02, 0.03, 0.05, 0.85), 6.0, true)
		if meter > 0.0:
			draw_arc(c, r + 1.0, -PI * 0.5, -PI * 0.5 + TAU * meter, maxi(int(64 * meter), 2), meter_color, 5.0, true)
	if _ready_ring > 0.0:
		var t := 1.0 - _ready_ring
		_blob(c, Vector2.ONE * r * (1.2 + 0.5 * t), Color(accent.lightened(0.3), 0.5 * _ready_ring))
		draw_arc(c, r * (1.0 + 0.45 * t), 0.0, TAU, 48, Color(accent.lightened(0.5), _ready_ring), 4.0 * _ready_ring + 1.0, true)
	var font := get_theme_default_font()
	var ink := Color(CREAM, 1.0 if active else 0.45)
	if cooling and seconds > 0:
		_glyph(c + Vector2(0, -r * 0.08), r * 0.4, Color(CREAM, 0.22))
		_text(font, c + Vector2(0, r * 0.2), str(seconds), int(r * 0.66), Color(1, 1, 1, 0.97))
	elif icon != "":
		var label := verb != "" and not sweep    # abilities show just their symbol (the name is in the class screen)
		var at := c + Vector2(0, -r * 0.12 if label else 0.0)
		var s := r * (0.42 if label else 0.56)
		_glyph(at + Vector2(0, maxf(r * 0.05, 2.0)), s, Color(0, 0, 0, 0.5 * ink.a))   # drop shadow
		_glyph(at, s, ink)
		if label:
			_text(font, c + Vector2(0, r * 0.62), verb, int(maxf(r * 0.25, 11.0)), Color(CREAM, 0.88 if active else 0.4))
	else:
		var size := int(font_size * radius / maxf(home_radius, 1.0))
		var up := size * 0.3 if sub != "" else 0.0
		_text(font, c + Vector2(0, size * 0.35 - up), verb if verb != "" else "·", size, ink)
		if sub != "":
			_text(font, c + Vector2(0, size * 0.35 + size * 0.45), sub, int(size * 0.6), Color(CREAM, 0.6 if active else 0.3))
	_draw_flicks(c, r, font)
	if editing:
		draw_arc(c, r + 8.0, 0.0, TAU, 48, Color(GOLD, 0.9), 2.0, true)


func _blob(at: Vector2, radii: Vector2, col: Color) -> void:
	Look.blob(self, at, radii, col)


func _metal_ring(c: Vector2, r: float, width: float, light: Color, dark: Color) -> void:
	Look.metal_ring(self, c, r, width, light, dark)


## Its symbol: an ability's (by id) or one of the drawn ones below.
func _glyph(at: Vector2, s: float, col: Color) -> void:
	if not AbilityIcons.draw(self, icon, at, s, col, Color(0.05, 0.06, 0.09, col.a)):
		_icon(at, s, col)


## The flicks: small marks at the rim, and while held their names pop out, the one you point at in gold.
func _draw_flicks(c: Vector2, r: float, font: Font) -> void:
	var pointing := _flick(_finger - _start) if _held != -1 else ""
	for dir: String in swipes:
		var at: Vector2 = DIRS[dir]
		var side := Vector2(-at.y, at.x)
		var tip := c + at * (r + 9.0)
		var col := Color(GOLD, 0.95) if dir == pointing else Color(CREAM, 0.6)
		draw_colored_polygon(PackedVector2Array([tip + at * 6.0, tip + side * 6.0, tip - side * 6.0]), col)
		if _held == -1 and not editing:
			continue
		var label: String = swipes[dir]
		var ls := 20 if dir == pointing else 16
		var p := c + at * (r + 34.0)
		if at.x != 0.0:
			var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, ls).x
			p.x += (lw / 2.0 + 4.0) * at.x
		var box := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, ls) + Vector2(16, 6)
		draw_rect(Rect2(p - box / 2.0, box), Color(0.05, 0.06, 0.1, 0.75 if dir == pointing else 0.55))
		_text(font, p + Vector2(0, ls * 0.35), label, ls, col)
	if pointing != "" and not _swiped:
		draw_line(c, _finger, Color(GOLD, 0.6), 3.0, true)


func _text(font: Font, at: Vector2, text: String, size: int, col: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string_outline(font, at - Vector2(w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(int(size * 0.18), 3), Color(0, 0, 0, 0.55 * col.a))
	draw_string(font, at - Vector2(w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## The drawn symbols, `s` is about half their size.
func _icon(c: Vector2, s: float, col: Color) -> void:
	match icon:
		"sword", "heavy":
			var d := Vector2(1, -1).normalized()       # blade up and to the right
			var n := Vector2(d.y, -d.x)
			var base := c - d * s * 0.55
			var tip := c + d * s * 1.05
			draw_colored_polygon(PackedVector2Array([base + n * s * 0.16, tip - d * s * 0.22 + n * s * 0.16, tip,
				tip - d * s * 0.22 - n * s * 0.16, base - n * s * 0.16]), col)
			draw_line(base + n * s * 0.42, base - n * s * 0.42, col, s * 0.16, true)
			draw_line(base, base - d * s * 0.42, col, s * 0.13, true)
			draw_circle(base - d * s * 0.5, s * 0.1, col, true, -1.0, true)
			if icon == "heavy":                  # a sweeping arc: a big swing
				draw_arc(c + Vector2(-s * 0.15, s * 0.15), s * 1.15, PI * 0.62, PI * 1.12, 16, Color(GOLD, col.a), s * 0.12, true)
				draw_arc(c + Vector2(-s * 0.15, s * 0.15), s * 0.85, PI * 0.68, PI * 1.05, 12, Color(GOLD, col.a * 0.7), s * 0.08, true)
		"shield":
			var pts := PackedVector2Array()
			pts.append(c + Vector2(-s * 0.8, -s * 0.85))
			pts.append(c + Vector2(0, -s * 1.0))
			pts.append(c + Vector2(s * 0.8, -s * 0.85))
			for k in range(1, 9):                # the lower edge curving to a point
				var t := k / 8.0
				pts.append(c + Vector2(s * 0.8 * (1.0 - t) * (1.0 - t * 0.3), s * (-0.85 + 1.95 * sin(t * PI * 0.5))))
			for k in range(7, 0, -1):
				var t := k / 8.0
				pts.append(c + Vector2(-s * 0.8 * (1.0 - t) * (1.0 - t * 0.3), s * (-0.85 + 1.95 * sin(t * PI * 0.5))))
			draw_colored_polygon(pts, col)
			draw_line(c + Vector2(0, -s * 0.7), c + Vector2(0, s * 0.7), Color(0.07, 0.09, 0.14, 0.7), s * 0.12, true)
		"roll":
			draw_arc(c, s * 0.8, -PI * 0.35, PI * 1.25, 24, col, s * 0.2, true)
			var a := -PI * 0.35
			var p := c + Vector2(cos(a), sin(a)) * s * 0.8
			var fwd := Vector2(-sin(a), cos(a)) * -1.0
			var out := Vector2(cos(a), sin(a))
			draw_colored_polygon(PackedVector2Array([p + fwd * s * 0.45, p + out * s * 0.35, p - out * s * 0.35]), col)
		"bow":                                   # a bow and its string
			draw_arc(c + Vector2(-s * 0.35, 0), s * 0.95, -PI * 0.42, PI * 0.42, 18, col, s * 0.17, true)
			var top := c + Vector2(-s * 0.35, 0) + Vector2(cos(-PI * 0.42), sin(-PI * 0.42)) * s * 0.95
			var bottom := c + Vector2(-s * 0.35, 0) + Vector2(cos(PI * 0.42), sin(PI * 0.42)) * s * 0.95
			draw_line(top, bottom, col, s * 0.06, true)
			draw_line(c + Vector2(-s * 0.5, 0), c + Vector2(s * 0.75, 0), col, s * 0.08, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.95, 0), c + Vector2(s * 0.62, -s * 0.16), c + Vector2(s * 0.62, s * 0.16)]), col)
		"sneak":                                 # a half-closed eye
			var lid := PackedVector2Array()
			for k in 13:
				var t := k / 12.0
				lid.append(c + Vector2(lerpf(-s, s, t), -sin(t * PI) * s * 0.25))
			for k in range(1, 12):
				var t := 1.0 - k / 12.0
				lid.append(c + Vector2(lerpf(-s, s, t), sin(t * PI) * s * 0.55))
			draw_colored_polygon(lid, col)
			draw_circle(c + Vector2(0, s * 0.12), s * 0.3, Color(0.07, 0.09, 0.14, 0.9), true, -1.0, true)
			draw_line(c + Vector2(-s * 1.1, -s * 0.05), c + Vector2(s * 1.1, -s * 0.05), col, s * 0.14, true)
