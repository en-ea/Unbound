extends RefCounted
## Acting out what the village says a resident is doing about the player (runtime.reactions[str(id)] =
## {state, since, until}, game minutes). Presentation only: the rules wrote it, the body acts it out until `until`,
## then residents.gd hands it back to the day (the way back is walked: a carried offset that shrinks to nothing).
##
##   the one struck: puzzled, startled, protest, flee, call_help, plead, down, fight_back
##   onlookers:      intervene, shout, flee, back_away, watch
##
## An Act is one resident's turn. It is made by residents.gd, which gives it the body and its mover and answers its
## questions (where the door is, the way round the houses, where the player is, who might help): `reg`.
##
## The act says where to go and how (a jog, backing off, standing to face the player); the body's mover
## (people/mover.gd) gets it there through the crowd at the person's own pace and turn, as in everyday life. A run
## home ends indoors, through the door.
const React := preload("res://scripts/studio/village/resident_react.gd")
const Lines := preload("res://scripts/studio/village/resident_lines.gd")
const Mover := preload("res://scripts/studio/people/mover.gd")

## States only the one struck can be in (an onlooker's `flee` is told from a struck one's by this).
const STRUCK_ONLY := ["puzzled", "startled", "protest", "call_help", "plead", "down", "fight_back"]
const CLOSE_TO := 1.55        # a fighter stops this far from the player
const CLOSE_EVERY := 0.25     # seconds between a fighter's looks at where the player has got to
const JOG_FROM := 4.0         # metres: further than this a fighter closes at a jog, nearer at a hurry
const HIT_REACH := 2.0        # ... and a blow reaches this far (creatures/bandit.gd)
## An honest blow, in the timing of Enea's bandits (creatures/bandit.gd): the glint comes GLINT_LEAD before it lands.
const GLINT_LEAD := 0.45
const IMPACT := 0.24          # into the swing, when it lands
const WINDUP := 0.85
const SWING := 0.6
const RECOVER := 0.9
const PUSH := 3.5             # how hard a blow shoves the player
const FLEE_HURT := 60         # hurt this much and a fighter turns to flee (sim/world_actions.gd hurt)
const GIVE_UP := 12.0         # metres: a fighter lets the player go this far (provoke.gd LEAVE_DISTANCE)


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
	var mover: Mover              # moves the body (the crowd steps it)
	var pos := Vector2.ZERO       # on the ground (x, z): the mover's, read each update
	var hidden := false           # indoors: fled home
	var attacker: Attacker        # a fight_back's blow, in the terms of Enea's defence
	var t := 0.0
	var mode := ""                # what the state is doing now
	var _helper := -1
	var _reroute := 0.0
	var _bark_in := 0.0
	var _anchor: Node3D           # follows the body: holds the "!" or the attacker
	var _overlay: EnemyOverlay
	var _swung := false
	var _stagger := 0.0
	var _up_at := -1.0            # down: when getting up began
	var trace: Array[String] = [] # what the fight did, "seconds:step" (probes read it; a few entries per answer)
	var age := 0.0                # seconds since the answer began

	func staggered() -> bool:
		return _stagger > 0.0

	## Parried: the blow is stopped and the fighter reels (Enea's bandits do the same, Hit_Knockback).
	func stagger(seconds: float) -> void:
		_stagger = seconds
		trace.append("%.2f:stagger" % age)
		mode = "stagger"
		t = 0.0
		_swung = true
		body.play_action("Hit_Knockback", 1.0)

	## Begins acting. The body is where the routine left it.
	func start() -> void:
		pos = mover.pos
		mover.backing = false
		mode = state
		var away: Vector2 = -_to_player()
		if away.length() < 0.01:
			away = Vector2(0.0, 1.0)
		away = away.normalized()
		match state:
			"puzzled":
				_stand()
				_loop("Idle_No")
			"startled":
				_back_off(pos + away * 0.9, "hurry")                 # a quick step back, facing them
				_loop("Spell_Simple_Idle")
			"protest":
				_stand()
				body.play_action("Spell_Simple_Shoot", 1.0)         # a hand thrust at them, then talk
			"plead":
				_stand()
				_loop("Fixing_Kneeling")
			"down":
				_stand()
				body.play_action("Hit_Knockback", 1.0)
			"flee":
				_run_to(reg.door_of(id), true)
			"call_help":
				_helper = reg.helper_for(id)
				if _helper < 0:
					mode = "flee"
					_run_to(reg.door_of(id), true)
				else:
					_run_to(_near_helper())
			"intervene":
				var struck: int = reg.struck_of(since)
				var at: Vector2 = reg.body_xz(struck) if struck >= 0 else pos
				var between: Vector2 = reg.player_xz() - at
				_run_to(at + (between.normalized() if between.length() > 0.1 else away) * 1.1)   # between the two
			"shout":
				_stand()
				body.play_action("Spell_Simple_Shoot", 1.0)
				_mark()
			"back_away":
				var ring: Vector2 = reg.onlooker_spot(id, _watched())
				_back_off(ring if ring.distance_to(reg.player_xz()) > pos.distance_to(reg.player_xz()) else pos + away * 3.5, "walk")
			"watch":
				var ring: Vector2 = reg.onlooker_spot(id, _watched())      # out to a ring round it, by their boldness
				if ring.distance_to(pos) > 0.4:
					mover.go(reg.route(pos, ring), INF, "walk")
					mover.face_at = _watched()
				else:
					_stand()
				_loop("Idle_FoldArms")
			"fight_back":
				_mark()
				attacker = Attacker.new()
				attacker.act = self
				_anchor.add_child(attacker)
				mode = "close"
				_reroute = 0.0
		_bark()

	func done(now: int) -> bool:
		if state == "down":
			return now >= until and _up_at >= 0.0 and t - _up_at > 1.3
		if state == "fight_back" and mode != "flee" and _to_player().length() > GIVE_UP:
			return true   # the player ran off, or was knocked out and woke elsewhere: the fight is over
		return now >= until

	func update(delta: float, now: int) -> void:
		t += delta
		age += delta
		pos = mover.pos
		if hidden:
			return
		match state:
			"puzzled", "plead", "shout":
				mover.face(reg.player_xz())
			"watch":
				mover.face(_watched())
				if _there() and t > 0.5:
					_loop("Idle_FoldArms")
			"protest":
				mover.face(reg.player_xz())
				if mode == "protest" and t > 0.9:
					mode = "talk"
					_loop("Idle_Talking")
			"startled":
				mover.face(reg.player_xz())
				if mode == "startled" and _there():
					mode = "wary"
					mover.backing = false
					_stand()
					_loop("Spell_Simple_Idle")
			"down":
				_down(now)
			"flee":
				hidden = _there() and mover.indoors
			"call_help":
				_call_help(delta)
			"intervene":
				if mode == "intervene" and _there():
					mode = "between"
					_stand()
					_loop("Idle_FoldArms")
				mover.face(reg.player_xz())
			"back_away":
				mover.face(reg.player_xz())
				if mode == "back_away" and _there():
					mode = "wary"
					mover.backing = false
					_stand()
					_loop("Idle_FoldArms")
			"fight_back":
				if mode != "flee":
					_fight(delta)
		if mode == "flee" and state != "flee":            # a call for help with no one to call, or a fighter who has had enough
			hidden = _there() and mover.indoors
		if is_instance_valid(_anchor):
			_anchor.global_position = Vector3(pos.x, body.position.y, pos.y)

	func cleanup() -> void:
		if is_instance_valid(_anchor):
			_anchor.queue_free()
		_anchor = null
		attacker = null
		if mover != null:
			mover.backing = false

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
		var priority := React.Speech.STEP_IN if onlooker else React.Speech.STRUCK
		React.say(body, Lines.bark(state, id, since, onlooker), 0.0, priority, reg.voice_of(id))

	## What an onlooker watches: the one struck (else the player).
	func _watched() -> Vector2:
		var struck: int = reg.struck_of(since)
		return reg.body_xz(struck) if struck >= 0 and struck != id else reg.player_xz()

	## Stands where they are, facing the player.
	func _stand() -> void:
		mover.hold(mover.pos, reg.player_xz())

	## A run (a jog) round the houses; `door`: they go in there (home).
	func _run_to(goal: Vector2, door := false) -> void:
		mover.go(reg.route(mover.pos, goal), INF, "jog")
		mover.enters = door

	## Backing off to `to`, still facing the player.
	func _back_off(to: Vector2, how: String) -> void:
		mover.face_at = reg.player_xz()
		mover.go(reg.route(mover.pos, to), INF, how)
		mover.backing = true

	## There: the mover has arrived.
	func _there() -> bool:
		return not mover.walking()

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
		if pos.distance_to(reg.body_xz(_helper)) > 1.9 or not _there():
			_bark_in -= delta
			if _bark_in <= 0.0:
				_bark_in = 3.0
				React.say(body, Lines.bark("call_help", id, since + int(t)), 0.0, React.Speech.STRUCK, reg.voice_of(id))
		elif mode != "telling":
			mode = "telling"
			mover.hold(mover.pos, reg.body_xz(_helper))
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
			trace.append("%.2f:flee hurt %d" % [age, reg.hurt_of(id)])
			_run_to(reg.door_of(id), true)
			React.say(body, Lines.bark("flee", id, since + 7), 0.0, React.Speech.STRUCK, reg.voice_of(id))
			return
		var pxz: Vector2 = reg.player_xz()
		var to := pxz - pos
		var dist := to.length()
		if mode != "swing" and mode != "stagger":
			mover.face(pxz)
		match mode:
			"close":
				_reroute -= delta
				if dist > CLOSE_TO + 0.15:
					if _reroute <= 0.0 or _there():           # closing in on where the player has got to
						_reroute = CLOSE_EVERY
						var goal := pxz - to.normalized() * CLOSE_TO
						mover.go(PackedVector2Array([goal]), INF, "jog" if dist > JOG_FROM else "hurry")
				elif reg.player_can_be_hit():
					mode = "windup"
					trace.append("%.2f:windup at %.1f m" % [age, dist])
					t = 0.0
					_swung = false
					mover.hold(mover.pos, pxz)
					body.play_loop("Punch_Jab", 0.1, 0.0, 0.15)      # the guard is up: nothing is hidden
				elif _there() or mover.hold_at == Vector2.INF:
					mover.hold(mover.pos, pxz)
			"windup":
				if not _swung and t >= WINDUP - (GLINT_LEAD - IMPACT):
					_swung = true
					if _overlay != null:
						_overlay.glint()
					attacker.blow_coming.emit(id)
					trace.append("%.2f:glint" % age)
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
					trace.append("%.2f:blow %s at %.1f m" % [age, result, dist])
				if t >= SWING:
					mode = "recover"
					t = 0.0
			"recover":
				if t >= RECOVER:
					mode = "close"
					_reroute = 0.0
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
