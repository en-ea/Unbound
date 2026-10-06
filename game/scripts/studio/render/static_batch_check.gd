extends SceneTree
## Graphics S1's proof (studio plan GRAPHICS-STAGES-2026-10-04.md): StaticBatch against the originals it hides, in the
## real scene, in place. Dev-only: nothing in the game calls it.
##
##   godot --rendering-driver opengl3 --fixed-fps 30 --path game --resolution 1560x720 \
##     --script res://scripts/studio/render/static_batch_check.gd -- --test-save=<fresh> --check-out=<absolute dir> \
##     --studio-batch=on --studio-merge=on
##
## Per time (morning, night with the lamps lit) and framing (explore, build45, low): the paused frame drawn with the
## originals, then with the batches, then with the originals again (the floor spans the batched capture in time), for
## toolbox/parity. Then, with the world running:
##   a member hidden by its own code leaves its batch at once and its cell re-merges without it;
##   shown again, it draws itself, outside any batch;
##   moved, it leaves in the same frame (before the frame is drawn);
##   freed, it leaves and its cell re-merges;
##   every cell meets at most 6 point, 6 spot and 1 shadowed light; the build's cost and size are reported.
## Prints CHECK PASS/FAIL lines and "CHECK complete: N checks, F failed"; writes captures and check.json.

const FRAMINGS := {"explore": [8.0, -10.0, 50.0], "build45": [18.0, -45.0, 32.0], "low": []}
const TIMES := {"morning": -1, "night": 1350}

var _out := ""
var _lines: PackedStringArray = []
var _failed := 0
var _report := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--check-out="):
			_out = arg.trim_prefix("--check-out=")
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


func _run() -> void:
	for i in 240:
		await process_frame
		if current_scene != null and current_scene.name == "Main" and i > 150:
			break
	var main := current_scene
	var batch: Node = main.get_node_or_null("StudioBatch")
	_check(batch != null, "the batcher is attached by main.gd's line")
	if batch == null:
		_finish()
		return
	for _i in 300:
		if bool(batch.call("report")["done"]):
			break
		await process_frame
	var rep: Dictionary = batch.call("report")
	_report["build"] = rep
	_check(bool(rep["done"]), "built: %d members (%d props, %d scatter multimeshes) in %d cells; gather %.1f ms in one frame, merging %.1f ms over frames, worst cell %.1f ms; %.2f MB of arrays" % [
		rep["members"], rep["props"], rep["scatter"], (rep["cells"] as Array).size(), rep["gather_ms"], rep["merge_ms"],
		rep["worst_cell_ms"], float(rep["bytes"]) / 1e6])
	_check(bool(rep["under_cover"]), "the one-frame gather ran while the game's loading cover still hid the scene")
	var worst := Vector3i.ZERO
	for c: Dictionary in rep["cells"]:
		worst = Vector3i(maxi(worst.x, c["lights"][0]), maxi(worst.y, c["lights"][1]), maxi(worst.z, c["lights"][2]))
	_check(worst.x <= 6 and worst.y <= 6 and worst.z <= 1, "lights per cell, lit or not, at most %d point, %d spot, %d shadowed (limits 6, 6, 1)" % [worst.x, worst.y, worst.z])

	# Parity in place.
	var rig: Node3D = main.get_node("CameraRig")
	var day_night: Node = main.get_node("WorldEnvironment")
	var session: Node = root.get_node_or_null("VillageSession")
	var hud: CanvasLayer = main.get_node("HUD")
	for t: String in TIMES:
		if int(TIMES[t]) >= 0:
			var village = session.get("village") if session != null else null
			var now := int(village.runtime.now) if village != null else int(float(day_night.get("time_of_day")) * 1440.0)
			var to := (now - now % 1440) + int(TIMES[t])
			if to <= now:
				to += 1440
			day_night.call("skip", float(to - now) / 1440.0)
			for _i in 135:
				await process_frame
		for f: String in FRAMINGS:
			paused = false
			var v: Array = FRAMINGS[f]
			if v.is_empty():
				rig.call("reset_view", 0.01)
			else:
				rig.call("set_view", v[0], v[1], Vector3.ZERO, 0.01, v[2])
			rig.call("snap")
			for _i in 45:
				await process_frame
			paused = true
			hud.visible = false
			batch.set("frozen", true)
			for step in [["originals", true], ["batched", false], ["originals-again", true]]:
				batch.call("show_originals", step[1])
				for _i in 3:
					await process_frame
				root.get_texture().get_image().save_png("%s/%s-%s-%s.png" % [_out, t, f, step[0]])
			batch.call("show_originals", false)
			batch.set("frozen", false)
			hud.visible = true
	paused = false

	# Self-healing, with the world running.
	var members: Dictionary = batch.get("_members")
	var props: Array = []
	for id: int in members:
		if not members[id]["multi"]:
			props.append(id)
	_check(props.size() >= 3, "three props to test with (%d batched)" % props.size())
	if props.size() >= 3:
		var hide_id: int = props[0]
		var hide_node: MeshInstance3D = members[hide_id]["node"]
		var cell: String = members[hide_id]["cell"]
		var before := _cell_vertices(batch, cell)
		hide_node.visible = false
		await process_frame
		var left := not (batch.get("_members") as Dictionary).has(hide_id) and hide_node.layers != 0
		for _i in 30:
			await process_frame
		var after := _cell_vertices(batch, cell)
		_check(left and after < before, "hidden by its own code: it leaves at once (layers back) and its cell re-merges without it (%d -> %d vertices)" % [before, after])
		hide_node.visible = true
		await process_frame
		_check(hide_node.is_visible_in_tree() and hide_node.layers != 0 and not (batch.get("_members") as Dictionary).has(hide_id),
			"shown again: it draws itself, outside any batch")
		var move_id: int = props[1]
		var move_node: MeshInstance3D = members[move_id]["node"]
		move_node.position += Vector3(0.5, 0.0, 0.0)
		await process_frame      # (this resumes before the frame's nodes run; the batcher runs last in it)
		await process_frame
		_check(move_node.layers != 0 and not (batch.get("_members") as Dictionary).has(move_id),
			"moved: the batcher, last in the frame, lets it go before the frame is drawn; it draws itself where it now is")
		var free_id: int = props[2]
		var free_node: MeshInstance3D = members[free_id]["node"]
		var free_cell: String = members[free_id]["cell"]
		var fb := _cell_vertices(batch, free_cell)
		free_node.queue_free()
		for _i in 30:
			await process_frame
		_check(not (batch.get("_members") as Dictionary).has(free_id) and _cell_vertices(batch, free_cell) < fb,
			"freed: it leaves and its cell re-merges without it")
	_finish()


func _cell_vertices(batch: Node, key: String) -> int:
	var cells: Dictionary = batch.get("_cells")
	if not cells.has(key) or cells[key]["mesh"] == null:
		return 0
	var mesh: Mesh = (cells[key]["mesh"] as MeshInstance3D).mesh
	var n := 0
	for i in mesh.get_surface_count():
		n += int(RenderingServer.mesh_get_surface(mesh.get_rid(), i).get("vertex_count", 0))
	return n


func _finish() -> void:
	_report["checks"] = _lines
	var f := FileAccess.open(_out + "/check.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(_report, "  "))
	f.close()
	print("CHECK complete: %d checks, %d failed" % [_lines.size(), _failed])
	quit(0 if _failed == 0 else 1)
