extends Node3D
## The companion with you (Companions.with_you(): Cinder, a Pyromancer's fire spirit). She floats at your
## shoulder, bobbing, blinking, her crown of flames flickering, and lights the dark around you. In a fight
## she throws fire bolts at the enemy you're fighting (or the nearest one that's after you); from level 3
## they set it alight. When you stand still a while she does a little loop. Left behind (a waystone, a door),
## she catches up. The first time she joins, she leaps out of the nearest campfire.
## Model: tools-src/blender/make_companion.py (parts animated here).

const MODEL := preload("res://assets/creatures/cinder.glb")
const TREASURE := preload("res://scripts/world/treasure.gd")
const PARTS := ["Body", "Eyes", "Flame", "Tail", "Arm_L", "Arm_R"]
const SHOT_SOUND := preload("res://assets/sounds/fire_cast.wav")
const HEIGHT := 1.75
const SPEED := 7.0

var player: CharacterBody3D
var day_night: Node
var id := ""
var _root: Node3D
var _parts := {}
var _rest := {}
var _light: OmniLight3D
var _embers: CPUParticles3D
var _t := 0.0
var _cool := 1.0
var _blink := 2.0
var _cast := 0.0                  # 1 -> 0 after throwing a bolt (arms up, flames flare)
var _idle := 0.0
var _loop := -1.0                 # a happy loop-the-loop, 0..1
var _audio: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group("companion")
	top_level = true
	_audio = AudioStreamPlayer3D.new()
	_audio.unit_size = 6.0
	add_child(_audio)
	Companions.changed.connect(_refresh)
	Classes.changed.connect(_refresh)
	Companions.joined.connect(_on_joined)
	Companions.grew.connect(func(cid: String, lv: int) -> void:
		Banner.show_now(get_tree().get_first_node_in_group("hud"), "%s GREW" % Companions.DEFS[cid]["name"].to_upper(),
			"Level %d: hotter, quicker fire%s." % [lv, " (it sets things alight now)" if lv == Balance.COMPANIONS[cid]["ignite_at"] else ""],
			Color(1.0, 0.6, 0.3), null, 2.2))
	_refresh.call_deferred()


func _refresh() -> void:
	var now := Companions.with_you()
	if now == id:
		return
	id = now
	if is_instance_valid(_root):
		_root.queue_free()
		_root = null
	visible = id != ""
	set_process(id != "")
	if id == "":
		return
	_build()
	come_to(player.global_position)


func _build() -> void:
	_root = Node3D.new()
	add_child(_root)
	var model := TREASURE._solid(MODEL.instantiate())
	model.scale = Vector3.ONE * 1.1
	_root.add_child(model)
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for part: String in PARTS:
		var n := model.find_child(part, true, false) as Node3D
		if n:
			_parts[part] = n
			_rest[part] = n.transform
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.62, 0.3)
	_light.omni_range = 5.0
	_light.shadow_enabled = false
	_root.add_child(_light)
	_embers = CPUParticles3D.new()
	_embers.amount = 10
	_embers.lifetime = 0.8
	_embers.local_coords = false
	_embers.direction = Vector3.UP
	_embers.spread = 25.0
	_embers.gravity = Vector3(0, 0.6, 0)
	_embers.initial_velocity_min = 0.2
	_embers.initial_velocity_max = 0.6
	var dot := SphereMesh.new()
	dot.radius = 0.018
	dot.height = 0.036
	dot.radial_segments = 4
	dot.rings = 2
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.65, 0.25)
	dot.material = m
	_embers.mesh = dot
	_embers.position = Vector3(0, 0.25, 0)
	_root.add_child(_embers)


## Appear beside you (after a trip, or when she's been left far behind).
func come_to(at: Vector3) -> void:
	if not is_instance_valid(player):
		return
	global_position = _spot()
	if at.distance_to(player.global_position) > 0.1:
		global_position = at + Vector3(0, HEIGHT, 0)


## Where she floats: at your right shoulder, a little behind.
func _spot() -> Vector3:
	var yaw: float = player.visual.rotation.y
	var right := Vector3(-cos(yaw), 0, sin(yaw))
	var back := -Vector3(sin(yaw), 0, cos(yaw))
	return player.global_position + right * 0.75 + back * 0.45 + Vector3(0, HEIGHT, 0)


func _process(delta: float) -> void:
	if not is_instance_valid(player) or _root == null:
		return
	_t += delta
	var want := _spot()
	if global_position.distance_to(want) > 25.0:
		come_to(player.global_position)
	var step := (want - global_position)
	global_position += step * clampf(delta * 4.0, 0.0, 1.0)
	var moving := Vector2(player.velocity.x, player.velocity.z).length() > 0.3
	_idle = 0.0 if moving or player.fighter.is_busy() else _idle + delta
	if _idle > 7.0 and _loop < 0.0:
		_loop = 0.0
		_idle = 0.0
	# Facing: where she's going, or the fight, or you.
	var foe := _target()
	var look := (foe.global_position - global_position) if foe else (step if step.length() > 0.3 else player.global_position - global_position)
	look.y = 0.0
	if look.length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(look.x, look.z), clampf(delta * 6.0, 0.0, 1.0))
	_animate(delta, step)
	_fight(delta, foe)
	var night: float = day_night.night if day_night and "night" in day_night else 0.0
	_light.light_energy = lerpf(0.5, 1.5, night) * (1.0 + sin(_t * 11.0) * 0.08 + _cast * 0.8)


func _animate(delta: float, step: Vector3) -> void:
	var bob := sin(_t * 2.6) * 0.07
	var tilt := clampf(step.length(), 0.0, 1.5) * 0.25                 # leans into the way she flies
	_root.position = Vector3(0, bob, 0)
	_root.rotation = Vector3(tilt, 0, sin(_t * 1.7) * 0.08)
	if _loop >= 0.0:                                                   # a happy loop-the-loop
		_loop += delta / 1.1
		_root.rotation.x -= TAU * smoothstep(0.0, 1.0, _loop)
		_root.position.y += sin(_loop * PI) * 0.35
		if _loop >= 1.0:
			_loop = -1.0
	_cast = maxf(_cast - delta * 2.5, 0.0)
	if _parts.has("Flame"):
		var f: float = 1.0 + sin(_t * 9.0) * 0.1 + sin(_t * 23.0) * 0.05 + _cast * 0.5
		_parts["Flame"].transform = _rest["Flame"] * Transform3D(Basis.from_scale(Vector3(1.0 - _cast * 0.1, f, 1.0 - _cast * 0.1)), Vector3.ZERO)
	if _parts.has("Tail"):
		_parts["Tail"].transform = _rest["Tail"] * Transform3D(Basis(Vector3.UP, sin(_t * 4.0) * 0.4) * Basis(Vector3.RIGHT, sin(_t * 3.1) * 0.2), Vector3.ZERO)
	for side: String in ["L", "R"]:
		var arm: String = "Arm_" + side
		if _parts.has(arm):
			var s := 1.0 if side == "L" else -1.0
			var lift := _cast * 1.6 + sin(_t * 3.0 + s) * 0.15
			_parts[arm].transform = _rest[arm] * Transform3D(Basis(Vector3(0, 1, 0), s * 0.2) * Basis(Vector3(0, 1, 0).cross(Vector3(s, 0, 0)), -lift * s), Vector3.ZERO)
	_blink -= delta
	if _parts.has("Eyes"):
		var shut := _blink < 0.12 and _blink > 0.0
		_parts["Eyes"].transform = _rest["Eyes"] * Transform3D(Basis.from_scale(Vector3(1, 1, 0.12 if shut else 1.0)), Vector3.ZERO)
	if _blink <= 0.0:
		_blink = randf_range(2.5, 5.0)


## The enemy to throw fire at: the one you're fighting, or the nearest that's after you, in range.
func _target() -> Node3D:
	var reach: float = Balance.COMPANIONS[id]["range"]
	var t: Node3D = player.fighter.target
	if is_instance_valid(t) and t.is_alive() and t.get("verb") != "Calm" and t.global_position.distance_to(player.global_position) < reach \
			and (not t.has_method("is_engaged") or t.is_engaged() or player.fighter._since < 3.0):
		return t
	var best: Node3D = null
	var best_d := reach
	for e in get_tree().get_nodes_in_group("enemy"):
		var d: float = (e as Node3D).global_position.distance_to(player.global_position)
		if e.is_alive() and d < best_d and e.has_method("is_engaged") and e.is_engaged():
			best = e
			best_d = d
	return best


func _fight(delta: float, foe: Node3D) -> void:
	_cool -= delta
	if foe == null or _cool > 0.0:
		return
	_cool = Companions.stat(id, "every")
	_cast = 1.0
	_audio.stream = SHOT_SOUND
	_audio.pitch_scale = randf_range(1.3, 1.5)
	_audio.volume_db = -8.0
	_audio.play()
	var bolt := Node3D.new()
	bolt.set_script(preload("res://scripts/world/companion_bolt.gd"))
	get_parent().add_child(bolt)
	bolt.fire(global_position + Vector3(0, 0.1, 0), foe, int(Companions.stat(id, "bolt")),
		Companions.level(id) >= Balance.COMPANIONS[id]["ignite_at"], func(killed: bool) -> void:
			if killed:
				Companions.add_xp(id, Balance.COMPANIONS[id]["xp_kill"]))


## Her first time: she leaps out of the nearest campfire and flies to you.
func _on_joined(cid: String) -> void:
	_refresh()
	if cid != id:
		return
	var fire: Node3D = null
	for f in get_tree().get_nodes_in_group("interactable"):
		if f.get("verb") == "Cook" and (fire == null or (f as Node3D).global_position.distance_to(player.global_position)
				< fire.global_position.distance_to(player.global_position)):
			fire = f
	if fire:
		global_position = fire.global_position + Vector3(0, 0.6, 0)
		FireFX.blast(get_parent(), fire.global_position, 1.5)
	_loop = 0.0
	Banner.show_now(get_tree().get_first_node_in_group("hud"), "CINDER JOINS YOU",
		"A spark of the fire took a liking to you. She'll fight at your side while you're a Pyromancer.", Color(1.0, 0.6, 0.3), null, 3.0)
