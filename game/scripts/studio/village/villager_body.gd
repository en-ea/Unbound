extends Node3D
## A villager's body for crowds: the same character as CharacterVisual (the "hero" model on the
## Quaternius rig, dressed and coloured by a CharacterLook), drawn as ONE skinned mesh instead of one
## MeshInstance3D per outfit part. A CharacterVisual costs about 40 draw calls (its ~20 visible parts,
## each drawn again for shadows); this body costs 1, plus 1 for its shadow when it casts one.
##
## How the parts become one mesh. In CharacterVisual every part is drawn with its colour slot's shared
## material, whose colour is  slot colour x per-face shade  (foliage_solid.gdshader: albedo x (UV.x, UV.y,
## UV2.x), the shade stored in the UVs by make_hero.py). Multiplying each part's slot colour into its UVs
## gives the same product with a white material, so every visible part can share one material and so
## one surface. The colour is baked as stored, not converted to linear: body_compare.gd measures the two
## side by side in the same pose and finds no difference beyond frame-to-frame noise (a linear bake came
## out visibly darker).
##
##   hero.glb parts ──visible for this look?──> part arrays ──UV x slot colour──> one surface
##                                                             (+ each part's LODs, merged)
##
## Sharing: merged meshes are cached by look (visible parts and colours) and shared by every body wearing
## it; the white material, the skin, the part arrays and the animation library are shared by all bodies.
## Each body owns only its rig (skeleton and AnimationPlayer) and one MeshInstance3D.
##
## Detail tiers (set_detail) spend animation and shadows only where the camera is looking closely:
##   0: full-rate animation, casts shadows;
##   1: animation stepped by hand at about 10 Hz, no shadows (skinning work drops ~6x at 60 fps);
##   2: hidden, animation and skeleton processing off.
##
## Same public interface as CharacterVisual for villagers (hero_look, is_player_look, wear_gear,
## apply_hero_look, play_motion, play_action, animation_length, hit_stop, flash, show_tool,
## head_attachment), plus play_loop, set_detail and hand_attachment. Not carried over: charge_tool
## (the player's sword only). Which parts show and how they are coloured mirrors
## CharacterVisual.apply_hero_look and _slot_material; keep the two in step.

const TIER1_STEP := 0.1         # seconds between animation steps at detail tier 1 (about 10 Hz)
const LOOP_LIBRARY := "loop"    # looping copies of one-shot animations, made on first play_loop

## CharacterVisual's defaults, except the look: a new body wears the default look rather than reading
## the player's saved look from disk (crowds make dozens of bodies, each given its own look anyway).
var hero_look := CharacterLook.new()
var is_player_look := true      # the player takes height/build from the look; NPCs set their own scale
var wear_gear := false          # show the player's worn armour over the look

var _metal_tint := Color(0, 0, 0, 0)
var _rig: Node3D
var _anim: AnimationPlayer
var _skeleton: Skeleton3D
var _body: MeshInstance3D
var _current := ""
var _action_left := 0.0         # seconds left of a one-shot action (swing, pick-up)
var _holding_loop := false      # a play_loop animation stays until the body moves or acts
var _detail := 0
var _step_left := 0.0           # tier 1: seconds until the next animation step
var _stepped := 0.0             # tier 1: seconds of animation not yet applied
var _lean: SkeletonModifier3D   # only while running, so walking and standing bodies carry no modifier
var _hand: BoneAttachment3D
var _tools := {}                # name -> Node3D in the hand (made on first show_tool)
var _flash := 0.0
var _flash_material: ShaderMaterial

## Shared by every body, built on first use.
static var _part_names: Array[String] = []   # hero.glb's parts, in the file's order
static var _parts := {}         # part name -> [{"arrays", "slot", "albedo", "lods": [[edge, indices]]}] per surface
static var _skin: Skin
static var _material: ShaderMaterial
static var _meshes := {}        # look key -> ArrayMesh
static var _library: AnimationLibrary
static var _loops: AnimationLibrary
static var _metals := {}        # tool metal: colour -> StandardMaterial3D (shared by tier colour)
static var _made := 0           # bodies made so far, to spread tier-1 steps over frames


func _ready() -> void:
	_rig = (load(CharacterVisual.RIG) as PackedScene).instantiate()
	add_child(_rig)
	_skeleton = _rig.find_children("*", "Skeleton3D", true, false)[0]
	_anim = _rig.find_children("*", "AnimationPlayer", true, false)[0]
	for mi in _skeleton.find_children("*", "MeshInstance3D", true, false):
		mi.free()   # the grey mannequin
	_load_parts()
	_body = MeshInstance3D.new()
	_body.name = "Body"
	_skeleton.add_child(_body)
	_body.skeleton = NodePath("..")
	_body.skin = _skin
	_use_shared_animations()
	apply_hero_look()
	play_motion(0.0)
	# Tier-1 bodies step on different frames (ten phases), so a crowd doesn't spike every 0.1 s.
	_step_left = (_made % 10) * TIER1_STEP / 10.0
	_made += 1
	_apply_detail()


func _process(delta: float) -> void:
	if _action_left > 0.0:
		_action_left -= delta
		if _action_left <= 0.0:
			_current = ""      # let play_motion pick idle/walk/run again
	if _detail == 1:
		_stepped += delta
		_step_left -= delta
		if _step_left <= 0.0:
			_anim.advance(_stepped)
			_stepped = 0.0
			_step_left = maxf(_step_left + TIER1_STEP, 0.0)
	_update_lean(delta)
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 5.0, 0.0)
		_flash_material.set_shader_parameter("flash", _flash)
		if _flash == 0.0:
			_body.material_override = null   # back to the shared material


## 0: full-rate animation and shadows; 1: animation at ~10 Hz, no shadows; 2: hidden and still.
func set_detail(tier: int) -> void:
	tier = clampi(tier, 0, 2)
	if tier == _detail and is_node_ready():
		return
	_detail = tier
	if is_node_ready():
		_apply_detail()


func _apply_detail() -> void:
	var hidden := _detail == 2
	visible = not hidden
	_rig.process_mode = Node.PROCESS_MODE_DISABLED if hidden else Node.PROCESS_MODE_INHERIT
	_anim.active = not hidden
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _detail == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _detail == 0:
		if _stepped > 0.0:
			_anim.advance(_stepped)    # catch up the time a stepped body hadn't shown yet
		_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	else:
		_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_stepped = 0.0


func play_motion(speed: float) -> void:
	if _action_left > 0.0:
		return
	if _holding_loop and speed <= 0.2:
		return          # standing still keeps a play_loop pose (arms folded, talking)
	_holding_loop = false
	var anim_name := CharacterVisual.IDLE
	if speed > 6.4:
		anim_name = CharacterVisual.SPRINT
	elif speed > 3.0:
		anim_name = CharacterVisual.RUN
	elif speed > 0.2:
		anim_name = CharacterVisual.WALK
	if anim_name != _current:
		_current = anim_name
		_anim.play(anim_name, 0.2)
	var native: Dictionary = CharacterVisual.NATIVE_SPEED
	_anim.speed_scale = clampf(speed / native[anim_name], 0.7, 1.8) if native.has(anim_name) else 1.0


## Plays one pass of an animation (a swing), optionally starting part-way through (for looping
## animations like TreeChopping, so a tap gives wind-up then strike). Idle/walk/run resume after.
func play_action(anim_name: String, speed := 1.0, start_at := 0.0) -> void:
	_holding_loop = false
	_action_left = _anim.get_animation(anim_name).length / speed
	_current = anim_name
	_anim.speed_scale = 1.0
	if _anim.current_animation == anim_name:
		_anim.stop()          # replaying the same animation would otherwise just continue it
	_anim.play(anim_name, 0.12, speed)
	if start_at > 0.0:
		_anim.seek(start_at, true)


## Loops any animation of the rig (UAL1 or UAL2, e.g. "Idle_FoldArms", "Idle_Talking") until the body
## moves (play_motion faster than a stroll), acts (play_action) or loops something else. Animations
## made as one-shots get a looping copy, made once and shared by every body.
func play_loop(anim_name: String, blend := 0.2) -> void:
	var looped := _looping_name(anim_name)
	_holding_loop = true
	_action_left = 0.0
	if looped == _current:
		return
	_current = looped
	_anim.speed_scale = 1.0
	_anim.play(looped, blend)


func animation_length(anim_name: String) -> float:
	return _anim.get_animation(anim_name).length


## A split-second freeze on impact, so hits feel solid.
func hit_stop(seconds := 0.07) -> void:
	_anim.pause()
	get_tree().create_timer(seconds).timeout.connect(func() -> void: _anim.play())


## A short white flash (taking a hit). The body switches to its own copy of the material while it
## flashes, so the shared material (and every other body) stays unlit.
func flash() -> void:
	if _flash_material == null:
		_flash_material = _material.duplicate() as ShaderMaterial
	_body.material_override = _flash_material
	_flash = 1.0


func show_tool(tool_name: String) -> void:
	if CharacterVisual.TOOLS.has(tool_name) and not _tools.has(tool_name):
		_make_tool(tool_name)
	for t: String in _tools:
		_tools[t].visible = t == tool_name
	if _tools.has(tool_name):              # the head shows the tool's tier (stone, copper, iron)
		var tint := Gear.color(tool_name)
		for mi: MeshInstance3D in (_tools[tool_name] as Node3D).find_children("*", "MeshInstance3D", true, false):
			for surf in mi.mesh.get_surface_count():
				var src := mi.mesh.surface_get_material(surf)
				if src and src.resource_name == "Metal":
					mi.set_surface_override_material(surf, _metal(src as StandardMaterial3D, tint))


## A spot on the head bone for small props (a cigarette). Made once.
func head_attachment() -> BoneAttachment3D:
	var found := _skeleton.get_node_or_null("HeadProps") as BoneAttachment3D
	if found:
		return found
	var head := BoneAttachment3D.new()
	head.name = "HeadProps"
	head.bone_name = "Head"
	_skeleton.add_child(head)
	return head


## The right hand (tools, things to throw or carry). Made on first use: an attachment follows its bone
## every skeleton update, which a crowd of empty-handed villagers shouldn't pay for.
func hand_attachment() -> BoneAttachment3D:
	if _hand == null:
		_hand = BoneAttachment3D.new()
		_hand.name = "HandProps"
		_hand.bone_name = "hand_r"
		_skeleton.add_child(_hand)
	return _hand


## Shows the look's parts in its colours: picks (or builds) the merged mesh for this look.
func apply_hero_look() -> void:
	if is_player_look:
		scale = Vector3(hero_look.build, hero_look.height, hero_look.build)
	if _body == null:
		return            # before _ready: the mesh is made there
	var names := _visible_parts(_worn_parts())
	var colors := {}      # slot -> colour, for the slots these parts use
	for n in names:
		for s: Dictionary in _parts[n]:
			colors[s["slot"]] = _slot_color(s["slot"], s["albedo"])
	var key := ",".join(names)
	var slots := colors.keys()
	slots.sort()
	for slot: String in slots:
		key += "|%s=%s" % [slot, (colors[slot] as Color).to_html(false)]
	if not _meshes.has(key):
		_meshes[key] = _build_mesh(names, colors)
	_body.mesh = _meshes[key]


## Which of hero.glb's parts this look shows (CharacterVisual.apply_hero_look's rules).
func _visible_parts(p: Dictionary) -> Array[String]:
	var covered: bool = p["head"] in CharacterVisual.COVERING
	var shown: Array[String] = []
	for n in _part_names:
		var on := false
		if n == "H_base_Main":          # the sleeves: a jerkin leaves the arms bare
			on = p["top"] != "jerkin"
		elif n.begins_with("H_base_"):
			on = true
		elif n.begins_with("H_ears"):   # round (plain H_ears), pointed or long; hidden under a hood or helm
			var ears := String(p.get("ears", "round"))
			on = not p["head"] in ["hood", "helm"] and n == ("H_ears" if ears == "round" else "H_ears_" + ears)
		elif n.begins_with("H_hair_"):  # the "_hat" cut under covering headwear, else the style (and "_top" locks)
			var style := "H_hair_" + String(p["hair"])
			on = n == style + "_hat" if covered else (n == style or n == style + "_top")
		else:
			var bits := n.split("_")    # H_<slot>_<choice>[_extra]
			on = bits.size() >= 3 and p.get(bits[1], "") == bits[2]
		if on:
			shown.append(n)
	return shown


## The look's parts, with worn armour on top when `wear_gear` is on (CharacterVisual._worn_parts).
func _worn_parts() -> Dictionary:
	var p := hero_look.parts.duplicate()
	_metal_tint = Color(0, 0, 0, 0)
	if not wear_gear:
		return p
	var chest := Armor.current("chest")
	var helm := Armor.current("helm")
	if not helm.is_empty() and Armor.show_helm:
		p["head"] = "helm"
	if not chest.is_empty():
		p["top"] = "armor"
	if not Armor.current("boots").is_empty():
		p["feet"] = "boots"
	var shown := chest if not chest.is_empty() else helm
	if not shown.is_empty():
		_metal_tint = Armor.TIERS[shown["tier"]]["color"]
	return p


## A slot's colour (CharacterVisual._slot_material): the look's palette pick, the armour tier's metal,
## or the model's own colour for fixed slots (Face, Shine, Gold, Wood...).
func _slot_color(slot: String, albedo: Color) -> Color:
	if CharacterLook.PALETTES.has(slot):
		return hero_look.color(slot)
	if slot == "Metal" and _metal_tint.a > 0.0:
		return _metal_tint
	return albedo


## Reads hero.glb's parts once: their vertex arrays, colour slot, own colour and LOD index lists.
static func _load_parts() -> void:
	if _skin != null:
		return
	var scene := (load(CharacterVisual.HERO) as PackedScene).instantiate()
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if _skin == null:
			_skin = mi.skin
		elif mi.skin != _skin:
			push_error("VillagerBody: %s has its own skin; merging assumes hero.glb shares one" % mi.name)
		var mesh := mi.mesh as ArrayMesh
		var surfaces := []
		for s in mesh.get_surface_count():
			var src := mesh.surface_get_material(s)
			var surface: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(), s)
			var arrays := mesh.surface_get_arrays(s)
			var index_count: int = surface.get("index_count", 0)
			var width := 2 if index_count > 0 and (surface["index_data"] as PackedByteArray).size() == index_count * 2 else 4
			var lods := []
			for lod: Dictionary in surface.get("lods", []):
				lods.append([float(lod["edge_length"]), _indices(lod["index_data"], width)])
			lods.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
			surfaces.append({"arrays": arrays, "slot": src.resource_name if src else "",
				"albedo": (src as StandardMaterial3D).albedo_color if src is StandardMaterial3D else Color.WHITE,
				"lods": lods})
		_part_names.append(String(mi.name))
		_parts[String(mi.name)] = surfaces
	scene.free()
	_material = ShaderMaterial.new()
	_material.shader = CharacterVisual.SOLID_SHADER
	_material.set_shader_parameter("sway", 0.0)
	_material.set_shader_parameter("albedo", Color.WHITE)   # the colours are in the UVs


## An index buffer from the renderer's bytes (16-bit for small meshes, 32-bit otherwise).
static func _indices(bytes: PackedByteArray, width: int) -> PackedInt32Array:
	if width == 4:
		return bytes.to_int32_array()
	var out := PackedInt32Array()
	out.resize(bytes.size() / 2)
	for i in out.size():
		out[i] = bytes.decode_u16(i * 2)
	return out


## One skinned surface from the given parts, each part's slot colour multiplied into its shade UVs.
## LODs: the merged surface gets a level at every edge length any part has a LOD at; at each level every
## part uses its own coarsest LOD at or under that length. The renderer picks the level from the error it
## allows, so each part ends up at the same LOD it would pick on its own.
static func _build_mesh(names: Array[String], colors: Dictionary) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var index := PackedInt32Array()
	var placed := []        # [first vertex, surface] for the LOD pass
	var edges := {}         # every LOD edge length among the parts
	for n in names:
		for s: Dictionary in _parts[n]:
			var a: Array = s["arrays"]
			var base := verts.size()
			var c: Color = colors[s["slot"]]
			var src_uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
			var src_uv2: PackedVector2Array = a[Mesh.ARRAY_TEX_UV2]
			for i in src_uv.size():
				uv.append(Vector2(src_uv[i].x * c.r, src_uv[i].y * c.g))
				uv2.append(Vector2(src_uv2[i].x * c.b, src_uv2[i].y))
			verts.append_array(a[Mesh.ARRAY_VERTEX])
			normals.append_array(a[Mesh.ARRAY_NORMAL])
			bones.append_array(a[Mesh.ARRAY_BONES])
			weights.append_array(a[Mesh.ARRAY_WEIGHTS])
			index.append_array(_shifted(a[Mesh.ARRAY_INDEX], base))
			placed.append([base, s])
			for lod: Array in s["lods"]:
				edges[lod[0]] = true
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals      # no tangents: the shader has no normal map
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = index
	var levels := edges.keys()
	levels.sort()
	var lods := {}
	for edge: float in levels:
		var level := PackedInt32Array()
		for p: Array in placed:
			var s: Dictionary = p[1]
			var chosen: PackedInt32Array = s["arrays"][Mesh.ARRAY_INDEX]
			for lod: Array in s["lods"]:
				if lod[0] <= edge:
					chosen = lod[1]
			level.append_array(_shifted(chosen, p[0]))
		lods[edge] = level
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], lods)
	mesh.surface_set_material(0, _material)
	return mesh


static func _shifted(indices: PackedInt32Array, by: int) -> PackedInt32Array:
	var out := indices.duplicate()
	if by != 0:
		for i in out.size():
			out[i] += by
	return out


## Every body plays from one shared animation library instead of each converting its own copy of UAL2.
func _use_shared_animations() -> void:
	if _library == null:
		_library = _build_library()
		_loops = AnimationLibrary.new()
	_anim.remove_animation_library("")
	_anim.add_animation_library("", _library)
	_anim.add_animation_library(LOOP_LIBRARY, _loops)


## The rig's own animations (idle, walk, jog and sprint looping) plus UAL2's, converted into this rig's
## bone frames exactly as CharacterVisual._add_extra_animations does (for UAL2 the frames match).
func _build_library() -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	var own := _anim.get_animation_library("")
	for anim_name in own.get_animation_list():
		var anim := own.get_animation(anim_name)
		if anim_name in [CharacterVisual.IDLE, CharacterVisual.WALK, CharacterVisual.RUN, CharacterVisual.SPRINT]:
			anim = anim.duplicate() as Animation     # leave the rig's own resource as it was
			anim.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation(anim_name, anim)
	var scene := (load(CharacterVisual.EXTRA_ANIMS) as PackedScene).instantiate()
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
		lib.add_animation(anim_name, anim)
	scene.free()
	return lib


## The name to loop an animation by: itself if it already loops, else a looping copy in LOOP_LIBRARY.
func _looping_name(anim_name: String) -> String:
	var anim := _library.get_animation(anim_name)
	if anim.loop_mode != Animation.LOOP_NONE:
		return anim_name
	if not _loops.has_animation(anim_name):
		var copy := anim.duplicate() as Animation
		copy.loop_mode = Animation.LOOP_LINEAR
		_loops.add_animation(anim_name, copy)
	return LOOP_LIBRARY + "/" + anim_name


## CharacterVisual straightens the torso while jogging or sprinting. Here the modifier exists only while
## it has work to do: a skeleton with any modifier re-poses every frame, which tier 1 is meant to avoid.
func _update_lean(delta: float) -> void:
	var target: float = CharacterVisual.LEAN_FIX.get(_current, 0.0)
	if _lean == null:
		if target == 0.0:
			return
		_lean = SkeletonModifier3D.new()
		_lean.set_script(preload("res://scripts/player/lean_fix.gd"))
		_skeleton.add_child(_lean)
	if _lean.amount != target:
		_lean.amount = move_toward(_lean.amount, target, delta * 60.0)
	if _lean.amount == 0.0 and target == 0.0:
		_lean.queue_free()
		_lean = null


func _make_tool(tool_name: String) -> void:
	var tool := (load(CharacterVisual.TOOLS[tool_name]) as PackedScene).instantiate() as Node3D
	tool.rotation_degrees = CharacterVisual.TOOL_GRIP[tool_name]
	tool.position = CharacterVisual.TOOL_OFFSET
	tool.visible = false
	hand_attachment().add_child(tool)
	_tools[tool_name] = tool


## A tool head's metal in a tier colour, one material per colour for all bodies.
static func _metal(src: StandardMaterial3D, tint: Color) -> StandardMaterial3D:
	var key := tint.to_html()
	if not _metals.has(key):
		var m := src.duplicate() as StandardMaterial3D
		m.albedo_color = tint
		_metals[key] = m
	return _metals[key]
