extends Node
## The player's body, measured headless for his notes (plan LIVELY-VILLAGE sections 1.1 and 1.3). A measure only: it
## changes nothing but where the player stands and what the stick says.
##
##   --body-probe=sword   SWORD <json>: where the back sword sits against the torso, in the body's own frame (rest
##                        pose: the sword rides on spine_03, so its place against the chest is the same in every pose)
##                          forward_of_back   metres the blade's most forward point is in front of the back's surface
##                                            (> 0: into or in front of the body; behind the back: below 0)
##                          blade_f / blade_r / blade_u   its extent forward, to the right and up from spine_03
##                          back_f / chest_f  the torso's back and chest surfaces (a slice at chest height)
##                          verdict          "behind the back" | "through the body" | "in front"
##                          clearance_min/max the blade's distance behind the body's back surface where it lies against
##                                           it (each blade vertex against the back-most body vertex within NEAR_RU);
##                                           inside_body: blade vertices in front of that surface; thickness_f
##                          spine_gap_max    the widest gap where it crosses the middle of the back (within SPINE_R)
##                          done             plan 1.1: none inside, 0.01 m clear or more, 0.12 m or less off the middle
##                                           of the back, 0.08 m thick or less
##   --body-probe=stick:<x>,<y>[:<s>]  no measure: the stick held there every frame (a look board of his walk or run),
##                        or for <s> seconds, then let go (he stands, turned that way: a look from behind)
##   --body-probe=haul    HAUL <json> a kind: each carcass kind taken and walked north 15 s on a full stick
##                          speed_mps      metres a second over the last 10 s, along his path (straight_mps: the
##                                         line from where he was to where he is; a villager or a creature crossing
##                                         may turn him)
##                          facing         the body's facing against the way of travel (1 forward, -1 backwards)
##                          clip           what the body plays
##   --body-probe=haul_look:<kind>[:<x>,<y>]  no measure: a body of that kind taken and the stick held there (default
##                        east: seen from the side), for a look board with --shot
##   --body-probe=haul_time  HAUL <json> a kill site: from each meadow home of a carried kind (the wolves' and stags',
##                        enemies.gd) to the butcher's rack with a wolf on his shoulders, the stick held toward the
##                        rack and turned round what stands in the way (steer_around.gd, as the creatures go); the
##                        meadow's creatures are taken away first (a walk measured, not a fight)
##                          seconds / metres   until he is within the rack's reach (butcher.gd); straight_m the line
##                          then HAUL {"haul_time_median_s": ...}: plan 1.3's haul time (35 s or less)
## Then BODY complete.
const KINDS := ["wolf", "stag", "boar", "shadow_wolf", "duskmaw"]
const NEAR_RU := 0.05        # metres sideways and up: the body "behind" a blade vertex
const TORSO_U := Vector2(-0.45, 0.2)   # metres up from spine_03: the back the sword lies against (hips to shoulders)
const SPINE_R := 0.1         # metres either side of the spine: where it must lie close (the shoulder's side rounds away)
const CARCASS := preload("res://scripts/world/carcass.gd")
const ENEMIES := preload("res://scripts/creatures/enemies.gd")
const BUTCHER := preload("res://scripts/world/butcher.gd")
const STEER := preload("res://scripts/studio/creatures/steer_around.gd")
const RACK_REACH := 3.4      # metres: butcher.gd's reach (Sell)
const HAUL_LIMIT_S := 120.0

var _mode := ""


var _stick := Vector2.INF     # --body-probe=stick:<x>,<y>[:<s>]: the stick held there every frame (a look board's walk
var _stick_for := INF         # or run), or for <s> seconds and then let go (he stands facing that way)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--body-probe="):
			_mode = arg.trim_prefix("--body-probe=")
	if _mode.begins_with("haul_look:"):
		_haul_look.call_deferred()
		return
	if _mode.begins_with("stick:"):
		var bits := _mode.trim_prefix("stick:").split(":")
		var xy := bits[0].split(",")
		_stick = Vector2(float(xy[0]), float(xy[1]))
		if bits.size() > 1:
			_stick_for = float(bits[1])
		return                                   # (an input only: the shot's own --shot quits)
	_run.call_deferred()


func _process(delta: float) -> void:
	if _stick != Vector2.INF:
		_stick_for -= delta
		Controls.joystick = _stick if _stick_for > 0.0 else Vector2.ZERO


func _run() -> void:
	for _i in 30:
		await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		print("BODY FAIL no player")
		print("BODY complete")
		return
	if _mode == "sword" or _mode == "all":
		_sword(player)
	if _mode == "haul" or _mode == "all":
		await _haul(player)
	if _mode == "haul_time" or _mode == "all":
		await _haul_time(player as CharacterBody3D)
	print("BODY complete")
	get_tree().quit()


# ---------- the back sword ----------

func _sword(player: Node3D) -> void:
	var visual: Node3D = player.get("visual")
	var skeleton: Skeleton3D = visual.get("_skeleton")
	var back: Node3D = visual.get("_back")
	var anim: AnimationPlayer = visual.get("_anim")
	if skeleton == null or back == null:
		print("SWORD %s" % JSON.stringify({"error": "no skeleton or no back sword"}))
		return
	visual.call("show_tool", "")                 # (the back sword shows when the hand is empty)
	if anim != null:
		anim.stop()
	skeleton.reset_bone_poses()                  # the rest pose: the skinned meshes stand as their vertices say
	skeleton.force_update_all_bone_transforms()
	for att: BoneAttachment3D in skeleton.find_children("*", "BoneAttachment3D", true, false):
		att.on_skeleton_update()                 # (the back sword's bone, at rest too: not the last frame's pose)
	var frame := visual.global_transform
	var to_local := frame.affine_inverse()
	var bone := func(name: String) -> Vector3:
		var i := skeleton.find_bone(name)
		return to_local * (skeleton.global_transform * skeleton.get_bone_global_pose(i)).origin if i >= 0 else Vector3.ZERO
	var foot: Vector3 = (bone.call("foot_l") + bone.call("foot_r")) * 0.5
	var ball: Vector3 = (bone.call("ball_l") + bone.call("ball_r")) * 0.5
	var forward := Vector3(ball.x - foot.x, 0.0, ball.z - foot.z).normalized()
	var right := forward.cross(Vector3.UP)
	var spine: Vector3 = bone.call("spine_03")
	var rel := func(p: Vector3) -> Vector3:      # (forward, right, up) from spine_03
		var d := p - spine
		return Vector3(d.dot(forward), d.dot(right), d.y)
	# the torso: every vertex of the body's own meshes (not the tools on the hands or back) within a slice round the
	# chest
	var slice: Array = []
	var meshes := {}
	for mi: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
		if _under_attachment(mi, visual) or mi.mesh == null or not mi.is_visible_in_tree():
			continue                           # (every outfit's parts are there; only the worn ones show)
		var to_visual := to_local * mi.global_transform
		for s in mi.mesh.get_surface_count():
			var verts: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for v in verts:
				var q: Vector3 = rel.call(to_visual * v)
				if absf(q.y) < 0.1 and q.z > -0.25 and q.z < 0.1:
					slice.append(q.x)
					meshes[str(mi.name)] = int(meshes.get(str(mi.name), 0)) + 1
	slice.sort()
	var pct := func(f: float) -> float: return float(slice[clampi(int(f * slice.size()), 0, slice.size() - 1)]) if not slice.is_empty() else 0.0
	# the torso's back and chest: the 3rd and 97th percentile of the slice (a strap or a buckle is not the body)
	var back_f: float = pct.call(0.03)
	var chest_f: float = pct.call(0.97)
	print("SWORD slice %s" % JSON.stringify({"n": slice.size(), "p1": snappedf(pct.call(0.01), 0.01), "p3": snappedf(back_f, 0.01),
		"p10": snappedf(pct.call(0.1), 0.01), "p50": snappedf(pct.call(0.5), 0.01), "p90": snappedf(pct.call(0.9), 0.01),
		"p97": snappedf(chest_f, 0.01), "p99": snappedf(pct.call(0.99), 0.01), "meshes": meshes}))
	# the blade: every vertex of the back sword's meshes; and against it, the body round each (the back's surface where
	# the blade lies: the back-most body vertex within NEAR_RU of it, sideways and up)
	var body_pts: Array = []
	for mi: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
		if _under_attachment(mi, visual) or mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var to_visual := to_local * mi.global_transform
		for s in mi.mesh.get_surface_count():
			for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				body_pts.append(rel.call(to_visual * v))
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	var clear_min := INF
	var gap_max := -INF
	var inside := 0
	var against := 0
	var blade_n := 0
	var profile: Array = []                      # [up, right, forward, clearance] of each blade vertex against the back
	var spine_gap := -INF                        # the widest gap where it crosses the middle of the back
	for mi: MeshInstance3D in back.find_children("*", "MeshInstance3D", true, false) + ([back] if back is MeshInstance3D else []):
		var to_visual := to_local * mi.global_transform
		for s in mi.mesh.get_surface_count():
			for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				var q: Vector3 = rel.call(to_visual * v)
				blade_n += 1
				lo = lo.min(q)
				hi = hi.max(q)
				if q.z < TORSO_U.x or q.z > TORSO_U.y:
					continue                           # (above the shoulders the handle rises clear by the neck)
				var back_here := INF
				for b: Vector3 in body_pts:
					if absf(b.y - q.y) < NEAR_RU and absf(b.z - q.z) < NEAR_RU:
						back_here = minf(back_here, b.x)
				if back_here == INF:
					continue                       # (beside the body: nothing to touch)
				against += 1
				var clear := back_here - q.x            # > 0: behind the back's surface there
				profile.append([snappedf(q.z, 0.01), snappedf(q.y, 0.01), snappedf(q.x, 0.01), snappedf(clear, 0.01)])
				clear_min = minf(clear_min, clear)
				gap_max = maxf(gap_max, clear)
				if absf(q.y) <= SPINE_R:
					spine_gap = maxf(spine_gap, clear)
				if clear < 0.0:
					inside += 1
	var verdict := "behind the back" if inside == 0 and clear_min >= 0.01 else ("in front" if lo.x > chest_f else "through the body")
	print("SWORD %s" % JSON.stringify({"forward_axis": [snappedf(forward.x, 0.01), snappedf(forward.z, 0.01)],
		"spine_03_height": snappedf(spine.y, 0.01), "back_f": snappedf(back_f, 0.01), "chest_f": snappedf(chest_f, 0.01),
		"blade_f": [snappedf(lo.x, 0.01), snappedf(hi.x, 0.01)], "blade_r": [snappedf(lo.y, 0.01), snappedf(hi.y, 0.01)],
		"blade_u": [snappedf(lo.z, 0.01), snappedf(hi.z, 0.01)], "forward_of_back": snappedf(hi.x - back_f, 0.01),
		"thickness_f": snappedf(hi.x - lo.x, 0.01), "vertices": blade_n, "against_body": against, "inside_body": inside,
		"clearance_min": snappedf(clear_min, 0.01) if clear_min < INF else null,
		"clearance_max": snappedf(gap_max, 0.01) if gap_max > -INF else null,
		"spine_gap_max": snappedf(spine_gap, 0.01) if spine_gap > -INF else null,
		"done": inside == 0 and clear_min >= 0.01 and spine_gap <= 0.12 and hi.x - lo.x <= 0.08,
		"verdict": verdict}))
	profile.sort_custom(func(a: Array, b: Array) -> bool: return float(a[3]) > float(b[3]))
	print("SWORD widest gaps %s" % JSON.stringify(profile.slice(0, 8)))
	print("SWORD nearest %s" % JSON.stringify(profile.slice(profile.size() - 6)))
	_sword_poses(visual, skeleton, back, anim, rel)
	if anim != null:
		anim.play("Idle")


## The same clearance through his motions (the body skinned on the CPU at each pose; the sword is rigid on spine_03, so
## both are taken into spine_03's rest frame, where the sword stands as at rest and the body bends round it).
## SWORD POSES {pose: {inside, clearance_min, spine_gap}}, then the worst.
func _sword_poses(visual: Node3D, skeleton: Skeleton3D, back: Node3D, anim: AnimationPlayer, rel: Callable) -> void:
	if anim == null:
		return
	var spine := skeleton.find_bone("spine_03")
	var to_local := visual.global_transform.affine_inverse()
	var skel_to_visual := to_local * skeleton.global_transform
	# the sword in the rest frame: its vertices as the rest measure saw them
	var blade: Array = []
	for mi: MeshInstance3D in back.find_children("*", "MeshInstance3D", true, false) + ([back] if back is MeshInstance3D else []):
		var to_visual := to_local * mi.global_transform
		for s in mi.mesh.get_surface_count():
			for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				var q: Vector3 = rel.call(to_visual * v)
				if q.z >= TORSO_U.x and q.z <= TORSO_U.y:
					blade.append(q)
	var bodies: Array = []
	for mi: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
		if not _under_attachment(mi, visual) and mi.mesh != null and mi.is_visible_in_tree() and mi.skin != null:
			bodies.append(mi)
	var out := {}
	var worst := {"clearance_min": INF, "pose": ""}
	for pose: String in ["Rest", "Idle", "Walk", "Jog_Fwd", "Sprint"]:
		if pose != "Rest" and not anim.has_animation(pose):
			continue
		var length := anim.get_animation(pose).length if pose != "Rest" else 0.0
		for phase: float in ([0.0] if pose == "Rest" else [0.0, 0.25, 0.5, 0.75]):
			if pose == "Rest":                  # (the skinning checked against the rest measure above)
				anim.stop()
				skeleton.reset_bone_poses()
			else:
				anim.play(pose)
				anim.seek(length * phase, true)
			skeleton.force_update_all_bone_transforms()
			# posed skeleton space -> spine_03 at rest (skeleton space) -> visual space -> (forward, right, up)
			var to_rest := skeleton.get_bone_global_rest(spine) * skeleton.get_bone_global_pose(spine).affine_inverse()
			var pts: Array = []
			for mi: MeshInstance3D in bodies:
				for v: Vector3 in _skinned(mi, skeleton):
					pts.append(rel.call(skel_to_visual * (to_rest * v)))
			var clear_min := INF
			var spine_gap := -INF
			var inside := 0
			for q: Vector3 in blade:
				var back_here := INF
				for b: Vector3 in pts:
					if absf(b.y - q.y) < NEAR_RU and absf(b.z - q.z) < NEAR_RU:
						back_here = minf(back_here, b.x)
				if back_here == INF:
					continue
				var clear := back_here - q.x
				clear_min = minf(clear_min, clear)
				if absf(q.y) <= SPINE_R:
					spine_gap = maxf(spine_gap, clear)
				if clear < 0.0:
					inside += 1
			var key := "%s@%.2f" % [pose, phase]
			out[key] = {"inside": inside, "clearance_min": snappedf(clear_min, 0.01), "spine_gap": snappedf(spine_gap, 0.01)}
			if clear_min < float(worst.clearance_min):
				worst = {"clearance_min": snappedf(clear_min, 0.01), "pose": key, "inside": inside}
	print("SWORD POSES %s" % JSON.stringify(out))
	print("SWORD POSES WORST %s" % JSON.stringify(worst))


## A skinned mesh's vertices at the skeleton's current pose, in the skeleton's space (as the renderer has them:
## the sum of weight * bone's global pose * bind pose * vertex).
static func _skinned(mi: MeshInstance3D, skeleton: Skeleton3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	var skin := mi.skin
	var mats: Array[Transform3D] = []
	for i in skin.get_bind_count():
		var b := skin.get_bind_bone(i)
		if b < 0:
			b = skeleton.find_bone(skin.get_bind_name(i))
		mats.append(skeleton.get_bone_global_pose(b) * skin.get_bind_pose(i) if b >= 0 else Transform3D.IDENTITY)
	for s in mi.mesh.get_surface_count():
		var arrays := mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones = arrays[Mesh.ARRAY_BONES]
		var weights = arrays[Mesh.ARRAY_WEIGHTS]
		if bones == null or weights == null or (bones as PackedInt32Array).is_empty():
			out.append_array(verts)
			continue
		var per := (bones as PackedInt32Array).size() / verts.size()
		for i in verts.size():
			var p := Vector3.ZERO
			for j in per:
				var w: float = weights[i * per + j]
				if w > 0.0:
					p += (mats[bones[i * per + j]] * verts[i]) * w
			out.append(p)
	return out


func _under_attachment(n: Node, stop: Node) -> bool:
	var p := n.get_parent()
	while p != null and p != stop:
		if p is BoneAttachment3D:
			return true
		p = p.get_parent()
	return false


# ---------- a look at a haul ----------

func _haul_look() -> void:
	for _i in 30:
		await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player") as Node3D
	for c: Node in get_tree().get_nodes_in_group("enemy"):
		c.queue_free()                               # (a walk to look at, not a fight)
	var bits := _mode.trim_prefix("haul_look:").split(":")
	var kind := bits[0]
	_stick = Vector2(1.0, 0.0)
	if bits.size() > 1:
		var xy := bits[1].split(",")
		_stick = Vector2(float(xy[0]), float(xy[1]))
	var body: Node3D = CARCASS.spawn(player.get_parent(), kind, player.global_position - Vector3(_stick.x, 0.0, _stick.y) * 1.5, 0.0, player)
	for _i in 3:
		await get_tree().physics_frame
	player.get("hauling").call("start_carry", body)


# ---------- the haul time ----------

func _haul_time(player: CharacterBody3D) -> void:
	var hauling: Node = player.get("hauling")
	var shape := WorldShape.new()
	for c: Node in get_tree().get_nodes_in_group("enemy"):
		c.queue_free()
	var sites: Array = []
	for key: String in ["wolves", "stags"]:
		sites.append_array(ENEMIES.HOMES["meadow"][key])
	var times: Array = []
	for site: Vector2 in sites:
		player.global_position = Vector3(site.x, shape.height_at(site.x, site.y) + 0.1, site.y)
		player.velocity = Vector3.ZERO
		var body: Node3D = CARCASS.spawn(player.get_parent(), "wolf", player.global_position + Vector3(0, 0, 1.0), 0.0, player)
		for _i in 5:
			await get_tree().physics_frame
		hauling.call("start_carry", body)
		var t := 0.0
		var walked := 0.0
		var last := player.global_position
		var arrived := false
		while t < HAUL_LIMIT_S:
			await get_tree().physics_frame
			var dt := get_physics_process_delta_time()
			t += dt
			var p := player.global_position
			walked += Vector2(p.x - last.x, p.z - last.z).length()
			last = p
			var to := Vector3(BUTCHER.AT.x - p.x, 0.0, BUTCHER.AT.y - p.z)
			if to.length() <= RACK_REACH:
				arrived = true
				break
			var want := STEER.steer(player, to.normalized() * 3.6, dt)
			Controls.cam_yaw = 0.0
			Controls.joystick = Vector2(want.x, want.z).normalized()
		Controls.joystick = Vector2.ZERO
		if arrived:
			times.append(t)
		print("HAUL %s" % JSON.stringify({"from": [site.x, site.y], "seconds": snappedf(t, 0.1) if arrived else -1.0,
			"metres": snappedf(walked, 0.1), "straight_m": snappedf(site.distance_to(BUTCHER.AT), 0.1), "arrived": arrived,
			"carried": hauling.get("carrying") != null and is_instance_valid(body) and body.get_meta("on_shoulders", false)}))
		hauling.call("drop")
		if is_instance_valid(body):
			body.queue_free()
		for _i in 5:
			await get_tree().physics_frame
	times.sort()
	var median: float = -1.0
	if times.size() == sites.size():
		median = (times[(times.size() - 1) / 2] + times[times.size() / 2]) * 0.5
	print("HAUL %s" % JSON.stringify({"haul_time_median_s": snappedf(median, 0.1), "arrived": times.size(), "sites": sites.size(),
		"done": median >= 0.0 and median <= 35.0}))


# ---------- hauling a body ----------

func _haul(player: Node3D) -> void:
	var hauling: Node = player.get("hauling")
	var visual: Node3D = player.get("visual")
	for kind: String in KINDS:
		var start := Vector3(-30.0, 0.0, 60.0)
		start.y = WorldShape.new().height_at(start.x, start.z) + 0.1
		player.global_position = start
		player.set("velocity", Vector3.ZERO)
		var body: Node3D = CARCASS.spawn(player.get_parent(), kind, start + Vector3(0, 0, 1.5), 0.0, player)
		for _i in 5:
			await get_tree().physics_frame
		hauling.call("start_carry", body)
		Controls.cam_yaw = 0.0
		Controls.joystick = Vector2(0.0, -1.0)    # stick up: away from the camera (north, -z)
		var at5 := Vector3.ZERO
		var t := 0.0
		var facing_sum := 0.0
		var facing_n := 0
		var clip := ""
		var per_s: Array = []                      # metres each second (where a slowing is)
		var last_s := player.global_position
		var next_s := 1.0
		while t < 15.0:
			await get_tree().physics_frame
			t += get_physics_process_delta_time()
			if t >= next_s:
				per_s.append(snappedf(Vector2(player.global_position.x - last_s.x, player.global_position.z - last_s.z).length(), 0.1))
				last_s = player.global_position
				next_s += 1.0
			if t >= 5.0 and at5 == Vector3.ZERO:
				at5 = player.global_position
			var v: Vector3 = player.get("velocity")
			if t >= 5.0 and Vector2(v.x, v.z).length() > 0.2:
				var face := Vector3(sin(visual.rotation.y), 0.0, cos(visual.rotation.y))
				facing_sum += face.dot(Vector3(v.x, 0.0, v.z).normalized())
				facing_n += 1
			clip = str(visual.get("_current"))
		var moved := 0.0                           # the path he made over the last 10 s (something moving may turn him)
		for i in range(5, per_s.size()):
			moved += float(per_s[i])
		var straight := Vector2(player.global_position.x - at5.x, player.global_position.z - at5.z).length()
		Controls.joystick = Vector2.ZERO
		var need: float = 1.8 if kind == "duskmaw" else (3.5 if kind in ["wolf", "stag"] else 2.5)   # plan 1.3
		var facing := facing_sum / maxf(facing_n, 1.0)
		print("HAUL %s" % JSON.stringify({"kind": kind, "speed_mps": snappedf(moved / 10.0, 0.01), "straight_mps": snappedf(straight / 10.0, 0.01),
			"facing": snappedf(facing, 0.01), "clip": clip, "need_mps": need, "done": moved / 10.0 >= need and facing >= 0.9,
			"walk_anim": str(visual.get("walk_anim")), "backward": bool(visual.get("walk_backward")),
			"on_shoulders": is_instance_valid(body) and body.get_meta("on_shoulders", false), "per_s": per_s,
			"end": [snappedf(player.global_position.x, 0.1), snappedf(player.global_position.z, 0.1)]}))
		hauling.call("drop")
		if is_instance_valid(body):
			body.queue_free()
		for _i in 5:
			await get_tree().physics_frame
