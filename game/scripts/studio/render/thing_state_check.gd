extends SceneTree
## Graphics S4's proof (studio plan GRAPHICS-STAGES-2026-10-04.md): things with state, in the real scene. Dev-only:
## nothing in the game calls it.
##
##   godot --rendering-driver opengl3 --fixed-fps 30 --path game --resolution 1560x720 \
##     --script res://scripts/studio/render/thing_state_check.gd -- --test-save=<fresh> --check-out=<absolute dir> \
##     --studio-things=on|off --studio-batch=on --studio-merge=on
##
## Off: nothing is attached (today's scene). On: first the idle cost a build pays (the frame's drive over the region's
## own things, no facts). Then a row of the four carriers (fence, bench, crates, rack) is built the way Enea's builders
## build them, beside the player; they are found and given their columns. Then:
##   neutral parity in place: the row drawn with his materials, the thing copies, his again (for toolbox/parity);
##   a state change costs no draw call: paused, the same frame neutral, then soot, char, wet, wear, flash, shake and
##     tint all set, then neutral again, draw calls read each time;
##   its time: a column written and the texture uploaded, 200 times; and the per-frame drive with every thing burning;
##   Body's runtime plays them: facts in the requested shape, from THIS CHECK'S FIXTURE (nothing in the game sets a
##     thing's facts yet; Body's setters come after Hilmi plays), through people/body_elements.gd and the five modules
##     in things/elements/, stage by stage, by day and at night: intact, burning (2 s, then 10 s), doused (soaked
##     while scorched: steam), dried and scorched, struck, broken, repaired (all facts gone: neutral again);
##   the shared effects (villager_body.make_fx) six frames after they start, before and after the black-disc fix;
##   a thing freed gives its column back.
## Prints CHECK PASS/FAIL lines and "CHECK complete: N checks, F failed"; writes captures (day-*, night-*, neutral-*,
## fx-before-after) and check.json (with the crop the boards use; graphics-s4.sh composes them).

const KINDS := ["fence", "bench", "crates", "rack"]
const MODELS := {"fence": "res://assets/props/fence.glb", "bench": "res://assets/props/bench.glb",
	"crates": "res://assets/camp/camp_crates.glb", "rack": "res://assets/camp/camp_rack.glb"}
const SPACING := 2.4

var _out := ""
var _on := true
var _lines: PackedStringArray = []
var _failed := 0
var _report := {}
var _facts := {}                     # thing id -> {kind: fact}: the fixture standing in for Body's thing facts
var _clock := 100000                 # the facts' clock, ms
var _deed := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--check-out="):
			_out = arg.trim_prefix("--check-out=")
		elif arg == "--studio-things=off":
			_on = false
	if _out == "":
		print("CHECK REFUSE no --check-out=<absolute dir>")
		quit(3)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	var line := ("CHECK PASS " if ok else "CHECK FAIL ") + what
	print(line)
	_lines.append(line)
	if not ok:
		_failed += 1


func _frames(n: int) -> void:
	for _i in n:
		await process_frame
		if not paused:
			_clock += 33


func _draws() -> int:
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)


func _run() -> void:
	for i in 240:
		await process_frame
		if current_scene != null and current_scene.name == "Main" and i > 150:
			break
	var main := current_scene
	var things: Node = main.get_node_or_null("StudioThings")
	if not _on:
		_check(things == null, "switch off: nothing is attached (today's scene)")
		_check(main.get_node_or_null("StudioBatch") != null, "switch off: the batcher (S1) still attaches by its own switch")
		_finish()
		return
	_check(things != null, "switch on: attached by the S1 line in main.gd")
	if things == null:
		_finish()
		return
	things.set("facts_source", func() -> Dictionary: return _facts)
	things.set("tick_source", func() -> int: return _clock)
	# What it costs a build, where nothing sets a thing's facts yet: the frame's drive over the region's own things.
	paused = true
	await _frames(1)
	var own := int((things.call("report") as Dictionary).things)
	var t_idle := Time.get_ticks_usec()
	for k in 200:
		things.call("_process", 1.0 / 30.0)
	var idle_scene := float(Time.get_ticks_usec() - t_idle) / 200.0
	paused = false
	_report["idle_scene"] = {"things": own, "usec": idle_scene}
	print("CHECK note: idle in the real scene (no facts): %d things of the region's own, %.2f microseconds a frame" % [own, idle_scene])

	# The row, built as Enea's builders build these (TREASURE._solid on the instanced model), beside the player.
	var player: Node3D = main.get_node("Player")
	var centre := player.global_position + Vector3(3.0, 0.0, 4.0)
	var holder := Node3D.new()
	holder.name = "ThingRow"
	main.add_child(holder)
	var treasure: GDScript = load("res://scripts/world/treasure.gd")
	var roots: Array[Node3D] = []
	for i in KINDS.size():
		var m: Node3D = treasure.call("_solid", (load(MODELS[KINDS[i]]) as PackedScene).instantiate())
		holder.add_child(m)
		m.global_position = _ground(centre + Vector3((float(i) - 1.5) * SPACING, 0.0, 0.0))
		roots.append(m)
	await _frames(3)
	var ids: Array[String] = []
	for m in roots:
		ids.append(str(m.get_meta("studio_thing", "")))
	_check(not ids.has(""), "found as they were built (deferred to the frame's end): %s" % ", ".join(ids))
	var all: Dictionary = things.call("things")
	var body = all[ids[0]].body if all.has(ids[0]) else null
	var modules: Array = (body.runner.modules as Dictionary).keys() if body != null else []
	_check(body != null and body.runner.get_script().resource_path == "res://scripts/studio/people/body_elements.gd" \
		and modules == ["broken", "burning", "scorched", "soaked", "struck"],
		"played by Body's own runtime (people/body_elements.gd) with the thing modules %s" % str(modules))
	_report["found"] = things.call("report")

	# Camera on the row; the HUD off for captures.
	var cam := Camera3D.new()
	main.add_child(cam)
	var look := centre + Vector3(0.0, 0.7, 0.0)
	look.y = _ground(centre).y + 0.7
	cam.global_position = look + Vector3(0.0, 2.0, 7.5)
	cam.look_at(look)
	cam.fov = 50.0
	cam.current = true
	var hud: CanvasLayer = main.get_node("HUD")
	hud.visible = false
	await _frames(20)

	# Neutral parity in place, and a state change's draw calls, in one paused frame.
	paused = true
	await _frames(3)
	for step in [["his", true], ["things", false], ["his-again", true]]:
		things.call("show_originals", step[1])
		await _frames(3)
		root.get_texture().get_image().save_png("%s/neutral-%s.png" % [_out, step[0]])
	things.call("show_originals", false)
	await _frames(3)
	var d0 := _draws()
	things.call("set_channels", ids[0], {"soot": 0.6, "char": 0.5, "wet": 0.7, "wear": 0.4, "flash": 0.5, "shake": 0.3,
		"ember": 0.8, "tint": Color(0.9, 0.85, 0.8)})
	things.call("set_channels", ids[2], {"soot": 1.0, "wet": 1.0})
	var upload := int(things.call("flush"))
	await _frames(3)
	var d1 := _draws()
	root.get_texture().get_image().save_png("%s/channels-set.png" % _out)
	things.call("set_channels", ids[0], {})
	things.call("set_channels", ids[2], {})
	things.call("flush")
	await _frames(3)
	var d2 := _draws()
	_check(d0 == d1 and d1 == d2, "a state change costs no draw call: %d neutral, %d with every channel set on two things, %d neutral again" % [d0, d1, d2])
	_report["draws"] = [d0, d1, d2]

	# Its time: a column written and uploaded, 200 times; then the frame's drive with all four burning.
	var t0 := Time.get_ticks_usec()
	for k in 200:
		things.call("set_channels", ids[k % 4], {"soot": float(k % 7) / 7.0, "wet": float(k % 5) / 5.0, "flash": float(k % 2)})
		things.call("flush")
	var per_change := float(Time.get_ticks_usec() - t0) / 200.0
	for id in ids:
		things.call("set_channels", id, {})
	things.call("flush")
	for id in ids:
		_facts[id] = {"burning": _fact("burning", id, 2000, 60000, {"heat": 800})}
	things.call("_process", 0.0)            # (the first frame begins the elements)
	t0 = Time.get_ticks_usec()
	for k in 100:
		things.call("_process", 1.0 / 30.0)
	var per_frame := float(Time.get_ticks_usec() - t0) / 100.0
	_facts.clear()
	things.call("_process", 1.0 / 30.0)
	t0 = Time.get_ticks_usec()
	for k in 100:
		things.call("_process", 1.0 / 30.0)
	var idle := float(Time.get_ticks_usec() - t0) / 100.0
	_check(per_change <= 100.0, "a state change takes %.1f microseconds (a column written and the texture uploaded; limit 100), first upload %d" % [per_change, upload])
	_report["usec"] = {"per_change": per_change, "drive_4_burning": per_frame, "drive_4_neutral": idle, "first_upload": upload}
	print("CHECK note: the frame's drive, four things burning through Body's runtime: %.1f microseconds; four neutral: %.1f" % [per_frame, idle])
	paused = false

	# Body's runtime, stage by stage, for the boards: by day, then at night.
	await _frames(10)
	var stages: Array = await _stages("day", ids, roots)
	var debris := int(stages[6].debris)
	_check(debris == 4, "broken: each piece gone and its debris lying there (%d of 4)" % debris)
	var neutral := true
	var img: Image = things.get("_image")
	for id in ids:
		var col := int(all[id].column)
		for r in 3:
			neutral = neutral and img.get_pixel(col, r) == Color(0, 0, 0, 0)
	var fx_left := 0
	for m in roots:
		fx_left += m.find_children("*", "CPUParticles3D", false, false).size() \
			+ m.find_children("StudioDebris", "MultiMeshInstance3D", false, false).size()
	_check(neutral and fx_left == 0, "repaired (every fact gone): every column neutral again, no effect or debris left (%d)" % fx_left)
	var flames: int = stages[1].fx
	_check(flames == 4 and int(stages[3].fx) == 4 and int(stages[4].fx) == 0,
		"the people's own effects on things: flames while burning (%d), steam when doused (%d), none once dry (%d)" % [flames, stages[3].fx, stages[4].fx])
	await _to_night(main)
	var night: Array = await _stages("night", ids, roots)
	_check(int(night[1].fx) == 4 and int(night[6].debris) == 4, "at night the same: flames (%d), debris (%d)" % [night[1].fx, night[6].debris])
	_report["stages"] = stages + night
	_report["board_rect"] = _rect(roots, cam)
	await _fx_board(main, look, cam)

	# A thing freed gives its column back.
	var before := int((things.call("report") as Dictionary).things)
	roots[3].queue_free()
	await _frames(2)
	_check(int((things.call("report") as Dictionary).things) == before - 1, "freed: it leaves and gives its column back")
	_finish()


## The shared effects six frames after they start, as made before this stage (no pre-run: the particles not yet emitted
## drew as a black disc at the emitter) and as made now, side by side in one frame: fx-before-after.png.
func _fx_board(main: Node, look: Vector3, cam: Camera3D) -> void:
	var vb: GDScript = load("res://scripts/studio/village/villager_body.gd")
	var made: Array[Node3D] = []
	var kinds := ["steam", "smoke", "flames"]
	for i in kinds.size():
		for now in [false, true]:
			var p: CPUParticles3D = vb.call("make_fx", kinds[i], 1.2, 1.0)
			if not now:
				p.preprocess = 0.0
			main.add_child(p)
			p.global_position = look + cam.global_basis.x * ((float(i) - 1.0) * 2.6 + (0.6 if now else -0.6)) \
				+ Vector3(0.0, 0.6, 0.0) + cam.global_basis.z * 2.0
			p.emitting = true
			made.append(p)
	await _frames(6)
	root.get_texture().get_image().save_png(_out + "/fx-before-after.png")
	for p in made:
		p.queue_free()


func _fact(kind: String, id: String, age_ms: int, until_ms: int, fields: Dictionary) -> Dictionary:
	var f := {"kind": kind, "id": "%s:%s" % [kind, id], "deed": "check-%d" % _deed, "cause_id": "check",
		"revision": 1, "since_tick": _clock - age_ms, "strength": 1000, "at": [0.0, 0.0]}
	if until_ms >= 0:
		f["until_tick"] = _clock + until_ms
	f.merge(fields, true)
	return f


func _stage(prefix: String, label: String, roots: Array[Node3D]) -> Dictionary:
	await _frames(2)
	var shot := "%s/%s-%s.png" % [_out, prefix, label.replace(" ", "-").replace(",", "")]
	root.get_texture().get_image().save_png(shot)
	var fx := 0
	for n in (current_scene.get_node("ThingRow") as Node).find_children("*", "CPUParticles3D", true, false):
		fx += 1
	var debris := 0
	for m in roots:
		if is_instance_valid(m):
			debris += m.find_children("StudioDebris", "MultiMeshInstance3D", false, false).size()
	return {"label": label, "time": prefix, "shot": shot, "fx": fx, "debris": debris, "draws": _draws()}


## One pass of the stages, captured as <prefix>-<stage>.png. Facts as Body would set them (the requested shape), from
## this check's fixture: nothing in the game sets a thing's facts yet.
func _stages(prefix: String, ids: Array[String], roots: Array[Node3D]) -> Array:
	var out := []
	_deed += 1
	out.append(await _stage(prefix, "intact", roots))
	for id in ids:
		_facts[id] = {"burning": _fact("burning", id, 2000, 60000, {"heat": 800}),
			"scorched": _fact("scorched", id, 2000, -1, {"level": 150})}
	await _frames(40)
	out.append(await _stage(prefix, "burning 2 s", roots))
	_deed += 1
	for id in ids:
		_facts[id] = {"burning": _fact("burning", id, 10000, 60000, {"heat": 900}),
			"scorched": _fact("scorched", id, 10000, -1, {"level": 650})}
	await _frames(40)
	out.append(await _stage(prefix, "burning 10 s", roots))
	for id in ids:
		_facts[id] = {"soaked": _fact("soaked", id, 0, 60000, {"method": "water"}),
			"scorched": _fact("scorched", id, 10000, -1, {"level": 650})}
	await _frames(12)
	out.append(await _stage(prefix, "doused", roots))
	for id in ids:
		_facts[id] = {"scorched": _fact("scorched", id, 10000, -1, {"level": 650})}
	await _frames(20)
	out.append(await _stage(prefix, "dry, scorched", roots))
	for id in ids:
		_facts[id]["struck"] = _fact("struck", id, 0, 700, {"force": 900, "n": 1, "from": [0.0, 0.0]})
	await _frames(2)
	out.append(await _stage(prefix, "struck", roots))
	for id in ids:
		_facts[id] = {"scorched": _fact("scorched", id, 10000, -1, {"level": 650}),
			"broken": _fact("broken", id, 0, -1, {"by": "blow"})}
	await _frames(20)
	out.append(await _stage(prefix, "broken", roots))
	_facts.clear()
	await _frames(20)
	out.append(await _stage(prefix, "repaired", roots))
	return out


func _to_night(main: Node) -> void:
	var day_night: Node = main.get_node("WorldEnvironment")
	var session: Node = root.get_node_or_null("VillageSession")
	var village = session.get("village") if session != null else null
	var now := int(village.runtime.now) if village != null else int(float(day_night.get("time_of_day")) * 1440.0)
	var to := (now - now % 1440) + 1350
	if to <= now:
		to += 1440
	day_night.call("skip", float(to - now) / 1440.0)
	await _frames(135)


## Where the row is on screen, for the boards' crop.
func _rect(roots: Array[Node3D], cam: Camera3D) -> Array:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for m in roots:
		for dy in [0.0, 1.8]:
			for dx in [-1.1, 1.1]:
				var p := cam.unproject_position(m.global_position + Vector3(dx, dy, 0.0))
				lo = lo.min(p)
				hi = hi.max(p)
	var rect := Rect2i(Vector2i(lo - Vector2(20, 40)), Vector2i(hi - lo + Vector2(40, 60)))
	rect = rect.intersection(Rect2i(Vector2i.ZERO, root.get_texture().get_image().get_size()))
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _ground(at: Vector3) -> Vector3:
	var space := (current_scene as Node3D).get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 30, 0), at - Vector3(0, 30, 0))
	var hit := space.intersect_ray(q)
	return hit.position if not hit.is_empty() else at


func _finish() -> void:
	_report["checks"] = _lines
	var f := FileAccess.open(_out + "/check.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(_report, "  "))
	f.close()
	print("CHECK complete: %d checks, %d failed" % [_lines.size(), _failed])
	quit(0 if _failed == 0 else 1)
