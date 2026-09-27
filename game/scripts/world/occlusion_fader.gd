extends Node3D
## Makes trees that hide the player see-through. Every few frames it checks which tree crowns
## cover the player on screen; each one is swapped for a copy with a dithered fade shader, and
## swapped back once it no longer covers the player. Only those few trees pay for the effect.
##
## Anything that moves a tree instance (shakes, falling, growing) goes through pose(), so a
## faded tree's copy follows along.

const FADE_SHADER := preload("res://shaders/foliage_fade.gdshader")
const CHECK_EVERY := 0.1
const FADED := 0.4
const CROWN_HEIGHT := 3.2       # crown centre above the trunk base, at scale 1
const CROWN_RADIUS := 2.2

@export var camera_rig: Node3D
@export var player: Node3D

var _trees: Array[Dictionary] = []    # {xf, multimesh, index} from Scatter
var _faded := {}                      # "id:index" -> {proxy, mm, idx, xf, tween, leaving}
var _materials := {}                  # Mesh -> Array[ShaderMaterial] templates
var _timer := 0.0


var _warm_node: MeshInstance3D


func _ready() -> void:
	add_to_group("warmup")


func setup(trees: Array[Dictionary]) -> void:
	_trees = trees


## Loading-screen warm-up: show one faded tree so its shader is ready.
func warm(at: Vector3) -> void:
	if _trees.is_empty():
		return
	var mesh: Mesh = _trees[0]["multimesh"].mesh
	_warm_node = MeshInstance3D.new()
	_warm_node.mesh = mesh
	var mats := _materials_for(mesh)
	for s in mats.size():
		var m: ShaderMaterial = mats[s].duplicate()
		m.set_shader_parameter("fade", 0.5)
		_warm_node.set_surface_override_material(s, m)
	add_child(_warm_node)
	_warm_node.global_position = at + Vector3(0, 0, -3)


func unwarm() -> void:
	if _warm_node:
		_warm_node.queue_free()


## Place a tree instance (used instead of MultiMesh.set_instance_transform directly).
func pose(mm: MultiMesh, idx: int, xf: Transform3D) -> void:
	var key := _key(mm, idx)
	if _faded.has(key):
		_faded[key]["xf"] = xf
		_faded[key]["proxy"].transform = xf
	else:
		mm.set_instance_transform(idx, xf)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = CHECK_EVERY
	var camera: Camera3D = camera_rig.camera
	var screen_h := get_viewport().get_visible_rect().size.y
	var focal := screen_h * 0.5 / tan(deg_to_rad(camera.fov) * 0.5)
	var eye := camera.global_position
	var target := player.global_position + Vector3(0, 1.0, 0)
	var target_screen := camera.unproject_position(target)
	var target_dist := eye.distance_to(target)
	var covering := {}
	for t in _trees:
		var xf: Transform3D = t["xf"]
		if xf.origin.distance_squared_to(player.global_position) > 400.0:
			continue
		var scale := xf.basis.get_scale().x
		var crown := xf.origin + Vector3(0, CROWN_HEIGHT * scale, 0)
		var dist := eye.distance_to(crown)
		if dist > target_dist - 0.5:
			continue
		var radius := CROWN_RADIUS * scale * focal / dist
		if camera.unproject_position(crown).distance_to(target_screen) < radius:
			covering[_key(t["multimesh"], t["index"])] = t
	for key: String in covering:
		if not _faded.has(key):
			_fade_in(key, covering[key])
		elif _faded[key]["leaving"]:
			_faded[key]["leaving"] = false
			_tween_fade(key, FADED)
	for key: String in _faded.keys():
		if not covering.has(key) and not _faded[key]["leaving"]:
			_faded[key]["leaving"] = true
			_tween_fade(key, 1.0)


func _fade_in(key: String, t: Dictionary) -> void:
	var mm: MultiMesh = t["multimesh"]
	var idx: int = t["index"]
	var current := mm.get_instance_transform(idx)
	var proxy := MeshInstance3D.new()
	proxy.mesh = mm.mesh
	var mats := _materials_for(mm.mesh)
	for s in mats.size():
		proxy.set_surface_override_material(s, mats[s].duplicate())
	proxy.transform = current
	add_child(proxy)
	mm.set_instance_transform(idx, Transform3D(Basis.from_scale(Vector3.ONE * 0.001), current.origin))
	_faded[key] = {"proxy": proxy, "mm": mm, "idx": idx, "xf": current, "tween": null, "leaving": false}
	_tween_fade(key, FADED)


func _tween_fade(key: String, to: float) -> void:
	var entry: Dictionary = _faded[key]
	if entry["tween"]:
		entry["tween"].kill()
	var proxy: MeshInstance3D = entry["proxy"]
	var from: float = proxy.get_surface_override_material(0).get_shader_parameter("fade")
	var tween := create_tween()
	tween.tween_method(func(f: float) -> void:
		for s in proxy.get_surface_override_material_count():
			proxy.get_surface_override_material(s).set_shader_parameter("fade", f), from, to, 0.25)
	if to >= 1.0:
		tween.tween_callback(_restore.bind(key))
	entry["tween"] = tween


func _restore(key: String) -> void:
	var entry: Dictionary = _faded[key]
	entry["mm"].set_instance_transform(entry["idx"], entry["xf"])
	entry["proxy"].queue_free()
	_faded.erase(key)


## Fade-shader copies of a tree mesh's materials (same colours and sway).
func _materials_for(mesh: Mesh) -> Array:
	if _materials.has(mesh):
		return _materials[mesh]
	var mats := []
	for s in mesh.get_surface_count():
		var src := mesh.surface_get_material(s)
		var m := ShaderMaterial.new()
		m.shader = FADE_SHADER
		if src is ShaderMaterial:
			for p in ["albedo", "sway", "sway_height"]:
				m.set_shader_parameter(p, src.get_shader_parameter(p))
		elif src is StandardMaterial3D:
			m.set_shader_parameter("albedo", src.albedo_color)
			m.set_shader_parameter("sway", 0.0)
		m.set_shader_parameter("fade", 1.0)
		mats.append(m)
	_materials[mesh] = mats
	return mats


func _key(mm: MultiMesh, idx: int) -> String:
	return "%d:%d" % [mm.get_instance_id(), idx]
