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
const SPRINT := "Sprint"
## Ground speed (m/s) each animation was made for, so feet don't slide.
## The jog's real pace is 5.36 m/s, but its long strides looked like lunging, so it plays ~30%
## faster (quicker, shorter-looking steps).
const NATIVE_SPEED := {"Walk": 0.975, "Jog_Fwd": 4.2, "Sprint": 6.6, "Crouch_Fwd": 1.3, "Push": 0.7}

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
## Styled swords (make_swords.py, from the owner's pictures): Epic swords look like the Runeblade,
## Legendary and up like the Frost blade. Parts named Rune or Crystal glow.
const SWORD_STYLES := {"runeblade": "res://assets/items/sword_runeblade.glb", "frost": "res://assets/items/sword_frost.glb"}
const SWORD_GLOW := {"Rune": Color(1.0, 0.62, 0.2), "Crystal": Color(0.45, 0.9, 1.0)}
static var lab_sword_style := ""     # the Build lab's preview: "plain", "runeblade" or "frost" ("" = your real sword)
## Headwear that covers the top of the head: hair switches to its cut-down "_hat" version.
const COVERING := ["hat", "bandana", "hood", "helm", "cap", "straw", "sunhat", "wayfarer"]

var hero_look := CharacterLook.load_saved()
var body_model := ""            # a different body on the same rig (Brakk the golem), instead of the hero
var is_player_look := true      # the player takes height/build from the look; NPCs set their own scale
var idle_anim := ""             # instead of the plain idle (sneaking: Crouch_Idle; a guard: Idle_FoldArms)
var walk_anim := ""             # instead of the walk (sneaking: Crouch_Fwd)
var walk_backward := false      # play the walk in reverse (dragging a body: Push, stepping backwards)
var wear_gear := false          # show the player's worn armour over the look (off in the look picker)
var back_sword := false         # the player: your sword rides on your back while it isn't in your hand
var hand_sword := false         # the player's "Sword: always in hand" setting
var hands_busy := false         # fishing, riding, dragging, talking...: no sword in hand, whatever the setting
var claws := false              # the Delver: claws on both hands instead of a sword (set_claws)
var tool_shown := ""
var _sword_style := ""
## Where the sheathed sword sits, in the model's own space (it faces +Z): grip up by the right shoulder,
## blade slanting down across the back.
const BACK_SWORD_TILT := PI + 0.5          # blade down, slanting across the back (turned flat to it first)
const BACK_SWORD_AT := Vector3(-0.2, 1.58, -0.25)  # behind you (-Z), far enough off the back to clear coats and cloaks
const BACK_SWORD_LEAN := 0.16              # the tip angled out from the body, so it doesn't sink into flared clothes
var _back: Node3D
var _metal_tint := Color(0, 0, 0, 0)

var _anim: AnimationPlayer
var _skeleton: Skeleton3D
var _current := ""
var _action_left := 0.0      # seconds left of a one-shot action (swing, pick-up)
var _tools := {}             # name -> Node3D in the hand
var _tool_metal := {}        # name -> the material of its head, tinted by tier
var _parts: Array[MeshInstance3D] = []
var _slot_materials := {}    # colour slot -> ShaderMaterial shared by the hero's meshes
var _flash := 0.0
var _lean: SkeletonModifier3D          # straightens the torso while running (lean_fix.gd)
var _hold: SkeletonModifier3D          # two-handed prop hold (two_hand_hold.gd), NPCs only
var _hold_hand_prop: Node3D
var _hold_on := false
var _lean_target := 0.0
## Degrees the torso is straightened for each motion (the jog leans ~27°, the sprint ~40°).
const CLAW_BACK := 0.035      # claws sit this far over the back of the hand (hand bone +Z)
const CLAW_CURL := -0.25      # and lean this much (radians) towards the palm
const LEAN_FIX := {"Jog_Fwd": 20.0, "Sprint": 32.0}   # leaves the jog at ~16° and the sprint at ~21°


func _ready() -> void:
	var rig := (load(RIG) as PackedScene).instantiate()
	add_child(rig)
	_skeleton = rig.find_children("*", "Skeleton3D", true, false)[0]
	_anim = rig.find_children("*", "AnimationPlayer", true, false)[0]
	for mi in _skeleton.find_children("*", "MeshInstance3D", true, false):
		mi.free()   # the grey mannequin
	_attach_hero()
	apply_hero_look()
	for anim_name in [IDLE, WALK, RUN, SPRINT]:
		_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_add_extra_animations()
	_make_tools()
	Gear.changed.connect(func() -> void:
		if wear_gear:
			_apply_sword_style())
	_lean = SkeletonModifier3D.new()
	_lean.set_script(preload("res://scripts/player/lean_fix.gd"))
	_skeleton.add_child(_lean)
	play_motion(0.0)


func _process(delta: float) -> void:
	if _hold:
		_hold.weight = move_toward(_hold.weight, 1.0 if _hold_on else 0.0, delta * 4.0)
	if _action_left > 0.0:
		_action_left -= delta
		if _action_left <= 0.0:
			_current = ""      # let play_motion pick idle/walk/run again
	var target: float = LEAN_FIX.get(_current, 0.0)
	if _lean.amount != target:
		_lean.amount = move_toward(_lean.amount, target, delta * 60.0)
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 5.0, 0.0)
		for m: ShaderMaterial in _slot_materials.values():
			m.set_shader_parameter("flash", _flash)


## Moves both shoulders (and so the whole arms) outward, for a body wider than the rig (Brakk the golem).
func widen_shoulders(amount: float) -> void:
	for side in ["l", "r"]:
		var i := _skeleton.find_bone("clavicle_" + side)
		if i < 0:
			continue
		var out := Vector3(amount if side == "l" else -amount, 0, 0)
		var parent_global := _skeleton.get_bone_global_rest(_skeleton.get_bone_parent(i))
		_skeleton.set_bone_pose_position(i, _skeleton.get_bone_rest(i).origin + parent_global.basis.inverse() * out)


## Talking (a portrait): the gesturing idle while `on`, the plain idle otherwise.
func talk(on: bool) -> void:
	var anim_name := "Idle_Talking" if on else IDLE
	if not _anim.has_animation(anim_name):
		return
	_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_current = anim_name
	_anim.play(anim_name, 0.25)


## Ends a one-shot action now (an NPC stopping its work to talk).
func stop_action() -> void:
	_action_left = 0.0
	_current = ""


func play_motion(speed: float) -> void:
	if _action_left > 0.0:
		return
	var anim_name := idle_anim if idle_anim != "" else IDLE
	if speed > 6.4:
		anim_name = SPRINT
	elif speed > 3.0:
		anim_name = RUN
	elif speed > 0.2:
		anim_name = walk_anim if walk_anim != "" else WALK
	if anim_name != _current:
		_current = anim_name
		_anim.play(anim_name, 0.2)
	_anim.speed_scale = clampf(speed / NATIVE_SPEED[anim_name], 0.7, 1.8) if NATIVE_SPEED.has(anim_name) else 1.0
	if walk_backward and anim_name == walk_anim:
		_anim.speed_scale = -_anim.speed_scale


## Footfalls a second of the walk or run playing now (two per loop), so footsteps match the feet;
## 0 when standing still or mid-action.
func step_rate() -> float:
	if _action_left > 0.0 or not NATIVE_SPEED.has(_current):
		return 0.0
	return 2.0 * absf(_anim.speed_scale) / _anim.get_animation(_current).length


## Where the feet are within a step (0 to 1, two steps per loop).
func step_phase() -> float:
	if not NATIVE_SPEED.has(_current):
		return 0.0
	return fmod(_anim.current_animation_position * 2.0 / _anim.get_animation(_current).length, 1.0)


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


static var _shadow_overlay: ShaderMaterial


## Made of shadow for a moment (the Shade's roll and Shadow Dance): a dark violet layer over everything.
func set_shadow(on: bool) -> void:
	if on and _shadow_overlay == null:
		_shadow_overlay = ShaderMaterial.new()
		_shadow_overlay.shader = preload("res://shaders/shadow_double.gdshader")
	for mi in find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = _shadow_overlay if on else null


## A short white flash (taking a hit).
func flash() -> void:
	_flash = 1.0


## The sword heats up while a heavy blow winds up (0..1), and goes back to steel at 0.
func charge_tool(amount: float) -> void:
	var metal: StandardMaterial3D = _tool_metal.get("sword")
	if metal == null:
		return
	metal.emission_enabled = amount > 0.0
	metal.emission = Color(1.0, 0.72, 0.4)
	metal.emission_energy_multiplier = amount * 2.2


## Which sword look goes with a rarity (the Build lab can override it, for looking only).
static func sword_style_for(rarity: int) -> String:
	if lab_sword_style != "":
		return "" if lab_sword_style == "plain" else lab_sword_style
	return "frost" if rarity >= Loot.LEGENDARY else ("runeblade" if rarity >= Loot.EPIC else "")


## Swaps the sword models (hand and back) when your sword's look changes.
func _apply_sword_style() -> void:
	if not wear_gear or not _tools.has("sword"):
		return
	var style := sword_style_for(int(Gear.current("sword").get("rarity", 0)))
	if style == _sword_style:
		return
	_sword_style = style
	var path: String = SWORD_STYLES.get(style, TOOLS["sword"])
	var old: Node3D = _tools["sword"]
	var fresh := (load(path) as PackedScene).instantiate() as Node3D
	fresh.rotation_degrees = TOOL_GRIP["sword"]
	fresh.position = TOOL_OFFSET
	fresh.visible = old.visible
	old.get_parent().add_child(fresh)
	old.queue_free()
	_tools["sword"] = fresh
	_dress_sword(fresh)
	if _back:
		var back := (load(path) as PackedScene).instantiate() as Node3D
		back.transform = _back.transform
		back.visible = _back.visible
		_back.get_parent().add_child(back)
		_back.queue_free()
		_back = back
		_dress_sword(back)


## The plain sword's metal shows its tier; a styled sword's runes or crystal glow.
func _dress_sword(sword: Node3D) -> void:
	for mi: MeshInstance3D in sword.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if sword == _back else mi.cast_shadow
		for surf in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(surf)
			if src == null:
				continue
			if src.resource_name == "Metal" and _tool_metal.has("sword"):
				mi.set_surface_override_material(surf, _tool_metal["sword"])
			elif SWORD_GLOW.has(src.resource_name):
				var m := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
				m.emission_enabled = true
				m.emission = SWORD_GLOW[src.resource_name]
				m.emission_energy_multiplier = 1.4
				mi.set_surface_override_material(surf, m)


func show_tool(tool_name: String) -> void:
	_apply_sword_style()
	var has_sword := back_sword and Gear.tier("sword") >= 0 and not claws
	if claws and tool_name == "sword":
		tool_name = ""
	if tool_name == "" and hand_sword and has_sword and not hands_busy:
		tool_name = "sword"
	tool_shown = tool_name
	if _back:
		_back.visible = has_sword and tool_name != "sword"
	for t: String in _tools:
		_tools[t].visible = t == tool_name
	if _tool_metal.has(tool_name):              # the head shows the tool's tier (stone, copper, iron)
		(_tool_metal[tool_name] as StandardMaterial3D).albedo_color = Gear.color(tool_name)


## The Delver's claws: three curved iron blades over the back of each hand, on a cuff with an ore stone.
func set_claws(on: bool) -> void:
	claws = on
	for side: String in ["l", "r"]:
		var hand := _skeleton.get_node_or_null("Claw_" + side) as BoneAttachment3D
		if hand == null and on:
			hand = BoneAttachment3D.new()
			hand.name = "Claw_" + side
			hand.bone_name = "hand_" + side
			_skeleton.add_child(hand)
			hand.add_child(_make_claw())
		if hand:
			hand.visible = on
	show_tool(tool_shown)


func _make_claw() -> Node3D:
	var root := Node3D.new()
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.42, 0.44, 0.47)
	iron.metallic = 0.5
	iron.roughness = 0.35
	var leather := StandardMaterial3D.new()
	leather.albedo_color = Color(0.28, 0.19, 0.13)
	var cuff := MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = 0.05
	ring.bottom_radius = 0.055
	ring.height = 0.07
	ring.radial_segments = 6
	ring.rings = 1
	cuff.mesh = ring
	cuff.material_override = leather
	cuff.position = Vector3(0, 0.0, 0)
	root.add_child(cuff)
	var gem := MeshInstance3D.new()
	var stone := BoxMesh.new()
	stone.size = Vector3(0.035, 0.035, 0.035)
	gem.mesh = stone
	gem.material_override = EarthFX.ore_material()
	gem.position = Vector3(0, 0.0, CLAW_BACK + 0.02)
	gem.rotation = Vector3(0.6, 0.6, 0)
	root.add_child(gem)
	for i in 3:
		var blade := MeshInstance3D.new()
		var spike := CylinderMesh.new()
		spike.top_radius = 0.0
		spike.bottom_radius = 0.032
		spike.height = 0.3
		spike.radial_segments = 3
		spike.rings = 1
		blade.mesh = spike
		blade.material_override = iron
		blade.scale = Vector3(1.0, 1.0, 0.45)
		blade.position = Vector3((i - 1) * 0.036, 0.18, CLAW_BACK)
		blade.rotation = Vector3(CLAW_CURL, 0, (i - 1) * -0.08)
		root.add_child(blade)
	return root


## Makes an animation loop (stances used as idles: Sword_Idle).
func loop_animation(anim_name: String) -> void:
	if _anim.has_animation(anim_name):
		_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR


## The red-hot warning glow before an attack (0..1), like the creatures' wind-up.
func set_warn(amount: float) -> void:
	for m: ShaderMaterial in _slot_materials.values():
		m.set_shader_parameter("warn", amount)


## Colours a shown tool's metal (bandits' plain iron swords) instead of the player's tier colour.
func tint_tool(tool_name: String, color: Color) -> void:
	if _tool_metal.has(tool_name):
		(_tool_metal[tool_name] as StandardMaterial3D).albedo_color = color


## Shows the hero's chosen parts and applies its colours.
func apply_hero_look() -> void:
	if is_player_look:
		scale = Vector3(hero_look.build, hero_look.height, hero_look.build)
	if body_model != "":                    # a ready-made body: every part shows, only the materials need setting
		for mi in _parts:
			mi.visible = true
			for s in mi.mesh.get_surface_count():
				var src := mi.mesh.surface_get_material(s)
				if src:
					mi.set_surface_override_material(s, _slot_material(src))
		return
	var p := _worn_parts()
	var covered: bool = p["head"] in COVERING
	for mi in _parts:
		var n := String(mi.name)
		if n == "H_base_Main":          # the sleeves: a jerkin leaves the arms bare
			mi.visible = p["top"] != "jerkin"
		elif n.begins_with("H_base_"):
			mi.visible = true
		elif n.begins_with("H_ears"):          # round (plain H_ears), pointed or long; hidden under a hood or helm
			var ears := String(p.get("ears", "round"))
			mi.visible = not p["head"] in ["hood", "helm"] and n == ("H_ears" if ears == "round" else "H_ears_" + ears)
		elif n.begins_with("H_hair_"):
			# Under a hat or bandana the "_hat" cut of the style shows (nothing pokes through);
			# otherwise the full style (with the messy style's spiky "_top" locks).
			var style := "H_hair_" + String(p["hair"])
			if covered:
				mi.visible = n == style + "_hat"
			else:
				mi.visible = n == style or n == style + "_top"
		else:
			var bits := n.split("_")   # H_<slot>_<choice>[_extra]
			mi.visible = bits.size() >= 3 and p.get(bits[1], "") == bits[2]
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			if src:
				mi.set_surface_override_material(s, _slot_material(src))


## The look's parts, with worn armour on top when `wear_gear` is on: a helm (unless hidden), the
## chestplate as the armour top, boots. Metal takes the colour of the armour's tier.
## (Placeholder looks until each armour set gets its own model.)
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


## One shared material per colour slot, using the world's faceted shader: the slot's colour times
## each face's small shade variation (stored in the model's UVs). Hit flashes use it too.
func _slot_material(src: Material) -> ShaderMaterial:
	var slot := src.resource_name
	if not _slot_materials.has(slot):
		var m := ShaderMaterial.new()
		m.shader = SOLID_SHADER
		m.set_shader_parameter("sway", 0.0)
		if slot.ends_with("Glow"):
			m.set_shader_parameter("glow", 1.2)
		_slot_materials[slot] = m
	var mat: ShaderMaterial = _slot_materials[slot]
	if CharacterLook.PALETTES.has(slot):
		mat.set_shader_parameter("albedo", hero_look.color(slot))
	elif slot == "Metal" and _metal_tint.a > 0.0:
		mat.set_shader_parameter("albedo", _metal_tint)
	elif src is StandardMaterial3D:
		mat.set_shader_parameter("albedo", (src as StandardMaterial3D).albedo_color)
	return mat


func _attach_hero() -> void:
	var scene := (load(body_model if body_model != "" else HERO) as PackedScene).instantiate()
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		mi.owner = null
		mi.get_parent().remove_child(mi)
		_skeleton.add_child(mi)
		mi.skeleton = NodePath("..")
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_parts.append(mi)
	scene.free()


## Puts a model in the right hand (an NPC's prop: shears). `grip` turns it, `offset` moves it from the wrist.
func hold_prop(item: String, grip: Vector3, offset := TOOL_OFFSET, bone := "hand_r") -> Node3D:
	var hand := BoneAttachment3D.new()
	hand.name = "PropHand" if bone == "hand_r" else "Prop_" + bone
	hand.bone_name = bone
	_skeleton.add_child(hand)
	var prop := MeshInstance3D.new()
	prop.mesh = Items.mesh(item)
	prop.rotation_degrees = grip
	prop.position = offset
	hand.add_child(prop)
	return prop


## Holds a prop low in front in both hands (Wren's shears): an arm pose after the animation (see
## two_hand_hold.gd). The one-handed `hand_prop` shows instead while `set_two_hand(false)` (working).
func hold_two_handed(item: String, scale_by: float, hand_prop: Node3D = null) -> void:
	var holder := MeshInstance3D.new()
	holder.mesh = Items.mesh(item)
	holder.scale = Vector3.ONE * scale_by
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(holder)
	_hold = SkeletonModifier3D.new()
	_hold.set_script(preload("res://scripts/player/two_hand_hold.gd"))
	_hold.visual = self
	_hold.holder = holder
	_skeleton.add_child(_hold)
	_hold_hand_prop = hand_prop
	set_two_hand(true)


func set_two_hand(on: bool) -> void:
	if _hold == null:
		return
	_hold_on = on
	if is_instance_valid(_hold_hand_prop):
		_hold_hand_prop.visible = not on


func skeleton() -> Skeleton3D:
	return _skeleton


## A model carried on the back (the bow): `at` places it in the model's own space at rest, like the
## sword on the back (BACK_SWORD_AT), so it sits the same whatever way the bone points.
func back_prop(mesh: Mesh, at: Transform3D) -> MeshInstance3D:
	var spine := _skeleton.find_bone("spine_03")
	var holder := BoneAttachment3D.new()
	holder.bone_name = "spine_03" if spine >= 0 else "Head"
	_skeleton.add_child(holder)
	var prop := MeshInstance3D.new()
	prop.mesh = mesh
	prop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var skel_in_self := global_transform.affine_inverse() * _skeleton.global_transform
	prop.transform = (skel_in_self * _skeleton.get_bone_global_rest(maxi(spine, 0))).affine_inverse() * at
	holder.add_child(prop)
	return prop


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
	# A second sword for the back, on the upper spine, placed from the rest pose so it sits the same
	# whatever way the bone points. It shares the hand sword's metal (tier colour).
	var spine := _skeleton.find_bone("spine_03")
	if spine < 0:
		return
	var back := BoneAttachment3D.new()
	back.bone_name = "spine_03"
	_skeleton.add_child(back)
	_back = (load(TOOLS["sword"]) as PackedScene).instantiate() as Node3D
	var skel_in_self := global_transform.affine_inverse() * _skeleton.global_transform
	_back.transform = (skel_in_self * _skeleton.get_bone_global_rest(spine)).affine_inverse() * Transform3D(
		Basis(Vector3.RIGHT, BACK_SWORD_LEAN) * Basis(Vector3.BACK, BACK_SWORD_TILT) * Basis(Vector3.UP, PI * 0.5), BACK_SWORD_AT)
	_back.visible = false
	back.add_child(_back)
	for mi: MeshInstance3D in _back.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surf in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(surf)
			if src and src.resource_name == "Metal" and _tool_metal.has("sword"):
				mi.set_surface_override_material(surf, _tool_metal["sword"])


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
