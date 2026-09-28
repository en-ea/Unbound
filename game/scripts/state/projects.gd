extends Node
## Village projects (game state): buildings you pay for, which appear at their spot in the village
## and unlock things. Fund one through fund(). Sites: world/project_site.gd.

signal built(id: String)
signal unbuilt(id: String)        # only from the test menu

const DEFS := {
	"smithy": {"name": "Smithy", "region": "meadow", "at": Vector2(-17.0, 12.0),
		"text": "The smith can forge Steel tools at the workbench."},
}

var _built := {}


func is_built(id: String) -> bool:
	return _built.has(id)


func coins(id: String) -> int:
	return Balance.PROJECTS[id]["coins"]


func cost(id: String) -> Dictionary:
	return Balance.PROJECTS[id]["cost"]


func can_fund(id: String) -> bool:
	return not is_built(id) and Money.coins >= coins(id) and Gear.can_afford(cost(id))


## The action: pay for a project; it is built straight away.
func fund(id: String) -> bool:
	if not can_fund(id):
		return false
	Money.spend(coins(id))
	var c := cost(id)
	for item: String in c:
		Inventory.remove(item, c[item])
	_built[id] = true
	built.emit(id)
	Gear.changed.emit()       # the workbench shows what it unlocked
	return true


## The action (test menu only): take a built project down again, back to its scaffolding. No refund.
func unbuild(id: String) -> void:
	if not is_built(id):
		return
	_built.erase(id)
	unbuilt.emit(id)
	Gear.changed.emit()


func to_data() -> Array:
	return _built.keys()


func load_data(data: Variant) -> void:
	_built.clear()
	if data is Array:
		for id: Variant in data:
			if DEFS.has(String(id)):
				_built[String(id)] = true
