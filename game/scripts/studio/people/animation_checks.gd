extends RefCounted
## Headless checks for the people's body and pose (B5/B6/B8, the animation specialist's machinery): the rig and the
## clips the elements play, the derived limp's tracks, the posture lock, layers composing and clearing, a reach and a
## fist landing, the wrist hold staying the last word, the one-file element proof composing and cleaning up, equal fear
## read two ways, the vocal hook; then the fact elements through Body's real runner (people/body_elements.gd) with a
## fixture port: a blow, a fresh fall against a reload and a held body, the get-up, active time freezing every visual
## clock, death over the burn and a carried corpse; the player's pose from Body's intent and its active clock;
## alertness and interest made visible. Seconds:
##   godot --headless --path game --script res://scripts/studio/run.gd -- people/animation_checks
## Machinery only: the look is judged on the hidden boards (people/animation_board.gd), never by these lines.

const VillagerBody := preload("res://scripts/studio/village/villager_body.gd")
const Pose := preload("res://scripts/studio/people/pose.gd")
const BodyElements := preload("res://scripts/studio/people/body_elements.gd")
const CLIPS := ["Hit_Knockback", "LayToIdle", "Death01", "Hit_Chest", "Hit_Head", "Crouch_Idle", "Zombie_Walk_Fwd",
	"Walk", "Walk_Limp"]
const WATCH := ["hand_l", "hand_r", "index_02_l", "spine_03", "Head"]
const DT := 1.0 / 30.0


## Hands' face the player pose reads on resume (studio/player/hands.gd preview()).
class StubHands:
	extends Node
	var live := {"verb": "", "phase": "idle", "strength": 0.0, "load": "", "guard": false, "crouch": false}

	func preview() -> Dictionary:
		return live


## The mover's face the elements touch (people/mover.gd): constraints, hold, stagger. Moves nothing.
class StubMover:
	extends RefCounted
	var constraints := {}
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var staggers: Array = []

	func can_move() -> bool:
		for c: Dictionary in constraints.values():
			if not bool(c.get("move", true)):
				return false
		return true

	func can_posture(posture: String) -> bool:
		for c: Dictionary in constraints.values():
			var allowed: Array = c.get("postures", [])
			if not allowed.is_empty() and not allowed.has(posture):
				return false
		return true

	func hold(_at: Vector2, _face := Vector2.INF) -> void:
		pass

	func stagger(away: Vector2, distance: float, _delay := 0.18, _duration := 0.55) -> bool:
		if not can_move():
			return false
		staggers.append([away, distance])
		return true


static func report() -> PackedStringArray:
	var out := PackedStringArray()
	var root := (Engine.get_main_loop() as SceneTree).root
	var body: Node3D = VillagerBody.new()
	root.add_child(body)
	var sk: Skeleton3D = body._skeleton
	var anim: AnimationPlayer = body._anim
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	sk.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	var seen := {}
	sk.skeleton_updated.connect(func() -> void:
		for b: String in WATCH:
			seen[b] = sk.get_bone_global_pose(sk.find_bone(b)))

	# the rig: every bone the pose drives, every clip the elements play
	var missing: Array = []
	for b: String in Pose.FLINCH_BONES + Pose.LOOK_BONES + ["pelvis", "clavicle_l", "clavicle_r", "thigh_l", "calf_r"]:
		if sk.find_bone(b) < 0:
			missing.append(b)
	for side: String in ["l", "r"]:
		for b: String in Pose.ARMS[side]:
			if sk.find_bone(b) < 0:
				missing.append(b)
		for f: String in Pose.FINGERS:
			for k in [1, 2, 3]:
				if sk.find_bone("%s_%02d_%s" % [f, k, side]) < 0:
					missing.append("%s_%02d_%s" % [f, k, side])
	for c: String in CLIPS:
		if not anim.has_animation(c):
			missing.append(c)
	out.append(("PASS" if missing.is_empty() else "FAIL") + " rig: %d bones and %d clips present (missing %s)"
		% [sk.get_bone_count(), CLIPS.size(), missing])

	# the derived limp: the zombie's legs, the walk's upper body, the pelvis half way
	var limp := anim.get_animation("Walk_Limp")
	var legs := anim.get_animation("Zombie_Walk_Fwd")
	var walk := anim.get_animation("Walk")
	var limp_ok := limp != null and legs != null and walk != null
	var limp_err := 0.0
	if limp_ok:
		limp_ok = limp.loop_mode == Animation.LOOP_LINEAR and absf(limp.length - legs.length) < 0.001
		for pair: Array in [["thigh_r", legs], ["calf_l", legs], ["spine_02", walk], ["upperarm_r", walk]]:
			var t := 0.4
			var a := _rot(limp, pair[0], t)
			var b := _rot(pair[1], pair[0], t)
			limp_err = maxf(limp_err, a.angle_to(b))
		var mid := _rot(legs, "pelvis", 0.4).slerp(_rot(walk, "pelvis", 0.4), 0.5)
		limp_err = maxf(limp_err, _rot(limp, "pelvis", 0.4).angle_to(mid))
	body.set_gait("limp")
	body.play_motion(1.0)
	var g: Dictionary = body.gait()
	out.append(("PASS" if limp_ok and limp_err < 0.01 and g.clip == "Walk_Limp" and absf(float(g.speed) - 1.0) < 0.05 else "FAIL")
		+ " derived limp: %.2f s loop, tracks within %.4f rad of their sources, plays %s at %.2f m/s"
		% [limp.length if limp else 0.0, limp_err, g.clip, float(g.speed)])
	body.set_gait("")

	# the posture lock: a held posture is the body's until its key lets go; a soft one ends at a step
	body.play_motion(0.0)
	body.hold_posture("down", "LayToIdle", 0.0, 0.0)
	body.play_motion(1.5)
	body.play_loop("Idle_Talking")
	body.play_action("Yes")
	var held: bool = anim.assigned_animation == "LayToIdle" and body.holding() and body.posture() == "down"
	body.release_posture("dead")
	held = held and body.posture() == "down"
	body.release_posture("down")
	var walked: bool = anim.assigned_animation == "Walk" and not body.holding()
	body.play_motion(0.0)
	body.express({"fear": 0.9, "style": {"show": 0.9, "steady": 0.2}})
	var cowered: bool = body.posture() == "cower"
	body.play_motion(1.0)
	out.append(("PASS" if held and walked and cowered and body.posture() == "" else "FAIL")
		+ " posture lock: held against motion/loop/action %s, released to the walk %s, soft cower %s then stepped out of"
		% [held, walked, cowered])
	body.express({})
	body.play_motion(0.0)
	_frames(body, sk, anim, 1.2)

	# layers: two compose, clearing one leaves the other as it was
	var pose: Node = body.pose()
	_frames(body, sk, anim, 0.3)
	var open_finger: Transform3D = seen.get("index_02_l", Transform3D())
	pose.set_layer("check:a", {"spine": Vector3(0.3, 0.0, 0.0)}, 1.0, 0.1)
	pose.set_layer("check:b", {"fist": 1.0}, 1.0, 0.1)
	_frames(body, sk, anim, 0.3)
	var curled: float = open_finger.basis.get_rotation_quaternion().angle_to(
		(seen.get("index_02_l", Transform3D()) as Transform3D).basis.get_rotation_quaternion())
	pose.clear_layer("check:a", 0.1)
	_frames(body, sk, anim, 0.3)
	var kept: bool = not pose.has_layer("check:a") and not pose._layers.has("check:a") and pose.has_layer("check:b") \
		and is_equal_approx(float(pose._layers["check:b"].w), 1.0)
	out.append(("PASS" if kept and curled > 0.5 and not seen.is_empty() else "FAIL")
		+ " layers: cleared one gone, the other at full weight %s; the fist curled a finger %.2f rad (bones seen %d)"
		% [kept, curled, seen.size()])
	pose.clear_layer("check:b", 0.1)

	# a reach lands its wrist where it was sent (metres in the body's own frame)
	var target := Vector3(-0.3, 1.5, 0.35)
	pose.set_layer("check:reach", {"reach_r": {"bone": "", "at": target}}, 1.0, 0.05)
	_frames(body, sk, anim, 0.3)
	var wrist := body.to_local(sk.global_transform * (seen.get("hand_r", Transform3D()) as Transform3D).origin)
	out.append(("PASS" if wrist.distance_to(target) < 0.03 else "FAIL")
		+ " reach: the right wrist %.3f m from its target %s" % [wrist.distance_to(target), target])
	pose.clear_layer("check:reach", 0.05)
	_frames(body, sk, anim, 0.6)

	# a wrist hold (a pillory) stays the last word: the pose made after it runs before it, and reaches never move it
	var held_body: Node3D = VillagerBody.new()
	root.add_child(held_body)
	var hsk: Skeleton3D = held_body._skeleton
	var hanim: AnimationPlayer = held_body._anim
	hanim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	hsk.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	var hseen := {}
	hsk.skeleton_updated.connect(func() -> void: hseen["hand_l"] = hsk.get_bone_global_pose(hsk.find_bone("hand_l")))
	var hole := Vector3(0.16, 1.32, 0.42)
	held_body.hold_hands(hole, Vector3(-0.16, 1.32, 0.42))
	var hpose: Node = held_body.pose()
	hpose.set_layer("check:reach", {"reach_l": {"bone": "", "at": Vector3(0.3, 1.8, 0.1)}, "spine": Vector3(0.3, 0.2, 0.3)}, 1.0, 0.05)
	_frames(held_body, hsk, hanim, 0.4)
	var hands: Node = hsk.get_node("Hands")
	var hwrist := held_body.to_local(hsk.global_transform * (hseen.get("hand_l", Transform3D()) as Transform3D).origin)
	out.append(("PASS" if hpose.get_index() < hands.get_index() and hwrist.distance_to(hole) < 0.05 else "FAIL")
		+ " wrist hold last: pose %d before hands %d, the held wrist %.3f m from the board" % [hpose.get_index(),
		hands.get_index(), hwrist.distance_to(hole)])
	held_body.free()

	# the one-file element proof composes over another key's posture and layer, and leaves the body as it found it
	var runner = BodyElements.new("res://scripts/studio/people/proofs/elements/")
	var emitted: Array = []
	var port := {"body": body, "mover": StubMover.new(), "source": "check", "live": func(_f: Dictionary) -> bool: return true,
		"emit": func(kind: String, _fields: Dictionary) -> void: emitted.append(kind),
		"vocal": func(kind: String, _strength: float) -> void: emitted.append(kind)}
	body.hold_posture("down", "LayToIdle", 0.0, 0.0)
	pose = body.pose()        # (the earlier one may have been dropped once it had nothing to show)
	pose.set_layer("element:other", {"breath": Vector2(0.4, 0.02)}, 1.0, 0.05)
	_frames(body, sk, anim, 0.2)
	var children := [body.get_child_count(), sk.get_child_count()]
	runner.play("wince", port, 0.8, {"kind": "wince"})
	var during := false
	for i in 60:
		runner.update(DT)
		body.apply_elements(runner.layers)
		_frames(body, sk, anim, DT)
		during = during or pose.has_layer("element:wince")
	_frames(body, sk, anim, 0.5)
	var composed: bool = during and runner.playing.is_empty() and runner.layers.is_empty() \
		and not pose._layers.has("element:wince") and pose.has_layer("element:other") and body.posture() == "down" \
		and emitted == ["gasp", "wince"]
	var tidy: bool = children == [body.get_child_count(), sk.get_child_count()] and body.surface() == Vector2.ZERO
	out.append(("PASS" if composed and tidy else "FAIL")
		+ " one-file element: composed over another posture and layer %s, nothing left after %s" % [composed, tidy])
	pose.clear_layer("element:other", 0.05)
	body.release_posture("down")
	_frames(body, sk, anim, 1.0)
	out.append(("PASS" if not body.has_pose() and body.posture() == "" else "FAIL")
		+ " cleanup: no pose modifier or posture once nothing shows (pose %s, posture '%s')" % [body.has_pose(), body.posture()])

	# Body's runner layers through the one consumer: the highest posture shows, death masks motion, removal restores
	var layers := {"down": {"posture": {"name": "down", "clip": "LayToIdle", "at": 0.0}, "breath": Vector2(0.5, 0.02), "knee_l": 0.4},
		"burning": {"flail": 1.0, "surface": Vector2(0.4, 0.8), "fx": {"kind": "flames"}}}
	body.apply_elements(layers)
	_frames(body, sk, anim, 0.2)
	var lying: bool = body.posture() == "down" and anim.assigned_animation == "LayToIdle" and body.surface() == Vector2(0.4, 0.8) \
		and body._fx.has("burning") and body.pose().has_layer("element:down") and body.pose().has_layer("element:burning")
	layers["dead"] = {"posture": {"name": "dead", "clip": "Death01", "at": 2.3}, "still": true}     # (over down; under carried)
	body.apply_elements(layers)
	var burning_layer: Dictionary = body.pose()._layers.get("element:burning", {})
	var dead: bool = body.posture() == "dead" and (burning_layer.is_empty() or bool(burning_layer.end)
		or not (burning_layer.p as Dictionary).has("flail"))
	layers.erase("dead")
	body.apply_elements(layers)
	var back: bool = body.posture() == "down" and anim.assigned_animation == "LayToIdle" \
		and (body.pose()._layers["element:burning"].p as Dictionary).has("flail")
	body.apply_elements({})
	_frames(body, sk, anim, 0.4)
	var clear: bool = body.posture() == "" and body._fx.is_empty() and body.surface() == Vector2.ZERO \
		and (not body.has_pose() or body.pose()._layers.is_empty())
	out.append(("PASS" if lying and dead and back and clear else "FAIL")
		+ " element layers: down+burning %s, dead over them masks the flail %s, back to down %s, all gone %s"
		% [lying, dead, back, clear])

	# equal fear read two ways: a timid temperament cowers, a bold one stands its ground
	var timid := Pose.contraction(0.9, 0.9, 0.2)
	var bold := Pose.contraction(0.9, 0.3, 0.9)
	out.append(("PASS" if timid >= VillagerBody.COWER_FROM and bold < VillagerBody.COWER_UNTIL and timid > 2.5 * bold else "FAIL")
		+ " equal fear 0.9: timid draws in %.2f (cowers from %.2f), bold %.2f" % [timid, VillagerBody.COWER_FROM, bold])

	# what the pose shows others: an angry body leaning in reads as threatening while it shows, and not after
	for i in 45:
		body.express({"fear": 0.0, "anger": 0.9, "style": {"show": 0.6, "steady": 0.7, "lean": 0.9}})
		_frames(body, sk, anim, DT)
	var threat: bool = bool((body.get_meta("people_observable", {}) as Dictionary).get("threatening", false))
	for i in 60:
		body.express({"fear": 0.0, "anger": 0.0, "style": {"show": 0.6, "steady": 0.7, "lean": 0.0}})
		_frames(body, sk, anim, DT)
	var calm: bool = not body.has_meta("people_observable")
	out.append(("PASS" if threat and calm else "FAIL")
		+ " observable clue: threatening while the angry lean shows %s, cleared once calm %s" % [threat, calm])
	body.express({})

	# alertness and interest made visible
	var dull: Array = _attention(body, sk, anim, seen, 0.0, 0.0, body.global_position + Vector3(2.0, 1.55, 1.2))
	var alert: Array = _attention(body, sk, anim, seen, 1.0, 0.0, body.global_position + Vector3(2.0, 1.55, 1.2))
	var calm_ahead: Array = _attention(body, sk, anim, seen, 0.0, 0.0, body.global_position + Vector3(0.0, 1.5, 3.0))
	var keen_ahead: Array = _attention(body, sk, anim, seen, 0.0, 1.0, body.global_position + Vector3(0.0, 1.5, 3.0))
	var quicker: bool = float(alert[0]) > 0.0 and float(dull[0]) > float(alert[0]) + 0.03
	var leans: bool = float(keen_ahead[1]) > float(calm_ahead[1]) + 0.02
	out.append(("PASS" if quicker and leans else "FAIL")
		+ " attention: an alert head reaches the look in %.2f s, a dull one in %.2f s; interest brings the head %.3f m forward"
		% [float(alert[0]), float(dull[0]), float(keen_ahead[1]) - float(calm_ahead[1])])
	body.look_at_point(Vector3.INF)
	body.express({})

	# the vocal hook: a real voice can answer it; the placeholder needs a voice set
	var heard: Array = []
	body.vocalized.connect(func(kind: String, k: float) -> void: heard.append([kind, k]))
	body.voice = ""
	body.vocal("cry", 700.0)
	var one_cry: bool = heard.size() == 1 and heard[0][0] == "cry" and is_equal_approx(float(heard[0][1]), 0.7)
	out.append(("PASS" if one_cry and body.get_node_or_null("Vocal") == null else "FAIL")
		+ " vocal hook: emitted %s, no placeholder without a voice" % [heard])
	body.free()
	out.append_array(_facts_through_runner(root))
	out.append(_player_pose(root))
	out.append(_player_clock(root))
	return out


## The player pose on the game's active clock: locked (a dialogue, the phone in the background), nothing moves and no
## intent is taken; on resume a release from before is not replayed and the live guard or load shows again.
static func _player_clock(root: Node) -> String:
	var flags := [Controls.locked, VillageSession.background]
	Controls.locked = false
	VillageSession.background = false
	var visual := CharacterVisual.new()
	root.add_child(visual)
	var hands := StubHands.new()
	root.add_child(hands)
	var adapter: Node = (load("res://scripts/studio/player/player_pose.gd") as GDScript).new()
	adapter.visual = visual
	hands.add_child(adapter)
	adapter.show_intent({"verb": "guard", "phase": "prepared", "strength": 1.0, "forward": Vector3.FORWARD, "target": -2})
	adapter._process(0.5)
	adapter.show_intent({"verb": "shove", "phase": "released", "strength": 1.0})
	adapter._process(0.05)
	var thrust_before: float = adapter._thrust_left
	var pose_time: float = adapter._pose._time
	Controls.locked = true
	adapter._process(1.0)
	adapter.show_intent({"verb": "strike", "phase": "prepared", "strength": 1.0})
	adapter._process(1.0)
	var still: bool = is_equal_approx(float(adapter._thrust_left), thrust_before) and is_equal_approx(float(adapter._pose._time), pose_time) \
		and adapter.showing() == "thrust"
	hands.live = {"verb": "", "phase": "idle", "strength": 0.0, "load": "", "guard": true, "crouch": false}
	Controls.locked = false
	adapter._process(0.016)
	var guard_back: bool = adapter.showing() == "guard" and float(adapter._thrust_left) == 0.0
	VillageSession.background = true
	adapter._process(1.0)
	hands.live = {"verb": "", "phase": "idle", "strength": 0.0, "load": "person", "guard": false, "crouch": false}
	VillageSession.background = false
	adapter._process(0.016)
	var load_back: bool = adapter.showing() == "carry"
	hands.free()
	visual.free()
	Controls.locked = flags[0]
	VillageSession.background = flags[1]
	return ("PASS" if still and guard_back and load_back else "FAIL") \
		+ " player pose clock: locked, the thrust and springs stood still and no intent was taken %s; resumed to the held guard without replaying the thrust %s; back from the background to a carried person %s" \
		% [still, guard_back, load_back]


## Alertness and interest from Mind made visible: an alert body turns its head to a look sooner than a dull one, and an
## interested one leans in to what it watches.
static func _attention(body: Node3D, sk: Skeleton3D, anim: AnimationPlayer, seen: Dictionary, alert: float, interest: float,
		at: Vector3) -> Array:
	var hints := {"fear": 0.0, "anger": 0.0, "pain": 0.0, "interest": interest, "alertness": alert, "tension": 0.0,
		"style": {"show": 0.5, "steady": 0.5, "pace": 0.0, "lean": 0.0}}
	body.look_at_point(Vector3.INF)
	for i in 60:
		body.express(hints)
		_frames(body, sk, anim, DT)
	var pose: Node = body.pose()
	body.look_at_point(at)
	var reached := -1.0
	var t := 0.0
	while t < 2.5:
		body.express(hints)
		_frames(body, sk, anim, DT)
		t += DT
		if reached < 0.0 and float(pose._yaw) >= 0.9 * atan2(at.x - body.global_position.x, at.z - body.global_position.z):
			reached = t
	var head := body.to_local(sk.global_transform * (seen.get("Head", Transform3D()) as Transform3D).origin)
	return [reached, head.z]


## The player's pose adapter (studio/player/player_pose.gd) from Body's intent shapes (studio/player/hands.gd preview):
## a coil while prepared, eased out when cancelled, a released shove's thrust held its moment, a person carried.
static func _player_pose(root: Node) -> String:
	var visual := CharacterVisual.new()
	root.add_child(visual)
	var adapter: Node = (load("res://scripts/studio/player/player_pose.gd") as GDScript).new()
	adapter.visual = visual
	root.add_child(adapter)
	adapter.show_intent({"verb": "strike", "phase": "prepared", "strength": 1.0, "forward": Vector3.FORWARD, "target": -2})
	var coiled: bool = adapter.showing() == "strike" and adapter._pose.has_layer("player:strike")
	adapter.show_intent({"verb": "strike", "phase": "cancelled", "strength": 1.0, "forward": Vector3.FORWARD, "target": -2})
	adapter._process(0.5)
	var eased: bool = adapter.showing() == "" and not adapter._pose._layers.has("player:strike")
	adapter.show_intent({"verb": "shove", "phase": "released", "strength": 1.0})
	var idle := {"verb": "", "phase": "idle", "strength": 0.0, "load": "person", "guard": false, "crouch": false}
	adapter.show_intent(idle)
	var thrust: bool = adapter.showing() == "thrust"
	adapter._process(0.3)
	adapter.show_intent(idle)
	var carry: bool = adapter.showing() == "carry" and adapter._pose.get_parent() == visual._skeleton
	adapter.free()
	visual.free()
	return ("PASS" if coiled and eased and thrust and carry else "FAIL") 		+ " player pose: strike coiled %s, cancelled eased out %s, shove thrust held %s, a person carried %s" 		% [coiled, eased, thrust, carry]


## The fact elements (people/elements/) through Body's runner: reconcile -> update -> apply_elements every frame, as
## residents._physical does, against a fixture port whose facts live on a local tick.
static func _facts_through_runner(root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	var body: Node3D = VillagerBody.new()
	root.add_child(body)
	var sk: Skeleton3D = body._skeleton
	var anim: AnimationPlayer = body._anim
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	sk.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	body.voice = ""
	var runner = BodyElements.new()
	var mover := StubMover.new()
	var facts := {}
	var clock := {"tick": 0}
	var heard: Array = []
	var current := func(fact: Dictionary) -> Dictionary:
		var now: Dictionary = facts.get(str(fact.get("kind", "")), {})
		if now.is_empty() or str(now.get("deed", "")) != str(fact.get("deed", "")) \
				or int(now.get("revision", 0)) != int(fact.get("revision", 0)):
			return {}
		if now.has("until_tick") and int(now.until_tick) <= int(clock.tick):
			return {}
		return now
	var base := {"body": body, "mover": mover, "source": "check", "visible": true, "hints": {}, "current": current,
		"live": func(fact: Dictionary) -> bool: return not (current.call(fact) as Dictionary).is_empty(),
		"emit": func(kind: String, _fields: Dictionary) -> void: heard.append("emit:" + kind),
		"announce": func(kind: String, _fact: Dictionary, transition := false) -> bool:
			heard.append("announce:%s:%s" % [kind, transition])
			return true,
		"vocal": func(kind: String, _strength: float) -> void: heard.append("vocal:" + kind)}
	var run := func(seconds: float, hydrate := false, active := true) -> void:
		var left := seconds
		var first := true
		while left > 0.0001:
			var dt := minf(DT, left)
			if active:
				clock.tick = int(clock.tick) + roundi(dt * 1000.0)
			runner.reconcile(base, facts, int(clock.tick), hydrate and first)
			runner.update(dt if active else 0.0)
			body.apply_elements(runner.layers)
			_frames(body, sk, anim, dt)
			left -= dt
			first = false

	# a blow: planted (Hit_Chest), flashed, grunted, stepped back by Body's stagger, then gone
	runner.play("impact", base, 0.5, {"kind": "impact", "from": Vector3(0.0, 0.0, 2.0), "force": 500, "deed": "check:blow",
		"since_tick": 0})
	body.apply_elements(runner.layers)
	var planted: bool = anim.assigned_animation == "Hit_Chest" and body._flash > 0.0 and mover.staggers.size() == 1 \
		and heard == ["emit:blow", "vocal:grunt"]
	run.call(0.8)
	var blown: bool = planted and runner.playing.is_empty() and runner.layers.is_empty()
	out.append(("PASS" if blown else "FAIL") + " impact: planted, flashed, grunted and staggered once %s, gone after %s"
		% [planted, blown])

	# a fresh fall: faced, announced as a transition and cried once, Hit_Knockback scrubbed, then lying
	heard.clear()
	facts["down"] = _fact("down", {"until_tick": 6000, "strength": 900, "from": [3.0, 0.0], "at": [0.0, 0.0],
		"since_tick": int(clock.tick)})
	run.call(0.25)
	var mid := [anim.assigned_animation, body.posture_position()]
	run.call(0.75)
	var turned: float = body.rig_turn()
	var fell: bool = mid[0] == "Hit_Knockback" and absf(float(mid[1]) - 0.35) < 0.06 and body.posture() == "down" \
		and absf(turned - PI / 2.0) < 0.05 \
		and anim.assigned_animation == "LayToIdle" and mover.constraints.has("element:down") \
		and heard == ["announce:fall:true", "announce:cry:false", "vocal:cry", "emit:fall"]
	# a reload (or coming into view): lying at once, nothing replayed
	heard.clear()
	clock.tick = int(clock.tick) + 3000
	run.call(DT, true)
	var reloaded: bool = body.posture() == "down" and anim.assigned_animation == "LayToIdle" and heard.is_empty()
	run.call(0.3)
	reloaded = reloaded and anim.assigned_animation == "LayToIdle" and heard.is_empty()
	out.append(("PASS" if fell and reloaded else "FAIL")
		+ " fall: fresh %s (%s at %.2f s, turned %.2f rad to the blow, heard once), a reload lies at once in silence %s"
		% [fell, mid[0], float(mid[1]), turned, reloaded])

	# active time stops (runner.update(0)): pose, flash, embers and flames stand still; they go on with it
	facts["burning"] = _fact("burning", {"until_tick": 90000, "strength": 750, "heat": 750, "since_tick": int(clock.tick)})
	run.call(0.3)
	var flames: CPUParticles3D = (body._fx.get("burning", {}) as Dictionary).get("node")
	var pose_time: float = body.pose()._time
	run.call(0.3, false, false)
	var stood: bool = body.frozen() and flames != null and flames.speed_scale == 0.0 \
		and is_equal_approx(float(body.pose()._time), pose_time)
	run.call(0.1)
	var resumed: bool = not body.frozen() and flames != null and flames.speed_scale == 1.0 and float(body.pose()._time) > pose_time
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL    # (unfreezing hands it back)
	out.append(("PASS" if stood and resumed else "FAIL")
		+ " active-time freeze: update(0) stood every visual clock still %s, update(dt) resumed them %s" % [stood, resumed])

	# death over a burning body on the ground: the burn's hurt fact keeps its soot and smoke, stillness masks the clutch;
	# carried shows over dead and gives it back where it is set down
	heard.clear()
	facts.erase("burning")
	facts.erase("down")
	facts["dead"] = _fact("dead", {"at": [0.0, 0.0], "event": 1, "since_tick": int(clock.tick)})
	facts["hurt"] = _fact("hurt", {"strength": 1000, "where": "burn", "since_tick": int(clock.tick)})
	run.call(1.0)
	var hurt_layer: Dictionary = body.pose()._layers.get("element:hurt", {})
	var dead: bool = body.posture() == "dead" and anim.assigned_animation == "Death01" and not runner.layers.has("down") \
		and not runner.layers.has("burning") and body.surface().x > 0.7 and body._fx.has("hurt") \
		and not hurt_layer.is_empty() and not (hurt_layer.p as Dictionary).has("reach_l") and heard == ["vocal:groan"]
	facts["carried"] = _fact("carried", {"carrier": "actor:check", "at": [0.0, 0.0], "since_tick": int(clock.tick)})
	run.call(0.3)
	var carried_layer: Dictionary = body.pose()._layers.get("element:carried", {})
	var borne: bool = body.posture() == "carried" and not carried_layer.is_empty() and (carried_layer.p as Dictionary).has("knee_r")
	facts.erase("carried")
	run.call(0.6)
	var set_down: bool = body.posture() == "dead" and anim.assigned_animation == "Death01" and not runner.layers.has("carried")
	out.append(("PASS" if dead and borne and set_down else "FAIL")
		+ " death: still over the burn, soot and smoke kept %s; carried over dead %s, dead again where set down %s"
		% [dead, borne, set_down])

	# held upright (the stocks): a down fact falls nothing and cries nothing; free, a fall ends in getting up
	facts.clear()
	run.call(0.5)
	var cleared: bool = body.posture() == "" and runner.layers.is_empty()
	mover.constraints["restraint"] = {"move": false, "postures": ["upright"]}
	heard.clear()
	facts["down"] = _fact("down", {"until_tick": int(clock.tick) + 6000, "strength": 900, "from": [0.0, 3.0],
		"at": [0.0, 0.0], "since_tick": int(clock.tick), "revision": 2})
	var ever_down := false
	for i in 30:
		run.call(DT)
		ever_down = ever_down or body.posture() == "down"
	var blocked: bool = cleared and not ever_down and not heard.has("vocal:cry") and not heard.has("announce:fall:true") \
		and not runner.layers.has("down") and not mover.constraints.has("element:down")
	mover.constraints.erase("restraint")
	facts.clear()
	run.call(0.2)
	facts["down"] = _fact("down", {"until_tick": int(clock.tick) + 6000, "strength": 600, "from": [-3.0, 0.0],
		"at": [0.0, 0.0], "since_tick": int(clock.tick), "revision": 3})
	run.call(1.0)
	facts.erase("down")
	run.call(0.5)
	var rising := [anim.assigned_animation, body.posture_position()]
	run.call(1.2)
	var got_up: bool = rising[0] == "LayToIdle" and float(rising[1]) > 0.5 and body.posture() == "" \
		and runner.layers.is_empty() and not mover.constraints.has("element:down") and absf(body.rig_turn()) < 0.02
	out.append(("PASS" if blocked and got_up else "FAIL")
		+ " held and freed: a held body neither falls nor cries %s; freed, it falls and gets up when the fact ends %s (%s at %.2f s)"
		% [blocked, got_up, rising[0], float(rising[1])])
	body.free()
	return out


static func _fact(kind: String, fields: Dictionary) -> Dictionary:
	var row := {"kind": kind, "id": kind, "deed": "check:" + kind, "revision": 1, "since_tick": 0, "strength": 1000}
	row.merge(fields, true)
	return row


## Steps a body by hand: its own process (pose springs, fades, timers), its clips, then its skeleton's modifiers and
## update (skeleton_updated reports the final pose, wrist hold included).
static func _frames(body: Node3D, sk: Skeleton3D, anim: AnimationPlayer, seconds: float) -> void:
	var left := seconds
	while left > 0.0001:
		var dt := minf(DT, left)
		body._process(dt)
		anim.advance(dt)
		sk.advance(dt)                                            # (queues the modifiers' deferred update ...)
		sk.notification(Skeleton3D.NOTIFICATION_UPDATE_SKELETON)  # (... run here: one check is one engine frame)
		left -= dt


static func _rot(anim: Animation, bone: String, t: float) -> Quaternion:
	for i in anim.get_track_count():
		if anim.track_get_type(i) == Animation.TYPE_ROTATION_3D \
				and String(anim.track_get_path(i).get_concatenated_subnames()) == bone:
			return anim.rotation_track_interpolate(i, t)
	return Quaternion.IDENTITY
