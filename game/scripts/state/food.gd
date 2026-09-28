extends Node
## Food (game state, no visuals): what each food does when eaten, the campfire recipes, and the
## buffs running right now. Change it only through cook() and eat().

signal changed        # buffs started or ended
signal ate(item: String)

## heal: hearts back. buff: a short boost (see BUFFS), for secs. Numbers in Balance.
const FOODS := Balance.FOODS
const BUFFS := {
	"strong": {"name": "Strong", "text": "Hits 1 harder", "color": Color(1.0, 0.55, 0.4)},
	"swift": {"name": "Swift", "text": "Runs 20% faster", "color": Color(0.55, 0.9, 1.0)},
	"nimble": {"name": "Nimble", "text": "Chops and mines 25% faster", "color": Color(0.7, 1.0, 0.5)},
	"sturdy": {"name": "Sturdy", "text": "Takes 1 less damage", "color": Color(1.0, 0.85, 0.45)},
}
## Campfire recipes, in the order shown.
const RECIPES := Balance.COOKING

var _until := {}       # buff -> time (seconds since start) it ends


func is_food(item: String) -> bool:
	return FOODS.has(item)


## What a food does, in a few words ("+2 hearts, Strong 1:30").
func describe(item: String) -> String:
	var f: Dictionary = FOODS[item]
	var text := "+%d heart%s" % [f["heal"], "" if f["heal"] == 1 else "s"]
	if f.has("buff"):
		text += ", %s: %s (%ds)" % [BUFFS[f["buff"]]["name"], BUFFS[f["buff"]]["text"].to_lower(), int(f["secs"])]
	return text


## The action: cook a recipe at a campfire.
func cook(recipe: Dictionary) -> bool:
	if not Gear.can_afford(recipe["cost"]) or not Inventory.has_room(recipe["out"]):
		return false
	for item: String in recipe["cost"]:
		Inventory.remove(item, recipe["cost"][item])
	Inventory.add(recipe["out"])
	return true


## The action: eat one of a food. Returns how many hearts it heals (the player applies them).
func eat(item: String) -> int:
	if not is_food(item) or not Inventory.remove(item):
		return 0
	var f: Dictionary = FOODS[item]
	if f.has("buff"):
		_until[f["buff"]] = _now() + f["secs"]
		changed.emit()
	ate.emit(item)
	return f["heal"]


func has(buff: String) -> bool:
	return _until.get(buff, 0.0) > _now()


## Seconds left on a buff (0 if not running).
func left(buff: String) -> float:
	return maxf(_until.get(buff, 0.0) - _now(), 0.0)


func active() -> Array[String]:
	var out: Array[String] = []
	for b: String in BUFFS:
		if has(b):
			out.append(b)
	return out


func _process(_delta: float) -> void:
	for b: String in _until.keys():
		if _until[b] <= _now():
			_until.erase(b)
			changed.emit()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
