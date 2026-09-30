extends RefCounted
## Acting out what the village says a resident is doing about the player (runtime.reactions[str(id)] =
## {state, since, until}, game minutes). Presentation only: the rules wrote it, the body acts it out until `until`,
## then residents.gd hands it back to the day (the way back is walked: a carried offset that shrinks to nothing).
##
##   the one struck: puzzled, startled, protest, flee, call_help, plead, down, fight_back
##   onlookers:      intervene, shout, flee, back_away, watch
##
## An Act is one resident's turn. It is made by residents.gd, which gives it the body and answers its questions
## (where the door is, the way round the houses, where the player is, who might help): `reg`.
const React := preload("res://scripts/studio/village/resident_react.gd")
const Lines := preload("res://scripts/studio/village/resident_lines.gd")

## States only the one struck can be in (an onlooker's `flee` is told from a struck one's by this).
const STRUCK_ONLY := ["puzzled", "startled", "protest", "call_help", "plead", "down", "fight_back"]
const JOG := 3.4              # m/s: running (VillagerBody plays Jog_Fwd above 3)
const BACKING := 1.9          # m/s: backing off, brisk
const CLOSE_TO := 1.55        # a fighter stops this far from the player
const HIT_REACH := 2.0        # ... and a blow reaches this far (creatures/bandit.gd)
## An honest blow, in the timing of Enea's bandits (creatures/bandit.gd): the glint comes GLINT_LEAD before it lands.
const GLINT_LEAD := 0.45
const IMPACT := 0.24          # into the swing, when it lands
const WINDUP := 0.85
const SWING := 0.6
const RECOVER := 0.9
const PUSH := 3.5             # how hard a blow shoves the player
const FLEE_HURT := 60         # hurt this much and a fighter turns to flee (sim/world_actions.gd hurt)


## What Enea's defence talks to. player.receive_attack(attacker, damage, push) reads its position, and asks it to
## `parried(seconds)` (a stagger) and `is_open()` (staggered: the next counter is a critical hit).
class Attacker extends Node3D:
	signal blow_coming(who: int)
	signal blow_landed(who: int, result: String)
	var act: Act

	func parried(seconds: float) -> void:
		if act != null:
			act.stagger(seconds)

	func is_open() -> bool:
		return act != null and act.staggered()


class Act extends RefCounted:
	var id := -1
	var state := ""
	var since := 0
	var until := 0
	var onlooker := false
	var reg: Node3D               # residents.gd
	var body: Node3D
	var pos := Vector2.ZERO       # on the ground (x, z)
	var hidden := false           # indoors: fled home
	var attacker: Attacker        # a fight_back's blow, in the terms of Enea's defence
	var t := 0.0
	var mode := ""                # what the state is doing now
	var _path := PackedVector2Array()
	var _helper := -1
	var _reroute := 0.0
	var _bark_in := 0.0
	var _anchor: Node3D           # follows the body: holds the "!" or the attacker
	var _overlay: EnemyOverlay
	var _swung := false
	var _stagger := 0.0
	var _up_at := -1.0            # down: when getting up began

	func staggered() -> bool:
		return _stagger > 0.0

	## Parried: the blow is stopped and the fighter reels (Enea's bandits do the same, Hit_Knockback).
	func stagger(seconds: float) -> void:
		_stagger = seconds
		mode = "stagger"
		t = 0.0
		_swung = true
		body.play_action("Hit_Knockback", 1.0)

	## Begins acting. The body is where the routine left it.
	func start() -> void:
		pos = Vector2(body.position.x, body.position.z)
		mode = state
		var away: Vector2 = -_to_player()
		if away.length() < 0.01:
			away = Vector2(0.0, 1.0)
		away = away.normalized()
		match state:
			"puzzled":
				_loop("Idle_No")
			"startled":
				_loop("Spell_Simple_Idle")
				_path = PackedVector2Array([pos + away * 0.9])      # a quick step back
			"protest":
				body.play_action("Spell_Simple_Shoot", 1.0)         # a hand thrust at them, then talk
			"plead":
				_loop("Fixing_Kneeling")
			"down":
				body.play_action("Hit_Knockback", 1.0)
			"flee":
				_run_to(reg.door_of(id))
			"call_help":
				_helper = reg.helper_for(id)
				if _helper < 0:
					mode = "flee"
					_run_to(reg.door_of(id))
				else:
					_run_to(_near_helper())
			"intervene":
				var struck: int = reg.struck_of(since)
				var at: Vector2 = reg.body_xz(struck) if struck >= 0 else pos
				var between: Vector2 = reg.player_xz() - at
				_run_to(at + (between.normalized() if between.length() > 0.1 else away) * 1.1)   # between the two
			"shout":
				body.play_action("Spell_Simple_Shoot", 1.0)
				_mark()
			"back_away":
				_path = reg.route(pos, pos + away * 3.5)
			"watch":
				_loop("Idle_FoldArms")
			"fight_back":
				_mark()
				attacker = Attacker.new()
				attacker.act = self
				_anchor.add_child(attacker)
				mode = "close"
		_bark()

	func done(now: int) -> bool:
		if state == "down":
			return now >= until and _up_at >= 0.0 and t - _up_at > 1.3
		return now >= until

	func update(delta: float, now: int) -> void:
		t += delta
		if hidden:
			return
		match state:
			"puzzled", "plead", "watch", "shout":
				_face(reg.player_xz(), delta)
			"protest":
				_face(reg.player_xz(), delta)
				if mode == "protest" and t > 0.9:
					mode = "talk"
					_loop("Idle_Talking")
			"startled":
				if not _path.is_empty():
					_follow(delta, 3.2)
				_face(reg.player_xz(), delta)
			"down":
				_down(now)
			"flee":
				if _follow(delta, JOG):
					hidden = true
			"call_help":
				_call_help(delta)
			"intervene":
				if _follow(delta, JOG):
					_loop("Idle_FoldArms")
					_face(reg.player_xz(), delta)
			"back_away":
				if _follow(delta, BACKING):
					_loop("Idle_FoldArms")
					_face(reg.player_xz(), delta)
			"fight_back":
				if mode != "flee":
					_fight(delta)
		if mode == "flee" and state != "flee":            # a call for help with no one to call, or a fighter who has had enough
			if _follow(delta, JOG):
				hidden = true
		if is_instance_valid(_anchor):
			_anchor.global_position = Vector3(pos.x, body.position.y, pos.y)
		body.position = Vector3(pos.x, reg.ground(pos), pos.y)

	func cleanup() -> void:
		if is_instance_valid(_anchor):
			_anchor.queue_free()
		_anchor = null
		attacker = null

	# ---- pieces ----------------------------------------------------------------------------------------------

	func _to_player() -> Vector2:
		return reg.player_xz() - pos

	func _loop(anim: String, speed := 1.0) -> void:
		body.play_loop(anim, 0.2, speed, id * 0.37)

	## A few words as they start (never a rule).
	## Only the one struck, and the onlookers who speak up (a shout, a step between), say anything: a crowd that all
	## talked at once would be noise. Running children call out for one in two.
	func _bark() -> void:
		if hidden or (onlooker and state in ["watch", "back_away"]) or (onlooker and state == "flee" and id % 2 == 0):
			return
		React.say(body, Lines.bark(state, id, since, onlooker))

	func _face(at: Vector2, delta: float) -> void:
		var to := at - pos
		if to.length_squared() > 0.01:
			body.rotation.y = lerp_angle(body.rotation.y, atan2(to.x, to.y), clampf(delta * 8.0, 0.0, 1.0))

	func _run_to(goal: Vector2) -> void:
		_path = reg.route(pos, goal)

	## Along the path at `speed`; true once there.
	func _follow(delta: float, speed: float) -> bool:
		var step := speed * delta
		while step > 0.0 and not _path.is_empty():
			var to: Vector2 = _path[0]
			var d := pos.distance_to(to)
			if d > 0.001:
				body.rotation.y = lerp_angle(body.rotation.y, atan2(to.x - pos.x, to.y - pos.y), clampf(delta * 12.0, 0.0, 1.0))
			if d <= step:
				pos = to
				step -= d
				_path.remove_at(0)
			else:
				pos += (to - pos) * (step / d)
				step = 0.0
		if not _path.is_empty():
			body.play_motion(speed)
		return _path.is_empty()

	func _near_helper() -> Vector2:
		var at: Vector2 = reg.body_xz(_helper)
		var off := pos - at
		return at + (off.normalized() if off.length() > 0.1 else Vector2(0.0, 1.0)) * 1.4

	func _call_help(delta: float) -> void:
		if _helper < 0:
			return
		_reroute -= delta
		if _reroute <= 0.0:
			_reroute = 1.2
			if pos.distance_to(reg.body_xz(_helper)) > 1.9:
				_run_to(_near_helper())
		if pos.distance_to(reg.body_xz(_helper)) > 1.9 or not _path.is_empty():
			_follow(delta, JOG)
			_bark_in -= delta
			if _bark_in <= 0.0:
				_bark_in = 3.0
				React.say(body, Lines.bark("call_help", id, since + int(t)))
		else:
			_face(reg.body_xz(_helper), delta)
			_loop("Idle_Talking")

	## Knocked down: the fall, then sat on the ground dazed; at the end, getting up. Nothing of an injury is shown.
	func _down(now: int) -> void:
		if _up_at >= 0.0:
			return
		if now >= until:
			_up_at = t
			body.play_action("LayToIdle", 1.0, 0.5)
		elif t > float(body.animation_length("Hit_Knockback")):
			body.play_loop("LayToIdle", 0.15, 0.0, 0.5)         # sat up, held

	## A blow with fists, honestly: close in, a guard held (the wind-up), the glint, the swing, a breather.
	func _fight(delta: float) -> void:
		if reg.hurt_of(id) >= FLEE_HURT and mode != "stagger":
			mode = "flee"                                       # (`flee` is acted on by update)
			_run_to(reg.door_of(id))
			React.say(body, Lines.bark("flee", id, since + 7))
			return
		var pxz: Vector2 = reg.player_xz()
		var to := pxz - pos
		var dist := to.length()
		if mode != "swing" and mode != "stagger":
			_face(pxz, delta)
		match mode:
			"close":
				if dist > CLOSE_TO:
					pos += to.normalized() * JOG * delta * (1.0 if dist > CLOSE_TO + 0.3 else 0.5)
					body.play_motion(JOG)
				elif reg.player_can_be_hit():
					mode = "windup"
					t = 0.0
					_swung = false
					body.play_loop("Punch_Jab", 0.1, 0.0, 0.15)      # the guard is up: nothing is hidden
				else:
					body.play_motion(0.0)
			"windup":
				if not _swung and t >= WINDUP - (GLINT_LEAD - IMPACT):
					_swung = true
					if _overlay != null:
						_overlay.glint()
					attacker.blow_coming.emit(id)
				if t >= WINDUP:
					mode = "swing"
					t = 0.0
					_swung = false
					body.play_action("Punch_Cross", 1.0)
			"swing":
				if not _swung and t >= IMPACT:
					_swung = true
					var result := "miss"
					if dist < HIT_REACH and reg.player_can_be_hit():
						var dir := to.normalized()
						result = reg.player().receive_attack(attacker, 1, Vector3(dir.x, 0.0, dir.y) * PUSH)
					attacker.blow_landed.emit(id, result)
				if t >= SWING:
					mode = "recover"
					t = 0.0
			"recover":
				body.play_motion(0.0)
				if t >= RECOVER:
					mode = "close"
			"stagger":
				_stagger -= delta
				if _stagger <= 0.0:
					mode = "recover"
					t = 0.0

	## Enea's red "!" over the head (creatures/enemy_overlay.gd), and the anchor that carries it.
	func _mark() -> void:
		_anchor = Node3D.new()
		reg.add_child(_anchor)
		_anchor.global_position = Vector3(pos.x, body.position.y, pos.y)
		_overlay = EnemyOverlay.new()
		_overlay.position = Vector3(0.0, 1.95, 0.0)
		_anchor.add_child(_overlay)
		if state == "shout":
			_overlay.set_awareness(1.0, true)
