extends SceneTree
## Graphics S0 (studio plan GRAPHICS-STAGES-2026-10-04.md): where a frame's draw calls come from. Dev-only: nothing in
## the game calls it. It starts the real main scene as a normal launch with a dev argument would (living village on,
## a fresh test save), so the counts are the game's own, then for each time of day and camera framing it pauses the
## world, reads the frame's counters and hides one category at a time to see what each costs.
##
##   godot --rendering-driver opengl3 --fixed-fps 30 --path game --resolution 1560x720 \
##     --script res://scripts/studio/render/draw_probe.gd -- --test-save=drawprobe --probe-out=<absolute dir> [--probe-region=forest]
##
## Options: --probe-times=morning,noon,night (morning is the start, 07:12, when the low sun casts no shadows; noon and
## night move the village clock on to 12:00 and 22:30),
## --probe-frames=explore,build45,low (camera/framings.gd's explore and build; low is the game's own camera),
## --probe-lod-at=far,explore (where the auto-LOD test runs), --probe-wait=<frames> after a time or framing change.
## --probe-region=forest arrives there as through its gate; --probe-cave then goes down into Glimmerdeep (Enea's main); --probe-at=x,z puts the player there; --probe-yaw=<deg> turns
## the camera (180 looks south).
##
## Writes <out>/draws.json and <out>/draws.txt, and per time and framing three captures with the HUD hidden, for the
## parity tool (studio toolbox/parity): <time>-<framing>.png, then -noplayer.png (the player hidden: a change the tool
## must see), then -again.png (the player back: base against again is the floor, spanning the control in time), all
## with the world still paused. Prints DRAWPROBE lines.
## Exit 0 when every breakdown sums to its measured total, 1 when one does not, 3 when the scene never came up.
##
## Counting [Godot 4.7, Compatibility]: Viewport.get_render_info gives the root viewport's draws by pass (visible,
## shadow, canvas); RenderingServer's total is what the game's own FPS label shows (the S10's 629). Categories are
## disjoint, so each one's drop is its own cost; the remainder after hiding every category is what no category owns.
## The breakdown sums the 3D passes; the canvas (the HUD) is reported beside it, since its FPS text changes on its own.

const FRAMINGS := {   # distance m, pitch deg, lens deg
	"explore": [8.0, -10.0, 50.0],
	"build45": [18.0, -45.0, 32.0],
	"far": [45.0, -14.0, 50.0],
}
const TIMES := {"morning": -1, "noon": 720, "night": 1350}   # minute of the day; -1: as the game starts (07:12, sun low, no shadows)
const CATEGORIES := ["nature", "buildings and props", "characters", "effects", "labels and markers", "terrain and water",
	"batched (S1)", "other"]
const CHARACTER_GROUPS := ["player", "Enea's NPCs", "villagers", "creatures"]
## Scripts whose meshes are characters, wherever they sit (an NPC's body, a creature's body, a carried carcass).
const CHARACTER_SCRIPTS := ["character_visual.gd", "npc.gd", "villager_body.gd", "boar_visual.gd", "wolf_visual.gd",
	"stag_visual.gd", "critters.gd", "carcass.gd", "crow.gd", "player.gd", "companion.gd", "elk_mount.gd"]
const MARKER_SCRIPTS := ["quest_guide.gd", "lock_marker.gd"]
const BUILDING_SCRIPTS := ["village.gd", "places.gd", "treasure.gd", "workbench.gd", "station.gd", "project_site.gd",
	"home_plot.gd", "butcher.gd", "region_gates.gd", "ox_cart.gd", "landmark_light.gd", "shrine.gd", "campfire.gd",
	"bandit_camp.gd", "use_spot.gd", "home_interior.gd", "props.gd", "cave.gd", "waystone.gd", "forest_village.gd",
	"bounty_board.gd", "visit_interior.gd", "fishing_spots.gd"]      # (the last six: Enea's main, 5 Oct)

var _out := ""
var _times: PackedStringArray = ["morning", "noon", "night"]
var _frames: PackedStringArray = ["explore", "build45", "low"]
var _lod_at: PackedStringArray = ["far", "explore"]
var _wait := 45
var _yaw := 0.0          # --probe-yaw=<deg>: the camera's turn (0 looks north, as the game starts)
var _at := Vector2.INF   # --probe-at=x,z: where the player stands (the game's own --at runs only with --shot)
var _cave := false       # --probe-cave: Glimmerdeep (Enea's main), entered as its mouth enters it
var _report := {"framings": [], "lod": [], "notes": []}
var _all_sum := true


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--probe-out="):
			_out = arg.trim_prefix("--probe-out=")
		elif arg.begins_with("--probe-times="):
			_times = arg.trim_prefix("--probe-times=").split(",", false)
		elif arg.begins_with("--probe-frames="):
			_frames = arg.trim_prefix("--probe-frames=").split(",", false)
		elif arg.begins_with("--probe-lod-at="):
			_lod_at = arg.trim_prefix("--probe-lod-at=").split(",", false)
		elif arg.begins_with("--probe-wait="):
			_wait = maxi(int(arg.trim_prefix("--probe-wait=")), 10)
		elif arg.begins_with("--probe-at="):
			var xz := arg.trim_prefix("--probe-at=").split(",")
			_at = Vector2(float(xz[0]), float(xz[1]))
		elif arg.begins_with("--probe-yaw="):
			_yaw = deg_to_rad(float(arg.trim_prefix("--probe-yaw=")))
		elif arg == "--probe-cave":
			_cave = true          # (with --probe-region=forest) down into Glimmerdeep, as its mouth takes the player
		elif arg.begins_with("--probe-region="):
			# Arrive as through the gate (Region.travel's own state): with a test save the game reads the region from
			# the save, not from --region, so a fresh test save always starts in the meadow.
			var region := root.get_node("Region")
			var to := arg.trim_prefix("--probe-region=")
			for from: String in region.get("GATES"):
				for g: Dictionary in region.get("GATES")[from]:
					if g["to"] == to:
						region.set("current", to)
						region.set("arrive", g["arrive"])
	if _out == "":
		print("DRAWPROBE REFUSE no --probe-out=<absolute dir>")
		quit(3)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _run() -> void:
	for i in 240:   # the region, the village and its people come up over the first frames
		await process_frame
		if current_scene != null and current_scene.name == "Main" and i > 150:
			break
	var main := current_scene
	if main == null or main.name != "Main":
		print("DRAWPROBE FAIL the main scene never came up")
		quit(3)
		return
	var rig: Node3D = main.get_node("CameraRig")
	var day_night: Node = main.get_node("WorldEnvironment")
	if _cave:
		var cave := get_first_node_in_group("cave")
		if cave == null:
			print("DRAWPROBE FAIL no cave here (it is under the forest: --probe-region=forest)")
			quit(3)
			return
		cave.call("enter")
		rig.call("snap")
		for _i in _wait:
			await process_frame
	if _at != Vector2.INF:
		var player: Node3D = main.get_node("Player")
		var shape: RefCounted = load("res://scripts/world/world_shape.gd").new()
		player.global_position = Vector3(_at.x, float(shape.call("height_at", _at.x, _at.y)) + 0.3, _at.y)
		rig.call("snap")
		for _i in _wait:
			await process_frame
	# Autoloads are nodes here (a --script runner cannot name them); older builds have no village (29 Sep, look board 1).
	var session: Node = root.get_node_or_null("VillageSession")
	var region: Node = root.get_node_or_null("Region")
	_report["region"] = str(region.get("current")) if region != null else "meadow"
	_report["resolution"] = "%dx%d" % [root.size.x, root.size.y]
	_report["renderer"] = RenderingServer.get_current_rendering_method()
	_report["living_village"] = main.get_node_or_null("VillageLive") != null
	for t in _times:
		var minute: int = TIMES.get(t, -1)
		if minute >= 0:
			var village = session.get("village") if session != null else null
			var now := int(village.runtime.now) if village != null else int(float(day_night.get("time_of_day")) * 1440.0)
			var to := (now - now % 1440) + minute
			if to <= now:
				to += 1440
			day_night.skip(float(to - now) / 1440.0)   # the village clock moves on: people go home, lamps light
			for _i in _wait * 3:
				await process_frame
		_report["notes"].append("%s: clock %.4f" % [t, float(day_night.get("time_of_day"))])
		for f in _frames:
			await _frame_view(rig, f)
			var entry := await _measure(main, t, f)
			_report["framings"].append(entry)
		for f in _lod_at:
			if t != _times[0]:
				continue
			await _frame_view(rig, f)
			_report["lod"].append(await _lod(f))
	rig.reset_view(0.01)
	_write()
	quit(0 if _all_sum else 1)


## Puts the camera on a framing and lets the world catch up (the tree fader, the camera's ease).
func _frame_view(rig: Node3D, f: String) -> void:
	paused = false
	if f == "low":
		rig.reset_view(0.01)
	else:
		var v: Array = FRAMINGS[f]
		if rig.get_method_argument_count("set_view") >= 5:
			rig.set_view(v[0], v[1], Vector3.ZERO, 0.01, v[2])
		else:   # before set_view took a lens (look board 1's build): the lens is set after, as framings.gd did then
			rig.set_view(v[0], v[1], Vector3.ZERO, 0.01)
			rig.get("camera").fov = v[2]
	if _yaw != 0.0:
		rig.call("_set_yaw", _yaw)
	rig.snap()
	for _i in _wait:
		await process_frame


func _counts() -> Dictionary:
	var vp := root
	var c := {
		"total": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"visible": vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"shadow": vp.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"visible_objects": vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_OBJECTS_IN_FRAME),
		"shadow_objects": vp.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_OBJECTS_IN_FRAME),
		"visible_primitives": vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
	}
	if ClassDB.class_has_integer_constant("Viewport", "RENDER_INFO_TYPE_CANVAS"):
		c["canvas"] = vp.get_render_info(ClassDB.class_get_integer_constant("Viewport", "RENDER_INFO_TYPE_CANVAS"), Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	return c


## Counters for the frame after a change: a render info reading describes the last frame drawn, so wait, then read
## twice and insist they agree (the world is paused, so they must).
func _settled() -> Dictionary:
	for _i in 3:
		await process_frame
	var a := _counts()
	await process_frame
	var b := _counts()
	if a != b:
		_report["notes"].append("unsettled counters: %s then %s" % [str(a), str(b)])
	return b


func _measure(main: Node, t: String, f: String) -> Dictionary:
	paused = true
	var batch: Node = main.get_node_or_null("StudioBatch")   # graphics S1: its batches stay put while the probe hides things
	if batch != null:
		batch.set("frozen", true)
		_report["batch"] = batch.call("report")
	var things: Node = main.get_node_or_null("StudioThings")     # graphics S4: its idle cost (no facts in a build)
	if things != null and not _report.has("things"):
		var t0 := Time.get_ticks_usec()
		for _k in 200:
			things.call("_process", 1.0 / 30.0)
		_report["things"] = (things.call("report") as Dictionary).merged({"idle_usec": float(Time.get_ticks_usec() - t0) / 200.0})
	var groups := _classify(main)
	var base := await _settled()
	var entry := {"time": t, "framing": f, "base": base, "categories": {}, "characters": {},
		"memory_mb": {"video": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1e6, 0.01),
			"buffers": snappedf(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1e6, 0.01),
			"static": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1e6, 0.01)}}
	for cat in CATEGORIES:
		entry["categories"][cat] = await _drop(groups["by_category"].get(cat, []), base)
	for g in CHARACTER_GROUPS:
		entry["characters"][g] = await _drop(groups["by_character"].get(g, []), base)
	# Shadows: this renderer counts its shadow-map draws with the frame's draws and reports no shadow pass of its own
	# (RENDER_INFO_TYPE_SHADOW reads 0 with the sun's shadows plainly drawn), so they are measured by switching every
	# light's shadows off: the drop is the shadow draws. Each category alone is then measured again without them; the
	# difference is that category's share of the shadows.
	var lights: Array = []
	for l in root.find_children("*", "Light3D", true, false):
		if (l as Light3D).shadow_enabled and (l as Light3D).is_visible_in_tree():
			lights.append(l)
	for l in lights:
		(l as Light3D).shadow_enabled = false
	var unshadowed := await _settled() if not lights.is_empty() else base
	entry["shadow_lights"] = lights.size()
	entry["shadows"] = _d3(base) - _d3(unshadowed)
	for cat in CATEGORIES:
		var d: Dictionary = entry["categories"][cat]
		var main_only := await _drop(groups["by_category"].get(cat, []), unshadowed) if not lights.is_empty() else d
		d["main"] = int(main_only["visible"]) + int(main_only["shadow"])
		d["casts"] = int(d["visible"]) + int(d["shadow"]) - int(d["main"])
	# In turn: shadows off first, then each category hidden on top of the ones before, in the table's order. The steps
	# sum exactly to the 3D draws less what no category owns (the remainder, with everything hidden). Alone is what each
	# costs by itself, checked as its main pass (shadows off) plus the shadow pass once, as its own term: the two differ
	# only where the main passes are not additive (the interaction, reported, never hidden).
	var hidden: Array = []
	var prev := unshadowed
	entry["in_turn"] = {}
	for cat in CATEGORIES:
		var nodes: Array = groups["by_category"].get(cat, [])
		for n in nodes:
			(n as GeometryInstance3D).visible = false
		hidden.append_array(nodes)
		var now := await _settled() if not nodes.is_empty() else prev
		entry["in_turn"][cat] = _d3(prev) - _d3(now)
		prev = now
	for n in hidden:
		(n as GeometryInstance3D).visible = true
	for l in lights:
		(l as Light3D).shadow_enabled = true
	entry["remainder"] = prev
	# Checked on the 3D passes (visible + shadow): the HUD's canvas draws change with its own text (the FPS label runs
	# while the world is paused), so the canvas is reported beside the breakdown, not inside it.
	# The shadow pass is its own term. A shadow map is not additive by the renderer's design: a category's shadow
	# casts measured alone (the drop when it is hidden with the shadows on) overlap the others' (on 5-6 Oct the casts
	# summed 3-4 more than the whole shadow pass at a sunlit view, every time, while the main passes summed exactly). So
	# the casts are reported per category, and their sum beside the shadow pass, but never summed into the check.
	var alone := int(entry["shadows"])
	var casts := 0
	var in_turn := int(entry["shadows"])
	for cat in CATEGORIES:
		alone += int(entry["categories"][cat]["main"])
		casts += int(entry["categories"][cat]["casts"])
		in_turn += int(entry["in_turn"][cat])
	entry["sum_of_drops"] = alone
	entry["casts_sum"] = casts
	entry["in_turn_sum"] = in_turn
	entry["base_3d"] = _d3(base)
	entry["remainder_3d"] = _d3(prev)
	entry["interaction"] = alone + int(entry["remainder_3d"]) - int(entry["base_3d"])
	# The gate: the in-turn steps and the remainder sum to the measured draws, and the categories' main passes alone,
	# with the shadow pass, stay within 1 % (at least 2 draws) of them.
	entry["sums"] = in_turn + int(entry["remainder_3d"]) == int(entry["base_3d"]) \
		and absi(int(entry["interaction"])) <= maxi(2, int(entry["base_3d"]) / 100)
	if not entry["sums"]:
		_all_sum = false
	var restored := await _settled()
	entry["restored"] = int(restored["visible"]) + int(restored["shadow"]) == int(entry["base_3d"])
	# The capture for parity: the 3D frame only (the HUD's FPS text differs between any two runs).
	var hud: CanvasLayer = main.get_node("HUD")
	hud.visible = false
	for _i in 3:
		await process_frame
	var png := "%s/%s-%s.png" % [_out, t, f]
	root.get_texture().get_image().save_png(png)
	# A known change for the parity tool's control (the same frame without the player), then the unchanged frame again:
	# base and again span the control in time, so shader time moves the floor at least as far as the control.
	var player: Array = groups["by_character"].get("player", [])
	for n in player:
		(n as GeometryInstance3D).visible = false
	for _i in 3:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s-%s-noplayer.png" % [_out, t, f])
	for n in player:
		(n as GeometryInstance3D).visible = true
	for _i in 3:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s-%s-again.png" % [_out, t, f])
	hud.visible = true
	entry["capture"] = png.get_file()
	entry["nodes"] = groups["nodes"]
	print("DRAWPROBE %s %s total %d (3D %d, canvas %s); shadows %d; 3D alone %s; remainder %d; interaction %d; sums %s" % [
		t, f, base["total"], entry["base_3d"], str(base.get("canvas", "-")), entry["shadows"],
		JSON.stringify(_short(entry["categories"])), entry["remainder_3d"], entry["interaction"], str(entry["sums"])])
	paused = false
	if batch != null:
		batch.set("frozen", false)
	return entry


## The 3D passes' draws in a reading (the root viewport's visible and shadow passes).
func _d3(c: Dictionary) -> int:
	return int(c["visible"]) + int(c["shadow"])


## Hides these geometry nodes, reads what the frame lost, and puts them back exactly.
func _drop(nodes: Array, base: Dictionary) -> Dictionary:
	if nodes.is_empty():
		return {"draws": 0, "visible": 0, "shadow": 0, "objects": 0, "primitives": 0, "nodes": 0, "left": base}
	for n in nodes:
		(n as GeometryInstance3D).visible = false
	var after := await _settled()
	var reshown := 0
	for n in nodes:
		if is_instance_valid(n) and (n as GeometryInstance3D).visible:
			reshown += 1
		(n as GeometryInstance3D).visible = true
	if reshown > 0:
		_report["notes"].append("%d nodes were shown again while hidden" % reshown)
	return {
		"draws": base["total"] - after["total"],
		"visible": base["visible"] - after["visible"],
		"shadow": base["shadow"] - after["shadow"],
		"objects": base["visible_objects"] - after["visible_objects"],
		"primitives": base["primitives"] - after["primitives"],
		"nodes": nodes.size(),
		"left": after,
	}


## Every geometry node drawn in the main viewport, by category. Disjoint: each node gets exactly one.
func _classify(main: Node) -> Dictionary:
	var by_category := {}
	var by_character := {}
	var nodes := {}
	for g in root.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		if gi.get_viewport() != root or not gi.is_visible_in_tree():
			continue
		var cat := _category(main, gi)
		if not by_category.has(cat):
			by_category[cat] = []
		by_category[cat].append(gi)
		nodes[cat] = int(nodes.get(cat, 0)) + 1
		if cat == "characters":
			var who := _character_group(main, gi)
			if not by_character.has(who):
				by_character[who] = []
			by_character[who].append(gi)
	return {"by_category": by_category, "by_character": by_character, "nodes": nodes}


func _category(main: Node, gi: GeometryInstance3D) -> String:
	if gi is CPUParticles3D or gi is GPUParticles3D:
		return "effects"
	if gi is Label3D or gi is Sprite3D:
		return "labels and markers"
	var top := _top(main, gi)
	if top == "StudioBatch":
		return "batched (S1)"
	var scripts := _scripts(gi)
	for s in MARKER_SCRIPTS:
		if s in scripts:
			return "labels and markers"
	if top in ["Player", "Enemies", "VillageLive"]:
		return "characters"
	for s in CHARACTER_SCRIPTS:
		if s in scripts:
			return "characters"
	if top == "Terrain":
		return "terrain and water"
	if top in ["Scatter", "ResourceVisuals"]:
		return "nature"
	for s in BUILDING_SCRIPTS:
		if s in scripts:
			return "buildings and props"
	if top in ["Village", "Landmark"]:
		return "buildings and props"
	_report["notes"].append("other: %s (%s)" % [str(main.get_path_to(gi)), gi.get_class()])
	return "other"


func _character_group(main: Node, gi: GeometryInstance3D) -> String:
	var top := _top(main, gi)
	if top == "Player":
		return "player"
	if top == "VillageLive" or "villager_body.gd" in _scripts(gi):
		return "villagers"
	if top == "Village":
		return "Enea's NPCs"
	return "creatures"


func _top(main: Node, n: Node) -> String:
	var a := n
	while a.get_parent() != null and a.get_parent() != main and a.get_parent() != root:
		a = a.get_parent()
	return str(a.name)


func _scripts(n: Node) -> PackedStringArray:
	var out: PackedStringArray = []
	var a := n
	while a != null:
		if a.get_script() != null:
			out.append((a.get_script() as Script).resource_path.get_file())
		a = a.get_parent()
	return out


## Auto-LOD: the same view with mesh LOD on (the default threshold) and off (0: every mesh at full detail).
func _lod(f: String) -> Dictionary:
	paused = true
	var on := await _settled()
	var was := root.mesh_lod_threshold
	root.mesh_lod_threshold = 0.0
	var off := await _settled()
	root.mesh_lod_threshold = was
	await _settled()
	paused = false
	var r := {"framing": f, "threshold": was, "lod_on": {"draws": on["total"], "primitives": on["primitives"]},
		"lod_off": {"draws": off["total"], "primitives": off["primitives"]}}
	print("DRAWPROBE lod %s threshold %.2f: primitives %d with LOD, %d without; draws %d / %d" % [f, was,
		on["primitives"], off["primitives"], on["total"], off["total"]])
	return r


func _short(cats: Dictionary) -> Dictionary:
	var s := {}
	for k in cats:
		s[k] = int(cats[k]["visible"]) + int(cats[k]["shadow"])
	return s


func _write() -> void:
	var f := FileAccess.open(_out + "/draws.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(_report, "  "))
	f.close()
	var lines: PackedStringArray = []
	lines.append("Draw-call breakdown, region %s, %s, %s, living village %s" % [_report["region"], _report["resolution"],
		_report["renderer"], str(_report["living_village"])])
	for e: Dictionary in _report["framings"]:
		var b: Dictionary = e["base"]
		lines.append("")
		lines.append("  memory MB: %s" % JSON.stringify(e.get("memory_mb", {})))
		lines.append("%s, %s: total %d = visible %d + shadow %d + canvas %s + other viewports %d; objects %d, primitives %dk" % [
			e["time"], e["framing"], b["total"], b["visible"], b["shadow"], str(b.get("canvas", "-")),
			int(b["total"]) - int(b["visible"]) - int(b["shadow"]) - int(b.get("canvas", 0)), b["objects"], int(b["primitives"]) / 1000])
		lines.append("  %-22s %7s %6s %6s %6s %8s %7s %6s" % ["3D draws", "in turn", "alone", "main", "casts", "objects", "kprims",
			"nodes"])
		lines.append("  %-22s %7d %6s %6s %6s   (every light's shadows off: %d lights)" % ["shadows", e["shadows"], "", "", "",
			e["shadow_lights"]])
		for cat in CATEGORIES:
			var d: Dictionary = e["categories"][cat]
			lines.append("  %-22s %7d %6d %6d %6d %8d %7d %6d" % [cat, e["in_turn"][cat], int(d["visible"]) + int(d["shadow"]),
				d["main"], d["casts"], d["objects"], int(d["primitives"]) / 1000, d["nodes"]])
		lines.append("  %-22s %7d   (3D drawn by no category)" % ["remainder", e["remainder_3d"]])
		lines.append("  3D measured %d: in turn (shadows first) %d + remainder %d; alone (main passes + the shadow pass) %d + remainder %d (interaction %d): %s" % [e["base_3d"],
			e["in_turn_sum"], e["remainder_3d"], e["sum_of_drops"], e["remainder_3d"], e["interaction"],
			"SUMS" if e["sums"] else "DOES NOT SUM"])
		if e.has("casts_sum"):
			lines.append("  shadow casts by category %d, the shadow pass %d (a shadow map is not additive: reported, not summed)" % [
				e["casts_sum"], e["shadows"]])
		lines.append("  %-22s %6s   (the HUD and every 2D control)" % ["canvas", str(b.get("canvas", "-"))])
		lines.append("  %-22s %6d   (item icons and other sub-viewports)" % ["other viewports",
			int(b["total"]) - int(b["visible"]) - int(b["shadow"]) - int(b.get("canvas", 0))])
		lines.append("  characters by group:")
		for g in CHARACTER_GROUPS:
			var d: Dictionary = e["characters"][g]
			lines.append("    %-20s %6d draws (%d visible, %d shadow), %d nodes" % [g, int(d["visible"]) + int(d["shadow"]), d["visible"], d["shadow"], d["nodes"]])
	lines.append("")
	for l: Dictionary in _report["lod"]:
		lines.append("LOD at %s (threshold %.2f): %dk primitives with auto-LOD, %dk without; draws %d / %d" % [l["framing"],
			l["threshold"], int(l["lod_on"]["primitives"]) / 1000, int(l["lod_off"]["primitives"]) / 1000, l["lod_on"]["draws"], l["lod_off"]["draws"]])
	if not _report["notes"].is_empty():
		lines.append("")
		lines.append("Notes:")
		for n in _report["notes"]:
			lines.append("  " + str(n))
	var t := FileAccess.open(_out + "/draws.txt", FileAccess.WRITE)
	t.store_string("\n".join(lines) + "\n")
	t.close()
	print("DRAWPROBE wrote %s/draws.txt" % _out)
