class_name CharacterVisual
extends Node3D
## A character on the Quaternius animation rig: our "hero" model (tools-src/blender/make_hero.py)
## dressed and coloured by a CharacterLook, with idle / walk / run, one-shot actions (swings,
## rolls, hits), tools in the right hand, and a hit flash.

const DIR := "res://assets/quaternius_characters/"
const RIG := DIR + "UAL1_Standard.glb"
## Universal Animation Library 2 (Quaternius, CC0): tree chopping, harvesting, sword and shield moves.
const EXTRA_ANIMS := DIR + "UAL2_Standard.glb"
const HERO := "res://assets/characters/hero.glb"
const SOLID_SHADER := preload("res://shaders/foliage_solid.gdshader")

const IDLE := "Idle"        # Godot drops the "_Loop" suffix on import
const WALK := "Walk"
const RUN := "Jog_Fwd"
## Ground speed (m/s) each animation was made for, so feet don't slide.
## The jog's real pace is 5.36 m/s, but its long strides looked like lunging, so it plays ~30%
## faster (quicker, shorter-looking steps).
const NATIVE_SPEED := {"Walk": 0.975, "Jog_Fwd": 4.2}

const TOOLS := {"axe": "res://assets/items/axe.glb", "pickaxe": "res://assets/items/pickaxe.glb",
	"sword": "res://assets/items/sword.glb"}
## How each tool sits in the right hand (tools are modelled with the handle along +Y from the
## grip). The UAL2 animations hold props along the hand bone's +Y (wrist to knuckles); these
## angles were worked out from the hand pose at the moment of impact (the blade leads the swing).
const TOOL_GRIP := {
	"axe": Vector3(8.0, 104.0, 6.0),
	"pickaxe": Vector3(8.0, 104.0, 6.0),
	"sword": Vector3(0.0, 90.0, 0.0),
}
const TOOL_OFFSET := Vector3(0.0, 0.07, 0.0)       # from the wrist into the palm

var hero_look := CharacterLook.load_saved()

var _anim: AnimationPlayer
var _skeleton: Skeleton3D
var _current := ""
var _action_left := 0.0      # seconds left of a one-shot action (swing, pick-up)
var _tools := {}             # name -> Node3D in the hand
var _tool_metal := {}        # name -> the material of its head, tinted by tier
var _parts: Array[MeshInstance3D] = []
var _slot_materials := {}    # colour slot -> ShaderMaterial shared by the hero's meshes
var _flash := 0.0


func _ready() -> void:
	var rig := (load(RIG) as PackedScene).instantiate()
	add_child(rig)
	_skeleton = rig.find_children("*", "Skeleton3D", true, false)[0]
	_anim = rig.find_children("*", "AnimationPlayer", true, false)[0]
	for mi in _skeleton.find_children("*", "MeshInstance3D", true, false):
		mi.free()   # the grey mannequin
	_attach_hero()
	apply_hero_look()
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
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 5.0, 0.0)
		for m: ShaderMaterial in _slot_materials.values():
			m.set_shader_parameter("flash", _flash)


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


## Plays one pass of an animation (a swing), optionally starting part-way through (for looping
## animations like TreeChopping, so a tap gives wind-up then strike). Idle/walk/run resume after.
func play_action(anim_name: String, speed := 1.0, start_at := 0.0) -> void:
	_action_left = _anim.get_animation(anim_name).length / speed
	_current = anim_name
	_anim.speed_scale = 1.0
	if _anim.current_animation == anim_name:
		_anim.stop()          # replaying the same animation would otherwise just continue it
	_anim.play(anim_name, 0.12, speed)
	if start_at > 0.0:
		_anim.seek(start_at, true)


func animation_length(anim_name: String) -> float:
	return _anim.get_animation(anim_name).length


## A split-second freeze on impact, so hits feel solid.
func hit_stop(seconds := 0.07) -> void:
	_anim.pause()
	get_tree().create_timer(seconds).timeout.connect(func() -> void: _anim.play())


## A short white flash (taking a hit).
func flash() -> void:
	_flash = 1.0


func show_tool(tool_name: String) -> void:
	for t: String in _tools:
		_tools[t].visible = t == tool_name
	if _tool_metal.has(tool_name):              # the head shows the tool's tier (stone, copper, iron)
		(_tool_metal[tool_name] as StandardMaterial3D).albedo_color = Gear.color(tool_name)


## Shows the hero's chosen parts and applies its colours.
func apply_hero_look() -> void:
	var p := hero_look.parts
	var covered: bool = p["head"] in ["hat", "bandana"]
	for mi in _parts:
		var n := String(mi.name)
		if n.begins_with("H_base_"):
			mi.visible = true
		elif n == "H_ears":
			mi.visible = true
		elif n.begins_with("H_hair_"):
			# Spiky "_top" locks hide under a hat or bandana.
			mi.visible = n.begins_with("H_hair_" + p["hair"]) and not (n.ends_with("_top") and covered)
		else:
			var bits := n.split("_")   # H_<slot>_<choice>[_extra]
			mi.visible = bits.size() >= 3 and p.get(bits[1], "") == bits[2]
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			if src:
				mi.set_surface_override_material(s, _slot_material(src))


## One shared material per colour slot, using the world's faceted shader: the slot's colour times
## each face's small shade variation (stored in the model's UVs). Hit flashes use it too.
func _slot_material(src: Material) -> ShaderMaterial:
	var slot := src.resource_name
	if not _slot_materials.has(slot):
		var m := ShaderMaterial.new()
		m.shader = SOLID_SHADER
		m.set_shader_parameter("sway", 0.0)
		_slot_materials[slot] = m
	var mat: ShaderMaterial = _slot_materials[slot]
	if CharacterLook.PALETTES.has(slot):
		mat.set_shader_parameter("albedo", hero_look.color(slot))
	elif src is StandardMaterial3D:
		mat.set_shader_parameter("albedo", (src as StandardMaterial3D).albedo_color)
	return mat


func _attach_hero() -> void:
	var scene := (load(HERO) as PackedScene).instantiate()
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		mi.owner = null
		mi.get_parent().remove_child(mi)
		_skeleton.add_child(mi)
		mi.skeleton = NodePath("..")
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_parts.append(mi)
	scene.free()


func _make_tools() -> void:
	var hand := BoneAttachment3D.new()
	hand.bone_name = "hand_r"
	_skeleton.add_child(hand)
	for t: String in TOOLS:
		var tool := (load(TOOLS[t]) as PackedScene).instantiate() as Node3D
		tool.rotation_degrees = TOOL_GRIP[t]
		tool.position = TOOL_OFFSET
		tool.visible = false
		hand.add_child(tool)
		_tools[t] = tool
		for mi: MeshInstance3D in tool.find_children("*", "MeshInstance3D", true, false):
			for surf in mi.mesh.get_surface_count():
				var src := mi.mesh.surface_get_material(surf)
				if src and src.resource_name == "Metal":
					var metal := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
					mi.set_surface_override_material(surf, metal)
					_tool_metal[t] = metal


## Adds the extra animation library. If its skeleton's bone frames differ from this rig's (e.g.
## anything round-tripped through Blender), rotations are converted into this rig's frames:
## local_ours = C_parent^-1 * local_theirs * C_bone, where C = their_rest^-1 * our_rest (global).
## For UAL2 the frames match, so C is identity.
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
