extends SceneTree
## Graphics S6's gate (studio plan GRAPHICS-STAGES-2026-10-04.md; the desk's unit G-M, 6 Oct): in one region a launch,
## at the build's own settings (no switch arguments: characters merged, still meshes batched, things on, houses on
## preset), every graphics stage against Enea's own drawing of the same paused frame, in place. Dev-only: nothing in the
## game calls it.
##
##   godot --rendering-driver opengl3 --fixed-fps 30 --path game --resolution 1560x720 \
##     --script res://scripts/studio/render/graphics_gate_check.gd -- --test-save=<fresh> --check-out=<absolute dir> \
##     [--check-region=forest|highlands [--check-cave]] [--check-at=x,z] [--check-yaw=<deg>] [--check-class=<id>]
##
## --check-class=shade also steps his Mirage doubles out ahead of the player (one in shadow, one a perfect likeness).
##
## Per time (morning, night with the lamps lit) and framing (explore, build45, low) the paused frame is drawn as his
## (every stage showing his own drawing), then each stage alone (s1 batches, s2 merged characters, s4 things, s5 houses),
## then all of them, then his again (the floor spans the rest in time), for toolbox/parity; each capture's draw calls are
## read too (the HUD hidden). A stage with nothing here is not drawn alone. s1 alone draws the houses it batched from the
## grammar's preset, the same model as his.
## Then, by scan, with no list of characters or props:
##   every visible CharacterVisual is drawn by exactly one merge path, his own (CharacterVisual.merge) or S2's;
##   models built from rigid parts (assets/creatures/), with their meshes: in no merge path;
##   the things found (S4) by kind; the drawing's carriers against Body's (village/things.gd, where the line has it);
##   every other model of his standing here, by count, for the carriers decision; the houses the grammar draws (S5).
## Prints CHECK PASS/FAIL lines and "CHECK complete: N checks, F failed"; writes captures, census.txt and check.json.

const FRAMINGS := {"explore": [8.0, -10.0, 50.0], "build45": [18.0, -45.0, 32.0], "low": []}
const TIMES := {"morning": -1, "night": 1350}
const BODY_THINGS := "res://scripts/studio/village/things.gd"
## The stages' scripts, loaded once the game is up: a --script runner that names a game class compiles it before the
## autoloads exist, and that breaks the class for the whole launch (CharacterVisual needs Gear).
const BATCH := "res://scripts/studio/render/static_batch.gd"
const THINGS := "res://scripts/studio/render/thing_state.gd"
const HOUSES := "res://scripts/studio/render/house_variety.gd"
const MERGE := "res://scripts/studio/render/character_merge.gd"

var _out := ""
var _cave := false
var _at := Vector2.INF
var _yaw := 0.0
var _class := ""
var _lines: PackedStringArray = []
var _failed := 0
var _report := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--check-out="):
			_out = arg.trim_prefix("--check-out=")
		elif arg == "--check-cave":
			_cave = true
		elif arg.begins_with("--check-at="):
			var xz := arg.trim_prefix("--check-at=").split(",")
			_at = Vector2(float(xz[0]), float(xz[1]))
		elif arg.begins_with("--check-yaw="):
			_yaw = deg_to_rad(float(arg.trim_prefix("--check-yaw=")))
		elif arg.begins_with("--check-class="):
			_class = arg.trim_prefix("--check-class=")
		elif arg.begins_with("--check-region="):
			# Arrive as through the gate (Region.travel's own state), as the draw probe does: with a test save the game
			# reads the region from the save, so a fresh test save always starts in the meadow.
			var region := root.get_node("Region")
			var to := arg.trim_prefix("--check-region=")
			for from: String in region.get("GATES"):
				for g: Dictionary in region.get("GATES")[from]:
					if g["to"] == to:
						region.set("current", to)
						region.set("arrive", g["arrive"])
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
		_check(false, "the main scene came up")
		_finish()
		return
	var rig: Node3D = main.get_node("CameraRig")
	var day_night: Node = main.get_node("WorldEnvironment")
	if _class != "":
		root.get_node("Classes").call("choose", _class)     # (his own call, as the shrine's choice makes it)
		for _i in 60:
			await process_frame
	if _class == "shade":
		# His Mirage without the fight: the doubles his Shade builds ahead step out ahead of the player, one in shadow
		# and one a perfect likeness (ShadowDouble.appear, his own call), so the frames and the census hold them.
		var player: Node3D = main.get_node("Player")
		var side := 1.6
		var perfect := false
		for d in root.find_children("*", "CharacterBody3D", true, false):
			var s: Script = d.get_script()
			if s != null and s.get_global_name() == "ShadowDouble":
				d.call("appear", player.global_position + Vector3(side, 0.0, -1.5), 0.0, 600.0, 99, perfect)
				_report["doubles"] = int(_report.get("doubles", 0)) + 1
				side = -side
				perfect = not perfect
		for _i in 30:
			await process_frame
	if _cave:
		var cave := get_first_node_in_group("cave")
		if cave == null:
			_check(false, "Glimmerdeep is here (it is under the forest: --check-region=forest)")
			_finish()
			return
		cave.call("enter")
		rig.call("snap")
		for _i in 150:
			await process_frame
	if _at != Vector2.INF:
		var player: Node3D = main.get_node("Player")
		var shape: RefCounted = load("res://scripts/world/world_shape.gd").new()
		player.global_position = Vector3(_at.x, float(shape.call("height_at", _at.x, _at.y)) + 0.3, _at.y)
		rig.call("snap")
		for _i in 90:
			await process_frame
	var region: Node = root.get_node_or_null("Region")
	_report["region"] = (str(region.get("current")) if region != null else "meadow") + (" (Glimmerdeep)" if _cave else "")
	_report["class"] = _class

	# The stages, as the build attaches them.
	var batch: Node = main.get_node_or_null("StudioBatch")
	var things: Node = main.get_node_or_null("StudioThings")
	var houses: Node = main.get_node_or_null("StudioHouses")
	if batch != null:
		for _i in 300:
			if bool(batch.call("report")["done"]):
				break
			await process_frame
	var house_setting := str(load(HOUSES).call("setting"))
	_check((batch != null) == bool(load(BATCH).call("enabled")) and (things != null) == bool(load(THINGS).call("enabled"))
		and (houses != null) == (house_setting in ["preset", "variety"]),
		"the stages are attached as the build's settings have them: batching %s, things %s, houses %s" % [
		batch != null, things != null, house_setting if houses != null else "off"])
	if batch != null:
		var b: Dictionary = batch.call("report")
		_report["batch"] = {"members": b["members"], "props": b["props"], "scatter": b["scatter"],
			"cells": (b["cells"] as Array).size(), "gather_ms": b["gather_ms"], "merge_ms": b["merge_ms"],
			"mb": float(b["bytes"]) / 1e6, "under_cover": b["under_cover"], "done": b["done"]}
		_check(bool(b["done"]), "batched: %d members in %d cells, gather %.1f ms, merging %.1f ms, %.2f MB" % [
			b["members"], (b["cells"] as Array).size(), b["gather_ms"], b["merge_ms"], float(b["bytes"]) / 1e6])
		# His creatures are rigid parts his code moves (assets/creatures/): one held still in a batch would leave it at
		# its first step and its cell re-merge, so none should be in one.
		var held := []
		var members: Dictionary = batch.get("_members")
		for id: int in members:
			var a: Node = members[id]["node"]
			while a != null and a != main:
				if a.scene_file_path.begins_with("res://assets/creatures/"):
					held.append(a.scene_file_path.get_file())
					break
				a = a.get_parent()
		_report["creature_parts_batched"] = held.size()
		_check(held.is_empty(), "no part of his creatures (rigid parts his code moves) is held in a batch%s" % (
			"" if held.is_empty() else ": %d (%s)" % [held.size(), ", ".join(held)]))
	if things != null:
		_report["things"] = things.call("report")
	if houses != null:
		_report["houses"] = houses.call("report")

	_census(main, things)

	# Parity in place: his, each stage alone, all, his again.
	var hud: CanvasLayer = main.get_node("HUD")
	var session: Node = root.get_node_or_null("VillageSession")
	var draws := {}
	var steps_used := []
	var never_more := true
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
			if _yaw != 0.0:
				rig.call("_set_yaw", _yaw)
			rig.call("snap")
			for _i in 45:
				await process_frame
			var merges := _merges()
			var alone := []
			if batch != null and int(batch.call("report")["members"]) > 0:
				alone.append("s1")
			if not merges.is_empty():
				alone.append("s2")
			if things != null and int(things.call("report")["things"]) > 0:
				alone.append("s4")
			if houses != null and int(houses.call("report")["swapped"]) > 0:
				alone.append("s5")
			var steps := [["his", []]]
			for s: String in alone:
				steps.append([s, [s]])
			if alone.size() > 1:
				steps.append(["all", alone])
			steps.append(["his-again", []])
			paused = true
			hud.visible = false
			if batch != null:
				batch.set("frozen", true)
			if things != null:
				things.set("frozen", true)
			var view := "%s-%s" % [t, f]
			draws[view] = {}
			for step: Array in steps:
				_show(batch, merges, things, houses, step[1])
				for _i in 3:
					await process_frame
				draws[view][step[0]] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
				root.get_texture().get_image().save_png("%s/%s-%s.png" % [_out, view, step[0]])
				if not steps_used.has(step[0]):
					steps_used.append(step[0])
			_show(batch, merges, things, houses, alone)     # back to the build
			if batch != null:
				batch.set("frozen", false)
			if things != null:
				things.set("frozen", false)
			hud.visible = true
			var last: String = steps[-2][0]
			if int(draws[view][last]) > int(draws[view]["his"]):
				never_more = false
			print("GATE %s draws %s" % [view, JSON.stringify(draws[view])])
	paused = false
	_report["draws"] = draws
	_report["steps"] = steps_used
	_check(never_more, "in every view the build draws no more than his frame (draw calls, HUD hidden: %s)" % _draws_line(draws))
	_finish()


## Every stage showing his own drawing (none in on) or its own (its name in on: s1, s2, s4, s5), in place.
func _show(batch: Node, merges: Array, things: Node, houses: Node, on: Array) -> void:
	if batch != null:
		batch.call("show_originals", not on.has("s1"))
	for m: Node in merges:
		if is_instance_valid(m):
			m.call("show_parts", not on.has("s2"))
	if things != null:
		things.call("show_originals", not on.has("s4"))
	if houses != null:
		houses.call("show_his", not on.has("s5"))


## S2's adapters standing now that drew a merged body.
func _merges() -> Array:
	var out := []
	for n in root.find_children("StudioMerge", "", true, false):
		if n.get_script() == load(MERGE) and n.get("merged") != null:
			out.append(n)
	return out


func _draws_line(draws: Dictionary) -> String:
	var parts := []
	for view: String in draws:
		var d: Dictionary = draws[view]
		parts.append("%s %d -> %d" % [view, d["his"], d.get("all", d.get(str(d.keys()[1]), d["his"]))])
	return ", ".join(parts)


## The census, by scan: merge paths, rigid-part models, things and his other models here.
func _census(main: Node, things: Node) -> void:
	var visuals: Array = []
	var models := {}                 # his model -> how many stand here
	var creatures := {}              # rigid-part model -> [standing, meshes each]
	_walk(root, visuals, models, creatures)
	var rows: PackedStringArray = []
	var paths := {"his": 0, "s2": 0, "both": 0, "his pending": 0, "none": 0}
	var odd: PackedStringArray = []
	for v: Node3D in visuals:
		if not v.is_visible_in_tree():
			rows.append("character %s: hidden" % v.get_parent().name)
			continue
		var his: bool = v.get("_merged") == true
		var pending: bool = v.get("merge") == true and not his
		var m := v.get_node_or_null("StudioMerge")
		var body: Node3D = m.get("merged") if m != null else null
		var s2 := body != null and body.visible
		var path := "both" if his and s2 else ("his" if his else ("his pending" if pending else ("s2" if s2 else "none")))
		paths[path] += 1
		var owner_script: Script = v.get_parent().get_script() if v.get_parent() != null else null
		var who := "%s (%s)" % [v.get_parent().name, owner_script.resource_path.get_file() if owner_script != null else "-"]
		var meshes := 0
		for mi in v.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).is_visible_in_tree():
				meshes += 1
		rows.append("character %s: %s, %d meshes drawn" % [who, path, meshes])
		if path in ["both", "his pending"] or (path == "none" and bool(load(MERGE).call("enabled"))):
			odd.append(who + " " + path)
	_report["merge_paths"] = paths
	_check(odd.is_empty(), "every visible character is drawn by exactly one merge path: his %d, S2 %d (none %d, both %d, his pending %d)%s" % [
		paths["his"], paths["s2"], paths["none"], paths["both"], paths["his pending"], "" if odd.is_empty() else ": " + ", ".join(odd)])
	for c: String in creatures:
		rows.append("rigid parts %s: %d standing, %d meshes each (in no merge path)" % [c.get_file(), creatures[c][0], creatures[c][1]])
	_report["rigid_parts"] = creatures
	var carriers: Dictionary = (load(THINGS) as GDScript).get_script_constant_map()["CARRIERS"]
	var styled: Dictionary = (load(HOUSES) as GDScript).get_script_constant_map()["STYLED"]
	if ResourceLoader.exists(BODY_THINGS):
		var body: Dictionary = (load(BODY_THINGS) as GDScript).get_script_constant_map().get("CARRIERS", {})
		_check(body == carriers, "the drawing's carriers are Body's (village/things.gd): %s" % ", ".join(carriers.values()))
	if things != null:
		var r: Dictionary = things.call("report")
		rows.append("things (S4): %d, %s" % [r["things"], JSON.stringify(r["kinds"])])
	var listed := models.keys()
	listed.sort()
	var others := {}
	for p: String in listed:
		var tag := "carrier (%s)" % carriers[p] if carriers.has(p) else ("grammar style" if styled.has(p) else "")
		rows.append("model %s: %d%s" % [p.trim_prefix("res://assets/"), models[p], " - " + tag if tag != "" else ""])
		if tag == "":
			others[p.trim_prefix("res://assets/")] = models[p]
	_report["his_models"] = others
	var f := FileAccess.open(_out + "/census.txt", FileAccess.WRITE)
	f.store_string("\n".join(rows) + "\n")
	f.close()


func _walk(n: Node, visuals: Array, models: Dictionary, creatures: Dictionary) -> void:
	if _is_visual(n):
		visuals.append(n)
	var file := n.scene_file_path
	if file.begins_with("res://assets/") and file.ends_with(".glb") and n is Node3D and (n as Node3D).is_visible_in_tree():
		if file.begins_with("res://assets/creatures/"):
			var e: Array = creatures.get(file, [0, 0])
			e[0] += 1
			e[1] = (n.find_children("*", "MeshInstance3D", true, false)).size()
			creatures[file] = e
		else:
			models[file] = int(models.get(file, 0)) + 1
	for c in n.get_children():
		_walk(c, visuals, models, creatures)


## A CharacterVisual (his class, by its script's name, not by naming the class here).
func _is_visual(n: Node) -> bool:
	var s: Script = n.get_script()
	while s != null:
		if s.get_global_name() == "CharacterVisual":
			return true
		s = s.get_base_script()
	return false


func _finish() -> void:
	_report["checks"] = _lines
	var f := FileAccess.open(_out + "/check.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(_report, "  "))
	f.close()
	print("CHECK complete: %d checks, %d failed" % [_lines.size(), _failed])
	quit(0 if _failed == 0 else 1)
