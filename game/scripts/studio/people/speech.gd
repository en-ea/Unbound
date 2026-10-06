extends Node
## Who speaks when (Pass 3, stage 5: the plan's L8). One manager for every line said aloud near the player - a bark, a
## scene's line, words overheard from a conversation - and for the murmur of talk with no words. It decides what is
## shown and heard, so speech reads instead of piling up. Generic: bodies, words, priorities and voices, not villages.
##
##   speech.say(body, text, priority, group := 0, voice := "", seconds := 0.0) -> bool   a line with words (false: not
##                                                                                 shown, outranked and not worth waiting;
##                                                                                 a situated line is always taken: true)
##   speech.murmur(body, group, voice, seconds)   talking with no words: their voice in blips, no bubble
##   speech.hush(group)                           that conversation stops: its bubble goes, its voice falls silent
##   speech.camera                                the view the screen rules are judged in (else the viewport's)
##   speech.role                                  Callable(body) -> {priority, situation} or {}: who this speaker is in
##                                                what is happening (the one struck, one stepping in, the crowd), for a
##                                                line said with no group of its own (B7)
##   speech.adopt(body, label_of)                 another system's bubble over a speaker (Callable -> Label3D, e.g.
##                                                Enea's greeting): kept hidden, its words said through these rules
##
##   priority   STRUCK 4 (the one struck, an answer to the player) > STEP_IN 3 (who steps in, a shout) > SCENE 2 (a
##              scene, a rescue) > TALK 1 (words overheard from a conversation)
##
##   one voice a group    a new line or murmur in a group ends the one before: a conversation never talks over itself
##   taking turns         in a situation (role's situation), a line from another speaker that does not outrank the one
##                        up waits its turn (up to TURN_WAIT; the crowd's does not wait); the same words just said there
##                        are not said again; the one struck outranks whoever steps in, who outranks the crowd
##   two bubbles at most  on screen; a new line takes the place of the lowest shown if it outranks it (equal: if nearer
##                        the camera), else waits up to WAIT for a place, then is dropped
##   fixed size           every bubble reads the same at any distance (a line LINE_SHARE of the screen high), wrapping at
##                        WIDTH_SHARE of the screen wide
##   no overlap           a bubble that would cover another on screen rises above it; one that would have to rise
##                        further than RISE_MOST lines is held back until the other goes
##   on screen            a bubble that would run off the screen's side is moved in to EDGE px from it
##   clear of what is up  a bubble that would sit on space already in use moves the least way (sideways, up or down,
##                        staying on screen) that clears it. In use, read each frame: whatever the HUD draws that is
##                        visible and smaller than a quarter of the screen (Enea's minimap, quest card, top buttons,
##                        the FPS line ...), and every node in group OCCUPIED: a Control's rectangle, a world label's
##                        (a name tag), or occupied_rects() (Hands: the controls and their words)
##   readable             the words sit on a dark backing (BACKING, as the controls' words: Hands), PAD of a line
##                        round them, so cream ink reads over any world (contrast >= 4.5, the probe's pixel check)
##   voices               blips in the speaker's own voice while they talk, quieter with distance, at most MAX_VOICES at
##                        once (the nearest), none further than HEAR
##
## Each bubble is a Label3D named NAME under the speaker's body (the motion watcher reads them there).

const NAME := "SpeechBubble"
const STRUCK := 4
const STEP_IN := 3
const SCENE := 2
const TALK := 1
const MAX_BUBBLES := 2
const WAIT := 1.6             # seconds a line waits for a place on screen
const LINE_SHARE := 0.034     # of the screen's height: one line of a bubble
const WIDTH_SHARE := 0.27     # of the screen's width: a bubble wraps here
const RISE_MOST := 2.5        # lines a bubble may rise to clear another
const TURN_WAIT := 4.0        # seconds a line waits for its turn in a situation
const EDGE := 12.0            # px a bubble keeps from the screen's sides
const BACKING := Color(0.05, 0.04, 0.03, 0.8)   # the controls' backing (player/hands.gd)
const INK := Color(1.0, 0.97, 0.88)
const PAD := 0.3              # of a line: the backing's margin round the words
const BACK := "SpeechBacking"
const OCCUPIED := "speech_occupied"
const HUD_SHARE := 0.25       # a HUD control this share of the screen or more is a layer, not a panel in use
const CLEAR := 6.0            # px a bubble keeps from space in use
const MOVE_MOST := 0.4        # of the screen's width: further than this, a bubble stays put rather than wander off
static var _back_texture: ImageTexture
const HEIGHT := 2.3           # metres over the feet (a grown body; a child's is scaled with them)
const SECONDS_PER_WORD := 0.42
const MIN_SECONDS := 2.4
const MAX_VOICES := 3
const HEAR := 14.0            # metres from the camera's subject: voices beyond are not played
const BLIP := Vector2(0.09, 0.17)     # seconds between blips
const PHRASE := Vector2i(4, 10)       # blips in a phrase, then a breath
const BREATH := Vector2(0.35, 0.8)
const VOICE_DB := -16.0

var camera: Camera3D
var role: Callable             # body -> {priority, situation} or {} (residents.gd: from the person's plan)
var listener: Node3D           # the player (voices are judged by distance to them); else the camera
var voice_path := "res://assets/sounds/voice_%s_%d.wav"

var _shown: Array = []         # Line, at most MAX_BUBBLES
var _waiting: Array = []       # Line
var _murmurs := {}             # group -> Murmur
var _players: Array = []       # AudioStreamPlayer3D pool
var _voices := {}              # voice -> Array[AudioStream]
var _n := 0
var _adopted: Array = []       # Adopted
var _said := {}                # situation -> the last words said there
var _hud_controls: Array = []  # the HUD's Controls, refreshed every second (their rectangles are read each frame)
var _hud_in := 0.0
var _taken: Array[Rect2] = []  # this frame's space in use


class Line:
	var body: Node3D
	var text := ""
	var priority := 0
	var group := 0
	var voice := ""
	var seconds := 0.0
	var age := 0.0
	var waited := 0.0
	var label: Label3D
	var back: Sprite3D         # the backing behind the words
	var rise := 0.0            # metres it has risen to clear another bubble
	var rise_want := 0.0
	var turn := false          # waiting for its turn in a situation (not for a place on screen)
	var situated := false      # its group is a situation (role): turns are taken there


class Adopted:
	var body: Node3D
	var label_of: Callable
	var on := false
	var text := ""


class Murmur:
	var body: Node3D
	var voice := ""
	var left := 0.0
	var next := 0.0
	var in_phrase := 0
	var player: AudioStreamPlayer3D


func _ready() -> void:
	process_priority = 20      # after the people have moved this frame
	for i in MAX_VOICES:
		var p := AudioStreamPlayer3D.new()
		p.volume_db = VOICE_DB
		p.unit_size = 4.0
		p.max_distance = HEAR + 4.0
		p.bus = &"Master"
		add_child(p)
		_players.append(p)


## A line with words over `body`. False if it will not be shown (outranked, and nothing frees a place in time).
func say(body: Node3D, text: String, priority: int, group := 0, voice := "", seconds := 0.0) -> bool:
	if not is_instance_valid(body) or text.is_empty():
		return false
	var line := Line.new()
	line.body = body
	line.text = text
	line.priority = priority
	line.group = group if group != 0 else body.get_instance_id()
	line.voice = voice
	line.seconds = seconds if seconds > 0.0 else maxf(MIN_SECONDS, text.split(" ", false).size() * SECONDS_PER_WORD)
	var situated := false
	if group == 0 and role.is_valid():
		var r: Dictionary = role.call(body)
		if not r.is_empty():
			line.priority = int(r.get("priority", priority))
			line.group = int(r.get("situation", line.group))
			situated = true
	line.situated = situated
	if situated:
		# (A situated line is always taken - shown, waiting its turn, or left unsaid - so the act that says it goes on:
		# people/steps/say.gd waits for true.)
		if str(_said.get(line.group, "")) == text:
			return true                         # just said there: nobody repeats it
		var up := _speaking(line.group)
		if up != null and up.body != body and up.priority >= line.priority:
			if line.priority <= TALK:
				return true                     # the crowd does not wait its turn: the remark goes unheard
			line.turn = true
			_waiting.append(line)               # its turn comes when the one speaking is done
			return true
		if up != null:
			_drop(up)                           # outranked (or their own next words): the one up stops
		for other: Line in _shown.duplicate():
			if other.body == body:
				_drop(other)                    # (one bubble a body)
	else:
		_end_group(line.group, null)          # one voice a group: the line before it ends
	for other: Line in _shown.duplicate():
		if other.body == body:
			_drop(other)                     # (one bubble a body: the new one replaces it)
	if _place(line):
		return true
	if line.priority >= SCENE:
		_waiting.append(line)               # worth a short wait
		return true
	return situated                         # (the crowd's remark with no place goes unheard; its act goes on)


## Another system's bubble over `body` (label_of() -> its Label3D, or null while it has none): kept hidden, and each
## time it comes up (or its words change) they are said here, as the crowd's, under the same rules.
func adopt(body: Node3D, label_of: Callable) -> void:
	var a := Adopted.new()
	a.body = body
	a.label_of = label_of
	_adopted.append(a)


## The line up in a group (null when none).
func _speaking(group: int) -> Line:
	for l: Line in _shown:
		if l.group == group:
			return l
	return null


## Talking with no words: their voice, in blips, for `seconds`.
func murmur(body: Node3D, group: int, voice: String, seconds: float) -> void:
	if not is_instance_valid(body) or voice == "":
		return
	var shown: Line = null
	for l: Line in _shown:
		if l.group == group:
			shown = l
	if shown != null and shown.body != body:
		_drop(shown)                         # someone else in the group speaks now
	var m: Murmur = _murmurs.get(group)
	if m == null:
		m = Murmur.new()
		_murmurs[group] = m
	m.body = body
	m.voice = voice
	m.left = seconds
	m.next = 0.0
	m.in_phrase = 0


func hush(group: int) -> void:
	_end_group(group, null)


## Whether a body has words up.
func saying(body: Node3D) -> bool:
	for l: Line in _shown:
		if l.body == body:
			return true
	return false


func _process(delta: float) -> void:
	var cam := camera if is_instance_valid(camera) else get_viewport().get_camera_3d()
	for l: Line in _shown.duplicate():
		l.age += delta
		if not is_instance_valid(l.body) or not l.body.is_visible_in_tree() or l.age >= l.seconds:
			_drop(l)
	for l: Line in _waiting.duplicate():
		l.waited += delta
		if not is_instance_valid(l.body) or l.waited > (TURN_WAIT if l.turn else WAIT):
			_waiting.erase(l)
		elif l.turn:
			var up := _speaking(l.group)
			if up == null or up.body == l.body:
				_waiting.erase(l)
				if str(_said.get(l.group, "")) != l.text:
					l.turn = false
					for other: Line in _shown.duplicate():
						if other.body == l.body:
							_drop(other)            # (one bubble a body)
					if not _place(l):
						l.waited = 0.0
						_waiting.append(l)      # its turn, but no place on screen yet: the short wait
		elif _place(l):
			_waiting.erase(l)
	_adopted_step()
	if cam != null:
		_layout(cam, delta)
	for l: Line in _shown:
		_fade(l)
	_voices_step(delta)


## Puts a line on screen if there is a place for it (or it outranks the lowest there).
func _place(line: Line) -> bool:
	for other: Line in _shown.duplicate():
		if other.body == line.body:
			if other.priority > line.priority:
				return false                 # one bubble a body: what they are saying now outranks it
			_drop(other)
	if _shown.size() >= MAX_BUBBLES:
		var lowest: Line = null
		for l: Line in _shown:
			if lowest == null or l.priority < lowest.priority or (l.priority == lowest.priority and _far(l) > _far(lowest)):
				lowest = l
		if lowest.priority > line.priority or (lowest.priority == line.priority and _far(lowest) <= _far(line)):
			return false
		_drop(lowest)
	line.label = _bubble(line)
	_shown.append(line)
	if line.situated:
		if _said.size() > 64:
			_said.clear()
		_said[line.group] = line.text
	if line.voice != "":
		murmur(line.body, line.group, line.voice, minf(line.seconds * 0.6, 2.5))
	return true


func _far(l: Line) -> float:
	var cam := camera if is_instance_valid(camera) else get_viewport().get_camera_3d()
	if cam == null or not is_instance_valid(l.body):
		return INF
	return cam.global_position.distance_to(l.body.global_position)


func _drop(l: Line) -> void:
	_shown.erase(l)
	_free(l.label)
	_free(l.back)
	l.label = null
	l.back = null


static func _free(label: Variant) -> void:     # (untyped: a label its body took with it is already freed)
	if is_instance_valid(label):
		if label.get_parent() != null:
			label.get_parent().remove_child(label)     # gone this frame (another may take its place at once)
		label.queue_free()


func _end_group(group: int, but: Line) -> void:
	for l: Line in _shown.duplicate():
		if l.group == group and l != but:
			_drop(l)
	for l: Line in _waiting.duplicate():
		if l.group == group:
			_waiting.erase(l)
	var m: Murmur = _murmurs.get(group)
	if m != null:
		m.left = 0.0


func _adopted_step() -> void:
	for a: Adopted in _adopted.duplicate():
		if not is_instance_valid(a.body):
			_adopted.erase(a)
			continue
		var label: Label3D = a.label_of.call()
		if not is_instance_valid(label):
			continue
		label.visible = false                   # its words show here instead
		var on := label.modulate.a > 0.05 and not label.text.is_empty() and a.body.is_visible_in_tree()
		if on and (not a.on or label.text != a.text):
			say(a.body, label.text, TALK, a.body.get_instance_id())
		elif not on and a.on:
			for l: Line in _shown.duplicate():
				if l.body == a.body and l.group == a.body.get_instance_id():
					_drop(l)                    # they stopped: the words go with them
		a.on = on
		a.text = label.text


## A bubble: fixed in size on screen, wrapping at a share of its width, sized for this screen and camera.
func _bubble(line: Line) -> Label3D:
	for name: String in [NAME, BACK]:
		var old := line.body.get_node_or_null(name)
		if old != null:
			old.free()
	var label := Label3D.new()
	label.name = NAME
	label.text = line.text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.no_depth_test = true
	label.font_size = 40
	label.outline_size = 12
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.render_priority = 3
	label.outline_render_priority = 2
	label.modulate = Color(INK, 0.0)
	label.outline_modulate = Color(0.08, 0.06, 0.1, 0.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	var cam := camera if is_instance_valid(camera) else get_viewport().get_camera_3d()
	var fov := deg_to_rad(cam.fov if cam != null else 60.0)
	var screen := get_viewport().get_visible_rect().size
	var tall_at_one := 2.0 * tan(fov * 0.5)                  # what a fixed-size label sees: the screen 1 m away
	var line_world := LINE_SHARE * tall_at_one                 # one line, in those metres
	label.pixel_size = line_world / (label.font_size * 1.25)  # (a line is about 1.25 font sizes high)
	label.width = WIDTH_SHARE * tall_at_one * (screen.x / maxf(screen.y, 1.0)) / label.pixel_size
	var size := line.body.scale.y if line.body.scale.y > 0.0 else 1.0
	label.scale = Vector3.ONE / size
	label.position = Vector3(0.0, HEIGHT * (1.0 if size >= 1.0 else 0.8) / size, 0.0)
	line.body.add_child(label)
	line.back = _backing(label)
	line.body.add_child(line.back)
	return label


## The dark backing behind a label's words: a fixed-size billboard sized to the wrapped text plus PAD of a line,
## its bottom PAD below the words' (they sit on the label's origin, bottom aligned).
func _backing(label: Label3D) -> Sprite3D:
	if _back_texture == null:
		var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_back_texture = ImageTexture.create_from_image(image)
	var text := _text_size(label)
	var pad := PAD * label.font_size * 1.25
	var back := Sprite3D.new()
	back.name = BACK
	back.texture = _back_texture
	back.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	back.fixed_size = true
	back.no_depth_test = true
	back.shaded = false
	back.render_priority = 1                                   # under the outline (2) and the words (3)
	back.pixel_size = label.pixel_size
	back.modulate = Color(BACKING, 0.0)
	var sx := (text.x + 2.0 * pad) / 16.0
	var sy := (text.y + 2.0 * pad) / 16.0
	back.scale = label.scale * Vector3(sx, sy, 1.0)
	back.offset = Vector2(0.0, 8.0 - pad / sy)                 # its centre half the words' height up
	back.position = label.position
	return back


static func _text_size(label: Label3D) -> Vector2:
	var font := label.font if label.font != null else ThemeDB.fallback_font
	return font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, label.width, label.font_size)


func _fade(l: Line) -> void:
	if not is_instance_valid(l.label):
		return
	var a := minf(clampf(l.age / 0.15, 0.0, 1.0), clampf((l.seconds - l.age) / 0.5, 0.0, 1.0))
	l.label.modulate.a = a
	l.label.outline_modulate.a = a * 0.85
	if is_instance_valid(l.back):
		l.back.modulate.a = BACKING.a * a


## Two bubbles that would overlap on screen: the later (or lower) rises above the other; too far, it waits.
func _layout(cam: Camera3D, delta: float) -> void:
	_taken = _occupied(cam, delta)
	for l: Line in _shown:
		l.rise_want = 0.0
		_keep_on_screen(cam, l)
	if _shown.size() == 2:
		var a: Line = _shown[0]
		var b: Line = _shown[1]
		var ra := _rect(cam, a)
		var rb := _rect(cam, b)
		if ra.size != Vector2.ZERO and rb.size != Vector2.ZERO:
			ra.position.y += a.rise / _metres_per_px(cam, a)     # where each would be without rising (judged from there,
			rb.position.y += b.rise / _metres_per_px(cam, b)     # or a risen one would fall back and rise again)
			if ra.grow(6.0).intersects(rb) and (_going(a) or _going(b)):
				_drop(a if _going(a) else b)          # one already fading out gives way at once
			elif ra.grow(6.0).intersects(rb):
				var low: Line = b if b.priority <= a.priority else a
				var high: Line = a if low == b else b
				var r_low := rb if low == b else ra
				var r_high := ra if low == b else rb
				var per_px := _metres_per_px(cam, low)
				var need := (r_low.end.y - r_high.position.y) + 8.0 + high.rise / _metres_per_px(cam, high)
				var lines := need / maxf(r_low.size.y / _lines_of(low), 1.0)
				if lines > RISE_MOST:
					_shown.erase(low)                 # no room: back to waiting a moment (the first to go makes room)
					_free(low.label)
					_free(low.back)
					low.label = null
					low.back = null
					low.waited = 0.0
					_waiting.append(low)
				else:
					low.rise_want = need * per_px
	for l: Line in _shown:
		# (at screen speed: a far bubble's metres are many pixels' worth less, so a fixed rate in metres crawled)
		l.rise = move_toward(l.rise, l.rise_want, delta * maxf(6.0, absf(l.rise_want - l.rise) * 12.0))
		if is_instance_valid(l.label):
			var size := l.body.scale.y if l.body.scale.y > 0.0 else 1.0
			l.label.position.y = (HEIGHT * (1.0 if size >= 1.0 else 0.8) + l.rise) / size
			if is_instance_valid(l.back):
				l.back.position = l.label.position


## Whether a line is in its last half second, fading out.
func _going(l: Line) -> bool:
	return l.seconds - l.age < 0.5


func _lines_of(l: Line) -> float:
	if not is_instance_valid(l.label):
		return 1.0
	var font := l.label.font if l.label.font != null else ThemeDB.fallback_font
	var one := font.get_height(l.label.font_size)
	var all := font.get_multiline_string_size(l.label.text, HORIZONTAL_ALIGNMENT_CENTER, l.label.width, l.label.font_size).y
	return maxf(all / maxf(one, 1.0), 1.0)


## Moves a bubble in from the screen's sides, then the least way off any space in use (its label's offset, in its own
## pixels: fixed size, so at any distance; the backing follows).
func _keep_on_screen(cam: Camera3D, l: Line) -> void:
	if not is_instance_valid(l.label):
		return
	l.label.offset = Vector2.ZERO
	var r := _rect(cam, l)
	if r.size == Vector2.ZERO:
		_offset(l, Vector2.ZERO, cam)
		return
	var screen := get_viewport().get_visible_rect().size
	var move := Vector2.ZERO
	if r.position.x < EDGE:
		move.x = EDGE - r.position.x
	elif r.end.x > screen.x - EDGE:
		move.x = (screen.x - EDGE) - r.end.x
	move = _clear_move(r, move, screen)
	_offset(l, move, cam)


## The least move (from `move`, already on screen) that takes `r` off every space in use and keeps it on screen.
func _clear_move(r: Rect2, move: Vector2, screen: Vector2) -> Vector2:
	var area := Rect2(Vector2(EDGE, EDGE), screen - Vector2(EDGE, EDGE) * 2.0)
	var at := Rect2(r.position + move, r.size)
	if not _hits(at):
		return move
	var tries: Array[Vector2] = []
	for t: Rect2 in _taken:
		if not at.grow(CLEAR).intersects(t):
			continue
		var gap := CLEAR + 2.0
		tries.append(move + Vector2(t.position.x - gap - at.end.x, 0.0))     # to its left
		tries.append(move + Vector2(t.end.x + gap - at.position.x, 0.0))     # to its right
		tries.append(move + Vector2(0.0, t.position.y - gap - at.end.y))     # above it
		tries.append(move + Vector2(0.0, t.end.y + gap - at.position.y))     # below it
	tries.sort_custom(func(a: Vector2, b: Vector2) -> bool: return (a - move).length() < (b - move).length())
	for m: Vector2 in tries:
		var there := Rect2(r.position + m, r.size)
		if (m - move).length() <= MOVE_MOST * screen.x and area.encloses(there) and not _hits(there):
			return m
	return move                                          # nowhere clear near: it stays (the words still have their backing)


func _hits(r: Rect2) -> bool:
	for t: Rect2 in _taken:
		if r.grow(CLEAR).intersects(t):
			return true
	return false


## Sets a bubble's screen move (px, y down) as its label's and backing's offsets.
func _offset(l: Line, move: Vector2, cam: Camera3D) -> void:
	var screen := get_viewport().get_visible_rect().size
	var px_per_m := screen.y / (2.0 * tan(deg_to_rad(cam.fov) * 0.5))
	var per := l.label.pixel_size * px_per_m                       # screen px per label px
	l.label.offset = Vector2(move.x / per, -move.y / per)          # (a label's offset is y up)
	if is_instance_valid(l.back):
		var k := l.back.scale / l.label.scale
		var pad := PAD * l.label.font_size * 1.25
		l.back.offset = Vector2(l.label.offset.x / k.x, 8.0 - pad / k.y + l.label.offset.y / k.y)


## The screen's space in use this frame (see the header).
func _occupied(cam: Camera3D, delta: float) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var screen := get_viewport().get_visible_rect().size
	_hud_in -= delta
	if _hud_in <= 0.0:
		_hud_in = 1.0
		_hud_controls.clear()
		for hud: Node in get_tree().get_nodes_in_group("hud"):
			for c: Node in hud.find_children("*", "Control", true, false):
				_hud_controls.append(c)
	for c in _hud_controls:
		if not is_instance_valid(c) or not (c as Control).is_visible_in_tree() or (c as Control).is_in_group(OCCUPIED):
			continue
		var r := (c as Control).get_global_rect()
		if r.size.x < 2.0 or r.size.y < 2.0 or r.get_area() >= HUD_SHARE * screen.x * screen.y or _faint(c):
			continue
		out.append(r)
	for n: Node in get_tree().get_nodes_in_group(OCCUPIED):
		if n.has_method("occupied_rects"):
			for r: Rect2 in n.occupied_rects():
				out.append(r)
		elif n is Control and (n as Control).is_visible_in_tree():
			out.append((n as Control).get_global_rect())
		elif n is Label3D and (n as Label3D).visible and (n as Label3D).modulate.a > 0.05:   # (a tag fading out still reads)
			var r := _world_label_rect(cam, n as Label3D)
			if r.size != Vector2.ZERO:
				out.append(r)
	return out


## Whether a Control shows too faintly to count (its own and its parents' alpha).
static func _faint(c: Node) -> bool:
	var a := 1.0
	var n := c
	while n is CanvasItem:
		a *= (n as CanvasItem).modulate.a * (n as CanvasItem).self_modulate.a
		n = n.get_parent()
	return a < 0.3


## A world-size label's rectangle on screen (a name tag: centred on its point).
func _world_label_rect(cam: Camera3D, label: Label3D) -> Rect2:
	if label.text.is_empty() or cam.is_position_behind(label.global_position):
		return Rect2()
	var font := label.font if label.font != null else ThemeDB.fallback_font
	var text := font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, -1, label.font_size)
	var d := cam.global_position.distance_to(label.global_position)
	var screen := get_viewport().get_visible_rect().size
	var px_per_m := screen.y / (2.0 * d * tan(deg_to_rad(cam.fov) * 0.5))
	var size := text * label.pixel_size * px_per_m
	var at := cam.unproject_position(label.global_position)
	var outline := float(label.outline_size) * label.pixel_size * px_per_m       # (a thick outline reads past the glyphs)
	return Rect2(at - size * 0.5, size).grow(outline)


## A bubble's rectangle on screen (a fixed-size billboard: its text's size seen from 1 m, wherever it is). From the
## font, not the label's mesh (which a renderer makes later, and a headless one never).
func _rect(cam: Camera3D, l: Line) -> Rect2:
	if not is_instance_valid(l.label) or not l.label.is_inside_tree() or cam.is_position_behind(l.label.global_position):
		return Rect2()
	var font := l.label.font if l.label.font != null else ThemeDB.fallback_font
	var text := font.get_multiline_string_size(l.label.text, HORIZONTAL_ALIGNMENT_CENTER, l.label.width, l.label.font_size)
	var at := cam.unproject_position(l.label.global_position)
	var screen := get_viewport().get_visible_rect().size
	var px_per_m := screen.y / (2.0 * tan(deg_to_rad(cam.fov) * 0.5))       # at 1 m (fixed size)
	var pad := PAD * l.label.font_size * 1.25                                # (the backing's margin)
	var w := (text.x + 2.0 * pad) * l.label.pixel_size * px_per_m
	var h := (text.y + 2.0 * pad) * l.label.pixel_size * px_per_m
	at.x += l.label.offset.x * l.label.pixel_size * px_per_m                # (moved in from a side, or off space in use)
	at.y -= l.label.offset.y * l.label.pixel_size * px_per_m
	at.y += pad * l.label.pixel_size * px_per_m
	return Rect2(at.x - w * 0.5, at.y - h, w, h)


## The board's pixel check: for each bubble up, its backing's screen rectangle (words and margin) and the margin's
## inner ring, where only the backing shows. The probe compares the rendered words with what is behind them there.
func label_boxes(cam: Camera3D = null) -> Array:
	var view := cam if is_instance_valid(cam) else (camera if is_instance_valid(camera) else get_viewport().get_camera_3d())
	var out := []
	if view == null:
		return out
	for l: Line in _shown:
		var r := _rect(view, l)
		if r.size == Vector2.ZERO:
			continue
		var margin := PAD * l.label.font_size * 1.25 * l.label.pixel_size * get_viewport().get_visible_rect().size.y / (2.0 * tan(deg_to_rad(view.fov) * 0.5))
		var ring := r.grow(-margin * 0.4)
		var samples := PackedVector2Array()
		var x := ring.position.x
		while x <= ring.end.x:
			samples.append_array([Vector2(x, ring.position.y), Vector2(x, ring.end.y)])
			x += 3.0
		out.append({"name": l.text, "rect": r, "words": r.grow(-margin), "samples": samples, "alpha": l.label.modulate.a})
	return out


## Metres of rise (at the body) that move a bubble one pixel up the screen.
func _metres_per_px(cam: Camera3D, l: Line) -> float:
	var d := cam.global_position.distance_to(l.body.global_position)
	var screen := get_viewport().get_visible_rect().size
	return 2.0 * d * tan(deg_to_rad(cam.fov) * 0.5) / maxf(screen.y, 1.0)


## The voices: the nearest murmurs get a player each and blip in phrases.
func _voices_step(delta: float) -> void:
	var ear: Node3D = listener if is_instance_valid(listener) else (camera if is_instance_valid(camera) else null)
	var live: Array = []
	for group: int in _murmurs.keys():
		var m: Murmur = _murmurs[group]
		m.left -= delta
		if m.left <= 0.0 or not is_instance_valid(m.body) or not m.body.is_visible_in_tree():
			if m.player != null:
				m.player.stop()
				m.player = null
			_murmurs.erase(group)
			continue
		if ear != null and ear.global_position.distance_to(m.body.global_position) > HEAR:
			if m.player != null:
				m.player = null
			continue
		live.append(m)
	if ear != null:
		live.sort_custom(func(a: Murmur, b: Murmur) -> bool:
			return ear.global_position.distance_squared_to(a.body.global_position) < ear.global_position.distance_squared_to(b.body.global_position))
	var free: Array = _players.duplicate()
	for i in live.size():
		var m: Murmur = live[i]
		if i >= MAX_VOICES:
			m.player = null
			continue
		if m.player != null:
			free.erase(m.player)
	for i in mini(live.size(), MAX_VOICES):
		var m: Murmur = live[i]
		if m.player == null and not free.is_empty():
			m.player = free.pop_back()
		if m.player == null:
			continue
		m.next -= delta
		if m.next > 0.0:
			continue
		_n += 1
		var clips := _voice(m.voice)
		if clips.is_empty():
			continue
		m.player.global_position = m.body.global_position + Vector3(0.0, 1.5 * m.body.scale.y, 0.0)
		m.player.stream = clips[_n % clips.size()]
		m.player.pitch_scale = 0.9 + 0.25 * _noise(_n, 1)
		m.player.play()
		m.in_phrase += 1
		if m.in_phrase >= PHRASE.x + int(_noise(_n, 2) * (PHRASE.y - PHRASE.x)):
			m.in_phrase = 0
			m.next = lerpf(BREATH.x, BREATH.y, _noise(_n, 3))
		else:
			m.next = lerpf(BLIP.x, BLIP.y, _noise(_n, 4))


func _voice(voice: String) -> Array:
	if not _voices.has(voice):
		var clips: Array = []
		for i in 8:
			var path := voice_path % [voice, i]
			if ResourceLoader.exists(path):
				clips.append(load(path))
		_voices[voice] = clips
	return _voices[voice]


static func _noise(k: int, salt: int) -> float:
	return float(posmod(hash(k * 7919 + salt * 104729), 100000)) / 100000.0
