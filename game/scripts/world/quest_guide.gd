extends Node3D
## A tall golden beam where the quest you follow wants you next (Quests.guide_point): the spot itself, the
## giver when it's time to hand in, or the gate out when it's in another region. Fades out as you arrive.

const BEAM_SHADER := preload("res://shaders/light_beam.gdshader")
const HEIGHT := 40.0
const NEAR := 6.0              # metres: closer than this and the beam fades away

var player: Node3D
var _shape: WorldShape
var _mats: Array[ShaderMaterial] = []
var _tick := 0.0
var _fade := 0.0
var _on := false


func build(shape: WorldShape) -> void:
	_shape = shape
	for i in 2:
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.35 + i * 0.5
		mesh.bottom_radius = 0.45 + i * 0.6
		mesh.height = HEIGHT
		mesh.cap_top = false
		mesh.cap_bottom = false
		mesh.radial_segments = 12
		mesh.rings = 1
		var mat := ShaderMaterial.new()
		mat.shader = BEAM_SHADER
		mat.set_shader_parameter("tint", Color(1.0, 0.82, 0.4))
		mesh.material = mat
		_mats.append(mat)
		var beam := MeshInstance3D.new()
		beam.mesh = mesh
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.position.y = HEIGHT * 0.5 - 0.5
		add_child(beam)
	visible = false


func _process(delta: float) -> void:
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.3
		var g := Quests.guide_point(Quests.tracked_quest())
		_on = not g.is_empty() and player != null
		if _on:
			var at: Vector2 = g["at"]
			global_position = Vector3(at.x, _shape.height_at(at.x, at.y), at.y)
	if not _on:
		_fade = 0.0
		visible = false
		return
	var d := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()
	var want := clampf((d - NEAR) / 10.0, 0.0, 1.0)
	_fade = move_toward(_fade, want, delta * 1.5)
	visible = _fade > 0.01
	for i in _mats.size():
		_mats[i].set_shader_parameter("strength", 0.5 * _fade / (1.0 + i * 1.5))
