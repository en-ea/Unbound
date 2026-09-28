extends Node
## Village projects (game state): buildings you pay for, which appear at their spot in the village
## and unlock things. Fund one through fund(). Sites: world/project_site.gd.

signal built(id: String)

const DEFS := {
	"smithy": {"name": "Smithy", "region": "meadow", "at": Vector2(-17.0, 12.0),
		"text": "The smith can forge Steel tools at the workbench.",
		"coins": 150, "cost": {"stone": 20, "pinewood": 12, "iron": 6}},
}

var _built := {}


func is_built(id: String) -> bool:
	return _built.has(id)


func can_fund(id: String) -> bool:
	return not is_built(id) and Money.coins >= DEFS[id]["coins"] and Gear.can_afford(DEFS[id]["cost"])


## The action: pay for a project; it is built straight away.
func fund(id: String) -> bool:
	if not can_fund(id):
		return false
	Money.spend(DEFS[id]["coins"])
	var cost: Dictionary = DEFS[id]["cost"]
	for item: String in cost:
		Inventory.remove(item, cost[item])
	_built[id] = true
	built.emit(id)
	Gear.changed.emit()       # the workbench shows what it unlocked
	return true


func to_data() -> Array:
	return _built.keys()


func load_data(data: Variant) -> void:
	_built.clear()
	if data is Array:
		for id: Variant in data:
			if DEFS.has(String(id)):
				_built[String(id)] = true
