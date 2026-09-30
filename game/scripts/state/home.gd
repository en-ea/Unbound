extends Node
## Your home (game state): whether you own your plot, which house you chose, and what you have built
## on it, and the furniture inside. Change it only through the action functions (buy, place, remove,
## furnish, put_away). The plot is world/home_plot.gd; the room inside is world/home_interior.gd.

signal changed
signal furniture_changed

## House choices: [name, model, the inside's feel it starts with (FEELS)].
const HOUSES := {
	"lodge": ["Swoop Lodge", "res://assets/buildings/house_lodge.glb", "lodge"],
	"hill": ["Hill House", "res://assets/buildings/house_hill.glb", "hill"],
	"lantern": ["Lantern House", "res://assets/buildings/house_lantern.glb", "lantern"],
	"storybook": ["Storybook Cottage", "res://assets/buildings/house_storybook.glb", "lantern"],
	"turret": ["Turret Cottage", "res://assets/buildings/house_turret.glb", "hill"],
	"arch": ["Arch Cottage", "res://assets/buildings/house_arch.glb", "hill"],
	"skep": ["Skep Cottage", "res://assets/buildings/house_skep.glb", "lantern"],
	"hull": ["Hull House", "res://assets/buildings/house_hull.glb", "lodge"],
	"gable": ["Gable House", "res://assets/buildings/house_gable.glb", "lodge"],
}
## The inside, chosen apart from the house and changeable any time (free): its feel (walls, floor, cloth)
## and its layout (where the fireplace and windows are). Rooms: assets/interior/room_<feel>[_bright].glb.
const FEELS := {"lantern": "Cottage", "lodge": "Lodge", "hill": "Stone"}
const LAYOUTS := {
	"hearth": {"name": "Hearth Room", "blurb": "A big fireplace at the back, one wide window.", "file": "",
		"built_in": [Rect2(-4.8, -3.8, 3.65, 1.2), Rect2(-4.8, -1.3, 0.45, 1.8), Rect2(-4.8, 2.3, 0.45, 0.6)],
		"hearth": Vector3(-2.4, 0.0, -3.0), "cook": Vector3(-2.4, 0.0, -2.1), "window": Vector3(2.55, 2.1, -3.2)},
	"bright": {"name": "Bright Room", "blurb": "Two tall windows at the back, the fire on the side wall.", "file": "_bright",
		"built_in": [Rect2(3.6, -2.95, 1.2, 3.7), Rect2(-4.8, -1.3, 0.45, 1.8), Rect2(-4.8, 2.3, 0.45, 0.6)],
		"hearth": Vector3(4.2, 0.0, -1.6), "cook": Vector3(3.25, 0.0, -1.6), "window": Vector3(0.0, 2.1, -3.2)},
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
## Furniture for inside: [name, model, footprint (width, depth) in metres, how it sits ("wall": backs
## onto a wall when Snap is on, "rug": things stand on it, "": anywhere), action button ("rest", "")].
const FURNITURE := {
	"bed": ["Bed", "res://assets/interior/furn_bed.glb", Vector2(1.3, 2.2), "wall", "rest"],
	"table": ["Table", "res://assets/interior/furn_table.glb", Vector2(1.6, 0.92), "", ""],
	"chair": ["Chair", "res://assets/interior/furn_chair.glb", Vector2(0.5, 0.5), "", ""],
	"stool": ["Stool", "res://assets/interior/furn_stool.glb", Vector2(0.42, 0.42), "", ""],
	"armchair": ["Armchair", "res://assets/interior/furn_armchair.glb", Vector2(0.92, 0.86), "", ""],
	"bookshelf": ["Bookshelf", "res://assets/interior/furn_bookshelf.glb", Vector2(1.2, 0.42), "wall", ""],
	"wardrobe": ["Wardrobe", "res://assets/interior/furn_wardrobe.glb", Vector2(1.2, 0.66), "wall", ""],
	"dresser": ["Dresser", "res://assets/interior/furn_dresser.glb", Vector2(1.45, 0.54), "wall", ""],
	"trunk": ["Trunk", "res://assets/interior/furn_trunk.glb", Vector2(0.92, 0.58), "", ""],
	"plant": ["Potted plant", "res://assets/interior/furn_plant.glb", Vector2(0.56, 0.56), "", ""],
	"lamp": ["Lamp", "res://assets/interior/furn_lamp.glb", Vector2(0.42, 0.42), "", ""],
	"rug_round": ["Round rug", "res://assets/interior/furn_rug_round.glb", Vector2(2.4, 2.4), "rug", ""],
	"rug_long": ["Long rug", "res://assets/interior/furn_rug_long.glb", Vector2(2.4, 1.6), "rug", ""],
	"trophy": ["Stag trophy", "res://assets/interior/furn_trophy.glb", Vector2(0.7, 0.3), "wall", ""],
}
## The room: its floor runs from -ROOM_HALF to +ROOM_HALF (x right, z towards the front door).
const ROOM_HALF := Vector2(4.8, 3.8)
## The way in from the door: nothing can go there. (The hearth and shelves are in LAYOUTS; match
## tools-src/blender/make_interior.py.)
const ROOM_DOORWAY := Rect2(-0.8, 2.6, 1.6, 1.2)
## What a new home comes with (you can move it, put it away, or place it again for free).
const STARTER := [
	{"id": "bed", "x": 3.85, "z": -2.7, "turn": 0.0}, {"id": "trunk", "x": 3.85, "z": -1.05, "turn": 0.0},
	{"id": "rug_round", "x": 0.4, "z": 0.2, "turn": 0.0}, {"id": "table", "x": 0.4, "z": 0.1, "turn": 0.0},
	{"id": "chair", "x": -0.1, "z": -0.66, "turn": 0.0}, {"id": "chair", "x": 0.9, "z": -0.66, "turn": 0.0},
	{"id": "armchair", "x": -2.5, "z": -1.55, "turn": PI}, {"id": "lamp", "x": -3.7, "z": -1.9, "turn": 0.0},
	{"id": "plant", "x": 4.35, "z": 3.3, "turn": 0.0}, {"id": "dresser", "x": 4.5, "z": 1.1, "turn": -PI / 2.0},
]

const PLOT_CENTER := Vector2(-40.0, 38.0)      # meadow; flattened in WorldShape.REGIONS
const PLOT_HALF := Vector2(9.0, 6.0)           # the buildable yard in front of the house

var house := ""                   # "" = not bought yet
var pieces: Array = []            # [{id, x, z, turn}]
var furniture: Array = []         # [{id, x, z, turn}] in room metres (see ROOM_HALF)
var stored := {}                  # id -> how many you've put away (placing them again is free)
var feel := ""                    # the inside's feel (FEELS); "" = the house's own
var layout := "hearth"            # the inside's layout (LAYOUTS)


## The feel the room has now.
func room_feel() -> String:
	return feel if FEELS.has(feel) else (HOUSES[house][2] if HOUSES.has(house) else "lantern")


## The room model for the feel and layout.
func room_model() -> String:
	return "res://assets/interior/room_%s%s.glb" % [room_feel(), LAYOUTS[layout]["file"]]


func room_layout() -> Dictionary:
	return LAYOUTS[layout]


## The action: change the inside's feel (free).
func set_feel(id: String) -> void:
	if FEELS.has(id) and id != room_feel():
		feel = id
		changed.emit()


## The action: change the layout (free). Furniture where the new hearth or shelves stand is put away.
func set_layout(id: String) -> void:
	if not LAYOUTS.has(id) or id == layout:
		return
	layout = id
	_clear_built_ins()
	changed.emit()
	furniture_changed.emit()


## Furniture standing where this layout's hearth or shelves are moves to the nearest free spot (or is put
## away if there's none).
func _clear_built_ins() -> void:
	var all := furniture.duplicate()
	var blocked: Array = []
	furniture = []
	for f: Dictionary in all:
		var r := footprint(f["id"], f["x"], f["z"], f["turn"])
		var hit := false
		for b: Rect2 in LAYOUTS[layout]["built_in"]:
			hit = hit or r.intersects(b)
		if hit:
			blocked.append(f)
		else:
			furniture.append(f)
	for f: Dictionary in blocked:
		var best := Vector2.INF
		var x := -ROOM_HALF.x + 0.5
		while x < ROOM_HALF.x:
			var z := -ROOM_HALF.y + 0.5
			while z < ROOM_HALF.y:
				if room_fits(f["id"], x, z, f["turn"]) and Vector2(x, z).distance_to(Vector2(f["x"], f["z"])) < best.distance_to(Vector2(f["x"], f["z"])):
					best = Vector2(x, z)
				z += 0.25
			x += 0.25
		if best != Vector2.INF:
			furniture.append({"id": f["id"], "x": best.x, "z": best.y, "turn": f["turn"]})
		else:
			stored[f["id"]] = stored.get(f["id"], 0) + 1


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
	furniture = STARTER.duplicate(true)
	_clear_built_ins()
	changed.emit()
	furniture_changed.emit()
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
	furniture = []
	stored = {}
	feel = ""
	layout = "hearth"
	changed.emit()
	furniture_changed.emit()


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


# --- furniture ----------------------------------------------------------------------------

## A piece's footprint on the floor at a spot and turn (turned pieces swap width and depth).
func footprint(id: String, x: float, z: float, turn: float) -> Rect2:
	var size: Vector2 = FURNITURE[id][2]
	var quarter := posmod(roundi(turn / (PI / 2.0)), 2) == 1
	if absf(fposmod(turn, PI / 2.0) - PI / 4.0) < 0.3:          # at 45 degrees: the square round it
		size = Vector2.ONE * maxf(size.x, size.y) * 0.85
	elif quarter:
		size = Vector2(size.y, size.x)
	return Rect2(x - size.x / 2.0, z - size.y / 2.0, size.x, size.y)


## Whether a piece fits: on the floor, clear of the hearth and doorway, and not on another piece
## (rugs only mind other rugs; everything else stands on rugs). `skip` ignores one placed piece.
func room_fits(id: String, x: float, z: float, turn: float, skip := -1) -> bool:
	var r := footprint(id, x, z, turn).grow(-0.02)
	if absf(r.position.x) > ROOM_HALF.x or r.end.x > ROOM_HALF.x or r.position.y < -ROOM_HALF.y or r.end.y > ROOM_HALF.y:
		return false
	var rug: bool = FURNITURE[id][3] == "rug"
	if not rug and r.intersects(ROOM_DOORWAY):
		return false
	for b: Rect2 in LAYOUTS[layout]["built_in"]:
		if r.intersects(b):
			return false
	for i in furniture.size():
		var f: Dictionary = furniture[i]
		if i == skip or (FURNITURE[f["id"]][3] == "rug") != rug:
			continue
		if r.intersects(footprint(f["id"], f["x"], f["z"], f["turn"])):
			return false
	return true


func can_furnish(id: String) -> bool:
	return stored.get(id, 0) > 0 or Gear.can_afford(Balance.HOME_FURNITURE[id])


## The action: place a piece of furniture (one you put away is free, otherwise it costs materials).
func furnish(id: String, x: float, z: float, turn: float) -> bool:
	if not owned() or not FURNITURE.has(id) or not room_fits(id, x, z, turn) or not can_furnish(id):
		return false
	if stored.get(id, 0) > 0:
		stored[id] -= 1
		if stored[id] == 0:
			stored.erase(id)
	else:
		var cost: Dictionary = Balance.HOME_FURNITURE[id]
		for item: String in cost:
			Inventory.remove(item, cost[item])
	furniture.append({"id": id, "x": x, "z": z, "turn": turn})
	furniture_changed.emit()
	return true


## The action: put a piece away (it waits in storage, free to place again).
func put_away(index: int) -> void:
	if index < 0 or index >= furniture.size():
		return
	var id: String = furniture[index]["id"]
	stored[id] = stored.get(id, 0) + 1
	furniture.remove_at(index)
	furniture_changed.emit()


## The piece nearest a spot (within 1.6 m; a rug only when nothing stands nearer), or -1.
func furniture_near(x: float, z: float) -> int:
	var best := -1
	var best_d := 1.6
	for i in furniture.size():
		var f: Dictionary = furniture[i]
		var d := Vector2(x, z).distance_to(Vector2(f["x"], f["z"])) + (1.0 if FURNITURE[f["id"]][3] == "rug" else 0.0)
		if d < best_d:
			best_d = d
			best = i
	return best


func to_data() -> Dictionary:
	return {"house": house, "pieces": pieces, "furniture": furniture, "stored": stored, "feel": feel, "layout": layout}


func load_data(data: Variant) -> void:
	house = ""
	pieces = []
	furniture = []
	stored = {}
	feel = ""
	layout = "hearth"
	if data is Dictionary:
		feel = str(data.get("feel", "")) if FEELS.has(str(data.get("feel", ""))) else ""
		layout = str(data.get("layout", "hearth")) if LAYOUTS.has(str(data.get("layout", ""))) else "hearth"
		house =String(data.get("house", "")) if HOUSES.has(String(data.get("house", ""))) else ""
		for p: Variant in data.get("pieces", []):
			if p is Dictionary and PIECES.has(String(p.get("id", ""))):
				pieces.append({"id": String(p["id"]), "x": float(p["x"]), "z": float(p["z"]), "turn": float(p.get("turn", 0.0))})
		if house != "" and not data.has("furniture"):         # a home bought before it had an inside
			furniture = STARTER.duplicate(true)
		for f: Variant in data.get("furniture", []):
			if f is Dictionary and FURNITURE.has(String(f.get("id", ""))):
				furniture.append({"id": String(f["id"]), "x": float(f["x"]), "z": float(f["z"]), "turn": float(f.get("turn", 0.0))})
		var st: Variant = data.get("stored", {})
		if st is Dictionary:
			for id: String in st:
				if FURNITURE.has(id) and int(st[id]) > 0:
					stored[id] = int(st[id])
	changed.emit()
	furniture_changed.emit()
