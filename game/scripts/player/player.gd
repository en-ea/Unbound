extends CharacterBody3D
## Moves the player from Controls input. The model and animations live in CharacterVisual.

const WALK_SPEED := 1.6
const RUN_SPEED := 5.4
const RUN_THRESHOLD := 0.75
const ACCEL := 12.0
const TURN_SPEED := 12.0
const GRAVITY := 22.0
const ROLL_SPEED := 7.6        # at the start; it eases down a little by the end (about 4 m in all)
const ROLL_TIME := 0.7
const ROLL_COOLDOWN := 0.25    # a short breath between rolls, so it can't be spammed

signal verb_changed(verb: String)       # what the action button does right now
signal health_changed(health: int, max_health: int)
signal knocked_out
signal got_up

const MAX_HEALTH := Balance.HEARTS
const REGEN_DELAY := Balance.REGEN_DELAY
const REGEN_EVERY := Balance.REGEN_EVERY
const DOWN_TIME := 3.2         # lying on the ground before getting back up at the start
const INVULNERABLE := 1.2      # after a hit, enemies can't hurt you again for a moment

@onready var visual: CharacterVisual = $Visual
@onready var gatherer: Node = $Gatherer
@onready var fighter: Node = $Fighter

var verb := ""
var stamina: Stamina
var sprinting := false
var _roll := 0.0
var _roll_rest := 0.0
var _roll_dir := Vector3.FORWARD
var _stun := 0.0
var _knock := Vector3.ZERO
var health := MAX_HEALTH
var spawn_point := Vector3.ZERO
const TOOL_DROP := preload("res://scripts/world/tool_drop.gd")

var _station: Node3D = null     # a workbench (or other "interactable") in reach
var _since_hit := 99.0
var _regen := 0.0
var _down := 0.0
var _safe := 0.0


func is_rolling() -> bool:
	return _roll > 0.0


## Heavy attack (the Heavy button in a fight): a slow, big swing that costs stamina.
func heavy() -> void:
	if _roll > 0.0 or _stun > 0.0 or _down > 0.0 or fighter.is_busy() or Controls.locked:
		return
	if stamina.use("heavy"):
		fighter.heavy()


## The action button: fight if an enemy is in reach, otherwise gather.
func act() -> void:
	if _roll > 0.0 or _stun > 0.0:
		return
	if fighter.verb != "":
		fighter.attack()
	elif is_instance_valid(_station):
		_station.interact()
	else:
		gatherer.act()


func _ready() -> void:
	add_to_group("player")
	stamina = Stamina.new()
	stamina.name = "Stamina"
	add_child(stamina)
	_ready_drops()


func _ready_drops() -> void:
	Gear.tool_dropped.connect(func(slot: String, t: Dictionary) -> void:
		TOOL_DROP.spawn(get_parent(), slot, t, global_position, self, false))


## The closest node in group "interactable" whose `reach` we are inside (it has `verb` and interact()).
func _nearest_station() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for n: Node3D in get_tree().get_nodes_in_group("interactable"):
		var d := Vector2(n.global_position.x - global_position.x, n.global_position.z - global_position.z).length()
		if d < n.reach and d < best_d and absf(n.global_position.y - global_position.y) < 3.0:
			best_d = d
			best = n
	return best


## Dodge roll: a quick roll in the stick direction (or forward). Charges miss you mid-roll.
func roll() -> void:
	if _roll > 0.0 or _roll_rest > 0.0 or _stun > 0.0 or gatherer.is_busy() or Controls.locked:
		return
	if not stamina.use("roll"):
		return
	fighter.cancel()        # a roll cuts a swing short
	var m := Controls.get_move()
	if m.length() > 0.1:
		_roll_dir = Vector3(m.x, 0, m.y).normalized()
	else:
		_roll_dir = Vector3(sin(visual.rotation.y), 0, cos(visual.rotation.y))
	visual.rotation.y = atan2(_roll_dir.x, _roll_dir.z)
	visual.play_action("Roll", visual.animation_length("Roll") / ROLL_TIME)
	_roll = ROLL_TIME
	$Sounds.play_roll()
	$Effects.burst(true)


## Something hit us (a boar charge): pushed back and briefly stunned. No damage for now.
func knockback(push: Vector3) -> void:
	if _roll > 0.0 or _down > 0.0 or _safe > 0.0:
		return
	_knock = push
	_stun = 0.45
	visual.play_action("Hit_Chest", 1.0)
	visual.flash()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_E, KEY_SPACE]:
			act()
		elif event.physical_keycode in [KEY_Q, KEY_CTRL]:
			roll()
		elif event.physical_keycode == KEY_F:
			heavy()


## The action: something hurts the player (a boar charge). At 0 hearts they are knocked down
## and get back up at the start with full hearts; nothing is lost.
## Enemies only go after a player who is up and not blinking from a recent hit.
func can_be_targeted() -> bool:
	return _down <= 0.0 and _safe <= 0.0 and _roll <= 0.0


## The action: eat a food from the Bag (hearts back, and maybe a buff).
func eat(item: String) -> void:
	var hearts := Food.eat(item)
	if hearts > 0 and _down <= 0.0:
		health = mini(health + hearts, MAX_HEALTH)
		health_changed.emit(health, MAX_HEALTH)


func heal_full() -> void:
	if _down <= 0.0:
		health = MAX_HEALTH
		health_changed.emit(health, MAX_HEALTH)


func take_damage(amount: int) -> void:
	if _roll > 0.0 or _down > 0.0 or _safe > 0.0:
		return
	if Food.has("sturdy"):
		amount = maxi(amount - Balance.STURDY_BLOCK, 1)
	health = maxi(health - amount, 0)
	_safe = INVULNERABLE
	_since_hit = 0.0
	health_changed.emit(health, MAX_HEALTH)
	if health == 0:
		_down = DOWN_TIME
		_stun = 0.0
		visual.play_action("Death01", 1.0)
		knocked_out.emit()


func _physics_process(delta: float) -> void:
	_since_hit += delta
	_roll_rest = maxf(_roll_rest - delta, 0.0)
	if _safe > 0.0:
		_safe -= delta
		visual.visible = _safe <= 0.0 or fmod(_safe, 0.2) > 0.1      # blink while protected
	if health < MAX_HEALTH and _since_hit > REGEN_DELAY and _down <= 0.0:
		_regen += delta
		if _regen >= REGEN_EVERY:
			_regen = 0.0
			health += 1
			health_changed.emit(health, MAX_HEALTH)
	if _down > 0.0:
		_down -= delta
		velocity = Vector3.ZERO
		if _down <= 0.0:
			global_position = spawn_point
			health = MAX_HEALTH
			_safe = INVULNERABLE
			health_changed.emit(health, MAX_HEALTH)
			stamina.refill()
			get_tree().call_group("camera_rig", "snap")
			got_up.emit()
		return
	_station = _nearest_station()
	var new_verb: String = fighter.verb
	if new_verb == "":
		new_verb = _station.verb if _station else gatherer.verb
	if new_verb != verb:
		verb = new_verb
		verb_changed.emit(verb)
	if _roll > 0.0 or _stun > 0.0:
		sprinting = false
		_special_move(delta)
		return
	# Gathering roots you in place; swinging the sword only slows you (and steps you in).
	var swinging: bool = fighter.is_busy()
	var move := Controls.get_move() if not gatherer.is_busy() else Vector2.ZERO
	if swinging:
		move *= 0.45
	var strength := move.length()
	var target_speed := 0.0
	# Holding Roll after the roll keeps you sprinting while stamina lasts.
	var was_sprinting := sprinting
	sprinting = Controls.is_sprint_held() and strength >= RUN_THRESHOLD and not swinging and stamina.can("sprint")
	if sprinting and not was_sprinting:
		$Effects.burst(true)              # a kick of dust as you take off
	if sprinting:
		stamina.drain(delta)
	if strength > 0.1:
		var run := Balance.SPRINT_SPEED if sprinting else RUN_SPEED
		target_speed = run * (Balance.SWIFT_SPEED if Food.has("swift") else 1.0) if strength >= RUN_THRESHOLD else WALK_SPEED * remap(strength, 0.1, RUN_THRESHOLD, 0.6, 1.0)
	# The camera never rotates, so screen up is world -Z.
	var dir := Vector3(move.x, 0.0, move.y).normalized()
	var flat := Vector3(velocity.x, 0.0, velocity.z).lerp(dir * target_speed, clampf(ACCEL * delta, 0.0, 1.0))
	flat += fighter.step_velocity()
	velocity.x = flat.x
	velocity.z = flat.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()

	var speed := Vector2(velocity.x, velocity.z).length()
	if strength > 0.1 and not swinging:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(dir.x, dir.z), clampf(TURN_SPEED * delta, 0.0, 1.0))
	visual.play_motion(speed)


## Rolling (steerable with the stick) or being knocked back (forced).
func _special_move(delta: float) -> void:
	var flat: Vector3
	if _roll > 0.0:
		_roll -= delta
		if _roll <= 0.0:
			_roll_rest = ROLL_COOLDOWN
			$Effects.burst(false)             # a puff where you land
		var m := Controls.get_move()
		if m.length() > 0.3:                   # a little steering, not a full turn
			_roll_dir = _roll_dir.slerp(Vector3(m.x, 0, m.y).normalized(), clampf(3.0 * delta, 0.0, 1.0)).normalized()
			visual.rotation.y = atan2(_roll_dir.x, _roll_dir.z)
		var t := 1.0 - _roll / ROLL_TIME       # 0 at the start of the roll, 1 at the end
		flat = _roll_dir * ROLL_SPEED * lerpf(1.0, 0.6, t * t)
	else:
		_stun -= delta
		flat = _knock
		_knock = _knock.lerp(Vector3.ZERO, clampf(6.0 * delta, 0.0, 1.0))
	velocity = Vector3(flat.x, 0.0 if is_on_floor() else velocity.y - GRAVITY * delta, flat.z)
	move_and_slide()
