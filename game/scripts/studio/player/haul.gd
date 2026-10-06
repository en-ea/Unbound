extends Node
## Hauling a body the way its size asks (plan LIVELY-VILLAGE 1.3; his note 230032: "dragging is visually wrong and
## PAINFULLY slow. would be better if some things are dragged and some carried on his shoulders"). The logic behind
## five marked lines in Enea's files:
##   hauling.gd start_carry   Haul.start(player, body): a wolf or a stag goes on the shoulders, the rest is dragged
##                            forward on a rope over the right shoulder; he walks facing the way he goes
##   hauling.gd _walk_normally  Haul.stop(player)
##   player.gd (speed)        free_speed := target_speed, before his drag's cap (1.3 m/s, Balance.HUNT), then
##                            target_speed = Haul.pace(player, target_speed, heave, free_speed): carried PACE.carry,
##                            dragged PACE.drag (the Duskmaw PACE.duskmaw), a heave in each step while dragging
##   player.gd (facing)       if Haul.walk(player, dir, strength, speed, delta): return - facing the way he goes, the
##                            jog or walk at the pace he makes
##   carcass.gd (the rope)    a body on the shoulders skips the rope's pull (and stays `dragged`: a wolf's _find_meal
##                            skips dragged bodies)
## A node of its own under the player while he hauls (STUDIO_HAUL): it lays a carried body across his shoulders each
## frame, after his animation, and holds his arms to the load (haul_pose.gd).
const CARRIED := ["wolf", "stag"]
const PACE := {"carry": 3.6, "drag": 2.6, "duskmaw": 1.9}     # m/s at a full stick (his walk 1.6, his run 5.4)
const NODE := "StudioHaul"
const POSE := preload("res://scripts/studio/player/haul_pose.gd")
## The load's middle from spine_03 (up, and a little behind), his frame; the stag's bigger body lower and further back,
## so his head stays clear of it (the look board, 2 Oct).
const SHOULDER := {"wolf": Vector3(0.0, 0.22, -0.06), "stag": Vector3(0.0, 0.1, -0.16)}

var player: Node3D
var body: Node3D
var how := "drag"
var _pose: SkeletonModifier3D


static func start(the_player: Node3D, the_body: Node3D) -> void:
	stop(the_player)
	var h: Node = load("res://scripts/studio/player/haul.gd").new()
	h.name = NODE
	h.player = the_player
	h.body = the_body
	h.how = "carry" if str(the_body.get("kind")) in CARRIED else "drag"
	h.process_priority = 100                    # (after his animation and his own placing of the body)
	the_player.add_child(h)
	var visual: Node3D = the_player.get("visual")
	visual.set("walk_anim", "")                 # forward, not the backward push
	visual.set("walk_backward", false)
	h._pose = POSE.new()
	h._pose.visual = visual
	h._pose.how = h.how
	(visual.get("_skeleton") as Skeleton3D).add_child(h._pose)
	the_player.get_tree().call_group("hud", "hint", "On your shoulders: Drop to let go." if h.how == "carry"
		else "Dragging it: Drop to let go.")


static func stop(the_player: Node3D) -> void:
	var h := the_player.get_node_or_null(NODE)
	if h != null:
		if is_instance_valid(h._pose):
			h._pose.queue_free()
		the_player.remove_child(h)
		h.queue_free()


static func hauling(the_player: Node3D) -> Node:
	return the_player.get_node_or_null(NODE)


## The pace he can make hauling: `free` is player.gd's target speed for the stick before the drag's cap (a full or part
## stick); `capped` what the cap made of it, kept when nothing of ours is hauled.
static func pace(the_player: Node3D, capped: float, heave: float, free: float) -> float:
	var h := hauling(the_player)
	if h == null:
		return capped
	if h.how == "carry":
		return minf(free, PACE.carry)
	var most: float = PACE.duskmaw if str(h.body.get("kind")) == "duskmaw" else PACE.drag
	return minf(free, most) * (0.8 + 0.4 * heave * heave)       # (heave and step: a surge as each foot plants)


## He faces the way he goes and plays the walk or jog his pace makes. -> true: done (player.gd returns).
static func walk(the_player: Node3D, dir: Vector3, strength: float, speed: float, delta: float, turn_speed: float) -> bool:
	if hauling(the_player) == null:
		return false
	var visual: Node3D = the_player.get("visual")
	if strength > 0.1 and dir.length() > 0.1:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(dir.x, dir.z), clampf(turn_speed * 0.7 * delta, 0.0, 1.0))
	visual.call("play_motion", speed if strength > 0.1 else 0.0)
	return true


## The body is on someone's shoulders (carcass.gd skips the rope then).
static func on_shoulders(the_body: Node3D) -> bool:
	return the_body.get_meta("on_shoulders", false)


func _ready() -> void:
	if how == "carry":
		body.set_meta("on_shoulders", true)


func _exit_tree() -> void:
	if is_instance_valid(body) and body.has_meta("on_shoulders"):
		body.remove_meta("on_shoulders")
		var shape = body.get("shape")
		if shape != null:                            # set down on the ground where he stands
			var p := body.global_position
			body.global_position = Vector3(p.x, shape.height_at(p.x, p.z), p.z)
			body.rotation = Vector3(0.0, body.rotation.y, 0.0)


func _process(_delta: float) -> void:
	if how != "carry" or not is_instance_valid(body) or not is_instance_valid(player):
		return
	var visual: Node3D = player.get("visual")
	var sk: Skeleton3D = visual.get("_skeleton")
	var spine := sk.find_bone("spine_03")
	if spine < 0:
		return
	# across his shoulders: the body's length along his left-right, its back up, its middle on spine_03
	var bone := sk.global_transform * sk.get_bone_global_pose(spine)
	var frame := Basis(Vector3.UP, visual.global_rotation.y)
	var at := bone.origin + frame * (SHOULDER.get(str(body.get("kind")), SHOULDER.wolf) as Vector3)
	var across := Basis(Vector3.UP, visual.global_rotation.y + PI * 0.5)
	body.global_transform = Transform3D(across, at - across * Vector3(0.0, 0.0, 0.0))
