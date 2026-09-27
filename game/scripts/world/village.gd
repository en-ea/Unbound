extends Node3D
## A tiny village by the path: four houses in four styles (for the owner to compare) and the
## Merchant, a heavy-set NPC who turns to greet you when you come close.

const SOLID_SHADER := preload("res://shaders/foliage_solid.gdshader")
const HOUSES := [
	{"model": "res://assets/buildings/house_cottage.glb", "at": Vector2(-5.5, 11.5), "size": Vector3(4.6, 4, 3.6)},
	{"model": "res://assets/buildings/house_cabin.glb", "at": Vector2(10.5, 13.0), "size": Vector3(4.4, 4, 3.6)},
	{"model": "res://assets/buildings/house_round.glb", "at": Vector2(-9.0, 23.0), "size": Vector3(4.4, 4, 4.4)},
	{"model": "res://assets/buildings/house_long.glb", "at": Vector2(14.0, 2.5), "size": Vector3(6.4, 4, 3.8)},
]
const MERCHANT_AT := Vector2(5.4, 16.0)
const GREETINGS := ["Fine goods today, traveller!", "Wood, stone, hides... I buy it all. Soon.",
	"Mind the boars past the hill.", "Come back when my stall is built!"]

@export var player: Node3D

var _merchant: CharacterVisual
var _bubble: Label3D
var _greeted := false


func build(shape: WorldShape) -> void:
	for h: Dictionary in HOUSES:
		var at: Vector2 = h["at"]
		var house := (load(h["model"]) as PackedScene).instantiate() as Node3D
		for mi: MeshInstance3D in house.find_children("*", "MeshInstance3D", true, false):
			for s in mi.mesh.get_surface_count():
				var src := mi.mesh.surface_get_material(s)
				var mat := ShaderMaterial.new()
				mat.shader = SOLID_SHADER
				mat.set_shader_parameter("albedo", Color.WHITE)
				mat.set_shader_parameter("sway", 0.0)
				mat.set_shader_parameter("glow", 1.5 if src and src.resource_name == "Glow" else 0.0)
				mi.set_surface_override_material(s, mat)
		add_child(house)
		house.global_position = Vector3(at.x, shape.height_at(at.x, at.y) - 0.15, at.y)
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = h["size"]
		col.shape = box
		col.position = Vector3(0, 2, 0)
		body.add_child(col)
		house.add_child(body)
	_add_merchant(shape)


func _add_merchant(shape: WorldShape) -> void:
	_merchant = CharacterVisual.new()
	var look := CharacterLook.new()
	look.outfit = "Wanderer"
	while look.outfit != "Merchant":
		look.cycle_outfit(1)
	# The big merchant from the owner's reference sheet: red coat with cream cuffs, red hat,
	# full dark beard, strap and belt, and a huge pack with a bedroll and a lantern.
	look.parts = {"face": "happy", "cheeks": "blush", "hair": "short", "beard": "full", "head": "hat",
		"top": "coat", "chest": "strap", "shoulders": "none", "back": "backpack"}
	look.colors = {"Skin": 2, "Hair": 5, "Main": 2, "Second": 1, "Cloth": 0, "Accent": 0, "Leather": 0}
	_merchant.hero_look = look
	add_child(_merchant)
	_merchant.scale = Vector3(1.38, 0.96, 1.32)     # big and broad
	_merchant.global_position = Vector3(MERCHANT_AT.x, shape.height_at(MERCHANT_AT.x, MERCHANT_AT.y), MERCHANT_AT.y)
	var lantern := MeshInstance3D.new()
	var glass := SphereMesh.new()
	glass.radius = 0.07
	glass.height = 0.16
	glass.radial_segments = 6
	glass.rings = 3
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.75, 0.4)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.7, 0.35)
	glow.emission_energy_multiplier = 2.0
	glass.material = glow
	lantern.mesh = glass
	lantern.position = Vector3(-0.2, 1.05, -0.3)      # hanging off the side of the pack
	_merchant.add_child(lantern)
	_bubble = Label3D.new()
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.no_depth_test = true
	_bubble.font_size = 44
	_bubble.outline_size = 14
	_bubble.pixel_size = 0.005
	_bubble.modulate = Color(1, 0.97, 0.88, 0.0)
	_bubble.outline_modulate = Color(0.08, 0.06, 0.1, 0.0)
	_bubble.position = Vector3(0, 2.35, 0)
	_merchant.add_child(_bubble)


func _process(delta: float) -> void:
	if _merchant == null:
		return
	var to := player.global_position - _merchant.global_position
	to.y = 0.0
	var near := to.length() < 3.5
	if near:
		_merchant.rotation.y = lerp_angle(_merchant.rotation.y, atan2(to.x, to.z), clampf(delta * 5.0, 0.0, 1.0))
		if not _greeted:
			_greeted = true
			_bubble.text = GREETINGS.pick_random()
	elif to.length() > 5.0:
		_greeted = false
	var a := move_toward(_bubble.modulate.a, 1.0 if near else 0.0, delta * 4.0)
	_bubble.modulate.a = a
	_bubble.outline_modulate.a = a * 0.8
