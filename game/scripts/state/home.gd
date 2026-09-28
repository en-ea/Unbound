extends Node
## Your home (game state): whether you own your plot, which house you chose, and what you have built
## on it. Change it only through buy(), place() and remove(). The plot is world/home_plot.gd.

signal changed

## House choices: [name, model].
const HOUSES := {
	"lodge": ["Swoop Lodge", "res://assets/buildings/house_lodge.glb"],
	"hill": ["Hill House", "res://assets/buildings/house_hill.glb"],
	"lantern": ["Lantern House", "res://assets/buildings/house_lantern.glb"],
}
## Buildable pieces: [name, model, footprint radius, what pressing the action button does ("" = nothing)].
const PIECES := {
	"fence": ["Fence", "res://assets/props/fence.glb", 1.0, ""],
	"lantern_post": ["Lantern post", "res://assets/props/lantern_post.glb", 0.5, ""],
	"bench": ["Bench", "res://assets/props/bench.glb", 0.9, ""],
	"flower_bed": ["Flower bed", "res://assets/props/flower_bed.glb", 1.0, ""],
	"campfire": ["Campfire", "res://assets/props/campfire.glb", 1.2, "cook"],
	"workbench": ["Workbench", "res://assets/props/workbench.glb", 1.8, "craft"],
	"tree": ["Apple tree", "res://assets/nature/tree_apple_1.glb", 1.0, ""],
	"rock": ["Boulder", "res://assets/nature/rock_2.glb", 1.0, ""],
}
const PLOT_CENTER := Vector2(-40.0, 38.0)      # meadow; flattened in WorldShape.REGIONS
const PLOT_HALF := Vector2(9.0, 6.0)           # the buildable yard in front of the house

var house := ""                   # "" = not bought yet
var pieces: Array = []            # [{id, x, z, turn}]


func owned() -> bool:
	return house != ""


## Why you can't buy yet, one line per missing thing (empty = you can).
func missing() -> Array[String]:
	var out: Array[String] = []
	var h: Dictionary = Balance.HOME
	if not Projects.is_built(h["needs_project"]):
		out.append("Build the village %s first" % Projects.DEFS[h["needs_project"]]["name"])
	var total := 0
	for sk: String in Skills.SKILLS:
		total += Skills.level(sk)
	if total < h["needs_skill_total"]:
		out.append("Reach %d total skill levels (you have %d)" % [h["needs_skill_total"], total])
	if Money.coins < h["coins"]:
		out.append("%d coins" % h["coins"])
	return out


## The action: buy the plot with a house.
func buy(choice: String) -> bool:
	if owned() or not HOUSES.has(choice) or not missing().is_empty():
		return false
	Money.spend(Balance.HOME["coins"])
	house = choice
	changed.emit()
	return true


## The action: move into another of the houses (free; what you built in the yard stays).
func change_house(choice: String) -> bool:
	if not owned() or not HOUSES.has(choice) or choice == house:
		return false
	house = choice
	changed.emit()
	return true


## The action (test menu only): give the home back: no house, empty yard, the plot for sale again.
func reset() -> void:
	house = ""
	pieces = []
	changed.emit()


func inside(x: float, z: float) -> bool:
	return absf(x - PLOT_CENTER.x) <= PLOT_HALF.x and absf(z - (PLOT_CENTER.y + 2.0)) <= PLOT_HALF.y


## Whether a piece fits at a spot: inside the yard and not on top of another piece.
func fits(id: String, x: float, z: float) -> bool:
	if not inside(x, z):
		return false
	for p: Dictionary in pieces:
		var gap: float = PIECES[id][2] + PIECES[p["id"]][2]
		if id in ["fence", "lantern_post"] and p["id"] in ["fence", "lantern_post"]:
			gap = 0.9          # fences and posts may touch end to end
		if Vector2(x, z).distance_to(Vector2(p["x"], p["z"])) < gap * 0.9:
			return false
	return true


## The action: build a piece (spends its cost).
func place(id: String, x: float, z: float, turn: float) -> bool:
	if not owned() or not fits(id, x, z) or not Gear.can_afford(Balance.HOME_PIECES[id]):
		return false
	var cost: Dictionary = Balance.HOME_PIECES[id]
	for item: String in cost:
		Inventory.remove(item, cost[item])
	pieces.append({"id": id, "x": x, "z": z, "turn": turn})
	changed.emit()
	return true


## The action: take a piece down (you get its materials back).
func remove(index: int) -> void:
	if index < 0 or index >= pieces.size():
		return
	var cost: Dictionary = Balance.HOME_PIECES[pieces[index]["id"]]
	for item: String in cost:
		Inventory.add(item, cost[item])
	pieces.remove_at(index)
	changed.emit()


## The piece nearest a spot (within 2 m), or -1.
func nearest(x: float, z: float) -> int:
	var best := -1
	var best_d := 2.0
	for i in pieces.size():
		var d := Vector2(x, z).distance_to(Vector2(pieces[i]["x"], pieces[i]["z"]))
		if d < best_d:
			best_d = d
			best = i
	return best


func to_data() -> Dictionary:
	return {"house": house, "pieces": pieces}


func load_data(data: Variant) -> void:
	house = ""
	pieces = []
	if data is Dictionary:
		house = String(data.get("house", "")) if HOUSES.has(String(data.get("house", ""))) else ""
		for p: Variant in data.get("pieces", []):
			if p is Dictionary and PIECES.has(String(p.get("id", ""))):
				pieces.append({"id": String(p["id"]), "x": float(p["x"]), "z": float(p["z"]), "turn": float(p.get("turn", 0.0))})
	changed.emit()
