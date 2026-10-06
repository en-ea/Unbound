extends PanelContainer
## The notice board (plan VILLAGE-LIFE-AND-NEWS section 7): what the player knows of the village, small, under Enea's
## quest tracker in the same dark-glass style. One line by default - the newest - that folds to a tab with a count
## of what is unread after a few seconds; tap it to open three lines, tap a line for its story (its phases, oldest
## first, and what someone there saw). Each line: an icon for its kind, the headline, how the player knows and when,
## and, while it is going on near them, which way and how far. Generic: it shows a source's desk, not villages.
##
##   Board.add_to(hud, tracker)    one line in the HUD (ui/hud.gd), after the tracker: the board sits under it
##   source (found in the group "news"): desk: Array of lines (stories.gd desk), header() -> String,
##          thread(story) -> Array[String], signal changed, read(story)
##   Board.blocks_stick(tree, point) -> bool   a touch there begins on the board or the tracker (ui/joystick.gd asks: a tap
##                                       on them is not the stick)
const UIStyle := preload("res://scripts/ui/ui_style.gd")
const EdgeCues := preload("res://scripts/studio/news/edge_cues.gd")

const WIDTH := 330.0
const FOLD_AFTER := 7.0         # seconds a new line stays open before the board folds to its tab
const OPEN_LINES := 3
const GAP_BELOW := 8.0          # pixels under the tracker
const KIND_COLOURS := {"argument": Color(1.0, 0.72, 0.4), "crime": Color(1.0, 0.5, 0.42), "death": Color(0.85, 0.85, 0.95),
	"feast": Color(1.0, 0.86, 0.45), "meeting": Color(0.6, 0.85, 1.0), "hunger": Color(0.9, 0.75, 0.45),
	"mood": Color(0.8, 0.8, 0.8), "feud": Color(1.0, 0.55, 0.55), "birth": Color(0.7, 1.0, 0.75)}
const HOW_WORDS := {"seen": "you saw it", "heard": "you heard it", "announced": "the bell", "word": "people are saying"}

var source: Node
var _tracker: Control
var _hud: Node
var _box: VBoxContainer
var _header: Label
var _rows: VBoxContainer
var _thread: VBoxContainer
var _open := false               # three lines, by the player's tap
var _open_story := -1            # a story's thread open
var _folded := true
var _fold_left := 0.0
var _last_top := -1
var _look_left := 0.0


static func add_to(hud: Node, tracker: Control) -> void:
	var board := PanelContainer.new()
	board.set_script(load("res://scripts/studio/news/board.gd"))
	board.set("_tracker", tracker)
	board.set("_hud", hud)
	board.name = "NewsBoard"
	hud.add_child(board)
	tracker.add_to_group("stick_ignores")
	var cues := Control.new()
	cues.set_script(EdgeCues)
	cues.name = "NewsEdgeCues"
	hud.add_child(cues)


static func blocks_stick(tree: SceneTree, point: Vector2) -> bool:
	for c in tree.get_nodes_in_group("stick_ignores"):
		if c is Control and (c as Control).is_visible_in_tree() and (c as Control).get_global_rect().has_point(point):
			return true
	return false


## Enea's camera asks every Control this one-argument question.
func covers(point: Vector2) -> bool:
	return is_visible_in_tree() and get_global_rect().has_point(point)


func _ready() -> void:
	add_to_group("stick_ignores")
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.06, 0.07, 0.1, 0.55)
	box.set_corner_radius_all(12)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 7
	add_theme_stylebox_override("panel", box)
	custom_minimum_size.x = WIDTH
	mouse_filter = Control.MOUSE_FILTER_STOP
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 3)
	add_child(_box)
	_header = UIStyle.label(_box, "", 14, true)
	_header.add_theme_color_override("font_color", Color(1.0, 0.9, 0.65, 0.9))
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	_box.add_child(_rows)
	_thread = VBoxContainer.new()
	_thread.add_theme_constant_override("separation", 2)
	_box.add_child(_thread)
	gui_input.connect(_on_input)
	visible = false


func _process(delta: float) -> void:
	_look_left -= delta
	if source == null or not is_instance_valid(source):
		source = get_tree().get_first_node_in_group("news")
		if source != null and source.has_signal("changed"):
			source.changed.connect(_refresh)
		if source == null:
			visible = false
			return
		_refresh()
	if _tracker != null:
		var top: float = _tracker.position.y + (_tracker.size.y + GAP_BELOW if _tracker.visible else 0.0)
		position = Vector2(_tracker.position.x, top)
	var shown: bool = not source.desk.is_empty() and (_hud == null or _hud.get("_hearts") == null or (_hud.get("_hearts") as Control).visible) \
		and not (_tracker != null and bool(_tracker.get("hidden_for_talk")))
	visible = shown
	if not shown:
		return
	if not _folded and not _open:
		_fold_left -= delta
		if _fold_left <= 0.0:
			_folded = true
			_refresh()
	if _look_left <= 0.0:
		_look_left = 0.5
		_refresh()                       # (the "when" and the arrows age)


func _refresh() -> void:
	if source == null:
		return
	var desk: Array = source.desk
	if desk.is_empty():
		return
	var top := int(desk[0].story) * 100000 + int(desk[0].when)
	if top != _last_top:
		if _last_top != -1:
			_folded = false               # something new: the board opens on it for a while
			_fold_left = FOLD_AFTER
		_last_top = top
	_header.text = source.header()
	for c in _rows.get_children():
		c.queue_free()
	for c in _thread.get_children():
		c.queue_free()
	var unread := 0
	for line: Dictionary in desk:
		if line.get("new", false):
			unread += 1
	if _folded and not _open:
		_header.text = "%s  ·  %d new" % [source.header(), unread] if unread > 0 else source.header()
		size = get_combined_minimum_size()
		return
	var count := OPEN_LINES if _open else 1
	for i in mini(count, desk.size()):
		_row(desk[i])
	if _open_story >= 0 and source.has_method("thread"):
		for text: String in source.thread(_open_story):
			var l := UIStyle.label(_thread, "· " + text, 13, true)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size.x = WIDTH - 24.0
	reset_size()


func _row(line: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.set_meta("story", int(line.story))
	_rows.add_child(row)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(16, 16)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.draw.connect(_draw_icon.bind(icon, str(line.kind), int(line.severity)))
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var head := UIStyle.label(text, str(line.headline), 16)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.custom_minimum_size.x = WIDTH - 70.0
	if line.get("new", false):
		head.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	UIStyle.label(text, "%s · %s" % [HOW_WORDS.get(str(line.how), ""), _when(int(line.when))], 12, true)
	var where := _where(line)
	if not where.is_empty():
		var w := UIStyle.label(row, where, 13, true)
		w.size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _on_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	accept_event()
	if _folded and not _open:
		_open = true
		_folded = false
	elif _open:
		var story := _story_at(get_global_mouse_position())
		if story >= 0 and story != _open_story:
			_open_story = story
			if source.has_method("read"):
				source.read(story)
		else:
			_open = false
			_open_story = -1
			_folded = true
	else:
		_open = true
	_refresh()


func _story_at(point: Vector2) -> int:
	for row in _rows.get_children():
		if row is Control and (row as Control).get_global_rect().has_point(point):
			return int(row.get_meta("story", -1))
	return -1


## How long ago, in the village's own words (game minutes: a game day is 1440).
func _when(minute: int) -> String:
	var v = VillageSession.village
	var now := int(v.runtime.now) if v != null else minute
	var ago := now - minute
	if ago < 30:
		return "just now"
	if ago < 180:
		return "a while ago"
	if now / 1440 == minute / 1440:
		var m := minute % 1440
		return "this morning" if m < 720 else ("this afternoon" if m < 1080 else "this evening")
	if now / 1440 - minute / 1440 == 1:
		return "yesterday"
	return "days ago"


## While it goes on: which way and how far, from where the player stands and looks.
func _where(line: Dictionary) -> String:
	var v = VillageSession.village
	if v == null or int(line.get("until", -1)) <= int(v.runtime.now) or (line.at as Vector2) == Vector2.INF:
		return ""
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var camera := get_viewport().get_camera_3d()
	if player == null or camera == null:
		return ""
	var to: Vector2 = (line.at as Vector2) - Vector2(player.global_position.x, player.global_position.z)
	var d := to.length()
	if d < 4.0:
		return "here"
	var ahead := Vector2(-camera.global_basis.z.x, -camera.global_basis.z.z).normalized()
	var turn := rad_to_deg(ahead.angle_to(to.normalized()))
	var arrow := "↑" if absf(turn) < 30.0 else ("↓" if absf(turn) > 150.0 else ("→" if turn > 0.0 else "←"))
	if absf(turn) >= 30.0 and absf(turn) < 75.0:
		arrow = "↗" if turn > 0.0 else "↖"
	elif absf(turn) > 105.0 and absf(turn) <= 150.0:
		arrow = "↘" if turn > 0.0 else "↙"
	return "%d m %s" % [int(round(d)), arrow]


func _draw_icon(c: Control, kind: String, severity: int) -> void:
	var col: Color = KIND_COLOURS.get(kind, Color(0.85, 0.85, 0.85))
	if severity >= 3:
		col = col.lerp(Color(1.0, 0.35, 0.3), 0.35)
	var m := c.size * 0.5
	match kind:
		"argument":                       # two voices facing each other
			c.draw_circle(m + Vector2(-3.5, 0), 3.5, col)
			c.draw_circle(m + Vector2(3.5, 0), 3.5, col)
			c.draw_line(m + Vector2(-1, -6), m + Vector2(1, -2), col, 1.5)
		"crime":                          # a broken ring
			c.draw_arc(m, 6.0, 0.4, TAU - 0.4, 16, col, 2.0)
		"death":                          # a mark of mourning
			c.draw_line(m + Vector2(0, -7), m + Vector2(0, 7), col, 2.0)
			c.draw_line(m + Vector2(-4.5, -2.5), m + Vector2(4.5, -2.5), col, 2.0)
		"meeting":                        # people gathered
			for i in 3:
				c.draw_circle(m + Vector2(-5 + i * 5, 2), 2.2, col)
			c.draw_circle(m + Vector2(0, -4), 2.2, col)
		"feast":
			c.draw_polygon(PackedVector2Array([m + Vector2(0, -7), m + Vector2(2, -2), m + Vector2(7, -2), m + Vector2(3, 1),
				m + Vector2(5, 7), m + Vector2(0, 3.5), m + Vector2(-5, 7), m + Vector2(-3, 1), m + Vector2(-7, -2), m + Vector2(-2, -2)]),
				PackedColorArray([col]))
		"hunger", "mood":                 # a slack line
			c.draw_polyline(PackedVector2Array([m + Vector2(-7, 2), m + Vector2(-3, -2), m + Vector2(1, 2), m + Vector2(5, -2), m + Vector2(7, 0)]), col, 2.0)
		_:
			c.draw_circle(m, 4.0, col)
