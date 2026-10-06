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
## apply_hero_look, play_motion, walk_backward, step_rate, step_phase, play_action, animation_length, hit_stop,
## flash, show_tool, head_attachment), plus play_loop, set_detail, hand_attachment and hold_hands / release_hands. Not carried over: charge_tool
## (the player's sword only). Which parts show and how they are coloured mirrors
## CharacterVisual.apply_hero_look and _slot_material; keep the two in step.
##
## The people's body (people B5/B6/B8; elements and gestures drive it, pose.gd layers over it):
##   hold_posture(key, clip, at := 0.0, blend := 0.2, rate := 0.0, soft := false)   a whole-body posture held over
##            locomotion and loops: `clip` frozen at `at` seconds (rate 0) or played on from there at `rate`. While held,
##            play_motion, play_loop and play_action leave the body alone and holding() is true, so nothing knocks a lying
##            body back to idle. Only its key releases it; a soft one (a cower) also ends at the body's next step.
##            The key is the posture's name (down, dead, carried, cower): a later posture takes over, and the element
##            whose posture was taken over lets go of nothing (pose.gd reads down/dead/carried as on the ground).
##   play_posture(key, clip, from := 0.0, rate := 1.0, blend := 0.12)   the same, played (a fall, a get-up)
##   release_posture(key)   back to locomotion;  posture() -> key ("" none);  posture_position() -> seconds into it
##   set_gait(style)        "" or "limp" (a derived clip: Zombie_Walk_Fwd's legs under Walk's upper body, no new art)
##   set_surface(soot, ember)   0..1 each: blackened skin and a glowing flicker, on the body's own material copy
##   vocal(kind, strength)  grunt | gasp | cry | scream | groan | wail: emits `vocalized` for a real voice; meanwhile a
##            PLACEHOLDER made of the body's own talking blips (no recorded cry exists), `voice` picks the set
##   express(hints)         Mind's S5 hints: pose expression, idle stillness, a timid body's cower (a soft posture);
##            what it shows that others can read goes to metadata people_observable {threatening, fleeing}
##   moving_speed           m/s the body was last asked to move at (pose reads it: a fleeing glance, a panicked run)
##   apply_elements(layers) the one consumer of Body's element runner's named visual fields (see the function)

const TIER1_STEP := 0.1         # seconds between animation steps at detail tier 1 (about 10 Hz)
const LOOP_LIBRARY := "loop"    # looping copies of one-shot animations, made on first play_loop
const POSE := preload("res://scripts/studio/people/pose.gd")
const DERIVED_NATIVE := {"Walk_Limp": 1.016}    # derived clips' ground speed at rate 1 (m/s, measured by FK)
const LIMP_LEGS := ["thigh_l", "calf_l", "foot_l", "ball_l", "thigh_r", "calf_r", "foot_r", "ball_r", "root"]
const SOOT := Color(0.2, 0.18, 0.17)          # what a burned body's colours darken toward
const COWER_FROM := 0.55        # pose.contraction at which a standing body cowers ...
const COWER_UNTIL := 0.4        # ... and stands up out of it
## PLACEHOLDER vocal kinds, made of the body's talking blips: [blips, pitch first, pitch last, seconds apart, dB]
const VOCALS := {
	"grunt": [1, 0.72, 0.72, 0.0, -9.0], "gasp": [1, 1.4, 1.4, 0.0, -12.0], "cry": [3, 1.2, 1.55, 0.08, -7.0],
	"scream": [8, 1.35, 1.95, 0.06, -3.0], "groan": [2, 0.62, 0.55, 0.32, -12.0], "wail": [5, 1.15, 0.8, 0.15, -7.0],
}
const VOICE_PATH := "res://assets/sounds/voice_%s_%d.wav"
const POSTURE_RANK := {"carried": 4, "dead": 3, "down": 2, "cower": 1}   # which element posture shows when several ask
const LAYER_ONLY := ["posture", "surface", "gait", "still", "keep", "fx", "flash", "kick", "action", "clock", "weight",
	"fade"]   # not pose's
const OWN_CLUES := ["threatening", "fleeing"]   # people_observable keys this body's pose publishes
const MOTION := ["flail", "writhe", "tremble", "breath", "reach_l", "reach_r", "knee_l", "knee_r", "roll", "apply"]   # still masks

signal vocalized(kind: String, strength: float)

## CharacterVisual's defaults, except the look: a new body wears the default look rather than reading
## the player's saved look from disk (crowds make dozens of bodies, each given its own look anyway).
var hero_look := CharacterLook.new()
var is_player_look := true      # the player takes height/build from the look; NPCs set their own scale
var wear_gear := false          # show the player's worn armour over the look
var walk_backward := false      # play the walk in reverse (backing off), as CharacterVisual.walk_backward
var walk_clip := ""             # a walk of the scene's own (Walk_Carry, Walk_Formal) in place of the plain one
const PEOPLE_LAYER := 2         # physics layer of a villager's body: only the player collides with it (residents.gd)
const RUN_FROM := 1.9           # m/s: the jog clip from here (it plays down to half rate, 2.1 m/s; the walk up to 1.75:
                                # a walk shown faster than this glides, a jog this slow barely skates) ...
const RUN_UNTIL := 1.8          # ... and back to the walk below this
var _solid: AnimatableBody3D    # the body the player bumps into (made on first set_solid)
var _solid_shape: CollisionShape3D
var walk_native := 0.975        # ... and the ground speed it covers at rate 1 (m/s)
var moving_speed := 0.0         # m/s last asked of play_motion
var voice := ""                 # the body's voice set (residents.voice_of: man, woman, elder, child)
var vocal_placeholder := true   # false once a real voice answers `vocalized`
var _gait := ""                 # "" or "limp"
var _posture := ""              # the key holding a whole-body posture
var _posture_soft := false
var _posture_rate := 0.0
var _idle_rate := 1.0           # the idle's rate: slow when a bold body stands its ground, quick when a timid one frets
var _soot := 0.0
var _ember := 0.0
var _own_material: ShaderMaterial    # this body's copy of the material, only while flashing, sooted or glowing
var _own_glow: ShaderMaterial        # ... and of the glow material, when its look has glowing parts (surface 1)
var _vocal_player: AudioStreamPlayer3D
var _vocal_queue: Array = []    # [seconds until, pitch, dB]
var _applied := {}              # element layer key -> its fields as last applied (apply_elements)
var _still := false
var _element_posture := {}      # the posture spec apply_elements holds now ({} none)
var _fx := {}                   # element layer key -> {node, bone, at, kind}
var _flashes := {}              # element layer key -> its last flash value
var _kicks := {}                # element layer key -> its last kick number
var _actions := {}              # element layer key -> its last action number
var _clocks := {}               # element layer key -> its last clock (active seconds)
var _frozen := false            # element clocks stood still: active time has stopped, so every visual clock stops too
var _toward := Vector3.ZERO     # world direction the showing posture turns the rig to face (a fall away from a blow)
var _rig_yaw := 0.0             # radians the visual rig is turned from Body's facing (eased; back to 0 once upright)
var _rig_base := 0.0
const TURN_IN := 9.0            # radians a second the rig turns to face a blow as the fall begins
const TURN_BACK := 3.5          # and back to Body's facing once the body is up again
static var _puff: Texture2D     # a soft round sprite for smoke, steam and flames (made once, no asset)

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
var _pose: SkeletonModifier3D   # the head and upper body's own motion (people/pose.gd): a look, a flinch, a nod, a
                                # wave; only while it has something to show
var _pose_idle := 0.0           # seconds it has had nothing to show
var _head_kept := false         # head_forward reads the head's final pose, kept as each skeleton update ends
var _head_bone := -1
var _head_final := Basis()
var _head_seen := false
var _hands: TwoBoneIK3D         # only while the hands are held somewhere (hold_hands)
var _hand_marks: Array[Marker3D] = []   # the wrists' targets, then the elbows' poles (left, right)
var _hand: BoneAttachment3D
var _tools := {}                # name -> Node3D in the hand (made on first show_tool)
var _flash := 0.0

## Shared by every body, built on first use.
static var _part_names: Array[String] = []   # hero.glb's parts, in the file's order
static var _parts := {}         # part name -> [{"arrays", "slot", "albedo", "lods": [[edge, indices]]}] per surface
static var _skin: Skin
static var _material: ShaderMaterial
static var _glow_material: ShaderMaterial   # the second surface: slots CharacterVisual lights (glow 1.2: SunGlow, MaskGlow, LensGlow)
static var _models := {}        # model path -> {"names", "parts", "skin"}: hero.glb, and NPCs' ready-made bodies (merged_mesh)
static var _meshes := {}        # model and look key -> ArrayMesh
static var _library: AnimationLibrary
static var _loops: AnimationLibrary
static var _metals := {}        # tool metal: colour -> StandardMaterial3D (shared by tier colour)
static var _made := 0           # bodies made so far, to spread tier-1 steps over frames
static var _rig_template: PackedScene
static var _head_axis := Vector3.ZERO   # the body's forward in the head bone's rest frame (head_forward)
static var _voices := {}        # voice -> Array[AudioStream] (the placeholder vocals)


func _ready() -> void:
	# Strip the shared mannequin once. Re-instantiating and deleting all its meshes for every
	# resident made cold arrivals much more expensive than the measured steady-state animation.
	if _rig_template == null:
		var source := (load(CharacterVisual.RIG) as PackedScene).instantiate()
		for mi in source.find_children("*", "MeshInstance3D", true, false):
			mi.free()
		_rig_template = PackedScene.new()
		_rig_template.pack(source)
		source.free()
	_rig = _rig_template.instantiate()
	add_child(_rig)
	_skeleton = _rig.find_children("*", "Skeleton3D", true, false)[0]
	_rig_base = _rig.rotation.y
	_anim = _rig.find_children("*", "AnimationPlayer", true, false)[0]
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
	if _frozen:
		if not _fx.is_empty():
			_follow_fx()
		return                      # active time stands still: clips, pose, flash, embers and cries wait with it
	if _action_left > 0.0:
		_action_left -= delta
		if _action_left <= 0.0:
			_current = ""      # let play_motion pick idle/walk/run again
	if _detail == 1:
		_stepped += delta
		_step_left -= delta
		var moving_pose: bool = _pose != null and _pose.animating()     # a flinch or a nod shows from the very next frame
		if _step_left <= 0.0 or moving_pose:
			_anim.advance(_stepped)
			_stepped = 0.0
			if _step_left <= 0.0:
				_step_left = maxf(_step_left + TIER1_STEP, 0.0)
	_update_lean(delta)
	_turn_rig(delta)
	if _pose != null:
		_pose.step(delta)
		_pose_idle = _pose_idle + delta if _pose.idle() else 0.0
		if _pose_idle > 0.5:
			_pose.queue_free()               # nothing to show: no modifier (tier 1 relies on it)
			_pose = null
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 5.0, 0.0)
		_own_param("flash", _flash)
		if _flash == 0.0:
			_refresh_material()
	if _ember > 0.0 and _own_material != null:
		var now := Time.get_ticks_msec()
		var flicker := 0.65 + 0.2 * sin(now * 0.011 + float(get_instance_id() % 97)) + 0.15 * sin(now * 0.027)
		_own_param("warn", _ember * flicker)
	if not _vocal_queue.is_empty():
		_vocal_step(delta)
	if not _fx.is_empty():
		_follow_fx()


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
	if _detail != 0 or _frozen:
		_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_stepped = 0.0


func play_motion(speed: float) -> void:
	moving_speed = speed
	if _posture != "":
		if not (_posture_soft and speed > 0.2):
			return          # a held posture: the element holding it lets go
		_release()
		return
	if _action_left > 0.0:
		return
	if _holding_loop and speed <= 0.2:
		return          # standing still keeps a play_loop pose (arms folded, talking)
	_holding_loop = false
	var anim_name := CharacterVisual.IDLE
	if speed > 6.4:
		anim_name = CharacterVisual.SPRINT
	elif speed > RUN_FROM or (speed > RUN_UNTIL and _current == CharacterVisual.RUN):
		anim_name = CharacterVisual.RUN      # into a jog mid-way through the gap, out of it a little lower (no flicker)
	elif speed > 0.2:
		anim_name = walk_clip if walk_clip != "" else ("Walk_Limp" if _gait == "limp" else CharacterVisual.WALK)
	if anim_name != _current:
		_current = anim_name
		_anim.play(anim_name, 0.2)
	var native := _native(anim_name)
	# The clip at the speed actually moved (people/mover.gd eases in and out of a walk): a walk plays down to 0.4 of
	# its rate, a shuffle in a crowd (CharacterVisual's player keeps 0.7; a villager easing to a stop or edging through
	# people is slower than a player ever walks).
	var walking := anim_name == CharacterVisual.WALK or anim_name == walk_clip or anim_name == "Walk_Limp"
	var low := 0.4 if walking else (0.5 if anim_name == CharacterVisual.RUN else 0.7)
	_anim.speed_scale = clampf(speed / native, low, 1.8) if native > 0.0 else (_idle_rate if anim_name == CharacterVisual.IDLE else 1.0)
	if walk_backward and (anim_name == CharacterVisual.WALK or anim_name == "Walk_Limp"):
		_anim.speed_scale = -_anim.speed_scale


## Solid to the player (near them) or not (far, hidden): a cylinder the player's own body stops at, on a layer of its
## own, so animals and the world's sight lines pass as before.
func set_solid(on: bool) -> void:
	if _solid == null:
		if not on:
			return
		_solid = AnimatableBody3D.new()
		_solid.sync_to_physics = false
		_solid.collision_layer = PEOPLE_LAYER
		_solid.collision_mask = 0
		_solid_shape = CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.28
		shape.height = 1.7
		_solid_shape.shape = shape
		_solid_shape.position = Vector3(0.0, 0.85, 0.0)
		_solid.add_child(_solid_shape)
		add_child(_solid)
	if _solid_shape.disabled == on:
		_solid_shape.set_deferred("disabled", not on)


## The ground speed a clip covers at rate 1 (0: it does not travel).
func _native(anim_name: String) -> float:
	if anim_name != "" and anim_name == walk_clip:
		return walk_native
	return float(CharacterVisual.NATIVE_SPEED.get(anim_name, DERIVED_NATIVE.get(anim_name, 0.0)))


## Footfalls a second of the walk or run playing now (two per loop), so footsteps match the feet; 0 when standing
## still or mid-action (CharacterVisual.step_rate).
func step_rate() -> float:
	if _action_left > 0.0 or not (CharacterVisual.NATIVE_SPEED.has(_current) or DERIVED_NATIVE.has(_current)):
		return 0.0
	return 2.0 * absf(_anim.speed_scale) / _anim.get_animation(_current).length


## Where the feet are within a step (0 to 1, two steps per loop) (CharacterVisual.step_phase).
func step_phase() -> float:
	if not (CharacterVisual.NATIVE_SPEED.has(_current) or DERIVED_NATIVE.has(_current)):
		return 0.0
	return fmod(_anim.current_animation_position * 2.0 / _anim.get_animation(_current).length, 1.0)


## What the feet are doing, read-only (people/motion_watch.gd compares it with the ground actually covered): the clip
## playing, its rate, and the ground speed that clip at that rate covers (0 for one that does not travel, or paused).
func gait() -> Dictionary:
	var native := _native(_current)
	var playing := _anim.is_playing() and _detail < 2
	return {"clip": _current, "rate": _anim.speed_scale, "speed": native * absf(_anim.speed_scale) if playing else 0.0}


## Where the head points, in world space, read-only (probes now; the look director later). After the skeleton's
## modifiers (people/pose.gd: the look, the flinch): their work is only in the pose while the skeleton updates (polled
## any other time, the bones give the animation's pose), so the head's final pose is kept as each update ends.
func head_forward() -> Vector3:
	var bone := _skeleton.find_bone("Head")
	if bone < 0:
		return global_basis.z.normalized()
	if not _head_kept:
		_head_kept = true
		_head_bone = bone
		_skeleton.skeleton_updated.connect(_keep_head)
	if _head_axis == Vector3.ZERO:
		# the body's forward (+z) in the head bone's frame at rest: the same for every body (one rig)
		var forward := _skeleton.global_basis.orthonormalized().inverse() * global_basis.orthonormalized().z
		_head_axis = (_skeleton.get_bone_global_rest(bone).basis.orthonormalized().inverse() * forward).normalized()
	var head := _head_final if _head_seen else _skeleton.get_bone_global_pose(bone).basis
	return (_skeleton.global_basis.orthonormalized() * head.orthonormalized() * _head_axis).normalized()


## The head's whole turn in the world as drawn (a flinch rolls it as well as pitching it: its forward alone misses that).
func head_basis() -> Basis:
	head_forward()                       # (keeps the drawn pose from now on)
	var head := _head_final if _head_seen else _skeleton.get_bone_global_pose(_head_bone).basis
	return _skeleton.global_basis.orthonormalized() * head.orthonormalized()


func _keep_head() -> void:
	_head_final = _skeleton.get_bone_global_pose(_head_bone).basis
	_head_seen = true


## The head and upper body's own motion (people/pose.gd), made on first use.
func pose() -> SkeletonModifier3D:
	if _pose == null:
		_pose = POSE.new()
		_pose.name = "Pose"
		_pose.body = self
		_pose.turn = _rig_yaw
		_skeleton.add_child(_pose)
		if _hands != null:
			_skeleton.move_child(_pose, _hands.get_index())   # the wrists' hold stays the last word on the arms
		_pose_idle = 0.0
	return _pose


## Whether the pose modifier exists now (an element clearing its layer need not make one).
func has_pose() -> bool:
	return _pose != null


## Looks at a world point (Vector3.INF: ahead again), the head and a little of the chest turning to it.
func look_at_point(point: Vector3) -> void:
	if _pose == null and point == Vector3.INF:
		return
	pose().look_at_point(point)


## A blow from the direction `from` (world): the upper body is thrown away from it and rocks back.
func flinch(from: Vector3, force: float) -> void:
	pose().flinch(from, force)


func nod(times := 2) -> void:
	pose().nod(times)


func wave(seconds := 1.6) -> void:
	pose().wave(seconds)


## Plays one pass of an animation (a swing), optionally starting part-way through (for looping
## animations like TreeChopping, so a tap gives wind-up then strike). Idle/walk/run resume after.
func play_action(anim_name: String, speed := 1.0, start_at := 0.0) -> void:
	if _posture != "":
		return
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
## `speed` scales the loop's rate (the stage plays on its own clock: x8 fast-forward loops x8); asking
## for the loop already playing only changes its rate. `start_at` > 0 starts that far into the loop (so
## a crowd doesn't breathe in step).
## Whether a play_loop pose still holds (a step - a nudge, a step aside - ends it: the walk takes over, then idle).
func holding() -> bool:
	return _holding_loop or _posture != ""


func play_loop(anim_name: String, blend := 0.2, speed := 1.0, start_at := 0.0) -> void:
	if _posture != "":
		return
	var looped := _looping_name(anim_name)
	_holding_loop = true
	_action_left = 0.0
	_anim.speed_scale = speed
	if looped == _current:
		return
	_current = looped
	_anim.play(looped, blend)
	if start_at > 0.0:
		_anim.seek(fposmod(start_at, _anim.get_animation(looped).length), true)


## Holds the wrists at two points in the body's own space (+z forward; left is +x), elbows down and out,
## over whatever the body plays: the hands through a pillory's board. Two-bone IK on each arm (upper arm,
## forearm, hand); a skeleton with a modifier re-poses every frame, so it exists only while held.
func hold_hands(left: Vector3, right: Vector3) -> void:
	if _hands == null:
		_hands = TwoBoneIK3D.new()
		_hands.name = "Hands"
		_skeleton.add_child(_hands)
		_hands.set_setting_count(2)
		for i in 4:
			var mark := Marker3D.new()
			add_child(mark)
			_hand_marks.append(mark)
		for i in 2:
			var side := "_l" if i == 0 else "_r"
			_hands.set_root_bone_name(i, "upperarm" + side)
			_hands.set_middle_bone_name(i, "lowerarm" + side)
			_hands.set_end_bone_name(i, "hand" + side)
			_hands.set_target_node(i, _hands.get_path_to(_hand_marks[i]))
			_hands.set_pole_node(i, _hands.get_path_to(_hand_marks[i + 2]))
	_hand_marks[0].position = left
	_hand_marks[1].position = right
	_hand_marks[2].position = Vector3(0.7, left.y - 0.6, left.z - 0.35)
	_hand_marks[3].position = Vector3(-0.7, right.y - 0.6, right.z - 0.35)


func release_hands() -> void:
	if _hands == null:
		return
	_hands.queue_free()
	_hands = null
	for mark in _hand_marks:
		mark.queue_free()
	_hand_marks.clear()

func hands_held() -> bool:
	return _hands != null


func animation_length(anim_name: String) -> float:
	return _anim.get_animation(anim_name).length


## A split-second freeze on impact, so hits feel solid.
func hit_stop(seconds := 0.07) -> void:
	if _posture != "" and _posture_rate == 0.0:
		return              # a held posture is already still (and play() would set it moving)
	var resume := _posture_rate if _posture != "" else 1.0
	_anim.pause()
	get_tree().create_timer(seconds).timeout.connect(func() -> void: _anim.play(_anim.assigned_animation, -1, resume))


## A short white flash (taking a hit). The body switches to its own copy of the material while it
## flashes, so the shared material (and every other body) stays unlit.
func flash() -> void:
	_flash = 1.0
	_refresh_material()
	_own_param("flash", _flash)


## Blackened (soot 0..1) and glowing like embers (ember 0..1, flickering), on the body's own copy of the material;
## both 0: back to the shared one.
func set_surface(soot: float, ember: float) -> void:
	_soot = clampf(soot, 0.0, 1.0)
	_ember = clampf(ember, 0.0, 1.0)
	_refresh_material()
	if _own_material != null:
		_own_param("albedo", Color.WHITE.lerp(SOOT, _soot))
		_own_param("warn", _ember * 0.8)


func surface() -> Vector2:
	return Vector2(_soot, _ember)


func _refresh_material() -> void:
	var surfaces := _body.mesh.get_surface_count() if _body.mesh != null else 0
	if _flash > 0.0 or _soot > 0.0 or _ember > 0.0:
		if _own_material == null:
			_own_material = _material.duplicate() as ShaderMaterial
			_own_material.set_shader_parameter("albedo", Color.WHITE.lerp(SOOT, _soot))
		if surfaces > 1 and _own_glow == null:
			_own_glow = _glow_material.duplicate() as ShaderMaterial
			for p in ["albedo", "flash", "warn"]:
				_own_glow.set_shader_parameter(p, _own_material.get_shader_parameter(p))
		for i in surfaces:
			_body.set_surface_override_material(i, _own_glow if i == 1 else _own_material)
	else:
		for i in surfaces:
			_body.set_surface_override_material(i, null)   # back to the shared materials
		_own_material = null
		_own_glow = null


## Sets a parameter on this body's own material copies (both surfaces).
func _own_param(param: String, value: Variant) -> void:
	if _own_material != null:
		_own_material.set_shader_parameter(param, value)
	if _own_glow != null:
		_own_glow.set_shader_parameter(param, value)


## Holds a whole-body posture (see the header). Asking again with the same key moves it to the new clip and time.
func hold_posture(key: String, clip: String, at := 0.0, blend := 0.2, rate := 0.0, soft := false) -> void:
	_posture = key
	_posture_soft = soft
	_posture_rate = rate
	_holding_loop = false
	_action_left = 0.0
	var anim_name := _looping_name(clip) if rate > 0.0 and soft else clip
	_current = anim_name
	_anim.speed_scale = 1.0          # (a blend runs on the player's own rate: rate 0 freezes the clip, not the blend)
	_anim.play(anim_name, blend, rate)
	_anim.seek(clampf(at, 0.0, _anim.get_animation(anim_name).length), true)


func play_posture(key: String, clip: String, from := 0.0, rate := 1.0, blend := 0.12) -> void:
	if _anim.current_animation == clip and _posture == key:
		_anim.stop()                 # (replaying the same clip would otherwise continue it)
	hold_posture(key, clip, from, blend, rate)


func release_posture(key: String) -> void:
	if key == _posture and key != "":
		_release()


func _release() -> void:
	_posture = ""
	_posture_soft = false
	_posture_rate = 0.0
	_current = ""
	play_motion(moving_speed)


func posture() -> String:
	return _posture


func posture_position() -> float:
	return _anim.current_animation_position if _posture != "" else 0.0


## "" (the plain walk) or "limp".
func set_gait(style: String) -> void:
	if style == _gait:
		return
	_gait = style
	if _posture == "" and _action_left <= 0.0 and not _holding_loop and moving_speed > 0.2:
		_current = ""
		play_motion(moving_speed)


func gait_style() -> String:
	return _gait


## A cry from the body (see the header). Strength 0..1 (or a saved 0..1000) makes it louder; the placeholder plays only
## while the body is shown and has a voice.
func vocal(kind: String, strength := 1.0) -> void:
	var k := strength / 1000.0 if strength > 1.0 else clampf(strength, 0.0, 1.0)
	vocalized.emit(kind, k)
	if not vocal_placeholder or voice == "" or not VOCALS.has(kind) or _detail == 2:
		return
	var clips := _voice_clips(voice)
	if clips.is_empty():
		return
	var v: Array = VOCALS[kind]
	var n: int = int(v[0]) if k >= 0.5 or int(v[0]) <= 2 else maxi(2, int(ceil(float(v[0]) * (0.4 + k))))
	_vocal_queue.clear()
	for i in n:
		var t := float(i) / maxf(float(n - 1), 1.0)
		_vocal_queue.append([float(i) * float(v[3]), lerpf(float(v[1]), float(v[2]), t), float(v[4]) - 6.0 * (1.0 - k)])
	_vocal_step(0.0)


func vocal_playing() -> bool:
	return not _vocal_queue.is_empty() or (_vocal_player != null and _vocal_player.playing)


func _vocal_step(delta: float) -> void:
	for q: Array in _vocal_queue:
		q[0] -= delta
	while not _vocal_queue.is_empty() and float(_vocal_queue[0][0]) <= 0.0:
		var q: Array = _vocal_queue.pop_front()
		if _vocal_player == null:
			_vocal_player = AudioStreamPlayer3D.new()
			_vocal_player.name = "Vocal"
			_vocal_player.position = Vector3(0, 1.55, 0)
			_vocal_player.max_distance = 26.0
			_vocal_player.unit_size = 4.0
			add_child(_vocal_player)
		var clips := _voice_clips(voice)
		_vocal_player.stream = clips[_vocal_queue.size() % clips.size()]
		_vocal_player.pitch_scale = q[1]
		_vocal_player.volume_db = q[2]
		_vocal_player.play()


static func _voice_clips(set_name: String) -> Array:
	if not _voices.has(set_name):
		var clips: Array = []
		for i in 8:
			var path := VOICE_PATH % [set_name, i]
			if ResourceLoader.exists(path):
				clips.append(load(path))
		_voices[set_name] = clips
	return _voices[set_name]


## Mind's S5 hints (sim/people.gd expression: fear, anger, pain, interest, alertness, tension, style {show, steady,
## pace, lean}). The face and stance go to pose (interest and alertness too, for a near body clearly feeling them; style
## pace quickens or slows the idle); a bold frightened body's idle nearly stops (it stands its ground), a
## timid one's frets; a timid body frightened enough cowers where it stands (a soft posture: its next step ends it).
## Hints never move the body, pick where it goes or who helps.
func express(hints: Dictionary) -> void:
	if _detail == 2 or _frozen:
		return
	if _posture == "dead":
		if _pose != null:
			_pose.expression({})        # (a corpse shows nothing it might have felt)
		_show_clues()
		return
	var felt := false          # (a modifier re-poses its skeleton every frame: a far body needs a strong feeling for one)
	var enough := 0.05 if _detail == 0 else 0.3
	for channel: String in ["fear", "anger", "pain", "tension"]:
		felt = felt or POSE._unit(hints.get(channel, 0.0)) >= enough
	for channel: String in ["interest", "alertness"]:                # (milder: only a clear one is worth a modifier)
		felt = felt or POSE._unit(hints.get(channel, 0.0)) >= maxf(enough, 0.25)
	if felt or _pose != null:
		pose().expression(hints)
	var style: Dictionary = hints.get("style", {})
	var fear := POSE._unit(hints.get("fear", 0.0))
	var steady := POSE._unit(style.get("steady", 0.5))
	var contract := POSE.contraction(fear, POSE._unit(style.get("show", 0.5)), steady)
	var pace := clampf(float(style.get("pace", 0.0)) / (1000.0 if absf(float(style.get("pace", 0.0))) > 1.0 else 1.0), -1.0, 1.0)
	_idle_rate = clampf((1.0 - 0.7 * fear * steady + 0.6 * contract) * (1.0 + 0.25 * pace), 0.3, 1.6)
	if _current == CharacterVisual.IDLE and _posture == "" and not _holding_loop and _action_left <= 0.0:
		_anim.speed_scale = _idle_rate
	if _posture == "" and contract >= COWER_FROM and moving_speed <= 0.2 and _hands == null and _action_left <= 0.0:
		hold_posture("cower", "Crouch_Idle", 0.0, 0.35, 0.45, true)
	elif _posture == "cower" and contract < COWER_UNTIL:
		release_posture("cower")
	if _posture == "cower":
		var cover := clampf((contract - COWER_FROM) / 0.25, 0.0, 1.0)
		pose().set_layer("express:cower", {"spine": Vector3(0.25, 0.0, 0.0), "head": Vector3(0.3, 0.0, 0.0),
			"reach_l": {"bone": "Head", "at": Vector3(0.1, 0.13, 0.06), "pole": Vector3(0.8, 0.0, 0.6), "priority": 2},
			"reach_r": {"bone": "Head", "at": Vector3(-0.1, 0.13, 0.06), "pole": Vector3(-0.8, 0.0, 0.6), "priority": 2}},
			cover, 0.3)
	elif _pose != null and _pose.has_layer("express:cower"):
		_pose.clear_layer("express:cower", 0.3)
	_show_clues()


## What the pose shows now that others can read, as body metadata people_observable (people_bridge's visible clues:
## never a doer, a cause or a saved decision): an angry body leaning in is threatening, a frightened one running flees.
## Set only while shown; cleared the moment it is not (calm, lying, dead). Other writers' clues are left alone.
func _show_clues() -> void:
	var shown := {}
	if _posture == "" and _pose != null:
		if float(_pose._f("anger")) * maxf(float(_pose._f("lean")), 0.0) >= 0.3:
			shown["threatening"] = true
		if float(_pose._f("fear")) > 0.45 and moving_speed > 2.4:
			shown["fleeing"] = true
	var had: Dictionary = get_meta("people_observable", {})
	var now := had.duplicate()
	for clue: String in OWN_CLUES:
		now.erase(clue)
	now.merge(shown, true)
	if now == had:
		return
	if now.is_empty():
		remove_meta("people_observable")
	else:
		set_meta("people_observable", now)


## Body's element runner (people/body_elements.gd) keeps each playing element's named visual fields in runner.layers;
## residents hand them here every frame. This is their one consumer. Fields of a layer (all optional):
##   pose.gd's layer params (spine, head, shoulders, reach_l/_r, fist(_l/_r), breath, tremble, flail, writhe, roll,
##            knee_l/_r, apply), with weight (0..1, default 1) and fade (seconds it eases in and out, default 0.2)
##   posture {name, clip, at, rate := 0.0, blend := 0.2, soft := false}  or  {name, clip, from, rate := 1.0, blend}
##            (+ toward: Vector3 world direction: the visual rig turns to face it, so a fall goes away from a blow; the
##            turn holds while any posture does and eases back to Body's facing once the body is up)
##            (`at` holds or loops from there, `from` plays on). Of all the layers' postures the highest ranked shows
##            (carried > dead > down > cower: a carried corpse hangs as carried); a changed spec is played anew, the same
##            spec never replays
##   surface Vector2(soot, ember)   the most of each across the layers
##   gait "limp"     any layer limping limps the walk
##   still true      a dead body: every other layer's motion (flail, tremble, breath, reaches, knees, roll) is masked
##   keep true       a shape death does not mask (a carried body's drape)
##   fx {kind: flames | smoke | steam, bone := "spine_02", at := Vector3 metres off the bone, size := 1.0}
##            an upright effect that follows the bone while the layer has it
##   flash int       a white flash each time the value changes
##   kick {from: Vector3 towards the source (world), force 0..1, n: int}   the upper body thrown, once per new n
##   action {clip, n: int, from := 0.0, rate := 1.0}   a one-shot clip over locomotion, once per new n (a held posture
##            ignores it: a lying body does not play a standing hit)
##   clock float     the element's active seconds. While layers carry clocks and none moved since the last call,
##            active time has stopped: pose, flash, embers, effects and cries freeze with it. Postures follow their
##            element's time too: the same name and clip at a new `at` only seeks (a clip scrubbed by the element's
##            clock freezes with it and resumes at the right age after a reload)
## A key that disappears clears its pose layer and effect, and the posture if it was the one showing. Wrist holds stay
## the last word on the arms and a lying posture turns the look off (pose.gd), whatever the layers ask.
func apply_elements(layers: Dictionary) -> void:
	if layers.is_empty() and _applied.is_empty():
		return
	var still := false
	var clocked := false
	var ticking := false
	for key: String in layers:
		var lf: Dictionary = layers[key]
		still = still or bool(lf.get("still", false))
		if lf.has("clock"):
			clocked = true
			ticking = ticking or float(_clocks.get(key, -1.0)) != float(lf.clock)
			_clocks[key] = float(lf.clock)
	for key: String in _clocks.keys():
		if not layers.has(key):
			_clocks.erase(key)
	_set_frozen(clocked and not ticking)
	var restill := still != _still
	_still = still
	for key: String in _applied.keys():
		if not layers.has(key):
			_drop_layer(key)
	var best := {}
	var best_rank := -1
	var soot := 0.0
	var ember := 0.0
	var limp := false
	for key: String in layers:
		var f: Dictionary = layers[key]
		var shape := f.duplicate()
		shape.erase("clock")            # (a moving clock alone changes nothing to show)
		if restill or not _applied.has(key) or _applied[key] != shape:
			_apply_layer(key, f, still and not bool(f.get("still", false)) and not bool(f.get("keep", false)))
			_applied[key] = shape.duplicate(true)
		var spec: Dictionary = f.get("posture", {})
		if not spec.is_empty() and int(POSTURE_RANK.get(str(spec.get("name", "")), 0)) > best_rank:
			best = spec
			best_rank = int(POSTURE_RANK.get(str(spec.get("name", "")), 0))
		var surf: Vector2 = f.get("surface", Vector2.ZERO)
		soot = maxf(soot, surf.x)
		ember = maxf(ember, surf.y)
		limp = limp or str(f.get("gait", "")) == "limp"
	if best != _element_posture:
		var scrub: bool = not best.is_empty() and not best.has("from") and float(best.get("rate", 0.0)) == 0.0 \
			and _posture == str(best.get("name", "")) and str(_element_posture.get("name", "")) == _posture \
			and str(_element_posture.get("clip", "")) == str(best.get("clip", "")) and not _element_posture.has("from")
		if scrub:
			_anim.seek(clampf(float(best.get("at", 0.0)), 0.0, _anim.get_animation(str(best["clip"])).length), true)
		elif best.is_empty():
			release_posture(str(_element_posture.get("name", "")))
		elif best.has("from"):
			play_posture(str(best["name"]), str(best["clip"]), float(best["from"]), float(best.get("rate", 1.0)), float(best.get("blend", 0.12)))
		else:
			hold_posture(str(best["name"]), str(best["clip"]), float(best.get("at", 0.0)), float(best.get("blend", 0.2)),
				float(best.get("rate", 0.0)), bool(best.get("soft", false)))
		_element_posture = best.duplicate(true)
	if not is_equal_approx(soot, _soot) or not is_equal_approx(ember, _ember):
		set_surface(soot, ember)
	set_gait("limp" if limp else "")
	_toward = best.get("toward", Vector3.ZERO) if not best.is_empty() else Vector3.ZERO


func _apply_layer(key: String, f: Dictionary, masked: bool) -> void:
	var params := {}
	for field: String in f:
		if field in LAYER_ONLY or (masked and field in MOTION):
			continue
		params[field] = f[field]
	if not params.is_empty():
		pose().set_layer("element:" + key, params, float(f.get("weight", 1.0)), float(f.get("fade", 0.2)))
	elif _pose != null and _pose.has_layer("element:" + key):
		_pose.clear_layer("element:" + key, float(f.get("fade", 0.25)))
	var fx: Dictionary = f.get("fx", {})
	var had: Dictionary = _fx.get(key, {})
	if fx.is_empty() or (not had.is_empty() and str(had.kind) != str(fx.get("kind", ""))):
		_drop_fx(key)
		had = {}
	if not fx.is_empty():
		if had.is_empty():
			had = {"node": _make_fx(str(fx.get("kind", "flames")), float(fx.get("size", 1.0))), "kind": str(fx.get("kind", "flames"))}
			_fx[key] = had
		had.bone = _skeleton.find_bone(str(fx.get("bone", "spine_02")))
		had.at = fx.get("at", Vector3.ZERO)
		_follow_fx()
	if f.has("flash") and _flashes.get(key) != f.flash:
		_flashes[key] = f.flash
		flash()
	var kick: Dictionary = f.get("kick", {})
	if not kick.is_empty() and _kicks.get(key) != kick.get("n", 0):
		_kicks[key] = kick.get("n", 0)
		pose().flinch(kick.get("from", Vector3.BACK), float(kick.get("force", 0.5)))
	var action: Dictionary = f.get("action", {})
	if not action.is_empty() and _actions.get(key) != action.get("n", 0):
		_actions[key] = action.get("n", 0)
		if _anim.has_animation(str(action.get("clip", ""))):
			play_action(str(action.clip), float(action.get("rate", 1.0)), float(action.get("from", 0.0)))


func _drop_layer(key: String) -> void:
	var f: Dictionary = _applied[key]
	_applied.erase(key)
	_flashes.erase(key)
	_kicks.erase(key)
	_actions.erase(key)
	if _pose != null and _pose.has_layer("element:" + key):
		_pose.clear_layer("element:" + key, float(f.get("fade", 0.25)))
	_drop_fx(key)


func _drop_fx(key: String) -> void:
	if not _fx.has(key):
		return
	var node: Node = _fx[key].node
	_fx.erase(key)
	if is_instance_valid(node):
		if node is CPUParticles3D:
			(node as CPUParticles3D).emitting = false     # what is in the air finishes, then it goes
			get_tree().create_timer((node as CPUParticles3D).lifetime + 0.1).timeout.connect(node.queue_free)
		else:
			node.queue_free()


func _set_frozen(on: bool) -> void:
	if on == _frozen:
		return
	_frozen = on
	if on:
		_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	elif _detail == 0:
		_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	for key: String in _fx:
		var node := _fx[key].node as CPUParticles3D
		if is_instance_valid(node):
			node.speed_scale = 0.0 if on else 1.0
	if _vocal_player != null:
		_vocal_player.stream_paused = on


func frozen() -> bool:
	return _frozen


## The visual rig's turn from Body's facing (Body's mover keeps the root's): toward a fall's source while that posture
## asks, held while any posture is, eased back once upright. Purely visual: nothing reads it as where the body faces.
func _turn_rig(delta: float) -> void:
	var want := _rig_yaw if _posture != "" else 0.0
	if _posture != "" and _toward != Vector3.ZERO:
		var local := global_basis.orthonormalized().inverse() * _toward
		want = atan2(local.x, local.z)
	if is_equal_approx(_rig_yaw, want):
		return
	var rate := TURN_IN if _posture != "" else TURN_BACK
	_rig_yaw += clampf(angle_difference(_rig_yaw, want), -rate * delta, rate * delta)
	_rig.rotation.y = _rig_base + _rig_yaw
	if _pose != null:
		_pose.turn = _rig_yaw


func rig_turn() -> float:
	return _rig_yaw


## Effects stand upright on their bone: the emitter follows it, the particles rise in the world.
func _follow_fx() -> void:
	for key: String in _fx:
		var fx: Dictionary = _fx[key]
		var node := fx.node as Node3D
		if is_instance_valid(node) and int(fx.get("bone", -1)) >= 0:
			node.global_position = _skeleton.global_transform * _skeleton.get_bone_global_pose(int(fx.bone)).origin \
				+ global_basis * (fx.get("at", Vector3.ZERO) as Vector3)


## Flames, smoke or steam: soft round puffs (a radial sprite made once in code), flames added light, smoke and steam
## drifting up and spreading.
func _make_fx(kind: String, size: float) -> CPUParticles3D:
	var p := make_fx(kind, size)
	add_child(p)
	p.speed_scale = 0.0 if _frozen else 1.0
	p.emitting = true
	return p


## One element effect, made but not placed: flames, smoke or steam, at a body's scale (size 1). Shared with things
## (graphics S4, things/thing_body.gd), so a burning fence burns as a burning person does.
static func make_fx(kind: String, size: float, many := 1.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var flames := kind == "flames"
	var steam := kind == "steam"
	p.amount = int((40 if flames else 16 if steam else 10) * size * many)
	p.lifetime = 0.5 if flames else 0.9 if steam else 1.8
	if flames:                  # tongues licking up the whole trunk, not a ball at the chest
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(0.17, 0.4, 0.11) * size
	else:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.18 * size
	p.direction = Vector3.UP
	p.spread = 10.0 if flames else 25.0
	p.gravity = Vector3(0, 1.6 if flames else 0.9 if steam else 0.5, 0)
	p.initial_velocity_min = 0.9 if flames else 0.7 if steam else 0.25
	p.initial_velocity_max = 1.9 if flames else 1.5 if steam else 0.6
	p.scale_amount_min = 0.55 if flames else 0.7
	p.scale_amount_max = 1.0 if flames else 1.4
	var quad := QuadMesh.new()
	quad.size = Vector2(0.2, 0.3) * size if flames else Vector2.ONE * 0.5 * size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if flames else BaseMaterial3D.BLEND_MODE_MIX
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _puff_texture()
	quad.material = m
	p.mesh = quad
	var ramp := Gradient.new()
	if flames:                  # a yellow-white core, orange, a dark red fading out (the ends first: add_point appends)
		ramp.set_color(0, Color(1.0, 0.72, 0.28, 0.85))
		ramp.set_color(1, Color(0.45, 0.05, 0.02, 0.0))
		ramp.add_point(0.4, Color(1.0, 0.38, 0.06, 0.65))
	else:
		ramp.set_color(0, Color(0.92, 0.94, 0.97, 0.5) if steam else Color(0.2, 0.18, 0.17, 0.55))
		ramp.set_color(ramp.get_point_count() - 1, Color(0.95, 0.95, 0.95, 0.0) if steam else Color(0.42, 0.41, 0.4, 0.0))
	p.color_ramp = ramp
	var grow := Curve.new()             # flames shrink as they rise; smoke and steam spread
	grow.add_point(Vector2(0, 1.0 if flames else 0.4))
	grow.add_point(Vector2(1, 0.2 if flames else 1.0))
	p.scale_amount_curve = grow
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Born already running: particles not yet emitted in the first lifetime drew as one black disc at the emitter
	# (unseen under the added flames, plain in smoke and steam; graphics S4, 5 Oct).
	p.preprocess = p.lifetime
	return p


static func _puff_texture() -> Texture2D:
	if _puff == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.55, Color(1, 1, 1, 0.55))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_puff = t
	return _puff


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
	_body.mesh = merged_mesh(CharacterVisual.HERO, names, colors)
	_refresh_material()


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


## Reads hero.glb's parts once (model_parts): the body's own tables.
static func _load_parts() -> void:
	if _skin != null:
		return
	var hero := model_parts(CharacterVisual.HERO)
	_part_names = hero["names"]
	_parts = hero["parts"]
	_skin = hero["skin"]


## A model's parts, read once: their vertex arrays, colour slot, own colour and LOD index lists, in the file's order,
## and the skin they share. hero.glb for every villager; a ready-made body (Morrow, Brakk, the Seeker) for CharacterMerge.
static func model_parts(path: String) -> Dictionary:
	if _models.has(path):
		return _models[path]
	var names: Array[String] = []
	var parts := {}
	var skin: Skin = null
	var scene := (load(path) as PackedScene).instantiate()
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if skin == null:
			skin = mi.skin
		elif mi.skin != skin:
			push_error("VillagerBody: %s in %s has its own skin; merging assumes the model shares one" % [mi.name, path])
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
		names.append(String(mi.name))
		parts[String(mi.name)] = surfaces
	scene.free()
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = CharacterVisual.SOLID_SHADER
		_material.set_shader_parameter("sway", 0.0)
		_material.set_shader_parameter("albedo", Color.WHITE)   # the colours are in the UVs
		_glow_material = _material.duplicate() as ShaderMaterial
		_glow_material.set_shader_parameter("glow", 1.2)        # CharacterVisual._slot_material's glow for "...Glow" slots
	_models[path] = {"names": names, "parts": parts, "skin": skin}
	return _models[path]


## The one merge path: the merged mesh of these parts of a model in these slot colours, built once per look and shared
## by every body wearing it (villagers through apply_hero_look; the player and Enea's NPCs through CharacterMerge).
static func merged_mesh(model: String, names: Array[String], colors: Dictionary) -> ArrayMesh:
	var key := model + ":" + ",".join(names)
	var slots := colors.keys()
	slots.sort()
	for slot: String in slots:
		key += "|%s=%s" % [slot, (colors[slot] as Color).to_html(false)]
	if not _meshes.has(key):
		_meshes[key] = _build_mesh(model_parts(model)["parts"], names, colors)
	return _meshes[key]


## Lit as CharacterVisual._slot_material lights it (glow 1.2): those parts go on the second surface.
static func glows(slot: String) -> bool:
	return slot.ends_with("Glow")


## An index buffer from the renderer's bytes (16-bit for small meshes, 32-bit otherwise).
static func _indices(bytes: PackedByteArray, width: int) -> PackedInt32Array:
	if width == 4:
		return bytes.to_int32_array()
	var out := PackedInt32Array()
	out.resize(bytes.size() / 2)
	for i in out.size():
		out[i] = bytes.decode_u16(i * 2)
	return out


## The given parts as skinned surfaces, each part's slot colour multiplied into its shade UVs: surface 0 for every
## plain slot, surface 1 (only when the look has one) for the glowing slots, on the glow material.
## LODs: each surface gets a level at every edge length any of its parts has a LOD at; at each level every part uses
## its own coarsest LOD at or under that length. The renderer picks the level from the error it allows, so each part
## ends up at the same LOD it would pick on its own.
static func _build_mesh(parts: Dictionary, names: Array[String], colors: Dictionary) -> ArrayMesh:
	var plain := []
	var lit := []
	for n in names:
		for s: Dictionary in parts[n]:
			(lit if glows(s["slot"]) else plain).append(s)
	var mesh := ArrayMesh.new()
	var groups := [plain, lit]
	for g in 2:
		if (groups[g] as Array).is_empty():
			continue
		_add_surface(mesh, groups[g], colors)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _glow_material if g == 1 else _material)
	return mesh


static func _add_surface(mesh: ArrayMesh, group: Array, colors: Dictionary) -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var index := PackedInt32Array()
	var placed := []        # [first vertex, surface] for the LOD pass
	var edges := {}         # every LOD edge length among the parts
	for s: Dictionary in group:
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
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], lods)


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
	_derive_limp(lib)
	return lib


## Walk_Limp: Zombie_Walk_Fwd's legs (one dragged) under Walk's upper body, the pelvis half way between the two, so
## a hurt body limps with the village's own clips and no new art. Both clips are 1.333 s loops.
static func _derive_limp(lib: AnimationLibrary) -> void:
	if not (lib.has_animation("Zombie_Walk_Fwd") and lib.has_animation(CharacterVisual.WALK)):
		return
	var legs := lib.get_animation("Zombie_Walk_Fwd")
	var upper := lib.get_animation(CharacterVisual.WALK)
	var limp := Animation.new()
	limp.length = legs.length
	limp.loop_mode = Animation.LOOP_LINEAR
	var pelvis_l := -1
	var pelvis_u := -1
	for t in legs.get_track_count():
		var bone := String(legs.track_get_path(t).get_concatenated_subnames())
		if bone == "pelvis" and legs.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			pelvis_l = t
		elif bone in LIMP_LEGS or bone == "pelvis":
			legs.copy_track(t, limp)
	for t in upper.get_track_count():
		var bone := String(upper.track_get_path(t).get_concatenated_subnames())
		if bone == "pelvis" and upper.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			pelvis_u = t
		elif not (bone in LIMP_LEGS or bone == "pelvis"):
			upper.copy_track(t, limp)
	if pelvis_l >= 0 and pelvis_u >= 0:
		var t := limp.add_track(Animation.TYPE_ROTATION_3D)
		limp.track_set_path(t, legs.track_get_path(pelvis_l))
		for k in legs.track_get_key_count(pelvis_l):
			var at := legs.track_get_key_time(pelvis_l, k)
			var q: Quaternion = legs.track_get_key_value(pelvis_l, k)
			limp.rotation_track_insert_key(t, at, q.slerp(upper.rotation_track_interpolate(pelvis_u, fmod(at, upper.length)), 0.5))
	lib.add_animation("Walk_Limp", limp)


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
