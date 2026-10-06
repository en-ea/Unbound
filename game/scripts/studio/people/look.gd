extends RefCounted
## Where a person looks (Pass 3, stage 4: the plan's L6). A small director for each person near the camera: what is
## worth their eyes now, by priority, held a moment once chosen (eyes settle on something; they do not flick about
## every frame). Built to be replaced by perception's attention (PA-3) behind the same call. Generic: points and a few
## facts about the moment, not villages; the head itself is pose.gd's.
##
##   var gaze := Look.Gaze.new(key, alert)          key: keys their timing; alert 0..1: the alert glance more
##   gaze.update(dt, ctx) -> Vector3               a world point to look at (Vector3.INF: ahead)
##
##   ctx (any may be missing):
##     "addressed"  Vector3    someone talking to them (the player at a talk, the other in a meeting): looked at
##     "speaker"    Vector3    who talks in their conversation (not them): looked at, with glances round the others
##     "others"     Array      the rest of their conversation ([Vector3, ...])
##     "event"      Vector3    something that just happened near (a blow, a shout): looked at for EVENT_FOR
##     "player"     Vector3    the player's head; "player_near" metres; "player_moving" bool
##     "sights"     Array      [[Vector3, weight], ...]: people passing, a quarrel, children at play (or a Callable
##                             returning that: asked only when a glance is due, every few seconds)
##     "eye"        Vector3    their own eyes; "forward" Vector3 their facing (nothing behind them is looked at)
##
##   addressed > event > speaker (and glances round) > the player passing near > a glance at what passes > ahead
##
## Cost: a few comparisons a person, ten times a second (the sights, the dear part, only when a glance is due).

const EVENT_FOR := 2.5        # seconds a sudden thing holds the eyes
const GLANCE := Vector2(0.8, 1.6)     # seconds a glance lasts
const GLANCE_EVERY := Vector2(3.0, 8.0)   # seconds between glances at what passes
const ROUND_SHARE := 0.25     # in a conversation, this share of the time on someone other than the speaker
const PLAYER_NEAR := 4.5      # metres: the player passing this close draws a glance ...
const PLAYER_AGAIN := 10.0    # ... not again for this long
const BEHIND := 1.9           # radians off their facing: further round is behind them (not looked at)


class Gaze:
	var key := 0
	var alert := 0.5
	var target := Vector3.INF
	var kind := ""                # what they look at: "addressed", "event", "speaker", "round", "player", "sight", ""
	var _hold := 0.0              # seconds left of the present choice
	var _next := 0.0              # seconds to the next glance at what passes
	var _player_cool := 0.0
	var _event := Vector3.INF     # the last sudden thing seen (a new one draws the eyes again)
	var _event_t := 0.0
	var _n := 0

	func _init(the_key: int, the_alert := 0.5) -> void:
		key = the_key
		alert = the_alert
		_next = lerpf(GLANCE_EVERY.x, GLANCE_EVERY.y, noise(key, 1))

	func update(dt: float, ctx: Dictionary) -> Vector3:
		_hold -= dt
		_next -= dt
		_player_cool -= dt
		_event_t -= dt
		var eye: Vector3 = ctx.get("eye", Vector3.ZERO)
		var forward: Vector3 = ctx.get("forward", Vector3.BACK)
		var addressed: Vector3 = ctx.get("addressed", Vector3.INF)
		if addressed != Vector3.INF:
			return _choose("addressed", addressed, 0.5)
		var event: Vector3 = ctx.get("event", Vector3.INF)
		if event != Vector3.INF and (_event == Vector3.INF or event.distance_to(_event) > 0.5):
			_event = event                      # something new happened: eyes to it
			_event_t = EVENT_FOR
		if _event_t > 0.0 and _sees(eye, forward, _event):
			return _choose("event", _event, _event_t)
		var speaker: Vector3 = ctx.get("speaker", Vector3.INF)
		var others: Array = ctx.get("others", [])
		if speaker != Vector3.INF or not others.is_empty():
			if _hold > 0.0 and kind in ["speaker", "round"]:
				return target if kind == "round" else speaker
			_n += 1
			var round := speaker == Vector3.INF or (not others.is_empty() and noise(key + _n, 2) < ROUND_SHARE)
			if round and not others.is_empty():
				return _choose("round", others[int(noise(key + _n, 3) * others.size()) % others.size()], _length(4))
			return _choose("speaker", speaker, _length(5) * 2.0)
		if _hold > 0.0 and kind in ["player", "sight"]:
			return target
		var player: Vector3 = ctx.get("player", Vector3.INF)
		if player != Vector3.INF and float(ctx.get("player_near", INF)) < PLAYER_NEAR and _player_cool <= 0.0 \
				and bool(ctx.get("player_moving", false)) and _sees(eye, forward, player):
			_player_cool = PLAYER_AGAIN
			if noise(key + int(_player_cool * 7.0) + _n, 6) < 0.35 + 0.6 * alert:
				return _choose("player", player, _length(7) + 0.4)
		if _next <= 0.0:
			_next = lerpf(GLANCE_EVERY.x, GLANCE_EVERY.y, noise(key + _n, 8)) * (1.3 - 0.6 * alert)
			_n += 1
			var best := Vector3.INF
			var most := 0.0
			var sights = ctx.get("sights", [])
			if sights is Callable:
				sights = (sights as Callable).call()
			for s: Array in sights:
				var at: Vector3 = s[0]
				var w := float(s[1]) * (0.6 + 0.8 * noise(key + _n + int(at.x * 10.0), 9))
				if w > most and _sees(eye, forward, at):
					most = w
					best = at
			if best != Vector3.INF:
				return _choose("sight", best, _length(10))
		if _hold <= 0.0:
			kind = ""
			target = Vector3.INF
		return target

	func _choose(what: String, at: Vector3, hold: float) -> Vector3:
		kind = what
		target = at
		_hold = hold
		return at

	func _length(salt: int) -> float:
		return lerpf(GLANCE.x, GLANCE.y, noise(key + _n, salt))

	## In front of them enough to look at without turning round.
	static func _sees(eye: Vector3, forward: Vector3, at: Vector3) -> bool:
		var to := Vector2(at.x - eye.x, at.z - eye.z)
		var f := Vector2(forward.x, forward.z)
		if to.length_squared() < 0.01 or f.length_squared() < 0.0001:
			return true
		return absf(f.angle_to(to)) < BEHIND

	static func noise(k: int, salt: int) -> float:
		return float(posmod(hash(k * 7919 + salt * 104729), 100000)) / 100000.0
