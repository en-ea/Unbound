extends Node3D
## A dropped item: pops out in an arc, lands and bobs, then flies to the player when they come
## near and goes into the Inventory (the HUD's pickup feed shows it).

const MAGNET_RANGE := 2.4
const GRAVITY := 14.0
const SOUNDS := {"pickup": preload("res://assets/sounds/pickup.wav"), "rare": preload("res://assets/sounds/rare.wav")}

var item := ""
var _velocity := Vector3.ZERO
var _ground_y := 0.0
var _player: Node3D
var _age := 0.0
var _landed := false
var _collecting := false
var _mesh: MeshInstance3D


func launch(item_id: String, from: Vector3, velocity: Vector3, ground_y: float, player: Node3D) -> void:
	item = item_id
	_velocity = velocity
	_ground_y = ground_y
	_player = player
	global_position = from
	_mesh = make_mesh(item)
	_mesh.scale = Vector3.ONE * 1.3
	add_child(_mesh)
	if Items.rarity_of(item) == Items.Rarity.RARE:
		_add_sparkle()


func _process(delta: float) -> void:
	_age += delta
	var target := _player.global_position + Vector3(0, 1.0, 0)
	if _collecting:
		var to := target - global_position
		if to.length() < 0.35:
			_collect()
			return
		global_position += to.normalized() * minf(to.length(), (6.0 + _age * 10.0) * delta)
		return
	if not _landed:
		_velocity.y -= GRAVITY * delta
		global_position += _velocity * delta
		if global_position.y <= _ground_y + 0.15 and _velocity.y < 0.0:
			global_position.y = _ground_y + 0.15
			_landed = true
	else:
		_mesh.position.y = 0.08 + sin(_age * 3.0) * 0.05
	_mesh.rotation.y += delta * 1.5
	if _age > 0.5 and global_position.distance_to(_player.global_position) < MAGNET_RANGE:
		_collecting = true


func _collect() -> void:
	Inventory.add(item, 1)
	var rare := Items.rarity_of(item) != Items.Rarity.COMMON
	var sound := AudioStreamPlayer.new()
	sound.stream = SOUNDS["rare" if rare else "pickup"]
	sound.volume_db = -8.0 if not rare else -4.0
	sound.pitch_scale = randf_range(0.95, 1.1)
	get_parent().add_child(sound)
	sound.play()
	sound.finished.connect(sound.queue_free)
	queue_free()


func _add_sparkle() -> void:
	var p := CPUParticles3D.new()
	p.amount = 8
	p.lifetime = 0.9
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25
	p.gravity = Vector3(0, 0.5, 0)
	p.initial_velocity_max = 0.2
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.05
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Items.color_of(item) * 2.5
	quad.material = mat
	p.mesh = quad
	add_child(p)


## The item's model as a node (also used for warm-up).
static func make_mesh(item_id: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Items.mesh(item_id)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
