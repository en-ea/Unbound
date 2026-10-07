extends Node
## Deaths read dead (the desk's item of 6 Oct 06:26), in the live village through the player's own routes: a villager
## burned to death (the reference), one knocked down and finished by hand (Foundations' "finish": the killing ladder),
## one drowned (Water's Drown held its full time with the Drowned talent), and one soaked by the Tempest's rain and
## frozen by Rime Wave, in ice that then thaws. The fire death is lit as Body's own sequence lights it (body_play_probe
## restrained-flame: the people's door from the player's hand, heat 1000 for 20 s, force 900); the Pyromancer's own Flame
## Dash is cast first and what it did is noted (6 Oct: a helper put its fire out the same moment, every time).
## Dev-only: nothing in the game calls it.
##
##   godot --rendering-driver opengl3 --fixed-fps 30 --path game --resolution 1560x720 -- --studio=village/live \
##     --merge-check=../render/deaths_check --save-guard --test-save=<fresh> --deaths-out=<absolute dir>
##
## Checks: each death is the rules' one death with its cause (burned, finish, drowned); each body then lies in the dead
## posture at its last frame and stays still; the hand-killed and the drowned lie in the fire death's pose, bone for
## bone (the pelvis, head, hands and feet, in the skeleton's own space). The frozen one stands in its ice shell, no step
## and no act; after its time the shell is gone and it moves again, alive.
## Captures, side on, the HUD hidden: fire.png, finish.png, drowned.png, frozen.png, thawed.png.
## Prints "PASS deaths ..." / "FAIL deaths ..." lines and "DEATHS complete failures=N".
const Contact := preload("res://scripts/studio/village/contact.gd")
const Actions := preload("res://scripts/studio/village/sim/people_actions.gd")
const G := preload("res://scripts/studio/people/gestures.gd")
const BONES := ["pelvis", "head", "hand_l", "hand_r", "foot_l", "foot_r"]
const SAME_POSE := 0.05          # metres: the same last pose, bone for bone (bodies differ only in their looks)

var out := ""
var failed := 0
var player: CharacterBody3D
var _cam: Camera3D
var _report := {}


static func on_device(tree: SceneTree) -> void:
	if tree.root.has_node("DeathsCheck"):
		return
	var check: Node = load("res://scripts/studio/render/deaths_check.gd").new()
	check.name = "DeathsCheck"
	tree.root.add_child.call_deferred(check)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--deaths-out="):
			out = arg.trim_prefix("--deaths-out=")
	if out != "":
		DirAccess.make_dir_recursive_absolute(out)
	run.call_deferred()


## The check tests the bodies, not the fight: your hearts stay full.
func _process(_delta: float) -> void:
	if player != null and not player.is_down() and player.health < player.MAX_HEALTH:
		player.heal_full()


func check(ok: bool, text: String) -> void:
	print(("PASS deaths " if ok else "FAIL deaths ") + text)
	if not ok:
		failed += 1


func frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout


func run() -> void:
	await frames(120)
	for _i in 900:
		if VillageSession.village != null and VillageSession.active and get_tree().get_first_node_in_group("player") != null:
			break
		await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	await frames(30)
	Classes.choose("pyromancer")
	_cam = Camera3D.new()
	_cam.fov = 40.0
	get_tree().current_scene.add_child(_cam)
	var poses := {}

	# 1. Burned: the reference death, on someone with no water near (by a well or a trough the people put a fire out at
	# once, their own answer to it: 6 Oct, the dash's burn accepted and put out the same moment).
	var a := await wait_villager(25.0, [], true)
	if a >= 0:
		# First the Pyromancer's own Flame Dash (abilities.use): observed, not checked. On 6 Oct its sweep was accepted
		# and a helper's extinguish (a "use" plan step) put the fire out the same moment, every time, before any harm.
		await _stand(a, 2.5)
		var to := body(a).global_position - player.global_position
		to.y = 0.0
		cast("flame_dash", body(a).global_position, to.normalized())
		await seconds(0.6)
		_report["dash"] = {"burning": resident(a).body_facts.has("burning"), "hurt": resident(a).hurt}
		print("deaths note: the Flame Dash: burning %s, hurt %d, facts %s" % [resident(a).body_facts.has("burning"), resident(a).hurt,
			str((resident(a).body_facts as Dictionary).keys())])
		# The fire death as Body's own sequence makes it (body_play_probe restrained-flame): the people's door from the
		# player's hand, heat 1000 for 20 s with force 900; lit again if the village puts it out first.
		for attempt in 8:
			if not resident(a).alive:
				break
			if not resident(a).body_facts.has("burning"):
				await _stand(a, 2.0)
				_beside(a, 0.8)                   # as Body's sequence: the player 0.8 m from the held one (bodies keep
				                                  # about 1.46 m from a player of their own accord, past the flame's 1.2)
				var lit := Contact.perform(get_tree(), Contact.actor_of(player), player, "burn", {"press_id": "deaths:flame:%d" % attempt,
					"heat": 1000, "duration_ms": 20000, "force": 900}, player.global_position, 1.2, Vector3.ZERO, a)
				await frames(2)
				print("deaths note: flame %d: %s, hurt %d, facts %s" % [attempt, str(lit.get("reason", "ok")), resident(a).hurt,
					str((resident(a).body_facts as Dictionary).keys())])
				if attempt == 0:
					check(lit.get("accepted", false), "a villager set alight as Body's sequence does it (%d: %s)" % [a, str(lit.get("reason", "ok"))])
			for _i in 220:
				if not resident(a).alive or not resident(a).body_facts.has("burning"):
					break
				await seconds(0.1)
		await seconds(3.0)
		check(not resident(a).alive and resident(a).death_cause == "burned", "burned to death (cause %s)" % resident(a).death_cause)
		poses["fire"] = await _dead(a, "fire")
		await _shot(a, "fire")

	Classes.choose("tidecaller")
	Classes.bonus_points = 20
	for t in ["long_hold", "riptide", "drowned"]:
		if Classes.can_learn(t):
			Classes.learn(t)
	check(Classes.has_talent("drowned"), "the Tidecaller with the Drowned talent")

	# 2. Frozen: soaked under the Tempest's rain, then Rime Wave; it thaws after its time. Early, while the village is
	# calm (after the deaths the frightened move about); another villager is tried if the rain missed one.
	var d := -1
	for _try in 3:
		d = await wait_villager(9.0, [a] + ([] if d < 0 else [d]))
		if d < 0:
			break
		await _stand(d, 2.0)                      # under the Tempest's cloud: its rain soaks them (Water's own route)
		cast("tempest", player.global_position)
		await seconds(2.6)
		if live(d, "doused"):
			break
	if d >= 0:
		check(live(d, "doused"), "a villager soaked by the Tempest's rain (%d)" % d)
		cast("rime_wave", body(d).global_position)
		await seconds(0.8)
		var shell := _ice(d)
		var posture := str(body(d).posture())
		check(live(d, "frozen") and shell != null and not posture in G.LYING,
			"frozen: on its feet in an ice shell (frozen %s, shell %s, posture '%s')" % [live(d, "frozen"), shell != null, posture])
		await _shot(d, "frozen")
		for _i in 120:
			if not live(d, "frozen"):
				break
			await seconds(0.1)
		await seconds(1.5)
		check(not live(d, "frozen") and _ice(d) == null and resident(d).alive, "thawed: the shell gone, alive and free to move")
		await _shot(d, "thawed")

	# 3. Killed by hand: the knock-down blow, then the finish (the killing ladder's two holds of Heavy).
	var b := await wait_villager(10.0, [a, d])
	if b >= 0:
		await _stand(b, 1.5)
		var knock := Contact.perform(get_tree(), "player:local", player, "strike", {"press_id": "deaths:knock", "damage": 1, "force": 800},
			player.global_position, 2.8, Vector3.ZERO, b)
		await frames(3)
		check(knock.get("accepted", false) and live(b, "down"), "the knock-down blow puts them down (%s)" % str(knock.get("reason", "ok")))
		await seconds(0.8)
		var done := Contact.perform(get_tree(), "player:local", player, "finish", {"press_id": "deaths:finish"},
			player.global_position, 2.8, Vector3.ZERO, b)
		await frames(3)
		check(done.get("accepted", false) and not resident(b).alive and resident(b).death_cause == "finish",
			"finished by hand: the rules' death, cause %s (%s)" % [resident(b).death_cause, str(done.get("reason", "ok"))])
		await seconds(3.0)
		poses["finish"] = await _dead(b, "finish")
		await _shot(b, "finish")

	# 4. Drowned: Drown held its full time, with the Drowned talent.
	var c := await wait_villager(9.0, [a, b, d])
	if c >= 0:
		cast("drown", body(c).global_position)
		await frames(3)
		check(live(c, "suspended"), "Drown holds them in the water")
		for _i in 160:
			if not resident(c).alive:
				break
			await seconds(0.1)
		await seconds(3.0)
		check(not resident(c).alive and resident(c).death_cause == "drowned", "drowned at the end of the hold (cause %s)" % resident(c).death_cause)
		poses["drowned"] = await _dead(c, "drowned")
		await _shot(c, "drowned")

	for k in ["finish", "drowned"]:
		if poses.has("fire") and poses.has(k):
			var worst := 0.0
			for bone: String in poses["fire"]:
				if poses[k].has(bone):
					worst = maxf(worst, (poses[k][bone] as Vector3).distance_to(poses["fire"][bone]))
			_report["pose_" + k] = worst
			check(worst <= SAME_POSE, "%s lies in the fire death's pose, bone for bone (worst %.3f m)" % [k, worst])

	var f := FileAccess.open(out.path_join("check.json"), FileAccess.WRITE) if out != "" else null
	if f != null:
		f.store_string(JSON.stringify(_report, "  "))
		f.close()
	print("DEATHS complete failures=%d" % failed)
	get_tree().quit(1 if failed > 0 else 0)


## A dead body: the dead posture at its last frame, and nothing moves for a second. Returns its bones, body space.
func _dead(id: int, name: String) -> Dictionary:
	var b := body(id)
	var before := _bones(b)
	await seconds(1.0)
	var after := _bones(b)
	var moved := 0.0
	for bone: String in before:
		moved = maxf(moved, (before[bone] as Vector3).distance_to(after[bone]))
	var at: float = b.posture_position()
	_report[name] = {"person": id, "posture": b.posture(), "at": at, "moved": moved}
	check(b.posture() == "dead" and at >= G.DIE_TO - 0.01 and moved < 0.002,
		"%s: the body lies dead (posture %s at %.2f of %.2f s) and still (%.4f m in a second)" % [name, b.posture(), at, G.DIE_TO, moved])
	return after


func _bones(b: Node3D) -> Dictionary:
	var skeleton: Skeleton3D = b.get("_skeleton")
	var out_bones := {}
	if skeleton == null:
		return out_bones
	for name: String in BONES:              # in the skeleton's own space: the rig turns to face a blow as it falls
		var i := skeleton.find_bone(name)
		if i >= 0:
			out_bones[name] = skeleton.get_bone_global_pose(i).origin
	return out_bones


func _ice(id: int) -> Node3D:
	for n in body(id).get_children():
		if n is MeshInstance3D and (n as MeshInstance3D).mesh is CylinderMesh:
			return n
	return null


## The body from beyond it (the player behind it, not in front): from above when it lies, from the side when it stands;
## the HUD, the name tags and whatever stands in the way hidden, from the check's own camera; then back to the game's.
func _shot(id: int, name: String) -> void:
	if out == "" or DisplayServer.get_name() == "headless":
		return
	var b := body(id)
	var at := b.global_position
	var away := at - player.global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else Vector3.BACK
	var lying: bool = str(b.posture()) in G.LYING
	var aim := at + Vector3(0, 0.3 if lying else 0.9, 0)
	_cam.global_position = at + away * (2.6 if lying else 3.2) + Vector3(0, 2.4 if lying else 1.5, 0)
	_cam.look_at(aim)
	# Whatever stands between the camera and the body (a house, a roof, a merged cell, a passer-by) is hidden for the
	# shot; the ground and the body stay.
	var hidden: Array[GeometryInstance3D] = []
	var others: Array[Node3D] = []                 # every other body and the player: the subject alone in its place
	var people: Array = Contact.registry(get_tree()).bodies.values() + [player]
	for n in get_tree().current_scene.find_children("*", "Node3D", true, false):    # and his own characters (npc.gd)
		var sc: Script = n.get_script()
		if sc != null and sc.resource_path == "res://scripts/world/npc.gd":
			people.append(n)
	for n: Node3D in people:
		if n != b and is_instance_valid(n) and n.visible:
			n.visible = false
			others.append(n)
	var terrain := get_tree().current_scene.get_node_or_null("Terrain")
	for n in get_tree().current_scene.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		if not gi.is_visible_in_tree() or b.is_ancestor_of(gi) or (terrain != null and terrain.is_ancestor_of(gi)):
			continue
		var box: AABB = gi.global_transform * gi.get_aabb()
		if box.intersects_segment(_cam.global_position, aim):
			gi.visible = false
			hidden.append(gi)
	var game_cam := get_viewport().get_camera_3d()
	_cam.current = true
	var hud: CanvasLayer = get_tree().current_scene.get_node("HUD")
	hud.visible = false
	var tags: Array[Node3D] = []
	for n in get_tree().current_scene.find_children("*", "Label3D", true, false):
		if (n as Node3D).visible:
			(n as Node3D).visible = false
			tags.append(n)
	await frames(4)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var side_px := img.get_height()
	img = img.get_region(Rect2i((img.get_width() - side_px) / 2, 0, side_px, side_px))
	print("DEATHS shot %s %s" % [name, error_string(img.save_png(out.path_join(name + ".png")))])
	for n in tags:
		if is_instance_valid(n):
			n.visible = true
	for gi in hidden:
		if is_instance_valid(gi):
			gi.visible = true
	for n in others:
		if is_instance_valid(n):
			n.visible = true
	hud.visible = true
	if game_cam != null:
		game_cam.current = true


func cast(ability: String, at: Vector3, dir := Vector3.ZERO) -> void:
	Classes.start_cooldown(ability, 0.0)
	var aim := dir if dir != Vector3.ZERO else (at - player.global_position).normalized()
	player.abilities.use(ability, {"at": at, "dir": aim, "press_id": "deaths:%s:%d" % [ability, Time.get_ticks_usec()]})


func resident(id: int):
	return VillageSession.village.people[id]


func live(id: int, kind: String) -> bool:
	return Actions.live(VillageSession.village, resident(id), kind)


func body(id: int) -> Node3D:
	return Contact.registry(get_tree()).bodies[id]


## An adult villager the door may act on, standing within `near` metres (nearest first), not in `skip`; with `dry`,
## not wet and with no water place (a well, a trough) within 8 m.
func villager(near: float, skip: Array = [], dry := false) -> int:
	var res := Contact.registry(get_tree())
	var v = VillageSession.village
	var best := -1
	var best_d := near
	for id: int in res.bodies:
		if id in skip or not Contact.eligible(get_tree().current_scene.get_node("VillageLive"), v, id):
			continue
		if dry and (live(id, "doused") or _near_water(res, (res.bodies[id] as Node3D).global_position, 8.0)):
			continue
		var d: float = (res.bodies[id] as Node3D).global_position.distance_to(player.global_position)
		if d < best_d and Contact.clear(player, player.global_position, res.bodies[id].global_position):
			best = id
			best_d = d
	return best


func wait_villager(near: float, skip: Array = [], dry := false) -> int:
	for _i in 120:
		var id := villager(near, skip, dry)
		if id >= 0:
			return id
		await seconds(0.5)
	check(false, "a villager within %.0f m to act on" % near)
	return -1


func _near_water(res: Node, at: Vector3, within: float) -> bool:
	var water: GDScript = load("res://scripts/studio/village/water.gd")
	for place: String in VillageSession.village.place_ids:
		if bool(water.call("_water", place)):
			var focus: Vector2 = res.call("focus", place)
			if focus != Vector2.INF and focus.distance_to(Vector2(at.x, at.z)) < within:
				return true
	return false


## Stands a villager `dist` metres in front of the player, facing them, held there, as the storm, fire_known and
## saturation checks stand theirs. This check is about the death and its body, not about catching someone: on 6 Oct a
## villager walking a Mind plan away ended 4-8 m short of a 5 s walk, and the blow measured no contact.
## The spot is the first of eight ways round, ahead first, with a clear line from the player (Contact.clear, as the
## blow measures it); the check then waits, up to 60 frames (the saturation probe waits 30), until the body stands there.
## (A body settles about 1.46 m from the player however near it is put: their own room, 6 Oct.)
func _stand(id: int, dist: float) -> void:
	var res := Contact.registry(get_tree())
	var me := Vector2(player.global_position.x, player.global_position.z)
	var yaw: float = player.visual.rotation.y
	var front := me + Vector2(sin(yaw), cos(yaw)) * dist
	for k in 8:
		var way := yaw + TAU * float(k) / 8.0
		var spot := me + Vector2(sin(way), cos(way)) * dist
		if Contact.clear(player, player.global_position, Vector3(spot.x, player.global_position.y, spot.y)):
			front = spot
			break
	var face := me - front
	var off := INF
	for _i in 60:
		var at := Vector2(body(id).global_position.x, body(id).global_position.z)
		off = at.distance_to(front)
		if off < 0.3:
			break
		res._movers[id].place(front, atan2(face.x, face.y))
		res._movers[id].hold(front, me)
		await frames(1)
	print("deaths note: stood %d at %.2f m from the player (%.2f m off the spot; clear %s)" % [id,
		Vector2(body(id).global_position.x, body(id).global_position.z).distance_to(me), off,
		str(Contact.clear(player, player.global_position, body(id).global_position))])


## The player put `gap` metres from a held body, facing it, as Body's restrained-flame sequence puts them
## (body_play_probe position_player: the held one's place less 0.8 m).
func _beside(id: int, gap: float) -> void:
	var at: Vector3 = body(id).global_position
	var from := Vector2(player.global_position.x - at.x, player.global_position.z - at.z)
	from = from.normalized() if from.length() > 0.01 else Vector2(0.0, -1.0)
	player.global_position = at + Vector3(from.x, 0.0, from.y) * gap
	player.velocity = Vector3.ZERO
	player.visual.rotation.y = atan2(-from.x, -from.y)
	print("deaths note: the player %.2f m from %d" % [Vector2(player.global_position.x - at.x, player.global_position.z - at.z).length(), id])
