extends Node3D
## The story's start: the standing stones on the meadow hill hum until you come close, then the shrine
## wakes. A pillar of light rises, a deep chord sounds, a few words, and the class screen opens.
## Once you've chosen, fire answers you. Only happens once (Classes.awakened).

const LINES := [
	"The stones are warm under your hand.",
	"Something old turns over beneath the hill, and looks at you.",
	"A spark wakes in your chest.",
]
const REACH := 6.5
const BEAM_SHADER := preload("res://shaders/light_beam.gdshader")

var player: Node3D
var _running := false
var _check := 0.0


func build(shape: WorldShape) -> void:
	var c := WorldShape.HILL_CENTER
	global_position = Vector3(c.x, shape.height_at(c.x, c.y), c.y)


func _process(delta: float) -> void:
	_check -= delta
	if _running or Classes.awakened or _check > 0.0 or not is_instance_valid(player):
		return
	_check = 0.3
	var d := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()
	if d < REACH:
		_wake()


## Also usable from the test menu.
func _wake() -> void:
	_running = true
	Controls.locked = true
	var hud := get_tree().get_first_node_in_group("hud")
	Music.sting(preload("res://assets/sounds/shrine_wake.wav"), 0.0)
	# A pillar of light grows out of the stones.
	var pillar := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.6
	mesh.bottom_radius = 2.4
	mesh.height = 30.0
	mesh.cap_top = false
	mesh.cap_bottom = false
	mesh.radial_segments = 20
	var mat := ShaderMaterial.new()
	mat.shader = BEAM_SHADER
	mat.set_shader_parameter("strength", 0.0)
	mesh.material = mat
	pillar.mesh = mesh
	pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pillar.position = Vector3(0, 15.0, 0)
	add_child(pillar)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.5)
	light.light_energy = 0.0
	light.omni_range = 16.0
	light.position = Vector3(0, 3.0, 0)
	add_child(light)
	var t := create_tween()
	t.tween_method(func(v: float) -> void: mat.set_shader_parameter("strength", v), 0.0, 0.7, 2.0)
	t.parallel().tween_property(light, "light_energy", 3.0, 2.0)
	get_tree().call_group("camera_rig", "shake", 0.08)
	player.get_node("Effects").glow_burst(Color(1.0, 0.8, 0.5), 90)
	for i in LINES.size():
		get_tree().create_timer(0.8 + i * 1.9).timeout.connect(func() -> void:
			Banner.show_now(hud, "", LINES[i], Color(1.0, 0.85, 0.55), null, 1.3))
	get_tree().create_timer(0.8 + LINES.size() * 1.9 + 0.3).timeout.connect(func() -> void:
		Banner.show_now(hud, "THE SHRINE WAKES", "", Color(1.0, 0.82, 0.45), null, 1.6)
		Classes.awaken()
		get_tree().create_timer(1.8).timeout.connect(func() -> void:
			var fade := create_tween()
			fade.tween_method(func(v: float) -> void: mat.set_shader_parameter("strength", v), 0.7, 0.0, 3.0)
			fade.parallel().tween_property(light, "light_energy", 0.0, 3.0)
			fade.tween_callback(func() -> void:
				pillar.queue_free()
				light.queue_free())
			_running = false
			hud.open_class_panel(true)))
