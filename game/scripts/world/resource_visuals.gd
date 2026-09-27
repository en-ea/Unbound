extends Node3D
## Shows what happens to gatherable things (state lives in WorldResources): a shake and flying
## chips on each hit, a stump when a tree falls, a grow-back animation, and the item drops.

const STUMP := preload("res://assets/nature/tree_stump.glb")
const DROP := preload("res://scripts/world/drop.gd")
const KENNEY := "res://assets/kenney_impact/"

@export var player: Node3D

var _entries := {}        # resource id -> gatherable dict from Scatter
var _stumps := {}         # resource id -> stump node
var _sounds := {}         # "wood" / "wood_heavy" / "stone" / "soft" -> Array[AudioStream]
var _players: Array[AudioStreamPlayer3D] = []
var _next_player := 0
var _chips: CPUParticles3D
var _chip_material: StandardMaterial3D
var _warm_nodes: Array[Node] = []


func _ready() -> void:
	add_to_group("warmup")
	for pair in [["wood", "impactWood_medium"], ["wood_heavy", "impactWood_heavy"], ["stone", "impactMining"], ["soft", "impactSoft_medium"]]:
		_sounds[pair[0]] = []
		for i in 5:
			_sounds[pair[0]].append(load(KENNEY + "%s_%03d.ogg" % [pair[1], i]))
	for i in 4:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 6.0
		add_child(p)
		_players.append(p)
	_chips = _make_chips()
	add_child(_chips)


func setup(gatherables: Array[Dictionary]) -> void:
	for g in gatherables:
		var id: int = WorldResources.add_node(g["type"], g["xf"].origin, g["scale"])
		_entries[id] = g
	WorldResources.hit.connect(_on_hit)
	WorldResources.depleted.connect(_on_depleted)
	WorldResources.respawned.connect(_on_respawned)


func _on_hit(id: int, hits_left: int) -> void:
	var g: Dictionary = _entries[id]
	var tool: String = WorldResources.type_info(id)["tool"]
	var at: Vector3 = g["xf"].origin
	match tool:
		"axe":
			_play(at, "wood_heavy" if hits_left <= 0 else "wood", 0.9)
			_burst(at + Vector3(0, 1.0, 0), Color(0.78, 0.6, 0.4), 10)
		"pickaxe":
			_play(at, "stone", 1.0)
			_burst(at + Vector3(0, 0.6, 0), Color(0.65, 0.65, 0.62), 12)
		_:
			_play(at, "soft", 1.3)
			_burst(at + Vector3(0, 0.3, 0), Color(0.55, 0.8, 0.4), 6)
	if hits_left > 0:
		_shake(g)


func _on_depleted(id: int, drops: Array) -> void:
	var g: Dictionary = _entries[id]
	var base: Transform3D = g["xf"]
	g["multimesh"].set_instance_transform(g["index"], Transform3D(Basis.from_scale(Vector3.ONE * 0.001), base.origin))
	if g["collider"]:
		g["collider"].disabled = true
	if g["type"] in ["tree", "apple_tree"]:
		var stump := STUMP.instantiate() as Node3D
		stump.transform = Transform3D(Basis(Vector3.UP, randf() * TAU).scaled(Vector3.ONE * g["scale"]), base.origin)
		add_child(stump)
		_stumps[id] = stump
		_burst(base.origin + Vector3(0, 2.5, 0), Color(0.45, 0.65, 0.3), 24)
	for i in drops.size():
		var drop := Node3D.new()
		drop.set_script(DROP)
		add_child(drop)
		var dir := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * randf_range(1.0, 2.2)
		drop.launch(drops[i], base.origin + Vector3(0, 0.8, 0), dir + Vector3(0, randf_range(3.5, 5.0), 0), base.origin.y, player)


func _on_respawned(id: int) -> void:
	var g: Dictionary = _entries[id]
	if _stumps.has(id):
		_stumps[id].queue_free()
		_stumps.erase(id)
	if g["collider"]:
		g["collider"].disabled = false
	var base: Transform3D = g["xf"]
	var mm: MultiMesh = g["multimesh"]
	var idx: int = g["index"]
	var grow := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	grow.tween_method(func(f: float) -> void:
		mm.set_instance_transform(idx, Transform3D(base.basis * Basis.from_scale(Vector3.ONE * maxf(f, 0.001)), base.origin)),
		0.0, 1.0, 0.8)


func _shake(g: Dictionary) -> void:
	var base: Transform3D = g["xf"]
	var mm: MultiMesh = g["multimesh"]
	var idx: int = g["index"]
	var away := (base.origin - player.global_position)
	away.y = 0.0
	var axis := Vector3.UP.cross(away.normalized()) if away.length() > 0.01 else Vector3.RIGHT
	var strength := 0.06 if g["type"] in ["tree", "apple_tree"] else 0.03
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		var angle := sin(t * 28.0) * strength * (1.0 - t)
		mm.set_instance_transform(idx, Transform3D(Basis(axis, angle) * base.basis, base.origin)),
		0.0, 1.0, 0.35)


func _play(at: Vector3, sound: String, pitch: float) -> void:
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.global_position = at
	p.stream = _sounds[sound].pick_random()
	p.pitch_scale = pitch * randf_range(0.92, 1.08)
	p.play()


func _burst(at: Vector3, color: Color, count: int) -> void:
	_chips.global_position = at
	_chip_material.albedo_color = color
	_chips.amount = count
	_chips.restart()


func _make_chips() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 0.7
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -12, 0)
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var box := BoxMesh.new()
	box.size = Vector3(0.07, 0.05, 0.03)
	_chip_material = StandardMaterial3D.new()
	_chip_material.roughness = 0.9
	box.material = _chip_material
	p.mesh = box
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## Loading-screen warm-up: show one of each drop shape so their shaders are ready.
func warm(at: Vector3) -> void:
	var i := 0
	for item in ["wood", "stone", "apple", "mushroom", "resin", "shard"]:
		var sample := DROP.make_mesh(item)
		sample.position = at + Vector3((i - 2.5) * 0.4, 1.0, -1.0)
		add_child(sample)
		_warm_nodes.append(sample)
		i += 1
	_burst(at + Vector3(0, 1, -1), Color.WHITE, 4)


func unwarm() -> void:
	for n in _warm_nodes:
		n.queue_free()
	_warm_nodes.clear()
