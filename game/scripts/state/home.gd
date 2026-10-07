extends Node
## Your home (game state): whether you own your plot, which house you chose, and what you have built
## on it, and the furniture inside. Change it only through the action functions (buy, place, remove,
## furnish, put_away). The plot is world/home_plot.gd; the room inside is world/home_interior.gd.

signal changed
signal furniture_changed
signal stash_changed

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
	"swoophome": ["Grand Swoop Home", "res://assets/buildings/house_swoophome.glb", "swoop"],
}
## Houses you get by doing one up (not bought or moved into): the house -> its grand version. The Grand
## Swoop Home has a bigger room (GRAND_HALF), a bigger stash, longer rest, and a lodger who pays rent.
const UPGRADES := {"lodge": "swoophome"}
## The inside, chosen apart from the house and changeable any time (free): its feel (walls, floor, cloth)
## and its layout (where the fireplace and windows are). Rooms: assets/interior/room_<feel>[_bright].glb.
const FEELS := {"lantern": "Cottage", "lodge": "Lodge", "hill": "Stone", "swoop": "Swoop", "mill": "Mill"}
const FEEL_BLURBS := {"lantern": "Painted panels, cream walls, red curtains.", "lodge": "Warm planks all the way up, dark timber.",
	"hill": "Fieldstone and whitewash, golden cloth.", "swoop": "Navy panelling, cream plaster, tall windows.",
	"mill": "Pale pine boards, sage curtains, a light floor."}
const LAYOUTS := {
	"hearth": {"name": "Hearth Room", "blurb": "A big fireplace at the back, one wide window.", "file": "",
		"built_in": [Rect2(-4.8, -3.8, 3.65, 1.2), Rect2(-4.8, -1.3, 0.45, 1.8), Rect2(-4.8, 2.3, 0.45, 0.6)],
		"hearth": Vector3(-2.4, 0.0, -3.0), "cook": Vector3(-2.4, 0.0, -2.1), "window": Vector3(2.55, 2.1, -3.2)},
	"bright": {"name": "Bright Room", "blurb": "Two tall windows at the back, the fire on the side wall.", "file": "_bright",
		"built_in": [Rect2(3.6, -2.95, 1.2, 3.7), Rect2(-4.8, -1.3, 0.45, 1.8), Rect2(-4.8, 2.3, 0.45, 0.6)],
		"hearth": Vector3(4.2, 0.0, -1.6), "cook": Vector3(3.25, 0.0, -1.6), "window": Vector3(0.0, 2.1, -3.2)},
	# The Grand Swoop Home's big room only (GRAND_HALF): hearth left of the middle, two back windows,
	# shelves on both side walls.
	"grand": {"name": "Grand Hall", "blurb": "A big room: the fire on the back wall, two tall windows, shelves both sides.", "file": "_grand",
		"built_in": [Rect2(-5.6, -4.8, 3.65, 1.2), Rect2(-6.6, -1.3, 0.45, 1.8), Rect2(-6.6, 3.3, 0.45, 0.6), Rect2(6.15, -0.3, 0.45, 1.8)],
		"hearth": Vector3(-3.2, 0.0, -4.0), "cook": Vector3(-3.2, 0.0, -3.1), "window": Vector3(1.6, 2.1, -4.2)},
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
	"counter": ["Kitchen counter", "res://assets/interior/furn_counter.glb", Vector2(1.6, 0.6), "wall", ""],
	"barrel": ["Barrel", "res://assets/interior/furn_barrel.glb", Vector2(0.62, 0.62), "", ""],
	"sacks": ["Flour sacks", "res://assets/interior/furn_sacks.glb", Vector2(0.9, 0.6), "", ""],
	"weapon_rack": ["Weapon rack", "res://assets/interior/furn_weapon_rack.glb", Vector2(1.2, 0.3), "wall", ""],
	"bench_seat": ["Cushioned bench", "res://assets/interior/furn_bench_seat.glb", Vector2(1.4, 0.45), "", ""],
	"potted_tree": ["Fig tree", "res://assets/interior/furn_potted_tree.glb", Vector2(0.7, 0.7), "", ""],
	"millstone": ["Millstone", "res://assets/interior/furn_millstone.glb", Vector2(1.4, 1.4), "", ""],
}
## The room: its floor runs from -half to +half (x right, z towards the front door): ROOM_HALF, or
## GRAND_HALF in the Grand Swoop Home (room_half()). Match tools-src/blender/make_interior.py.
const ROOM_HALF := Vector2(4.8, 3.8)
const GRAND_HALF := Vector2(6.6, 4.8)
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
var upgraded: Array[String] = []  # houses you've done up (UPGRADES); moving out and back keeps it
var stash := {}                   # item -> count kept at home (the trunk's Stash)
var mail_coins := 0               # rent waiting in your mailbox (the Grand home's lodger)
var _day_secs := 0.0


## The house standing on your plot (the grand version once you've done it up).
func shown_house() -> String:
	return UPGRADES[house] if UPGRADES.has(house) and house in upgraded else house


func house_name() -> String:
	return HOUSES[shown_house()][0] if owned() else ""


func house_model() -> String:
	return HOUSES[shown_house()][1]


func is_grand() -> bool:
	return owned() and shown_house() != house


## The room's floor half-size (bigger in a grand home).
func room_half() -> Vector2:
	return GRAND_HALF if is_grand() else ROOM_HALF


## The way in from the door: nothing can go there.
func doorway() -> Rect2:
	return Rect2(-0.8, room_half().y - 1.2, 1.6, 1.2)


## Whether you can do up your house now (and haven't yet).
func can_upgrade() -> bool:
	return owned() and UPGRADES.has(house) and house not in upgraded


## The action: do your house up into its grand version (spends Balance.HOME_UPGRADE). The furniture moves
## out with the walls, so pieces by a wall stay by it.
func upgrade() -> bool:
	var u: Dictionary = Balance.HOME_UPGRADE
	if not can_upgrade() or Money.coins < u["coins"] or not Gear.can_afford(u["cost"]):
		return false
	Money.spend(u["coins"])
	for item: String in u["cost"]:
		Inventory.remove(item, u["cost"][item])
	upgraded.append(house)
	_refit(ROOM_HALF, GRAND_HALF)
	changed.emit()
	furniture_changed.emit()
	stash_changed.emit()
	return true


## Moves furniture from a room of one size to another: pieces near a wall keep their gap to it, the rest
## spread out with the floor. Then anything in the way of the hearth or shelves moves aside.
func _refit(from: Vector2, to: Vector2) -> void:
	if from == to:
		return
	for f: Dictionary in furniture:
		var x: float = f["x"]
		var z: float = f["z"]
		f["x"] = x + signf(x) * (to.x - from.x) if absf(x) > from.x - 1.4 else x * to.x / from.x
		f["z"] = z - (to.y - from.y) if z < -from.y + 1.4 else (z + (to.y - from.y) if z > from.y - 1.4 else z * to.y / from.y)
	_clear_built_ins()


# --- the stash (the trunk) ---------------------------------------------------------------------

## How many different things the stash holds.
func stash_room() -> int:
	return Balance.HOME_STASH["grand" if is_grand() else "kinds"]


## The action: put `amount` of an item from your bag into the stash.
func store(item: String, amount: int) -> bool:
	amount = mini(amount, Inventory.count(item))
	if amount <= 0 or (not stash.has(item) and stash.size() >= stash_room()):
		return false
	Inventory.remove(item, amount)
	stash[item] = stash.get(item, 0) + amount
	stash_changed.emit()
	return true


## The action: take `amount` of an item out of the stash into your bag (if there's room).
func take_out(item: String, amount: int) -> bool:
	amount = mini(amount, stash.get(item, 0))
	if amount <= 0 or not Inventory.has_room(item):
		return false
	stash[item] -= amount
	if stash[item] <= 0:
		stash.erase(item)
	Inventory.add(item, amount)
	stash_changed.emit()
	return true


# --- rent ------------------------------------------------------------------------------------

## Each in-game day in a grand home, the lodger leaves rent in your mailbox (up to a few days' worth).
func _process(delta: float) -> void:
	if not is_grand():
		return
	_day_secs += WorldClock.step # studio: merge - world seconds (the one world clock)
	if _day_secs >= Bounties.DAY_SECS:
		new_day()


## A new day (a day went by, or you slept through the night): rent comes in.
func new_day() -> void:
	_day_secs = 0.0
	if is_grand():
		var rent: int = Balance.HOME_UPGRADE["rent"]
		mail_coins = mini(mail_coins + rent, rent * Balance.HOME_UPGRADE["rent_days"])
		changed.emit()


## The action: take the rent out of the mailbox.
func collect_rent() -> int:
	var got := mail_coins
	if got > 0:
		Money.earn(got)
		mail_coins = 0
		changed.emit()
	return got


## The feel the room has now.
func room_feel() -> String:
	return feel if FEELS.has(feel) else (HOUSES[shown_house()][2] if HOUSES.has(shown_house()) else "lantern")


## The room model for the feel and layout.
func room_model() -> String:
	return "res://assets/interior/room_%s%s.glb" % [room_feel(), room_layout()["file"]]


## The layout in use (a grand home always has its Grand Hall).
func room_layout() -> Dictionary:
	return LAYOUTS["grand" if is_grand() else layout]


## The action: change the inside's feel (free).
func set_feel(id: String) -> void:
	if FEELS.has(id) and id != room_feel():
		feel = id
		changed.emit()


## The action: change the layout (free). Furniture where the new hearth or shelves stand is put away.
func set_layout(id: String) -> void:
	if not LAYOUTS.has(id) or id == layout or id == "grand":
		return
	layout = id
	_clear_built_ins()
	changed.emit()
	furniture_changed.emit()
	stash_changed.emit()


## Furniture standing where this layout's hearth or shelves are moves to the nearest free spot (or is put
## away if there's none).
func _clear_built_ins() -> void:
	var all := furniture.duplicate()
	var blocked: Array = []
	furniture = []
	for f: Dictionary in all:
		var r := footprint(f["id"], f["x"], f["z"], f["turn"])
		var hit := false
		for b: Rect2 in room_layout()["built_in"]:
			hit = hit or r.intersects(b)
		if hit:
			blocked.append(f)
		else:
			furniture.append(f)
	for f: Dictionary in blocked:
		var best := Vector2.INF
		var half := room_half()
		var x := -half.x + 0.5
		while x < half.x:
			var z := -half.y + 0.5
			while z < half.y:
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
	if owned() or not choosable(choice) or not missing().is_empty():
		return false
	Money.spend(Balance.HOME["coins"])
	house = choice
	furniture = STARTER.duplicate(true)
	_clear_built_ins()
	changed.emit()
	furniture_changed.emit()
	stash_changed.emit()
	return true


## The action: move into another of the houses (free; what you built in the yard stays, and a house you
## did up stays done up for when you move back).
func change_house(choice: String) -> bool:
	if not owned() or not choosable(choice) or choice == house:
		return false
	var before := room_half()
	house = choice
	_refit(before, room_half())
	changed.emit()
	furniture_changed.emit()
	stash_changed.emit()
	return true


## Houses you can buy or move into (not the grand versions: you do those up).
func choosable(id: String) -> bool:
	return HOUSES.has(id) and id not in UPGRADES.values()


## The action (test menu only): give the home back: no house, empty yard, the plot for sale again.
func reset() -> void:
	house = ""
	pieces = []
	furniture = []
	stored = {}
	feel = ""
	layout = "hearth"
	upgraded = []
	stash = {}
	mail_coins = 0
	changed.emit()
	furniture_changed.emit()
	stash_changed.emit()
	stash_changed.emit()


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
	var half := room_half()
	if absf(r.position.x) > half.x or r.end.x > half.x or r.position.y < -half.y or r.end.y > half.y:
		return false
	var rug: bool = FURNITURE[id][3] == "rug"
	if not rug and r.intersects(doorway()):
		return false
	for b: Rect2 in room_layout()["built_in"]:
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
	return stored.get(id, 0) > 0 or (Balance.HOME_FURNITURE.has(id) and Gear.can_afford(Balance.HOME_FURNITURE[id]))


## Furniture you can make (some pieces only stand in other people's houses).
static func for_sale() -> Array:
	return FURNITURE.keys().filter(func(id: String) -> bool: return Balance.HOME_FURNITURE.has(id))


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
	return {"house": house, "pieces": pieces, "furniture": furniture, "stored": stored, "feel": feel, "layout": layout,
		"upgraded": upgraded, "stash": stash, "mail": mail_coins, "day_secs": _day_secs}


func load_data(data: Variant) -> void:
	house = ""
	pieces = []
	furniture = []
	stored = {}
	feel = ""
	layout = "hearth"
	upgraded = []
	stash = {}
	mail_coins = 0
	_day_secs = 0.0
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
		for u: Variant in data.get("upgraded", []):
			if UPGRADES.has(str(u)):
				upgraded.append(str(u))
		var sh: Variant = data.get("stash", {})
		if sh is Dictionary:
			for item: String in sh:
				if Items.DEFS.has(item) and int(sh[item]) > 0:
					stash[item] = int(sh[item])
		mail_coins = int(data.get("mail", 0))
		_day_secs = float(data.get("day_secs", 0.0))
		var st: Variant = data.get("stored", {})
		if st is Dictionary:
			for id: String in st:
				if FURNITURE.has(id) and int(st[id]) > 0:
					stored[id] = int(st[id])
	changed.emit()
	furniture_changed.emit()
	stash_changed.emit()
