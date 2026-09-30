extends Node3D
## The ox cart (the first transport): a shaggy Dray Ox pulling a two-wheeled cart. "Ride" to sit on the
## bench and drive with the stick (the ox turns and plods, steady rather than quick); "Get off" to step
## down. Drag a body to it and "Load" (three fit; the Duskmaw fills the cart), then sell the lot at the
## butcher's rack. It goes through region gates with you. Where it is and what it holds: Hunting.cart.
## This node sits on the cart's axle (what you walk up to); the ox is a body of its own in front.

const OX_MODEL := preload("res://assets/creatures/ox.glb")
const CART_MODEL := preload("res://assets/creatures/cart.glb")
const SOLID_SHADER := preload("res://shaders/foliage_solid.gdshader")
const HITCH := 3.1              # axle to the ox's middle
const TURN := 1.5               # radians a second at full speed
const WHEEL_R := 0.55
const SEAT := Vector3(0.0, 0.62, 0.62)       # where you sit (the model's feet), on the cart
const LOAD_SPOTS := [Vector3(0.0, 0.9, 0.35), Vector3(0.0, 0.9, -0.3), Vector3(0.0, 0.9, -0.8)]

var player: Node3D
var verb := "Ride"
var reach := 2.8
var _shape: WorldShape
var _ox: CharacterBody3D
var _ox_visual: BoarVisual
var _cart: Node3D
var _wheels: Array[Node3D] = []
var _speed := 0.0
var _heading := 0.0             # the ox's facing
var _load_nodes: Array[Node3D] = []
var _save_tick := 0.0
var _audio: AudioStreamPlayer3D


func build(shape: WorldShape) -> void:
	_shape = shape
	add_to_group("interactable")
	add_to_group("ox_cart")
	_cart = CART_MODEL.instantiate()
	add_child(_cart)
	_solid(_cart)
	for n in ["Wheel_L", "Wheel_R"]:
		_wheels.append(_cart.find_child(n, true, false) as Node3D)
	_ox = CharacterBody3D.new()
	_ox.top_level = true
	_ox.floor_snap_length = 0.6
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.1, 1.6, 2.2)
	col.shape = box
	col.position.y = 1.0
	_ox.add_child(col)
	_ox_visual = BoarVisual.new()
	_ox_visual.model_scene = OX_MODEL
	_ox_visual.paws = false
	_ox_visual.bar_height = -10.0
	_ox.add_child(_ox_visual)
	add_child(_ox)
	_audio = AudioStreamPlayer3D.new()
	_audio.stream = preload("res://assets/sounds/boar_snort.wav")
	_audio.unit_size = 8.0
	_ox.add_child(_audio)
	var at: Vector2 = Hunting.cart["at"]
	_heading = Hunting.cart["yaw"]
	var fwd := Vector3(sin(_heading), 0, cos(_heading))
	var axle := Vector3(at.x, shape.height_at(at.x, at.y), at.y)
	global_position = axle
	_ox.global_position = axle + fwd * HITCH + Vector3(0, 0.3, 0)
	_ox.rotation.y = _heading
	_follow(0.0)
	_show_load()
	Hunting.changed.connect(_show_load)
	if Hunting.riding:                        # came through the gate on it
		Hunting.riding = false
		(func() -> void: player.hauling.mount(self)).call_deferred()


func yaw() -> float:
	return rotation.y


## Where the rider's feet go (the Sitting pose puts the hips on the bench).
func seat() -> Vector3:
	return global_transform * SEAT


## Where you step down: beside the bench.
func side_spot() -> Vector3:
	var p := global_transform * Vector3(-1.4, 0.0, 0.6)
	p.y = _shape.height_at(p.x, p.z) + 0.2
	return p


func rider_left() -> void:
	_speed = 0.0


func interact() -> void:
	var h: Variant = player.hauling
	if h.carrying:
		load_body(h.carrying)
	else:
		h.mount(self)
		_moo(0.9)
		get_tree().call_group("hud", "hint", "On the cart. Steer with the stick; Get off to step down.")


## The action: a body goes in the bed.
func load_body(body: Node3D) -> void:
	var slots_needed := 3 if Hunting.KINDS[body.kind]["size"] == "huge" else 1
	if Hunting.cart["load"].size() + slots_needed > Balance.HUNT["cart_slots"]:
		get_tree().call_group("hud", "hint", "The cart's full. Sell the load at the butcher's rack.")
		return
	player.hauling.let_go_of(body)
	for i in slots_needed:
		Hunting.load_cart(body.kind if i == 0 else "_", body.age)
	body.queue_free()


func _physics_process(delta: float) -> void:
	var driving: bool = is_instance_valid(player) and player.hauling.riding == self
	var want := 0.0
	if driving:
		var m := Controls.get_move()
		if m.length() > 0.15:
			var target := atan2(m.x, m.y)
			var diff := wrapf(target - _heading, -PI, PI)
			if absf(diff) > PI * 0.75:            # pulling back: the ox stops rather than turn on the spot
				want = 0.0
			else:
				want = Balance.HUNT["cart_speed"] * clampf(m.length(), 0.0, 1.0)
				_heading += clampf(diff, -TURN * delta, TURN * delta) * clampf(_speed / 2.0 + 0.3, 0.0, 1.0)
	_speed = move_toward(_speed, want, delta * (3.0 if want > _speed else 5.0))
	var fwd := Vector3(sin(_heading), 0, cos(_heading))
	_ox.rotation.y = _heading
	_ox.velocity = Vector3(fwd.x * _speed, _ox.velocity.y - 20.0 * delta if not _ox.is_on_floor() else 0.0, fwd.z * _speed)
	_ox.move_and_slide()
	if _speed > 0.1 and _ox.is_on_wall():
		_speed *= 0.5
	_ox_visual.speed = Vector2(_ox.velocity.x, _ox.velocity.z).length()
	_follow(delta)
	for b in Hunting.cart["load"]:
		b["age"] += delta
	_save_tick -= delta
	if _save_tick <= 0.0:
		_save_tick = 1.0
		Hunting.cart["at"] = Vector2(global_position.x, global_position.z)
		Hunting.cart["yaw"] = _heading
		Hunting.cart["region"] = Region.current
		_rot_check()
	verb = "Load" if is_instance_valid(player) and player.hauling.carrying else "Ride"


## The cart trails the ox: the axle keeps its distance from the hitch, the wheels roll.
func _follow(delta: float) -> void:
	var hitch := _ox.global_position
	var axle := global_position
	var to := Vector3(hitch.x - axle.x, 0, hitch.z - axle.z)
	if to.length() < 0.01:
		to = Vector3(sin(_heading), 0, cos(_heading))
	var dir := to.normalized()
	var new_axle := hitch - dir * HITCH
	new_axle.y = _shape.height_at(new_axle.x, new_axle.z)
	var moved := Vector2(new_axle.x - axle.x, new_axle.z - axle.z).length()
	global_position = new_axle
	rotation.y = atan2(dir.x, dir.z)
	for w in _wheels:
		w.rotation.x += moved / WHEEL_R


## Bodies in the bed rot too; rotten ones fall out.
func _rot_check() -> void:
	var before: int = Hunting.cart["load"].size()
	Hunting.cart["load"] = Hunting.cart["load"].filter(func(b: Dictionary) -> bool:
		return b["kind"] == "_" or Hunting.freshness(b["age"]) > 0.0)
	if Hunting.cart["load"].size() != before:
		Hunting.changed.emit()


## What's in the bed, shown as the bodies (small, lying across it).
func _show_load() -> void:
	for n in _load_nodes:
		n.queue_free()
	_load_nodes.clear()
	var looks: Dictionary = preload("res://scripts/world/carcass.gd").LOOKS
	var i := 0
	for b: Dictionary in Hunting.cart["load"]:
		if b["kind"] == "_":
			i += 1
			continue
		var v := Node3D.new()
		v.set_script(load(looks[b["kind"]]["visual"]))
		var huge: bool = Hunting.KINDS[b["kind"]]["size"] == "huge"
		v.scale = Vector3.ONE * (0.75 if huge else looks[b["kind"]]["scale"] * 0.8)
		add_child(v)
		v.position = LOAD_SPOTS[1] if huge else LOAD_SPOTS[mini(i, 2)]
		v.rotation.y = PI * 0.5
		v.set("mode", "dead")
		_load_nodes.append(v)
		i += 1


func _solid(root: Node) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var mat := ShaderMaterial.new()
			mat.shader = SOLID_SHADER
			mat.set_shader_parameter("albedo", Color.WHITE)
			mat.set_shader_parameter("sway", 0.0)
			mi.set_surface_override_material(s, mat)


func _moo(pitch: float) -> void:
	_audio.pitch_scale = pitch * 0.55
	_audio.play()
