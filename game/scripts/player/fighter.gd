extends Node
## Sword fighting: finds an enemy in reach and, on the action button, swings a 3-hit combo
## (Quaternius UAL2 sword animations). The hit lands mid-swing with a freeze and a camera shake.
## The Heavy button: a slow overhead blow (costs stamina) that hits much harder and knocks back.

signal target_changed(verb: String)     # "Attack", or "" when no enemy is in reach

const REACH := 2.2
const BUTTON_REACH := 3.4     # the Attack button shows this far out; the swing steps you in
const STEP_TO := 1.3          # stepping in stops at this distance
const STAY_ARMED := 1.2       # seconds the Attack button stays after a swing, even with no target
const DRAWN_FOR := 2.5        # seconds the sword (or bow) stays in hand after a swing with no fight on
const FIGHT_NEAR := 8.0       # an enemy this close that's fighting you keeps it drawn
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
## The bow (the Swap button): hold Attack to draw (you slow to a walk and keep facing your target), let go
## to loose. It only aims at an enemy in front of you, within BOW_RANGE; arrows fly straight at where the
## target is now (a moving one can be missed, a wolf may hop aside), and hit softer far away. A quick tap
## is a light shot; the longer the draw, the harder. Let go just as it's fully drawn (the flash and the ting)
## for a Perfect shot: a critical that curves onto its target and goes through. Hold too long and your arm
## shakes. Every shot costs stamina (Balance.BOW). Heavy is a Triple Shot at up to three enemies in front.
## The bow rides on your back outside fights. Arms and string: player/bow_pose.gd.
const BOW_RANGE := 15.0
const AIM_CONE := 0.55        # how far off your facing a target can be (dot)
const DRAW_TIME := 0.9        # seconds to a full draw (faster with a swift bow)
const MIN_DRAW := 0.14        # even a tap draws this long first
const PERFECT := 0.25         # seconds after the full draw when letting go is Perfect
const SHAKE_AFTER := 1.2      # seconds held at full before the arm starts to shake
const SHOT_REST := 0.22       # after a shot, before the next draw
const TRIPLE := {"draw": 0.45, "mult": 0.55, "fan": 0.2}
const ARROW := preload("res://scripts/player/player_arrow.gd")
const BOW_SOUND := preload("res://assets/sounds/bow_shot.wav")
const BOW_POSE := preload("res://scripts/player/bow_pose.gd")
const READY_SOUND := preload("res://assets/sounds/tell_glint.wav")
var _bow: Node3D                # in the left hand, lowered (between shots)
var _bow_back: Node3D           # on your back
var _pose: SkeletonModifier3D   # drawn: arms, bow, string and arrow
var _draw := -1.0               # seconds into a draw (-1: not drawing)
var _let_go := false            # the button came up: loose once the draw has gone MIN_DRAW
var _full_at := -1.0            # when the draw came full (for the Perfect window)
var _triple := false
var _bow_rest := 0.0
var _bow_target: Node3D = null
var _draw_queued := false       # tapped during SHOT_REST: draws as soon as it's over
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
var _studio_commit := 0.0 # studio: C1 unit 4 - the heavy swing and its recovery (no roll, no guard), seconds left
var _studio_intent := {} # studio: fixed prepared target (including air), independent of live nearest_enemy
var _contact_key := "" # studio: stable action identity from initiation through contact/retry
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
	_make_bow.call_deferred()
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


## Drawing the bow: you walk slowly and keep facing your target.
func aiming() -> bool:
	return _draw >= 0.0


func _physics_process(delta: float) -> void:
	if Controls.locked or VillageSession.background: return # studio: active-time commitment
	_studio_commit = maxf(0.0, _studio_commit - delta) # studio: C1 unit 4 - the heavy swing's commitment runs down
	_since += delta
	if _busy > 0.0:
		_busy -= delta
		if _busy <= 0.0:
			if _queued:
				_queued = false
				attack()
			if _busy <= 0.0 and visual.tool_shown != "sword":
				visual.show_tool("")
	# The sword stays drawn while the fight is on (an enemy close that's fighting you, or you swung lately),
	# then goes on your back; at once when your hands are wanted for something else.
	var busy_hands := _hands_wanted()
	if busy_hands != visual.hands_busy:
		visual.hands_busy = busy_hands
		if busy_hands:
			cancel_draw()
	if _busy <= 0.0 and visual.tool_shown == "sword" and (busy_hands or (not visual.hand_sword and _since > DRAWN_FOR and not _fight_on())):
		visual.show_tool("")
	_bow_tick(delta)
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
	target = _aim_target() if bow else _nearest_enemy(BUTTON_REACH)
	if target and target.get("verb") == "Calm":         # sneaking up to tame it, not to kill it
		target = null
	# With the bow, a far enemy only takes the button once the fight is on (so you can still chop and talk).
	var fighting: bool = target != null and (not bow or target.global_position.distance_to(player.global_position) < FIGHT_NEAR 		or (target.has_method("is_engaged") and target.is_engaged()))
	var new_verb := ("Shoot" if bow else "Attack") if fighting or _since < STAY_ARMED else ""
	if target and target.global_position.distance_to(player.global_position) < BUTTON_REACH 			and target.has_method("can_be_taken_down") and target.can_be_taken_down(player):
		new_verb = "Takedown"
	if new_verb != verb:
		verb = new_verb
		target_changed.emit(verb)


## studio: C1 unit 4 - the heavy swing still holds him (its swing and recovery): no roll, no guard.
func studio_committed() -> bool: # studio:
	return _studio_commit > 0.0 # studio:


## The action button near an enemy: one swing of the combo.
func attack() -> void:
	_studio_intent={} # studio: native keyboard adapter is a fresh commitment
	if verb == "Takedown" and _busy <= 0.0 and is_instance_valid(target):
		_takedown(target)
		return
	if bow_out():
		_start_draw()
		return
	if _busy > 0.0:
		_queued = _busy < 0.25
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


# studio: use the existing authored attack, then bind its contact to the prepared actor/target.
func directed(intent: Dictionary,strong := false) -> void:
	if _busy>0:
		return
	var chosen: Node3D=intent.get("native")
	var resident := int(intent.get("target",-2))
	if resident>=0:
		var res := preload("res://scripts/studio/village/contact.gd").registry(get_tree())
		chosen=res.bodies.get(resident) if res!=null else null
	target=chosen if is_instance_valid(chosen) else null
	verb="Attack"
	if strong:
		heavy()
	else:
		attack()
	_studio_intent=intent.duplicate()
	_contact_key=str(intent.press_id)
	_swing_target=target
	var facing: Vector3=intent.get("forward",Vector3.FORWARD)
	visual.rotation.y=atan2(facing.x,facing.z)

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
	_studio_intent={} # studio: native keyboard adapter is a fresh commitment
	_contact_key = "swing:%d" % Time.get_ticks_usec() # studio: interim input binding, generic action key
	if bow_out():
		_start_draw(true)
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
	_studio_commit = preload("res://scripts/studio/player/recovery.gd").heavy_commit(_busy, Food.has("rested")) # studio: C1 unit 4
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


## Stops a swing (a roll cancels it, and a draw).
func cancel() -> void:
	_studio_intent={} # studio: cancellation drops prepared intent
	cancel_draw()
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
	# studio: measured ordinary contact shares the accepted fact route with shove/heavy.
	if not _studio_intent.is_empty() and int(_studio_intent.get("target",-2))>=0:
		var contact := preload("res://scripts/studio/village/contact.gd") # studio: persistent controller ref, independent of its visible identity
		var struck := contact.perform(get_tree(),contact.actor_of(player),player,"strike",
			{"press_id":_contact_key,"damage":int(Gear.hit_damage()[0]),"force":int(_studio_intent.get("force",450))},player.global_position,REACH, # studio: proposal - a prepared flick carries its force; keyboard keeps 450
			_studio_intent.forward,int(_studio_intent.target))
		if struck.get("accepted",false):
			visual.hit_stop(0.04)
			get_tree().call_group("camera_rig","shake",0.04)
		return
	var t := _swing_target if is_instance_valid(_swing_target) else (null if not _studio_intent.is_empty() else _nearest_enemy(REACH)) # studio: a lost prepared target remains a miss
	if (t == null or not is_instance_valid(t)) and _strike_people(false):
		return
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
	_strike_people(true)
	var facing := Vector3(sin(visual.rotation.y), 0, cos(visual.rotation.y))
	var hit_any := false
	var hit := Gear.hit_damage(Balance.HEAVY_DAMAGE)
	if player.take_counter():
		hit = [hit[0] * 2, true]
	var damage: int = hit[0]
	# studio: prepared Heavy measures only its captured target; native keyboard Heavy keeps its authored area.
	var contact := preload("res://scripts/studio/village/contact.gd")
	var receipt := contact.perform(get_tree(),contact.actor_of(player),player,"strike",{"press_id":_contact_key,"damage":damage,"force":int(_studio_intent.get("force",850))}, # studio: same general actor door as walking/powers/haul; proposal - a prepared flick carries its force, keyboard keeps 850
		player.global_position,HEAVY_REACH,_studio_intent.get("forward",facing),int(_studio_intent.get("target",-1)))
	var contacts: int=receipt.get("contacts",[]).size() if receipt.get("accepted",false) and not receipt.get("duplicate",false) else 0
	hit_any = contacts > 0 # studio: village contact shares native feedback; villagers never join enemy merely to be hit
	if contacts > 0: _after_hit(hit[1]) # studio: retain native landed-hit feedback for ordinary contact
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.get_meta("crowd_ignore",false): continue # studio: village markers receive one checked contact
		if not _studio_intent.is_empty() and e!=_studio_intent.get("native"): continue # studio: no replacement target
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


## Enea's own people (world/npc.gd: the story's and the forest's) in front of the swing feel it (npc.struck).
func _strike_people(heavy: bool) -> bool:
	var facing := Vector3(sin(visual.rotation.y), 0, cos(visual.rotation.y))
	var any := false
	for n: Node3D in get_tree().get_nodes_in_group("npc_body"):
		var to := n.global_position - player.global_position
		to.y = 0.0
		if n.is_visible_in_tree() and to.length() < REACH + 0.6 and (to.length() < 0.6 or facing.dot(to.normalized()) > 0.3):
			n.struck(player.global_position, heavy)
			any = true
	if any:
		visual.hit_stop(0.05)
		get_tree().call_group("camera_rig", "shake", 0.05)
	return any


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


## Your hands are wanted for something else: no sword or bow out (fishing, dragging, riding, gathering,
## talking or in a menu).
func _hands_wanted() -> bool:
	return Controls.locked or player.fisher.is_fishing() or player.hauling.busy() or player.gatherer.is_busy()


## Someone close is fighting you.
func _fight_on() -> bool:
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.is_alive() and (e as Node3D).global_position.distance_to(player.global_position) < FIGHT_NEAR \
				and (not e.has_method("is_engaged") or e.is_engaged()):
			return true
	return false


func _make_bow() -> void:
	_bow = visual.hold_prop("crystal_bow", Vector3(90, 0, 0), Vector3(0.0, 0.08, 0.0), "hand_l")
	_bow.scale = Vector3.ONE * 1.15
	_bow.visible = false
	# On the back: slanting the other way from the sword, the string outwards.
	var along := Vector3(0.55, 1.0, 0.0).normalized()                # the limbs (the model's +Y)
	var inward := Vector3(0, 0, 1)                                  # the string against your back, the limbs bowing out
	_bow_back = visual.back_prop(Items.mesh("crystal_bow"), Transform3D(Basis(along.cross(inward), along, inward) * 1.1, Vector3(0.04, 1.22, -0.26)))
	_bow_back.visible = false
	_pose = SkeletonModifier3D.new()
	_pose.set_script(BOW_POSE)
	_pose.visual = visual
	_pose.glow = Gear.BOW["glow"]
	visual.skeleton().add_child(_pose)
	show_bow()


## Where the bow is: drawn (the pose), lowered in your left hand while a fight is on, or on your back.
func show_bow() -> void:
	if _bow == null:
		return
	var on := bow_out()
	var drawn: bool = on and _pose.weight > 0.5
	var in_hand: bool = on and not drawn and not visual.hands_busy and (_since < DRAWN_FOR or _fight_on())
	_bow.visible = in_hand
	_bow_back.visible = on and not drawn and not in_hand
	if on and visual.tool_shown == "sword":
		visual.show_tool("")


## The enemy the bow aims at: the nearest in range, favouring those in front of you (or where you push the
## stick). A tame-able elk you're sneaking up on doesn't count.
func _aim_target() -> Node3D:
	if _draw >= 0.0 and is_instance_valid(_bow_target) and _bow_target.is_alive() \
			and _bow_target.global_position.distance_to(player.global_position) < BOW_RANGE * 1.1:
		return _bow_target                  # keep the target you started drawing on
	var m := Controls.get_move()
	var facing := Vector3(m.x, 0, m.y).normalized() if m.length() > 0.3 else Vector3(sin(visual.rotation.y), 0, cos(visual.rotation.y))
	var best: Node3D = null
	var best_score := INF
	for e in get_tree().get_nodes_in_group("enemy"):
		if not e.is_alive() or e.get("verb") == "Calm":
			continue
		var to: Vector3 = (e as Node3D).global_position - player.global_position
		to.y = 0.0
		var d := to.length()
		if d > BOW_RANGE:
			continue
		var ahead := facing.dot(to / maxf(d, 0.01))
		if ahead < AIM_CONE:
			continue                         # you have to face it
		var score := d * (1.0 + (1.0 - ahead) * 1.2)
		if score < best_score:
			best_score = score
			best = e
	return best


## Up to `n` enemies in range in front of you, the target first (the Triple Shot).
func _targets_ahead(n: int) -> Array[Node3D]:
	var out: Array[Node3D] = []
	if target:
		out.append(target)
	var facing := Vector3(sin(visual.rotation.y), 0, cos(visual.rotation.y))
	var list := get_tree().get_nodes_in_group("enemy").filter(func(e: Node) -> bool:
		var to: Vector3 = (e as Node3D).global_position - player.global_position
		to.y = 0.0
		return e != target and e.is_alive() and e.get("verb") != "Calm" and to.length() < BOW_RANGE and facing.dot(to.normalized()) > AIM_CONE)
	list.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_to(player.global_position) < b.global_position.distance_to(player.global_position))
	for e: Node3D in list:
		if out.size() < n:
			out.append(e)
	return out


## Starts drawing (Attack held), or a Triple Shot (Heavy, the stamina already paid).
func _start_draw(triple := false) -> void:
	if _draw >= 0.0 or player.is_down():
		return
	if player.stamina.winded:
		get_tree().call_group("hud", "hint", "Too tired to draw")
		return
	if _bow_rest > 0.0:
		_draw_queued = not triple
		return
	_draw_queued = false
	_draw = 0.0
	_let_go = triple
	_full_at = -1.0
	_triple = triple
	_bow_target = target
	_since = 0.0
	visual.stop_action()
	_pose.nocked = true
	_audio.stream = _whoosh
	_audio.pitch_scale = 0.55
	_audio.play()


## Puts the arrow back (a roll, a hit that stuns, your hands wanted elsewhere).
func cancel_draw() -> void:
	if _draw < 0.0:
		return
	_draw = -1.0
	_pose.nocked = false


func _bow_tick(delta: float) -> void:
	if _pose == null:
		return
	_bow_rest = maxf(_bow_rest - delta, 0.0)
	if _draw_queued and _bow_rest <= 0.0 and bow_out():
		_start_draw()
	var pace := Gear.speed("sword")
	if _draw >= 0.0:
		_draw += delta * pace
		var full := DRAW_TIME
		if _triple:
			full = TRIPLE["draw"]
		var amount := clampf(_draw / full, 0.0, 1.0)
		_pose.draw = 1.0 - pow(1.0 - amount, 2.0)
		if amount >= 1.0 and _full_at < 0.0:
			_full_at = _draw
			if not _triple:                    # fully drawn: the string glows and a ting, let go now!
				_play_once(READY_SOUND, -8.0)
				player.get_node("Effects").glow_burst(Color(0.5, 1.0, 0.95), 24)
		if _full_at >= 0.0 and not _triple:   # holding it drawn tires the arm, then it shakes
			player.stamina._spend(Balance.BOW["hold"] * delta)
			if _draw - _full_at > SHAKE_AFTER:
				_pose.draw = 1.0 + sin(_draw * 40.0) * 0.04
			if _draw - _full_at > Balance.RECOVERY["loose_after"]: # studio: C1 unit 4 - held too long, it looses by itself (was: winded)
				_let_go = true # studio:
			if player.stamina.winded:
				_let_go = true
		var t := target if is_instance_valid(target) else null
		if t:
			var to := t.global_position - player.global_position
			visual.rotation.y = lerp_angle(visual.rotation.y, atan2(to.x, to.z), clampf(delta * 14.0, 0.0, 1.0))
		if not Controls.is_attack_held():
			_let_go = true
		if _let_go and _draw >= MIN_DRAW / pace and (not _triple or amount >= 1.0):
			_loose(amount)
	_pose.weight = move_toward(_pose.weight, 1.0 if _draw >= 0.0 or (_bow_rest > 0.0 and bow_out()) else 0.0, delta * (12.0 if _draw >= 0.0 else 5.0))
	show_bow()


## Lets the arrow fly: the longer the draw, the harder (fully drawn it goes through); Perfect on the beat.
func _loose(amount: float) -> void:
	var perfect := not _triple and _full_at >= 0.0 and _draw - _full_at <= PERFECT
	var shaking := not _triple and _full_at >= 0.0 and _draw - _full_at > SHAKE_AFTER
	var b: Dictionary = Balance.BOW
	var mult := lerpf(b["weak"], b["full"], amount)
	var pierce := 2 if perfect else 0
	if perfect:
		mult *= b["perfect"]
	player.stamina._spend(b["shot"] * (0.5 + amount * 0.5))
	var from := player.global_position + Vector3(0, 1.4, 0) + Vector3(sin(visual.rotation.y), 0, cos(visual.rotation.y)) * 0.6
	if _triple:
		var aims := _targets_ahead(3)            # the middle arrow at your target, the outer ones at the next two
		for k in 3:
			var turn: float = visual.rotation.y + (k - 1) * TRIPLE["fan"]
			var pick: int = [1, 0, 2][k]
			_fire(from, Vector3(sin(turn), 0, cos(turn)), aims[pick] if pick < aims.size() else null, TRIPLE["mult"], 0, false, 0.0)
	else:
		var turn := visual.rotation.y + (randf_range(-0.14, 0.14) if shaking else 0.0)
		var dir := Vector3(sin(turn), 0, cos(turn))
		var t: Node3D = target if is_instance_valid(target) and not shaking else null
		if t and t.has_method("sense_swing"):
			t.sense_swing()                  # a wary wolf may hop aside
		_fire(from, dir, t, mult, pierce, perfect, 5.0 if perfect else 0.0)
	if perfect:
		FloatText.spawn(get_tree(), player.global_position + Vector3(0, 2.2, 0), "Perfect!", Color(0.55, 1.0, 0.95), true)
	_audio.stream = BOW_SOUND
	_audio.pitch_scale = randf_range(0.95, 1.08) * (0.85 if amount >= 1.0 else 1.1)
	_audio.play()
	_draw = -1.0
	_pose.nocked = false
	_pose.draw = 0.0
	_bow_rest = SHOT_REST / Gear.speed("sword")
	_since = 0.0


func _fire(from: Vector3, dir: Vector3, t: Node3D, mult: float, pierce: int, crit: bool, homing: float) -> void:
	if is_instance_valid(t) and t.is_alive():
		var flat := t.global_position - from
		flat.y = 0.0
		if flat.normalized().dot(Vector3(dir.x, 0, dir.z).normalized()) > 0.3:
			dir = (t.global_position + Vector3(0, 0.7, 0) - from)
	else:
		t = null
	var arrow := Node3D.new()
	arrow.set_script(ARROW)
	player.get_parent().add_child(arrow)
	arrow.fire(from, dir, self, mult, pierce, Gear.BOW["glow"], t, homing, crit)


## An arrow found its mark (player_arrow.gd): damage like a sword blow, scaled for the shot.
func arrow_hit(t: Node3D, mult: float, crit := false) -> void:
	if not is_instance_valid(t) or not t.is_alive():
		return
	var far := t.global_position.distance_to(player.global_position)
	mult *= lerpf(1.0, Balance.BOW["far"], clampf((far - 6.0) / (BOW_RANGE - 6.0), 0.0, 1.0))
	var hit := Gear.hit_damage(mult)
	if crit:
		hit = [maxi(hit[0], 1), true]
	if player.take_counter() or (t.has_method("is_open") and t.is_open()):
		hit = [hit[0] * 2, true]
	hit = Abilities.passive_strike(t, hit, player)
	t.take_hit(player.global_position, hit[0], 1.4 if mult > 1.2 else 0.5)
	_hit_feedback(t, hit[0], hit[1])
	Skills.add("combat", Balance.XP_PER_SWORD_HIT)
