extends RefCounted
## The staging contract: how the village simulation (tier V) tells the stage (tier E) what to play.
## A staging is plain data (ints and strings), so it hashes, logs and replays like everything else; the
## simulation makes them, the stage only plays them. Time is in game minutes (a game day is 1440 minutes
## and lasts 12 real minutes, so one game minute is 0.5 real seconds at normal speed).
##
## staging = {
##   "id": int, "kind": String (see KINDS), "place": String (a sites.gd place),
##   "start": int (game minute), "end": int,
##   "phases": [{"name": String, "from": int, "to": int, "rescue": bool}],   # rescue: the player can still save them
##   "roles": {"victim": int, "accuser": int, "authority": int, "crowd": [int]},   # person ids (-1 if none)
##   "beats": [{"at": int, "who": int, "do": String (see ACTIONS), "slot": int, "target": int,
##              "anim": String, "prop": String}],   # sorted by (at, who)
##   "outcome": String (see OUTCOMES), "cause": [String],   # the readable cause chain, for tests and tales
## }
## people = [{"id": int, "name": String, "outfit": int (index into CharacterLook.OUTFITS keys),
##            "home": String (a sites.gd home), "role": String, "marks": [String]}]

const Sites := preload("res://scripts/studio/village/sites.gd")
const KINDS := ["pillory", "stoning", "hanging", "bonfire", "trial", "trial_by_combat", "exile", "sacrifice",
	"festival", "funeral", "gossip", "mob",
	"theft", "quarrel", "kindness", "alarm", "gathering"]   # appended (Pass 2): small scenes of 1-6 people, 5-30 minutes, no device, no decision
## What a body can be told to do. "walk_to" and "stand" use slot (a crowd slot at the place, sites.slot) or,
## with slot -1, the place itself; "throw" hurls prop at target; "lock"/"release" put the victim in or out of
## the place's device (pillory, stake); "leave" walks home.
const ACTIONS := ["walk_to", "stand", "gesture", "throw", "react", "lock", "release", "carry", "leave", "fall"]
const OUTCOMES := ["carried_out", "commuted", "rescued", "crowd_turned", "acquitted", "confessed_spared",
	"venerated", "fled", "pending",
	"done", "abandoned", "blows", "words"]   # appended (Pass 2): how a small scene ended (sim/incidents.gd)
## Animations the stage may be asked for (Quaternius UAL1 and UAL2, names as imported).
const ANIMS := ["Idle", "Walk", "Walk_Formal", "Walk_Carry", "Jog_Fwd", "Idle_FoldArms", "Idle_No", "Yes",
	"Idle_Talking", "Idle_Torch", "OverhandThrow", "Hit_Head", "Hit_Chest", "Crouch_Idle", "Fixing_Kneeling",
	"Spell_Simple_Idle", "Spell_Simple_Shoot", "Dance", "Death01", "Push", "Interact", "Sitting_Idle", "Consume",
	"Idle_Rail"]   # appended (stage 2): bent forward over a rail, the pillory's pose (props.gd VICTIM_POSE)
## Things that can be thrown or carried (props the stage makes).
const PROPS := ["cabbage", "turnip", "mud", "stone", "flower", "wood", "torch",
	"goose", "sack", "basket", "bread"]   # appended (Pass 2): props.gd builds them; carried by a `carry`, or by a `leave` that names one


## A hand-made staging for building the stage before the simulation exists: a pillory in the square.
## A thief is locked in; a crowd gathers; jeering turns to pelting (vegetables, then mud, then stones as
## anger rises) until the elder releases them at dusk. Twelve villagers; person 0 is the victim, 1 the
## accuser (whose goose was stolen), 2 the elder.
static func demo_pillory() -> Array:
	var people := []
	var names := ["Aldric", "Mara", "Old Wenna", "Tobin", "Ilse", "Garrow", "Petra", "Hob", "Sella", "Bram", "Nell", "Oswin"]
	var homes := ["cottage", "cabin", "lodge", "round", "hill", "loaf"]
	for i in names.size():
		people.append({"id": i, "name": names[i], "outfit": (i * 5) % 13, "home": homes[i % homes.size()],
			"role": ["thief", "goosewife", "elder"][i] if i < 3 else "villager", "marks": []})
	var t0 := 8 * 60   # 08:00 on day 0
	var beats := []
	beats.append({"at": t0, "who": 2, "do": "walk_to", "slot": -1, "target": -1, "anim": "Walk_Formal", "prop": ""})
	beats.append({"at": t0, "who": 0, "do": "walk_to", "slot": -1, "target": -1, "anim": "Walk", "prop": ""})
	beats.append({"at": t0 + 10, "who": 0, "do": "lock", "slot": -1, "target": -1, "anim": "Crouch_Idle", "prop": ""})
	for i in range(1, 12):
		beats.append({"at": t0 + 5 + i * 3, "who": i, "do": "walk_to", "slot": i - 1, "target": -1, "anim": "Walk", "prop": ""})
		beats.append({"at": t0 + 20 + i * 3, "who": i, "do": "stand", "slot": i - 1, "target": -1,
			"anim": ["Idle_FoldArms", "Idle_No", "Idle_Talking"][i % 3], "prop": ""})
	# jeering, then pelting that escalates: vegetables, mud, then stones from the angriest
	var thrown := [["cabbage", "turnip"], ["mud"], ["stone"]]
	for wave in 3:
		for k in 6:
			var who := 1 + ((wave * 5 + k * 3) % 11)
			var at := t0 + 60 + wave * 90 + k * 12
			beats.append({"at": at, "who": who, "do": "throw", "slot": who - 1, "target": 0, "anim": "OverhandThrow",
				"prop": thrown[wave][k % thrown[wave].size()]})
			beats.append({"at": at + 1, "who": 0, "do": "react", "slot": -1, "target": who,
				"anim": "Hit_Head" if wave == 2 else "Hit_Chest", "prop": ""})
	var end := t0 + 360
	beats.append({"at": end, "who": 2, "do": "release", "slot": -1, "target": 0, "anim": "Interact", "prop": ""})
	for i in 12:
		beats.append({"at": end + 5 + i, "who": i, "do": "leave", "slot": -1, "target": -1, "anim": "Walk", "prop": ""})
	beats.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["at"] < b["at"] or (a["at"] == b["at"] and a["who"] < b["who"]))
	var staging := {
		"id": 1, "kind": "pillory", "place": "pillory", "start": t0, "end": end + 20,
		"phases": [{"name": "gather", "from": t0, "to": t0 + 60, "rescue": true},
			{"name": "jeer and pelt", "from": t0 + 60, "to": end, "rescue": true},
			{"name": "release", "from": end, "to": end + 20, "rescue": false}],
		"roles": {"victim": 0, "accuser": 1, "authority": 2, "crowd": range(1, 12)},
		"beats": beats, "outcome": "carried_out",
		"cause": ["Aldric was hungry after a failed harvest", "he took Mara's goose at night", "Hob saw him by the pen",
			"Hob told Mara; Tobin had seen feathers by Aldric's door", "two sources: a case", "the elder chose the pillory (petty theft, village law)"],
	}
	return [staging, people]


## Hand-made small scenes, one of each incident kind, for building and checking the stage before the simulation
## sends its own (sim/incidents.gd): returns [staging, people] like demo_pillory. `kind` is a KINDS entry, or
## "theft_abandoned" (the thief the player scared off). Six villagers; person 0 is at home at the cabin for the kindness.
##   theft      the thief walks to a pen, takes the goose (an Interact), leaves with it under an arm
##   quarrel    two meet at the well, face to face, shake their heads at each other, then a shove and a stagger
##   kindness   a neighbour carries bread to the cabin door, hands it over (the host nods), leaves it on the step
##   alarm      someone runs to the square pointing and shouting; three neighbours run in, dismayed
##   gathering  five stand in a ring at the well, talking, nodding, one turning away
static func demo_incident(kind: String) -> Array:
	var people := []
	var names := ["Hob", "Mara", "Tobin", "Ilse", "Garrow", "Petra"]
	var homes := ["cottage", "cabin", "loaf", "hill", "lodge", "round"]
	var t0 := 9 * 60
	var beats := []
	var place := "square"
	var outcome := "done"
	var real_kind := kind
	var who_ids: Array = []
	var subject := 1
	match kind:
		"theft":
			place = "pen_hill"
			homes[1] = "cabin"
			subject = 1
			who_ids = [1]
			var t := t0 + _walk_min(homes[1], place)
			beats.append(_beat(t0, 1, "walk_to", -1, -1, "Walk"))
			beats.append(_beat(t + 1, 1, "gesture", -1, -1, "Interact"))
			beats.append(_beat(t + 4, 1, "leave", -1, -1, "Walk_Carry", "goose"))
		"theft_abandoned":
			real_kind = "theft"
			place = "pen_hill"
			homes[1] = "cabin"
			outcome = "abandoned"
			subject = 1
			who_ids = [1]
			var t := t0 + _walk_min(homes[1], place)
			beats.append(_beat(t0, 1, "walk_to", 0, -1, "Walk"))
			beats.append(_beat(t + 1, 1, "stand", 0, -1, "Idle_No"))
			beats.append(_beat(t + 7, 1, "leave", -1, -1, "Walk"))
		"quarrel":
			place = "well"
			homes[0] = "round"
			homes[1] = "hill"
			outcome = "blows"
			subject = 0
			who_ids = [0, 1]
			var t := t0 + maxi(_walk_min(homes[0], place), _walk_min(homes[1], place)) + 1
			beats.append(_beat(t0, 0, "walk_to", 0, -1, "Walk"))
			beats.append(_beat(t0, 1, "walk_to", 1, -1, "Walk"))
			beats.append(_beat(t, 0, "stand", 0, 1, "Idle_FoldArms"))
			beats.append(_beat(t, 1, "stand", 1, 0, "Idle_FoldArms"))
			beats.append(_beat(t + 2, 0, "gesture", 0, 1, "Idle_No"))
			beats.append(_beat(t + 4, 1, "gesture", 1, 0, "Idle_No"))
			beats.append(_beat(t + 6, 0, "gesture", 0, 1, "Idle_No"))
			beats.append(_beat(t + 8, 0, "gesture", 0, 1, "Push"))
			beats.append(_beat(t + 9, 1, "react", 1, 0, "Hit_Chest"))
			beats.append(_beat(t + 12, 0, "leave", -1, -1, "Walk"))
			beats.append(_beat(t + 14, 1, "leave", -1, -1, "Walk"))
		"kindness":
			place = "cabin"
			homes[0] = "cabin"
			homes[2] = "hill"
			subject = 2
			who_ids = [2, 0]
			var t := t0 + _walk_min(homes[2], place) + 2
			beats.append(_beat(t0, 2, "carry", -1, -1, "Walk_Carry", "bread"))
			beats.append(_beat(t, 2, "gesture", -1, 0, "Interact"))
			beats.append(_beat(t + 1, 0, "gesture", 0, 2, "Yes"))
			beats.append(_beat(t + 5, 2, "leave", -1, -1, "Walk"))
			beats.append(_beat(t + 7, 0, "leave", -1, -1, "Walk"))
		"alarm":
			place = "square"
			homes[3] = "hill"
			homes[0] = "cottage"
			homes[1] = "cabin"
			homes[2] = "round"
			subject = 3
			who_ids = [3, 0, 1, 2]
			var t := t0 + _walk_min(homes[3], place) / 2
			beats.append(_beat(t0, 3, "walk_to", 0, -1, "Jog_Fwd"))
			beats.append(_beat(t + 2, 3, "gesture", 0, -1, "Spell_Simple_Shoot"))
			for i in 3:
				beats.append(_beat(t0 + 3 + i * 2, i, "walk_to", i + 1, -1, "Jog_Fwd"))
				beats.append(_beat(t + 10 + i, i, "stand", i + 1, -1, ["Idle_No", "Idle_FoldArms", "Idle_No"][i]))
			beats.append(_beat(t + 13, 3, "gesture", 0, -1, "Spell_Simple_Shoot"))
			for i in 4:
				beats.append(_beat(t + 22 + i * 2, [3, 0, 1, 2][i], "leave", -1, -1, "Walk"))
		"gathering":
			place = "well"
			homes = ["round", "hill", "cabin", "cottage", "lodge", "round"]
			subject = 0
			who_ids = [0, 1, 2, 3, 4]
			var talk := ["Idle_Talking", "Idle_FoldArms", "Yes", "Idle_Talking", "Idle_No"]
			var t := t0 + 18
			for i in 5:
				beats.append(_beat(t0 + i * 2, i, "walk_to", i, -1, "Walk"))
				beats.append(_beat(t + i, i, "stand", i, -1, talk[i]))
			beats.append(_beat(t + 12, 2, "gesture", 2, -1, "Yes"))
			beats.append(_beat(t + 16, 4, "gesture", 4, 3, "Idle_No"))
			for i in 5:
				beats.append(_beat(t + 22 + i * 2, i, "leave", -1, -1, "Walk"))
		_:
			push_warning("staging: no demo for " + kind)
	for i in names.size():
		people.append({"id": i, "name": names[i], "outfit": (i * 5 + 2) % 13, "home": homes[i], "role": "villager", "marks": []})
	beats.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["at"] < b["at"] or (a["at"] == b["at"] and a["who"] < b["who"]))
	var end := t0 + 30
	for b: Dictionary in beats:
		end = maxi(end, int(b["at"]) + 20)
	var cast := []
	for person: Dictionary in people:
		if who_ids.has(person["id"]):
			cast.append(person)
	var staging := {
		"id": 100 + KINDS.find(real_kind), "kind": real_kind, "place": place, "start": t0, "end": end,
		"phases": [{"name": "scene", "from": t0, "to": end, "rescue": false}],
		"roles": {"victim": subject, "accuser": -1, "authority": -1, "crowd": []},
		"beats": beats, "outcome": outcome, "cause": ["a small scene: " + kind], "cue": "a small scene: " + kind, "day": 0, "people": cast,
	}
	return [staging, cast]


## Game minutes a person takes to walk from a home's door to a place (0.65 m per game minute at a stroll), plus one.
static func _walk_min(home: String, place: String) -> int:
	var pens := {"pen_cottage": Vector2(-7.0, 10.0), "pen_hill": Vector2(10.0, 25.0)}
	var to: Vector2 = pens.get(place, Sites.at(place))
	return int(ceil(Sites.at(home).distance_to(to) / 0.62)) + 1


static func _beat(at: int, who: int, action: String, slot: int, target: int, anim: String, prop := "") -> Dictionary:
	return {"at": at, "who": who, "do": action, "slot": slot, "target": target, "anim": anim, "prop": prop}


## Checks a staging against the contract; returns a list of problems (empty if valid).
static func validate(staging: Dictionary, people: Array) -> PackedStringArray:
	var problems := PackedStringArray()
	for k in ["id", "kind", "place", "start", "end", "phases", "roles", "beats", "outcome", "cause"]:
		if not staging.has(k):
			problems.append("missing " + k)
	if not problems.is_empty():
		return problems
	if not KINDS.has(staging["kind"]):
		problems.append("unknown kind " + str(staging["kind"]))
	if not OUTCOMES.has(staging["outcome"]):
		problems.append("unknown outcome " + str(staging["outcome"]))
	var ids := {}
	for p: Dictionary in people:
		ids[p["id"]] = true
	var last := -2147483648 # night preparation may belong to the preceding calendar day
	for b: Dictionary in staging["beats"]:
		if not ACTIONS.has(b["do"]):
			problems.append("unknown action " + str(b["do"]))
		if b["anim"] != "" and not ANIMS.has(b["anim"]):
			problems.append("unknown anim " + str(b["anim"]))
		if b["prop"] != "" and not PROPS.has(b["prop"]):
			problems.append("unknown prop " + str(b["prop"]))
		if not ids.has(b["who"]):
			problems.append("beat for unknown person %d" % b["who"])
		if b["at"] < last:
			problems.append("beats out of order at minute %d" % b["at"])
		last = b["at"]
	return problems
