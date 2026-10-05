extends SkeletonModifier3D
## The bow drawn and aimed (player/fighter.gd): after the animation, the left arm holds the bow out in front
## at shoulder height and the right hand pulls the string back towards the cheek as `draw` goes 0..1
## (two-bone IK, like two_hand_hold.gd). It places the bow (crystal_bow_bare: no string) in the left hand,
## draws the string from both tips to the right hand, and the nocked arrow on it. `weight` fades the pose
## in and out (0 = the animation's own arms, and the bow, string and arrow are hidden).

const ARMS := {"l": ["upperarm_l", "lowerarm_l", "hand_l"], "r": ["upperarm_r", "lowerarm_r", "hand_r"]}
## The bow model (make_items.py) in Godot: the grip at the origin, the limbs along +Y, the string on the +Z side.
const TIP := 0.7                 # the string's ends along the bow (its own space, before scaling)
const STRING_Z := 0.025

var visual: Node3D               # the character root (its local space: +Z forward, +X the character's left)
var weight := 0.0
var draw := 0.0                  # 0 = string at rest, 1 = pulled to the cheek
var nocked := false              # an arrow on the string
var bow_scale := 1.15
var glow := Color(0.35, 1.0, 0.95)
var _bow: MeshInstance3D
var _strings: Array[MeshInstance3D] = []
var _arrow: MeshInstance3D
var _bones := {}
var _arm := 0.55


func _ready() -> void:
	_bow = MeshInstance3D.new()
	_bow.mesh = Items.mesh("crystal_bow_bare")
	_bow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child.call_deferred(_bow)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = glow
	for i in 2:
		var s := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.012, 0.012, 1.0)
		s.mesh = box
		s.material_override = m
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual.add_child.call_deferred(s)
		_strings.append(s)
	_arrow = MeshInstance3D.new()
	_arrow.mesh = Items.mesh("arrow")
	_arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child.call_deferred(_arrow)
	_show(false)


func _show(on: bool) -> void:
	for n: Node3D in [_bow, _arrow] + _strings:
		n.visible = on
	if on:
		_arrow.visible = nocked


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or visual == null:
		return
	if _bones.is_empty():
		for side: String in ARMS:
			_bones[side] = ARMS[side].map(func(b: String) -> int: return sk.find_bone(b))
		var ids: Array = _bones["l"]
		if not -1 in ids:
			_arm = sk.get_bone_global_rest(ids[0]).origin.distance_to(sk.get_bone_global_rest(ids[1]).origin) \
				+ sk.get_bone_global_rest(ids[1]).origin.distance_to(sk.get_bone_global_rest(ids[2]).origin)
	_show(weight > 0.5)
	if weight < 0.01 or -1 in _bones["l"] or -1 in _bones["r"]:
		return
	var to_vis := visual.global_transform.affine_inverse() * sk.global_transform
	var to_sk := to_vis.affine_inverse()
	var sl: Vector3 = to_vis * sk.get_bone_global_pose(_bones["l"][0]).origin
	var sr: Vector3 = to_vis * sk.get_bone_global_pose(_bones["r"][0]).origin
	var scale_by := to_vis.basis.get_scale().x                 # the rig's size in the visual's space
	var arm := _arm * scale_by
	var mid := (sl + sr) * 0.5
	var fwd := Vector3(0, 0, 1)
	# The bow hand: straight out in front of the left shoulder, a little in towards the middle.
	var grip := mid + Vector3((sl.x - mid.x) * 0.45, 0.04 * scale_by, 0.0) + fwd * arm * 0.92
	var cant := Basis(fwd, -0.22)                                 # the top tipped a little to the right
	var bow_basis := cant * Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)) * bow_scale   # string towards you
	var bow_at := Transform3D(bow_basis, grip)
	_bow.transform = bow_at
	var rest := bow_at * Vector3(0, 0, STRING_Z)
	var top := bow_at * Vector3(0, TIP, STRING_Z)
	var bottom := bow_at * Vector3(0, -TIP, STRING_Z)
	# The string hand: from the string at rest back towards the right cheek.
	var cheek := mid + Vector3((sr.x - mid.x) * 0.25, 0.16 * scale_by, 0.06 * scale_by)
	var nock := rest.lerp(cheek, clampf(draw, 0.0, 1.0))
	_segment(_strings[0], top, nock)
	_segment(_strings[1], nock, bottom)
	var aim := (grip + fwd * 0.5 - nock).normalized()
	_arrow.visible = nocked and weight > 0.5
	var side := aim.cross(Vector3.UP).normalized()                # the arrow model points along +Y
	_arrow.transform = Transform3D(Basis(side, aim, side.cross(aim)), nock + aim * 0.36)
	_reach(sk, _bones["l"], to_sk * (grip - fwd * 0.05), (to_sk.basis * Vector3(1.0, -0.7, -0.2)).normalized())
	_reach(sk, _bones["r"], to_sk * (nock - aim * 0.06), (to_sk.basis * Vector3(-1.0, 0.2, -0.9)).normalized())


## A thin bar from a to b (the string), in the visual's space.
func _segment(s: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var length := maxf(d.length(), 0.001)
	var up := Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT
	s.transform = Transform3D(Basis.looking_at(-d / length, up).scaled_local(Vector3(1, 1, length)), (a + b) * 0.5)


## Two-bone IK: bends upper arm and forearm so the wrist reaches `target` (blended by weight).
func _reach(sk: Skeleton3D, ids: Array, target: Vector3, pole: Vector3) -> void:
	var up: Transform3D = sk.get_bone_global_pose(ids[0])
	var lo: Transform3D = sk.get_bone_global_pose(ids[1])
	var wr: Transform3D = sk.get_bone_global_pose(ids[2])
	var s := up.origin
	target = wr.origin.lerp(target, weight)
	var a := (lo.origin - s).length()
	var b := (wr.origin - lo.origin).length()
	var d := target - s
	var dist := clampf(d.length(), 0.01, a + b - 0.001)
	var dir := d.normalized()
	var cos_a := clampf((a * a + dist * dist - b * b) / (2.0 * a * dist), -1.0, 1.0)
	var side := (pole - dir * pole.dot(dir)).normalized()
	var elbow := s + (dir * cos_a + side * sqrt(1.0 - cos_a * cos_a)) * a
	var turn1 := Quaternion((lo.origin - s).normalized(), (elbow - s).normalized())
	sk.set_bone_global_pose(ids[0], Transform3D(Basis(turn1) * up.basis, s))
	lo = sk.get_bone_global_pose(ids[1])
	wr = sk.get_bone_global_pose(ids[2])
	var turn2 := Quaternion((wr.origin - lo.origin).normalized(), (target - lo.origin).normalized())
	sk.set_bone_global_pose(ids[1], Transform3D(Basis(turn2) * lo.basis, lo.origin))
