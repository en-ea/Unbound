extends CharacterBody3D
## Your tamed elk (state in Hunting.elk; tamed in the Highlands, see creatures/stag.gd's Calm). On foot,
## it follows you at a distance and comes with you through the gates. Ride it (the action button) and
## steer with the stick; hold sprint to gallop. Get off steps you down beside it. Uses the hauling
## "riding" seat the ox cart uses (player/hauling.gd).

const WALK := 4.5
const RUN := 9.0
const GALLOP := 13.5
const TURN := 3.2                 # radians a second
const FOLLOW_FAR := 9.0           # on foot: it trots after you past this
const FOLLOW_NEAR := 4.0
const SEAT := Vector3(0.0, 1.12, 0.02)
const GRAVITY := 20.0

var player: CharacterBody3D
var verb := "Ride"
var reach := 2.6
var _shape: WorldShape
var _visual: StagVisual
var _heading := 0.0
var _speed := 0.0
var _save_tick := 0.0


func build(shape: WorldShape, at: Vector2, yaw: float) -> void:
	_shape = shape
	add_to_group("interactable")
	add_to_group("elk")
	collision_layer = 0                      # it doesn't block you (or itself on you)
	collision_mask = 1
	floor_snap_length = 0.6
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 1.4, 1.5)
	col.shape = box
	col.position.y = 0.95
	add_child(col)
	_visual = StagVisual.new()
	_visual.bar_height = -10.0
	add_child(_visual)
	var blanket := MeshInstance3D.new()      # a saddle blanket: it's yours
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.62, 0.06, 0.62)
	blanket.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.42, 0.5)
	blanket.material_override = m
	blanket.position = Vector3(0, 1.5, 0.02)
	_visual.add_child(blanket)
	_heading = yaw
	global_position = Vector3(at.x, shape.height_at(at.x, at.y) + 0.3, at.y)
	rotation.y = _heading


func yaw() -> float:
	return _heading


func seat() -> Vector3:
	return global_transform * SEAT


func side_spot() -> Vector3:
	var p := global_transform * Vector3(-1.2, 0.0, 0.0)
	p.y = _shape.height_at(p.x, p.z) + 0.2
	return p


func rider_left() -> void:
	_speed = 0.0


func interact() -> void:
	player.hauling.mount(self)
	get_tree().call_group("hud", "hint", "Steer with the stick, hold sprint to gallop. Get off to step down.")


func _physics_process(delta: float) -> void:
	var ridden: bool = is_instance_valid(player) and player.hauling.riding == self
	var want := 0.0
	var dir := Vector3.ZERO
	if ridden:
		var m := Controls.get_move()
		if m.length() > 0.15:
			var target := atan2(m.x, m.y)
			var diff := wrapf(target - _heading, -PI, PI)
			_heading += clampf(diff, -TURN * delta, TURN * delta)
			want = (GALLOP if Controls.is_sprint_held() else RUN) * clampf(m.length(), 0.0, 1.0)
			if absf(diff) > PI * 0.6:
				want *= 0.3                       # turning round: slow down first
	elif is_instance_valid(player):
		var to := player.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d > 60.0:                          # left far behind (or a region change): it catches up
			var p := player.global_position - to.normalized() * 6.0
			global_position = Vector3(p.x, _shape.height_at(p.x, p.z) + 0.3, p.z)
		elif d > FOLLOW_FAR or (d > FOLLOW_NEAR and _speed > 0.1):
			var target := atan2(to.x, to.z)
			_heading += clampf(wrapf(target - _heading, -PI, PI), -TURN * delta, TURN * delta)
			want = RUN if d > 20.0 else WALK
	_speed = move_toward(_speed, want, delta * (6.0 if want > _speed else 9.0))
	dir = Vector3(sin(_heading), 0, cos(_heading))
	rotation.y = _heading
	velocity = Vector3(dir.x * _speed, velocity.y - GRAVITY * delta if not is_on_floor() else 0.0, dir.z * _speed)
	move_and_slide()
	if _speed > 0.5 and is_on_wall():
		_speed *= 0.6
	_visual.speed = Vector2(velocity.x, velocity.z).length()
	_visual.mode = "flee" if _speed > RUN + 0.5 else "walk"
	_save_tick -= delta
	if _save_tick <= 0.0:
		_save_tick = 1.0
		Hunting.elk = {"region": Region.current, "at": Vector2(global_position.x, global_position.z), "yaw": _heading}
