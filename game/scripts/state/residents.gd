extends Node
## The meadow village's residents (game state, no visuals): people with a home, a trade and a day.
## Their bodies and words are in state/npcs.gd (entries with "resident"); world/npc.gd walks them through
## the day and world/visit_interior.gd shows them indoors. Each has their own goods (what they make while
## working, which they'll sell you) and a liking for you that gifts raise (cheaper goods, a present
## now and then). From Hilmi's living-village ideas (studio branch), kept small.

signal changed

const PER_HOUR := 30.0                  # real seconds of an in-game hour (a 12-minute day)
const GOODS_CAP := 12
const FRIEND_GIFT_AT := [4, 10]         # liking at which they give you something back

var goods := {}                         # resident -> {item: count}
var liking := {}                        # resident -> int
var _gifted := {}                       # resident -> how many thank-you presents given
var _work_secs := {}


func _ready() -> void:
	_reset()


func _reset() -> void:
	goods = {}
	liking = {}
	_gifted = {}
	for id: String in ids():
		goods[id] = (Npcs.NPCS[id]["resident"]["goods"] as Dictionary).duplicate()
		liking[id] = 0
		_gifted[id] = 0


static func ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in Npcs.NPCS:
		if Npcs.NPCS[id].has("resident"):
			out.append(id)
	return out


static func def(id: String) -> Dictionary:
	return Npcs.NPCS[id]["resident"]


## The time of day (0..1, 0.25 dawn), from the world's clock.
func now() -> float:
	var scene := get_tree().current_scene
	var dn := scene.get_node_or_null("WorldEnvironment") if scene else null
	return float(dn.time_of_day) if dn and "time_of_day" in dn else 0.4


## What they're doing now: "home" (indoors), "work", "lunch" (on the green) or "evening" (by the fire).
func activity(id: String, t := -1.0) -> String:
	if t < 0.0:
		t = now()
	var r := def(id)
	if t < r.get("up", 0.27) or t >= r.get("bed", 0.85):
		return "home"
	if t >= 0.5 and t < 0.56:
		return "lunch"
	if t >= 0.76:
		return "evening"
	return "work"


## Where that happens (x, z): the work spot, a place on the green or by the fire, or their front door.
func anchor(id: String, act: String) -> Vector2:
	var r := def(id)
	match act:
		"work":
			return r["work"]
		"lunch":
			return r["lunch"]
		"evening":
			return r["evening"]
	return door(id)


func door(id: String) -> Vector2:
	return preload("res://scripts/world/village.gd").door_of(def(id)["house"])


## While they work they make things (up to a cap).
func _process(delta: float) -> void:
	if Region.current != "meadow":
		return
	for id: String in goods:
		if activity(id) != "work":
			continue
		_work_secs[id] = _work_secs.get(id, 0.0) + delta
		if _work_secs[id] >= PER_HOUR:
			_work_secs[id] = 0.0
			var make: String = (def(id)["makes"] as Array).pick_random()
			var total := 0
			for n: int in goods[id].values():
				total += n
			if total < GOODS_CAP:
				goods[id][make] = int(goods[id].get(make, 0)) + 1
				changed.emit()


func price(id: String, item: String) -> int:
	var off := 1.0 - 0.05 * mini(int(liking.get(id, 0)), 6)
	return maxi(1, roundi(Balance.VALUES.get(item, 2) * 3.0 * off))


## The action: buy one of their goods. False if they're out of it or you can't pay.
func buy(id: String, item: String) -> bool:
	if int(goods[id].get(item, 0)) <= 0 or not Inventory.has_room(item) or not Money.spend(price(id, item)):
		return false
	goods[id][item] -= 1
	if goods[id][item] <= 0:
		goods[id].erase(item)
	Inventory.add(item)
	changed.emit()
	return true


## The action: give them something. Returns what they say back (and maybe a present).
func give(id: String, item: String) -> String:
	if not Inventory.remove(item, 1):
		return ""
	var loved: bool = item in def(id)["likes"]
	liking[id] = int(liking.get(id, 0)) + (2 if loved else 1)
	var says: String = def(id)["loved"] if loved else def(id)["thanks"]
	var g: int = _gifted[id]
	if g < FRIEND_GIFT_AT.size() and liking[id] >= FRIEND_GIFT_AT[g]:
		_gifted[id] = g + 1
		var present: String = def(id)["present"][g]
		Inventory.add(present)
		says += " " + def(id)["present_line"] % Items.DEFS[present]["name"].to_lower()
	changed.emit()
	return says


## The talk screen when they have no quest for you (Quests.talk): a line for the time of day, then
## their goods, a gift, or goodbye.
func talk(id: String) -> Dictionary:
	var lines: Dictionary = def(id)["lines"]
	var act := activity(id)
	var text: String = (lines.get(act, lines["work"]) as Array).pick_random()
	if int(liking.get(id, 0)) >= 4:
		text = (def(id)["friendly"] as Array).pick_random() + " " + text
	return _screen(text, [
		{"label": "Your goods?", "do": func() -> Dictionary: return _goods_screen(id, def(id)["goods_line"])},
		{"label": "A gift", "do": func() -> Dictionary: return _gift_screen(id)},
		{"label": "Bye", "do": func() -> Dictionary: return {}}])


func _goods_screen(id: String, text: String) -> Dictionary:
	var options := []
	for item: String in goods[id]:
		if options.size() >= 3:
			break
		var p := price(id, item)
		options.append({"label": "%s ×%d · %d" % [Items.DEFS[item]["name"], goods[id][item], p], "do": func() -> Dictionary:
			if buy(id, item):
				return _goods_screen(id, "There you are. Anything else?")
			return _goods_screen(id, "You can't carry it, or you're short of coin." if Money.coins >= p else "That's %d coins, and you're short." % p)})
	if options.is_empty():
		text = "I've nothing left today. Come back after I've done some work."
	options.append({"label": "That's all", "do": func() -> Dictionary: return {}})
	return _screen(text, options)


func _gift_screen(id: String) -> Dictionary:
	var options := []
	var offer: Array = def(id)["likes"] + ["apple", "flower", "roast_meat", "skewer", "mushroom", "apple_tart", "stew", "cigarette"]
	var seen := {}
	for item: String in offer:
		if options.size() >= 3:
			break
		if seen.has(item) or Inventory.count(item) <= 0:
			continue
		seen[item] = true
		options.append({"label": Items.DEFS[item]["name"], "do": func() -> Dictionary:
			var reply := give(id, item)
			var s := _screen(reply, [{"label": "Glad you like it", "do": func() -> Dictionary: return {}}])
			s["emote"] = "Yes"
			return s})
	if options.is_empty():
		return _screen("That's kind, but your hands are empty. Something to eat, maybe? Or flowers.", [{"label": "Right", "do": func() -> Dictionary: return {}}])
	options.append({"label": "Not yet", "do": func() -> Dictionary: return {}})
	return _screen("For me? What is it?", options)


func _screen(text: String, options: Array) -> Dictionary:
	return {"text": text, "options": options}


func to_data() -> Dictionary:
	return {"goods": goods.duplicate(true), "liking": liking.duplicate(), "gifted": _gifted.duplicate()}


func load_data(data: Variant) -> void:
	_reset()
	if data is Dictionary:
		for id: String in ids():
			if data.get("goods", {}).has(id):
				goods[id] = {}
				for item: String in data["goods"][id]:
					if Items.DEFS.has(item):
						goods[id][item] = int(data["goods"][id][item])
			liking[id] = int(data.get("liking", {}).get(id, 0))
			_gifted[id] = int(data.get("gifted", {}).get(id, 0))
	changed.emit()
