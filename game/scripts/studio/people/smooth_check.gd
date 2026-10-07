extends Node
## Body 5's smoothness check (6 Oct tuning): a gathered crowd walking, measured frame by frame, so thinking less often
## is seen not to step. In the live village:
##   --studio=village/live --merge-check=../people/smooth_check --save-guard --test-save=<fresh> [--smooth-crowd=20]
##   [--smooth-shots=<absolute dir>]   (rendered: every 2nd frame of a second of it saved as PNGs for a board)
## At midday 20 grown villagers are stood round the player (as storm_crowd_check does) and let go: their day walks them
## off through each other. For 4 s, each frame: every body's ground step and its head's facing; and the animals'.
## A step is a frame whose ground step is over STEP_X times the mean of the frames either side (while walking), or a
## head turn of over TURN_DEG in one frame. Prints "SMOOTH ..." lines and "SMOOTH complete failures=N".
const Contact := preload("res://scripts/studio/village/contact.gd")
const Rules := preload("res://scripts/studio/village/sim/village.gd")
const STEP_X := 2.5
const TURN_DEG := 20.0      # degrees in one frame (a 30 fps frame): a snap; the untuned build's worst was 16.5
var failed := 0


static func on_device(tree: SceneTree) -> void:
	if tree.root.has_node("SmoothCheck"):
		return
	var probe: Node = load("res://scripts/studio/people/smooth_check.gd").new()
	probe.name = "SmoothCheck"
	tree.root.add_child.call_deferred(probe)


func _ready() -> void:
	run.call_deferred()


func check(ok: bool, text: String) -> void:
	print(("PASS smooth " if ok else "FAIL smooth ") + text)
	if not ok:
		failed += 1


func run() -> void:
	for _i in 120:
		await get_tree().process_frame
	var res: Node = null
	for _i in 900:
		res = Contact.registry(get_tree())
		if res != null and VillageSession.village != null and VillageSession.active and res.call("all_built") \
				and get_tree().get_first_node_in_group("player") != null:
			break
		await get_tree().process_frame
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var want := 20
	var shots := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--smooth-crowd="):
			want = int(arg.trim_prefix("--smooth-crowd="))
		if arg.begins_with("--smooth-shots="):
			shots = arg.trim_prefix("--smooth-shots=")
	var v = VillageSession.village
	WorldClock.advance_to_time(0.5)
	await get_tree().create_timer(3.0).timeout
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
	for _i in 30:
		await get_tree().process_frame
	var crowd := []
	for id: int in people:
		var body: Node3D = res.bodies[id]
		if Vector2(body.global_position.x, body.global_position.z).distance_to(spots[id]) <= 2.0 and crowd.size() < want:
			crowd.append(id)
	for i in crowd.size():
		var a := TAU * float(i) / float(crowd.size())
		res._movers[crowd[i]].place(centre + Vector2(cos(a), sin(a)) * (2.5 + 1.5 * float(i % 3)), a + PI)
	check(crowd.size() >= want - 2, "a crowd of about %d round the player (%d)" % [want, crowd.size()])
	var cam := get_viewport().get_camera_3d()
	var animals: Array = []
	for g in ["enemy", "stag"]:
		for n in get_tree().get_nodes_in_group(g):
			if n is CharacterBody3D and not animals.has(n):
				animals.append(n)
	var track := {}       # id -> [[ground step, head yaw], ...]
	var last := {}
	var beasts := {}      # animal -> ground steps
	var beast_last := {}
	var frames := 0
	var t := 0.0
	var saved := 0
	while t < 4.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		frames += 1
		for id: int in crowd:
			var body: Node3D = res.bodies[id]
			var head: Node3D = body.head_attachment()
			var fwd: Vector3 = head.global_basis.z if head != null else body.global_basis.z
			var now := [Vector2(body.global_position.x, body.global_position.z), atan2(fwd.x, fwd.z)]
			if last.has(id):
				(track.get_or_add(id, []) as Array).append([(now[0] as Vector2).distance_to(last[id][0]),
					absf(wrapf(float(now[1]) - float(last[id][1]), -PI, PI))])
			last[id] = now
		for a: CharacterBody3D in animals:
			if not is_instance_valid(a):
				continue
			var at := Vector2(a.global_position.x, a.global_position.z)
			if beast_last.has(a):
				(beasts.get_or_add(a, []) as Array).append(at.distance_to(beast_last[a]))
			beast_last[a] = at
		if shots != "" and t > 1.0 and saved < 16 and frames % 2 == 0:
			DirAccess.make_dir_recursive_absolute(shots)
			get_viewport().get_texture().get_image().save_png(shots.path_join("%02d.png" % saved))
			saved += 1
	var steps := 0
	var turns := 0
	var walked := 0
	var worst_turn := 0.0
	var worst_x := 0.0
	for id: int in track:
		var rows: Array = track[id]
		for i in range(1, rows.size() - 1):
			var around := (float(rows[i - 1][0]) + float(rows[i + 1][0])) * 0.5
			if around > 0.01:
				walked += 1
				worst_x = maxf(worst_x, float(rows[i][0]) / around)
				if float(rows[i][0]) > STEP_X * around:
					steps += 1
			var turn := rad_to_deg(float(rows[i][1]))
			worst_turn = maxf(worst_turn, turn)
			if turn > TURN_DEG:
				turns += 1
	var b_steps := 0
	var b_moving := 0
	for a: Variant in beasts:
		var rows: Array = beasts[a]
		for i in range(1, rows.size() - 1):
			var around := (float(rows[i - 1]) + float(rows[i + 1])) * 0.5
			if around > 0.005:
				b_moving += 1
				if float(rows[i]) > STEP_X * around:
					b_steps += 1
	print("SMOOTH frames=%d crowd=%d walking_frames=%d steps=%d worst_step_x=%.2f head_turns_over_%.0f=%d worst_turn_deg=%.1f animals=%d animal_moving_frames=%d animal_steps=%d" % [
		frames, crowd.size(), walked, steps, worst_x, TURN_DEG, turns, worst_turn, beasts.size(), b_moving, b_steps])
	check(walked > 100, "the crowd walked (%d walking body-frames)" % walked)
	check(steps <= walked / 100, "no visible stepping on foot (%d of %d walking body-frames over %.1fx their neighbours)" % [steps, walked, STEP_X])
	check(turns == 0, "no head snaps (%d body-frames turned over %.0f deg)" % [turns, TURN_DEG])
	check(b_steps <= b_moving / 100 + 1, "the animals glide (%d of %d moving frames stepped)" % [b_steps, b_moving])
	print("SMOOTH complete failures=%d" % failed)
	get_tree().quit(0 if failed == 0 else 1)
