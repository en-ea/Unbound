extends RefCounted
## Actions in the village outside any event: talk (now), strike, shove, give (Pass 2 stage 2). Same rules as
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

const TALK_REACH_DM := 30      # three metres
const MEMORY_CAP := 12


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
		"strike", "shove", "give":
			return fail("not yet")   # Pass 2 stage 2
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
