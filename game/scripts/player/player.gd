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
var smoking: Smoking
var sprinting := false
var sneaking := false          # crouched: slow and quiet, and bandits see you from much closer
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
var _roll_age := 0.0
var _roll_speed := ROLL_SPEED
var _roll_time := ROLL_TIME
var abilities: Abilities
var _guard := 0.0               # guard up (the Parry button): the first part of it is a perfect parry
var _guard_age := 0.0
var _guard_rest := 0.0
var _counter_until := 0.0       # after a perfect dodge or a parry: the next hit is a counter (double, critical)
const PARRY_SOUND := preload("res://assets/sounds/parry.wav")
const BLOCK_SOUND := preload("res://assets/sounds/block.wav")
const DODGE_SOUND := preload("res://assets/sounds/perfect_dodge.wav")


func is_rolling() -> bool:
	return _roll > 0.0


## Heavy attack (the Heavy button in a fight): a slow, big swing that costs stamina.
func heavy() -> void:
	if _roll > 0.0 or _stun > 0.0 or _down > 0.0 or fighter.is_busy() or Controls.locked:
		return
	if stamina.use("heavy"):
		fighter.heavy()


## The Parry button: raise the sword to meet a blow. Timed just as it lands (the glint is your cue), it
## parries: the attacker is knocked off balance and open, and your next hit is a counter. A late guard
## still blocks, but costs stamina and shoves you back.
func guard() -> void:
	if _roll > 0.0 or _stun > 0.0 or _down > 0.0 or _guard_rest > 0.0 or Controls.locked:
		return
	if not stamina.use("guard"):
		return
	fighter.cancel()
	var d: Dictionary = Balance.DEFENCE
	_guard = d["guard"]
	_guard_age = 0.0
	_guard_rest = d["guard"] + d["guard_rest"]
	var foe: Node3D = fighter.nearest_enemy(6.0)
	if foe:
		var to := foe.global_position - global_position
		visual.rotation.y = atan2(to.x, to.z)
	visual.show_tool("sword" if Gear.tier("sword") >= 0 else "")
	visual.play_action("Sword_Block", visual.animation_length("Sword_Block") / (d["guard"] + 0.25))


func is_down() -> bool:
	return _down > 0.0


## The Sneak button: crouch and creep (again to stand).
func sneak() -> void:
	if _down > 0.0 or Controls.locked:
		return
	set_sneaking(not sneaking)


func set_sneaking(on: bool) -> void:
	sneaking = on
	visual.idle_anim = "Crouch_Idle" if on else ""
	visual.walk_anim = "Crouch_Fwd" if on else ""
	get_tree().call_group("hud", "sneak_changed", on)


## How far away you can be heard right now (metres; 0 = silent). Bandits use it.
func noise() -> float:
	var st: Dictionary = Balance.STEALTH
	if _down > 0.0:
		return 0.0
	if fighter.is_busy() or _roll > 0.0 or _guard > 0.0:
		return st["noise_fight"]
	var speed := Vector2(velocity.x, velocity.z).length()
	if sprinting:
		return st["noise_sprint"]
	if speed > 3.0:
		return st["noise_run"]
	if speed > 0.3:
		return st["noise_sneak"] if sneaking else st["noise_walk"]
	return 0.0


## True (once) if a counter is ready: the fighter doubles the next hit.
func take_counter() -> bool:
	if Time.get_ticks_msec() / 1000.0 < _counter_until:
		_counter_until = 0.0
		return true
	return false


## Every enemy blow goes through here. Returns what happened, so the attacker can react:
## "perfect" (a perfect dodge: slow motion, a counter), "dodge" (rolled clear), "parry" (it is stunned),
## "block" (a late guard), "hit", or "miss" (you're down).
func receive_attack(attacker: Node3D, damage: int, push: Vector3) -> String:
	if _down > 0.0:
		return "miss"
	var d: Dictionary = Balance.DEFENCE
	if _roll > 0.0:
		if _roll_age < d["perfect_dodge"]:
			_perfect_dodge()
			return "perfect"
		return "dodge"
	var to := attacker.global_position - global_position
	to.y = 0.0
	var facing := Vector3(sin(visual.rotation.y), 0, cos(visual.rotation.y))
	if _guard > 0.0 and facing.dot(to.normalized()) > -0.2:
		if _guard_age < d["parry"]:
			_parry(attacker)
			return "parry"
		_play(BLOCK_SOUND, -2.0)
		stamina._spend(Balance.STAMINA["block"])
		FloatText.spawn(get_tree(), global_position + Vector3(0, 2.0, 0), "Blocked", Color(0.8, 0.85, 0.95))
		if not stamina.winded:
			_knock = push * 0.35
			_stun = 0.2
			return "block"
		get_tree().call_group("hud", "hint", "Guard broken!")      # out of stamina: the blow gets through
		_guard = 0.0
	knockback(push)
	take_damage(damage)
	return "hit"


func _parry(attacker: Node3D) -> void:
	var d: Dictionary = Balance.DEFENCE
	_guard = 0.0
	_guard_rest = 0.15
	_counter_until = Time.get_ticks_msec() / 1000.0 + d["counter_secs"]
	stamina.value = minf(stamina.value + Balance.STAMINA["guard"] * 2.0, stamina.max_value())
	if attacker.has_method("parried"):
		attacker.parried(d["parry_stun"])
	_play(PARRY_SOUND, 0.0)
	var at := (global_position + attacker.global_position) * 0.5 + Vector3(0, 1.2, 0)
	TOOL_DROP.sparks(get_parent(), at, Color(1.0, 0.85, 0.5), 30, 5.0)
	FloatText.spawn(get_tree(), global_position + Vector3(0, 2.1, 0), "PARRY!", Color(1.0, 0.85, 0.4), true)
	get_tree().call_group("camera_rig", "shake", 0.14)
	_slow_motion(0.12, 0.2)


func _perfect_dodge() -> void:
	var d: Dictionary = Balance.DEFENCE
	if Engine.time_scale < 1.0:
		return          # already slowed by another perfect dodge
	_counter_until = Time.get_ticks_msec() / 1000.0 + d["counter_secs"] + d["slow_secs"]
	stamina.value = minf(stamina.value + Balance.STAMINA["roll"], stamina.max_value())
	_play(DODGE_SOUND, -1.0)
	FloatText.spawn(get_tree(), global_position + Vector3(0, 2.0, 0), "Perfect!", Color(0.55, 0.9, 1.0), true)
	_slow_motion(d["slow"], d["slow_secs"])


## Slows the whole world for `seconds` of real time (tinting the screen while it lasts).
func _slow_motion(scale: float, seconds: float) -> void:
	Engine.time_scale = scale
	get_tree().call_group("hud", "slow_tint", seconds)
	get_tree().create_timer(seconds, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)


func _play(stream: AudioStream, db: float) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


## The action button: fight if an enemy is in reach, otherwise gather.
func act() -> void:
	if _roll > 0.0 or _stun > 0.0 or _down > 0.0 or Controls.locked:
		return
	_station = _nearest_station() # studio: validate the same local target at input time
	if is_instance_valid(_station) and _station.get_meta("village_action", false):
		_station.interact()
	elif fighter.verb != "":
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
	smoking = Smoking.new()
	smoking.name = "Smoking"
	add_child(smoking)
	abilities = Abilities.new()
	abilities.name = "Abilities"
	add_child(abilities)
	visual.wear_gear = true               # worn armour shows over your look
	Armor.changed.connect(visual.apply_hero_look)
	visual.apply_hero_look.call_deferred()


func _ready_drops() -> void:
	Gear.tool_dropped.connect(func(slot: String, t: Dictionary) -> void:
		TOOL_DROP.spawn(get_parent(), slot, t, global_position, self, false))
	Armor.dropped.connect(func(slot: String, p: Dictionary) -> void:
		TOOL_DROP.spawn(get_parent(), slot, p, global_position, self, false))


## The closest node in group "interactable" whose `reach` we are inside (it has `verb` and interact()).
func _nearest_station() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for n: Node3D in get_tree().get_nodes_in_group("interactable"):
		var d := Vector2(n.global_position.x - global_position.x, n.global_position.z - global_position.z).length()
		var score := d - (10.0 if n.get_meta("village_action", false) else 0.0)
		if d < n.reach and score < best_d and absf(n.global_position.y - global_position.y) < 3.0:
			best_d = score
			best = n
	return best


## Dodge roll: a quick roll in the stick direction (or forward). Charges miss you mid-roll.
func roll() -> void:
	if _roll > 0.0 or _roll_rest > 0.0 or _stun > 0.0 or gatherer.is_busy() or Controls.locked:
		return
	if not stamina.use("roll"):
		return
	fighter.cancel()        # a roll cuts a swing short
	_guard = 0.0
	_roll_age = 0.0
	var m := Controls.get_move()
	if m.length() > 0.1:
		_roll_dir = Vector3(m.x, 0, m.y).normalized()
	else:
		_roll_dir = Vector3(sin(visual.rotation.y), 0, cos(visual.rotation.y))
	visual.rotation.y = atan2(_roll_dir.x, _roll_dir.z)
	visual.play_action("Roll", visual.animation_length("Roll") / ROLL_TIME)
	_roll = ROLL_TIME
	_roll_time = ROLL_TIME
	_roll_speed = ROLL_SPEED
	$Sounds.play_roll()
	$Effects.burst(true)


## A fast dash (Flame Dash): like a roll (untouchable, perfect-dodge timing) but quicker and further.
func dash(dir: Vector3, speed: float, time: float) -> void:
	fighter.cancel()
	_guard = 0.0
	_roll_age = 0.0
	_roll_dir = dir
	_roll = time
	_roll_time = time
	_roll_speed = speed
	visual.rotation.y = atan2(dir.x, dir.z)
	visual.play_action("Sword_Dash", visual.animation_length("Sword_Dash") / (time + 0.25))
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
		elif event.physical_keycode == KEY_R:
			guard()
		elif event.physical_keycode == KEY_C:
			sneak()
		elif event.physical_keycode in [KEY_Z, KEY_X] and Classes.abilities().size() > (0 if event.physical_keycode == KEY_Z else 1):
			abilities.use(Classes.abilities()[0 if event.physical_keycode == KEY_Z else 1])


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


## The action: light a cigarette from the Bag (the look and a bit of calm; no stats).
func smoke() -> void:
	if _down <= 0.0:
		smoking.start()


func level_glow() -> void:
	$Effects.glow_burst()


func heal(hearts: int) -> void:
	if _down <= 0.0 and health < MAX_HEALTH:
		health = mini(health + hearts, MAX_HEALTH)
		health_changed.emit(health, MAX_HEALTH)


func heal_full() -> void:
	if _down <= 0.0:
		health = MAX_HEALTH
		health_changed.emit(health, MAX_HEALTH)


func take_damage(amount: int) -> void:
	if _roll > 0.0 or _down > 0.0 or _safe > 0.0:
		return
	if randf() < Armor.block_chance():        # armour took the whole hit
		_safe = INVULNERABLE * 0.5
		visual.flash()
		get_tree().call_group("hud", "hint", "Blocked!")
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
	_roll_age += delta
	_guard_rest = maxf(_guard_rest - delta, 0.0)
	if _guard > 0.0:
		_guard -= delta
		_guard_age += delta
	if _safe > 0.0:
		_safe -= delta
		visual.visible = _safe <= 0.0 or fmod(_safe, 0.2) > 0.1      # blink while protected
	if health < MAX_HEALTH and _since_hit > REGEN_DELAY and _down <= 0.0:
		_regen += delta
		if _regen >= REGEN_EVERY / (1.0 + Armor.bonus_total("mending") / 100.0):
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
	# studio: urgent village actions remain explicitly selectable near the target.
	var new_verb: String = fighter.verb
	if is_instance_valid(_station) and _station.get_meta("village_action", false):
		new_verb = _station.verb
	elif new_verb == "":
		new_verb = _station.verb if _station else gatherer.verb
	if new_verb != verb:
		verb = new_verb
		verb_changed.emit(verb)
	if _roll > 0.0 or _stun > 0.0:
		sprinting = false
		_special_move(delta)
		return
	# Gathering roots you in place. A swing commits you only until its blow lands (a short step in);
	# after that, pushing the stick cancels the follow-through and you move at full speed.
	var stick := Controls.get_move()
	if fighter.recovering() and stick.length() > 0.3:
		fighter.end_recovery()
	var swinging: bool = fighter.is_busy() or _guard > 0.0
	var move := stick if not gatherer.is_busy() else Vector2.ZERO
	if swinging:
		move *= 0.35
	var strength := move.length()
	var target_speed := 0.0
	# Holding Roll after the roll keeps you sprinting while stamina lasts.
	var was_sprinting := sprinting
	sprinting = Controls.is_sprint_held() and strength >= RUN_THRESHOLD and not swinging and stamina.can("sprint")
	if sprinting and not was_sprinting:
		$Effects.burst(true)              # a kick of dust as you take off
	if sprinting:
		stamina.drain(delta)
	if sneaking and sprinting:
		set_sneaking(false)                   # breaking into a sprint stands you up
	if strength > 0.1:
		var run := Balance.SPRINT_SPEED if sprinting else RUN_SPEED
		run *= 1.0 + Armor.bonus_total("fleet") / 100.0
		target_speed = run * (Balance.SWIFT_SPEED if Food.has("swift") else 1.0) if strength >= RUN_THRESHOLD else WALK_SPEED * remap(strength, 0.1, RUN_THRESHOLD, 0.6, 1.0)
		if sneaking:
			target_speed = minf(target_speed, Balance.STEALTH["sneak_speed"])
	# Controls already turned the stick into ground directions (relative to the camera).
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
		var t := 1.0 - _roll / _roll_time      # 0 at the start of the roll, 1 at the end
		flat = _roll_dir * _roll_speed * lerpf(1.0, 0.6, t * t)
	else:
		_stun -= delta
		flat = _knock
		_knock = _knock.lerp(Vector3.ZERO, clampf(6.0 * delta, 0.0, 1.0))
	velocity = Vector3(flat.x, 0.0 if is_on_floor() else velocity.y - GRAVITY * delta, flat.z)
	move_and_slide()
