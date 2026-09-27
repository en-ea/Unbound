extends Node3D
## Shows what happens to gatherable things (state lives in WorldResources): a shake and flying
## chips on each hit, a stump when a tree falls, a grow-back animation, and the item drops.

const STUMP := preload("res://assets/nature/tree_stump.glb")
const DROP := preload("res://scripts/world/drop.gd")
const KENNEY := "res://assets/kenney_impact/"
const FALL_SOUNDS := {
	"creak": preload("res://assets/sounds/tree_creak.wav"),
	"rustle": preload("res://assets/sounds/leaves_rustle.wav"),
	"thud": preload("res://assets/sounds/tree_thud.wav"),
}

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
	for key: String in FALL_SOUNDS:
		_sounds[key] = [FALL_SOUNDS[key]]
	for i in 6:
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
	WorldResources.grown.connect(_on_grown)


## The instance transform at the node's current size (saplings are smaller).
func _shown(id: int, extra := Basis.IDENTITY, factor := -1.0) -> Transform3D:
	var base: Transform3D = _entries[id]["xf"]
	var f := WorldResources.size_factor(id) if factor < 0.0 else factor
	return Transform3D(extra * base.basis * Basis.from_scale(Vector3.ONE * maxf(f, 0.001)), base.origin)


func _pose(id: int, xf: Transform3D) -> void:
	_entries[id]["multimesh"].set_instance_transform(_entries[id]["index"], xf)


func _on_hit(id: int, hits_left: int) -> void:
	var g: Dictionary = _entries[id]
	var tool: String = WorldResources.type_info(id)["tool"]
	var at: Vector3 = g["xf"].origin
	match tool:
		"axe":
			# A deep thunk layered with a brighter crack, plus a little leaf rustle.
			_play(at, "wood_heavy", 0.72, 0.0)
			_play(at, "wood", 1.15, -7.0)
			_play(at, "rustle", 1.0, -12.0)
			_burst(at + Vector3(0, 1.0, 0), Color(0.78, 0.6, 0.4), 10)
		"pickaxe":
			_play(at, "stone", 1.0, 0.0)
			_burst(at + Vector3(0, 0.6, 0), Color(0.65, 0.65, 0.62), 12)
		_:
			_play(at, "soft", 1.3, -2.0)
			_burst(at + Vector3(0, 0.3, 0), Color(0.55, 0.8, 0.4), 6)
	if hits_left > 0:
		_shake(id)


func _on_depleted(id: int, drops: Array) -> void:
	var g: Dictionary = _entries[id]
	var base: Transform3D = g["xf"]
	if g["collider"]:
		g["collider"].disabled = true
	if WorldResources.is_tree(id):
		_fell(id)
	else:
		_pose(id, Transform3D(Basis.from_scale(Vector3.ONE * 0.001), base.origin))
	for i in drops.size():
		var drop := Node3D.new()
		drop.set_script(DROP)
		add_child(drop)
		var dir := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * randf_range(1.0, 2.2)
		drop.launch(drops[i], base.origin + Vector3(0, 0.8, 0), dir + Vector3(0, randf_range(3.5, 5.0), 0), base.origin.y, player)


## The tree tips over away from the player, lands with a thud and a burst of leaves, and
## leaves a stump behind.
func _fell(id: int) -> void:
	var g: Dictionary = _entries[id]
	var base: Transform3D = g["xf"]
	var size := WorldResources.size_factor(id)
	var away := base.origin - player.global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	var axis := Vector3.UP.cross(away).normalized()
	var stump := STUMP.instantiate() as Node3D
	stump.transform = Transform3D(Basis(Vector3.UP, randf() * TAU).scaled(Vector3.ONE * g["scale"] * size), base.origin)
	add_child(stump)
	_stumps[id] = stump
	_play(base.origin, "creak", randf_range(0.9, 1.1), -2.0)
	var fall := create_tween()
	fall.tween_method(func(t: float) -> void:
		_pose(id, _shown(id, Basis(axis, t * t * 1.45))), 0.0, 1.0, 0.9)
	fall.tween_callback(func() -> void:
		var landing: Vector3 = base.origin + away * 3.0 * g["scale"] * size
		_play(landing, "thud", randf_range(0.9, 1.05), 0.0)
		_play(landing, "rustle", 0.8, -4.0)
		_burst(landing + Vector3(0, 0.6, 0), Color(0.45, 0.65, 0.3), 24))
	fall.tween_method(func(f: float) -> void:
		_pose(id, _shown(id, Basis(axis, 1.45), size * f)), 1.0, 0.0, 0.3)


func _on_grown(id: int, _size: float) -> void:
	if WorldResources.is_available(id):
		_pose(id, _shown(id))


func _on_respawned(id: int) -> void:
	var g: Dictionary = _entries[id]
	if _stumps.has(id):
		_stumps[id].queue_free()
		_stumps.erase(id)
	if g["collider"]:
		g["collider"].disabled = false
	var target := WorldResources.size_factor(id)
	var grow := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	grow.tween_method(func(f: float) -> void: _pose(id, _shown(id, Basis.IDENTITY, f)), 0.0, target, 0.8)


func _shake(id: int) -> void:
	var g: Dictionary = _entries[id]
	var base: Transform3D = g["xf"]
	var away := (base.origin - player.global_position)
	away.y = 0.0
	var axis := Vector3.UP.cross(away.normalized()) if away.length() > 0.01 else Vector3.RIGHT
	var strength := 0.06 if g["type"] in ["tree", "apple_tree"] else 0.03
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		_pose(id, _shown(id, Basis(axis, sin(t * 28.0) * strength * (1.0 - t)))),
		0.0, 1.0, 0.35)


func _play(at: Vector3, sound: String, pitch: float, volume_db := 0.0) -> void:
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.global_position = at
	p.stream = _sounds[sound].pick_random()
	p.pitch_scale = pitch * randf_range(0.92, 1.08)
	p.volume_db = volume_db
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
