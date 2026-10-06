extends CanvasLayer
## The note screens, game-agnostic: freeze, circle, write, save, resume.
##
##   NoteFlow.open(tree, capture, closed)
##     capture: () -> {"dir": the note's folder, already on disk (NoteStore.begin), "screen": Image, "things": Array}
##              (called first, before anything is drawn over the game)
##     closed:  (status: "saved" | "discarded" | "draft") -> void
##
## 1. The game pauses where it is; the frozen screen fills the display. A finger circles what it means (several
##    strokes, undo), or taps it; who is circled shows as it is drawn (NoteMarks.circled).
## 2. The note: what was circled, one tap for the kind, and the text. Rotation is unlocked here and never forced;
##    the game's own orientation comes back on closing. The text is written to the note as it is typed (a crash
##    keeps it). Save, or discard (tapped twice); the back button keeps it as a draft.
## 3. The game resumes as it was (paused or not, and its orientation).

const NoteStore := preload("res://scripts/studio/notes/note_store.gd")
const NoteMarks := preload("res://scripts/studio/notes/note_marks.gd")

const KINDS := ["bug", "looks wrong", "feels wrong", "idea", "good"]
const TEXT_SAVE_EVERY := 1.0   # s: typed text reaches the disk at most this late
const INK := Color(1.0, 0.25, 0.2)
const PANEL := Color(0.07, 0.08, 0.1, 0.96)

var capture: Callable
var closed: Callable

var _dir := ""
var _screen: Image
var _things: Array = []
var _strokes: Array = []                 # PackedVector2Array per stroke, in the screen image's pixels
var _drawing := PackedVector2Array()
var _was_paused := false
var _orientation := DisplayServer.SCREEN_SENSOR_LANDSCAPE
var _kind := ""
var _text: TextEdit
var _text_dirty := false
var _text_left := 0.0
var _discard_armed := false
var _circle_view: Control
var _canvas: Control
var _circled_label: Label
var _note_view: Control
var _keyboard_gap: Control
var _top_row: Control                    # the marked screen and who was circled
var _done := false


static func open(tree: SceneTree, the_capture: Callable, the_closed: Callable = Callable()) -> void:
	if tree.get_first_node_in_group("note_flow") != null:
		return                                    # one note at a time
	var flow := (load("res://scripts/studio/notes/note_flow.gd") as GDScript).new() as CanvasLayer
	flow.capture = the_capture
	flow.closed = the_closed
	tree.root.add_child(flow)


func _ready() -> void:
	add_to_group("note_flow")
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_paused = get_tree().paused                 # what to give back, whatever happens next
	_orientation = DisplayServer.screen_get_orientation()
	var got: Dictionary = capture.call()
	_dir = got.get("dir", "")
	_screen = got.get("screen")
	_things = got.get("things", [])
	if _dir == "":
		_close("failed")
		return
	get_tree().paused = true
	if _screen == null or _screen.is_empty():
		_open_note()                              # nothing to circle on (no renderer): straight to the words
	else:
		_open_circle()


func _process(delta: float) -> void:
	if _text_dirty:
		_text_left -= delta
		if _text_left <= 0.0:
			_save_text()
	if _keyboard_gap != null:
		var kb := DisplayServer.virtual_keyboard_get_height()
		var ui_per_px := get_viewport().get_visible_rect().size.y / maxf(1.0, DisplayServer.window_get_size().y)
		_keyboard_gap.custom_minimum_size.y = kb * ui_per_px
		if _top_row != null:                         # landscape with the keyboard up: the words get the room
			var win := DisplayServer.window_get_size()
			_top_row.visible = not (kb > 0 and win.x > win.y)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not _done:
		_save_text()
		_close("draft")


# --- 1. circle ---------------------------------------------------------------------------------------------------

func _open_circle() -> void:
	_circle_view = _full(Control.new())
	var shot := TextureRect.new()
	shot.texture = ImageTexture.create_from_image(_screen)
	shot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shot.stretch_mode = TextureRect.STRETCH_SCALE
	_full(shot, _circle_view)
	_canvas = _full(Control.new(), _circle_view)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.gui_input.connect(_on_canvas_input)
	_canvas.draw.connect(_draw_strokes)
	var bar := _bar(_circle_view)
	_circled_label = _label(bar, "Circle what you mean, or tap it", 22)
	_circled_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(bar, "Undo", func() -> void:
		if not _strokes.is_empty():
			_strokes.pop_back()
			_after_stroke())
	_button(bar, "No circle", func() -> void:
		_strokes.clear()
		_open_note())
	_button(bar, "Next", _open_note)


func _on_canvas_input(event: InputEvent) -> void:
	var k := Vector2(_screen.get_size()) / _canvas.size     # UI units -> the screen image's pixels
	if event is InputEventScreenTouch and event.index == 0:
		if event.pressed:
			_drawing = PackedVector2Array([event.position * k])
		elif _drawing.size() > 0:
			_strokes.append(_drawing)
			_drawing = PackedVector2Array()
			_after_stroke()
		_canvas.queue_redraw()
	elif event is InputEventScreenDrag and event.index == 0 and _drawing.size() > 0:
		var p: Vector2 = event.position * k
		if p.distance_to(_drawing[_drawing.size() - 1]) > 3.0:
			_drawing.append(p)
			_canvas.queue_redraw()


func _after_stroke() -> void:
	var names := _circled_names()
	_circled_label.text = "Circled: " + ", ".join(names) if not names.is_empty() else "Circle what you mean, or tap it"
	_canvas.queue_redraw()


func _draw_strokes() -> void:
	var k := _canvas.size / Vector2(_screen.get_size())
	for stroke: PackedVector2Array in _strokes + [_drawing]:
		if stroke.size() == 1:
			_canvas.draw_circle(stroke[0] * k, 6.0, INK)
		elif stroke.size() > 1:
			var pts := PackedVector2Array()
			for p in stroke:
				pts.append(p * k)
			_canvas.draw_polyline(pts, INK, 5.0, true)


func _circled_ids() -> Array:
	return NoteMarks.circled(_strokes, _things, float(_screen.get_height())) if _screen != null else []


func _circled_names() -> PackedStringArray:
	return NoteMarks.names_of(_circled_ids(), _things)


# --- 2. the note -------------------------------------------------------------------------------------------------

func _open_note() -> void:
	if _circle_view != null:
		_circle_view.queue_free()
		_circle_view = null
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR)   # unlocked, not forced
	NoteStore.update(_dir, {"strokes": _strokes.map(func(s: PackedVector2Array) -> Array: return Array(s).map(func(p: Vector2) -> Array: return [snappedf(p.x, 0.1), snappedf(p.y, 0.1)])),
		"circled": _circled_ids(), "circled_names": _circled_names()})
	_note_view = _full(Control.new())
	var back := ColorRect.new()
	back.color = PANEL
	_full(back, _note_view)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	_full(margin, _note_view)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	col.add_child(bar)
	var discard := _button(bar, "Discard", func() -> void: pass)
	discard.pressed.connect(func() -> void:
		if _discard_armed:
			NoteStore.discard(_dir)
			_close("discarded")
		else:
			_discard_armed = true
			discard.text = "Tap again to discard")
	var title := _label(bar, "Note", 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(bar, "Save", _save)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	col.add_child(top)
	_top_row = top
	if _screen != null and not _screen.is_empty():
		var thumb := TextureRect.new()
		thumb.texture = ImageTexture.create_from_image(NoteMarks.marked(_screen, _strokes))
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.custom_minimum_size = Vector2(260, 120)
		top.add_child(thumb)
	var names := _circled_names()
	var circled := _label(top, ("Circled: " + ", ".join(names)) if not names.is_empty() else "Nothing circled", 20)
	circled.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	circled.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var kinds := HFlowContainer.new()
	kinds.add_theme_constant_override("h_separation", 10)
	kinds.add_theme_constant_override("v_separation", 10)
	col.add_child(kinds)
	var group := ButtonGroup.new()
	group.allow_unpress = true
	for kind: String in KINDS:
		var chip := _button(kinds, kind.capitalize(), func() -> void: pass)
		chip.toggle_mode = true
		chip.button_group = group
		chip.toggled.connect(func(on: bool) -> void:
			_kind = kind if on else ("" if _kind == kind else _kind)
			NoteStore.update(_dir, {"kind": _kind}))
	_text = TextEdit.new()
	_text.placeholder_text = "What do you see? (the keyboard's microphone dictates)"
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("font_size", 24)
	_text.text_changed.connect(func() -> void:
		_text_dirty = true
		_text_left = TEXT_SAVE_EVERY)
	col.add_child(_text)
	_keyboard_gap = Control.new()
	col.add_child(_keyboard_gap)
	_text.grab_focus()


func _save_text() -> void:
	if _text != null and _text_dirty:
		_text_dirty = false
		NoteStore.update(_dir, {"text": _text.text})


func _save() -> void:
	_text_dirty = true
	_save_text()
	var marked: Image = null
	var crop: Image = null
	if _screen != null and not _screen.is_empty():
		marked = NoteMarks.marked(_screen, _strokes)
		var rect := NoteMarks.crop_rect(_strokes, _screen.get_size())
		if rect.has_area():
			crop = _screen.get_region(rect)
	NoteStore.finish(_dir, marked, crop)
	_close("saved")


# --- 3. back to the game -----------------------------------------------------------------------------------------

func _close(status: String) -> void:
	if _done:
		return
	_done = true
	DisplayServer.screen_set_orientation(_orientation)
	get_tree().paused = _was_paused
	if closed.is_valid():
		closed.call(status)
	queue_free()


# --- small builders ----------------------------------------------------------------------------------------------

func _full(c: Control, parent: Node = null) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	(parent if parent != null else self).add_child(c)
	return c


func _bar(parent: Control) -> HBoxContainer:
	var back := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0.6)
	box.set_content_margin_all(12)
	back.add_theme_stylebox_override("panel", box)
	back.set_anchors_preset(Control.PRESET_TOP_WIDE)
	parent.add_child(back)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	back.add_child(bar)
	return bar


func _label(parent: Node, text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


func _button(parent: Node, text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(110, 56)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b
