extends RefCounted
## Extension discovery shared by B/P/S/C: one .gd in the owning folder, unique nonempty ID.
## ResourceLoader.list_directory works in editor and exported packs. Sorted IDs, cached scripts;
## duplicate identities fail visibly. No registration edit, hardcoded preload catalogue or production proof toggle.
static var _cache := {}
static func discover(folder: String) -> Dictionary:
	if _cache.has(folder):
		return _cache[folder]
	var out := {}
	var names := ResourceLoader.list_directory(folder)
	names.sort()
	for name: String in names:
		if not name.ends_with(".gd"):
			continue
		var script: GDScript = load(folder.path_join(name))
		var key := str(script.get_script_constant_map().get("ID", ""))
		if key.is_empty() or out.has(key):
			push_error("people extension identity: " + folder.path_join(name))
			continue
		out[key] = script
	var sorted := {}
	var keys := out.keys()
	keys.sort()
	for key: String in keys:sorted[key]=out[key]
	_cache[folder] = sorted
	return sorted
