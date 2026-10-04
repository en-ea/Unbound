extends Node3D
## Named places out in each region, so it isn't all nature: rough placeholder builds (simple
## shapes and reused models) to be replaced with proper models once the owner likes the idea.
## Each has a floating name that shows when you're near, and a spot on the minimap.
## Their ground is flattened in WorldShape.REGIONS (clearings).

const TREASURE := preload("res://scripts/world/treasure.gd")
const NATURE := "res://assets/nature/%s.glb"
const PLACES := {
	"meadow": [
		{"name": "Old Watchtower", "kind": "watchtower", "at": Vector2(-76, -62)},
		{"name": "Farmstead", "kind": "farm", "at": Vector2(72, 44)},
		{"name": "Traveller's Rest", "kind": "rest", "at": Vector2(-70, 58)},
	],
	"forest": [
		{"name": "Woodcutter's Camp", "kind": "woodcutter", "at": Vector2(-70, -45)},
		{"name": "Giant's Hollow", "kind": "hollow", "at": Vector2(66, 52)},
		{"name": "Cave Mouth", "kind": "cave", "at": Vector2(-62, 74)},
		{"name": "Fernhollow", "kind": "fernhollow", "at": Vector2(-30, 16)},
	],
}
const STONE := Color(0.66, 0.64, 0.6)
const DARK_STONE := Color(0.5, 0.49, 0.47)
const WOOD := Color(0.55, 0.37, 0.23)
const DARK_WOOD := Color(0.38, 0.26, 0.18)
const CLOTH := Color(0.86, 0.8, 0.66)
const ROOF := Color(0.62, 0.3, 0.22)
const GLOW := Color(1.0, 0.72, 0.38)

var _labels: Array[Label3D] = []
var _shape: WorldShape
@export var player: Node3D


func build(shape: WorldShape) -> void:
	_shape = shape
	for p: Dictionary in PLACES.get(Region.current, []):
		var at: Vector2 = p["at"]
		var root := Node3D.new()
		add_child(root)
		root.global_position = Vector3(at.x, shape.height_at(at.x, at.y), at.y)
		root.add_to_group("map_building")
		root.set_meta("map_size", Vector2(6, 6))
		call("_" + String(p["kind"]), root)
		var label := Label3D.new()
		label.text = p["name"]
		label.font_size = 52
		label.outline_size = 14
		label.pixel_size = 0.01
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color(1.0, 0.94, 0.8, 0.0)
		label.outline_modulate = Color(0, 0, 0, 0.0)
		label.position = Vector3(0, 7.5, 0)
		root.add_child(label)
		_labels.append(label)


## Names fade in within 22 m.
func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	for l in _labels:
		var near := l.global_position.distance_to(player.global_position) < 22.0
		var a := move_toward(l.modulate.a, 1.0 if near else 0.0, delta * 2.0)
		l.modulate.a = a
		l.outline_modulate.a = a * 0.7


# --- the places ---------------------------------------------------------------------------------

func _watchtower(r: Node3D) -> void:
	for i in 4:                                     # a tapering round tower of stone drums
		_cyl(r, Vector3(0, 1.2 + i * 2.2, 0), 2.1 - i * 0.18, 2.2, STONE if i % 2 == 0 else DARK_STONE, 8)
	_cyl(r, Vector3(0, 9.9, 0), 2.1, 0.5, DARK_STONE, 8)
	for k in 8:                                     # battlements
		var a := k * TAU / 8.0
		_box(r, Vector3(cos(a) * 1.8, 10.5, sin(a) * 1.8), Vector3(0.6, 0.8, 0.6), STONE)
	_box(r, Vector3(0, 1.0, 2.0), Vector3(1.1, 2.0, 0.3), DARK_WOOD)          # door
	_box(r, Vector3(4.5, 1.0, 0.5), Vector3(4.0, 2.0, 0.9), STONE, 0.2)       # broken wall
	_box(r, Vector3(-3.8, 0.7, -1.5), Vector3(3.0, 1.4, 0.9), DARK_STONE, -0.4)
	_light(r, Vector3(0, 6.0, 2.1))
	_collide(r, Vector3(0, 5, 0), Vector3(4.0, 10, 4.0))


func _farm(r: Node3D) -> void:
	_model(r, "res://assets/buildings/house_cabin.glb", Vector3(-4.5, 0, -4.0), 0.0)
	for row in 5:                                   # a crop field in rows (one piece per row: few draw calls)
		_box(r, Vector3(4.3, 0.35, 0.5 + row * 1.3), Vector3(7.4, 0.7, 0.6), Color(0.46, 0.66, 0.3).lerp(Color(0.8, 0.72, 0.3), row * 0.2))
	for k in 3:                                     # fence posts round the field
		_box(r, Vector3(0.2 + k * 4.0, 0.5, -0.6), Vector3(0.15, 1.0, 0.15), WOOD)
		_box(r, Vector3(0.2 + k * 4.0, 0.5, 7.2), Vector3(0.15, 1.0, 0.15), WOOD)
	_box(r, Vector3(4.2, 0.75, -0.6), Vector3(8.2, 0.1, 0.1), WOOD)
	_box(r, Vector3(4.2, 0.75, 7.2), Vector3(8.2, 0.1, 0.1), WOOD)
	_cyl(r, Vector3(-4.0, 0.8, 4.0), 1.2, 1.6, Color(0.9, 0.78, 0.42), 8)     # haystack
	_cone(r, Vector3(-4.0, 2.0, 4.0), 1.2, 1.0, Color(0.86, 0.72, 0.38))
	_collide(r, Vector3(-4.5, 1.5, -4.0), Vector3(4.6, 3, 3.8))


func _rest(r: Node3D) -> void:
	_box(r, Vector3(0, 0.9, 0), Vector3(3.2, 0.7, 1.6), WOOD)                 # a wagon
	for x in [-1.1, 1.1]:
		for z in [-0.9, 0.9]:
			var w := _cyl(r, Vector3(x, 0.55, z), 0.55, 0.15, DARK_WOOD, 8)
			w.rotation.x = PI / 2.0
	var cover := _cyl(r, Vector3(0, 1.4, 0), 0.85, 3.0, CLOTH, 8)
	cover.rotation.z = PI / 2.0
	_cone(r, Vector3(4.0, 1.2, 1.5), 1.7, 2.4, Color(0.72, 0.36, 0.3), 4)     # a tent
	_box(r, Vector3(-3.0, 1.1, 2.5), Vector3(0.15, 2.2, 0.15), WOOD)          # a signpost
	_box(r, Vector3(-2.5, 1.9, 2.5), Vector3(1.1, 0.3, 0.08), WOOD)
	_box(r, Vector3(-3.4, 1.5, 2.5), Vector3(0.9, 0.3, 0.08), WOOD)
	_light(r, Vector3(1.8, 1.8, -1.0))
	_collide(r, Vector3(0, 1, 0), Vector3(3.2, 2, 1.8))


func _woodcutter(r: Node3D) -> void:
	_cone(r, Vector3(-3.0, 1.5, -2.5), 2.2, 3.0, Color(0.5, 0.46, 0.34), 4)    # a canvas tent
	for i in 3:                                     # a log pile
		for k in 3 - i:
			var log := _cyl(r, Vector3(2.0 + k * 0.62 + i * 0.31, 0.3 + i * 0.52, -1.5), 0.3, 3.0, WOOD, 7)
			log.rotation.x = PI / 2.0
	for p in [Vector3(0, 0, 2.5), Vector3(-2, 0, 3.5), Vector3(3.5, 0, 2.8)]:  # stumps
		_cyl(r, p + Vector3(0, 0.3, 0), 0.45, 0.6, DARK_WOOD, 7)
	_box(r, Vector3(0, 0.9, 2.5), Vector3(0.08, 0.6, 0.3), Color(0.6, 0.62, 0.66), 0.4)   # an axe in the stump
	_light(r, Vector3(-1.0, 1.6, -1.0))
	_collide(r, Vector3(2.6, 0.8, -1.5), Vector3(2.4, 1.6, 3.2))


func _hollow(r: Node3D) -> void:
	_model(r, NATURE % "tree_dead_1", Vector3.ZERO, 0.4, 4.0)                  # a huge dead tree
	_cyl(r, Vector3(0, 1.4, 0), 2.2, 2.8, DARK_WOOD, 9)
	var door := _box(r, Vector3(0, 1.1, 2.0), Vector3(1.2, 2.0, 0.4), Color(0.08, 0.06, 0.05))
	door.rotation.y = 0.0
	_light(r, Vector3(0, 1.2, 2.4))
	for k in 6:                                     # glowing mushrooms round the roots
		var a := k * TAU / 6.0 + 0.3
		var m := _cyl(r, Vector3(cos(a) * 3.0, 0.25, sin(a) * 3.0), 0.25, 0.1, Color(0.5, 1.0, 0.8), 6)
		(m.material_override as StandardMaterial3D).emission_enabled = true
		(m.material_override as StandardMaterial3D).emission = Color(0.3, 0.9, 0.7)
	_collide(r, Vector3(0, 2, 0), Vector3(4.2, 4, 4.2))


func _cave(r: Node3D) -> void:
	for p in [Vector3(-3.0, 0, 0), Vector3(3.0, 0, 0), Vector3(-1.5, 3.2, -0.3), Vector3(1.6, 3.4, -0.2), Vector3(0, 4.2, -0.8)]:
		_model(r, NATURE % "rock_%d" % (1 + int(abs(p.x)) % 3), p, p.x * 0.5, 2.6)
	_box(r, Vector3(0, 1.6, -0.6), Vector3(3.0, 3.2, 0.4), Color(0.03, 0.03, 0.04))   # the dark opening
	_cyl(r, Vector3(-2.3, 0.9, 0.9), 0.07, 1.8, DARK_WOOD, 5)                         # a lantern on a post
	_light(r, Vector3(-2.3, 1.85, 0.9))
	var glow := _box(r, Vector3(0, 0.05, -0.2), Vector3(2.4, 0.04, 0.6), Color(0.3, 0.75, 1.0))   # crystal light from within
	(glow.material_override as StandardMaterial3D).emission_enabled = true
	(glow.material_override as StandardMaterial3D).emission = Color(0.3, 0.75, 1.0)
	_collide(r, Vector3(-2.9, 2, -0.5), Vector3(2.2, 4, 2.5))
	_collide(r, Vector3(2.9, 2, -0.5), Vector3(2.2, 4, 2.5))
	_collide(r, Vector3(0, 2, -1.2), Vector3(4, 4, 1.0))
	var door := Node3D.new()
	door.set_script(preload("res://scripts/world/use_spot.gd"))
	r.add_child(door)
	door.setup(r.global_position + Vector3(0, 0.5, 0.2), "Enter", func() -> void: get_tree().call_group("cave", "enter"), 2.2)


## Fernhollow, the wood's village (world/forest_village.gd), and its people.
func _fernhollow(r: Node3D) -> void:
	r.set_meta("map_size", Vector2(2, 2))
	var village := Node3D.new()
	village.set_script(preload("res://scripts/world/forest_village.gd"))
	r.add_child(village)
	village.build(_shape)
	for id: String in Npcs.NPCS:
		if Npcs.NPCS[id].get("region", "meadow") == "forest":
			var npc := Node3D.new()
			npc.set_script(preload("res://scripts/world/npc.gd"))
			add_child(npc)
			npc.setup(id, _shape)


# --- helpers ------------------------------------------------------------------------------------

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _box(r: Node3D, at: Vector3, size: Vector3, c: Color, tilt := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = _mat(c)
	mi.position = at
	mi.rotation.z = tilt
	r.add_child(mi)
	return mi


func _cyl(r: Node3D, at: Vector3, radius: float, height: float, c: Color, seg := 8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = seg
	mesh.rings = 1
	mi.mesh = mesh
	mi.material_override = _mat(c)
	mi.position = at
	r.add_child(mi)
	return mi


func _cone(r: Node3D, at: Vector3, radius: float, height: float, c: Color, seg := 8) -> MeshInstance3D:
	var mi := _cyl(r, at, radius, height, c, seg)
	(mi.mesh as CylinderMesh).top_radius = 0.02
	return mi


func _model(r: Node3D, path: String, at: Vector3, turn: float, scale := 1.0) -> void:
	var m := TREASURE._solid((load(path) as PackedScene).instantiate())
	r.add_child(m)
	m.position = at
	m.rotation.y = turn
	m.scale = Vector3.ONE * scale


func _light(r: Node3D, at: Vector3) -> void:
	var lamp := _cyl(r, at, 0.14, 0.3, GLOW, 6)
	(lamp.material_override as StandardMaterial3D).emission_enabled = true
	(lamp.material_override as StandardMaterial3D).emission = GLOW
	(lamp.material_override as StandardMaterial3D).emission_energy_multiplier = 1.5


func _collide(r: Node3D, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position = at
	body.add_child(col)
	r.add_child(body)
