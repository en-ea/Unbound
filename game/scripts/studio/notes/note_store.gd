extends RefCounted
## Where notes are kept, one folder each: user://notes/<yyyymmdd-hhmmss>/. Game-agnostic. Every file is written
## beside its final name and then renamed into place, so a crash leaves the old file or the new one, never half of
## one. The capture is written at the press, before anything is asked of the player; the note's own record
## (note.json) says "draft" until it is saved, so a note cut short by a crash is found again on the next start.
##
##   var dir := NoteStore.begin(screen, state)          # at the press
##   NoteStore.update(dir, {"text": "...", "kind": "bug"})  # as the player goes
##   NoteStore.finish(dir, marked, crop)                # saved
##
## A folder holds: note.json (status, times, kind, text, the circle, who was circled), state.json (what the game
## knew), screen.jpg (as seen), marked.jpg (with the circle), crop.jpg (the circled part), and any extra files.

static var root := "user://notes"   # (tests use their own)
const QUALITY := 0.85


## Starts a note: the folder, the screen as seen, the state, and extra files ({name: text}). -> the folder, or "".
static func begin(screen: Image, state: Dictionary, extra: Dictionary = {}) -> String:
	var t := Time.get_datetime_dict_from_system()
	var name := "%04d%02d%02d-%02d%02d%02d" % [t.year, t.month, t.day, t.hour, t.minute, t.second]
	var dir := root.path_join(name)
	var n := 1
	while DirAccess.dir_exists_absolute(dir):        # two notes in one second
		n += 1
		dir = root.path_join("%s-%d" % [name, n])
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		return ""
	if screen != null and not screen.is_empty():
		_write_jpg(dir.path_join("screen.jpg"), screen)
	_write_text(dir.path_join("state.json"), JSON.stringify(state, "\t", false))
	for file: String in extra:
		_write_text(dir.path_join(file), str(extra[file]))
	_write_text(dir.path_join("note.json"), JSON.stringify({"status": "draft", "created": Time.get_datetime_string_from_system(),
		"has_screen": screen != null and not screen.is_empty()}, "\t"))
	return dir


## Merges fields into the note's record (the circle, the circled, the kind, the text).
static func update(dir: String, fields: Dictionary) -> void:
	var note := read(dir)
	note.merge(fields, true)
	_write_text(dir.path_join("note.json"), JSON.stringify(note, "\t"))


## Saves the note: the marked screen and the crop (either may be null), and the status "saved".
static func finish(dir: String, marked: Image, crop: Image) -> void:
	if marked != null and not marked.is_empty():
		_write_jpg(dir.path_join("marked.jpg"), marked)
	if crop != null and not crop.is_empty():
		_write_jpg(dir.path_join("crop.jpg"), crop)
	update(dir, {"status": "saved", "saved": Time.get_datetime_string_from_system()})


## Leaves the note as discarded (kept: what was captured may still matter; only the player's choice is recorded).
static func discard(dir: String) -> void:
	update(dir, {"status": "discarded"})


## The note's record, or {} if there is none.
static func read(dir: String) -> Dictionary:
	var path := dir.path_join("note.json")
	var text := FileAccess.get_file_as_string(path if FileAccess.file_exists(path) else path + ".tmp")
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	return parsed if parsed is Dictionary else {}


## Every note folder, oldest first.
static func all() -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(root):
		return out
	for name in DirAccess.get_directories_at(root):
		out.append(root.path_join(name))
	out.sort()
	return out


## Notes still marked "draft": cut short by a crash or by closing the game.
static func drafts() -> PackedStringArray:
	var out := PackedStringArray()
	for dir in all():
		if read(dir).get("status", "") == "draft":
			out.append(dir)
	return out


static func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(text)
	file.close()
	_into_place(path)


static func _write_jpg(path: String, image: Image) -> void:
	if image.save_jpg(path + ".tmp", QUALITY) == OK:
		_into_place(path)


static func _into_place(path: String) -> void:
	if DirAccess.rename_absolute(path + ".tmp", path) != OK:   # a rename over a file is atomic on Android and Linux;
		DirAccess.remove_absolute(path)                          # where it is refused, the old one goes first
		DirAccess.rename_absolute(path + ".tmp", path)
