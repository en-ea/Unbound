extends Node3D
## Sunreach, the second land: Saffra (the harbour town: adobe houses, domes and awnings round a well
## and a market), the pier with your ship moored at its end, and the lighthouse on the headland.
## Its people are in Npcs (region "sands"). Models: tools-src/blender/make_sunreach.py.

const DIR := "res://assets/sunreach/%s.glb"
const TREASURE := preload("res://scripts/world/treasure.gd")
const SQUARE := Vector2(6.0, 36.0)
## Saffra's buildings: model, spot, how wide to block them. Every door faces the square.
const HOUSES := [
	{"model": "house_dome", "at": Vector2(-9, 28), "radius": 3.0},
	{"model": "house_tower", "at": Vector2(21, 29), "radius": 3.0},
	{"model": "house_wide", "at": Vector2(7, 20.5), "radius": 3.6},
	{"model": "house_dome", "at": Vector2(-8, 46), "radius": 3.0},
	{"model": "house_tower", "at": Vector2(-14.5, 37.5), "radius": 2.8},
	{"model": "house_wide", "at": Vector2(24, 44), "radius": 3.6},
]
const STALLS := [Vector2(0.0, 42.5), Vector2(12.5, 41.5), Vector2(1.5, 29.5)]
const LANTERNS := [Vector2(9.5, 48), Vector2(13.5, 54), Vector2(7.5, 27), Vector2(2, 14), Vector2(-1, 37), Vector2(13, 35)]
const PLANTERS := [Vector2(10.5, 32), Vector2(1.5, 45), Vector2(16, 38)]
const PIER_X := 12.0
const PIER_TOP := WorldShape.WATER_Y + 1.1
const LIGHTHOUSE := Vector2(-30.0, 74.0)

var player: Node3D
var _ship: Node3D
var _beam: Node3D
var _t := 0.0


func build(shape: WorldShape) -> void:
	for h: Dictionary in HOUSES:
		var at: Vector2 = h["at"]
		var house := _model(h["model"], _at(shape, at, -0.1))
		if house == null:
			continue
		var to_mid: Vector2 = SQUARE - at
		house.rotation.y = atan2(to_mid.x, to_mid.y)
		house.add_to_group("map_building")
		house.set_meta("map_size", Vector2(6, 6))
		_block(house, h["radius"], 5.0)
	_model("well", _at(shape, SQUARE, -0.05))
	_block_at(_at(shape, SQUARE, 0.0), 1.2)
	for s: Vector2 in STALLS:
		var stall := _model("market_stall", _at(shape, s, 0.0))
		if stall:
			var to_mid: Vector2 = SQUARE - s
			stall.rotation.y = atan2(to_mid.x, to_mid.y)
			_block(stall, 1.2, 2.0)
	for p: Vector2 in LANTERNS:
		var post := _model("lantern_post", _at(shape, p, 0.0))
		if post:
			var glow := OmniLight3D.new()            # warm pools of light along the street at night
			glow.light_color = Color(1.0, 0.7, 0.38)
			glow.omni_range = 6.0
			glow.light_energy = 0.9
			glow.position = Vector3(0, 2.4, 0)
			post.add_child(glow)
	for p: Vector2 in PLANTERS:
		_model("palm_planter", _at(shape, p, 0.0))
	_build_pier()
	_build_lighthouse(shape)
	for id: String in Npcs.NPCS:
		if Npcs.NPCS[id].get("region", "meadow") == "sands":
			var npc := Node3D.new()
			npc.set_script(preload("res://scripts/world/npc.gd"))
			add_child(npc)
			npc.setup(id, shape)


func _process(delta: float) -> void:
	_t += delta
	if _ship:                                      # moored, rocking on the swell
		_ship.rotation = Vector3(sin(_t * 0.7) * 0.025, PI, sin(_t * 0.9 + 1.0) * 0.04)
		_ship.position.y = WorldShape.WATER_Y + sin(_t * 0.8) * 0.12
	if _beam:
		_beam.rotation.y = _t * 0.6


## The pier (two sections out from the beach), its rails, and the ship tied up at the end of it.
func _build_pier() -> void:
	for i in 2:
		var pier := _model("pier", Vector3(PIER_X, PIER_TOP - 1.2, 63.0 + i * 12.0))
		if pier:
			pier.rotation.y = PI                       # the model runs along -Z; ours runs out to sea (+Z)
			pier.scale = Vector3(1.5, 1.0, 1.0)
	var body := StaticBody3D.new()
	add_child(body)
	_box(body, Vector3(6.0, 1.0, 26.0), Vector3(PIER_X, PIER_TOP - 0.5, 75.0))      # the deck
	for side in [-1.0, 1.0]:
		_box(body, Vector3(0.4, 3.0, 26.0), Vector3(PIER_X + side * 3.1, PIER_TOP + 1.0, 75.0))
	_box(body, Vector3(6.4, 3.0, 0.4), Vector3(PIER_X, PIER_TOP + 1.0, 88.4))
	_ship = _model("ship", Vector3(PIER_X + 0.5, WorldShape.WATER_Y, 95.0))
	var sign := Label3D.new()
	sign.text = "Set sail for the mainland"
	sign.font_size = 56
	sign.outline_size = 10
	sign.pixel_size = 0.006
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = Color(1.0, 0.92, 0.7)
	sign.outline_modulate = Color(0.1, 0.06, 0.02, 0.8)
	add_child(sign)
	sign.global_position = Vector3(PIER_X, PIER_TOP + 3.0, 87.0)


## The lighthouse on the headland: a fire that never went out, and a slow sweeping beam.
func _build_lighthouse(shape: WorldShape) -> void:
	var tower := _model("lighthouse", _at(shape, LIGHTHOUSE, -0.2))
	if tower == null:
		return
	_block(tower, 2.6, 16.0)
	var fire := OmniLight3D.new()
	fire.light_color = Color(1.0, 0.72, 0.35)
	fire.light_energy = 2.5
	fire.omni_range = 26.0
	fire.position = Vector3(0, 16.0, 0)
	tower.add_child(fire)
	_beam = Node3D.new()
	_beam.position = Vector3(0, 15.6, 0)
	tower.add_child(_beam)
	var cone := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.4
	mesh.bottom_radius = 5.0
	mesh.height = 60.0
	mesh.radial_segments = 10
	mesh.cap_top = false
	mesh.cap_bottom = false
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/light_beam.gdshader")
	mat.set_shader_parameter("strength", 0.18)
	mesh.material = mat
	cone.mesh = mesh
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cone.rotation.x = PI * 0.5
	cone.position = Vector3(0, 0, -30.0)
	_beam.add_child(cone)


# --- helpers ------------------------------------------------------------------------------------

func _model(name: String, at: Vector3) -> Node3D:
	var path := DIR % name
	if not ResourceLoader.exists(path):
		return null
	var m := TREASURE._solid((load(path) as PackedScene).instantiate())
	add_child(m)
	m.position = at
	return m


func _at(shape: WorldShape, p: Vector2, lift: float) -> Vector3:
	return Vector3(p.x, shape.height_at(p.x, p.y) + lift, p.y)


func _block(node: Node3D, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	col.shape = cyl
	col.position = Vector3(0, height * 0.5, 0)
	body.add_child(col)
	node.add_child(body)


func _block_at(at: Vector3, radius: float) -> void:
	var body := StaticBody3D.new()
	add_child(body)
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = 3.0
	col.shape = cyl
	body.add_child(col)
	body.global_position = at + Vector3(0, 1.5, 0)


func _box(body: StaticBody3D, size: Vector3, at: Vector3) -> void:
	var box := BoxShape3D.new()
	box.size = size
	var col := CollisionShape3D.new()
	col.shape = box
	col.position = at
	body.add_child(col)
