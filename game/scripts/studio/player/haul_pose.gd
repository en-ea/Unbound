extends SkeletonModifier3D
## His arms to the load while he hauls (haul.gd), after the walk or jog: no clip in the libraries carries a body on the
## shoulders or pulls a rope over one (plan LIVELY-VILLAGE 1.3: a proper clip is a proposal for Enea).
##   carry   both hands up at the chest, holding the legs of the body across his shoulders
##   drag    the right hand at the right shoulder, holding the rope over it; the body leans into the pull
## Two-bone reach for each arm (as two_hand_hold.gd does for Wren's shears), faded in over FADE_S.
const ARMS := {"l": ["upperarm_l", "lowerarm_l", "hand_l"], "r": ["upperarm_r", "lowerarm_r", "hand_r"]}
const SPINE := ["spine_01", "spine_02", "spine_03"]
## Where each hand goes, in his own frame (+Z forward, +X his left), metres from spine_03; and the elbow's way out.
const GRIPS := {
	"carry": {"l": Vector3(0.2, 0.12, 0.2), "r": Vector3(-0.2, 0.12, 0.2)},
	"drag": {"r": Vector3(-0.17, 0.2, 0.02)},
}
const LEAN := {"carry": 0.0, "drag": 14.0}     # degrees forward, spread over the spine
const FADE_S := 0.3

var visual: Node3D
var how := "carry"
var weight := 0.0
var _bones := {}
var _spine: Array[int] = []


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or visual == null:
		return
	if _bones.is_empty():
		for side: String in ARMS:
			_bones[side] = ARMS[side].map(func(b: String) -> int: return sk.find_bone(b))
		for b: String in SPINE:
			_spine.append(sk.find_bone(b))
	weight = minf(weight + get_process_delta_time() / FADE_S, 1.0)
	var lean: float = LEAN[how] * weight
	if lean > 0.1:
		var tip := Basis(Vector3.RIGHT, deg_to_rad(lean) / SPINE.size())
		for i in _spine:
			if i >= 0:
				var pose := sk.get_bone_global_pose(i)
				pose.basis = tip * pose.basis
				sk.set_bone_global_pose(i, pose)
	var s3 := sk.find_bone("spine_03")
	if s3 < 0:
		return
	var chest := sk.get_bone_global_pose(s3).origin
	# his own frame in the skeleton's space: the visual's axes (the skeleton may be turned or scaled under it)
	var to_sk := (visual.global_transform.affine_inverse() * sk.global_transform).affine_inverse()
	for side: String in GRIPS[how]:
		var ids: Array = _bones[side]
		if -1 in ids:
			continue
		var target: Vector3 = chest + to_sk.basis * (GRIPS[how][side] as Vector3)
		var pole: Vector3 = (to_sk.basis * Vector3(1.0 if side == "l" else -1.0, -0.6, -0.3)).normalized()
		_reach(sk, ids, target, pole)


## Two-bone reach: the upper arm and forearm bend so the wrist comes to `target`, blended by `weight`.
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
