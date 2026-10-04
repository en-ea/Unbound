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

var verb := ""
var icon := ""                   # a drawn symbol: sword, heavy, shield, roll, sneak (the verb goes small underneath)
var sub := ""                    # small second line under the verb (a hint like "hold: sprint")
var meter := 1.0                 # 0..1: a thin arc round the rim while below 1 (stamina)
var meter_color := Color(0.62, 0.9, 0.38)
var sweep := false               # show the meter as a cooldown: a dark wedge and the seconds left
var seconds := 0                 # with sweep: the whole seconds still to wait
var lit := false                 # glows while its hold action is on (sprinting)
var lit_fill := Color(0.2, 0.3, 0.16, 0.75)     # its colour then (abilities: the class's colour)
var dim := false                 # can't be used right now
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
	_all.append(self)
	tree_exiting.connect(func() -> void: _all.erase(self))


## Slide mode (Settings): a thumb held on one button slides onto another and presses it, no lifting.
## The button it left lets go quietly (a roll or a tap doesn't fire on the way out).
func _slide(pos: Vector2) -> bool:
	if not Settings.slide_buttons or pos.distance_to(center()) < radius * 1.1:
		return false
	for b in _all:
		if b != self and b.is_visible_in_tree() and b._held == -1 and pos.distance_to(b.center()) < b.radius:
			var finger := _held
			_held = -1
			queue_redraw()
			b._take(finger, pos)
			return true
	return false


func _take(finger: int, pos: Vector2) -> void:
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
	return get_viewport().get_visible_rect().size - margin


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
	if not visible or editing:
		return
	if event is InputEventScreenDrag and event.index == _held and _slide(event.position):
		return
	if event is InputEventScreenDrag and event.index == _held and not swipes.is_empty() and not _swiped:
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
	if touch.pressed and touch.position.distance_to(center()) < radius * 1.25:
		_held = touch.index
		_held_for = 0.0
		_start = touch.position
		_finger = touch.position
		_swiped = false
		if swipes.is_empty():
			_pulse = 1.0
			pressed.emit()
		get_viewport().set_input_as_handled()
		queue_redraw()
	elif not touch.pressed and touch.index == _held:
		if not swipes.is_empty() and not _swiped:
			_pulse = 1.0
			pressed.emit()        # a plain tap, now that it wasn't a flick
		released.emit()           # (held_for() still answers here)
		_held = -1
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
	var c := center() + Vector2(sin(_shake * 40.0) * 6.0 * _shake, 0)
	var active := (verb != "" or icon != "") and not dim
	var r := radius * (1.0 - 0.08 * _pulse)
	var fill := Color(0.07, 0.09, 0.14, 0.6 if active else 0.32)
	if lit:
		fill = lit_fill
	draw_circle(c + Vector2(0, 4), r, Color(0, 0, 0, 0.22), true, -1.0, true)
	draw_circle(c, r, fill, true, -1.0, true)
	draw_circle(c, r * 0.86, Color(1, 1, 1, 0.04 if active else 0.0), true, -1.0, true)
	if _held != -1 and not editing:
		draw_circle(c, r, Color(1, 1, 1, 0.1), true, -1.0, true)
	var rim := Color(1, 0.95, 0.8, 0.85 if active else 0.25)
	if lit and sweep:
		rim = meter_color.lightened(0.35)
	draw_arc(c, r, 0.0, TAU, 64, rim, 3.0, true)
	var cooling := sweep and meter < 1.0
	if cooling:               # cooldown: a dark wedge over what's still to wait
		var pts := PackedVector2Array([c])
		var steps := maxi(int(48 * (1.0 - meter)), 2)
		for k in steps + 1:
			var a := -PI * 0.5 + TAU * meter + TAU * (1.0 - meter) * k / steps
			pts.append(c + Vector2(cos(a), sin(a)) * (r - 2.0))
		draw_colored_polygon(pts, Color(0.02, 0.03, 0.06, 0.55))
		draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * maxf(meter, 0.01), maxi(int(64 * meter), 2), meter_color, 4.0, true)
	elif meter < 1.0:         # stamina: the rim empties anticlockwise from the top
		draw_arc(c, r, 0.0, TAU, 64, Color(0.05, 0.06, 0.1, 0.8), 5.0, true)
		if meter > 0.0:
			draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * meter, maxi(int(64 * meter), 2), meter_color, 5.0, true)
	if _ready_ring > 0.0:
		var t := 1.0 - _ready_ring
		draw_arc(c, r * (1.0 + 0.45 * t), 0.0, TAU, 48, Color(meter_color.lightened(0.4), _ready_ring), 4.0 * _ready_ring + 1.0, true)
	var font := get_theme_default_font()
	var ink := Color(CREAM, 1.0 if active else 0.4)
	if cooling and seconds > 0:
		_text(font, c + Vector2(0, r * 0.12), str(seconds), int(r * 0.62), Color(1, 1, 1, 0.95))
		_text(font, c + Vector2(0, r * 0.52), verb, int(maxf(r * 0.24, 11.0)), Color(CREAM, 0.55))
	elif icon != "":
		_icon(c + Vector2(0, -r * 0.12), r * 0.42, ink)
		if verb != "":
			_text(font, c + Vector2(0, r * 0.58), verb, int(maxf(r * 0.26, 11.0)), Color(CREAM, 0.85 if active else 0.35))
	else:
		var size := int(font_size * radius / maxf(home_radius, 1.0))
		var up := size * 0.3 if sub != "" else 0.0
		_text(font, c + Vector2(0, size * 0.35 - up), verb if verb != "" else "·", size, ink)
		if sub != "":
			_text(font, c + Vector2(0, size * 0.35 + size * 0.45), sub, int(size * 0.6), Color(CREAM, 0.6 if active else 0.3))
	_draw_flicks(c, r, font)
	if editing:
		draw_arc(c, r + 7.0, 0.0, TAU, 48, Color(GOLD, 0.9), 2.0, true)


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
	draw_string(font, at + Vector2(-w / 2.0 + 1.0, 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.45 * col.a))
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
