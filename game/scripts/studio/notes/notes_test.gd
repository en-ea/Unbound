extends RefCounted
## The note tool's pure checks, headless (no window):
##   godot --headless --path game --script res://scripts/studio/run.gd -- notes/notes_test

const NoteLog := preload("res://scripts/studio/notes/note_log.gd")
const NoteRecorder := preload("res://scripts/studio/notes/note_recorder.gd")
const NoteStore := preload("res://scripts/studio/notes/note_store.gd")
const NoteMarks := preload("res://scripts/studio/notes/note_marks.gd")
const UnboundNotes := preload("res://scripts/studio/notes/unbound_notes.gd")

const TEST_ROOT := "user://notes-test"


static func report() -> PackedStringArray:
	var out := PackedStringArray()
	for t: Callable in [_rings_stay_bounded, _memory_reading, _log_keeps_errors, _note_survives, _circle_names, _marks_drawn]:
		out.append_array(t.call())
	return out


static func _check(ok: bool, what: String) -> String:
	return ("PASS " if ok else "FAIL ") + what


## An hour of frames costs what a minute does: every list is a fixed ring.
static func _rings_stay_bounded() -> PackedStringArray:
	var rec := NoteRecorder.new()
	rec._ready()
	var calls := [0]
	rec.sampler = func() -> Variant:
		calls[0] += 1
		return [[1, 0.5, 0.5, 1.2, "day", "walk"]]
	for i in 3600 * 60 / 10:                    # six minutes of frames at 60 fps
		rec._process(1.0 / 60.0)
	for i in 120:
		rec.event("meeting", "a meets b %d" % i)
	var snap := rec.snapshot()
	rec.free()
	return PackedStringArray([
		_check(snap.frames.count == NoteRecorder.FRAMES and snap.frames.ms.size() == NoteRecorder.FRAMES,
			"frame times kept: the last %d (%d)" % [NoteRecorder.FRAMES, snap.frames.ms.size()]),
		_check(absf(snap.frames.p50 - 16.67) < 0.05, "frame p50 read back as 16.67 ms (%.2f)" % snap.frames.p50),
		_check(snap.samples.size() == NoteRecorder.SAMPLES and calls[0] >= 715, "samples kept: the last %d of %d" % [snap.samples.size(), calls[0]]),
		_check(snap.events.size() == NoteRecorder.EVENTS and snap.events[-1][2] == "a meets b 119", "events kept: the last %d, newest last" % snap.events.size()),
		_check(snap.memory.size() <= NoteRecorder.MEMORY_KEPT and snap.memory.size() >= 30, "memory samples every %d s (%d)" % [NoteRecorder.MEMORY_EVERY, snap.memory.size()]),
	])


static func _memory_reading() -> PackedStringArray:
	var m := NoteRecorder.memory_now(1.0)
	var os_side := OS.get_name() in ["Android", "Linux"]
	return PackedStringArray([_check(m.has("static_mb") and m.has("objects") and (m.has("vmrss_mb") or not os_side),
		"memory read: the engine's counters%s (%s)" % [", and the OS's" if os_side else " (no /proc here)", m])])


## Errors and lines reach the log, from push_error and print alike.
static func _log_keeps_errors() -> PackedStringArray:
	var log := NoteLog.new()
	OS.add_logger(log)
	push_error("notes_test: a made-up error")
	print("notes_test: a line")
	for i in NoteLog.LINES + 20:
		print("notes_test: filler %d" % i)
	OS.remove_logger(log)
	var snap := log.snapshot()
	var found := false
	for e: Dictionary in snap.errors:
		found = found or "a made-up error" in e.said
	return PackedStringArray([
		_check(found and snap.errors_seen >= 1, "an error is kept with where it came from (%s)" % (snap.errors[-1].at if not snap.errors.is_empty() else "none")),
		_check(snap.lines.size() == NoteLog.LINES and "filler %d" % (NoteLog.LINES + 19) in snap.lines[-1], "the last %d lines are kept, newest last" % NoteLog.LINES),
	])


## A note is on disk from the press; a draft is found again; a half-written record is still read.
static func _note_survives() -> PackedStringArray:
	_clear(TEST_ROOT)
	NoteStore.root = TEST_ROOT
	var screen := Image.create(64, 32, false, Image.FORMAT_RGB8)
	screen.fill(Color(0.2, 0.4, 0.6))
	var dir := NoteStore.begin(screen, {"a": 1}, {"save.json": "{\"x\": 2}"})
	var out := PackedStringArray()
	out.append(_check(dir != "" and FileAccess.file_exists(dir.path_join("screen.jpg")) and FileAccess.file_exists(dir.path_join("state.json"))
		and FileAccess.file_exists(dir.path_join("save.json")), "the capture is on disk at the press (screen, state, save)"))
	out.append(_check(NoteStore.read(dir).get("status") == "draft" and NoteStore.drafts().has(dir), "until saved it is a draft, found again on the next start"))
	NoteStore.update(dir, {"text": "Bram walks into the wall", "kind": "bug"})
	DirAccess.rename_absolute(dir.path_join("note.json"), dir.path_join("note.json.tmp"))   # a crash between write and rename
	out.append(_check(NoteStore.read(dir).get("text") == "Bram walks into the wall", "a record left as .tmp by a crash is still read"))
	DirAccess.rename_absolute(dir.path_join("note.json.tmp"), dir.path_join("note.json"))
	NoteStore.finish(dir, screen, screen.get_region(Rect2i(0, 0, 16, 16)))
	out.append(_check(NoteStore.read(dir).get("status") == "saved" and not NoteStore.drafts().has(dir) and FileAccess.file_exists(dir.path_join("crop.jpg")),
		"saved: no longer a draft, with the marked screen and the crop"))
	var second := NoteStore.begin(screen, {})
	out.append(_check(second != dir and second != "", "two notes in the same second get two folders"))
	NoteStore.root = "user://notes"
	_clear(TEST_ROOT)
	return out


static func _circle_names() -> PackedStringArray:
	var things := [{"id": 7, "name": "Bram", "screen": [100.0, 100.0]}, {"id": 9, "name": "Wren", "screen": [500.0, 500.0]}]
	var ring := PackedVector2Array()
	for i in 25:                                 # a rough loop round Bram, ending near where it began
		var a := TAU * i / 24.0
		ring.append(Vector2(100, 100) + Vector2(cos(a), sin(a)) * (60.0 + 8.0 * sin(3.0 * a)))
	var arrow := PackedVector2Array([Vector2(300, 300), Vector2(400, 420), Vector2(490, 505)])
	var tap := PackedVector2Array([Vector2(900, 900)])
	var crop := NoteMarks.crop_rect([ring], Vector2i(1280, 720))
	return PackedStringArray([
		_check(NoteMarks.circled([ring], things) == [7], "a circle round Bram names Bram"),
		_check(NoteMarks.circled([arrow], things) == [9], "an arrow ending at Wren names Wren"),
		_check(NoteMarks.circled([tap], things).is_empty(), "a tap far from anyone names no one"),
		_check(NoteMarks.circled([ring, arrow], things) == [7, 9], "a circle and an arrow name both, circled first"),
		_check(crop.has_point(Vector2i(100, 100)) and crop.size.x >= NoteMarks.MIN_CROP and crop.position.x >= 0, "the crop holds the circle, on the screen (%s)" % crop),
		_check(UnboundNotes.things({"people": [{"id": 1, "name": "A", "screen": [1.0, 2.0]}, {"id": 2, "name": "B", "screen": null},
			{"id": 3, "name": "C", "screen": [5.0, 5.0], "visible": false}]}).size() == 1, "only people on the screen, and not hidden indoors, can be circled"),
		_check(NoteMarks.circled([_loop(Vector2(700, 200), 50.0)], [{"id": 4, "name": "Tall", "screen": [700.0, 330.0], "points": [[700.0, 450.0], [700.0, 210.0]]}]) == [4],
			"a circle round only someone's head names them (their feet and head count, not just the middle)"),
		_check(NoteMarks.names_of(["npc:brakk", "other:wolf:7", 7], [{"id": 7, "name": "Bram"}, {"id": "npc:brakk", "name": "brakk"},
			{"id": "other:wolf:7", "name": "wolf"}]) == PackedStringArray(["brakk", "wolf", "Bram"]),
			"Enea's people and creatures are named when circled beside residents (his note 233349 lost them)"),
	])


static func _loop(centre: Vector2, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 25:
		out.append(centre + Vector2(cos(TAU * i / 24.0), sin(TAU * i / 24.0)) * r)
	return out


static func _marks_drawn() -> PackedStringArray:
	var screen := Image.create(400, 300, false, Image.FORMAT_RGB8)
	screen.fill(Color.BLACK)
	var out := NoteMarks.marked(screen, [PackedVector2Array([Vector2(50, 50), Vector2(350, 50)])])
	return PackedStringArray([
		_check(_near(out.get_pixel(200, 50), NoteMarks.INK) and _near(out.get_pixel(200, 200), Color.BLACK)
			and _near(screen.get_pixel(200, 50), Color.BLACK), "the stroke is drawn on a copy; the screen as seen is untouched"),
	])


static func _near(a: Color, b: Color) -> bool:   # 8-bit colour: within a step
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


static func _clear(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for sub in DirAccess.get_directories_at(dir):
		_clear(dir.path_join(sub))
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)
