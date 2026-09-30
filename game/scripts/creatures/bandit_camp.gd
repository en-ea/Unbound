class_name BanditCamp
extends Node3D
## The Red Hand camp in the Whispering Wood: a ring of sharpened stakes with a gate on the west and a gap
## at the back (the sneaky way in), tents round a fire, a lookout, a banner, and the leader Varek by the
## big tent. Seven bandits: two by the fire, a shield guard at the gate, two archers, one walking the
## inside and one walking round the outside.
## It runs the fight for them: only Balance.BANDIT_TURNS may attack at once (the rest circle), a shout
## alerts the camp, a body lying in view makes a bandit come and look, and the dead come back once
## you're long gone. Varek drops his black seal while Morrow's job is open.

const DIR := "res://assets/camp/%s.glb"
const CAMPS := {"forest": {"at": Vector2(74.0, 10.0), "name": "Red Hand Camp"}}
const RING := 11.0
const TREASURE := preload("res://scripts/world/treasure.gd")
const DROP := preload("res://scripts/world/drop.gd")
const RESPAWN_AWAY := 45.0       # the dead come back after you've been this far away ...
const RESPAWN_AFTER := 90.0      # ... for this long

var player: Node3D
var day_night: Node

var _center := Vector3.ZERO
var _shape: WorldShape
var _turns: Array[Node] = []
var _bodies: Array = []           # [bandit, time it fell]
var _roster: Array[Dictionary] = []
var _alarm_at := -99.0
var _label: Label3D
var _away := 0.0


func build(shape: WorldShape) -> void:
	if not CAMPS.has(Region.current):
		return
	_shape = shape
	var c: Dictionary = CAMPS[Region.current]
	var at: Vector2 = c["at"]
	_center = Vector3(at.x, shape.height_at(at.x, at.y), at.y)
	add_to_group("map_building")
	set_meta("map_size", Vector2(20, 20))
	global_position = _center
	_build_ring()
	_piece("camp_big_tent", Vector2(7.0, 1.5), PI, Vector3(5.2, 3.2, 4.2))
	_piece("camp_tent", Vector2(2.5, 7.5), -PI / 2.0 + 0.3, Vector3(3.3, 2.1, 2.6))
	_piece("camp_tent", Vector2(-3.5, 7.0), -PI / 2.0 - 0.2, Vector3(3.3, 2.1, 2.6))
	_piece("camp_tent", Vector2(3.0, -7.0), PI / 2.0 - 0.2, Vector3(3.3, 2.1, 2.6))
	_piece("camp_watch", Vector2(-7.5, -5.5), 0.3, Vector3(2.3, 3.8, 2.3))
	_piece("camp_banner", Vector2(4.0, 3.8), -0.4, Vector3(0.3, 4.0, 0.3))
	_piece("camp_rack", Vector2(-1.5, -3.2), 0.2, Vector3(1.8, 1.4, 0.8))
	_piece("camp_crates", Vector2(-4.0, -7.5), 0.8, Vector3(2.4, 1.4, 1.4))
	_piece("camp_crates", Vector2(8.5, -4.0), 2.2, Vector3(2.4, 1.4, 1.4))
	_fire(Vector3(0, 0, 0))
	for p in [Vector2(-1.9, 0.9), Vector2(1.6, -1.4)]:        # logs to sit on by the fire
		var log := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.22
		cyl.bottom_radius = 0.22
		cyl.height = 1.4
		cyl.radial_segments = 7
		log.mesh = cyl
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.3, 0.22, 0.16)
		log.material_override = m
		add_child(log)
		log.position = _ground(p) - _center + Vector3(0, 0.2, 0)
		log.rotation = Vector3(0, atan2(p.x, p.y) + PI / 2.0, PI / 2.0)
	_label = Label3D.new()
	_label.text = c["name"]
	_label.font_size = 52
	_label.outline_size = 14
	_label.pixel_size = 0.01
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate = Color(1.0, 0.55, 0.45, 0.0)
	_label.outline_modulate = Color(0, 0, 0, 0.0)
	_label.position = Vector3(0, 7.5, 0)
	add_child(_label)
	# Who lives here: kind, look, where they stand (camp coordinates), facing, pose, and a beat to walk.
	_roster = [
		{"kind": "cutthroat", "look": 0, "at": Vector2(-1.9, 1.35), "turn": atan2(1.9, -1.35), "pose": "Sitting_Idle"},
		{"kind": "cutthroat", "look": 1, "at": Vector2(1.6, -1.85), "turn": atan2(-1.6, 1.85), "pose": "Sitting_Idle"},
		{"kind": "shield", "look": 2, "at": Vector2(-10.2, 0.0), "turn": -PI / 2.0, "pose": ""},
		{"kind": "archer", "look": 3, "at": Vector2(-6.2, -7.2), "turn": -PI / 2.0 - 0.6, "pose": "Idle_FoldArms"},
		{"kind": "archer", "look": 3, "at": Vector2(5.5, -8.5), "turn": PI * 0.9, "pose": "", "beat": [Vector2(5.5, -8.5), Vector2(8.5, -5.0)]},
		{"kind": "cutthroat", "look": 4, "at": Vector2(-6.0, 5.0), "turn": 0.0, "pose": "",
			"beat": [Vector2(-6.0, 5.0), Vector2(0.0, 8.8), Vector2(6.0, 5.5), Vector2(-4.0, -4.5)]},
		{"kind": "cutthroat", "look": 1, "at": Vector2(-14.5, 6.0), "turn": 0.0, "pose": "",
			"beat": [Vector2(-14.5, 6.0), Vector2(-4.0, 14.5), Vector2(10.0, 11.0), Vector2(14.5, -4.0), Vector2(4.0, -14.5), Vector2(-12.0, -8.0)]},
		{"kind": "leader", "look": 5, "at": Vector2(3.8, 1.8), "turn": -PI / 2.0, "pose": "Idle_FoldArms"},
	]
	for i in _roster.size():
		_spawn(i)


func _spawn(i: int) -> void:
	var r: Dictionary = _roster[i]
	var b := Bandit.new()
	b.kind = r["kind"]
	b.camp = self
	b.player = player
	b.day_night = day_night
	b.post = _ground(r["at"])
	b.post_turn = r["turn"]
	b.idle_pose = r["pose"]
	b.look = BanditLooks.make(r["look"], i)
	b.body_scale = 1.1 if r["kind"] == "leader" else (1.05 if r["kind"] == "shield" else 1.0)
	for spot: Vector2 in r.get("beat", []):
		b.beat.append(_ground(spot))
	get_parent().add_child(b)
	b.global_position = b.post + Vector3(0, 0.2, 0)
	r["node"] = b


# --- running the fight --------------------------------------------------------------------------

## A bandit asks to attack. Only a few may at once; the leader always may.
func request_turn(b: Node) -> bool:
	_turns = _turns.filter(func(n: Node) -> bool: return is_instance_valid(n) and n.is_alive() and n.state in [Bandit.State.WINDUP, Bandit.State.ATTACK])
	if b in _turns:
		return true
	if b.kind == "leader" or _turns.size() < Balance.BANDIT_TURNS:
		_turns.append(b)
		return true
	return false


func end_turn(b: Node) -> void:
	_turns.erase(b)


## Someone shouted: everyone within earshot (the whole camp for Varek's roar) joins in, a beat apart.
func raise_alarm(at: Vector3, everyone: bool) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _alarm_at > 20.0:
		get_tree().call_group("hud", "hint", "You've been spotted!")
		for r in _roster:
			var n: Node = r.get("node")
			if is_instance_valid(n) and n.alerted:
				n.play_spotted()
				break
	_alarm_at = now
	for r in _roster:
		var n: Node = r.get("node")
		if not is_instance_valid(n) or not n.is_alive() or n.alerted:
			continue
		if everyone or (n as Node3D).global_position.distance_to(at) < Balance.STEALTH["shout"]:
			get_tree().create_timer(randf_range(0.25, 0.9)).timeout.connect(func() -> void:
				if is_instance_valid(n):
					n.hear_alarm())


func bandit_died(b: Node, quiet: bool) -> void:
	_turns.erase(b)
	_bodies.append([b, Time.get_ticks_msec() / 1000.0])
	if quiet:
		FloatText.spawn(get_tree(), (b as Node3D).global_position + Vector3(0, 1.6, 0), "Takedown", Color(0.85, 0.85, 0.95))
	if b.kind == "leader":
		_leader_down(b)


## True if an unaware bandit can see a fallen comrade (then it comes to look).
func body_seen_by(b: Node3D) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	for entry: Array in _bodies:
		var body: Node3D = entry[0]
		if not is_instance_valid(body) or now - entry[1] < 1.5:
			continue
		var to := body.global_position - b.global_position
		to.y = 0.0
		if to.length() < 9.0 and b._facing().dot(to.normalized()) > 0.3:
			b._last_seen = body.global_position
			return true
	return false


func _leader_down(b: Node3D) -> void:
	if Quests.is_active("morrow_seal") and Inventory.count("black_seal") == 0:
		var drop := Node3D.new()
		drop.set_script(DROP)
		get_parent().add_child(drop)
		drop.launch("black_seal", b.global_position + Vector3(0, 1.0, 0), Vector3(0.6, 4.5, 0.4), b.global_position.y, player)
		Banner.show_now(get_tree().get_first_node_in_group("hud"), "TARGET DOWN", "Take the black seal", Color(0.85, 0.2, 0.18),
			preload("res://assets/sounds/kill.wav"))
	else:
		Banner.show_now(get_tree().get_first_node_in_group("hud"), "VAREK FALLS", "The Red Hand is broken, for now", Color(0.85, 0.2, 0.18),
			preload("res://assets/sounds/kill.wav"))


func _process(delta: float) -> void:
	if player == null or _label == null:
		return
	var d := player.global_position.distance_to(_center)
	var a := move_toward(_label.modulate.a, 1.0 if d < 24.0 else 0.0, delta * 2.0)
	_label.modulate.a = a
	_label.outline_modulate.a = a * 0.7
	# Long after you've gone, the camp fills up again (bodies cleared, the dead back at their posts).
	_away = _away + delta if d > RESPAWN_AWAY else 0.0
	if _away > RESPAWN_AFTER:
		_away = 0.0
		for i in _roster.size():
			var n: Node = _roster[i].get("node")
			if is_instance_valid(n) and not n.is_alive():
				n.queue_free()
				_spawn(i)
		_bodies.clear()
	# Bodies stay a while, then go.
	var now := Time.get_ticks_msec() / 1000.0
	for entry: Array in _bodies:
		var body: Node3D = entry[0]
		if is_instance_valid(body) and now - entry[1] > 40.0 and body.visible:
			body.visible = false


# --- building --------------------------------------------------------------------------------------

## The stake wall: every section is the same model, drawn in one go (a MultiMesh), each with its own box.
func _build_ring() -> void:
	var src := TREASURE._solid((load(DIR % "camp_palisade") as PackedScene).instantiate())
	var mi: MeshInstance3D = src.find_children("*", "MeshInstance3D", true, false)[0]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mi.mesh
	var spots: Array[Transform3D] = []
	var count := 17
	for k in count:
		var a := k * TAU / count
		if absf(angle_difference(a, PI)) < 0.3:          # the gate (west)
			continue
		if absf(angle_difference(a, PI * 0.28)) < 0.2:     # a gap at the back, where the stakes fell
			continue
		var spot := Vector2(cos(a), sin(a)) * RING
		var xf := Transform3D(Basis(Vector3.UP, -a + PI / 2.0), _ground(spot) - _center)
		spots.append(xf)
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(4.1, 2.5, 0.5)
		col.shape = box
		col.position = Vector3(0, 1.25, 0)
		body.add_child(col)
		body.transform = xf
		add_child(body)
	mm.instance_count = spots.size()
	for i in spots.size():
		mm.set_instance_transform(i, spots[i])
	var wall := MultiMeshInstance3D.new()
	wall.multimesh = mm
	wall.material_override = mi.get_surface_override_material(0)
	add_child(wall)
	src.free()


## One model at camp coordinates `spot` (x, z), turned `turn`, with a box to bump into (`size`).
func _piece(model: String, spot: Vector2, turn: float, size: Vector3) -> void:
	var m := TREASURE._solid((load(DIR % model) as PackedScene).instantiate())
	add_child(m)
	m.position = _ground(spot) - _center
	m.rotation.y = turn
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position = Vector3(0, size.y / 2.0, 0)
	body.add_child(col)
	m.add_child(body)


func _fire(at: Vector3) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = at
	for k in 7:                                        # a ring of stones
		var a := k * TAU / 7.0
		var stone := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.2
		sm.height = 0.28
		sm.radial_segments = 6
		sm.rings = 3
		stone.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.4, 0.39, 0.4)
		stone.material_override = mat
		stone.position = Vector3(cos(a) * 0.6, 0.08, sin(a) * 0.6)
		root.add_child(stone)
	var flame := CPUParticles3D.new()
	flame.amount = 22
	flame.lifetime = 0.8
	flame.local_coords = false
	flame.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flame.emission_sphere_radius = 0.25
	flame.direction = Vector3.UP
	flame.spread = 12.0
	flame.gravity = Vector3(0, 2.0, 0)
	flame.initial_velocity_min = 0.6
	flame.initial_velocity_max = 1.4
	flame.scale_amount_min = 0.6
	flame.scale_amount_max = 1.2
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.35
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.vertex_color_use_as_albedo = true
	quad.material = fm
	flame.mesh = quad
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.8, 0.3, 0.9))
	ramp.set_color(1, Color(0.9, 0.2, 0.05, 0.0))
	flame.color_ramp = ramp
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.position = Vector3(0, 0.25, 0)
	root.add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.3)
	light.light_energy = 1.6
	light.omni_range = 9.0
	light.shadow_enabled = false
	light.position = Vector3(0, 1.0, 0)
	root.add_child(light)


func _ground(spot: Vector2) -> Vector3:
	var x := _center.x + spot.x
	var z := _center.z + spot.y
	return Vector3(x, _shape.height_at(x, z), z)
