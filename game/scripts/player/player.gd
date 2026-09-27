extends CharacterBody3D
## Moves the player from Controls input. The model and animations live in CharacterVisual.

const WALK_SPEED := 1.6
const RUN_SPEED := 5.4
const RUN_THRESHOLD := 0.75
const ACCEL := 12.0
const TURN_SPEED := 12.0
const GRAVITY := 22.0
const ROLL_SPEED := 7.5
const ROLL_TIME := 0.55

signal verb_changed(verb: String)       # what the action button does right now
signal health_changed(health: int, max_health: int)

const MAX_HEALTH := 5
const REGEN_DELAY := 6.0       # seconds without being hit before hearts come back
const REGEN_EVERY := 4.0
const DOWN_TIME := 2.4         # lying on the ground before getting back up at the start

@onready var visual: CharacterVisual = $Visual
@onready var gatherer: Node = $Gatherer
@onready var fighter: Node = $Fighter

var verb := ""
var _roll := 0.0
var _roll_dir := Vector3.FORWARD
var _stun := 0.0
var _knock := Vector3.ZERO
var health := MAX_HEALTH
var spawn_point := Vector3.ZERO
var _since_hit := 99.0
var _regen := 0.0
var _down := 0.0


func is_rolling() -> bool:
	return _roll > 0.0


## The action button: fight if an enemy is in reach, otherwise gather.
func act() -> void:
	if _roll > 0.0 or _stun > 0.0:
		return
	if fighter.target:
		fighter.attack()
	else:
		gatherer.act()


## Dodge roll: a quick roll in the stick direction (or forward). Charges miss you mid-roll.
func roll() -> void:
	if _roll > 0.0 or _stun > 0.0 or gatherer.is_busy() or fighter.is_busy() or Controls.locked:
		return
	var m := Controls.get_move()
	if m.length() > 0.1:
		_roll_dir = Vector3(m.x, 0, m.y).normalized()
	else:
		_roll_dir = Vector3(sin(visual.rotation.y), 0, cos(visual.rotation.y))
	visual.rotation.y = atan2(_roll_dir.x, _roll_dir.z)
	visual.play_action("Roll", visual.animation_length("Roll") / ROLL_TIME)
	_roll = ROLL_TIME


## Something hit us (a boar charge): pushed back and briefly stunned. No damage for now.
func knockback(push: Vector3) -> void:
	if _roll > 0.0 or _down > 0.0:
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


## The action: something hurts the player (a boar charge). At 0 hearts they are knocked down
## and get back up at the start with full hearts; nothing is lost.
func take_damage(amount: int) -> void:
	if _roll > 0.0 or _down > 0.0:
		return
	health = maxi(health - amount, 0)
	_since_hit = 0.0
	health_changed.emit(health, MAX_HEALTH)
	if health == 0:
		_down = DOWN_TIME
		_stun = 0.0
		visual.play_action("Death01", 1.0)


func _physics_process(delta: float) -> void:
	_since_hit += delta
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
			health_changed.emit(health, MAX_HEALTH)
			get_tree().call_group("camera_rig", "snap")
		return
	var new_verb: String = fighter.verb if fighter.verb != "" else gatherer.verb
	if new_verb != verb:
		verb = new_verb
		verb_changed.emit(verb)
	if _roll > 0.0 or _stun > 0.0:
		_special_move(delta)
		return
	var busy: bool = gatherer.is_busy() or fighter.is_busy()
	var move := Controls.get_move() if not busy else Vector2.ZERO
	var strength := move.length()
	var target_speed := 0.0
	if strength > 0.1:
		target_speed = RUN_SPEED if strength >= RUN_THRESHOLD else WALK_SPEED * remap(strength, 0.1, RUN_THRESHOLD, 0.6, 1.0)
	# The camera never rotates, so screen up is world -Z.
	var dir := Vector3(move.x, 0.0, move.y).normalized()
	var flat := Vector3(velocity.x, 0.0, velocity.z).lerp(dir * target_speed, clampf(ACCEL * delta, 0.0, 1.0))
	velocity.x = flat.x
	velocity.z = flat.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()

	var speed := Vector2(velocity.x, velocity.z).length()
	if strength > 0.1:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(dir.x, dir.z), clampf(TURN_SPEED * delta, 0.0, 1.0))
	visual.play_motion(speed)


## Rolling or being knocked back: the move is forced, not steered.
func _special_move(delta: float) -> void:
	var flat: Vector3
	if _roll > 0.0:
		_roll -= delta
		flat = _roll_dir * ROLL_SPEED
	else:
		_stun -= delta
		flat = _knock
		_knock = _knock.lerp(Vector3.ZERO, clampf(6.0 * delta, 0.0, 1.0))
	velocity = Vector3(flat.x, 0.0 if is_on_floor() else velocity.y - GRAVITY * delta, flat.z)
	move_and_slide()
