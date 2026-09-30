extends Node3D
## A crow, come for a body left alone (carcass.gd): it glides down out of the sky in circles, lands beside
## the body, hops and pecks (the body rots faster), and bursts away cawing when you come close. Built from
## a few shapes; the wings flap in code.

const FLEE_RANGE := 8.0
const BLACK := Color(0.07, 0.07, 0.09)

var carcass: Node3D
var player: Node3D
var _state := "arrive"
var _t := 0.0
var _spot := Vector3.ZERO           # where it lands, beside the body
var _angle := 0.0
var _wings: Array[Node3D] = []
var _body: Node3D
var _audio: AudioStreamPlayer3D
var _hop := 0.0
var _away := Vector3.ZERO


func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BLACK
	mat.roughness = 0.6
	_part(BoxMesh.new(), Vector3(0.14, 0.13, 0.32), Vector3(0, 0.16, 0), mat)                  # body
	_part(SphereMesh.new(), Vector3(0.12, 0.12, 0.12), Vector3(0, 0.26, 0.17), mat)             # head
	var beak := StandardMaterial3D.new()
	beak.albedo_color = Color(0.22, 0.2, 0.2)
	_part(PrismMesh.new(), Vector3(0.04, 0.09, 0.03), Vector3(0, 0.25, 0.26), beak, Vector3(PI * 0.5, 0, 0))
	_part(BoxMesh.new(), Vector3(0.1, 0.02, 0.14), Vector3(0, 0.17, -0.2), mat)                # tail
	for s in [1.0, -1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(s * 0.06, 0.2, 0.02)
		_body.add_child(pivot)
		var wing := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(0.34, 0.015, 0.2)
		wing.mesh = m
		wing.material_override = mat
		wing.position = Vector3(s * 0.17, 0, 0)
		wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(wing)
		pivot.set_meta("side", s)
		_wings.append(pivot)
	_audio = AudioStreamPlayer3D.new()
	_audio.unit_size = 9.0
	add_child(_audio)
	_angle = randf() * TAU
	var c: Vector3 = carcass.global_position
	_spot = c + Vector3(cos(_angle), 0, sin(_angle)) * randf_range(0.8, 1.4)
	global_position = c + Vector3(cos(_angle) * 18.0, 14.0 + randf() * 4.0, sin(_angle) * 18.0)
	_caw(0.5)


func _part(mesh: PrimitiveMesh, size: Vector3, at: Vector3, mat: Material, turn := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	if mesh is BoxMesh:
		mesh.size = size
	elif mesh is SphereMesh:
		mesh.radius = size.x * 0.5
		mesh.height = size.y
		mesh.radial_segments = 6
		mesh.rings = 3
	elif mesh is PrismMesh:
		mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.rotation = turn
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(mi)


func _physics_process(delta: float) -> void:
	_t += delta
	var flap := 0.0
	var gone: bool = not is_instance_valid(carcass) or carcass.is_queued_for_deletion() or carcass.dragged
	if _state != "flee" and (gone or (is_instance_valid(player) and player.global_position.distance_to(global_position) < FLEE_RANGE)):
		_state = "flee"
		_t = 0.0
		_away = (global_position - (player.global_position if is_instance_valid(player) else global_position)).normalized()
		_away.y = 0.0
		if _away.length() < 0.1:
			_away = Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
		_caw(1.0)
	match _state:
		"arrive":            # spiral down onto the spot
			_angle += delta * 0.9
			var k := clampf(_t / 4.0, 0.0, 1.0)
			var r := lerpf(18.0, 0.0, k)
			var c: Vector3 = carcass.global_position
			var target := _spot + Vector3(cos(_angle) * r, lerpf(14.0, 0.0, k * k), sin(_angle) * r)
			var move := target - global_position
			global_position = target
			if move.length() > 0.01:
				rotation.y = atan2(move.x, move.z)
			flap = sin(_t * 18.0) * 0.8 if k < 0.85 else sin(_t * 30.0) * 0.5
			if k >= 1.0:
				_state = "peck"
				_t = 0.0
				var to := c - global_position
				rotation.y = atan2(to.x, to.z)
		"peck":              # hop about and peck at the body
			carcass.nibble(delta * 0.8)
			_hop -= delta
			_body.position.y = maxf(_body.position.y - delta * 1.5, 0.0)
			_body.rotation.x = maxf(sin(_t * 9.0), 0.0) * 0.6                    # the peck
			if _hop <= 0.0:
				_hop = randf_range(1.0, 3.0)
				_body.position.y = 0.12
				rotation.y += randf_range(-0.8, 0.8)
				if randf() < 0.3:
					_caw(randf_range(0.4, 0.55))
			flap = -1.2                                                        # folded
		"flee":
			global_position += (_away * 7.0 + Vector3.UP * 5.0) * delta
			rotation.y = atan2(_away.x, _away.z)
			_body.rotation.x = -0.3
			flap = sin(_t * 22.0) * 0.9
			if _t > 4.0:
				if is_instance_valid(carcass) and not carcass.is_queued_for_deletion():
					carcass.set("_crows_sent", false)                         # they'll be back
				queue_free()
	for w in _wings:
		w.rotation.z = flap * float(w.get_meta("side"))


func _caw(pitch: float) -> void:
	_audio.stream = load("res://assets/sounds/bird_%d.wav" % (randi() % 6))
	_audio.pitch_scale = pitch
	_audio.volume_db = -2.0
	_audio.play()
