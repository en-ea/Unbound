extends RefCounted
## The reactions and the cue sources there are: every script in a folder, found once at start (plan LIVELY-VILLAGE
## 3.1, 3.4). ResourceLoader.list_directory sees an exported pack's files too, so the normal build finds the same
## modules. Sorted by name, so every run offers them in one order. Generic: a folder of scripts and what they declare.
##
##   var reg := ReactionRegistry.new(REACTIONS)       (or CUES)
##   reg.modules                     [script, ...] by file name
##   reg.answering(kind) -> Array    the modules whose ANSWERS has a prefix of `kind`
##   reg.names                       script -> its file name without .gd ("go_to_them")
##
## Files named _proof_*.gd are skipped unless `proofs` is true: a test writes one, scans, and removes it (the commit
## check fails while one exists, so a crashed test never leaves one in a build).
const REACTIONS := "res://scripts/studio/village/reactions/"
const CUES := "res://scripts/studio/village/cues/"

var modules: Array = []
var names := {}
var _by_kind := {}           # cue kind -> [script] (asked once per kind)


func _init(folder: String, proofs := false) -> void:
	var files: Array = []
	for f: String in ResourceLoader.list_directory(folder):
		var file := f.trim_suffix(".remap")
		if not file.ends_with(".gd") or (file.begins_with("_proof_") and not proofs):
			continue
		files.append(file)
	files.sort()
	for file: String in files:
		var script := load(folder + file) as Script
		if script == null or not script.can_instantiate():
			push_warning("studio reactions: %s did not load" % file)
			continue
		modules.append(script)
		names[script] = file.get_basename()


func answering(kind: String) -> Array:
	if _by_kind.has(kind):
		return _by_kind[kind]
	var out: Array = []
	for m: Script in modules:
		for prefix: String in constant(m, "ANSWERS", []):
			if kind.begins_with(prefix):
				out.append(m)
				break
	_by_kind[kind] = out
	return out


## Whether module `m` answers cue `kind` (one of its ANSWERS is a prefix of it).
static func answering_static(m: Script, kind: String) -> bool:
	for prefix: String in constant(m, "ANSWERS", []):
		if kind.begins_with(prefix):
			return true
	return false


## A module's constant, or its base's (reaction.gd's defaults), or `fallback`.
static func constant(m: Script, n: String, fallback: Variant) -> Variant:
	var s := m
	while s != null:
		var c := s.get_script_constant_map()
		if c.has(n):
			return c[n]
		s = s.get_base_script()
	return fallback


func name_of(m: Script) -> String:
	return str(names.get(m, ""))


func by_name(n: String) -> Script:
	for m: Script in modules:
		if names[m] == n:
			return m
	return null
