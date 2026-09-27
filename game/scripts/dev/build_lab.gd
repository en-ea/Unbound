extends Node3D
## The build lab: a small flat stone floor far below the world where every building stands in a
## row with its name, for comparing styles. The title screen's "Build lab" button enters it; the
## pause menu's "Leave build lab" puts you back where you were. Saving pauses while you're here.

const TREASURE := preload("res://scripts/world/treasure.gd")
const AT := Vector3(0, -300, 0)
## [name, model, footprint]: the newest styles in the front row.
const FRONT := [["Hill house", "house_hill", 6.5], ["Lantern house", "house_lantern", 6.5], ["Hull house", "house_hull", 6.5], ["Swoop lodge", "house_lodge", 6.0]]
const BACK := [["Turret cottage", "house_turret", 6.5], ["Storybook cottage", "house_storybook", 6.5], ["Gable house", "house_gable", 5.5], ["Arch cottage", "house_arch", 6.0], ["Round house", "house_round", 5.0], ["Cottage", "house_cottage", 6.0], ["Cabin", "house_cabin", 6.0],
	["Loaf cottage", "house_loaf", 6.0], ["Windmill", "windmill", 5.0], ["Hex house (later)", "house_hex", 6.5],
	["Rune tower (later)", "house_tower", 6.0], ["Grotto house (later)", "house_grotto", 6.5]]

@export var player: CharacterBody3D

var active := false
var _return_to := Vector3.ZERO
var _built := false
var _fog_was := true


func _ready() -> void:
	add_to_group("build_lab")


func enter() -> void:
	if active:
		return
	if not _built:
		_build()
	_return_to = player.global_position
	SaveGame.paused = true
	active = true
	var env := get_viewport().world_3d.environment      # the world's height fog would wash the lab out
	if env:
		_fog_was = env.fog_enabled
		env.fog_enabled = false
	player.global_position = AT + Vector3(0, 0.6, 7.5)
	player.velocity = Vector3.ZERO
	get_tree().call_group("camera_rig", "snap")


func leave() -> void:
	if not active:
		return
	active = false
	var env := get_viewport().world_3d.environment
	if env:
		env.fog_enabled = _fog_was
	player.global_position = _return_to
	player.velocity = Vector3.ZERO
	SaveGame.paused = false
	get_tree().call_group("camera_rig", "snap")


func _build() -> void:
	_built = true
	global_position = AT
	# A dark stone floor with a slightly lighter centre, and a collider to stand on.
	for disc in [[48.0, Color(0.2, 0.22, 0.26)], [30.0, Color(0.26, 0.28, 0.32)]]:
		var mi := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = disc[0]
		mesh.bottom_radius = disc[0]
		mesh.height = 0.2
		mesh.radial_segments = 6            # hexagonal, like the style
		var mat := StandardMaterial3D.new()
		mat.albedo_color = disc[1]
		mat.roughness = 0.95
		mesh.material = mat
		mi.mesh = mesh
		mi.position.y = -0.1 + (0.01 if disc[0] < 40.0 else 0.0)
		add_child(mi)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(96, 1, 96)
	col.shape = box
	col.position.y = -0.5
	body.add_child(col)
	add_child(body)
	_row(FRONT, 0.0, 14.0)
	_row(BACK, -18.0, 12.0)


func _row(list: Array, z: float, gap: float) -> void:
	for i in list.size():
		var entry: Array = list[i]
		var x := (i - (list.size() - 1) / 2.0) * gap
		var model := TREASURE._solid((load("res://assets/buildings/%s.glb" % entry[1]) as PackedScene).instantiate())
		model.position = Vector3(x, 0, z)
		add_child(model)
		if entry[1] == "windmill":
			var sails := TREASURE._solid((load("res://assets/buildings/windmill_sails.glb") as PackedScene).instantiate())
			sails.position = Vector3(0, 5.75, 2.75)
			model.add_child(sails)
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(entry[2] * 0.7, 4, entry[2] * 0.7)
		col.shape = box
		col.position.y = 2
		body.add_child(col)
		model.add_child(body)
		var label := Label3D.new()
		label.text = entry[0]
		label.font_size = 56
		label.outline_size = 14
		label.pixel_size = 0.01
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color(1.0, 0.92, 0.76)
		label.position = Vector3(x, 0.6, z + entry[2] * 0.5 + 1.2)
		add_child(label)
