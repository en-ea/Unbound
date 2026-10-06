class_name HouseVariety
extends Node
## Graphics S5 (studio plan GRAPHICS-STAGES-2026-10-04.md): the village's houses drawn from the house grammar
## (tools-src/studio/blender/house_grammar.py), behind one switch with three settings:
##   off: his houses, today's scene exactly;
##   preset (when absent; the desk's rule for Hilmi's build, 5 Oct: a house Enea placed keeps his model): each house
##     the grammar's preset of it, the same model as his (built from his own helpers in his order);
##   variety: each house a seeded variant of its style, within his footprint, from its place (a look proposal).
## Only the drawing changes: his house node, its collision, its map entry and everything on it stay; its mesh is the
## grammar's, drawn as the village draws his (his solid shader, glowing parts at 1.5). It runs as the region is built,
## before StaticBatch gathers, so the houses it draws batch as his did.
## Setting: project setting studio/render/house_variety ("preset" when absent), or --studio-houses=off|preset|variety.

const SETTING := "studio/render/house_variety"
const SOLID := preload("res://shaders/foliage_solid.gdshader")
const DIR := "res://assets/studio/houses/"
## His houses the grammar has a style for, by model.
const STYLED := {"res://assets/buildings/house_cottage.glb": "house_cottage",
	"res://assets/buildings/house_cabin.glb": "house_cabin", "res://assets/buildings/house_round.glb": "house_round"}

var mode := "off"
var _swaps: Array = []               # [his MeshInstance3D, his mesh, his materials, grammar mesh, grammar materials]
var _swap_usec := 0


static func setting() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--studio-houses="):
			return arg.trim_prefix("--studio-houses=")
	return str(ProjectSettings.get_setting(SETTING, "preset"))


## From StaticBatch.attach (main.gd's graphics line), before the batcher: the region is built.
static func attach(main: Node) -> void:
	var m := setting()
	if m not in ["preset", "variety"] or main.has_node("StudioHouses"):
		return
	var n := HouseVariety.new()
	n.name = "StudioHouses"
	n.mode = m
	main.add_child(n)
	n.swap(main)


func swap(main: Node) -> void:
	var t0 := Time.get_ticks_usec()
	for house in _houses(main):
		var file: String = DIR + ("preset_" if mode == "preset" else "variety_") + str(STYLED[house.scene_file_path]) + ".glb"
		if not ResourceLoader.exists(file):
			push_warning("house variety: no " + file)
			continue
		var made := (load(file) as PackedScene).instantiate() as Node3D
		var theirs: Array = made.find_children("*", "MeshInstance3D", true, false)
		var his: Array = house.find_children("*", "MeshInstance3D", true, false)
		if theirs.size() != 1 or his.size() != 1:
			push_warning("house variety: one mesh each expected in " + file)
			made.free()
			continue
		var mi: MeshInstance3D = his[0]
		var mesh: Mesh = (theirs[0] as MeshInstance3D).mesh
		var old_mats := []
		for s in mi.mesh.get_surface_count():
			old_mats.append(mi.get_surface_override_material(s))
		var new_mats := []
		for s in mesh.get_surface_count():
			var src := mesh.surface_get_material(s)
			var mat := ShaderMaterial.new()
			mat.shader = SOLID
			mat.set_shader_parameter("albedo", Color.WHITE)
			mat.set_shader_parameter("sway", 0.0)
			mat.set_shader_parameter("glow", 1.5 if src and src.resource_name == "Glow" else 0.0)
			new_mats.append(mat)
		_swaps.append([mi, mi.mesh, old_mats, mesh, new_mats])
		made.free()
	show_his(false)
	_swap_usec = Time.get_ticks_usec() - t0


func _houses(from: Node) -> Array:
	var out := []
	if STYLED.has(from.scene_file_path):
		out.append(from)
		return out
	for c in from.get_children():
		out.append_array(_houses(c))
	return out


## For the checks: his houses drawn again (true) or the grammar's (false), in place.
func show_his(on: bool) -> void:
	for e: Array in _swaps:
		var mi: MeshInstance3D = e[0]
		if not is_instance_valid(mi):
			continue
		mi.mesh = e[1] if on else e[3]
		var mats: Array = e[2] if on else e[4]
		for s in mats.size():
			mi.set_surface_override_material(s, mats[s])


func report() -> Dictionary:
	var names := []
	for e: Array in _swaps:
		names.append(str((e[0] as Node).get_parent().name))
	return {"mode": mode, "swapped": _swaps.size(), "houses": names, "swap_ms": float(_swap_usec) / 1000.0}
