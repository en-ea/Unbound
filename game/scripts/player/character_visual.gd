class_name CharacterVisual
extends Node3D
## Puts a character look on the Quaternius animation rig and plays idle / walk / run.
## Looks: "hero" (our main style, tools-src/blender/make_hero.py, recoloured and dressed by a
## CharacterLook), "wanderer" (first prototype) or "villager" (Quaternius peasant outfit).

const DIR := "res://assets/quaternius_characters/"
const RIG := DIR + "UAL1_Standard.glb"
const OUTFIT := DIR + "Male_Peasant.gltf"
const BASE_BODY := DIR + "Superhero_Male_FullBody.gltf"
const HAIR := DIR + "Hair_SimpleParted.gltf"
const WANDERER := "res://assets/characters/wanderer.glb"
const HERO := "res://assets/characters/hero.glb"
## Our own gathering animations (Chop, Mine, Gather), made by tools-src/blender/make_anims.py.
const EXTRA_ANIMS := "res://assets/characters/gather_anims.glb"
const LOOKS := ["hero", "wanderer", "villager"]
const HAIR_COLOR := Color(0.36, 0.22, 0.13)   # the hair textures are grey, made for tinting
const NECK_Y := 1.47          # keep only the base body's head (the outfit covers the rest)

const IDLE := "Idle"        # Godot drops the "_Loop" suffix on import
const WALK := "Walk"
const RUN := "Jog_Fwd"
## Ground speed (m/s) each animation was made for, so feet don't slide.
## The jog's real pace is 5.36 m/s, but its long strides looked like lunging, so it plays ~30%
## faster (quicker, shorter-looking steps).
const NATIVE_SPEED := {"Walk": 0.975, "Jog_Fwd": 4.2}

const TOOLS := {"axe": "res://assets/items/axe.glb", "pickaxe": "res://assets/items/pickaxe.glb"}
## How a tool sits in the right hand (its handle runs along its own +Y).
const TOOL_ROTATION := Vector3(0.0, 0.0, 90.0)     # degrees
const TOOL_OFFSET := Vector3(0.0, 0.0, 0.0)

var _anim: AnimationPlayer
var _action_left := 0.0      # seconds left of a one-shot action (swing, pick-up)
var _tools := {}             # name -> Node3D in the hand
var _skeleton: Skeleton3D
var _current := ""
var _parts: Array[Node] = []   # everything the current look added to the skeleton
var look := ""
var hero_look := CharacterLook.load_saved()
var _slot_materials := {}      # colour slot -> StandardMaterial3D shared by the hero's meshes


func _ready() -> void:
	var rig := (load(RIG) as PackedScene).instantiate()
	add_child(rig)
	_skeleton = rig.find_children("*", "Skeleton3D", true, false)[0]
	_anim = rig.find_children("*", "AnimationPlayer", true, false)[0]
	for mi in _skeleton.find_children("*", "MeshInstance3D", true, false):
		mi.free()   # the grey mannequin
	set_look(LOOKS[0])
	for anim_name in [IDLE, WALK, RUN]:
		_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_add_extra_animations()
	_make_tools()
	play_motion(0.0)


func _process(delta: float) -> void:
	if _action_left > 0.0:
		_action_left -= delta
		if _action_left <= 0.0:
			_current = ""      # let play_motion pick idle/walk/run again


## Plays a one-shot animation (a swing); idle/walk/run resume when it ends.
func play_action(anim_name: String, speed := 1.0) -> void:
	_action_left = _anim.get_animation(anim_name).length / speed
	_current = anim_name
	_anim.speed_scale = 1.0
	if _anim.current_animation == anim_name:
		_anim.stop()          # replaying the same animation would otherwise just continue it
	_anim.play(anim_name, 0.12, speed)


## A split-second freeze on impact, so hits feel solid.
func hit_stop(seconds := 0.07) -> void:
	_anim.pause()
	get_tree().create_timer(seconds).timeout.connect(func() -> void: _anim.play())


## Adds our own animations. Blender re-orients each bone's local axes on the way through, so
## the rotations are converted from that skeleton's bone frames into this rig's frames:
## local_ours = C_parent^-1 * local_theirs * C_bone, where C = their_rest^-1 * our_rest (global).
func _add_extra_animations() -> void:
	var scene := (load(EXTRA_ANIMS) as PackedScene).instantiate()
	var source := scene.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var src_skel := scene.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var frames := {}      # bone name -> C (Quaternion)
	for i in _skeleton.get_bone_count():
		var bone := _skeleton.get_bone_name(i)
		var j := src_skel.find_bone(bone)
		if j >= 0:
			var theirs := src_skel.get_bone_global_rest(j).basis.get_rotation_quaternion()
			var ours := _skeleton.get_bone_global_rest(i).basis.get_rotation_quaternion()
			frames[bone] = theirs.inverse() * ours
	var library := _anim.get_animation_library("")
	for anim_name in source.get_animation_list():
		if anim_name == "RESET":
			continue
		var anim := source.get_animation(anim_name).duplicate(true) as Animation
		anim.loop_mode = Animation.LOOP_NONE
		for t in anim.get_track_count():
			var bone := String(anim.track_get_path(t).get_concatenated_subnames())
			if not frames.has(bone):
				continue
			var parent_idx := _skeleton.get_bone_parent(_skeleton.find_bone(bone))
			var c_parent: Quaternion = frames.get(_skeleton.get_bone_name(parent_idx), Quaternion.IDENTITY) if parent_idx >= 0 else Quaternion.IDENTITY
			var c_bone: Quaternion = frames[bone]
			match anim.track_get_type(t):
				Animation.TYPE_ROTATION_3D:
					for k in anim.track_get_key_count(t):
						var q: Quaternion = anim.track_get_key_value(t, k)
						anim.track_set_key_value(t, k, c_parent.inverse() * q * c_bone)
				Animation.TYPE_POSITION_3D:
					for k in anim.track_get_key_count(t):
						var v: Vector3 = anim.track_get_key_value(t, k)
						anim.track_set_key_value(t, k, c_parent.inverse() * v)
		library.add_animation(anim_name, anim)
	scene.free()


func show_tool(tool_name: String) -> void:
	for t: String in _tools:
		_tools[t].visible = t == tool_name


func _make_tools() -> void:
	var hand := BoneAttachment3D.new()
	hand.bone_name = "hand_r"
	_skeleton.add_child(hand)
	for t: String in TOOLS:
		var tool := (load(TOOLS[t]) as PackedScene).instantiate() as Node3D
		tool.rotation_degrees = TOOL_ROTATION
		tool.position = TOOL_OFFSET
		tool.visible = false
		hand.add_child(tool)
		_tools[t] = tool


func set_look(new_look: String) -> void:
	for part in _parts:
		part.queue_free()
	_parts.clear()
	look = new_look
	if look == "hero":
		_attach_meshes(HERO, false)
		apply_hero_look()
	elif look == "wanderer":
		_attach_meshes(WANDERER, false)
	else:
		_attach_meshes(OUTFIT, false)
		_attach_meshes(BASE_BODY, true)
		_attach_hair()


## Shows the hero's chosen parts and applies its colours.
func apply_hero_look() -> void:
	if look != "hero":
		return
	var p := hero_look.parts
	var hooded: bool = p["head"] == "hood"
	for node in _parts:
		var mi := node as MeshInstance3D
		if mi == null:
			continue
		var n := String(mi.name)
		if n.begins_with("H_base_"):
			mi.visible = true
		elif n == "H_ears":
			mi.visible = not hooded
		elif n.begins_with("H_hair_"):
			mi.visible = not hooded and n == "H_hair_" + p["hair"]
		else:
			var bits := n.split("_")   # H_<slot>_<choice>
			mi.visible = bits.size() >= 3 and p.get(bits[1], "") == bits[2]
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			if src and CharacterLook.PALETTES.has(src.resource_name):
				mi.set_surface_override_material(s, _slot_material(src.resource_name))


func _slot_material(slot: String) -> StandardMaterial3D:
	if not _slot_materials.has(slot):
		var m := StandardMaterial3D.new()
		m.roughness = 0.9
		_slot_materials[slot] = m
	var mat: StandardMaterial3D = _slot_materials[slot]
	mat.albedo_color = hero_look.color(slot)
	return mat


func next_look() -> void:
	set_look(LOOKS[(LOOKS.find(look) + 1) % LOOKS.size()])


func play_motion(speed: float) -> void:
	if _action_left > 0.0:
		return
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
		_parts.append(mi)
		mi.skeleton = NodePath("..")
		_tint_hair(mi)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	scene.free()


func _attach_hair() -> void:
	var head := _skeleton.find_bone("Head")
	var attach := BoneAttachment3D.new()
	attach.bone_name = "Head"
	_skeleton.add_child(attach)
	_parts.append(attach)
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
