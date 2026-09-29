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

const KINDS := ["pillory", "stoning", "hanging", "bonfire", "trial", "trial_by_combat", "exile", "sacrifice",
	"festival", "funeral", "gossip", "mob"]
## What a body can be told to do. "walk_to" and "stand" use slot (a crowd slot at the place, sites.slot) or,
## with slot -1, the place itself; "throw" hurls prop at target; "lock"/"release" put the victim in or out of
## the place's device (pillory, stake); "leave" walks home.
const ACTIONS := ["walk_to", "stand", "gesture", "throw", "react", "lock", "release", "carry", "leave", "fall"]
const OUTCOMES := ["carried_out", "commuted", "rescued", "crowd_turned", "acquitted", "confessed_spared",
	"venerated", "fled", "pending"]
## Animations the stage may be asked for (Quaternius UAL1 and UAL2, names as imported).
const ANIMS := ["Idle", "Walk", "Walk_Formal", "Walk_Carry", "Jog_Fwd", "Idle_FoldArms", "Idle_No", "Yes",
	"Idle_Talking", "Idle_Torch", "OverhandThrow", "Hit_Head", "Hit_Chest", "Crouch_Idle", "Fixing_Kneeling",
	"Spell_Simple_Idle", "Spell_Simple_Shoot", "Dance", "Death01", "Push", "Interact", "Sitting_Idle", "Consume"]
## Things that can be thrown or carried (props the stage makes).
const PROPS := ["cabbage", "turnip", "mud", "stone", "flower", "wood", "torch"]


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
	var last := -1
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
