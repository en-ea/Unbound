extends Node3D
## Inside your home: one room far off the map (like the build lab), built for the house you own
## (assets/interior/room_<house>.glb, made by make_interior.py) and furnished from Home.furniture.
## Walk into your front door (or press Enter) to go in; walk out through the doorway (or press
## Leave on the mat) to go out. The hearth cooks, a bed lets you rest (through the night, if it's
## dark), the windows show day or night, and the hearth and lamps give warm light. The HUD's
## Furnish button places furniture (ui/build_mode.gd with room = true). Saving works in here: you
## wake up where you were.

const TREASURE := preload("res://scripts/world/treasure.gd")
const STATION := preload("res://scripts/world/station.gd")
const USE_SPOT := preload("res://scripts/world/use_spot.gd")
const SOLID_SHADER := preload("res://shaders/foliage_solid.gdshader")
const DOOR_SOUND := preload("res://assets/kenney_impact/impactWood_medium_002.ogg")
const AT := Vector3(300, -300, 0)       # far east of the map and far below it
const ENTRY := Vector3(0.0, 0.15, 2.9)
const MAX_LAMPS := 4

var player: CharacterBody3D
var day_night: Node
var door_out := Vector3.ZERO           # set by the plot: where you stand outside your front door
var door_in := Vector3.ZERO            # set by the plot: walking into this spot takes you inside
var active := false
var origin := AT                       # where the room is built (a visit's room is elsewhere)

var _room_for := ""
var _room: Node3D
var _furniture: Node3D
var _fire: OmniLight3D
var _daylight: OmniLight3D
var _glass: ShaderMaterial
var _fog_was := true
var _time := 0.0
var _window_timer := 0.0
var _audio: AudioStreamPlayer


func _ready() -> void:
	if _is_home():
		add_to_group("home_interior")
	global_position = origin
	visible = false
	_audio = AudioStreamPlayer.new()
	_audio.stream = DOOR_SOUND
	_audio.volume_db = -9.0
	_audio.pitch_scale = 0.8
	add_child(_audio)
	Home.furniture_changed.connect(_place_furniture)
	Home.changed.connect(func() -> void:
		if _room_for != "" and Home.owned() and _room_for != _room_key():
			_build_room())


## The action: go inside (a short fade). `instant` skips the fade.
func enter(instant := false) -> void:
	if active or not _can_enter():
		return
	if instant:
		_go_in()
		return
	_audio.play()
	Region.fade_through(_go_in)


## The action: go back out to your front door.
func leave() -> void:
	if not active:
		return
	_audio.play()
	Region.fade_through(_go_out)


## Loading a save made indoors: straight in, standing where you were.
func resume(pos: Vector3, facing: float) -> void:
	_go_in()
	player.global_position = pos
	player.visual.rotation.y = facing
	get_tree().call_group("camera_rig", "snap")


func _go_in() -> void:
	if _room_for != _room_key():
		_build_room()
	active = true
	visible = true
	var env := get_viewport().world_3d.environment      # the world's height fog would wash the room out
	if env:
		_fog_was = env.fog_enabled
		env.fog_enabled = false
	day_night.set_indoors(true)
	player.global_position = origin + ENTRY
	player.velocity = Vector3.ZERO
	player.visual.rotation.y = PI
	get_tree().call_group("camera_rig", "enter_room", origin + Vector3(0, 0.4, -1.1))
	get_tree().call_group("hud", "set_indoors", true, _is_home())
	_update_windows()


func _go_out() -> void:
	_back_outside()
	player.global_position = door_out + Vector3(0, 0.3, 0)
	player.velocity = Vector3.ZERO
	player.visual.rotation.y = 0.0
	get_tree().call_group("camera_rig", "snap")


## Outdoor light, fog, camera and HUD again (also when something else moved you out: a knock-out,
## the build lab).
func _back_outside() -> void:
	active = false
	visible = false
	var env := get_viewport().world_3d.environment
	if env:
		env.fog_enabled = _fog_was
	day_night.set_indoors(false)
	get_tree().call_group("camera_rig", "leave_room")
	get_tree().call_group("hud", "set_indoors", false)


func _physics_process(delta: float) -> void:
	if active:
		var local := player.global_position - origin
		if local.length() > 40.0:
			_back_outside()
			return
		if local.z > Home.ROOM_HALF.y + 0.45 and absf(local.x) < 1.2:
			leave()
		_time += delta
		_fire.light_energy = lerpf(1.6, 2.3, day_night.night) + sin(_time * 7.3) * 0.18 + sin(_time * 12.7 + 1.3) * 0.12 + randf() * 0.06
		_window_timer -= delta
		if _window_timer <= 0.0:
			_update_windows()
		return
	# Outside: walking into your front door takes you in.
	if door_in == Vector3.ZERO or not _can_enter() or Controls.locked:
		return
	if get_tree().get_first_node_in_group("build_mode"):
		return
	var d := player.global_position - door_in
	if absf(d.x) < 0.8 and absf(d.z) < 0.6 and Controls.get_move().y < -0.5:     # pushing towards the door
		enter()


func _update_windows() -> void:
	_window_timer = 0.5
	var night: float = day_night.night
	if _glass:
		_glass.set_shader_parameter("albedo", Color(0.96, 0.97, 1.0).lerp(Color(0.2, 0.26, 0.48), night))
		_glass.set_shader_parameter("glow", lerpf(1.25, 0.55, night))
	if _daylight:
		_daylight.light_energy = lerpf(1.3, 0.0, night)


# --- building the room --------------------------------------------------------------------

## Which room is built (the model: feel and layout).
func _room_key() -> String:
	return _model() if _can_enter() else ""


# What the room is (a visit overrides these).
func _is_home() -> bool:
	return true


func _can_enter() -> bool:
	return Home.owned()


func _model() -> String:
	return Home.room_model()


func _layout() -> Dictionary:
	return Home.room_layout()


func _furnishing() -> Array:
	return Home.furniture


func _build_room() -> void:
	if is_instance_valid(_room):
		_room.queue_free()
	_room_for = _room_key()
	_room = Node3D.new()
	add_child(_room)
	var shell := TREASURE._solid((load(_model()) as PackedScene).instantiate())
	_room.add_child(shell)
	for mi: MeshInstance3D in shell.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():            # softer glow: flames stay orange, not white
			var m := mi.get_surface_override_material(i) as ShaderMaterial
			if m and float(m.get_shader_parameter("glow")) > 0.0:
				m.set_shader_parameter("glow", 0.6)
		if mi.name.begins_with("Windows"):
			_glass = ShaderMaterial.new()
			_glass.shader = SOLID_SHADER
			_glass.set_shader_parameter("sway", 0.0)
			mi.material_override = _glass
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_void()
	_walls()
	var lay := _layout()
	var hearth_at: Vector3 = lay["hearth"]
	_fire = _light(hearth_at + Vector3(0, 0.9, 0) + (lay["cook"] - hearth_at) * 0.6, Color(1.0, 0.64, 0.36), 1.7, 7.5)
	_daylight = _light(lay["window"] + Vector3(0, 0, 0.6), Color(0.8, 0.88, 1.0), 1.3, 6.5)
	var hearth := Node3D.new()
	hearth.set_script(STATION)
	_room.add_child(hearth)
	hearth.setup(origin + lay["cook"], "Cook", {"mode": "cook"})
	hearth.reach = 1.9
	var mat := Node3D.new()
	mat.set_script(USE_SPOT)
	_room.add_child(mat)
	mat.setup(origin + Vector3(0, 0, 3.35), "Leave", leave, 0.9)
	_furniture = Node3D.new()
	_room.add_child(_furniture)
	_place_furniture()


## Darkness all round the room, so it floats like a lit diorama.
func _void() -> void:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120, 120)
	mi.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.05, 0.042, 0.038)
	mi.material_override = mat
	mi.position.y = -0.2
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_room.add_child(mi)


## Floor and walls you can't walk through, the built-in hearth and shelves, and a short way out
## through the doorway (walking down it takes you outside).
func _walls() -> void:
	var body := StaticBody3D.new()
	_room.add_child(body)
	var hx := Home.ROOM_HALF.x
	var hz := Home.ROOM_HALF.y
	_box(body, Vector3(0, -0.5, 1.0), Vector3(hx * 2 + 4, 1, hz * 2 + 6))
	_box(body, Vector3(0, 1.5, -hz - 0.15), Vector3(hx * 2 + 0.6, 3, 0.3))
	for s: float in [-1.0, 1.0]:
		_box(body, Vector3(s * (hx + 0.15), 1.5, 0), Vector3(0.3, 3, hz * 2 + 0.6))
		_box(body, Vector3(s * (hx + 0.8) / 2.0, 1.5, hz + 0.15), Vector3(hx - 0.8, 3, 0.3))
		_box(body, Vector3(s * 0.95, 1.5, hz + 1.0), Vector3(0.3, 3, 1.8))
	_box(body, Vector3(0, 1.5, hz + 1.95), Vector3(2.2, 3, 0.3))
	for r: Rect2 in _layout()["built_in"]:
		_box(body, Vector3(r.get_center().x, 0.6, r.get_center().y), Vector3(r.size.x, 1.2, r.size.y))


func _box(body: StaticBody3D, at: Vector3, size: Vector3) -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = at
	body.add_child(col)


func _light(at: Vector3, color: Color, energy: float, reach: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = reach
	l.omni_attenuation = 1.3
	l.shadow_enabled = false
	l.position = at
	_room.add_child(l)
	return l


## Every piece from Home.furniture, with collision (not rugs), a light for the first few lamps,
## and "Rest" on beds.
func _place_furniture() -> void:
	if not is_instance_valid(_furniture):
		return
	for n in _furniture.get_children():
		n.queue_free()
	var lamps := 0
	for f: Dictionary in _furnishing():
		var info: Array = Home.FURNITURE[f["id"]]
		var node := TREASURE._solid((load(info[1]) as PackedScene).instantiate())
		_furniture.add_child(node)
		node.position = Vector3(f["x"], 0.0, f["z"])
		node.rotation.y = f["turn"]
		if info[3] != "rug":
			var body := StaticBody3D.new()
			node.add_child(body)
			var size: Vector2 = info[2]
			_box(body, Vector3(0, 0.5, 0), Vector3(size.x * 0.9, 1.0, size.y * 0.9))
		else:
			for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if f["id"] in ["lamp", "table"] and lamps < MAX_LAMPS:      # lamps, and the candle on a table
			lamps += 1
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.72, 0.42)
			l.light_energy = 2.0 if f["id"] == "lamp" else 0.9
			l.omni_range = 5.5 if f["id"] == "lamp" else 4.0
			l.omni_attenuation = 1.4
			l.position = Vector3(0, 1.5 if f["id"] == "lamp" else 2.1, 0)
			node.add_child(l)
		if info[4] == "rest" and _is_home():
			var spot := Node3D.new()
			spot.set_script(USE_SPOT)
			_furniture.add_child(spot)
			spot.setup(origin + Vector3(f["x"], 0.0, f["z"]), "Rest", _rest, 1.9)


## Resting in bed: through the night to morning if it's dark, otherwise a short nap. Heals you.
func _rest() -> void:
	var t: float = day_night.time_of_day
	var dark := t > 0.76 or t < 0.24
	Region.fade_through(func() -> void:
		day_night.time_of_day = 0.27 if dark else fposmod(t + 0.08, 1.0)
		day_night.set_indoors(true)
		player.heal_full()
		_update_windows()
		get_tree().call_group("hud", "hint", "You slept until morning. Fully rested." if dark else "A good nap. Fully rested.")
		SaveGame.save_game())
