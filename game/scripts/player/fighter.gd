extends Node
## Sword fighting: finds an enemy in reach and, on the action button, swings a 3-hit combo
## (Quaternius UAL2 sword animations). The hit lands mid-swing with a freeze and a camera shake.
## The Heavy button: a slow overhead blow (costs stamina) that hits much harder and knocks back.

signal target_changed(verb: String)     # "Attack", or "" when no enemy is in reach

const REACH := 2.2
const BUTTON_REACH := 3.4     # the Attack button shows this far out; the swing steps you in
const STEP_TO := 1.3          # stepping in stops at this distance
const STAY_ARMED := 1.2       # seconds the Attack button stays after a swing, even with no target
const COMBO := ["Sword_Regular_A", "Sword_Regular_B", "Sword_Regular_C"]
const FIST_COMBO := ["Punch_Jab", "Punch_Cross"]    # with no sword
const SPEED := 1.25
const CHAIN_WINDOW := 0.45     # tap again within this long after a swing to continue the combo
const HIT_SOUNDS := "res://assets/kenney_impact/impactPunch_heavy_%03d.ogg"
## Heavy attack: animation, play speed, and when in it the blow lands (seconds, at speed 1).
const HEAVY_SWORD := {"anim": "Sword_Attack", "speed": 1.0, "impact": 0.4, "busy": 1.0}
const HEAVY_FIST := {"anim": "Punch_Cross", "speed": 0.75, "impact": 0.22, "busy": 0.6}
const HEAVY_REACH := 2.8       # a heavy blow hits every enemy this close in front of you
const SHOCK_SHADER := preload("res://shaders/shockwave.gdshader")
const THUD := preload("res://assets/sounds/tree_thud.wav")

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
			if _busy <= 0.0:
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
	target = _nearest_enemy(BUTTON_REACH)
	var new_verb := "Attack" if target or _since < STAY_ARMED else ""
	if new_verb != verb:
		verb = new_verb
		target_changed.emit(verb)


## The action button near an enemy: one swing of the combo.
func attack() -> void:
	if _busy > 0.0:
		_queued = _busy < 0.25
		return
	var armed := Gear.tier("sword") >= 0
	var combo: Array = COMBO if armed else FIST_COMBO
	_step = (_step + 1) % combo.size() if _since < CHAIN_WINDOW else 0
	var anim: String = combo[_step]
	var length := visual.animation_length(anim) / (SPEED * Gear.speed("sword"))
	if target:
		var to := target.global_position - player.global_position
		visual.rotation.y = atan2(to.x, to.z)
	visual.show_tool("sword" if armed else "")
	visual.play_action(anim, SPEED * Gear.speed("sword"))
	_busy = length * 0.85
	_impact = length * 0.45
	_heavy = false
	_swing_target = target
	_since = -length * 0.85      # the chain window opens when this swing ends
	_audio.stream = _whoosh
	_audio.pitch_scale = randf_range(0.9, 1.15)
	_audio.play()


## The Heavy button: one big blow. The player has already paid the stamina.
func heavy() -> void:
	var armed := Gear.tier("sword") >= 0
	var h: Dictionary = HEAVY_SWORD if armed else HEAVY_FIST
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
		return
	if t.global_position.distance_to(player.global_position) > REACH + 0.8:
		return
	var hit := Gear.hit_damage()
	t.take_hit(player.global_position, hit[0])
	_after_hit(hit[1])
	Skills.add("combat", Balance.XP_PER_SWORD_HIT)
	_sparks.global_position = t.global_position + Vector3(0, 0.8, 0)
	_sparks.amount = 12
	_sparks.restart()
	visual.hit_stop(0.06)
	get_tree().call_group("camera_rig", "shake", 0.06)
	_audio.stream = _hits.pick_random()
	_audio.pitch_scale = randf_range(0.9, 1.05)
	_audio.play()


## Weapon bonuses after a hit lands: a critical shows, Vampiric may heal a heart.
func _after_hit(crit: bool) -> void:
	if crit:
		get_tree().call_group("hud", "hint", "Critical!")
	if randf() < Gear.lifesteal():
		player.heal(1)


## A heavy blow lands: every enemy close in front is hit hard and knocked back; the ground
## shakes (shockwave, dust, a deep thud) and the whole world freezes for a split second.
func _land_heavy() -> void:
	var facing := Vector3(sin(visual.rotation.y), 0, cos(visual.rotation.y))
	var hit_any := false
	var hit := Gear.hit_damage(Balance.HEAVY_DAMAGE)
	var damage: int = hit[0]
	for e in get_tree().get_nodes_in_group("enemy"):
		var to: Vector3 = (e as Node3D).global_position - player.global_position
		to.y = 0.0
		if not e.is_alive() or to.length() > HEAVY_REACH or (to.length() > 0.8 and to.normalized().dot(facing) < -0.1):
			continue
		e.take_hit(player.global_position, damage, Balance.HEAVY_PUSH)
		if not hit_any:
			_after_hit(hit[1])
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
