extends Node
## Companions (game state): who has joined you and how far they've grown. The first ones belong to a class:
## Cinder, a little fire spirit, keeps a Pyromancer company (she only comes along while you're one). She
## jumps out of a campfire the first time a Pyromancer cooks at one. She grows with the fights she helps
## win (levels 1..5: harder, quicker fire; from level 3 her bolts set enemies alight). In the world:
## world/companion.gd. Numbers: Balance.COMPANIONS.

signal changed
signal joined(id: String)
signal grew(id: String, level: int)

const DEFS := {
	"cinder": {"name": "Cinder", "title": "Fire spirit", "class": "pyromancer"},
}
const MAX_LEVEL := 5

var owned := {}                  # id -> {"level": int, "xp": int}
var _hinted := false


func _ready() -> void:
	Food.cooked.connect(_on_cooked)
	Classes.changed.connect(_hint)


## The companion with you now ("" if none): one who joined you and belongs to your class.
func with_you() -> String:
	for id: String in owned:
		if DEFS[id]["class"] in ["", Classes.current]:
			return id
	return ""


func level(id: String) -> int:
	return owned.get(id, {}).get("level", 0)


func xp_for_next(lv: int) -> int:
	return 30 + 30 * lv


## A number for this companion's level (Balance.COMPANIONS[id][key] is a list, one per level).
func stat(id: String, key: String) -> float:
	var list: Array = Balance.COMPANIONS[id][key]
	return list[clampi(level(id) - 1, 0, list.size() - 1)]


## The action: experience from a fight (a kill they helped with).
func add_xp(id: String, amount: int) -> void:
	if not owned.has(id) or owned[id]["level"] >= MAX_LEVEL:
		return
	owned[id]["xp"] += amount
	while owned[id]["level"] < MAX_LEVEL and owned[id]["xp"] >= xp_for_next(owned[id]["level"]):
		owned[id]["xp"] -= xp_for_next(owned[id]["level"])
		owned[id]["level"] += 1
		grew.emit(id, owned[id]["level"])
	changed.emit()


## A Pyromancer cooking at a fire: the first time, a spark in the flames takes a liking to you.
func _on_cooked() -> void:
	if Classes.current == "pyromancer" and not owned.has("cinder"):
		owned["cinder"] = {"level": 1, "xp": 0}
		joined.emit("cinder")
		changed.emit()


func _hint() -> void:
	if Classes.current == "pyromancer" and not owned.has("cinder") and not _hinted:
		_hinted = true
		get_tree().create_timer(4.0).timeout.connect(func() -> void:
			get_tree().call_group("hud", "hint", "The campfires crackle as you pass. Cook something at one..."))


func to_data() -> Dictionary:
	return owned


func load_data(data: Variant) -> void:
	owned = {}
	if data is Dictionary:
		for id: String in data:
			if DEFS.has(id) and data[id] is Dictionary:
				owned[id] = {"level": clampi(int(data[id].get("level", 1)), 1, MAX_LEVEL), "xp": int(data[id].get("xp", 0))}
	changed.emit()
