extends RefCounted
## Actions in the village outside any event: talk, square_up (the intent to fight), strike, shove, give. Same rules as
## the event verbs in runtime.gd: a unique action id, accepted once (a repeat returns the first receipt), the
## state changed before anything is shown, costs returned for the caller to charge.
##
##   request {action_id, player_id, village_id, logical_time, verb, target, parameters}
##   context {distance_dm, witnesses: [resident ids that could see]}
##   -> {accepted, outcome | reason, duplicate?, ...}
##
## The player's standing with each resident lives in runtime.acquaintance[str(id)]:
##   {met: minute first met, feeling: -100..100, memories: [token]} (view.gd reads it)
const S := preload("res://scripts/studio/village/sim/state.gd")
const Village := preload("res://scripts/studio/village/sim/village.gd")
const Reactions := preload("res://scripts/studio/village/sim/reactions.gd")
const R := preload("res://scripts/studio/village/sim/rng.gd")

const TALK_REACH_DM := 30      # three metres
const STRIKE_REACH_DM := 30    # a blow lands within three metres (the fighter steps in)
const MEMORY_CAP := 12
const DOWN_MINUTES := 60       # knocked down: an hour of game time (half a real minute) before they get up
## how long each answer is acted out (game minutes; the presentation reads runtime.reactions)
const REACT_MINUTES := {"puzzled": 4, "startled": 3, "protest": 6, "flee": 20, "call_help": 15, "fight_back": 10,
	"plead": 8, "down": DOWN_MINUTES, "intervene": 10, "shout": 5, "back_away": 5, "watch": 5}


static func act(v: S.Village, request: Dictionary, context: Dictionary) -> Dictionary:
	var r := v.runtime
	var id: String = request.get("action_id", "")
	if id.is_empty() or id.length() > 120:
		return fail("invalid action")
	if r.receipts.has(id):
		var old: Dictionary = r.receipts[id].duplicate(true)
		old.duplicate = true
		return old
	if request.get("village_id") != r.village or request.get("player_id") != "player:local" or request.get("logical_time") != r.now:
		return fail("stale context")
	var target := int(request.get("target", -1))
	if target < 0 or target >= v.people.size():
		return fail("no one there")
	var p := v.people[target]
	if not p.alive or not p.present:
		return fail("no one there")
	var distance := float(context.get("distance_dm", INF))
	var verb: String = request.get("verb", "")
	match verb:
		"talk":
			if distance > TALK_REACH_DM or is_nan(distance):
				return fail("out of reach")
			var known := acquaintance(v, target)
			var first := not known.has("met")
			if first:
				known.met = int(r.now)
				remember(v, target, "met")
			known.last_talk = int(r.now)
			return accept(v, request, "first meeting" if first else "talked", {"target": target})
		"square_up":
			# the player makes clear they mean to fight (the talk screen's "Pick a fight"): no blow yet, but it is noticed
			if distance > TALK_REACH_DM or is_nan(distance):
				return fail("out of reach")
			var guard := _can_target(v, p)
			if not guard.is_empty():
				return fail(guard)
			remember(v, target, "threatened_by_you", -10)
			var answer := Reactions.struck(v, target, {"hits": 0, "allies": context.get("allies", []), "k": _k(v, target, 0)})
			_react(v, target, "protest" if answer in ["puzzled", "startled"] else answer, 6)
			return accept(v, request, "squared up", {"target": target, "reaction": answer})
		"strike", "shove":
			if distance > STRIKE_REACH_DM or is_nan(distance):
				return fail("out of reach")
			var guard := _can_target(v, p)
			if not guard.is_empty():
				return fail(guard)
			var now := int(r.now)
			var known := acquaintance(v, target)
			var recent: Array = known.get_or_add("hits", [])
			recent.append(now)
			while recent.size() > 8 or (recent.size() > 0 and int(recent[0]) < now - 60):
				recent.remove_at(0)
			var strike: bool = verb == "strike"
			var damage := clampi(int(request.parameters.get("damage", 1)), 1, 5)
			p.hurt = clampi(p.hurt + (damage * 14 if strike else 4), 0, 100)
			var answer := "down"
			if strike and p.hurt >= 100:
				p.down_until = now + DOWN_MINUTES
			else:
				answer = Reactions.struck(v, target, {"hits": recent.size(), "allies": _allies(v, target, context), "k": _k(v, target, recent.size())})
			remember(v, target, "hit_by_you" if strike else "shoved_by_you", (-30 if recent.size() <= 1 else -15) if strike else -12)
			_react(v, target, answer, REACT_MINUTES.get(answer, 6))
			# those who could see it answer in their own way, and remember
			var seen_by := {}
			var reporter := -1
			for w: int in context.get("witnesses", []):
				if w == target or w < 0 or w >= v.people.size() or not v.people[w].alive or not v.people[w].present:
					continue
				var wr := Reactions.witness(v, w, target, {"k": _k(v, w, recent.size())})
				seen_by[w] = wr
				remember(v, w, "saw_you_hit" if strike else "saw_you_shove", Reactions.witness_feeling(v, w, target) / (1 if strike else 2))
				_react(v, w, wr, REACT_MINUTES.get(wr, 5))
				if reporter < 0 and wr in ["shout", "intervene"] and Village.age_of(v, v.people[w]) >= 14:
					reporter = w
			if reporter < 0 and answer != "down" and answer != "fight_back":
				reporter = target
			_report(v, reporter, target, now)
			return accept(v, request, answer, {"target": target, "reaction": answer, "witnesses": seen_by, "hurt": p.hurt,
				"down": p.down_until > now})
		"give":
			if distance > TALK_REACH_DM or is_nan(distance):
				return fail("out of reach")
			var item: String = request.parameters.get("item", "")
			var count := clampi(int(request.parameters.get("count", 1)), 1, 20)
			if item.is_empty() or int(context.get("have", 0)) < count:
				return fail("nothing to give")
			var value := count * (2 if item == "coins" else 4)
			var h := v.households[p.household]
			if context.get("food", false):
				h.food += count * 4   # food feeds the house
			remember(v, target, "gift_from_you", mini(30, value))
			return accept(v, request, "gift", {"target": target, "item": item, "count": count})
	return fail("unknown action")


## The player's standing with one resident (created on first need).
static func acquaintance(v: S.Village, id: int) -> Dictionary:
	var all: Dictionary = v.runtime.get_or_add("acquaintance", {})
	return all.get_or_add(str(id), {"feeling": 0, "memories": []})


static func remember(v: S.Village, id: int, token: String, feeling_change: int = 0) -> void:
	var known := acquaintance(v, id)
	var memories: Array = known.memories
	if not memories.has(token):
		memories.append(token)
		if memories.size() > MEMORY_CAP:
			memories.remove_at(1)   # the first meeting is kept; the oldest other memory goes
	known.feeling = clampi(int(known.feeling) + feeling_change, -100, 100)


## Who can never be struck or threatened: children (never, in any build), and the village's protected people
## (Enea's authored characters, from L5). -> the reason, or "" if they can be.
static func _can_target(v: S.Village, p: S.Person) -> String:
	if Village.age_of(v, p) < 14:
		return "never a child"
	if p.down_until > int(v.runtime.now):
		return "they are already down"
	if p.locked:
		return "they are held"
	return ""


## Kin and friends of the struck person who could see it (from the presentation's witnesses).
static func _allies(v: S.Village, target: int, context: Dictionary) -> Array:
	var out := []
	for w: int in context.get("witnesses", []):
		if w != target and w >= 0 and w < v.people.size() and (Village.is_kin(v, w, target) or Village.opinion(v, w, target) >= 30):
			out.append(w)
	return out


static func _k(v: S.Village, id: int, n: int) -> int:
	return R.key(R.key(R.key(v.base, Village.P_CROWD), int(v.runtime.now)), id * 17 + n)


## What a resident is doing about the player right now (the presentation acts it out until `until`).
static func _react(v: S.Village, id: int, state: String, minutes: int) -> void:
	var now := int(v.runtime.now)
	v.runtime.get_or_add("reactions", {})[str(id)] = {"state": state, "since": now, "until": now + minutes}


## Someone who saw it (or the one struck) goes to tell the village's authority, half an hour later.
static func _report(v: S.Village, reporter: int, about: int, now: int) -> void:
	if reporter < 0 or v.authority < 0 or reporter == v.authority:
		if reporter == v.authority and reporter >= 0:
			remember(v, v.authority, "saw_you_hit")
		return
	var minute := now % 1440 + 30
	var it := {"kind": "report", "actor": reporter, "other": v.authority, "about": about, "minute": minute,
		"k": _k(v, reporter, 99), "place": -1, "tries": 0}
	if minute >= Village.END_AT or not v.runtime.get("day_open", false):
		it.minute = 480
		v.intents_next.append(it)   # told in the morning
	else:
		Village.add_intent(v, it)


static func fail(reason: String) -> Dictionary:
	return {"accepted": false, "reason": reason}


static func accept(v: S.Village, request: Dictionary, outcome: String, extra: Dictionary = {}) -> Dictionary:
	var r := v.runtime
	var receipt := {"accepted": true, "action_id": request.action_id, "verb": request.verb, "at": r.now,
		"outcome": outcome, "player": request.player_id}
	receipt.merge(extra, true)
	r.receipts[request.action_id] = receipt
	r.sequence += 1
	if r.receipts.size() > 256:
		r.receipts.erase(r.receipts.keys()[0])
	return receipt
