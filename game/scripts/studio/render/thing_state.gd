class_name ThingState
extends Node
## Graphics S4 (studio plan GRAPHICS-STAGES-2026-10-04.md): things with state. A fence, a bench, a camp's crates and rack
## can burn, char, soak, break and be struck, shown by the same element modules people use, run by Body's own runtime
## (people/body_elements.gd, given the folder things/elements/; things/thing_body.gd plays its layers). No second
## runtime: what happens to a thing is Body's facts; this draws them.
##
##   found: a scan at the region build and every node added later (a yard rebuilt, a camp built), deferred to the end
##     of the frame so the builder has placed it: an instance of a carrier model (CARRIERS). Its id is
##     "<kind>@<x dm>,<z dm>", the same on every load of the same save.
##   drawn: every surface on Enea's solid shader gets a studio copy of it, render/thing_solid.gdshader, which is his
##     exactly while the thing is neutral. Each thing has a column of one shared state texture, picked by an instance
##     uniform: a change of state is a texel written and the texture uploaded once that frame. No material changes,
##     so no draw call; things leave StaticBatch (they are drawn as themselves, as before S1).
##   facts: Body's, read as the people read theirs (VillageSession's village): Village.thing_facts {id: {kind: row}}
##     on the people's clock (People.tick). A line without that field shows nothing: every thing stays neutral. A check
##     may set facts_source and tick_source to its own fixture.
## Switch: project setting studio/render/thing_state, ON when absent (Hilmi approved the look for his build, 5 Oct, with
## scorch softened to charred wood and the hit flash to a brief brighten; Enea sees it at S6), or the dev argument
## --studio-things=on|off. Off: nothing is added; today's scene exactly.

const SETTING := "studio/render/thing_state"
const SOLID := preload("res://shaders/foliage_solid.gdshader")
const THING_SOLID := preload("res://scripts/studio/render/thing_solid.gdshader")
const ThingBody := preload("res://scripts/studio/things/thing_body.gd")
const People := preload("res://scripts/studio/village/sim/people.gd")
## Carrier models and the kind of thing each is.
const CARRIERS := {
	"res://assets/props/fence.glb": "fence",
	"res://assets/props/bench.glb": "bench",
	"res://assets/camp/camp_crates.glb": "crates",
	"res://assets/camp/camp_rack.glb": "rack",
}
const COLUMNS := 512                # things at once (column 0 is the neutral one)
## Channels and where each lives: [row, component].
const CHANNELS := {"soot": [0, 0], "char": [0, 1], "wet": [0, 2], "wear": [0, 3],
	"flash": [1, 0], "shake": [1, 1], "broken": [1, 2], "ember": [1, 3]}

var facts_source := Callable()       # () -> {thing id: {kind: fact}}; the village's own unless a check sets one
var tick_source := Callable()        # () -> int milliseconds on the facts' clock; the people's clock unless set
var frozen := false                  # the checks stop time here; facts still apply

var _things := {}                    # id -> {root, kind, column, body (ThingBody), meshes: [[mi, surface, his, copy]]}
var _image: Image
var _texture: ImageTexture
var _free: Array[int] = []
var _dirty := false
var _pending: Array[Node] = []
var _copies := {}                    # source material id -> its thing_solid copy (each copy reads its own uniforms)
var _changes := 0
var _change_usec := 0
var _session: Node                   # the people's port to the village (VillageSession)


static func enabled() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--studio-things="):
			return arg.trim_prefix("--studio-things=") == "on"
	return bool(ProjectSettings.get_setting(SETTING, true))


## The one entry, from StaticBatch.attach (main.gd's graphics line): after the region is built.
static func attach(main: Node) -> void:
	if not enabled() or main.has_node("StudioThings"):
		return
	var n := ThingState.new()
	n.name = "StudioThings"
	main.add_child(n)


func _ready() -> void:
	process_priority = 900           # after the people (their fire reaches things the same frame), before the batcher
	_image = Image.create(COLUMNS, 3, false, Image.FORMAT_RGBA8)
	_image.fill(Color(0, 0, 0, 0))
	_texture = ImageTexture.create_from_image(_image)
	for c in range(COLUMNS - 1, 0, -1):
		_free.append(c)
	_session = get_tree().root.get_node_or_null("VillageSession")
	if facts_source.is_null():
		facts_source = _village_facts
	if tick_source.is_null():
		tick_source = _village_tick
	_scan(get_parent())
	get_tree().node_added.connect(_on_added)


## Body's facts for things, as the people read theirs: Village.thing_facts {id: {kind: row}}, written by
## sim/thing_facts.gd. A line without them (no field) has nothing to show.
func _village_facts() -> Dictionary:
	var v = _session.get("village") if _session != null else null
	var f = v.get("thing_facts") if v != null else null
	return f if f is Dictionary else {}


## The people's clock (People.tick: active milliseconds), which the facts' ticks are on.
func _village_tick() -> int:
	var v = _session.get("village") if _session != null else null
	return People.tick(v) if v != null else Time.get_ticks_msec()


func _on_added(n: Node) -> void:
	if CARRIERS.has(n.scene_file_path):
		if _pending.is_empty():
			_register_pending.call_deferred()
		_pending.append(n)


func _register_pending() -> void:
	for n in _pending:
		if is_instance_valid(n) and n.is_inside_tree():
			_register(n as Node3D)
	_pending.clear()


func _scan(from: Node) -> void:
	if CARRIERS.has(from.scene_file_path):
		_register(from as Node3D)
		return
	for c in from.get_children():
		_scan(c)


## The id a thing is known by: its kind and where it stands, in decimetres.
static func id_of(kind: String, at: Vector3) -> String:
	return "%s@%d,%d" % [kind, roundi(at.x * 10.0), roundi(at.z * 10.0)]


func _register(root: Node3D) -> void:
	if root == null or root.has_meta("studio_thing") or _free.is_empty():
		return
	var kind: String = CARRIERS[root.scene_file_path]
	var id := id_of(kind, root.global_position)
	if _things.has(id):
		id += "#%d" % root.get_instance_id()          # (two of a kind on one spot: both still work)
	var column: int = _free.pop_back()
	var meshes: Array = []
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or mi.material_override != null:
			continue
		var used := false
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s)
			if not (m is ShaderMaterial and (m as ShaderMaterial).shader == SOLID):
				continue
			var copy: ShaderMaterial = _copies.get(m.get_instance_id())
			if copy == null:
				copy = m.duplicate() as ShaderMaterial
				copy.shader = THING_SOLID
				copy.set_shader_parameter("thing_state", _texture)
				_copies[m.get_instance_id()] = copy
			meshes.append([mi, s, mi.get_surface_override_material(s), copy])
			mi.set_surface_override_material(s, copy)
			used = true
		if used:
			mi.set_instance_shader_parameter("thing_id", float(column))
	root.set_meta("studio_thing", id)
	root.add_to_group("studio_no_batch")
	var batch := get_parent().get_node_or_null("StudioBatch")
	if batch != null:
		for e: Array in meshes:
			batch.call("release", e[0])
	var body := ThingBody.new(self, id, kind, root)
	_things[id] = {"root": root, "kind": kind, "column": column, "body": body, "meshes": meshes}
	root.tree_exiting.connect(_unregister.bind(id), CONNECT_ONE_SHOT)


func _unregister(id: String) -> void:
	var t: Dictionary = _things.get(id, {})
	if t.is_empty():
		return
	(t.body as ThingBody).stop()
	_write(int(t.column), {})
	_free.append(int(t.column))
	_things.erase(id)


func _process(dt: float) -> void:
	var facts: Dictionary = facts_source.call() if facts_source.is_valid() else {}
	var tick: int = tick_source.call()
	for id: String in _things:
		(_things[id].body as ThingBody).drive(facts.get(id, {}), tick, 0.0 if frozen else dt)
	if _dirty:
		_texture.update(_image)
		_dirty = false


## A thing's channels (0..1 each; any not given is 0) and tint (a Color, white when not given). Written into its
## column now and uploaded once at the end of the frame. For thing_body.gd and the checks.
func set_channels(id: String, channels: Dictionary) -> void:
	var t: Dictionary = _things.get(id, {})
	if not t.is_empty():
		_write(int(t.column), channels)


func _write(column: int, channels: Dictionary) -> void:
	var t0 := Time.get_ticks_usec()
	var rows := [Color(0, 0, 0, 0), Color(0, 0, 0, 0)]
	for ch: String in CHANNELS:
		if channels.has(ch):
			var at: Array = CHANNELS[ch]
			rows[at[0]][at[1]] = clampf(float(channels[ch]), 0.0, 1.0)
	var tint: Color = channels.get("tint", Color.WHITE)
	var changed := false
	for r in 2:
		if _image.get_pixel(column, r) != rows[r]:
			_image.set_pixel(column, r, rows[r])
			changed = true
	var t2 := Color(1.0 - tint.r, 1.0 - tint.g, 1.0 - tint.b, 0.0)
	if _image.get_pixel(column, 2) != t2:
		_image.set_pixel(column, 2, t2)
		changed = true
	if changed:
		_dirty = true
		_changes += 1
		_change_usec += Time.get_ticks_usec() - t0


## For the checks: the state texture uploaded now (as the frame's end does), and its cost.
func flush() -> int:
	var t0 := Time.get_ticks_usec()
	if _dirty:
		_texture.update(_image)
		_dirty = false
	return Time.get_ticks_usec() - t0


## For the checks: every thing back to Enea's own materials (on false) or to the thing copies (on true), in place.
func show_originals(on: bool) -> void:
	for id: String in _things:
		for e: Array in _things[id].meshes:
			var mi: MeshInstance3D = e[0]
			if is_instance_valid(mi):
				mi.set_surface_override_material(int(e[1]), e[2] if on else e[3])


func things() -> Dictionary:
	return _things


func report() -> Dictionary:
	var kinds := {}
	for id: String in _things:
		kinds[_things[id].kind] = int(kinds.get(_things[id].kind, 0)) + 1
	return {"things": _things.size(), "kinds": kinds, "changes": _changes, "change_usec": _change_usec,
		"copies": _copies.size()}
