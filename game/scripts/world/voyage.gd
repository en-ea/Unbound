extends Node3D
## The voyage between the lands (Region "sea"): you're at the wheel of your ship on the open sea.
## Drag left or right (or A/D) to steer. Bound for Sunreach the first time: islets and sea rocks, then a
## storm rolls in, the Drowned Reach's serpent rises and strikes (its glowing rings on the water show
## where; steer clear), until Sunreach's lighthouse beam drives it under. The storm breaks into golden
## light, the coast rises ahead, and you come ashore (Region.travel to Region.voyage_to).
## Later trips are calm (the serpent remembers you, and keeps its distance).

const DIR := "res://assets/sunreach/%s.glb"
const TREASURE := preload("res://scripts/world/treasure.gd")
const SEA_SHADER := preload("res://shaders/sea.gdshader")
const CINZEL := preload("res://assets/fonts/Cinzel-Variable.ttf")
const ALMENDRA := preload("res://assets/fonts/Almendra-Regular.ttf")
const SPEED := 10.0
const TURN := 0.75
const SEGMENTS := 14
const SEG_GAP := 2.3
const STRIKE_R := 7.0
const SAVE := "user://voyage.cfg"

var player: Node3D
var camera_rig: Node3D
var day_night: Node

var _length := 760.0
var _first := true
var _ship: Node3D
var _sail: Node3D
var _sea: MeshInstance3D
var _sea_mat: ShaderMaterial
var _cam: Camera3D
var _heading := 0.0                  # yaw; 0 = towards -Z (the destination)
var _pos := Vector3.ZERO
var _steer := 0.0
var _drag_from := -1.0
var _travelled := 0.0
var _storm := 0.0
var _storm_goal := 0.0
var _shake := 0.0
var _hits := 0
var _done := false
var _cam_override := {}              # {"pos": Vector3, "look": Vector3} while a cinematic shot holds
var _t := 0.0

# The serpent
var _serpent: Node3D
var _head: Node3D
var _body: Array[Node3D] = []
var _trail: Array[Vector3] = []
var _head_pos := Vector3(0, -30, 0)
var _ring: MeshInstance3D

# Screen
var _layer: CanvasLayer
var _gloom: ColorRect
var _flash: ColorRect
var _caption: Label
var _hint: Label
var _bar: ProgressBar
var _rain: CPUParticles3D
var _audio: Array[AudioStreamPlayer] = []


func build() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE)
	_first = Region.voyage_to == "sands" and not cfg.get_value("voyage", "serpent_met", false)
	if Region.voyage_to != "sands":
		_length = 460.0
	elif not _first:
		_length = 520.0
	day_night.set_time(0.4)
	_build_sea()
	_build_ship()
	_build_scenery()
	_build_ui()
	_cam = Camera3D.new()
	_cam.fov = 62.0
	_cam.far = 900.0
	add_child(_cam)
	_cam.make_current()
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	Controls.locked = true
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.visible = false
	_place_cam(1.0)
	_story()


# --- the voyage, beat by beat ------------------------------------------------------------------

func _story() -> void:
	var bound := "Sunreach" if Region.voyage_to == "sands" else "the mainland"
	await _say("Bound for %s." % bound, 2.6)
	_hint.text = "Drag left or right to steer"
	_hint.modulate.a = 1.0
	get_tree().create_timer(5.0).timeout.connect(func() -> void: create_tween().tween_property(_hint, "modulate:a", 0.0, 1.0))
	if not _first:
		await _until(0.92)
		await _arrive()
		return
	await _until(0.22)
	await _say("The sky ahead is the colour of a bruise.", 3.0)
	_storm_goal = 1.0
	await _until(0.36)
	await _say("Something is moving under the hull.", 2.4)
	_shake = 0.25
	await _serpent_rises()
	for i in 3:
		await _strike(i)
	await _lighthouse_saves()
	_storm_goal = 0.0
	var cfg := ConfigFile.new()
	cfg.set_value("voyage", "serpent_met", true)
	cfg.save(SAVE)
	await _until(0.8)
	day_night.set_time(0.66)            # the storm breaks into late gold
	await _say("Land! Sunreach, gold under the sun.", 3.2)
	await _until(0.94)
	await _arrive()


func _arrive() -> void:
	_done = true
	await _say("Coming ashore...", 1.6)
	var to := Region.voyage_to
	Controls.locked = false
	Region.travel(to, Region.HARBOURS.get(to, Vector2.INF))


func _until(fraction: float) -> void:
	while _travelled < _length * fraction:
		await get_tree().process_frame


# --- the serpent -------------------------------------------------------------------------------

func _serpent_rises() -> void:
	_build_serpent()
	_sound("wolf_growl", 0.32, 6.0)
	var fwd := _forward()
	var right := fwd.cross(Vector3.UP)
	var start := _pos + fwd * 42.0 + right * 26.0
	var end := _pos + fwd * 52.0 - right * 30.0
	# A slow, huge arc right across your bow, out of the water and back in.
	var t := 0.0
	while t < 1.0:
		t += get_process_delta_time() / 5.5
		var p := start.lerp(end + fwd * _travelled * 0.0, t)
		p += fwd * (SPEED * t * 5.5)          # it keeps pace
		p.y = sin(t * PI) * 16.0 - 4.0
		_head_pos = p
		_cam_override = {"pos": _pos - fwd * 6.0 + Vector3(0, 3.2, 0) + right * 4.0, "look": p}
		_shake = 0.12
		await get_tree().process_frame
	_cam_override = {}
	_sound("fish_splash", 0.4, 6.0)
	_shake = 0.5
	await _say("The serpent of the Drowned Reach.", 2.4)


## One strike: a glowing ring opens on the water where you're headed; get the ship out of it.
func _strike(i: int) -> void:
	_hint.text = "Steer out of the ring!"
	_hint.modulate.a = 1.0
	var lead := 2.6 - i * 0.35
	var target := _pos + _forward() * SPEED * lead
	target.y = WorldShape.WATER_Y + 0.15
	_ring.global_position = target
	_ring.visible = true
	_head_pos = target + Vector3(0, -14, 0)
	var t := 0.0
	while t < lead:
		t += get_process_delta_time()
		var s := lerpf(0.4, 1.0, minf(t / lead * 1.6, 1.0))
		_ring.scale = Vector3(s, 1, s)
		(_ring.material_override as StandardMaterial3D).albedo_color.a = 0.35 + 0.4 * absf(sin(t * 9.0))
		await get_tree().process_frame
	_ring.visible = false
	_hint.modulate.a = 0.0
	# It bursts up out of the ring.
	_sound("wolf_snap", 0.45, 6.0)
	_sound("fish_splash", 0.35, 6.0)
	var hit := Vector2(_pos.x - target.x, _pos.z - target.z).length() < STRIKE_R
	t = 0.0
	while t < 1.6:
		t += get_process_delta_time()
		_head_pos = target + Vector3(0, sin(minf(t / 1.6, 1.0) * PI) * 13.0 - 3.0, 0)
		await get_tree().process_frame
	if hit:
		_hits += 1
		_shake = 0.9
		_flash_screen(Color(1.0, 0.3, 0.2, 0.45))
		await _say("It hits the hull! Timbers crack.", 1.6)
	else:
		_shake = 0.3
		await _say(["Missed you by a breath.", "Too slow, old thing.", "Clear!"][i], 1.2)
	_head_pos.y = -30.0


func _lighthouse_saves() -> void:
	var fwd := _forward()
	_head_pos = _pos + fwd * 30.0 + Vector3(0, 10, 0)
	_sound("wolf_growl", 0.28, 6.0)
	await _say("It rises for the last time-", 1.4)
	# A golden beam cuts through the storm from far ahead: Sunreach's lighthouse.
	var beam := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.2
	mesh.bottom_radius = 3.5
	mesh.height = 400.0
	mesh.radial_segments = 10
	mesh.cap_top = false
	mesh.cap_bottom = false
	beam.mesh = mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.8, 0.4, 0.0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = m
	add_child(beam)
	var from := Vector3(0, 30, -_length)
	beam.global_position = (from + _head_pos) * 0.5
	beam.look_at(_head_pos, Vector3.UP)
	beam.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	beam.scale = Vector3(1, from.distance_to(_head_pos) / 400.0, 1)
	_sound("shrine_wake", 1.0, 0.0)
	_flash_screen(Color(1.0, 0.85, 0.5, 0.7))
	var t := 0.0
	while t < 2.6:
		t += get_process_delta_time()
		m.albedo_color.a = minf(t * 2.0, 0.55)
		_cam_override = {"pos": _pos - fwd * 8.0 + Vector3(0, 5.0, 0), "look": _head_pos}
		_head_pos.y -= get_process_delta_time() * (2.0 + t * 6.0)
		_shake = 0.3
		await get_tree().process_frame
	_cam_override = {}
	_sound("wolf_yelp", 0.3, 6.0)
	create_tween().tween_property(m, "albedo_color:a", 0.0, 2.0).finished.connect(beam.queue_free)
	_head_pos.y = -40.0
	await _say("The lighthouse of Sunreach. Its light drives the serpent down.", 3.0)
	await _say("Somewhere far below, it remembers you.", 2.6)


func _build_serpent() -> void:
	_serpent = Node3D.new()
	add_child(_serpent)
	_head = _piece("serpent_head", Color(0.12, 0.3, 0.42), Vector3(2.6, 2.0, 3.6))
	for i in SEGMENTS:
		var s := _piece("serpent_segment" if i < SEGMENTS - 1 else "serpent_tail", Color(0.1, 0.26, 0.38), Vector3.ONE * lerpf(2.2, 1.0, float(i) / SEGMENTS))
		s.scale = Vector3.ONE * lerpf(1.0, 0.55, float(i) / SEGMENTS)
		_body.append(s)
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = STRIKE_R - 0.6
	torus.outer_radius = STRIKE_R
	torus.rings = 32
	torus.ring_segments = 4
	_ring.mesh = torus
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rm.albedo_color = Color(0.3, 1.0, 0.95, 0.6)
	_ring.material_override = rm
	_ring.scale = Vector3(1, 0.05, 1)
	_ring.visible = false
	add_child(_ring)


## A serpent part from the model, or a plain stand-in if the model isn't there.
func _piece(model: String, color: Color, size: Vector3) -> Node3D:
	var path := DIR % model
	var n: Node3D
	if ResourceLoader.exists(path):
		n = TREASURE._solid((load(path) as PackedScene).instantiate())
	else:
		n = MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = size.x * 0.5
		sph.height = size.z
		sph.radial_segments = 8
		sph.rings = 4
		(n as MeshInstance3D).mesh = sph
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		(n as MeshInstance3D).material_override = mat
	_serpent.add_child(n)
	n.position = Vector3(0, -40, 0)
	return n


func _update_serpent(delta: float) -> void:
	if _serpent == null:
		return
	var prev := _head.global_position
	_head.global_position = prev.lerp(_head_pos, minf(delta * 6.0, 1.0))
	var moved := _head.global_position - prev
	if moved.length() > 0.01:
		_head.look_at(_head.global_position + moved, Vector3.UP)     # the head model faces -Z, as look_at aims
	if _trail.is_empty() or _trail[0].distance_to(_head.global_position) > 0.4:
		_trail.push_front(_head.global_position)
		if _trail.size() > 200:
			_trail.pop_back()
	# Each ring sits a fixed distance back along the head's trail.
	var want := SEG_GAP
	var acc := 0.0
	var idx := 0
	for i in _body.size():
		while idx < _trail.size() - 1 and acc + _trail[idx].distance_to(_trail[idx + 1]) < want:
			acc += _trail[idx].distance_to(_trail[idx + 1])
			idx += 1
		var p := _trail[mini(idx, _trail.size() - 1)]
		var ahead := _trail[maxi(idx - 1, 0)]
		_body[i].global_position = p
		if ahead.distance_to(p) > 0.01:
			_body[i].look_at(ahead, Vector3.UP)
		want += SEG_GAP * _body[i].scale.x


# --- every frame -------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	var key := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) \
		- float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	var steer := clampf(_steer + key, -1.0, 1.0)
	if not _done:
		_heading -= steer * TURN * delta
		# The ship holds roughly to its course on its own (you can't get lost at sea).
		_heading = lerpf(_heading, 0.0, delta * (0.05 if absf(steer) > 0.1 else 0.35))
		var speed := SPEED * (1.0 - 0.08 * _hits)
		_pos += _forward() * speed * delta
		_travelled = -_pos.z
	_storm = move_toward(_storm, _storm_goal, delta * 0.15)
	_sea_mat.set_shader_parameter("swell", lerpf(0.4, 1.2, _storm))
	_sea_mat.set_shader_parameter("darken", _storm)
	_sea.global_position = Vector3(snappedf(_pos.x, 8.0), WorldShape.WATER_Y, snappedf(_pos.z, 8.0))
	_gloom.color.a = _storm * 0.45
	_rain.emitting = _storm > 0.3
	_rain.global_position = _pos + Vector3(0, 12, -6)
	if _storm > 0.6 and randf() < delta * 0.25:     # lightning
		_flash_screen(Color(0.85, 0.9, 1.0, 0.55))
		get_tree().create_timer(randf_range(0.3, 1.2)).timeout.connect(func() -> void: _sound("tree_thud", 0.35, 4.0))
	# The ship rides the swell: height and tilt from the same waves the sea shader draws.
	var fwd := _forward()
	var right := fwd.cross(Vector3.UP)
	var bow := _wave_y(_pos + fwd * 4.0)
	var stern := _wave_y(_pos - fwd * 4.0)
	var port := _wave_y(_pos - right * 2.0)
	var star := _wave_y(_pos + right * 2.0)
	var y := (bow + stern + port + star) * 0.25
	_ship.global_position = Vector3(_pos.x, WorldShape.WATER_Y + y, _pos.z)
	_ship.rotation = Vector3(atan2(bow - stern, 8.0), _heading, atan2(star - port, 4.0) + steer * 0.06)
	if _sail:
		_sail.scale = Vector3(1.0, 1.0, 1.0 + 0.06 * sin(_t * 2.3))
	player.global_position = _ship.global_transform * Vector3(0, 1.05, 3.6)
	player.visual.rotation.y = _heading + PI
	_bar.value = _travelled / _length * 100.0
	_update_serpent(delta)
	_place_cam(delta)


func _place_cam(delta: float) -> void:
	var fwd := _forward()
	var pos: Vector3
	var look: Vector3
	if _cam_override.is_empty():
		pos = _pos - fwd * 15.0 + Vector3(0, 6.5, 0) + fwd.cross(Vector3.UP) * _steer * 2.0
		look = _pos + fwd * 12.0 + Vector3(0, 1.5, 0)
	else:
		pos = _cam_override["pos"]
		look = _cam_override["look"]
	_cam.global_position = _cam.global_position.lerp(pos, minf(delta * 3.0, 1.0))
	_shake = move_toward(_shake, 0.0, delta * 0.8)
	var jitter := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.3
	_cam.look_at(look + jitter, Vector3.UP)


func _forward() -> Vector3:
	return Vector3(-sin(_heading), 0, -cos(_heading))


## The sea shader's swell at a spot (same three waves).
func _wave_y(p: Vector3) -> float:
	var swell := lerpf(0.4, 1.2, _storm)
	var t := Time.get_ticks_msec() / 1000.0
	var y := 0.0
	for w in [[Vector2(0.3, 1.0), 23.0, 1.0], [Vector2(-0.7, 0.6), 13.0, 0.55], [Vector2(0.9, -0.2), 7.0, 0.3]]:
		var k: float = TAU / w[1]
		var d: Vector2 = (w[0] as Vector2).normalized()
		y += sin(k * d.dot(Vector2(p.x, p.z)) - t * sqrt(9.8 * k)) * swell * w[2]
	return y


func _input(event: InputEvent) -> void:
	var w := get_viewport().get_visible_rect().size.x
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		_drag_from = event.position.x if event.pressed else -1.0
		if not event.pressed:
			_steer = 0.0
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _drag_from >= 0.0:
		_steer = clampf((event.position.x - _drag_from) / (w * 0.18), -1.0, 1.0)


# --- building the scene ------------------------------------------------------------------------

func _build_sea() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(900, 900)
	plane.subdivide_width = 120
	plane.subdivide_depth = 120
	_sea_mat = ShaderMaterial.new()
	_sea_mat.shader = SEA_SHADER
	_sea_mat.set_shader_parameter("use_depth", false)
	plane.material = _sea_mat
	_sea = MeshInstance3D.new()
	_sea.mesh = plane
	_sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sea)
	_rain = CPUParticles3D.new()
	_rain.amount = 260
	_rain.lifetime = 0.9
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(22, 1, 22)
	_rain.direction = Vector3(0.15, -1, 0)
	_rain.spread = 4.0
	_rain.gravity = Vector3(0, -30, 0)
	_rain.initial_velocity_min = 18.0
	_rain.initial_velocity_max = 24.0
	var drop := QuadMesh.new()
	drop.size = Vector2(0.03, 0.7)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color = Color(0.8, 0.88, 1.0, 0.35)
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	drop.material = dm
	_rain.mesh = drop
	_rain.emitting = false
	add_child(_rain)


func _build_ship() -> void:
	var path := DIR % "ship"
	if ResourceLoader.exists(path):
		_ship = TREASURE._solid((load(path) as PackedScene).instantiate())
		_sail = _ship.find_child("Sail", true, false) as Node3D
	else:
		_ship = MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(4, 1.2, 11)
		(_ship as MeshInstance3D).mesh = box
	add_child(_ship)


## Islets and sea rocks off both sides of the course; Sunreach's mesas and lighthouse at the end.
func _build_scenery() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 46:
		var z := -rng.randf_range(40.0, _length - 60.0)
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * rng.randf_range(28.0, 140.0)
		var model := "islet" if rng.randf() < 0.35 else "sea_rock"
		var n := _static(model, Vector3(x, WorldShape.WATER_Y, z), rng.randf_range(0.8, 2.0), rng.randf() * TAU)
		if n == null:
			break
	if Region.voyage_to != "sands":
		return
	var shore := -_length - 40.0
	for i in 18:                                   # Sunreach's skyline: banded mesas behind the beach
		var x := -260.0 + i * 30.0 + rng.randf_range(-8, 8)
		_static("mesa_big", Vector3(x, WorldShape.WATER_Y - 2.0, shore - 60.0 - rng.randf_range(0, 50)), rng.randf_range(2.0, 3.6), rng.randf() * TAU)
	for i in 10:
		_static("islet", Vector3(-150.0 + i * 32.0 + rng.randf_range(-6, 6), WorldShape.WATER_Y, shore + rng.randf_range(-10, 10)), rng.randf_range(1.6, 2.6), rng.randf() * TAU)
	var tower := _static("lighthouse", Vector3(-40.0, WorldShape.WATER_Y + 1.0, shore + 10.0), 1.4, 0.0)
	if tower:
		var fire := OmniLight3D.new()
		fire.light_color = Color(1.0, 0.72, 0.35)
		fire.light_energy = 3.0
		fire.omni_range = 40.0
		fire.position = Vector3(0, 16.0, 0)
		tower.add_child(fire)


func _static(model: String, at: Vector3, s: float, yaw: float) -> Node3D:
	var path := DIR % model
	if not ResourceLoader.exists(path):
		return null
	var n := TREASURE._solid((load(path) as PackedScene).instantiate())
	add_child(n)
	n.global_position = at
	n.scale = Vector3.ONE * s
	n.rotation.y = yaw
	return n


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 40
	add_child(_layer)
	_gloom = ColorRect.new()
	_gloom.color = Color(0.05, 0.08, 0.14, 0.0)
	_gloom.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gloom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_gloom)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_flash)
	_caption = Label.new()
	_caption.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_caption.offset_top = 110.0
	_caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_override("font", ALMENDRA)
	_caption.add_theme_font_size_override("font_size", 34)
	_caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_caption.add_theme_constant_override("outline_size", 10)
	_caption.modulate.a = 0.0
	_layer.add_child(_caption)
	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_top = -150.0
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_override("font", CINZEL)
	_hint.add_theme_font_size_override("font_size", 28)
	_hint.add_theme_color_override("font_color", Color(0.6, 1.0, 0.95))
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_hint.add_theme_constant_override("outline_size", 10)
	_hint.modulate.a = 0.0
	_layer.add_child(_hint)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_bar.offset_top = 40.0
	_bar.offset_left = -160.0
	_bar.offset_right = 160.0
	_bar.offset_bottom = 50.0
	_bar.modulate = Color(1.0, 0.85, 0.55, 0.8)
	_layer.add_child(_bar)
	var amb := AudioStreamPlayer.new()
	amb.stream = preload("res://assets/sounds/amb_pond.wav")
	amb.volume_db = -6.0
	add_child(amb)
	amb.play()


func _say(text: String, secs: float) -> void:
	_caption.text = text
	var t := create_tween()
	t.tween_property(_caption, "modulate:a", 1.0, 0.4)
	t.tween_interval(secs)
	t.tween_property(_caption, "modulate:a", 0.0, 0.5)
	await t.finished


func _flash_screen(c: Color) -> void:
	_flash.color = c
	create_tween().tween_property(_flash, "color:a", 0.0, 0.5)


func _sound(name: String, pitch: float, db: float) -> void:
	var a := AudioStreamPlayer.new()
	a.stream = load("res://assets/sounds/%s.wav" % name)
	a.pitch_scale = pitch
	a.volume_db = db
	add_child(a)
	a.play()
	a.finished.connect(a.queue_free)
