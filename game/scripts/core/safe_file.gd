extends RefCounted
## Saving files so a crash, a flat battery or iOS killing the app mid-write can't leave a
## half-written file behind (today that reads as "no save" and starts a new game).
## The new file is written beside the old one (".tmp"); the old one becomes the backup (".bak");
## then the new one takes its place. Reading tries the file, then a finished ".tmp" (a crash
## between the two renames), then the ".bak".
## The web build writes as before: the browser stores each file whole, and a rename there would
## only reach the browser's storage at the next write.


## Writes `text` to `path`. Returns OK or the error.
static func write_text(path: String, text: String) -> Error:
	var target := path if OS.has_feature("web") else path + ".tmp"
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var written := file.store_string(text)
	file.close()
	if not written:
		return ERR_FILE_CANT_WRITE
	return OK if target == path else _swap_in(target, path)


## Saves a ConfigFile to `path` the same way.
static func save_config(cfg: ConfigFile, path: String) -> Error:
	if OS.has_feature("web"):
		return cfg.save(path)
	var err := cfg.save(path + ".tmp")
	return err if err != OK else _swap_in(path + ".tmp", path)


## Loads a ConfigFile from `path`, or from what a crash left behind. OK if any copy loaded.
static func load_config(cfg: ConfigFile, path: String) -> Error:
	var err := ERR_FILE_NOT_FOUND
	for p in candidates(path):
		err = cfg.load(p)
		if err == OK:
			return OK
	return err


## The copies to try when reading `path`, best first: the file, a finished ".tmp", the ".bak".
static func candidates(path: String) -> PackedStringArray:
	var out := PackedStringArray()
	for p: String in [path, path + ".tmp", path + ".bak"]:
		if FileAccess.file_exists(p):
			out.append(p)
	return out


## Deletes the file and its ".tmp" and ".bak" (so "start over" can't come back from the backup).
static func remove(path: String) -> void:
	for p: String in [path, path + ".tmp", path + ".bak"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


## The old file becomes the backup, then the finished new file takes its place.
static func _swap_in(tmp: String, path: String) -> Error:
	if FileAccess.file_exists(path):
		var bak := path + ".bak"
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		var err := DirAccess.rename_absolute(path, bak)
		if err != OK:
			return err
	return DirAccess.rename_absolute(tmp, path)
