extends SceneTree
## Graphics S2's proof (studio plan GRAPHICS-STAGES-2026-10-04.md): CharacterMerge against Enea's own parts, in the
## real scene, with the world paused. Dev-only: nothing in the game calls it.
##
##   godot --rendering-driver opengl3 --fixed-fps 30 --path game --resolution 1560x720 \
##     --script res://scripts/studio/render/character_merge_check.gd -- --test-save=s2 --check-out=<absolute dir> \
##     --studio-merge=off
##
## With --studio-merge=off nothing merges by itself, so the scene starts exactly as today; the check then merges its
## subjects with CharacterMerge.merge (the call after_look makes) and compares them both ways in the same frame:
##   subjects: the player (the default look), five random looks (seeds 1-5), Wren, Morrow, Brakk and Moss-Cap in a row;
##   poses: idle at 0.5 s and mid-swing (Sword_Regular_C at half its length), every subject in the same frame;
##   captures per pose, HUD hidden: unmerged, merged, unmerged again (the noise floor spans the merged capture);
##   draws: the row's 3D draws both ways, and each subject's own (hidden alone, both ways);
##   gate per subject: at most 2 merged surfaces, tools still their own nodes, and the skinned vertices merged equal
##   the vertices of the parts shown (skinning work unchanged);
##   flash: one subject's hit flash reaches its merged body and no other;
##   live change: a subject's look changed and applied again re-merges to the new look;
##   switch off: no merged node exists anywhere before the check merges.
## Prints CHECK PASS/FAIL lines and "CHECK complete: N checks, F failed"; writes the captures and check.json.
## Exit 0 when nothing failed.

const SPOT := Vector2(-6.0, 44.0)        # the row's middle: open meadow north of the village, clear of buildings
const GAP := 1.35                        # metres between subjects
const NPCS := ["wren", "morrow", "brakk", "seeker"]
const SWING := "Sword_Regular_C"

var _out := ""
var _lines: PackedStringArray = []
var _failed := 0
var _report := {"subjects": [], "draws": {}, "parity_inputs": []}


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
	if main == null or main.name != "Main":
		print("CHECK FAIL the main scene never came up")
		quit(3)
		return
	# Game classes are loaded here, not named: a --script runner compiles before the autoloads exist, and his
	# scripts name them (Gear, Inventory, Region).
	var CM: GDScript = load("res://scripts/studio/render/character_merge.gd")
	var CV: GDScript = load("res://scripts/player/character_visual.gd")
	var Look: GDScript = load("res://scripts/player/character_look.gd")
	var NpcDefs: GDScript = load("res://scripts/state/npcs.gd")
	_check(not CM.enabled(), "launched with the switch off (--studio-merge=off)")
	_check(_merged_nodes().is_empty(), "switch off: no merged body anywhere in the scene (%d CharacterVisuals as Enea builds them)" % _visuals().size())

	# The row: the player and nine more, each as the game builds it.
	var player: Node3D = main.get_node("Player")
	var shape: RefCounted = load("res://scripts/world/world_shape.gd").new()
	player.global_position = Vector3(SPOT.x, shape.call("height_at", SPOT.x, SPOT.y) + 0.3, SPOT.y)
	var subjects: Array = [{"name": "player (default look)", "visual": player.get("visual")}]
	for seed in range(1, 6):
		var v: Node3D = CV.new()
		var look: RefCounted = Look.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		look.call("randomize_look", rng)
		v.set("hero_look", look)
		v.set("is_player_look", true)
		main.add_child(v)
		subjects.append({"name": "random look %d" % seed, "visual": v})
	for id in NPCS:
		var v: Node3D = NpcDefs.make_visual(id)
		main.add_child(v)
		NpcDefs.dress_visual(id, v, false, true)
		subjects.append({"name": "%s (%s)" % [NpcDefs.NPCS[id]["name"], "ready-made body" if v.get("body_model") != "" else "hero"], "visual": v})
	# The player in the middle of the row (the camera follows him), the others either side, all facing the camera
	# (it looks north from the south; a body faces +Z, south, unturned).
	var count := subjects.size()
	var middle := count / 2
	var order: Array = subjects.slice(1)
	order.insert(middle, subjects[0])
	subjects = order
	for i in count:
		var v: Node3D = subjects[i]["visual"]
		if v == player.get("visual"):
			continue
		var x := SPOT.x + (i - middle) * GAP
		v.global_position = Vector3(x, shape.call("height_at", x, SPOT.y), SPOT.y)
		v.rotation.y = 0.0
	var rig: Node3D = main.get_node("CameraRig")
	if rig.get_method_argument_count("set_view") >= 5:
		rig.set_view(9.5, -9.0, Vector3.ZERO, 0.01, 50.0)
	else:
		rig.set_view(9.5, -9.0, Vector3.ZERO, 0.01)
	for _i in 45:
		await process_frame
	(player.get("visual") as Node3D).rotation.y = 0.0
	rig.call("snap")
	paused = true
	var hud: CanvasLayer = main.get_node("HUD")
	hud.visible = false

	# Unmerged per-subject draws, then merge everything at once, as after_look would.
	await _pose(subjects, "Idle", 0.5)
	var before := await _per_subject(subjects)
	var row_before := await _draws3d()
	for s: Dictionary in subjects:
		CM.merge(s["visual"])
	await process_frame      # the deferred merge
	await process_frame
	var after := await _per_subject(subjects)
	var row_after := await _draws3d()
	_report["draws"] = {"row_unmerged": row_before, "row_merged": row_after}
	_check(row_after < row_before, "the row draws %d 3D calls merged against %d unmerged (%d subjects)" % [row_after, row_before, count])
	for i in count:
		var s: Dictionary = subjects[i]
		var v: Node3D = s["visual"]
		var m: Node = v.get_node_or_null("StudioMerge")
		var entry := {"name": s["name"], "draws_unmerged": before[i], "draws_merged": after[i]}
		if m == null or m.get("merged") == null:
			_check(false, "%s: merged" % s["name"])
			_report["subjects"].append(entry)
			continue
		var mesh: ArrayMesh = (m.get("merged") as MeshInstance3D).mesh
		var shown: Array = m.call("shown_parts")
		var verts := 0
		for mi: MeshInstance3D in shown:
			for k in mi.mesh.get_surface_count():
				verts += (mi.mesh.surface_get_arrays(k)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var merged_verts := 0
		for k in mesh.get_surface_count():
			merged_verts += (mesh.surface_get_arrays(k)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var tools := 0
		for mi: MeshInstance3D in v.find_children("*", "MeshInstance3D", true, false):
			if mi.is_visible_in_tree() and mi != m.get("merged") and not mi in shown:
				tools += 1
		entry.merge({"parts_shown": shown.size(), "surfaces": mesh.get_surface_count(), "vertices_parts": verts,
			"vertices_merged": merged_verts, "other_meshes": tools})
		_report["subjects"].append(entry)
		_check(mesh.get_surface_count() <= 2, "%s: %d parts drawn as %d surface(s), plus %d other meshes (tools, props); draws %d -> %d" % [
			s["name"], shown.size(), mesh.get_surface_count(), tools, before[i], after[i]])
		_check(verts == merged_verts, "%s: skinned vertices unchanged (%d in the parts shown, %d merged)" % [s["name"], verts, merged_verts])

	# The row's box on screen, for parity judged on the characters alone (box.txt: x,y,w,h).
	var cam: Camera3D = root.get_camera_3d()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for s: Dictionary in subjects:
		var v: Node3D = s["visual"]
		var k := v.global_basis.get_scale()
		for c in [Vector3(-0.8, 0.0, -0.6), Vector3(0.8, 0.0, 0.6), Vector3(-0.8, 2.3, 0.6), Vector3(0.8, 2.3, -0.6)]:
			var p := cam.unproject_position(v.global_position + Vector3(c.x * k.x, c.y * k.y, c.z * k.z))
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var box := Rect2i(Vector2i(lo) - Vector2i(12, 12), Vector2i(hi - lo) + Vector2i(24, 24)).intersection(Rect2i(Vector2i.ZERO, root.size))
	_report["box"] = [box.position.x, box.position.y, box.size.x, box.size.y]
	var bf := FileAccess.open(_out + "/box.txt", FileAccess.WRITE)
	bf.store_string("%d,%d,%d,%d" % [box.position.x, box.position.y, box.size.x, box.size.y])
	bf.close()

	# Parity, both poses: unmerged, merged, unmerged again, in the same paused frame.
	for pose in [["idle", "Idle", 0.5], ["swing", SWING, -0.5]]:
		await _pose(subjects, pose[1], pose[2])
		await _shot(subjects, true, "%s-unmerged.png" % pose[0])
		await _shot(subjects, false, "%s-merged.png" % pose[0])
		await _shot(subjects, true, "%s-unmerged-again.png" % pose[0])
		_report["parity_inputs"].append(pose[0])

	# The hit flash: one subject's own copies, nobody else's.
	var hit: Node3D = subjects[1]["visual"]
	var other: Node3D = subjects[2]["visual"]
	paused = false
	hit.call("flash")
	await process_frame
	await process_frame
	var hm: MeshInstance3D = hit.get_node("StudioMerge").get("merged")
	var om: MeshInstance3D = other.get_node("StudioMerge").get("merged")
	var hit_flash = hm.get_surface_override_material(0).get_shader_parameter("flash") if hm.get_surface_override_material(0) != null else 0.0
	var shared_flash = hm.mesh.surface_get_material(0).get_shader_parameter("flash")
	_check(hit_flash != null and float(hit_flash) > 0.0 and om.get_surface_override_material(0) == null \
		and (shared_flash == null or float(shared_flash) == 0.0),
		"flash: the struck body flashes on its own material (%.2f); the shared material and the next body stay unlit" % float(hit_flash if hit_flash != null else 0.0))
	for _i in 20:
		await process_frame
	_check(hm.get_surface_override_material(0) == null, "flash: over, the body is back on the shared material")
	paused = true

	# A live look change, as the look picker makes one: change, apply, and the body re-merges to the new look.
	var live: Node3D = subjects[1]["visual"]
	var old_mesh: Mesh = (live.get_node("StudioMerge").get("merged") as MeshInstance3D).mesh
	var lk: RefCounted = live.get("hero_look")
	lk.get("parts")["head"] = "hood" if lk.get("parts").get("head", "") != "hood" else "none"
	lk.get("colors")["Main"] = (int(lk.get("colors").get("Main", 0)) + 3) % (Look.PALETTES["Main"] as Array).size()
	live.call("apply_hero_look")
	CM.merge(live)           # what after_look does when the switch is on (the wired line calls it inside apply_hero_look)
	await process_frame
	await process_frame
	var lm: Node = live.get_node("StudioMerge")
	var parts_on := 0
	for mi: MeshInstance3D in live.get("_parts"):
		if mi.visible:
			parts_on += 1
	_check((lm.get("merged") as MeshInstance3D).mesh != old_mesh and parts_on == 0,
		"live change: a new merged body for the new look, and none of his parts left on (%d)" % parts_on)
	await _pose(subjects, "Idle", 0.5)
	await _shot(subjects, true, "live-unmerged.png")
	await _shot(subjects, false, "live-merged.png")
	await _shot(subjects, true, "live-unmerged-again.png")
	_report["parity_inputs"].append("live")

	_report["checks"] = _lines
	var f := FileAccess.open(_out + "/check.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(_report, "  "))
	f.close()
	print("CHECK complete: %d checks, %d failed" % [_lines.size(), _failed])
	quit(0 if _failed == 0 else 1)


func _visuals() -> Array:
	var out := []
	for n in root.find_children("*", "Node3D", true, false):
		if n.get_script() != null and (n.get_script() as Script).resource_path.ends_with("character_visual.gd"):
			out.append(n)
	return out


func _merged_nodes() -> Array:
	return root.find_children("StudioMerged", "MeshInstance3D", true, false)


## Every subject in the same frame of the same clip (negative at: that fraction of the clip's length).
func _pose(subjects: Array, clip: String, at: float) -> void:
	for s: Dictionary in subjects:
		var v: Node3D = s["visual"]
		var ap: AnimationPlayer = v.find_children("*", "AnimationPlayer", true, false)[0]
		var t := at if at >= 0.0 else ap.get_animation(clip).length * -at
		ap.play(clip)
		ap.seek(t, true)
		ap.pause()
	for _i in 3:
		await process_frame


func _draws3d() -> int:
	for _i in 3:
		await process_frame
	return root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME) \
		+ root.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)


## Each subject's own draws: the drop when it alone is hidden.
func _per_subject(subjects: Array) -> Array:
	var base := await _draws3d()
	var out := []
	for s: Dictionary in subjects:
		var v: Node3D = s["visual"]
		v.visible = false
		out.append(base - await _draws3d())
		v.visible = true
	return out


## A capture of the row, every subject drawn unmerged (his parts) or merged.
func _shot(subjects: Array, unmerged: bool, file: String) -> void:
	for s: Dictionary in subjects:
		var m: Node = (s["visual"] as Node3D).get_node_or_null("StudioMerge")
		if m != null:
			m.call("show_parts", unmerged)
	for _i in 3:
		await process_frame
	root.get_texture().get_image().save_png(_out + "/" + file)
