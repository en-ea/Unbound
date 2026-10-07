extends SceneTree
## Enea's seven as village bodies (Mind's port, sim/ported.gd; the desk's item of 6 Oct 06:26), proved in the live game
## with the port on. Dev-only: nothing in the game calls it.
##
##   godot --rendering-driver opengl3 --fixed-fps 30 --path game --resolution 1560x720 \
##     --script res://scripts/studio/render/his_seven_check.gd -- --test-save=<fresh> --check-out=<absolute dir> \
##     --port-residents=on
##
## Per one of his seven (tomas, elsa, nell, bram, tenant_odo, tenant_mira, tenant_fen), with no list of looks here:
##   the village body residents.gd made (a tenant whose house is not let is made by the same ensure() call) wears his
##   npcs.gd look exactly, every part and colour index, and his build (a child takes the village's child scale);
##   its mesh is one merged body, with as many surfaces as the trade look residents.gd gave before (draws do not grow);
##   his own npc.gd figure is hidden by the port and drawn by his own merge, so S2 never touches it.
## Board: per one of his seven, by day on a grass floor under the game's sky, both idle: his figure as his npc.gd draws
## it (his own merge on), his figure with its parts unmerged (his look as designed, as his picker and S2's checks draw
## it), and the village body (its look and scale): <id>.png. His merge (CharacterVisual.merge_parts) bakes each colour
## converted to linear, so his merged figures draw darker than his parts; the village body bakes them as stored
## (villager_body.gd, measured equal to his parts by body_compare.gd).
## The game's scripts are reached at run time, never named here: a --script runner that names a game class compiles it
## before the autoloads exist and breaks it for the launch.
## Prints CHECK PASS/FAIL lines and "CHECK complete: N checks, F failed"; writes check.json and the captures.

const SEVEN := ["tomas", "elsa", "nell", "bram", "tenant_odo", "tenant_mira", "tenant_fen"]
const AT := Vector3(0, -600, 0)

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
	for i in 300:
		await process_frame
		if current_scene != null and current_scene.name == "Main" and i > 200:
			break
	var main := current_scene
	var ported: GDScript = load("res://scripts/studio/village/sim/ported.gd")
	var npcs: GDScript = load("res://scripts/state/npcs.gd")
	var body_script: GDScript = load("res://scripts/studio/village/villager_body.gd")
	var talk: GDScript = load("res://scripts/studio/village/resident_talk.gd")
	var defs: Dictionary = npcs.get_script_constant_map()["NPCS"]
	var session: Node = root.get_node_or_null("VillageSession")
	var v = session.get("village") if session != null else null
	_check(bool(ported.call("enabled")) and v != null, "the port is on (--port-residents=on) and the village is live")
	if v == null:
		_finish()
		return
	var registry: Node = load("res://scripts/studio/village/contact.gd").call("registry", self)
	var his_nodes := {}
	for n in root.find_children("*", "Node3D", true, false):
		var s: Script = n.get_script()
		if s != null and s.resource_path == "res://scripts/world/npc.gd" and str(n.get("_id")) in SEVEN:
			his_nodes[str(n.get("_id"))] = n
	var made := {}
	for id: String in SEVEN:
		var pid: int = ported.call("person_of", v, id)
		var row := {"person": pid}
		_report[id] = row
		if pid < 0 or registry == null:
			_check(false, "%s has joined the village (person %d)" % [id, pid])
			continue
		var body: Node3D = registry.get("bodies").get(pid)
		row["made_now"] = body == null
		if body == null:                 # (a tenant whose house is not let: no body yet; the game's own call makes it)
			body = registry.call("ensure", {"id": pid})
		made[id] = body
		var want: Dictionary = defs[id]["look"]
		var look: Object = body.get("hero_look")
		var wrong := []
		for slot: String in want["parts"]:
			if str(look.get("parts").get(slot)) != str(want["parts"][slot]):
				wrong.append("%s %s not %s" % [slot, look.get("parts").get(slot), want["parts"][slot]])
		for slot: String in want["colors"]:
			if int(look.get("colors").get(slot, -1)) != int(want["colors"][slot]):
				wrong.append("%s colour %s not %s" % [slot, look.get("colors").get(slot), want["colors"][slot]])
		var child := float(defs[id]["scale"].y) < 0.8
		var scale_ok: bool = body.scale.is_equal_approx(Vector3.ONE * 0.68) if child else body.scale.is_equal_approx(defs[id]["scale"])
		row["wrong"] = wrong
		row["scale"] = [body.scale.x, body.scale.y, body.scale.z]
		_check(wrong.is_empty() and scale_ok, "%s (person %d%s): the village body wears his look, %d parts and %d colours as he drew them, and %s%s" % [
			id, pid, ", made by ensure() now: not present" if row["made_now"] else "", (want["parts"] as Dictionary).size(),
			(want["colors"] as Dictionary).size(), "the village's child scale 0.68 (his is %.2f)" % float(defs[id]["scale"].y) if child else "his build %s" % str(defs[id]["scale"]),
			"" if wrong.is_empty() else ": " + ", ".join(wrong)])
		# Draws: his look against the trade look residents.gd gave before, each as one merged body.
		var his_surfaces := _surfaces(body)
		var trade := body_script.new() as Node3D
		trade.set("hero_look", talk.call("look_of", v, pid))
		trade.set("is_player_look", false)
		main.add_child(trade)
		trade.global_position = AT + Vector3(40, 0, 0)
		await process_frame
		var trade_surfaces := _surfaces(trade)
		trade.queue_free()
		row["surfaces"] = [his_surfaces, trade_surfaces]
		_check(his_surfaces >= 1 and his_surfaces <= trade_surfaces + 1 and his_surfaces <= 2,
			"%s: one merged body of %d surface(s) (the trade look: %d); its draws are its surfaces, plus its shadow" % [id, his_surfaces, trade_surfaces])
		var his: Node3D = his_nodes.get(id)
		if his != null:
			var visual: Node = his.get("_visual")
			var merged_by_s2: bool = visual != null and visual.get_node_or_null("StudioMerge") != null and visual.get_node("StudioMerge").get("merged") != null
			row["his_node"] = {"visible": his.visible, "his_merge": visual != null and visual.get("_merged") == true, "s2": merged_by_s2}
			_check(not his.is_visible_in_tree() and visual != null and visual.get("merge") == true and not merged_by_s2,
				"%s: his npc.gd figure is hidden by the port and joined by his own merge; S2 never merged it" % id)
		else:
			row["his_node"] = "none in the meadow (a tenant lives in his letting)"

	# The board: his figure beside the village body.
	(main.get_node("HUD") as CanvasLayer).visible = false
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
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
	for id: String in SEVEN:
		if not made.has(id):
			continue
		var figure: Node3D = npcs.call("make_visual", id)
		figure.set("merge", true)
		main.add_child(figure)
		npcs.call("dress_visual", id, figure, false, true)
		figure.global_position = AT + Vector3(-1.3, 0, 0)
		var parts: Node3D = npcs.call("make_visual", id)
		main.add_child(parts)
		npcs.call("dress_visual", id, parts, false, true)
		parts.global_position = AT
		var copy := body_script.new() as Node3D
		copy.set("hero_look", made[id].get("hero_look"))
		copy.set("is_player_look", false)
		copy.scale = made[id].scale
		main.add_child(copy)
		copy.global_position = AT + Vector3(1.3, 0, 0)
		for _i in 3:
			await process_frame
		figure.call("play_motion", 0.0)
		parts.call("play_motion", 0.0)
		copy.call("play_motion", 0.0)
		var tall := maxf(float(figure.scale.y), float(copy.scale.y))
		var look_at := AT + Vector3(0, 0.95 * tall, 0)
		cam.global_position = look_at + Vector3(0, 0.25 * tall, 5.6 * maxf(tall, 0.75))
		cam.look_at(look_at)
		for _i in 30:
			await process_frame
		var img := root.get_texture().get_image()
		var wide := int(img.get_height() * 1.5)
		img = img.get_region(Rect2i((img.get_width() - wide) / 2, 0, wide, img.get_height()))
		img.save_png("%s/%s.png" % [_out, id])
		print("BOARD %s" % id)
		figure.queue_free()
		parts.queue_free()
		copy.queue_free()
		await process_frame
	_finish()


## Surfaces of a village body's merged mesh (each is a draw; its shadow doubles them).
func _surfaces(body: Node3D) -> int:
	var n := 0
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).mesh != null and (mi as MeshInstance3D).visible and (mi as MeshInstance3D).skin != null:
			n += (mi as MeshInstance3D).mesh.get_surface_count()
	return n


func _finish() -> void:
	_report["checks"] = _lines
	var f := FileAccess.open(_out + "/check.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(_report, "  "))
	f.close()
	print("CHECK complete: %d checks, %d failed" % [_lines.size(), _failed])
	quit(0 if _failed == 0 else 1)
