extends Node
## A gathered crowd still moves and expresses smoothly however often each body's expression and steering are worked
## out (8240e48: every 3rd frame, staggered; the tuned head: on Body's Think beat, 0.1 s near, and steering at about
## 10 Hz, interpolated). The check reads nothing of the game's beat (no constant, no turn counter, no frame phase): a
## time-based beat under a real-time budget lands irregularly on a slow machine, so it judges what is drawn.
## Dev-only: nothing in the game calls it.
##
##   godot --rendering-driver opengl3 --fixed-fps 30 --path game --resolution 1560x720 -- --studio=village/live \
##     --merge-check=../render/crowd_motion_check --save-guard --test-save=<fresh> --crowd-out=<absolute dir>
##
## At midday up to 12 grown villagers are stood in a ring round the player, facing in; then one of them takes a blow
## (the people's door from the player's hand, a strike that does not knock down), and the ring reacts. For 90 frames
## from just before the blow, each ring body's head is read in the body's own space (VillagerBody.head_basis) every
## frame. The judgement, blind to the beat: of the frames the head moves on (a tenth of its mean turn a frame or more),
## the share that jump - turn more than JUMP times both neighbouring frames. A head refreshed on a beat and held
## between moves on its beat frames alone, each a jump (the share near 1); stepping on top of other motion, it jumps
## once a beat (1/3 at a 0.1 s beat at 30 fps, 1/6 at 60). Easing, a turn's start or its slow tail is never a jump.
## Under JUMPS passes (6 Oct: smooth heads 0.02 at worst on 8240e48 and on the tuned head; heads held 2 frames in 3
## 0.58-1.00, riding on a whole-body turn 0.06-0.27). (The mean turn in each of the 3 frame phases, largest over
## smallest, is reported too, not judged: it lines up with a 0.1 s beat only at exactly 30 fps.)
## The same for each ring body's own movement (its ground position frame by frame): a body steered on a slower clock
## without interpolation would move on its beat frames and stand between.
## Captures crowd-0..5.png, 0.2 s apart from the blow, from above the ring, the HUD hidden: the filmstrip board.
## Prints "PASS crowd ..." / "FAIL crowd ..." lines and "CROWD complete failures=N"; writes check.json.
const Contact := preload("res://scripts/studio/village/contact.gd")
const Rules := preload("res://scripts/studio/village/sim/village.gd")
const FRAMES := 90
const MOVING := 0.05            # degrees a frame: a head turning less than this on average is at rest, not judged
const WALKING := 0.004          # metres a frame (0.12 m/s at 30 fps): a body moving less is standing, not judged
const JUMPS := 0.1             # of the frames moved on, the share that jump: smooth 0.02 at worst, stepped 1/6 or more
const STILL := 0.1              # a frame moving less than this share of the series' mean is not moved on
const JUMP := 2.0               # a frame turning more than this many times each neighbour's turn is a jump

var out := ""
var failed := 0
var player: Node3D
var _report := {}


static func on_device(tree: SceneTree) -> void:
	if tree.root.has_node("CrowdMotionCheck"):
		return
	var check: Node = load("res://scripts/studio/render/crowd_motion_check.gd").new()
	check.name = "CrowdMotionCheck"
	tree.root.add_child.call_deferred(check)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--crowd-out="):
			out = arg.trim_prefix("--crowd-out=")
	if out != "":
		DirAccess.make_dir_recursive_absolute(out)
	run.call_deferred()


func check(ok: bool, text: String) -> void:
	print(("PASS crowd " if ok else "FAIL crowd ") + text)
	if not ok:
		failed += 1


func frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout


func run() -> void:
	await frames(120)
	var res: Node = null
	for _i in 900:
		res = Contact.registry(get_tree())
		if res != null and VillageSession.village != null and VillageSession.active and res.call("all_built") \
				and get_tree().get_first_node_in_group("player") != null:
			break
		await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	var v = VillageSession.village
	WorldClock.advance_to_time(0.5)
	await seconds(3.0)
	# The ring: grown villagers who can be stood (as storm_crowd_check stands its crowd).
	var people := []
	for id: int in res.bodies:
		var p = v.people[id]
		if p.alive and p.present and p.authored == "" and Rules.age_of(v, p) >= 14:
			people.append(id)
	var centre := Vector2(player.global_position.x, player.global_position.z)
	var trial := centre + Vector2(3.0, 0.0)
	var spots := {}
	for i in people.size():
		spots[people[i]] = trial + Vector2(float(i % 6), float(i / 6)) * 1.5
		res._movers[people[i]].place(spots[people[i]], 0.0)
	await frames(30)
	var ring := []
	for id: int in people:
		var body: Node3D = res.bodies[id]
		if Vector2(body.global_position.x, body.global_position.z).distance_to(spots[id]) <= 2.0 and ring.size() < 12:
			ring.append(id)
	for i in ring.size():
		var a := TAU * float(i) / float(ring.size())
		var r := 2.2 + 1.2 * float(i % 3)
		res._movers[ring[i]].place(centre + Vector2(cos(a), sin(a)) * r, a + PI)
	check(ring.size() >= 8, "a crowd of %d villagers stood round the player" % ring.size())
	if ring.size() < 2:
		_finish()
		return
	await seconds(2.0)
	var cam := Camera3D.new()
	cam.fov = 50.0
	get_tree().current_scene.add_child(cam)
	var game_cam := get_viewport().get_camera_3d()
	# Record: every frame, each ring body's head in its own body space; the blow lands a few frames in.
	var target: int = ring[0]
	var heads := {}
	var roots := {}
	for id: int in ring:
		heads[id] = []
		roots[id] = []
	# The first head read connects the keeper of the drawn final pose (VillagerBody.head_forward); until then a read
	# gives the animation's pose without the head's own motion (6 Oct: a 66-74 degree "turn" from the first sample).
	for id: int in ring:
		(res.bodies[id] as Node3D).call("head_basis")
	await get_tree().process_frame
	var shots := 0
	var hud: CanvasLayer = get_tree().current_scene.get_node("HUD")
	for f in FRAMES:
		if f == 5:
			Contact.perform(get_tree(), Contact.actor_of(player), player, "strike", {"press_id": "crowd:blow", "damage": 1, "force": 450},
				player.global_position, 6.0, Vector3.ZERO, target)
		await get_tree().process_frame
		for id: int in ring:
			var b: Node3D = res.bodies[id]
			heads[id].append((b.global_basis.inverse() * (b.call("head_basis") as Basis)).get_rotation_quaternion())
			roots[id].append(b.global_position)
		if f >= 6 and (f - 6) % 6 == 0 and shots < 6 and out != "" and DisplayServer.get_name() != "headless":
			cam.global_position = Vector3(centre.x, player.global_position.y + 7.5, centre.y + 6.5)
			cam.look_at(Vector3(centre.x, player.global_position.y + 0.8, centre.y))
			cam.current = true
			hud.visible = false
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out.path_join("crowd-%d.png" % shots))
			shots += 1
			hud.visible = true
			if game_cam != null:
				game_cam.current = true
	# Per body: the head's turn a frame, the share of its moving frames that jump, and its frame phases.
	var judged := 0
	var even := 0
	var ratios := []
	var jumps := []
	var rows := {}
	var walkers := 0
	var walk_even := 0
	var walk_ratios := []
	var walk_jumps := []
	for id: int in ring:
		var q: Array = heads[id]
		var turn_by: Array[float] = []
		for f in range(1, q.size()):
			turn_by.append(rad_to_deg((q[f - 1] as Quaternion).angle_to(q[f])))
		var head := _phases(turn_by, func(f: int) -> int: return f % 3)
		var head_jumps := _jumps(turn_by)
		# The body's own movement, frame by frame (steering on a slower clock without interpolation would show the
		# same way: moving on its beat frames, standing between).
		var p: Array = roots[id]
		var step_by: Array[float] = []
		for f in range(1, p.size()):
			var d: Vector3 = (p[f] as Vector3) - (p[f - 1] as Vector3)
			step_by.append(Vector2(d.x, d.z).length())
		var walk := _phases(step_by, func(f: int) -> int: return f % 3)
		var walk_jump := _jumps(step_by)
		rows[id] = {"head_deg": head.mean, "head_phases": head.means, "head_ratio": head.ratio, "head_jumps": head_jumps,
			"step_m": walk.mean, "step_phases": walk.means, "step_ratio": walk.ratio, "step_jumps": walk_jump,
			"head_turn_by_frame": turn_by, "step_by_frame": step_by}
		if head.mean >= MOVING:
			judged += 1
			ratios.append(head.ratio)
			jumps.append(head_jumps)
			if head_jumps < JUMPS:
				even += 1
		if walk.mean >= WALKING:
			walkers += 1
			walk_ratios.append(walk.ratio)
			walk_jumps.append(walk_jump)
			if walk_jump < JUMPS:
				walk_even += 1
	_report["ring"] = rows
	_report["walkers"] = walkers
	check(judged >= 4, "the ring reacts: %d of %d heads turning (at least %.2f degrees a frame on average)" % [judged, ring.size(), MOVING])
	check(judged > 0 and even == judged, "every turning head moves frame by frame, no step: %d of %d (share of moving frames that jump: median %s, worst %s, under %.2f; a 0.1 s step 1/3 or more) [3-frame phases, not judged: median %s, worst %s]" % [
		even, judged, _mid(jumps), _worst(jumps), JUMPS, _mid(ratios), _worst(ratios)])
	check(walk_even == walkers, "every moving body moves frame by frame, no step: %d of %d moving (share of moving frames that jump: median %s, worst %s, under %.2f) [3-frame phases, not judged: median %s, worst %s]" % [
		walk_even, walkers, _mid(walk_jumps), _worst(walk_jumps), JUMPS, _mid(walk_ratios), _worst(walk_ratios)])
	_finish()


## Of the frames moved on (STILL of the series' mean or more), the share that jump: more than JUMP times both
## neighbouring frames. A series refreshed on a beat and held between moves on its beat frames alone, each a jump.
func _jumps(series: Array[float]) -> float:
	var mean := 0.0
	for x: float in series:
		mean += x
	mean /= maxf(1.0, float(series.size()))
	var moved := 0
	var jumped := 0
	for f in series.size():
		if series[f] < STILL * mean:
			continue
		moved += 1
		if f > 0 and f < series.size() - 1 and series[f] > JUMP * maxf(series[f - 1], series[f + 1]):
			jumped += 1
	return float(jumped) / maxf(1.0, float(moved))


func _mid(values: Array) -> String:
	if values.is_empty():
		return "-"
	var sorted := values.duplicate()
	sorted.sort()
	return "%.2f" % float(sorted[sorted.size() / 2])


func _worst(values: Array) -> String:
	return "-" if values.is_empty() else "%.2f" % float(values.max())


## Mean of a per-frame series in each of 3 phases (phase_of(frame index)), the overall mean, largest over smallest.
func _phases(series: Array[float], phase_of: Callable) -> Dictionary:
	var sums: Array[float] = [0.0, 0.0, 0.0]
	var counts: Array[int] = [0, 0, 0]
	for f in series.size():
		var k: int = phase_of.call(f)
		sums[k] += series[f]
		counts[k] += 1
	var means: Array[float] = []
	for k in 3:
		means.append(sums[k] / maxf(1.0, float(counts[k])))
	var mean_all: float = (sums[0] + sums[1] + sums[2]) / maxf(1.0, float(counts[0] + counts[1] + counts[2]))
	var hi: float = means.max()
	var lo: float = means.min()
	return {"means": means, "mean": mean_all, "ratio": hi / maxf(0.000001, lo)}


func _finish() -> void:
	var f := FileAccess.open(out.path_join("check.json"), FileAccess.WRITE) if out != "" else null
	if f != null:
		f.store_string(JSON.stringify(_report, "  "))
		f.close()
	print("CROWD complete failures=%d" % failed)
	get_tree().quit(1 if failed > 0 else 0)
