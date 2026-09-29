extends Node
## Quests (game state, no visuals). Change it only through accept() and turn_in(). Each quest has a
## giver (see state/npcs.gd), the words they say at each point, steps, and rewards. A step is either
## "have" (finishes by itself as soon as you carry the items) or "turn_in" (you hand the items to the
## giver when you talk to them). What you see: the tracker (ui/quest_tracker.gd) and the talk screen
## (ui/dialogue_panel.gd, built from talk()).

signal changed
signal completed(id: String)

const DEFS := {
	"wren_smokes": {
		"giver": "wren", "name": "Wren's Smokes",
		"offer": "Hm. You have the look of someone who's never had a proper smoke. The wild leaf grows in the open out on the grass, big and gold. Bring me four, and I'll show you how it's done.",
		"accepted": "Four leaves. Mind the stalks, they're proud things. There should be some out in the meadow, west of the houses.",
		"steps": [
			{"kind": "have", "text": "Pick wild tobacco", "items": {"tobacco": 4}, "or": {"cigarette": 1},
				"say": "Four leaves, that's all. They grow out in the open. Keep an eye out for the tall ones with the pink flowers."},
			{"kind": "have", "text": "Roll cigarettes at a campfire", "items": {"cigarette": 3},
				"say": "You've got the leaf. Any campfire will do, there is one down past the round house. Two leaves and a bit of wood make three. Roll three and bring them here."},
			{"kind": "turn_in", "text": "Bring the cigarettes to Wren", "items": {"cigarette": 3},
				"say": "Well now. Three of them, and rolled properly. Let me see."},
		],
		"thanks": "Not bad at all. Better than my first. Keep the spare leaf, I've plenty, and take this for your trouble. Light one up when the day gets long.",
		"reward": {"coins": 60, "items": {"tobacco": 5}},
	},
}

var _state := {}       # quest id -> {"step": int, "done": bool}


## "new" (not started), "active", "ready" (all that's left is to hand it in) or "done".
func status(id: String) -> String:
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


func accept(id: String) -> void:
	if status(id) != "new":
		return
	_state[id] = {"step": 0, "done": false}
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
	_state[id]["done"] = true
	completed.emit(id)
	changed.emit()
	return true


## The talk screen for a villager: {text, options: [{label, do}]}. `do` runs when a button is pressed and
## returns the next screen in the same shape, or an empty Dictionary to end the talk.
func talk(npc: String) -> Dictionary:
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


## Moves past every "have" step you already satisfy. True if it moved.
func _advance(id: String) -> bool:
	var moved := false
	while _step_kind(id) == "have" and _satisfied(_step(id)):
		_state[id]["step"] += 1
		moved = true
	return moved


func _satisfied(step: Dictionary) -> bool:
	return _has_items(step["items"]) or (step.has("or") and _has_items(step["or"]))


func _has_items(items: Dictionary) -> bool:
	for item: String in items:
		if Inventory.count(item) < items[item]:
			return false
	return true


func _step(id: String) -> Dictionary:
	return DEFS[id]["steps"][_state[id]["step"]]


func _step_kind(id: String) -> String:
	return _step(id)["kind"]


func _screen(text: String, options: Array) -> Dictionary:
	return {"text": text, "options": options}


func to_data() -> Dictionary:
	return _state.duplicate(true)


func load_data(data: Variant) -> void:
	_state = {}
	if data is Dictionary:
		for id: String in data:
			if DEFS.has(id) and data[id] is Dictionary:
				var step := clampi(int(data[id].get("step", 0)), 0, DEFS[id]["steps"].size() - 1)
				_state[id] = {"step": step, "done": bool(data[id].get("done", false))}
	changed.emit()
