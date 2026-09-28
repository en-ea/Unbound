class_name AttackTell
extends MeshInstance3D
## The warning before an enemy attacks: a lane on the ground showing where it will go, filling up
## as the attack gets closer (shaders/attack_tell.gdshader). The enemy calls aim() every frame of
## its wind-up and stop() when it attacks or is interrupted; the lane fades in and out on its own.

const SHADER := preload("res://shaders/attack_tell.gdshader")
const LIFT := 0.12            # just above the ground
const SEGMENTS := 8           # the lane bends with the ground at these steps

var _mat: ShaderMaterial
var _mesh := ArrayMesh.new()
var _origin := Vector3.INF
var _dir := Vector3.ZERO
var _alpha := 0.0
var _on := false


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh = _mesh
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material_override = _mat
	visible = false


## origin: the enemy's feet; dir: flat direction of the attack; progress: 0..1 of the wind-up.
func aim(origin: Vector3, dir: Vector3, length: float, width: float, progress: float) -> void:
	_on = true
	if origin.distance_to(_origin) > 0.05 or dir.distance_to(_dir) > 0.01:     # only rebuilt when it moves
		_build(origin, dir, length, width)
	_mat.set_shader_parameter("progress", progress)
	_mat.set_shader_parameter("length", length)


## A strip from the enemy's feet (UV.y 0) to the tip (UV.y 1), dropped onto the ground at each step.
func _build(origin: Vector3, dir: Vector3, length: float, width: float) -> void:
	_origin = origin
	_dir = dir
	var side := Vector3.UP.cross(dir).normalized() * width * 0.5
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var index := PackedInt32Array()
	var y := origin.y
	for i in SEGMENTS + 1:
		var f := float(i) / SEGMENTS
		var p := origin + dir * length * f
		y = clampf(_ground(p, y), origin.y - 2.5, origin.y + 2.5)
		p.y = y + LIFT
		verts.append_array([p - side, p + side])
		uvs.append_array([Vector2(0, f), Vector2(1, f)])
		if i < SEGMENTS:
			var a := i * 2
			index.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = index
	_mesh.clear_surfaces()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func stop() -> void:
	_on = false


func _process(delta: float) -> void:
	var a := move_toward(_alpha, 1.0 if _on else 0.0, delta * (7.0 if _on else 4.0))
	if a != _alpha:
		_alpha = a
		_mat.set_shader_parameter("alpha", _alpha)
	visible = _alpha > 0.0


func _ground(at: Vector3, fallback: float) -> float:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 4.0)
	query.exclude = [get_parent().get_rid()] if get_parent() is CollisionObject3D else []
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"].y if hit else fallback
