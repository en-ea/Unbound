extends SkeletonModifier3D
## Holds a two-handed prop (Wren's shears) low in front: after the animation, both arms are bent
## (two-bone IK) so each hand grips one handle, and the prop hangs between them. `weight` fades
## the hold in and out (0 = the animation's own arms, e.g. while working). Set by CharacterVisual.

const ARMS := {"l": ["upperarm_l", "lowerarm_l", "hand_l"], "r": ["upperarm_r", "lowerarm_r", "hand_r"]}

var visual: Node3D              # the character root (its local space: +Z forward, +X the left side)
var holder: Node3D              # the prop's node, a child of `visual`
var pivot := Vector3(0.0, 0.76, 0.62)        # where the prop hangs (its pivot), in the visual's local metres
var tilt := Vector3(160.0, 0.0, 14.0)        # the prop's turn (degrees): blades down to the ground, handles up to the hands
var grips := {"l": Vector3(0.12, -0.36, 0.0), "r": Vector3(-0.12, -0.36, 0.0)}   # handle points in the prop's space (blades along +Y)
var weight := 0.0
var _bones := {}


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or visual == null or holder == null:
		return
	if _bones.is_empty():
		for side: String in ARMS:
			_bones[side] = ARMS[side].map(func(b: String) -> int: return sk.find_bone(b))
	holder.visible = weight > 0.5
	if weight < 0.01:
		return
	# Follow the hips a little so the prop bobs with the walk.
	var pelvis := sk.find_bone("pelvis")
	var to_vis := visual.global_transform.affine_inverse() * sk.global_transform
	var hip_y := (to_vis * sk.get_bone_global_pose(pelvis).origin).y if pelvis >= 0 else 0.95
	holder.transform = Transform3D(Basis.from_euler(tilt * PI / 180.0), pivot + Vector3(0, hip_y - 0.95, 0))
	var to_sk := to_vis.affine_inverse()
	for side: String in ARMS:
		var ids: Array = _bones[side]
		if -1 in ids:
			continue
		var target: Vector3 = to_sk * (holder.transform * (grips[side] * holder.scale))
		var pole: Vector3 = to_sk.basis * Vector3(1.0 if side == "l" else -1.0, -0.2, -1.0)
		_reach(sk, ids, target, pole.normalized())


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
