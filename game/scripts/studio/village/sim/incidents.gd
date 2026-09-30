extends RefCounted
## Small scenes for deeds done in the live village while the player is there: a theft (or a thief who thinks
## better of it because the player is watching), words or blows between two who dislike each other, a neighbour
## bringing bread. The rules decide what happened (crime.gd run_intent); this only writes the staging the stage
## plays (staging.gd contract) and registers it with the runtime as an "incident" event, which has no decision
## window: it is shown, then it is over.
const S := preload("res://scripts/studio/village/sim/state.gd")
const Village := preload("res://scripts/studio/village/sim/village.gd")
const Justice := preload("res://scripts/studio/village/sim/justice.gd")
const E := preload("res://scripts/studio/village/sim/events.gd")

const WALK_DM := 26   # decimetres a person walks in a game minute (1.3 m/s)


## After an incident phase: stage it if the player is in the village and it is worth seeing.
static func show(V: S.Village, it: Dictionary, result: Dictionary) -> void:
	if V.runtime.is_empty() or not V.runtime.get("player", {}).get("present", false):
		return
	var done: bool = result.get("done", false)
	var turned_back: bool = result.get("abandoned", false) and result.get("watched", false)
	if not done and not turned_back:
		return
	var st := {}
	match it.kind:
		"theft":
			st = _theft(V, it, done)
		"brawl", "quarrel":
			if done:
				st = _quarrel(V, it, result.get("crime") != null)
		"kindness":
			if done:
				st = _kindness(V, it)
		"chat", "help":
			if done:
				st = _pair(V, it)
		"play":
			if done:
				st = _play(V, it)
	if st.is_empty():
		return
	V.stagings.append(st)
	if V.stagings.size() > 300:
		V.stagings.pop_front()
	var actors: Array[int] = []
	for person: Dictionary in st.people:
		actors.append(int(person.id))
	V.runtime.get_or_add("incidents", []).append({"staging": st.id, "kind": st.kind, "victim": int(it.actor), "actors": actors})
	V.runtime.quiet_since = int(V.runtime.now)


static func _walk_minutes(V: S.Village, p: S.Person, minute: int, place: int) -> int:
	var from := Village.place_at(p, maxi(0, minute - 1))
	if from < 0 or place < 0:
		return 4
	return 2 + int(sqrt(float(V.dist2[from * V.n_places + place]))) / WALK_DM


static func _base(V: S.Village, kind: String, place: int, start: int, end: int, subject: int, ids: Array, outcome: String, cue: String) -> Dictionary:
	var people := []
	for id: int in ids:
		people.append(Justice.person_entry(V, id))
	var st := {"id": V.staging_count, "kind": kind, "place": V.place_names[place], "start": start, "end": end,
		"phases": [{"name": "scene", "from": start, "to": end, "rescue": false}],
		"roles": {"victim": subject, "accuser": -1, "authority": -1, "crowd": []},
		"beats": [], "outcome": outcome, "cause": [], "cue": cue, "day": V.day, "people": people}
	V.staging_count += 1
	return st


static func _beat(st: Dictionary, at: int, who: int, action: String, slot: int = -1, target: int = -1, anim: String = "", prop: String = "") -> void:
	st.beats.append({"at": at, "who": who, "do": action, "slot": slot, "target": target, "anim": anim, "prop": prop})


## The thief walks to the pen, takes the goose or a sack of grain and carries it home; or, with the player watching,
## stops short, looks about and walks off empty-handed.
static func _theft(V: S.Village, it: Dictionary, done: bool) -> Dictionary:
	var p := V.people[int(it.actor)]
	var place := int(it.place)
	var start := int(it.minute)
	var walk := _walk_minutes(V, p, start, place)
	var h := V.households[int(it.target)]
	var st := _base(V, "theft", place, start, start + walk + 20, p.id, [p.id], "done" if done else "abandoned",
		("someone hurrying away from the %s pen with something under an arm" % h.home) if done else ("%s lingering by the %s pen, then walking off" % [p.name, h.home]))
	if done:
		_beat(st, start, p.id, "walk_to", -1, -1, "Walk")
		_beat(st, start + walk + 1, p.id, "gesture", -1, -1, "Interact")
		_beat(st, start + walk + 3, p.id, "leave", -1, -1, "Walk_Carry", "sack" if h.geese <= 0 else "goose")
	else:
		_beat(st, start, p.id, "walk_to", 0, -1, "Walk")
		_beat(st, start + walk + 1, p.id, "stand", 0, -1, "Idle_No")
		_beat(st, start + walk + 5, p.id, "leave", -1, -1, "Walk")
	return st


## Two people face each other and have it out; with blows, a shove and a stagger.
static func _quarrel(V: S.Village, it: Dictionary, blows: bool) -> Dictionary:
	var a := V.people[int(it.actor)]
	var b := V.people[int(it.other)]
	var place := int(it.place)
	var start := int(it.minute)
	var arrive := maxi(_walk_minutes(V, a, start, place), _walk_minutes(V, b, start, place))
	var t := start + arrive + 1
	var st := _base(V, "quarrel", place, start, t + 16, a.id, [a.id, b.id], "blows" if blows else "words",
		"%s and %s shouting at the %s" % [a.name, b.name, V.place_names[place]])
	_beat(st, start, a.id, "walk_to", 0, -1, "Walk")
	_beat(st, start, b.id, "walk_to", 1, -1, "Walk")
	_beat(st, t, a.id, "stand", 0, b.id, "Idle_FoldArms")
	_beat(st, t, b.id, "stand", 1, a.id, "Idle_FoldArms")
	_beat(st, t + 1, a.id, "gesture", 0, b.id, "Idle_No")
	_beat(st, t + 3, b.id, "gesture", 1, a.id, "Idle_No")
	_beat(st, t + 5, a.id, "gesture", 0, b.id, "Idle_No")
	if blows:
		_beat(st, t + 7, a.id, "gesture", 0, b.id, "Push")
		_beat(st, t + 8, b.id, "react", 1, a.id, "Hit_Chest")
	_beat(st, t + 11, a.id, "leave", -1, -1, "Walk")
	_beat(st, t + 13, b.id, "leave", -1, -1, "Walk")
	return st


## Two who get on: a word and a laugh where they meet (chat); or one carries a sack to the other's door (help).
static func _pair(V: S.Village, it: Dictionary) -> Dictionary:
	var a := V.people[int(it.actor)]
	var b := V.people[int(it.other)]
	var place := int(it.place)
	var start := int(it.minute)
	var t := start + maxi(_walk_minutes(V, a, start, place), _walk_minutes(V, b, start, place)) + 1
	var chat: bool = it.kind == "chat"
	var st := _base(V, it.kind, place, start, t + 14, a.id, [a.id, b.id], "done",
		("%s and %s laughing at the %s" % [a.name, b.name, V.place_names[place]]) if chat else ("%s carrying a sack to %s's door" % [a.name, b.name]))
	if chat:
		_beat(st, start, a.id, "walk_to", 0, -1, "Walk")
		_beat(st, start, b.id, "walk_to", 1, -1, "Walk")
		_beat(st, t, a.id, "stand", 0, b.id, "Idle_Talking")
		_beat(st, t, b.id, "stand", 1, a.id, "Idle_Talking")
		_beat(st, t + 4, b.id, "gesture", 1, a.id, "Yes")
	else:
		_beat(st, start, a.id, "carry", -1, -1, "Walk_Carry", "sack")
		_beat(st, start, b.id, "walk_to", 0, -1, "Walk")
		_beat(st, t, a.id, "gesture", -1, b.id, "Interact")
		_beat(st, t + 1, b.id, "gesture", 0, a.id, "Yes")
	_beat(st, t + 9, a.id, "leave", -1, -1, "Walk")
	_beat(st, t + 10, b.id, "leave", -1, -1, "Walk")
	return st


## Children chasing about near the player.
static func _play(V: S.Village, it: Dictionary) -> Dictionary:
	var kids: Array = it.others
	var place := int(it.place)
	var start := int(it.minute)
	var st := _base(V, "play", place, start, start + 26, int(kids[0]), kids, "done", "children shrieking, running rings round the %s" % V.place_names[place])
	for round_i in 3:
		for i in kids.size():
			_beat(st, start + round_i * 6 + i, int(kids[i]), "walk_to", (i + round_i) % 4, -1, "Jog_Fwd")
	for i in kids.size():
		_beat(st, start + 20 + i, int(kids[i]), "leave", -1, -1, "Jog_Fwd")
	return st


## A neighbour carries bread to a hungry house; someone at home takes it with a nod.
static func _kindness(V: S.Village, it: Dictionary) -> Dictionary:
	var p := V.people[int(it.actor)]
	var place := int(it.place)
	var start := int(it.minute)
	var walk := _walk_minutes(V, p, start, place)
	var host := -1
	for m in V.households[int(it.target)].members:
		var q := V.people[m]
		if q.alive and q.present and not q.locked and Village.place_at(q, start + walk) == place:
			host = m
			break
	var ids := [p.id] if host < 0 else [p.id, host]
	var st := _base(V, "kindness", place, start, start + walk + 14, p.id, ids, "done",
		"%s at the %s door with bread" % [p.name, V.households[int(it.target)].home])
	_beat(st, start, p.id, "carry", -1, -1, "Walk_Carry", "bread")
	_beat(st, start + walk + 1, p.id, "gesture", -1, host, "Interact")
	if host >= 0:
		_beat(st, start + walk + 2, host, "gesture", 0, p.id, "Yes")
	_beat(st, start + walk + 5, p.id, "leave", -1, -1, "Walk")
	return st