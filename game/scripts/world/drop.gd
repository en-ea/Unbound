extends Node3D
## A dropped item: pops out in an arc, bounces, bobs a moment, then flies to the player by itself
## and goes into the Inventory with a little burst. Uncommon and rare items stand in a light beam.
## Pickups in quick succession play at rising pitch.

const MAGNET_RANGE := 2.4
const AUTO_COLLECT := 0.9      # seconds after landing before it flies to you anyway
const AUTO_RANGE := 9.0

static var _chain := 0         # pickups in a row (for the rising pitch)
static var _last_pick := 0.0
const GRAVITY := 14.0
const SOUNDS := {"pickup": preload("res://assets/sounds/pickup.wav"), "rare": preload("res://assets/sounds/rare.wav")}

var item := ""
var _velocity := Vector3.ZERO
var _ground_y := 0.0
var _player: Node3D
var _age := 0.0
var _landed := false
var _bounced := false
var _landed_at := 0.0
var _delay := 0.0
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
	_delay = randf_range(0.0, 0.35)
	if Items.rarity_of(item) == Items.Rarity.RARE:
		_add_sparkle()
	if Items.rarity_of(item) != Items.Rarity.COMMON:
		add_child(make_beam(item))


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
			if not _bounced:          # one small hop before it settles
				_bounced = true
				_velocity = Vector3(_velocity.x * 0.4, -_velocity.y * 0.35, _velocity.z * 0.4)
			else:
				_landed = true
				_landed_at = _age
	else:
		_mesh.position.y = 0.08 + sin(_age * 3.0) * 0.05
	_mesh.rotation.y += delta * 1.5
	var near := global_position.distance_to(_player.global_position)
	if _age > 0.5 and near < MAGNET_RANGE:
		_collecting = true
	elif _landed and _age - _landed_at > AUTO_COLLECT + _delay and near < AUTO_RANGE:
		_collecting = true


func _collect() -> void:
	Inventory.add(item, 1)
	var rare := Items.rarity_of(item) != Items.Rarity.COMMON
	var now := Time.get_ticks_msec() / 1000.0
	_chain = _chain + 1 if now - _last_pick < 0.6 else 0
	_last_pick = now
	var sound := AudioStreamPlayer.new()
	sound.stream = SOUNDS["rare" if rare else "pickup"]
	sound.volume_db = -8.0 if not rare else -4.0
	sound.pitch_scale = (1.0 + minf(_chain, 8) * 0.06) * randf_range(0.98, 1.03)
	get_parent().add_child(sound)
	sound.play()
	sound.finished.connect(sound.queue_free)
	_burst(rare)
	queue_free()


## A quick puff of sparks in the item's colour where it reaches the player.
func _burst(rare: bool) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 14 if rare else 7
	p.lifetime = 0.45
	p.spread = 180.0
	p.gravity = Vector3(0, -3, 0)
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 2.6
	p.mesh = _spark_quad(Items.color_of(item).lightened(0.3) * (2.2 if rare else 1.5), 0.06)
	get_parent().add_child(p)
	p.global_position = global_position
	p.emitting = true
	p.finished.connect(p.queue_free)


## A soft vertical beam in the rarity colour, so good drops stand out (also used for warm-up).
static func make_beam(item: String) -> MeshInstance3D:
	var beam := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.35, 2.4)
	quad.center_offset = Vector3(0, 1.2, 0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.0))
	grad.add_point(0.5, Color(1, 1, 1, 0.55))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 32
	tex.height = 4
	mat.albedo_texture = tex
	var c: Color = Items.RARITY_COLORS[Items.rarity_of(item)]
	mat.albedo_color = Color(c.r, c.g, c.b, 1.0)
	quad.material = mat
	beam.mesh = quad
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return beam


static func _spark_quad(color: Color, size: float) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = color
	quad.material = mat
	return quad


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
