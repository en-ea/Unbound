extends Node3D
## This region's waystone (Waystones.STONES): asleep (dim rune) until you come close, then it wakes with a
## flash and a chime and stays lit. At a woken stone the action button says Travel and opens the map
## (ui/world_map.gd) to pick where to go. Model: tools-src/blender/make_waystone.py.

const MODEL := preload("res://assets/props/waystone.glb")
const TREASURE := preload("res://scripts/world/treasure.gd")
const WAKE_REACH := 5.0
const WAKE_SOUND := preload("res://assets/sounds/shrine_wake.wav")

var player: Node3D
var verb := ""
var reach := 2.6
var _glow: Array[ShaderMaterial] = []
var _light: OmniLight3D
var _check := 0.0
var _time := 0.0


func build(shape: WorldShape) -> void:
	if not Waystones.STONES.has(Region.current):
		queue_free()
		return
	var at: Vector2 = Waystones.STONES[Region.current]["at"]
	global_position = Vector3(at.x, shape.height_at(at.x, at.y) - 0.05, at.y)
	var model := TREASURE._solid(MODEL.instantiate())
	add_child(model)
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(s) as ShaderMaterial
			if m and float(m.get_shader_parameter("glow")) > 0.0:
				_glow.append(m)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape_box := CylinderShape3D.new()
	shape_box.radius = 0.55
	shape_box.height = 3.0
	col.shape = shape_box
	col.position.y = 1.5
	body.add_child(col)
	add_child(body)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.5, 0.95, 1.0)
	_light.omni_range = 6.0
	_light.shadow_enabled = false
	_light.position = Vector3(0, 1.6, -0.6)
	add_child(_light)
	add_to_group("interactable")
	add_to_group("map_building")
	set_meta("map_size", Vector2(2.5, 2.5))
	_show_awake(Waystones.is_found(Region.current))


func _show_awake(on: bool) -> void:
	verb = "Travel" if on else ""
	for m in _glow:
		m.set_shader_parameter("glow", 1.6 if on else 0.15)
	_light.visible = on


func interact() -> void:
	get_tree().call_group("hud", "open_map", true)


func _process(delta: float) -> void:
	_time += delta
	if verb != "":
		_light.light_energy = 1.1 + sin(_time * 2.0) * 0.25
		return
	_check -= delta
	if _check > 0.0 or not is_instance_valid(player):
		return
	_check = 0.25
	if player.global_position.distance_to(global_position) < WAKE_REACH and Waystones.attune(Region.current):
		_show_awake(true)
		var p := AudioStreamPlayer.new()
		p.stream = WAKE_SOUND
		p.volume_db = -6.0
		add_child(p)
		p.play()
		p.finished.connect(p.queue_free)
		player.get_node("Effects").glow_burst(Color(0.5, 0.95, 1.0), 50)
		Banner.show_now(get_tree().get_first_node_in_group("hud"), "WAYSTONE WOKEN", Waystones.STONES[Region.current]["name"] +
			": travel between woken waystones from here.", Color(0.55, 0.95, 1.0), null, 2.2)
