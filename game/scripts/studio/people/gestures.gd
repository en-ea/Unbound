extends RefCounted
## The people's shared physical vocabulary (B6/B8; the animation specialist's): where Enea's UAL clips put a body, and
## the pose shapes the visual elements (people/elements/) post through Body's port. Data and pure functions only: no
## state, no truth lookup, nothing saved, nothing chosen. Elements compose these into their own named layers, which
## villager_body.apply_elements is the one consumer of.
##
## Clip placements, measured on the rig (plan/PEOPLE-ANIMATION-BUILD-2026-10-03.md):
##   fall   Hit_Knockback from 0.1 s (frame 0 is a crouch) to 0.6 s, settled on the back 0.15 m behind
##   lie    LayToIdle at 0: flat on the back, the knockback's last pose (pelvis 0.24 m in both)
##   rise   LayToIdle from 0.45 s (sitting up) to its end standing; pain slows its squat (0.75-1.05 s)
##   die    Death01 to 2.35 s: knees buckle 0-0.6 s, down by 1.0 s, still after
##   hit    Hit_Chest 0.33 s / Hit_Head 0.43 s, feet planted
## Body space for reaches: +z forward, +x the body's own left, metres (pose.gd).

const FALL_CLIP := "Hit_Knockback"
const FALL_FROM := 0.1
const FALL_TO := 0.6
const LIE_CLIP := "LayToIdle"
const LIE_AT := 0.0
const RISE_FROM := 0.45
const RISE_TO := 1.5
const SQUAT := Vector2(0.75, 1.05)
const DIE_CLIP := "Death01"
const DIE_DOWN := 1.0
const DIE_TO := 2.35
const HIT_CHEST := "Hit_Chest"
const HIT_HEAD := "Hit_Head"
const LYING := ["down", "carried", "dead"]


## A value as 0..1, whether it came as 0..1 or as a saved 0..1000 strength.
static func unit(value: Variant) -> float:
	var v := float(value)
	return clampf(v / 1000.0 if v > 1.0 else v, 0.0, 1.0)


## A hand (or two) to the hurt place, how much by strength k 0..1: chest, belly, head, arm, leg, or burn (raw arms held
## off the body, trembling). Anything else reads as the chest.
static func clutch(where: String, k: float) -> Dictionary:
	var both := k >= 0.6
	match where:
		"head":
			return {"reach_r": {"bone": "Head", "at": Vector3(-0.1, 0.07, 0.06), "pole": Vector3(-0.8, 0.0, 0.3), "priority": 1},
				"head": Vector3(0.18 * k, -0.15 * k, 0.0), "spine": Vector3(0.12 * k, 0.0, 0.0), "shoulders": 0.06 * k}
		"leg":
			return {"reach_r": {"bone": "thigh_r", "at": Vector3(0.0, -0.15, 0.1), "priority": 1},
				"spine": Vector3(0.14 * k, -0.05, 0.0), "breath": Vector2(0.7 + 0.4 * k, 0.025)}
		"arm":
			return {"reach_r": {"bone": "upperarm_l", "at": Vector3(0.0, 0.12, 0.07), "pole": Vector3(-0.3, -0.6, 0.4), "priority": 1},
				"spine": Vector3(0.1 * k, 0.06 * k, 0.0), "shoulders": 0.08 * k}
		"belly", "gut":
			var gut := {"reach_l": {"bone": "spine_01", "at": Vector3(0.03, 0.02, 0.17), "priority": 1},
				"spine": Vector3(0.38 * k, 0.0, 0.0), "head": Vector3(0.2 * k, 0.0, 0.0), "breath": Vector2(0.9 + 0.4 * k, 0.03)}
			if both:
				gut["reach_r"] = {"bone": "spine_01", "at": Vector3(-0.05, 0.0, 0.17), "priority": 1}
			return gut
		"burn":
			return {"reach_l": {"bone": "spine_01", "at": Vector3(0.3, 0.0, 0.3), "pole": Vector3(0.7, -0.4, -0.2), "priority": 1},
				"reach_r": {"bone": "spine_01", "at": Vector3(-0.3, 0.0, 0.3), "pole": Vector3(-0.7, -0.4, -0.2), "priority": 1},
				"tremble": 0.025 * k, "shoulders": 0.12 * k, "spine": Vector3(0.15 * k, 0.0, 0.0),
				"breath": Vector2(1.0 + 0.6 * k, 0.035)}
	var chest := {"reach_l": {"bone": "spine_03", "at": Vector3(-0.02, -0.02, 0.17), "priority": 1},
		"spine": Vector3(0.3 * k, 0.0, 0.1 * k), "head": Vector3(0.2 * k, 0.0, 0.0), "breath": Vector2(0.8 + 0.4 * k, 0.03),
		"fist_l": 0.6 * k}
	if both:
		chest["reach_r"] = {"bone": "spine_02", "at": Vector3(0.04, 0.0, 0.18), "priority": 1}
	return chest


## On fire, by what the body is doing: upright (arms swatting, head thrown back), on the ground (thrashing, rolling) or
## held at the wrists (the free spine, head and legs struggle).
static func burning(mode: String, k: float) -> Dictionary:
	match mode:
		"ground":
			return {"flail": 0.6 * k, "writhe": 0.55 * k, "head": Vector3(-0.2, 0.0, 0.0), "breath": Vector2(2.0, 0.05),
				"tremble": 0.03}
		"held":
			return {"writhe": 0.4 * k, "head": Vector3(-0.4, 0.0, 0.0), "spine": Vector3(-0.12, 0.0, 0.0),
				"tremble": 0.05, "breath": Vector2(2.0, 0.05)}
	return {"flail": k, "head": Vector3(-0.35, 0.0, 0.0), "spine": Vector3(-0.1, 0.0, 0.0), "tremble": 0.04,
		"breath": Vector2(1.8, 0.04)}


## Breath and small life of a body lying hurt (k 0..1): a heaving chest, a knee drawn up, the head lifted off the ground.
static func lying(k: float) -> Dictionary:
	return {"breath": Vector2(0.8 + 0.5 * k, 0.04 + 0.03 * k), "knee_l": 0.35 + 0.3 * k, "head": Vector3(0.28, 0.0, 0.0),
		"writhe": 0.1 * k}


## The direction (world, flat) from a body to the point [x, z] a fact names; ZERO when there is none to speak of.
static func toward(body: Node3D, point: Variant) -> Vector3:
	if not (point is Array) or (point as Array).size() != 2:
		return Vector3.ZERO
	var d := Vector3(float(point[0]) - body.global_position.x, 0.0, float(point[1]) - body.global_position.z)
	return d.normalized() if d.length_squared() > 0.0025 else Vector3.ZERO


## A layer's `fields` with its element's clock: every layer carries its element's active seconds, so the body's
## visual clocks stand still exactly when Body's runner does (update(0)).
static func timed(fields: Dictionary, seconds: float) -> Dictionary:
	var out := fields.duplicate()
	out["clock"] = seconds
	return out
