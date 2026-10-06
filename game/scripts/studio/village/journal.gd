extends RefCounted
## Step 4 (5 Oct, plan/STEP4-SAVE-STALL-2026-10-05.md section 3): the save on disk is a full checkpoint plus a
## journal of small lines.
## - A full save (save.json, written from live state only when a chain starts: load, new game, a broken journal)
##   names its chain ("save_id") and the last line it already holds ("journal_seq").
## - append() writes one line {"chain", "seq", "save"} and flushes it before the caller publishes anything. "save" holds
##   the game's other state whole and the village as a delta (village/sim/image.gd, applied by save.gd apply_line).
##   A line is a binary record: a 32-bit length, then var_to_bytes of the line (never objects). A torn last record
##   is shorter than its length and ends the replay; stringifying JSON on the action path measured 59 us per KB.
## - checkpoint() builds the next full save on a worker thread from data only: the last checkpoint's text and the
##   lines since, never live objects. poll() then drops the lines it holds from the journal.
## - replay() lays the lines over a full save when loading. A line of another chain or one already held is skipped;
##   the first missing, torn or unfitting line ends the replay (later lines depend on it).
const Codec := preload("res://scripts/studio/village/sim/save.gd")
const SafeFile := preload("res://scripts/core/safe_file.gd")

var path := ""
var chain := "" # the chain on disk; "" until this session wrote a full save
var seq := 0 # the last line written
var bytes := 0 # journal size since the last rotation
var checkpoints := 0
var _lines: Array = [] # [seq, record bytes] written since the checkpoint on disk
var _file: FileAccess = null
var _task := -1
# Worker side: touched by the checkpoint task, or by the main thread only when no task runs.
var _base_text := ""
var _base = null
var _applied := 0
var _done := {}


func _init(save_path: String) -> void:
	path = save_path


func journal_path() -> String:
	return path + ".journal"


## A full save of chain `id` (holding no line) was just written as `text`: the journal starts over.
func rebase(id: String, text: String) -> void:
	wait()
	_close()
	chain = id
	seq = 0
	bytes = 0
	_lines = []
	_base_text = text
	_base = null
	_applied = 0
	if FileAccess.file_exists(journal_path()):
		DirAccess.remove_absolute(journal_path())


## No chain: the next save must be a full one.
func reset() -> void:
	wait()
	_close()
	chain = ""
	seq = 0
	bytes = 0
	_lines = []
	_base_text = ""
	_base = null
	_applied = 0


## One line, written and flushed. A failed write breaks the chain: the next save is a full one.
func append(save: Dictionary) -> Error:
	if chain.is_empty():
		return ERR_UNCONFIGURED
	if _file == null:
		_file = FileAccess.open(journal_path(), FileAccess.READ_WRITE if FileAccess.file_exists(journal_path()) else FileAccess.WRITE)
		if _file == null:
			chain = ""
			return FileAccess.get_open_error()
		_file.seek_end()
	var record := var_to_bytes({"chain": chain, "seq": seq + 1, "save": save})
	var written := _file.store_32(record.size()) and _file.store_buffer(record)
	_file.flush()
	if not written or _file.get_error() != OK:
		_close()
		chain = ""
		return ERR_FILE_CANT_WRITE
	seq += 1
	bytes += record.size() + 4
	_lines.append([seq, record])
	return OK


func _close() -> void:
	if _file != null:
		_file.close()
		_file = null


func busy() -> bool:
	return _task >= 0


## Starts building the next checkpoint on a worker thread (nothing when one is already building or nothing is new).
func checkpoint() -> void:
	if _task >= 0 or chain.is_empty() or _lines.is_empty():
		return
	_task = WorkerThreadPool.add_task(_build.bind(_lines.duplicate(), chain), false, "studio save checkpoint")


## Worker: last checkpoint + lines -> the next full save, written atomically. Data only.
func _build(lines: Array, id: String) -> void:
	if _base == null:
		_base = JSON.parse_string(_base_text if not _base_text.is_empty() else FileAccess.get_file_as_string(path))
		_base_text = ""
		_applied = int(_base.get("journal_seq", 0)) if _base is Dictionary else 0
	if not _base is Dictionary:
		_base = null
		_done = {"error": ERR_PARSE_ERROR, "seq": 0}
		return
	var last := _applied
	for row: Array in lines:
		if int(row[0]) <= _applied:
			continue
		var entry: Variant = bytes_to_var(row[1])
		if not entry is Dictionary or not apply(_base, entry.get("save")):
			_base = null # half-applied: the next attempt starts from disk again
			_done = {"error": ERR_INVALID_DATA, "seq": last}
			return
		last = int(row[0])
		_applied = last
	if _base.get("village") is Dictionary and not _base.village.is_empty():
		Codec.pack_village(_base.village)
	_base["save_id"] = id
	_base["journal_seq"] = last
	_done = {"error": SafeFile.write_text(path, JSON.stringify(_base)), "seq": last}


## One line's save laid over a full save (data only). False when the village delta does not fit.
static func apply(base: Dictionary, save: Variant) -> bool:
	if not save is Dictionary:
		return false
	for key: String in save:
		if key == "region_world":
			if not base.get("regions") is Dictionary:
				base["regions"] = {}
			base.regions.merge(save.region_world, true)
		elif key == "village":
			var line: Variant = save.village
			if line is Dictionary and not line.is_empty():
				if not base.get("village") is Dictionary or base.village.is_empty() or not Codec.apply_line(base.village, line):
					return false
		else:
			base[key] = save[key]
	return true


## Main thread, every frame: a finished checkpoint drops the lines it holds from the journal.
func poll() -> void:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		_finish()


func _finish() -> void:
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	if int(_done.get("error", FAILED)) != OK:
		push_warning("save checkpoint failed (%d); the journal keeps every line" % int(_done.get("error", FAILED)))
		return
	checkpoints += 1
	var held := int(_done.seq)
	var keep: Array = _lines.filter(func(row: Array) -> bool: return int(row[0]) > held)
	_close()
	if keep.size() == _lines.size():
		return
	_lines = keep
	bytes = 0
	if keep.is_empty():
		DirAccess.remove_absolute(journal_path())
		return
	var tmp := journal_path() + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return
	for row: Array in keep:
		file.store_32(row[1].size())
		file.store_buffer(row[1])
		bytes += row[1].size() + 4
	file.close()
	DirAccess.rename_absolute(tmp, journal_path())


func wait() -> void:
	if _task >= 0:
		_finish()


## Every whole record in a journal file, in order; a torn or unreadable record ends the list.
static func records(file: FileAccess) -> Array:
	var out := []
	var size := file.get_length()
	while file.get_position() + 4 <= size:
		var length := file.get_32()
		if length <= 0 or file.get_position() + length > size:
			break
		var entry: Variant = bytes_to_var(file.get_buffer(length))
		if not entry is Dictionary or not entry.get("save") is Dictionary:
			break
		out.append(entry)
	return out


## Loading: the full save with this chain's newer journal lines laid over it, line by line (the save is returned
## unchanged when there are none). A line that does not fit ends the replay at the line before it.
static func replay(data: Dictionary, journal: String) -> Dictionary:
	if not data.has("save_id") or not FileAccess.file_exists(journal):
		return data
	var file := FileAccess.open(journal, FileAccess.READ)
	if file == null:
		return data
	var entries := []
	var next := int(data.get("journal_seq", 0)) + 1
	for entry: Variant in records(file):
		if str(entry.get("chain", "")) != str(data.save_id):
			if entries.is_empty():
				continue
			break
		var at := int(entry.get("seq", 0))
		if at < next:
			continue
		if at > next:
			break
		entries.append(entry.save)
		next += 1
	if entries.is_empty():
		return data
	var out: Dictionary = data.duplicate(true)
	for i in entries.size():
		if not apply(out, entries[i]):
			out = data.duplicate(true)
			for j in i:
				apply(out, entries[j])
			push_warning("save journal line %d did not fit; replayed the %d before it" % [i + 1, i])
			break
	return out
