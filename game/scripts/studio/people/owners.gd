extends RefCounted
## Who drives a body (plan VILLAGE-LIFE-AND-NEWS section 5, #4; it is Pass 3's agreed step "shared control: one owner
## at a time by priority, suspend and resume"). Everything that moves a person - a stage's scene, the player's talk, an
## answer to a blow, a happening, a meeting or a conversation - asks here first, and the one with the higher claim has
## them. Generic: ids, owner names and priorities (the caller's), not villages.
##
##   var owners := Owners.new()
##   owners.claim(id, by, priority, lost := Callable(), keep := false) -> bool
##       granted if nobody holds `id`, `by` already does, or the holder's priority is no higher (equal: the latest
##       wins, as a new answer replaces the talk and the talk a standing answer). The holder it takes them from is told
##       first-hand: its `lost` is called (id, by) - it lets go of what it was doing with them. A holder that claimed
##       with keep = true is not let go but suspended under the new one: when that one releases, it has them again
##       (its `resumed`, see below), unless it released them meanwhile.
##   owners.release(id, by)           only the holder's release counts (or a suspended one withdrawing); then the
##                                    suspended one under it, if any, resumes: resumed.call(id)
##   owners.owner(id) -> String       "" when nobody holds them: their own day has them
##   owners.held(id, by) -> bool      `by` is the one driving them now
##   owners.suspended(id, by) -> bool `by` keeps them, waiting under a higher claim
##   owners.is_free(id) -> bool       nobody holds them
##   owners.can_claim(id, priority) -> bool
##   owners.resumed[by] = Callable    (id) -> void: how a suspended owner takes someone back
##
## The day is never an owner: it is what everyone goes back to.
## Foundations: opaque body keys (including actor strings) are accepted. claim(..., wait=true) queues a refused
## claim; release resumes the highest priority waiting claim, latest among equals. Physical constraints belong
## to the mover/element port, independently of this arbitration. A queued claim must still check held before moving.

var resumed := {}                 # owner name -> (id) -> void
var _held := {}                   # id -> [by, priority, lost, keep]
var _under := {}                  # id -> Array of [by, priority, lost, keep]: suspended claims, the latest last


func claim(id: Variant, by: String, priority: int, lost := Callable(), keep := false, wait := false) -> bool:
	var now: Array = _held.get(id, [])
	if not now.is_empty():
		if now[0] == by:
			_held[id] = [by, priority, lost, keep]
			return true
		if int(now[1]) > priority:
			if wait:
				var pending: Array = _under.get_or_add(id, [])
				for i in range(pending.size() - 1, -1, -1):
					if pending[i][0] == by:
						pending.remove_at(i)
				pending.append([by, priority, lost, keep])
			return false
	_held[id] = [by, priority, lost, keep]
	if now.is_empty():
		return true
	if bool(now[3]):
		(_under.get_or_add(id, []) as Array).append(now)     # kept: it waits under the new one
	elif (now[2] as Callable).is_valid():
		(now[2] as Callable).call(id, by)                     # let go: it ends what it was doing with them
	return true


func release(id: Variant, by: String) -> void:
	var under: Array = _under.get(id, [])
	for i in range(under.size() - 1, -1, -1):
		if under[i][0] == by:
			under.remove_at(i)                               # a suspended one withdrawing
	var now: Array = _held.get(id, [])
	if now.is_empty() or now[0] != by:
		return
	_held.erase(id)
	if under.is_empty():
		_under.erase(id)
		return
	var best := 0
	for i in range(1, under.size()):
		if int(under[i][1]) >= int(under[best][1]):
			best = i
	var back: Array = under.pop_at(best)
	if under.is_empty():
		_under.erase(id)
	_held[id] = back
	var f: Callable = resumed.get(back[0], Callable())
	if f.is_valid():
		f.call(id)


func owner(id: Variant) -> String:
	var now: Array = _held.get(id, [])
	return "" if now.is_empty() else str(now[0])


func held(id: Variant, by: String) -> bool:
	var now: Array = _held.get(id, [])
	return not now.is_empty() and now[0] == by


## `by` claimed them with keep and waits under someone higher (theirs again when that one lets go).
func suspended(id: Variant, by: String) -> bool:
	for c: Array in _under.get(id, []):
		if c[0] == by:
			return true
	return false


func is_free(id: Variant) -> bool:
	return not _held.has(id)


func can_claim(id: Variant, priority: int) -> bool:
	var now: Array = _held.get(id, [])
	return now.is_empty() or int(now[1]) <= priority


## Everyone `by` holds or keeps suspended (a measure, and for an owner that ends everything at once).
func of(by: String) -> Array:
	var out: Array = []
	for id: Variant in _held:
		if _held[id][0] == by:
			out.append(id)
	for id: Variant in _under:
		for c: Array in _under[id]:
			if c[0] == by and not out.has(id):
				out.append(id)
	return out
