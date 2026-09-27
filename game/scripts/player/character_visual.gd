class_name CharacterVisual
extends Node3D
## Assembles the villager (peasant outfit + head + hair) on the Quaternius animation rig
## and plays idle / walk / run.

const DIR := "res://assets/quaternius_characters/"
const RIG := DIR + "UAL1_Standard.glb"
const OUTFIT := DIR + "Male_Peasant.gltf"
const BASE_BODY := DIR + "Superhero_Male_FullBody.gltf"
const HAIR := DIR + "Hair_SimpleParted.gltf"
const HAIR_COLOR := Color(0.36, 0.22, 0.13)   # the hair textures are grey, made for tinting
const NECK_Y := 1.47          # keep only the base body's head (the outfit covers the rest)

const IDLE := "Idle"        # Godot drops the "_Loop" suffix on import
const WALK := "Walk"
const RUN := "Jog_Fwd"
## Ground speed (m/s) each animation was made for, so feet don't slide.
const NATIVE_SPEED := {"Walk": 0.975, "Jog_Fwd": 5.36}

var _anim: AnimationPlayer
var _skeleton: Skeleton3D
var _current := ""


func _ready() -> void:
	var rig := (load(RIG) as PackedScene).instantiate()
	add_child(rig)
	_skeleton = rig.find_children("*", "Skeleton3D", true, false)[0]
	_anim = rig.find_children("*", "AnimationPlayer", true, false)[0]
	for mi in _skeleton.find_children("*", "MeshInstance3D", true, false):
		mi.free()   # the grey mannequin
	_attach_meshes(OUTFIT, false)
	_attach_meshes(BASE_BODY, true)
	_attach_hair()
	for anim_name in [IDLE, WALK, RUN]:
		_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	play_motion(0.0)


func play_motion(speed: float) -> void:
	var anim_name := IDLE
	if speed > 3.0:
		anim_name = RUN
	elif speed > 0.2:
		anim_name = WALK
	if anim_name != _current:
		_current = anim_name
		_anim.play(anim_name, 0.2)
	_anim.speed_scale = clampf(speed / NATIVE_SPEED[anim_name], 0.7, 1.8) if NATIVE_SPEED.has(anim_name) else 1.0


func _attach_meshes(path: String, head_only: bool) -> void:
	var scene := (load(path) as PackedScene).instantiate()
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		mi.owner = null
		mi.get_parent().remove_child(mi)
		if head_only:
			mi.mesh = _above_neck(mi.mesh)
		_skeleton.add_child(mi)
		mi.skeleton = NodePath("..")
		_tint_hair(mi)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	scene.free()


func _attach_hair() -> void:
	var head := _skeleton.find_bone("Head")
	var attach := BoneAttachment3D.new()
	attach.bone_name = "Head"
	_skeleton.add_child(attach)
	var hair := (load(HAIR) as PackedScene).instantiate() as Node3D
	attach.add_child(hair)
	# The hair was modelled in place on the rest pose, so undo the head's rest transform.
	hair.transform = _skeleton.get_bone_global_rest(head).affine_inverse()
	for mi: MeshInstance3D in hair.find_children("*", "MeshInstance3D", true, false):
		_tint_hair(mi)


## Hair and eyebrow materials are grey; colour them.
func _tint_hair(mi: MeshInstance3D) -> void:
	for s in mi.mesh.get_surface_count():
		var mat := mi.mesh.surface_get_material(s) as StandardMaterial3D
		if mat and mat.resource_name.begins_with("MI_Hair"):
			var tinted := mat.duplicate() as StandardMaterial3D
			tinted.albedo_color = HAIR_COLOR
			mi.set_surface_override_material(s, tinted)


## Copies a skinned mesh, keeping only triangles above the neck (the head).
func _above_neck(src: Mesh) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var keep := PackedInt32Array()
		for i in range(0, idx.size(), 3):
			var a := verts[idx[i]]
			var b := verts[idx[i + 1]]
			var c := verts[idx[i + 2]]
			if minf(a.y, minf(b.y, c.y)) > NECK_Y and maxf(absf(a.x), maxf(absf(b.x), absf(c.x))) < 0.25:
				keep.append_array([idx[i], idx[i + 1], idx[i + 2]])
		if keep.is_empty():
			continue
		arrays[Mesh.ARRAY_INDEX] = keep
		for custom in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
			arrays[custom] = null
		var flags: int = src.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		out.surface_set_material(out.get_surface_count() - 1, src.surface_get_material(s))
	return out
