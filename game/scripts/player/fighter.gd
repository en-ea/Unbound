extends Node
## Sword fighting: finds an enemy in reach and, on the action button, swings a 3-hit combo
## (Quaternius UAL2 sword animations). The hit lands mid-swing with a freeze and a camera shake.
## The Heavy button: a slow overhead blow (costs stamina) that hits much harder and knocks back.

signal target_changed(verb: String)     # "Attack", or "" when no enemy is in reach

const REACH := 2.2
const BUTTON_REACH := 3.4     # the Attack button shows this far out; the swing steps you in
const STEP_TO := 1.3          # stepping in stops at this distance
const STAY_ARMED := 1.2       # seconds the Attack button stays after a swing, even with no target
const DRAWN_FOR := 3.0        # seconds the sword stays in hand after a swing with nobody near
const FIGHT_NEAR := 8.0       # an enemy this close keeps it drawn
const COMBO := ["Sword_Regular_A", "Sword_Regular_B", "Sword_Regular_C"]
const FIST_COMBO := ["Punch_Jab", "Punch_Cross"]    # with no sword
const CLAW_COMBO := ["Punch_Jab", "Punch_Cross", "Melee_Hook"]   # the Delver's claws: quicker, lighter swipes
const CLAW_SPEED := 1.35
const HEAVY_CLAW := {"anim": "Melee_Hook", "speed": 0.55, "impact": 0.24, "busy": 0.7}
const SPEED := 1.25
const CHAIN_WINDOW := 0.45     # tap again within this long after a swing to continue the combo
const HIT_SOUNDS := "res://assets/kenney_impact/impactPunch_heavy_%03d.ogg"
## Heavy attack: animation, play speed, and when in it the blow lands (seconds, at speed 1).
const HEAVY_SWORD := {"anim": "Sword_Attack", "speed": 1.0, "impact": 0.4, "busy": 1.0}
const HEAVY_FIST := {"anim": "Punch_Cross", "speed": 0.75, "impact": 0.22, "busy": 0.6}
const HEAVY_REACH := 2.8       # a heavy blow hits every enemy this close in front of you
## The bow: Attack looses a quick arrow at the nearest enemy in range; Heavy draws a power shot that hits
## harder and goes through. Bow poses borrow the pistol aim and shot (no bow clips in our library).
const BOW_RANGE := 24.0
const QUICK_SHOT := {"mult": 0.7, "draw": 0.16, "busy": 0.42, "pierce": 0}
const POWER_SHOT := {"mult": 2.2, "draw": 0.62, "busy": 0.95, "pierce": 2}
const ARROW := preload("res://scripts/player/player_arrow.gd")
const BOW_SOUND := preload("res://assets/sounds/bow_shot.wav")
var _bow: Node3D
const SHOCK_SHADER := preload("res://shaders/shockwave.gdshader")
const THUD := preload("res://assets/sounds/tree_thud.wav")
const CRIT_SOUND := preload("res://assets/sounds/crit.wav")
const KILL_SOUND := preload("res://assets/sounds/kill.wav")

@onready var player: CharacterBody3D = get_parent()
@onready var visual: CharacterVisual = get_parent().get_node("Visual")

var target: Node3D = null
var verb := ""
var _busy := 0.0
var _impact := -1.0
var _swing_target: Node3D = null
var _step := 0
var _since := 99.0
var _queued := false
var _heavy := false
var _heavy_wind := 0.0          # length of the heavy wind-up, for the sword's glow
var _thud: AudioStreamPlayer3D
var _shock: MeshInstance3D
var _shock_mat: ShaderMaterial
var _shock_t := 1.0
var _audio: AudioStreamPlayer3D
var _hits: Array[AudioStream] = []
var _whoosh: AudioStream = preload("res://assets/sounds/swing.wav")
var _sparks: CPUParticles3D


func _ready() -> void:
	Gear.changed.connect(show_bow)
	show_bow.call_deferred()
	_audio = AudioStreamPlayer3D.new()
	_audio.unit_size = 6.0
	player.add_child.call_deferred(_audio)
	for i in 5:
		_hits.append(load(HIT_SOUNDS % i))
	_sparks = CPUParticles3D.new()
	_sparks.emitting = false
	_sparks.one_shot = true
	_sparks.explosiveness = 1.0
	_sparks.amount = 12
	_sparks.lifetime = 0.35
	_sparks.local_coords = false
	_sparks.spread = 180.0
	_sparks.gravity = Vector3(0, -6, 0)
	_sparks.initial_velocity_min = 2.0
	_sparks.initial_velocity_max = 4.5
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.07
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(2.5, 2.1, 1.3)
	quad.material = mat
	_sparks.mesh = quad
	player.add_child.call_deferred(_sparks)
	var marker := LockMarker.new()
	marker.fighter = self
	player.add_child.call_deferred(marker)
	_thud = AudioStreamPlayer3D.new()
	_thud.stream = THUD
	_thud.unit_size = 8.0
	player.add_child.call_deferred(_thud)
	_shock = MeshInstance3D.new()
	var disc := PlaneMesh.new()
	disc.size = Vector2.ONE * 4.4
	_shock.mesh = disc
	_shock_mat = ShaderMaterial.new()
	_shock_mat.shader = SHOCK_SHADER
	_shock.material_override = _shock_mat
	_shock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shock.top_level = true
	_shock.visible = false
	player.add_child.call_deferred(_shock)


func is_busy() -> bool:
	return _busy > 0.0


func _physics_process(delta: float) -> void:
	_since += delta
	if _busy > 0.0:
		_busy -= delta
		if _busy <= 0.0:
			if _queued:
				_queued = false
				attack()
			if _busy <= 0.0 and visual.tool_shown != "sword":
				visual.show_tool("")
	# The sword stays drawn while the fight is on (someone close, or you swung lately), then goes on your back.
	if _busy <= 0.0 and visual.tool_shown == "sword" and not visual.hand_sword and _since > DRAWN_FOR \
			and nearest_enemy(FIGHT_NEAR) == null:
		visual.show_tool("")
	if _impact >= 0.0:
		_impact -= delta
		if _heavy:
			visual.charge_tool(clampf(1.0 - _impact / _heavy_wind, 0.0, 1.0))
		if _impact < 0.0:
			_land_hit()
	if _shock.visible:
		_shock_t += delta / 0.45
		_shock.visible = _shock_t < 1.0
		_shock_mat.set_shader_parameter("t", _shock_t)
	var bow := bow_out()
	target = _nearest_enemy(BOW_RANGE if bow else BUTTON_REACH)
	# With the bow, a far enemy only takes the button once the fight is on (so you can still chop and talk).
	var fighting: bool = target != null and (not bow or target.global_position.distance_to(player.global_position) < FIGHT_NEAR 		or (target.has_method("is_engaged") and target.is_engaged()))
	var new_verb := ("Shoot" if bow else "Attack") if fighting or _since < STAY_ARMED else ""
	if target and target.global_position.distance_to(player.global_position) < BUTTON_REACH 			and target.has_method("can_be_taken_down") and target.can_be_taken_down(player):
		new_verb = "Takedown"
	if new_verb != verb:
		verb = new_verb
		target_changed.emit(verb)


## The action button near an enemy: one swing of the combo.
func attack() -> void:
	if verb == "Takedown" and _busy <= 0.0 and is_instance_valid(target):
		_takedown(target)
		return
	if _busy > 0.0:
		_queued = _busy < 0.25
		return
	if bow_out():
		_shoot(QUICK_SHOT)
		return
	var armed := Gear.tier("sword") >= 0
	var combo: Array = CLAW_COMBO if _claws() else (COMBO if armed else FIST_COMBO)
	_step = (_step + 1) % combo.size() if _since < CHAIN_WINDOW else 0
	var anim: String = combo[_step]
	var pace := SPEED * Gear.speed("sword") * (CLAW_SPEED if _claws() else 1.0)
	var length := visual.animation_length(anim) / pace
	if target:
		var to := target.global_position - player.global_position
		visual.rotation.y = atan2(to.x, to.z)
	visual.show_tool("sword" if armed else "")
	visual.play_action(anim, pace)
	_busy = length * 0.85
	_impact = length * 0.45
	_heavy = false
	_swing_target = target
	if target and target.has_method("sense_swing"):
		target.sense_swing()     # a wary enemy may hop out of reach
	_since = -length * 0.85      # the chain window opens when this swing ends
	_audio.stream = _whoosh
	_audio.pitch_scale = randf_range(0.9, 1.15)
	_audio.play()


## From behind an unaware bandit: one quick, quiet blow.
func _takedown(t: Node3D) -> void:
	var to := t.global_position - player.global_position
	visual.rotation.y = atan2(to.x, to.z)
	visual.show_tool("sword" if Gear.tier("sword") >= 0 else "")
	visual.play_action("Sword_Regular_C", 1.5)
	_busy = 0.55
	_impact = -1.0
	_since = 0.0
	get_tree().create_timer(0.22).timeout.connect(func() -> void:
		if is_instance_valid(t) and t.is_alive():
			t.taken_down(player)
			_play_once(preload("res://assets/sounds/sneak_kill.wav"), -2.0)
			get_tree().call_group("camera_rig", "shake", 0.06)
			Skills.add("combat", Balance.XP_PER_SWORD_HIT * 3))


## The Heavy button: one big blow. The player has already paid the stamina.
func heavy() -> void:
	if bow_out():
		_shoot(POWER_SHOT)
		return
	var armed := Gear.tier("sword") >= 0
	var h: Dictionary = HEAVY_CLAW if _claws() else (HEAVY_SWORD if armed else HEAVY_FIST)
	var speed: float = h["speed"] * Gear.speed("sword")
	if target:
		var to := target.global_position - player.global_position
		visual.rotation.y = atan2(to.x, to.z)
	visual.show_tool("sword" if armed else "")
	visual.play_action(h["anim"], speed)
	_busy = h["busy"] / speed
	_impact = h["impact"] / speed
	_heavy_wind = _impact
	_heavy = true
	_queued = false
	_swing_target = target
	_since = -_busy - CHAIN_WINDOW       # the light combo starts over afterwards
	_audio.stream = _whoosh
	_audio.pitch_scale = randf_range(0.7, 0.78)
	_audio.play()


## After the blow has landed, the rest of the swing is only follow-through: moving cuts it short, so
## you're never stuck slow after an attack.
func recovering() -> bool:
	return _busy > 0.0 and _impact < 0.0 and not _heavy and not _queued


func end_recovery() -> void:
	_busy = 0.0
	visual.stop_action()
	visual.show_tool("")


## Stops a swing (a roll cancels it).
func cancel() -> void:
	_heavy = false
	visual.charge_tool(0.0)
	_busy = 0.0
	_impact = -1.0
	_queued = false
	_swing_target = null
	visual.show_tool("")


## Early in a swing, a quick step toward the target so hits connect even if it backed off.
func step_velocity() -> Vector3:
	if _impact <= 0.0 or not is_instance_valid(_swing_target):
		return Vector3.ZERO
	if _swing_target.has_method("is_evading") and _swing_target.is_evading():
		return Vector3.ZERO
	var to := _swing_target.global_position - player.global_position
	to.y = 0.0
	var gap := to.length() - STEP_TO
	return to.normalized() * clampf(gap * 8.0, 0.0, 7.0) if gap > 0.0 else Vector3.ZERO


func _land_hit() -> void:
	var heavy := _heavy
	_heavy = false
	if heavy:
		visual.charge_tool(0.0)
		_land_heavy()
		return
	var t := _swing_target if is_instance_valid(_swing_target) else _nearest_enemy(REACH)
	if t == null or not is_instance_valid(t) or not t.is_alive():
		Wolf.open_up()           # a swing at nothing leaves you open
		return
	if t.global_position.distance_to(player.global_position) > REACH + 0.8 or (t.has_method("is_evading") and t.is_evading()):
		Wolf.open_up()
		return
	var hit := Gear.hit_damage(Delver.CLAW_POWER if _claws() else 1.0)
	if player.take_counter() or (t.has_method("is_open") and t.is_open()):
		hit = [hit[0] * 2, true]           # a counter after a parry or perfect dodge, or a stunned foe
	hit[0] = Delver.cracked_damage(t, hit[0])
	hit = Abilities.passive_strike(t, hit, player)
	t.take_hit(player.global_position, hit[0])
	if _claws() and _step == 2 and Classes.has_talent("sharp_claws"):
		EarthFX.crack(t, Delver.CRACK_TIME)
	_after_hit(hit[1])
	_hit_feedback(t, hit[0], hit[1])
	Skills.add("combat", Balance.XP_PER_SWORD_HIT)
	_sparks.global_position = t.global_position + Vector3(0, 0.8, 0)
	_sparks.amount = 12
	_sparks.restart()
	visual.hit_stop(0.06)
	get_tree().call_group("camera_rig", "shake", 0.06)
	_audio.stream = _hits.pick_random()
	_audio.pitch_scale = randf_range(0.9, 1.05)
	_audio.play()


## Every blow that lands: its damage floats up (gold and bigger for a critical, with a sharp ring), and
## a kill gets a finisher: a deep boom, a harder shake, and a moment of slow motion on the last enemy.
func _hit_feedback(t: Node3D, damage: int, crit: bool) -> void:
	var at := t.global_position + Vector3(0, 1.4, 0)
	FloatText.spawn(get_tree(), at, str(damage) + ("!" if crit else ""), Color(1.0, 0.82, 0.3) if crit else Color(1, 0.97, 0.92), crit)
	if crit:
		_play_once(CRIT_SOUND, -4.0)
	if t.has_method("is_alive") and not t.is_alive():
		_play_once(KILL_SOUND, -2.0)
		get_tree().call_group("camera_rig", "shake", 0.16)
		var others := get_tree().get_nodes_in_group("enemy").filter(func(e: Node) -> bool:
			return e != t and e.is_alive() and e.has_method("is_engaged") and e.is_engaged())
		if others.is_empty():
			Engine.time_scale = 0.25
			get_tree().create_timer(0.28, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)


func _play_once(stream: AudioStream, db: float) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	player.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


## Weapon bonuses after a hit lands: a critical shows, Vampiric may heal a heart.
func _after_hit(crit: bool) -> void:
	if randf() < Gear.lifesteal():
		player.heal(1)


## A heavy blow lands: every enemy close in front is hit hard and knocked back; the ground
## shakes (shockwave, dust, a deep thud) and the whole world freezes for a split second.
func _land_heavy() -> void:
	var facing := Vector3(sin(visual.rotation.y), 0, cos(visual.rotation.y))
	var hit_any := false
	var hit := Gear.hit_damage(Balance.HEAVY_DAMAGE)
	if player.take_counter():
		hit = [hit[0] * 2, true]
	var damage: int = hit[0]
	for e in get_tree().get_nodes_in_group("enemy"):
		var to: Vector3 = (e as Node3D).global_position - player.global_position
		to.y = 0.0
		if not e.is_alive() or to.length() > HEAVY_REACH or (to.length() > 0.8 and to.normalized().dot(facing) < -0.1):
			continue
		var struck := Abilities.passive_strike(e, [Delver.cracked_damage(e, damage), hit[1]], player)
		var dealt: int = struck[0]
		e.take_hit(player.global_position, dealt, Balance.HEAVY_PUSH)
		if not hit_any:
			_after_hit(struck[1])
		_hit_feedback(e, dealt, struck[1])
		hit_any = true
		_sparks.global_position = (e as Node3D).global_position + Vector3(0, 0.8, 0)
	var ground := player.global_position + facing * 1.1
	_shock.global_position = ground + Vector3(0, 0.2, 0)
	_shock_t = 0.0
	_shock.visible = true
	_shock_mat.set_shader_parameter("t", 0.0)
	player.get_node("Effects").burst(true)
	_thud.pitch_scale = randf_range(0.55, 0.62)
	_thud.play()
	get_tree().call_group("camera_rig", "shake", 0.2 if hit_any else 0.1)
	if not hit_any:
		return
	Skills.add("combat", Balance.XP_PER_SWORD_HIT * 2)
	_sparks.amount = 28
	_sparks.restart()
	_audio.stream = _hits.pick_random()
	_audio.pitch_scale = randf_range(0.7, 0.78)
	_audio.play()
	# Hit-stop for everything: the world nearly stops for a moment, then carries on.
	Engine.time_scale = 0.05
	get_tree().create_timer(0.11, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)


## The Delver fights with claws (character_visual.gd shows them; no sword).
func _claws() -> bool:
	return Classes.current == "delver"


## The closest living enemy within `reach` metres, or null (the camera and the lock marker use it).
func nearest_enemy(reach: float) -> Node3D:
	return _nearest_enemy(reach)


func _nearest_enemy(reach: float) -> Node3D:
	var best: Node3D = null
	var best_d := reach
	for e in get_tree().get_nodes_in_group("enemy"):
		if not e.is_alive():
			continue
		var d: float = (e as Node3D).global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


# --- the bow ---------------------------------------------------------------------------------------

func bow_out() -> bool:
	return Gear.weapon == "bow" and Gear.has_bow and not _claws()


## The bow in your left hand while it's your weapon (the sword stays on your back).
func show_bow() -> void:
	var on := bow_out()
	if on and _bow == null:
		_bow = visual.hold_prop("crystal_bow", Vector3(90, 0, 0), Vector3(0.0, 0.08, 0.0), "hand_l")
		_bow.scale = Vector3.ONE * 1.15
	if _bow:
		_bow.visible = on
	if on and visual.tool_shown == "sword":
		visual.show_tool("")


## Draw, then loose an arrow at the target (or straight ahead). `shot` is QUICK_SHOT or POWER_SHOT.
func _shoot(shot: Dictionary) -> void:
	var t := target
	if t:
		var to := t.global_position - player.global_position
		visual.rotation.y = atan2(to.x, to.z)
	show_bow()
	var draw: float = shot["draw"] / Gear.speed("sword")
	if shot == POWER_SHOT:
		visual.play_action("Pistol_Aim_Neutral", 1.0)
		visual.charge_tool(0.0)
	_busy = shot["busy"] / Gear.speed("sword")
	_impact = -1.0
	_heavy = false
	_queued = false
	_since = -_busy
	get_tree().create_timer(draw).timeout.connect(func() -> void:
		if player.is_down() or not bow_out():
			return
		visual.play_action("Pistol_Shoot", 1.6)
		var from := player.global_position + Vector3(0, 1.35, 0) + Vector3(sin(visual.rotation.y), 0, cos(visual.rotation.y)) * 0.5
		var dir := Vector3(sin(visual.rotation.y), 0, cos(visual.rotation.y))
		if is_instance_valid(t) and t.is_alive():
			dir = (t.global_position + Vector3(0, 0.7, 0) - from)
		var arrow := Node3D.new()
		arrow.set_script(ARROW)
		player.get_parent().add_child(arrow)
		arrow.fire(from, dir, self, shot["mult"], shot["pierce"], Gear.BOW["glow"])
		_audio.stream = BOW_SOUND
		_audio.pitch_scale = randf_range(0.95, 1.08) * (0.85 if shot == POWER_SHOT else 1.0)
		_audio.play())


## An arrow found its mark (player_arrow.gd): damage like a sword blow, scaled for the shot.
func arrow_hit(t: Node3D, mult: float) -> void:
	if not is_instance_valid(t) or not t.is_alive():
		return
	var hit := Gear.hit_damage(mult)
	if player.take_counter() or (t.has_method("is_open") and t.is_open()):
		hit = [hit[0] * 2, true]
	hit = Abilities.passive_strike(t, hit, player)
	t.take_hit(player.global_position, hit[0], 1.4 if mult > 1.0 else 0.5)
	_hit_feedback(t, hit[0], hit[1])
	Skills.add("combat", Balance.XP_PER_SWORD_HIT)
