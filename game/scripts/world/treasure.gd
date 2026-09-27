extends Node3D
## Old ruins and treasure chests hidden around the meadow. A chest is a gatherable in
## WorldResources (type "chest": "Open", no tool), so reach, the action button, loot and saving all
## work like trees; this script shows it: a glint while it's full, the lid swinging open, the loot.
## It refills after a long while.

const SOLID_SHADER := preload("res://shaders/foliage_solid.gdshader")
const DROP := preload("res://scripts/world/drop.gd")
const RUIN := preload("res://assets/props/ruin_arch.glb")
const CHEST_BASE := preload("res://assets/props/chest_base.glb")
const CHEST_LID := preload("res://assets/props/chest_lid.glb")
const SOUNDS := {"open": preload("res://assets/sounds/tree_creak.wav"), "rare": preload("res://assets/sounds/rare.wav")}
const LID_HINGE := Vector3(0, 0.47, -0.3)
const LID_OPEN := -1.9

## Ruins (x, z) and chests (x, z, turn in degrees, lift: chests in a ruin sit on its platform). Chest spots are also in WorldShape.keep_clear.
const RUINS := [Vector2(-38, -12), Vector2(40, 22)]
const CHESTS := [Vector4(-38, -11.2, 0, 0.37), Vector4(40, 22.8, 0, 0.37), Vector4(31, -40, 25, 0)]

@export var player: Node3D

var _chests := {}        # resource id -> {"root": Node3D, "lid": Node3D, "glint": CPUParticles3D}
var _audio: AudioStreamPlayer3D


func build(shape: WorldShape) -> void:
	_audio = AudioStreamPlayer3D.new()
	_audio.unit_size = 6.0
	add_child(_audio)
	for r: Vector2 in RUINS:
		var ruin := _solid(RUIN.instantiate())
		add_child(ruin)
		ruin.global_position = Vector3(r.x, shape.height_at(r.x, r.y) - 0.1, r.y)
		for x in [-1.3, 1.3]:
			_collider(ruin, Vector3(x, 1.5, 0), Vector3(0.7, 3.0, 0.7))
	for c: Vector4 in CHESTS:
		var at := Vector3(c.x, shape.height_at(c.x, c.y) + c.w, c.y)
		var id := WorldResources.add_node("chest", at)
		var root := Node3D.new()
		add_child(root)
		root.global_position = at
		root.rotation.y = deg_to_rad(c.z)
		root.add_child(_solid(CHEST_BASE.instantiate()))
		var lid := _solid(CHEST_LID.instantiate())
		lid.position = LID_HINGE
		root.add_child(lid)
		_collider(root, Vector3(0, 0.3, 0), Vector3(0.9, 0.6, 0.6))
		var glint := _make_glint()
		root.add_child(glint)
		_chests[id] = {"root": root, "lid": lid, "glint": glint}
	WorldResources.depleted.connect(_on_opened)
	WorldResources.respawned.connect(_on_refilled)
	WorldResources.loaded.connect(_on_loaded)


func _on_opened(id: int, drops: Array) -> void:
	if not _chests.has(id):
		return
	var c: Dictionary = _chests[id]
	c["glint"].emitting = false
	var at: Vector3 = c["root"].global_position
	_audio.global_position = at
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(c["lid"], "rotation:x", LID_OPEN, 0.45)
	_play("open", 1.7)
	get_tree().create_timer(0.25).timeout.connect(func() -> void: _play("rare", 1.0))
	for i in drops.size():
		var drop := Node3D.new()
		drop.set_script(DROP)
		add_child(drop)
		var dir := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * randf_range(0.8, 1.8)
		drop.launch(drops[i], at + Vector3(0, 0.6, 0), dir + Vector3(0, randf_range(4.0, 5.5), 0), at.y, player)


func _on_refilled(id: int) -> void:
	if not _chests.has(id):
		return
	var c: Dictionary = _chests[id]
	c["lid"].rotation.x = 0.0
	c["glint"].emitting = true


func _on_loaded() -> void:
	for id: int in _chests:
		var open := not WorldResources.is_available(id)
		_chests[id]["lid"].rotation.x = LID_OPEN if open else 0.0
		_chests[id]["glint"].emitting = not open


## A few golden sparkles rising off a full chest, so it catches the eye from a distance.
func _make_glint() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 6
	p.lifetime = 1.4
	p.position = Vector3(0, 0.5, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.4, 0.1, 0.25)
	p.gravity = Vector3(0, 0.6, 0)
	p.initial_velocity_max = 0.1
	p.scale_amount_min = 0.6
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.add_point(0.3, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.06
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(2.4, 1.9, 0.9)
	quad.material = mat
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _collider(parent: Node3D, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position = at
	body.add_child(col)
	parent.add_child(body)


## Gives an imported model our faceted colour shader (colours live in its UVs); "Glow" parts glow.
static func _solid(model: Node) -> Node3D:
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			var mat := ShaderMaterial.new()
			mat.shader = SOLID_SHADER
			mat.set_shader_parameter("albedo", Color.WHITE)
			mat.set_shader_parameter("sway", 0.0)
			mat.set_shader_parameter("glow", 1.2 if src and src.resource_name == "Glow" else 0.0)
			mi.set_surface_override_material(s, mat)
	return model as Node3D


func _play(sound: String, pitch: float) -> void:
	_audio.stream = SOUNDS[sound]
	_audio.pitch_scale = pitch
	_audio.play()
