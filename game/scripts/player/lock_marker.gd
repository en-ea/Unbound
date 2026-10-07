class_name LockMarker
extends Node3D
## Shows which enemy your attacks go to: an orange ring under it and a bobbing arrow above.
## Faint while the enemy is near but out of reach, bright once Attack would hit it.

const SEEN_RANGE := 9.0
const COLOR := Color(1.0, 0.55, 0.15)

var fighter: Node                 # the player's Fighter (target, nearest_enemy)

var _ring: MeshInstance3D
var _arrow: MeshInstance3D
var _mat: StandardMaterial3D
var _t := 0.0


func _ready() -> void:
	top_level = true
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = COLOR
	var torus := TorusMesh.new()
	torus.inner_radius = 0.95
	torus.outer_radius = 1.08
	torus.rings = 32
	torus.ring_segments = 4
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.material_override = _mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.2
	cone.bottom_radius = 0.0
	cone.height = 0.36
	cone.radial_segments = 4
	cone.rings = 1
	_arrow = MeshInstance3D.new()
	_arrow.mesh = cone
	_arrow.material_override = _mat
	_arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_arrow)
	visible = false


func _process(delta: float) -> void:
	var locked: Node3D = fighter.target if is_instance_valid(fighter.target) else null # studio: a targeted foe freed before the fighter's next step (despawn, region change)
	var e: Node3D = locked if locked else fighter.nearest_enemy(SEEN_RANGE)
	visible = e != null
	if e == null:
		return
	_t += delta
	global_position = e.global_position + Vector3(0, 0.06, 0)
	var pulse := 1.0 + 0.06 * sin(_t * 7.0)
	_ring.scale = Vector3.ONE * (pulse if locked else 1.0)
	_arrow.visible = locked != null
	_arrow.position.y = 2.0 + 0.12 * sin(_t * 4.0)
	_arrow.rotation.y = _t * 2.0
	_mat.albedo_color.a = 0.95 if locked else 0.35
