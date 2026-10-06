extends SceneTree
## Graphics S5's look board (studio plan GRAPHICS-STAGES-2026-10-04.md): houses and stalls made by the grammar
## (tools-src/studio/blender/house_grammar.py), each drawn alone on a grass floor under the game's own sky and sun,
## by day and at night, from one camera, for toolbox/lookboard/phone_board.py. Dev-only: nothing in the game calls it.
## The models are read from a folder at run time (no import), drawn as the village draws its houses (his solid
## shader, glowing parts at 1.5).
##
##   godot --rendering-driver opengl3 --fixed-fps 30 --path game --resolution 1560x720 \
##     --script res://scripts/studio/render/house_board.gd -- --test-save=<fresh> --board-in=<glb dir> \
##     --board-out=<dir> --board-list=house_cottage,timber_1,...
## Writes <name>-day.png and <name>-night.png (the middle of the frame, square), prints BOARD lines.

const SOLID := preload("res://shaders/foliage_solid.gdshader")
const AT := Vector3(0, -600, 0)

var _in := ""
var _out := ""
var _list: PackedStringArray = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--board-in="):
			_in = arg.trim_prefix("--board-in=")
		elif arg.begins_with("--board-out="):
			_out = arg.trim_prefix("--board-out=")
		elif arg.begins_with("--board-list="):
			_list = arg.trim_prefix("--board-list=").split(",", false)
	if _in == "" or _out == "" or _list.is_empty():
		print("BOARD REFUSE need --board-in, --board-out, --board-list")
		quit(3)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _run() -> void:
	for i in 240:
		await process_frame
		if current_scene != null and current_scene.name == "Main" and i > 150:
			break
	var main := current_scene
	(main.get_node("HUD") as CanvasLayer).visible = false
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	floor.mesh = plane
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color(0.33, 0.52, 0.22)
	grass.roughness = 1.0
	floor.material_override = grass
	main.add_child(floor)
	floor.global_position = AT
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.fov = 40.0
	cam.current = true
	var shown: Array[Node3D] = []
	for t in ["day", "night"]:
		if t == "night":
			await _to_night(main)
		for name in _list:
			var house := _load(_in.path_join(name + ".glb"))
			if house == null:
				print("BOARD FAIL missing ", name)
				continue
			main.add_child(house)
			house.global_position = AT
			var box := _bounds(house)
			var size := maxf(box.size.x, maxf(box.size.y * 1.4, box.size.z))
			var look := AT + Vector3(box.get_center().x, box.size.y * 0.42, box.get_center().z)
			cam.global_position = look + Vector3(0.55, 0.32, 1.0).normalized() * size * 2.1
			cam.look_at(look)
			for _i in 4:
				await process_frame
			var img := root.get_texture().get_image()
			var side := img.get_height()
			img = img.get_region(Rect2i((img.get_width() - side) / 2, 0, side, side))
			img.save_png("%s/%s-%s.png" % [_out, name, t])
			print("BOARD %s %s size %.1f x %.1f x %.1f" % [name, t, box.size.x, box.size.y, box.size.z])
			house.queue_free()
			await process_frame
	print("BOARD complete")
	quit(0)


func _load(path: String) -> Node3D:
	if not FileAccess.file_exists(path):
		return null
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		return null
	var node := doc.generate_scene(state) as Node3D
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			var mat := ShaderMaterial.new()
			mat.shader = SOLID
			mat.set_shader_parameter("albedo", Color.WHITE)
			mat.set_shader_parameter("sway", 0.0)
			mat.set_shader_parameter("glow", 1.5 if src and src.resource_name == "Glow" else 0.0)
			mi.set_surface_override_material(s, mat)
	return node


func _bounds(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = n.global_transform.affine_inverse() * mi.global_transform * mi.mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
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
	for _i in 135:
		await process_frame
