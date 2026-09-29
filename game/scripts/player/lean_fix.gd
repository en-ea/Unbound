extends SkeletonModifier3D
## Straightens the upper body a little after the animation: the library's jog and sprint bend the
## torso far forward (about 27 and 40 degrees). `amount` (degrees) is spread over the three spine
## bones, tipping them back around the character's side-to-side axis. Set by CharacterVisual.

const SPINE := ["spine_01", "spine_02", "spine_03"]

var amount := 0.0
var _bones: Array[int] = []


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or amount < 0.1:
		return
	if _bones.is_empty():
		for b: String in SPINE:
			_bones.append(sk.find_bone(b))
	var tip := Basis(Vector3.RIGHT, -deg_to_rad(amount) / SPINE.size())
	for i in _bones:
		if i < 0:
			continue
		var pose := sk.get_bone_global_pose(i)
		pose.basis = tip * pose.basis
		sk.set_bone_global_pose(i, pose)
