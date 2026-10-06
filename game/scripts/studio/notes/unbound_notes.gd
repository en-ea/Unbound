extends RefCounted
## Unbound's side of the note tool: what the game knew at the press, and what to sample twice a second. The rest
## of notes/ is game-agnostic (note_log, note_recorder, note_store, note_marks). Started once by the studio's
## session (session.gd): install(tree). A press calls capture().
##
## What a note keeps, and why (plan/NOTE-TOOL-2026-10-01.md section 2): the build and settings; the frame times and
## the process's memory; the world, the player and the camera; for everyone within NEAR, who they are, what they do
## and why, where they look, what they say, how they feel about the player, and their place on the screen (so a
## circle can name them); the last 20 s of the same; the last meetings; every error; and the save as it stands.

const NoteLog := preload("res://scripts/studio/notes/note_log.gd")
const NoteRecorder := preload("res://scripts/studio/notes/note_recorder.gd")
const NoteStore := preload("res://scripts/studio/notes/note_store.gd")
const BuildId := preload("res://scripts/studio/notes/build_id.gd")
const View := preload("res://scripts/studio/village/sim/view.gd")
const React := preload("res://scripts/studio/village/resident_react.gd")

const NEAR := 30.0             # m from the player: the people a note describes and samples
const MEETINGS_KEPT := 30

static var log: NoteLog
static var recorder: NoteRecorder


## Starts the log and the recorder (once; they live for the whole game).
static func install(tree: SceneTree) -> void:
	if recorder != null:
		return
	log = NoteLog.new()
	OS.add_logger(log)
	recorder = NoteRecorder.new()
	recorder.name = "NoteRecorder"
	recorder.sampler = func() -> Variant: return sample()
	tree.root.add_child.call_deferred(recorder)


## The press: the screen as seen, then everything else, written at once.
## -> {"dir": the note's folder ("" if it failed), "screen": Image or null, "things": what a circle can name}
static func capture(viewport: Viewport) -> Dictionary:
	var screen: Image = null
	var texture := viewport.get_texture()
	if texture != null and DisplayServer.get_name() != "headless":
		screen = texture.get_image()                      # first, before any note UI is drawn (none without a renderer)
	var state := state_now(viewport)
	state["recent"] = recorder.snapshot() if recorder != null else {}
	state["log"] = log.snapshot() if log != null else {}
	var extra := {}
	var save := _save_now()
	if save != "":
		extra["save.json"] = save
	return {"dir": NoteStore.begin(screen, state, extra), "screen": screen, "things": things(state)}


## What the game knows now.
static func state_now(viewport: Viewport) -> Dictionary:
	var tree := viewport.get_tree()
	var player := tree.get_first_node_in_group("player") as Node3D
	var camera := viewport.get_camera_3d()
	var out := {"build": _build(viewport), "world": _world(tree, player, camera), "people": [], "others": [],
		"meetings": [], "scene": {}}
	var registry := _registry(tree)
	if registry == null or player == null:
		return out
	var v = VillageSession.village
	var at := player.global_position
	for id: int in registry.bodies:
		var body: Node3D = registry.bodies[id]
		if body.global_position.distance_to(at) <= NEAR:
			out.people.append(_person(registry, v, id, body, camera, viewport))
	out.people.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.metres < b.metres)
	var seen := {}
	for npc: Node3D in registry.get("_npcs"):         # Enea's characters (world/npc.gd)
		if is_instance_valid(npc) and npc.global_position.distance_to(at) <= NEAR:
			seen[npc] = true
			out.others.append(_other(npc, "npc:" + str(npc.get("_id")), str(npc.get("_id")), at, camera, viewport))
	for pair: Array in registry.get("_world_others"):  # and the rest of his people and animals (a trader, a boar)
		var node := pair[0] as Node3D
		if is_instance_valid(node) and not seen.has(node) and node.global_position.distance_to(at) <= NEAR:
			seen[node] = true
			var kind: String = (node.get_script() as Script).resource_path.get_file().get_basename() if node.get_script() != null else node.get_class()
			out.others.append(_other(node, "other:%s:%d" % [kind, node.get_instance_id()], "%s (%s)" % [node.name, kind], at, camera, viewport))
	var society = registry.get("society")
	if society != null:
		var meetings: Array = society.log
		out.meetings = meetings.slice(maxi(0, meetings.size() - MEETINGS_KEPT))
	var live := tree.current_scene.get_node_or_null("VillageLive") if tree.current_scene != null else null
	if live != null:
		var stage = live.get("_stage")
		out.scene = {"event": live.get("_event"), "stage": stage.stats() if stage != null else {}}
	return out


## What everyone near the player is doing, compactly, for the recorder: [id, x, z, speed, what drives them].
static func sample() -> Variant:
	var tree := Engine.get_main_loop() as SceneTree
	var registry := _registry(tree)
	var player := tree.get_first_node_in_group("player") as Node3D if tree != null else null
	if registry == null or player == null:
		return []
	var out := []
	var movers: Dictionary = registry.get("_movers")
	for id: int in registry.bodies:
		var body: Node3D = registry.bodies[id]
		if body.global_position.distance_to(player.global_position) > NEAR or not movers.has(id):
			continue
		var m = movers[id]
		out.append([id, snappedf(m.pos.x, 0.01), snappedf(m.pos.y, 0.01), snappedf(m.vel.length(), 0.01), _driver(registry, id), m.why])
	return out


## Everything the circle can name: people and Enea's characters, with their screen positions.
static func things(state: Dictionary) -> Array:
	var out := []
	for p: Dictionary in state.get("people", []) + state.get("others", []):
		if p.get("screen") != null and p.get("visible", true):     # (not someone indoors, hidden from the camera)
			out.append({"id": p.id, "name": p.name, "screen": p.screen, "points": p.get("points", [])})
	return out


static func _other(node: Node3D, id: String, name: String, at: Vector3, camera: Camera3D, viewport: Viewport) -> Dictionary:
	var bubble = node.get("_bubble")
	return {"id": id, "name": name, "says": bubble.text if bubble is Label3D and bubble.visible else "",
		"metres": snappedf(node.global_position.distance_to(at), 0.1), "visible": node.is_visible_in_tree(),
		"screen": _screen(camera, viewport, node.global_position + Vector3.UP), "points": _points(camera, viewport, node.global_position)}


## Feet and head on the screen too, so a circle round either one still counts.
static func _points(camera: Camera3D, viewport: Viewport, feet: Vector3) -> Array:
	return [feet + Vector3.UP * 0.2, feet + Vector3.UP * 1.8].map(func(p: Vector3) -> Variant: return _screen(camera, viewport, p)).filter(func(q: Variant) -> bool: return q != null)


static func _person(registry: Node, v, id: int, body: Node3D, camera: Camera3D, viewport: Viewport) -> Dictionary:
	var d := View.describe(v, id)
	var player := registry.get("_player") as Node3D
	var out := {"id": id, "name": d.name, "role": d.role, "age": d.age_group, "mood": d.mood, "activity": d.activity,
		"toward_player": d.toward_player, "metres": snappedf(body.global_position.distance_to(player.global_position), 0.1) if player != null else -1.0,
		"screen": _screen(camera, viewport, body.global_position + Vector3.UP * 1.0), "points": _points(camera, viewport, body.global_position),
		"visible": body.is_visible_in_tree(),
		"driver": _driver(registry, id), "says": React.bubble_text(body) if React.has_bubble(body) else ""}
	var m = registry.get("_movers").get(id)
	if m != null:
		out["mover"] = {"at": [snappedf(m.pos.x, 0.01), snappedf(m.pos.y, 0.01)], "speed": snappedf(m.vel.length(), 0.01),
			"wished": snappedf(m.wished, 0.01), "why": m.why, "style": m.style, "active": m.active, "arrived": m.arrived,
			"path_left": m.path.size(), "seconds_left": m.seconds if is_finite(m.seconds) else -1.0, "waiting": snappedf(m.wait, 0.01),
			"held_at": [m.hold_at.x, m.hold_at.y] if is_finite(m.hold_at.x) else null, "indoors": m.indoors, "asides": m.asides,
			"shoved": snappedf(m.shoved, 0.01) if is_finite(m.shoved) else -1.0, "shoved_by": m.shoved_by}
	var stay = registry.get("_stays").get(id)
	if stay != null:
		out["stay"] = {"kind": stay.kind, "restless": stay.restless, "sociable": stay.sociable}
	var gaze = registry.get("_gazes").get(id)
	if gaze != null:
		out["looks_at"] = {"kind": gaze.kind, "at": [snappedf(gaze.target.x, 0.1), snappedf(gaze.target.z, 0.1)] if is_finite(gaze.target.x) else null}
	var society = registry.get("society")
	if society != null and society.in_sit.has(id):
		var sit = society.in_sit[id]
		out["meeting"] = {"name": sit.name, "with": sit.who, "phase": sit.phase, "seconds": snappedf(sit.t, 0.1), "shape": sit.shape()}
	var act = registry.get("_acts").get(id)
	if act != null:
		out["acting"] = str(act.get("state")) if act.get("state") != null else str(act)
	return out


## Who moves this body now: the scene, a meeting, a reaction, the talk, a happening, or their day (the registry's one
## owner per body, people/owners.gd; the fields below for a registry from before it).
static func _driver(registry: Node, id: int) -> String:
	var owners = registry.get("owners")
	if owners != null:
		return {"stage": "scene", "talk": "talk", "act": "reaction", "society": "meeting", "happening": "happening"}.get(owners.owner(id), "day")
	if registry.borrowed.has(id):
		return "scene"
	if registry.get("_talking") == id:
		return "talk"
	if registry.get("_acts").has(id):
		return "reaction"
	var society = registry.get("society")
	if society != null and society.in_sit.has(id):
		return "meeting"
	return "day"


static func _build(viewport: Viewport) -> Dictionary:
	return {"id": BuildId.ID, "godot": Engine.get_version_info().string, "device": OS.get_model_name(), "os": OS.get_name(),
		"renderer": RenderingServer.get_current_rendering_method(), "gpu": RenderingServer.get_video_adapter_name(),
		"msaa_3d": viewport.msaa_3d, "fps_cap": Engine.max_fps, "debug": OS.is_debug_build(),
		"window": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
		"orientation": DisplayServer.screen_get_orientation(), "settings": _settings()}


static func _settings() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") != OK:
		return {}
	var out := {}
	for section in cfg.get_sections():
		for key in cfg.get_section_keys(section):
			out[section + "/" + key] = cfg.get_value(section, key)
	return out


static func _world(tree: SceneTree, player: Node3D, camera: Camera3D) -> Dictionary:
	var out := {"region": Region.current, "coins": Money.coins, "controls_locked": Controls.locked}
	var v = VillageSession.village
	if v != null:
		out["village_minute"] = snappedf(float(v.runtime.now) + float(v.runtime.fraction), 0.01)
		out["day"] = int(v.runtime.now) / 1440
		out["clock"] = "%02d:%02d" % [int(v.runtime.now) % 1440 / 60, int(v.runtime.now) % 60]
	if player != null:
		out["player"] = {"at": _v3(player.global_position), "facing": snappedf(player.get("visual").rotation.y, 0.01) if player.get("visual") != null else 0.0,
			"health": player.get("health"), "station": _station(player)}
	if camera != null:
		out["camera"] = {"at": _v3(camera.global_position), "looking": _v3(-camera.global_basis.z), "fov": camera.fov}
	return out


static func _station(player: Node3D) -> Variant:
	var station: Variant = player.get("_station")
	if not is_instance_valid(station):
		return null
	return {"verb": station.get("verb"), "resident": station.get("resident")}


static func _screen(camera: Camera3D, viewport: Viewport, at: Vector3) -> Variant:
	if camera == null or camera.is_position_behind(at):
		return null
	# unproject_position is in the 3D viewport's pixels (the window's, on the root), not the UI's stretched units;
	# the screenshot is the viewport's texture, so it is scaled from the one to the other (1 where they match)
	var p := camera.unproject_position(at)
	var size := Vector2(viewport.size) if viewport is Window else viewport.get_visible_rect().size
	var shot := Vector2(viewport.get_texture().get_size()) if viewport.get_texture() != null else size
	var q := p * (shot / size)
	if q.x < 0 or q.y < 0 or q.x > shot.x or q.y > shot.y:     # judged on the screenshot itself
		return null
	return [snappedf(q.x, 0.1), snappedf(q.y, 0.1)]


static func _registry(tree: SceneTree) -> Node:
	if tree == null or tree.current_scene == null:
		return null
	var live := tree.current_scene.get_node_or_null("VillageLive")
	return live.get("registry") if live != null else null


## The save as it stands now (the game saves, then the file is read back), or "" where saving is off.
static func _save_now() -> String:
	var path: Variant = SaveGame.get("_path")
	if path == null:
		return ""
	SaveGame.save_game()
	return FileAccess.get_file_as_string(str(path)) if FileAccess.file_exists(str(path)) else ""


static func _v3(p: Vector3) -> Array:
	return [snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)]
