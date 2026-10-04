extends Node
## Bounties (game state, no visuals). Each region's bounty board (world/bounty_board.gd) pins three jobs:
## a "hunt" (kill some of a creature in that region), a "gather" (bring items to any board) and a
## "wanted" (a named elite beast waiting somewhere in that region; creatures/enemies.gd brings it out while
## the bounty is taken). New ones go up every in-game day. Take up to three at a time; they show with your
## quests (ids "bounty:<n>", see quests.gd). Claim the reward at any board. Renown (bounties done)
## unlocks bigger, better-paid jobs. Change it only through take(), give_up(), claim() and killed().

signal changed

const MAX_TAKEN := 3
const DAY_SECS := 720.0                  # one day/night cycle (day_night.gd cycle_minutes)
const RENOWN_FOR_STAR := [0, 2, 5]       # renown needed for 1, 2 and 3-star hunts and gathers
const REGION_PAY := {"meadow": 1.0, "forest": 1.5, "highlands": 2.0}
const HUNT_PAY := {"wolf": 14, "boar": 16, "stag": 30, "shadow_wolf": 30, "bandit": 20}   # coins a head
## Where each region's board stands (world/bounty_board.gd).
const BOARDS := {"meadow": Vector2(-3.4, 17.5), "forest": Vector2(-17.5, 25.0), "highlands": Vector2(-13.5, -40.0)}
## Hunts: [creature, plural, fewest, most].
const HUNTS := {
	"meadow": [["wolf", "wolves", 3, 5], ["boar", "boars", 2, 4], ["stag", "stags", 1, 2]],
	"forest": [["wolf", "wolves", 4, 6], ["shadow_wolf", "shadow wolves", 2, 3], ["boar", "boars", 2, 3], ["bandit", "Red Hand bandits", 3, 5]],
	"highlands": [["wolf", "wolves", 4, 6], ["shadow_wolf", "shadow wolves", 2, 3], ["boar", "boars", 2, 3], ["stag", "stags", 2, 3]],
}
## Gathers: [item, fewest, most].
const GATHERS := {
	"meadow": [["wood", 15, 25], ["copper", 6, 10], ["apple", 5, 8], ["hide", 2, 4], ["bluegill", 2, 4], ["flower", 6, 10]],
	"forest": [["pinewood", 10, 16], ["mushroom", 6, 10], ["pelt", 2, 4], ["resin", 1, 2], ["glowcap", 2, 3], ["trout", 2, 3], ["red_hand", 3, 5]],
	"highlands": [["iron", 6, 10], ["pinewood", 12, 18], ["antler", 1, 2], ["stag_hide", 2, 3], ["pelt", 3, 5], ["perch", 3, 4]],
}
## Wanted beasts: a name, the creature it is, a line about it, and where it waits.
const WANTED := {
	"meadow": [
		{"name": "Old Greyjaw", "kind": "wolf", "about": "A grey wolf the size of a pony. Took two of the miller's sheep and the dog that tried to stop it.", "at": Vector2(-70, -70)},
		{"name": "Ironhide", "kind": "boar", "about": "A boar with a hide like a barrel lid. It has broken three fences and one leg.", "at": Vector2(66, 34)},
	],
	"forest": [
		{"name": "Nightfang", "kind": "shadow_wolf", "about": "A shadow wolf that walks the deep wood at all hours. The woodcutters won't go past the hollow.", "at": Vector2(58, 58)},
		{"name": "Rootgut", "kind": "boar", "about": "A huge boar that roots up whole saplings. Fernhollow wants it gone before it finds the gardens.", "at": Vector2(-66, -20)},
	],
	"highlands": [
		{"name": "Frostmane", "kind": "wolf", "about": "A white-maned wolf that comes down off the snow. The shepherds hear it before they see it.", "at": Vector2(-50, 52)},
		{"name": "The Cairn Boar", "kind": "boar", "about": "It sleeps among the old cairns and charges anything that climbs them.", "at": Vector2(52, -64)},
		{"name": "Ashmaw", "kind": "shadow_wolf", "about": "A shadow wolf with a scorched muzzle. Nobody knows where it came from.", "at": Vector2(66, 64)},
	],
}

var renown := 0                       # bounties done
var offers := {}                      # region -> Array of bounties on its board
var taken: Array[Dictionary] = []     # the bounties you're on
var _next_id := 1
var _day_secs := 0.0


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_day_secs += delta
	if _day_secs >= DAY_SECS:
		_day_secs = 0.0
		offers.clear()                    # a new day: every board gets fresh jobs
		changed.emit()


## Seconds until the boards get new jobs.
func next_day_in() -> float:
	return DAY_SECS - _day_secs


## The jobs on a region's board (pinned up when first looked at).
func board(region: String) -> Array:
	if not offers.has(region):
		offers[region] = [_hunt(region), _gather(region), _wanted(region)]
	return offers[region]


## The action: take a bounty off a board. False when you already have three.
func take(b: Dictionary) -> bool:
	if taken.size() >= MAX_TAKEN or not offers.get(b["region"], []).has(b):
		return false
	offers[b["region"]].erase(b)
	taken.append(b)
	Quests.track("bounty:%d" % b["id"])
	changed.emit()
	return true


func give_up(b: Dictionary) -> void:
	taken.erase(b)
	changed.emit()
	Quests.changed.emit()


func progress(b: Dictionary) -> int:
	if b["kind"] == "gather":
		return mini(Inventory.count(b["target"]), b["count"])
	return mini(int(b["have"]), b["count"])


func is_ready(b: Dictionary) -> bool:
	return progress(b) >= b["count"]


## The action: claim a finished bounty at a board. Gathers hand the items over. Pays coins, and a
## wanted beast's bounty a piece of gear. Returns the gear [slot, record], or [] (for the HUD to show).
func claim(b: Dictionary) -> Array:
	if not taken.has(b) or not is_ready(b):
		return []
	if b["kind"] == "gather":
		Inventory.remove(b["target"], b["count"])
	Money.earn(b["coins"])
	var gear: Array = []
	if b["kind"] == "wanted":
		gear = Gear.roll_found("elite")
		Gear.take(gear[0], gear[1])
	taken.erase(b)
	renown += 1
	changed.emit()
	Quests.changed.emit()
	return gear


## The action: something died (creatures call this). Hunts in this region count it; a wanted beast
## ends its bounty.
func killed(kind: String, who: Node) -> void:
	var moved := false
	for b in taken:
		if b["region"] != Region.current or is_ready(b):
			continue
		if b["kind"] == "hunt" and b["target"] == kind \
				or b["kind"] == "wanted" and who.get_meta("bounty_id", -1) == b["id"]:
			b["have"] = int(b["have"]) + 1
			moved = true
			var hud_text := ("Bounty done: %s. Claim it at a bounty board." % b["title"]) if is_ready(b) \
				else "Bounty: %s %d/%d" % [b["plural"], progress(b), b["count"]]
			get_tree().call_group("hud", "hint", hud_text)
	if moved:
		changed.emit()
		Quests.changed.emit()


func find(id: int) -> Dictionary:
	for b in taken:
		if b["id"] == id:
			return b
	return {}


## What the tracker says: "Kill wolves in the Whispering Wood (2/4)".
func step_text(b: Dictionary) -> String:
	if is_ready(b):
		return "Claim the reward at a bounty board"
	match b["kind"]:
		"hunt":
			return "Kill %s in the %s (%d/%d)" % [b["plural"], Region.NAMES[b["region"]], progress(b), b["count"]]
		"gather":
			return "Bring %d %s to a bounty board (%d/%d)" % [b["count"], Items.DEFS[b["target"]]["name"], progress(b), b["count"]]
	return "Hunt down %s (%s)" % [b["title"].trim_prefix("Wanted: "), Region.NAMES[b["region"]]]


## Where to go: {"region", "at"}, or {} for anywhere (the quest guide points there).
func target(b: Dictionary) -> Dictionary:
	if is_ready(b):
		var region: String = Region.current if BOARDS.has(Region.current) else b["region"]
		return {"region": region, "at": BOARDS[region]}
	match b["kind"]:
		"wanted":
			for e in get_tree().get_nodes_in_group("enemy"):
				if e.get_meta("bounty_id", -1) == b["id"] and e.is_alive():
					return {"region": b["region"], "at": Vector2(e.global_position.x, e.global_position.z)}
			return {"region": b["region"], "at": b["at"]}
		"hunt":
			return {"region": b["region"], "at": b["at"]}
	return {}


## The wanted bounties you're on in this region whose beast is still out there (creatures/enemies.gd).
func wanted_here() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b in taken:
		if b["kind"] == "wanted" and b["region"] == Region.current and not is_ready(b):
			out.append(b)
	return out


## Stars a new hunt or gather may have, from your renown.
func _stars() -> int:
	var top := 1
	for i in RENOWN_FOR_STAR.size():
		if renown >= RENOWN_FOR_STAR[i]:
			top = i + 1
	return randi_range(maxi(1, top - 1), top)


func _new(region: String, kind: String) -> Dictionary:
	var b := {"id": _next_id, "region": region, "kind": kind, "have": 0}
	_next_id += 1
	return b


func _hunt(region: String) -> Dictionary:
	var h: Array = HUNTS[region].pick_random()
	var stars := _stars()
	var b := _new(region, "hunt")
	b["target"] = h[0]
	b["plural"] = h[1]
	b["count"] = randi_range(h[2], h[3]) + (stars - 1)
	b["stars"] = stars
	b["coins"] = roundi((20 + b["count"] * HUNT_PAY[h[0]]) * REGION_PAY[region] * (1.0 + 0.35 * (stars - 1)))
	b["title"] = "Cull the %s" % h[1]
	b["about"] = "The %s around here have got bold. Thin them out." % h[1]
	var homes: Dictionary = preload("res://scripts/creatures/enemies.gd").HOMES[region]
	var key: String = {"wolf": "wolves", "shadow_wolf": "shadow", "boar": "boars", "stag": "stags"}.get(h[0], "")
	b["at"] = (homes[key] as Array).pick_random() if key != "" and not (homes[key] as Array).is_empty() else Vector2(74, 10)
	return b


func _gather(region: String) -> Dictionary:
	var g: Array = GATHERS[region].pick_random()
	var stars := _stars()
	var b := _new(region, "gather")
	b["target"] = g[0]
	b["plural"] = Items.DEFS[g[0]]["name"]
	b["count"] = roundi(randi_range(g[1], g[2]) * (1.0 + 0.4 * (stars - 1)))
	b["stars"] = stars
	var value: int = Balance.VALUES.get(g[0], 2)
	b["coins"] = roundi((value * b["count"] * 1.8 + 20) * (1.0 + 0.25 * (stars - 1)))
	b["title"] = "Bring %d %s" % [b["count"], Items.DEFS[g[0]]["name"]]
	b["about"] = "Someone in the village is short of %s. Bring it to any board." % Items.DEFS[g[0]]["name"].to_lower()
	return b


func _wanted(region: String) -> Dictionary:
	var taken_names := taken.map(func(t: Dictionary) -> String: return t.get("title", ""))
	var pool: Array = WANTED[region].filter(func(w: Dictionary) -> bool: return not ("Wanted: " + w["name"]) in taken_names)
	if pool.is_empty():
		return _hunt(region)
	var w: Dictionary = pool.pick_random()
	var b := _new(region, "wanted")
	b["target"] = w["kind"]
	b["plural"] = w["name"]
	b["count"] = 1
	b["stars"] = 3
	b["coins"] = roundi(160 * REGION_PAY[region])
	b["title"] = "Wanted: " + w["name"]
	b["about"] = w["about"]
	b["at"] = w["at"]
	return b


func to_data() -> Dictionary:
	var list := []
	for b in taken:
		var d := b.duplicate()
		if d.has("at"):
			d["at"] = [d["at"].x, d["at"].y]
		list.append(d)
	return {"renown": renown, "taken": list, "next_id": _next_id, "day_secs": _day_secs}


func load_data(data: Variant) -> void:
	renown = 0
	taken = []
	offers = {}
	_next_id = 1
	_day_secs = 0.0
	if data is Dictionary:
		renown = int(data.get("renown", 0))
		_next_id = int(data.get("next_id", 1))
		_day_secs = float(data.get("day_secs", 0.0))
		for d: Variant in data.get("taken", []):
			if d is Dictionary and d.has("kind") and d.has("region"):
				var b: Dictionary = d.duplicate()
				for k in ["id", "count", "have", "stars", "coins"]:
					b[k] = int(b.get(k, 0))
				if b.get("at") is Array:
					b["at"] = Vector2(b["at"][0], b["at"][1])
				taken.append(b)
	changed.emit()
