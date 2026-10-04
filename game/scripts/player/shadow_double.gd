class_name ShadowDouble
extends CharacterBody3D
## The Shade's Mirage: a double of you made of shadow (or, with Perfect Likeness, exactly you). Enemies
## near it go for it instead of you (it answers to everything they ask of a player: receive_attack,
## is_down...), and it swings its own blade at whatever is close. A few hits or its time ending and
## it bursts in shadow, hurting everyone round it. Kept hidden between uses (building one costs a moment).

const SHADER := preload("res://shaders/shadow_double.gdshader")
const SWING_EVERY := 1.0
const REACH := 2.4
const CHASE := 6.0
const SPEED := 3.2
const GRAVITY := 20.0
const BURST_RADIUS := 3.5
const BURST_POWER := 2.5
const SWING_POWER := 0.6
const SWINGS := ["Sword_Regular_A", "Sword_Regular_B"]

signal ended(double: ShadowDouble)

var real: CharacterBody3D            # the player it copies
var visual: CharacterVisual
var sneaking := false
var active := false
var life := 0.0
var health := 0
var _fooled := {}                    # enemy -> true (their `player` points here while it lasts)
var _swing := 0.0
var _step := 0
var _look := 0.0
var _mats: Array[ShaderMaterial] = []
var _taunt_tick := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	col.shape = cap
	col.position.y = 0.85
	add_child(col)
	visual = CharacterVisual.new()
	visual.name = "Visual"
	visual.wear_gear = true
	add_child(visual)
	visual.show_tool.call_deferred("sword")
	_park()


## Shadow (dark, glowing rim) or a perfect likeness of you.
func _set_look(perfect: bool) -> void:
	for mi in visual.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if perfect:
			m.material_override = null
		else:
			var sm := ShaderMaterial.new()
			sm.shader = SHADER
			m.material_override = sm
			_mats.append(sm)


func is_down() -> bool:
	return not active or health <= 0


func can_be_targeted() -> bool:
	return active and health > 0


func noise() -> float:
	return 1.0


## Something hits it: it shudders, and a few hits pop it.
func receive_attack(_attacker: Node3D, _damage: int, _push: Vector3) -> String:
	if not active:
		return "dodge"
	health -= 1
	visual.flash()
	ShadowFX.puff(get_parent(), global_position + Vector3(0, 1.0, 0), 0.5)
	if health <= 0:
		end()
	return "hit"


## Out it steps, where `at` is, facing `yaw`, for `seconds`, taking `hits`.
func appear(at: Vector3, yaw: float, seconds: float, hits: int, perfect: bool) -> void:
	_mats.clear()
	_set_look(perfect)
	global_position = at
	velocity = Vector3.ZERO
	visual.rotation.y = yaw
	life = seconds
	health = hits
	active = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	_swing = 0.4
	_fooled.clear()
	_taunt_tick = 0.0
	ShadowFX.puff(get_parent(), at + Vector3(0, 0.9, 0), 1.0)


## It's over: a burst of shadow that hurts everyone close, and the enemies it fooled look for you again.
func end(power := BURST_POWER) -> void:
	if not active:
		return
	active = false
	var at := global_position
	ShadowFX.burst(get_parent(), at, BURST_RADIUS)
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.is_alive() and (e as Node3D).global_position.distance_to(at) < BURST_RADIUS:
			e.take_hit(at, Gear.hit_damage(power)[0], 2.0)
	get_tree().call_group("camera_rig", "shake", 0.08)
	_release()
	ended.emit(self)
	_park()


func _release() -> void:
	for e: Node in _fooled:
		if is_instance_valid(e) and e.get("player") == self:
			e.set("player", real)
	_fooled.clear()


func _park() -> void:
	visible = false
	global_position = Vector3(0, -500, 0)
	process_mode = Node.PROCESS_MODE_DISABLED


## Enemies near it (that were after you) turn on it instead.
func taunt(radius: float) -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.is_alive() and e.get("player") == real and (e as Node3D).global_position.distance_to(global_position) < radius:
			e.set("player", self)
			_fooled[e] = true


func _physics_process(delta: float) -> void:
	if not active:
		return
	life -= delta
	for m in _mats:
		m.set_shader_parameter("fade", clampf(life / 0.6, 0.0, 1.0) if life < 0.6 else 1.0)
	if life <= 0.0:
		end()
		return
	_taunt_tick -= delta
	if _taunt_tick <= 0.0:
		_taunt_tick = 0.3
		taunt(real.abilities.shade.fool_radius())
	var foe: Node3D = null
	var best := CHASE
	for e in get_tree().get_nodes_in_group("enemy"):
		var d: float = (e as Node3D).global_position.distance_to(global_position)
		if e.is_alive() and d < best:
			best = d
			foe = e
	var flat := Vector3.ZERO
	if foe:
		var to := foe.global_position - global_position
		to.y = 0.0
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(to.x, to.z), clampf(10.0 * delta, 0.0, 1.0))
		if best > REACH:
			flat = to.normalized() * SPEED
		_swing -= delta
		if best <= REACH and _swing <= 0.0:
			_swing = SWING_EVERY
			visual.play_action(SWINGS[_step % 2], 1.3)
			_step += 1
			var target := foe
			get_tree().create_timer(0.25).timeout.connect(func() -> void:
				if active and is_instance_valid(target) and target.is_alive() \
						and target.global_position.distance_to(global_position) < REACH + 0.6:
					target.take_hit(global_position, Gear.hit_damage(SWING_POWER)[0]))
	velocity.x = flat.x
	velocity.z = flat.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	visual.play_motion(flat.length())
