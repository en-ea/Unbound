extends Node
## The note tool against the live village, with no window: --note-test (with --studio=village/live, --headless).
## Waits for the villagers, lets the recorder fill for a few seconds, presses "note" (UnboundNotes.capture), and
## reads the folder back. Prints NOTETEST PASS/FAIL lines, then "NOTETEST complete failures=N", and quits.
## Its notes go to user://notes-test-live (cleared first), never among real notes.

const UnboundNotes := preload("res://scripts/studio/notes/unbound_notes.gd")
const NoteStore := preload("res://scripts/studio/notes/note_store.gd")
const NoteFlow := preload("res://scripts/studio/notes/note_flow.gd")

const ROOT := "user://notes-test-live"
const SETTLE := 6.0            # s of village life before the press

var _fails := 0


func _ready() -> void:
	_clear(ROOT)                                   # its own test notes from last time
	NoteStore.root = ROOT
	_run.call_deferred()


static func _clear(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for sub in DirAccess.get_directories_at(dir):
		_clear(dir.path_join(sub))
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)


func _run() -> void:
	var tree := get_tree()
	for i in 1200:                                  # the village and its bodies (up to 20 s at 60 frames)
		var live := tree.current_scene.get_node_or_null("VillageLive") if tree.current_scene != null else null
		if live != null and live.get("registry") != null and live.registry.ready_for_play and not live.registry.bodies.is_empty():
			break
		await tree.process_frame
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < SETTLE * 1000.0:
		await tree.process_frame
	var press := Time.get_ticks_usec()
	var dir: String = UnboundNotes.capture(get_viewport()).dir
	var cost_ms := (Time.get_ticks_usec() - press) / 1000.0
	_check(dir != "", "the press wrote a note (%s, in %.0f ms)" % [dir, cost_ms])
	var state: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("state.json")))
	_check(state is Dictionary, "state.json reads back")
	if state is Dictionary:
		var people: Array = state.get("people", [])
		var named := people.filter(func(p: Dictionary) -> bool: return p.get("name", "") != "" and p.has("mover") and p.has("driver"))
		_check(not people.is_empty() and named.size() == people.size(), "%d people near the player, each with a name, a mover and who drives them" % people.size())
		_check(people.is_empty() or people.any(func(p: Dictionary) -> bool: return p.has("activity")), "what they are doing is there")
		var recent: Dictionary = state.get("recent", {})
		_check(recent.get("samples", []).size() >= int(SETTLE / 0.5) - 2, "the last seconds were sampled (%d samples)" % recent.get("samples", []).size())
		_check(recent.get("frames", {}).get("count", 0) > 0 and not recent.get("memory", []).is_empty(), "frame times and memory are there")
		_check(state.get("log", {}).has("errors"), "the error log is there (%d errors so far)" % state.get("log", {}).get("errors_seen", -1))
		_check(state.get("build", {}).get("id", "") != "" and state.get("world", {}).has("clock"), "the build and the village clock are there (%s, %s)" % [state.build.id, state.world.get("clock", "")])
		print("NOTETEST people: ", people.map(func(p: Dictionary) -> String: return "%s %s %s" % [p.name, p.driver, p.get("mover", {}).get("why", "")]))
	_check(FileAccess.file_exists(dir.path_join("save.json")) and FileAccess.get_file_as_string(dir.path_join("save.json")).length() > 1000, "the save as it stands is in the note")
	_check(NoteStore.drafts().has(dir), "it stays a draft until saved (a crash keeps it)")
	await _flow_saved()
	await _flow_discarded()
	await _flow_back_button()
	print("NOTETEST complete failures=%d" % _fails)
	NoteStore.root = "user://notes"
	get_tree().quit(0 if _fails == 0 else 1)


## The screens, driven like a finger would: circle Bram on a stand-in screen, pick a kind, type, save.
func _flow_saved() -> void:
	var tree := get_tree()
	var size := get_viewport().get_visible_rect().size
	var statuses := []
	NoteFlow.open(tree, _fake_capture.bind(size), func(st: String) -> void: statuses.append(st))
	await tree.process_frame
	var flow := tree.get_first_node_in_group("note_flow")
	_check(flow != null and tree.paused, "a press freezes the game and opens the circle screen")
	for i in 25:                                     # a loop round Bram at (300, 300), drawn with a finger
		var at := Vector2(300, 300) + Vector2(cos(TAU * i / 24.0), sin(TAU * i / 24.0)) * 70.0
		if i == 0:
			_touch(at, true)
		else:
			_drag(at)
		await tree.process_frame
	_touch(Vector2(370, 300), false)
	await tree.process_frame
	_check(_label_with(flow, "Circled: Bram") != null, "Bram is named as the circle closes")
	_press(flow, "Next")
	await tree.process_frame
	_press(flow, "Looks Wrong")
	var text := _find(flow, func(n: Node) -> bool: return n is TextEdit) as TextEdit
	text.text = "Bram stands in the doorway"
	text.text_changed.emit()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1500:
		await tree.process_frame
	var dir: String = flow.get("_dir")
	_check(NoteStore.read(dir).get("text") == "Bram stands in the doorway" and NoteStore.read(dir).get("status") == "draft",
		"typed words reach the disk within a second, still a draft")
	_press(flow, "Save")
	await tree.process_frame
	var note := NoteStore.read(dir)
	_check(note.get("status") == "saved" and note.get("kind") == "looks wrong" and note.get("circled", []).map(func(x: Variant) -> int: return int(x)) == [7]
		and FileAccess.file_exists(dir.path_join("marked.jpg")) and FileAccess.file_exists(dir.path_join("crop.jpg")),
		"saved: kind, words, Bram circled, the marked screen and the crop (%s)" % [note.get("circled")])
	_check(not tree.paused and tree.get_first_node_in_group("note_flow") == null and statuses == ["saved"], "the game resumes as it was")


func _flow_discarded() -> void:
	var tree := get_tree()
	var statuses := []
	NoteFlow.open(tree, _fake_capture.bind(get_viewport().get_visible_rect().size), func(st: String) -> void: statuses.append(st))
	await tree.process_frame
	var flow := tree.get_first_node_in_group("note_flow")
	var dir: String = flow.get("_dir")
	_press(flow, "No circle")
	await tree.process_frame
	_press(flow, "Discard")
	await tree.process_frame
	_check(tree.get_first_node_in_group("note_flow") != null, "one tap on Discard does not lose the note")
	_press(flow, "Tap again to discard")
	await tree.process_frame
	_check(NoteStore.read(dir).get("status") == "discarded" and not tree.paused and statuses == ["discarded"], "a second tap discards it (the capture is kept, marked discarded)")


func _flow_back_button() -> void:
	var tree := get_tree()
	var statuses := []
	NoteFlow.open(tree, _fake_capture.bind(get_viewport().get_visible_rect().size), func(st: String) -> void: statuses.append(st))
	await tree.process_frame
	var flow := tree.get_first_node_in_group("note_flow")
	var dir: String = flow.get("_dir")
	flow.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await tree.process_frame
	_check(NoteStore.read(dir).get("status") == "draft" and not tree.paused and statuses == ["draft"], "the back button keeps it as a draft and resumes")


## The real capture, with a stand-in screen (no renderer here) and two people on it.
func _fake_capture(size: Vector2) -> Dictionary:
	var got := UnboundNotes.capture(get_viewport())
	var screen := Image.create(int(size.x), int(size.y), false, Image.FORMAT_RGB8)
	screen.fill(Color(0.3, 0.5, 0.3))
	got.screen = screen
	got.things = [{"id": 7, "name": "Bram", "screen": [300.0, 300.0]}, {"id": 9, "name": "Wren", "screen": [900.0, 400.0]}]
	return got


func _touch(at: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = at
	e.pressed = down
	get_viewport().push_input(e, true)   # in the viewport's own units (headless has no real window)


func _drag(at: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = at
	get_viewport().push_input(e, true)   # in the viewport's own units (headless has no real window)


func _press(root: Node, text: String) -> void:
	var b := _find(root, func(n: Node) -> bool: return n is Button and n.text == text) as Button
	if b == null:
		_check(false, "a button reading \"%s\"" % text)
		return
	if b.toggle_mode:
		b.button_pressed = not b.button_pressed
	else:
		b.pressed.emit()


func _label_with(root: Node, text: String) -> Label:
	return _find(root, func(n: Node) -> bool: return n is Label and text in n.text) as Label


func _find(root: Node, test: Callable) -> Node:
	if test.call(root):
		return root
	for c in root.get_children():
		var f := _find(c, test)
		if f != null:
			return f
	return null


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("NOTETEST %s %s" % ["PASS" if ok else "FAIL", what])
