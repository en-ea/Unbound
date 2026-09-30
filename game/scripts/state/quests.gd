extends Node
## Quests (game state, no visuals). Change it only through accept() and turn_in(). Each quest has a
## giver (see state/npcs.gd), the words they say at each point, steps, and rewards. A step is either
## "have" (finishes by itself as soon as you carry the items) or "turn_in" (you hand the items to the
## giver when you talk to them). What you see: the tracker (ui/quest_tracker.gd) and the talk screen
## (ui/dialogue_panel.gd, built from talk()).
## A quest is "story" (the main thread; "auto" ones need no giver and are done when their events
## happen) or a "job" someone gave you. Each step can say "where" it happens, so the guide beam
## (world/quest_guide.gd) and the minimap can point there; a hand-in step points at the giver.

signal changed
signal completed(id: String)

const TYPE_NAMES := {"story": "Story", "job": "Job"}

const DEFS := {
	"strange_hum": {
		"giver": "", "name": "A Strange Hum", "type": "story", "auto": true,
		"about": "The standing stones on the meadow hill have started to hum, and beams of light rise over them. Something up there is waking.",
		"steps": [
			{"kind": "event", "event": "awakened", "text": "Go to the standing stones on the hill", "where": {"region": "meadow", "at": "hill"}},
		],
	},
	"wren_smokes": {
		"giver": "wren", "name": "Wren's Smokes",
		"offer": "Hm. You have the look of someone who's never had a proper smoke. The wild leaf grows in the open out on the grass, big and gold. Bring me four, and I'll show you how it's done.",
		"accepted": "Four leaves. Mind the stalks, they're proud things. There should be some out in the meadow, west of the houses.",
		"steps": [
			{"kind": "have", "text": "Pick wild tobacco", "items": {"tobacco": 4}, "or": {"cigarette": 1},
				"where": {"region": "meadow", "at": Vector2(-13.0, 28.0)},
				"say": "Four leaves, that's all. They grow out in the open. Keep an eye out for the tall ones with the pink flowers."},
			{"kind": "have", "text": "Roll cigarettes at a campfire", "items": {"cigarette": 3},
				"where": {"region": "meadow", "at": Vector2(-3.5, 27.0)},
				"say": "You've got the leaf. Any campfire will do, there is one down past the round house. Two leaves and a bit of wood make three. Roll three and bring them here."},
			{"kind": "turn_in", "text": "Bring the cigarettes to Wren", "items": {"cigarette": 3},
				"say": "Well now. Three of them, and rolled properly. Let me see."},
		],
		"thanks": "Not bad at all. Better than my first. Keep the spare leaf, I've plenty, and take this for your trouble. Light one up when the day gets long.",
		"reward": {"coins": 60, "items": {"tobacco": 5}},
	},
	"harvest_supper": {
		"giver": "wren", "name": "The Harvest Supper",
		"offer": "Supper's coming, the proper one, end of harvest. Everyone eats. Except this year there's no stag for the spit. They graze out on the open grass, big red things with crowns on their heads. Run at them and they're gone. Creep. Bring a whole one to the butcher's rack, fresh, and I'll see you right.",
		"accepted": "Whole, mind, not carved. Drag it if you have to, or take the ox cart by the rack. And quick about it: meat doesn't wait.",
		"steps": [
			{"kind": "event", "event": "sold_stag", "text": "Bring a whole stag to the butcher's rack",
				"where": {"region": "meadow", "at": Vector2(46.0, -22.0)},
				"say": "No stag yet? They're out on the open grass. Sneak up on them, they spook at a run."},
			{"kind": "turn_in", "text": "Tell Wren the stag's in", "items": {},
				"say": "I heard the butcher whistling from here. Is that our stag?"},
		],
		"thanks": "That's a supper, then. You'll sit at the long table with the rest of us. Here, for your trouble, and some stew to keep you going till then.",
		"reward": {"coins": 120, "items": {"stew": 2}},
	},
	"morrow_seal": {
		"giver": "morrow", "name": "The Black Seal",
		"offer": "You have a steady hand. Good. There is a man in the eastern wood who calls himself Varek. His Red Hand take from the road, and the road has had enough. I want him not to see another morning. And at his throat he wears a black seal on a chain. That you bring to me. Not to the trader. Not to the smith. To me.",
		"accepted": "East, deep in the Whispering Wood, past the old hill. Stakes and red banners. They keep a lookout. Go quietly and you choose who dies first. Go loudly and they choose for you.",
		"steps": [
			{"kind": "have", "text": "Take Varek's black seal (Red Hand camp, east of the Whispering Wood)", "items": {"black_seal": 1},
				"where": {"region": "forest", "at": Vector2(74.0, 10.0)},
				"say": "Varek. The camp in the east of the wood. Crouch, stay out of their eyes, and they never know you were there. His seal, remember. Not his coin."},
			{"kind": "turn_in", "text": "Bring the seal to Morrow", "items": {"black_seal": 1},
				"say": "You have it. I can hear it from here. Give it to me."},
		],
		"thanks": "Cold. Still cold. It was never his, you know. It was lent, a long time ago, and the lender is patient. Take this for your trouble, and forget the shape of that seal. That part is important.",
		"reward": {"coins": 180, "gear": ["sword", 3]},
	},
}

var _state := {}       # quest id -> {"step": int, "done": bool}
var _events := {}      # things that happened, for "event" steps ("sold_stag")
var tracked := ""      # the quest the tracker and the guide beam follow ("" or finished = the first one)


## "new" (not started), "active", "ready" (all that's left is to hand it in) or "done".
func status(id: String) -> String:
	if DEFS[id].get("auto", false):
		return "active" if _open_event(id) >= 0 else "done"
	if not _state.has(id):
		return "new"
	if _state[id]["done"]:
		return "done"
	return "ready" if _step_kind(id) == "turn_in" and _has_items(_step(id)["items"]) else "active"


func is_active(id: String) -> bool:
	return status(id) in ["active", "ready"]


## Quests you are on, in the order you took them.
func active() -> Array[String]:
	var out: Array[String] = []
	for id: String in DEFS:                  # the story first
		if DEFS[id].get("auto", false) and is_active(id):
			out.append(id)
	for id: String in _state:
		if is_active(id):
			out.append(id)
	return out


## Quests a villager can still give you or is waiting to hear back on: "!" (new) or "?" (ready).
func marker(npc: String) -> String:
	for id: String in DEFS:
		if DEFS[id]["giver"] != npc:
			continue
		match status(id):
			"new":
				return "!"
			"ready":
				return "?"
	return ""


## What the tracker shows: "Pick wild tobacco (2/4)".
func step_text(id: String) -> String:
	var s := _step(id)
	var text: String = s["text"]
	if s["kind"] == "have":
		var item: String = s["items"].keys()[0]
		text += " (%d/%d)" % [mini(Inventory.count(item), s["items"][item]), s["items"][item]]
	return text


func type_of(id: String) -> String:
	return DEFS[id].get("type", "job")


## The quests you've finished, oldest first.
func finished() -> Array[String]:
	var out: Array[String] = []
	for id: String in DEFS:
		if status(id) == "done" and (_state.has(id) or DEFS[id].get("auto", false)):
			out.append(id)
	return out


## What the quest is about, for the quest log: its own line, or what the giver said.
func about(id: String) -> String:
	return DEFS[id].get("about", DEFS[id].get("accepted", ""))


## Which step you're on and how many there are (for the log's ticks).
func step_index(id: String) -> int:
	if DEFS[id].get("auto", false):
		var open := _open_event(id)
		return DEFS[id]["steps"].size() if open < 0 else open
	if not _state.has(id):
		return 0
	return DEFS[id]["steps"].size() if _state[id]["done"] else int(_state[id]["step"])


## The quest the tracker shows and the guide beam points to.
func tracked_quest() -> String:
	var list := active()
	if tracked in list:
		return tracked
	return list[0] if not list.is_empty() else ""


## The action: follow a quest (Track in the quest log, or tapping the tracker to go to the next one).
func track(id: String) -> void:
	tracked = id
	changed.emit()


func track_next() -> void:
	var list := active()
	if list.size() > 1:
		track(list[(list.find(tracked_quest()) + 1) % list.size()])


## Where the current step happens: {"region": String, "at": Vector2}, or {} if nowhere in particular.
func target(id: String) -> Dictionary:
	if not is_active(id):
		return {}
	var s := _step(id)
	if s["kind"] == "turn_in":
		return {"region": "meadow", "at": Npcs.get_def(DEFS[id]["giver"])["at"]}
	var w: Dictionary = s.get("where", {})
	if w.is_empty():
		return {}
	var at: Variant = w["at"]
	if at is String:                          # a named place in that region ("hill")
		at = WorldShape.REGIONS[w["region"]][at]
	return {"region": w["region"], "at": at}


## Where to head from the region you're in: the spot itself, or the gate towards its region.
## {"at": Vector2, "gate": bool}, or {} if there's nowhere to point.
func guide_point(id: String) -> Dictionary:
	var t := target(id) if id != "" else {}
	if t.is_empty():
		return {}
	if t["region"] == Region.current:
		return {"at": t["at"], "gate": false}
	for g: Dictionary in Region.GATES.get(Region.current, []):
		if g["to"] == t["region"]:
			return {"at": g["at"], "gate": true, "to": t["region"]}
	return {}


func accept(id: String) -> void:
	if status(id) != "new":
		return
	_state[id] = {"step": 0, "done": false}
	tracked = id                              # a new quest is the one you follow
	_advance(id)
	changed.emit()


## The action: hand in a finished quest to its giver. Takes the items, pays the reward.
func turn_in(id: String) -> bool:
	if status(id) != "ready":
		return false
	for item: String in _step(id)["items"]:
		Inventory.remove(item, _step(id)["items"][item])
	var reward: Dictionary = DEFS[id]["reward"]
	Money.earn(reward.get("coins", 0))
	for item: String in reward.get("items", {}):
		Inventory.add(item, reward["items"][item])
	if reward.has("gear"):                        # a piece of gear: [slot, rarity], rolled like a find
		var g: Array = reward["gear"]
		var piece := Gear._tool(maxi(Gear.tier(g[0]), 1), g[1], Loot.roll_bonuses("weapon" if g[0] == "sword" else "tool", g[1]))
		Gear.take(g[0], piece)
		get_tree().call_group("hud", "found_tool", g[0], piece)
	_state[id]["done"] = true
	completed.emit(id)
	changed.emit()
	return true


## The talk screen for a villager: {text, options: [{label, do}]}. `do` runs when a button is pressed and
## returns the next screen in the same shape, or an empty Dictionary to end the talk.
func talk(npc: String) -> Dictionary:
	if npc.begins_with("resident:"):   # studio: a simulated villager talks through the same screen
		return load("res://scripts/studio/village/resident_talk.gd").screen(npc)   # studio
	var def := Npcs.get_def(npc)
	for id: String in DEFS:
		if DEFS[id]["giver"] != npc:
			continue
		match status(id):
			"new":
				return _screen(DEFS[id]["offer"], [
					{"label": "I'll do it", "do": func() -> Dictionary:
						accept(id)
						return _screen(DEFS[id]["accepted"], [{"label": "On it", "do": func() -> Dictionary: return {}}])},
					{"label": "Not now", "do": func() -> Dictionary: return {}}])
			"active":
				return _screen(_step(id)["say"], [{"label": "Right", "do": func() -> Dictionary: return {}}])
			"ready":
				return _screen(_step(id)["say"], [
					{"label": "Hand them over", "do": func() -> Dictionary:
						turn_in(id)
						var thanks := _screen(DEFS[id]["thanks"], [{"label": "Thanks", "do": func() -> Dictionary: return {}}])
						thanks["emote"] = "Yes"
						return thanks},
					{"label": "Later", "do": func() -> Dictionary: return {}}])
	return _screen(def["chatter"].pick_random(), [{"label": "Bye", "do": func() -> Dictionary: return {}}])


## Everything you've been given and what's left (checked after each item change).
func refresh() -> void:
	var moved := false
	for id: String in active():
		moved = _advance(id) or moved
	if moved:
		changed.emit()


func _ready() -> void:
	Inventory.changed.connect(func(_i: String, _c: int) -> void: refresh())
	(func() -> void: Classes.changed.connect(changed.emit)).call_deferred()   # the story waits on the shrine


## Moves past every "have" step you already satisfy. True if it moved.
func _advance(id: String) -> bool:
	var moved := false
	while _step_kind(id) in ["have", "event"] and _satisfied(_step(id)):
		_state[id]["step"] += 1
		moved = true
	return moved


## The first story step whose event hasn't happened yet, or -1 when they all have.
func _open_event(id: String) -> int:
	var steps: Array = DEFS[id]["steps"]
	for i in steps.size():
		if not _event_done(steps[i]["event"]):
			return i
	return -1


func _event_done(event: String) -> bool:
	match event:
		"awakened":
			return Classes.awakened
	return _events.has(event)


## The action: something happened that a quest step may be waiting for.
func note(event: String) -> void:
	if not _events.has(event):
		_events[event] = true
	refresh()


func _satisfied(step: Dictionary) -> bool:
	if step["kind"] == "event":
		return _event_done(step["event"])
	return _has_items(step["items"]) or (step.has("or") and _has_items(step["or"]))


func _has_items(items: Dictionary) -> bool:
	for item: String in items:
		if Inventory.count(item) < items[item]:
			return false
	return true


func _step(id: String) -> Dictionary:
	if DEFS[id].get("auto", false):
		return DEFS[id]["steps"][maxi(_open_event(id), 0)]
	return DEFS[id]["steps"][_state[id]["step"]]


func _step_kind(id: String) -> String:
	return _step(id)["kind"]


func _screen(text: String, options: Array) -> Dictionary:
	return {"text": text, "options": options}


func to_data() -> Dictionary:
	var d := _state.duplicate(true)
	d["_tracked"] = tracked
	d["_events"] = _events.keys()
	return d


func load_data(data: Variant) -> void:
	_state = {}
	tracked = ""
	if data is Dictionary:
		tracked = str(data.get("_tracked", ""))
		_events = {}
		for e: Variant in data.get("_events", []):
			_events[str(e)] = true
		for id: String in data:
			if DEFS.has(id) and data[id] is Dictionary and not DEFS[id].get("auto", false):
				var step := clampi(int(data[id].get("step", 0)), 0, DEFS[id]["steps"].size() - 1)
				_state[id] = {"step": step, "done": bool(data[id].get("done", false))}
	changed.emit()
