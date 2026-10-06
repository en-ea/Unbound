extends SceneTree
## Graphics S5's proof (studio plan GRAPHICS-STAGES-2026-10-04.md): the village's houses from the house grammar, in
## the real scene. Dev-only: nothing in the game calls it.
##
##   godot --rendering-driver opengl3 --fixed-fps 30 --path game --resolution 1560x720 \
##     --script res://scripts/studio/render/house_variety_check.gd -- --test-save=<fresh> --check-out=<absolute dir> \
##     [--studio-houses=off|preset|variety] --studio-batch=on --studio-merge=on   (none: the game's own setting)
##
## Off: nothing is attached. Preset or variety: the three houses the grammar has a style for (cottage, cabin, round
## house) are drawn from it; then, by day and at night, each house framed alone and the game's own view, drawn with
## his house, the grammar's, his again, in one paused frame (the batches stood down so the houses draw themselves),
## for toolbox/parity (preset: within noise; variety: the board); the batcher took the grammar's houses into its cells
## as it took his; the switch costs nothing a frame (no process) and its swap is timed.
## Prints CHECK PASS/FAIL lines and "CHECK complete: N checks, F failed"; writes captures and check.json.

const HOUSES := {"cottage": Vector2(-5.5, 11.5), "cabin": Vector2(10.5, 13.0), "round": Vector2(-9.0, 23.0)}
const TIMES := {"day": -1, "night": 1350}

var _out := ""
var _mode := ""
var _lines: PackedStringArray = []
var _failed := 0
var _report := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--check-out="):
			_out = arg.trim_prefix("--check-out=")
		elif arg.begins_with("--studio-houses="):
			_mode = arg.trim_prefix("--studio-houses=")
	if _out == "":
		print("CHECK REFUSE no --check-out=<absolute dir>")
		quit(3)
		return
	if _mode == "":                          # no argument: the game's own setting (preset when absent)
		_mode = str(load("res://scripts/studio/render/house_variety.gd").call("setting"))
	DirAccess.make_dir_recursive_absolute(_out)
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	var line := ("CHECK PASS " if ok else "CHECK FAIL ") + what
	print(line)
	_lines.append(line)
	if not ok:
		_failed += 1


func _run() -> void:
	for i in 240:
		await process_frame
		if current_scene != null and current_scene.name == "Main" and i > 150:
			break
	var main := current_scene
	var houses: Node = main.get_node_or_null("StudioHouses")
	if _mode not in ["preset", "variety"]:
		_check(houses == null, "switch off: nothing is attached (his houses, today's scene)")
		_finish()
		return
	_check(houses != null, "switch %s: attached by the S1 line in main.gd" % _mode)
	if houses == null:
		_finish()
		return
	var rep: Dictionary = houses.call("report")
	_report["houses"] = rep
	var models := {}
	for e: Array in houses.get("_swaps"):
		models[(e[0] as Node).get_parent().scene_file_path] = true
	_check(models.size() == 3, "every house of the three models the grammar has a style for (cottage, cabin, round house) is drawn from it: %d houses %s (swapped in %.1f ms as the region was built)" % [int(rep.swapped), str(rep.houses), float(rep.swap_ms)])
	_check(not houses.has_method("_process") and not houses.has_method("_physics_process"),
		"it costs nothing a frame: no process of its own (the swap happens once, as the region is built)")
	var batch: Node = main.get_node_or_null("StudioBatch")
	for _i in 300:
		if batch == null or bool(batch.call("report")["done"]):
			break
		await process_frame
	var members: Dictionary = batch.get("_members") if batch != null else {}
	# The batcher takes a house as it takes his: unless a part glows at the village's 1.5 (S1 carries glow 1.2 only).
	var agree := 0
	var batched := 0
	for e: Array in houses.get("_swaps"):
		var glows := false
		for m: ShaderMaterial in e[4]:
			glows = glows or float(m.get_shader_parameter("glow")) > 0.0
		var took := members.has((e[0] as Node).get_instance_id())
		batched += 1 if took else 0
		agree += 1 if took == (not glows) else 0
	_check(agree == (houses.get("_swaps") as Array).size(),
		"the batcher took the grammar's houses into its cells by the same rule as his (%d batched; the rest glow at 1.5, which S1 leaves to themselves as it leaves his)" % batched)
	_report["batched"] = batched

	var cam := Camera3D.new()
	main.add_child(cam)
	cam.fov = 45.0
	var rig_cam: Camera3D = main.get_viewport().get_camera_3d()
	var hud: CanvasLayer = main.get_node("HUD")
	var day_night: Node = main.get_node("WorldEnvironment")
	for t: String in TIMES:
		if int(TIMES[t]) >= 0:
			var session: Node = root.get_node_or_null("VillageSession")
			var village = session.get("village") if session != null else null
			var now := int(village.runtime.now) if village != null else int(float(day_night.get("time_of_day")) * 1440.0)
			var to := (now - now % 1440) + int(TIMES[t])
			if to <= now:
				to += 1440
			day_night.call("skip", float(to - now) / 1440.0)
			for _i in 135:
				await process_frame
		var views := {"game": null}
		for h: String in HOUSES:
			views[h] = HOUSES[h]
		for v: String in views:
			if views[v] == null:
				rig_cam.current = true
			else:
				var at: Vector2 = views[v]
				var ground := _ground(Vector3(at.x, 0.0, at.y))
				var look := ground + Vector3(0.0, 1.8, 0.0)
				cam.global_position = look + Vector3(6.5, 4.0, 12.5)
				cam.look_at(look)
				cam.current = true
			for _i in 20:
				await process_frame
			paused = true
			hud.visible = false
			if batch != null:
				batch.set("frozen", true)
				batch.call("show_originals", true)
			for step in [["his", true], ["grammar", false], ["his-again", true]]:
				houses.call("show_his", step[1])
				for _i in 3:
					await process_frame
				root.get_texture().get_image().save_png("%s/%s-%s-%s.png" % [_out, t, v, step[0]])
			houses.call("show_his", false)
			if batch != null:
				batch.call("show_originals", false)
				batch.set("frozen", false)
			hud.visible = true
			paused = false
	_finish()


func _ground(at: Vector3) -> Vector3:
	var space := (current_scene as Node3D).get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3(0, 40, 0), at - Vector3(0, 40, 0)))
	return hit.position if not hit.is_empty() else at


func _finish() -> void:
	_report["checks"] = _lines
	var f := FileAccess.open(_out + "/check.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(_report, "  "))
	f.close()
	print("CHECK complete: %d checks, %d failed" % [_lines.size(), _failed])
	quit(0 if _failed == 0 else 1)
