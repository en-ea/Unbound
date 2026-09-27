extends Node3D
## A dropped item: pops out in an arc, bounces, bobs a moment, then flies to the player by itself
## and goes into the Inventory with a little burst. Uncommon and rare items stand in a light beam.
## Pickups in quick succession play at rising pitch.

const MAGNET_RANGE := 2.4
const GLOW_SHADER := preload("res://shaders/loot_glow.gdshader")
const AUTO_COLLECT := 0.9      # seconds after landing before it flies to you anyway
const AUTO_RANGE := 9.0

static var _chain := 0         # pickups in a row (for the rising pitch)
static var _last_pick := 0.0
static var _full_hint_at := -10.0
static var _popups := {}       # item -> {"label": Label3D, "count": int, "at": seconds}
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
var _shadow: MeshInstance3D
var _size := 1.5


func launch(item_id: String, from: Vector3, velocity: Vector3, ground_y: float, player: Node3D) -> void:
	item = item_id
	_velocity = velocity
	_ground_y = ground_y
	_player = player
	global_position = from
	_mesh = make_mesh(item)
	_mesh.scale = Vector3.ONE * _size
	_mesh.rotation.x = 0.35          # tipped a little toward the camera so its shape reads
	add_child(_mesh)
	_shadow = make_shadow()
	add_child(_shadow)
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
				_squash()
			else:
				_landed = true
				_landed_at = _age
				_squash()
	else:
		_mesh.position.y = 0.08 + sin(_age * 3.0) * 0.05
	_mesh.rotation.y += delta * 1.5
	# The shadow stays on the ground, smaller and fainter the higher the item is.
	var height := global_position.y - _ground_y
	_shadow.global_position = Vector3(global_position.x, _ground_y + 0.03, global_position.z)
	_shadow.scale = Vector3.ONE * clampf(1.0 - height * 0.25, 0.4, 1.0)
	var near := global_position.distance_to(_player.global_position)
	var wants := (_age > 0.5 and near < MAGNET_RANGE) or (_landed and _age - _landed_at > AUTO_COLLECT + _delay and near < AUTO_RANGE)
	if wants and Inventory.has_room(item):
		_collecting = true
	elif wants and near < MAGNET_RANGE:
		var now := Time.get_ticks_msec() / 1000.0
		if now - _full_hint_at > 3.0:          # a full bag: new kinds of item stay on the ground
			_full_hint_at = now
			_player.get_tree().call_group("hud", "hint", "Bag is full (craft a bigger bag)")


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
	_popup(now)
	queue_free()


## "+3 Wood" floating up above the player; quick pickups of the same item add to one popup.
func _popup(now: float) -> void:
	var entry: Dictionary = _popups.get(item, {})
	var old: Variant = entry.get("label")          # may have faded out and been freed already
	var label: Label3D = old if is_instance_valid(old) else null
	if label and now - entry["at"] < 0.9:
		entry["count"] += 1
		entry["at"] = now
	else:
		label = Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.font_size = 64
		label.outline_size = 16
		label.pixel_size = 0.005
		label.outline_modulate = Color(0.08, 0.06, 0.1, 0.85)
		var rarity := Items.rarity_of(item)
		label.modulate = Color(1.0, 0.96, 0.86) if rarity == Items.Rarity.COMMON else Items.RARITY_COLORS[rarity]
		_player.get_parent().add_child(label)
		entry = {"label": label, "count": 1, "at": now}
		_popups[item] = entry
		label.set_meta("slot", _popups.size() % 3)
	label.text = "+%d %s" % [entry["count"], Items.name_of(item)]
	label.global_position = _player.global_position + Vector3(0.0, 2.3 + label.get_meta("slot") * 0.32, 0.0)
	label.scale = Vector3.ONE * 1.25
	if label.has_meta("tween"):
		(label.get_meta("tween") as Tween).kill()
	var t := label.create_tween()
	label.set_meta("tween", t)
	t.tween_property(label, "scale", Vector3.ONE, 0.15)
	t.tween_interval(0.6)
	t.set_parallel()
	t.tween_property(label, "position:y", label.position.y + 0.6, 0.7)
	t.tween_property(label, "modulate:a", 0.0, 0.7)
	t.tween_property(label, "outline_modulate:a", 0.0, 0.7)
	t.chain().tween_callback(label.queue_free)


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


## A soft light beam with a pool of light under it, in the rarity colour, so good drops stand out
## (also used for warm-up).
static func make_beam(item: String) -> Node3D:
	var root := Node3D.new()
	var c: Color = Items.RARITY_COLORS[Items.rarity_of(item)]
	c.a = 1.0
	for disc in [false, true]:
		var mi := MeshInstance3D.new()
		var quad := QuadMesh.new()
		if disc:
			quad.size = Vector2.ONE * 1.1
			quad.orientation = PlaneMesh.FACE_Y
			mi.position.y = -0.12
		else:
			quad.size = Vector2(0.5, 1.8)
			quad.center_offset = Vector3(0, 0.8, 0)
		var mat := ShaderMaterial.new()
		mat.shader = GLOW_SHADER
		mat.set_shader_parameter("color", c)
		mat.set_shader_parameter("disc", disc)
		mat.set_shader_parameter("strength", 0.9 if Items.rarity_of(item) == Items.Rarity.RARE else 0.6)
		quad.material = mat
		mi.mesh = quad
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	return root


## A soft round shadow under the item, so it sits on the ground (also used for warm-up).
static func make_shadow() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.45
	quad.orientation = PlaneMesh.FACE_Y
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.5))
	grad.set_color(1, Color(0, 0, 0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 32
	tex.height = 32
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	quad.material = mat
	mi.mesh = quad
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## A quick squash and stretch when it hits the ground.
func _squash() -> void:
	var t := _mesh.create_tween()
	t.tween_property(_mesh, "scale", Vector3(1.3, 0.7, 1.3) * _size, 0.06)
	t.tween_property(_mesh, "scale", Vector3.ONE * _size, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
