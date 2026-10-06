extends "res://scripts/world/home_interior.gd"
## Inside a house in the meadow village (the Enter spots by their doors, world/village.gd): a resident's
## home, the mill, or a house to let (Lettings: bare while it's for sale, better furnished as you do it up).
## The same kind of room as your home, in that house's feel and layout, with its own furniture, and whoever
## lives there inside when they're home (Residents: at night, or before they head out). You can talk to
## them and use their hearth; no furnishing, no sleeping in their bed, and the game doesn't save in here.

## A piece: [id, x, z, turn]. Each house's own things (the residents' homes and the mill).
const FURNISH := {
	0: [["bed", 3.85, -2.7, 0.0], ["trunk", 3.85, -1.05, 0.0], ["rug_long", 0.4, 0.4, 0.0], ["table", 0.4, 0.1, 0.0],
		["stool", -0.2, -0.66, 0.0], ["stool", 1.0, -0.66, 0.0], ["weapon_rack", 4.65, 1.6, -PI / 2.0],
		["barrel", -3.8, 1.5, 0.0], ["armchair", -2.5, -1.55, PI], ["lamp", -3.7, -1.9, 0.0]],
	1: [["bed", -3.9, -2.7, 0.0], ["sacks", -1.2, -3.2, 0.0], ["sacks", 2.2, 2.6, 0.4], ["barrel", -3.9, 1.6, 0.0],
		["rug_round", 0.2, 0.2, 0.0], ["table", 0.2, 0.1, 0.0], ["chair", -0.3, -0.66, 0.0], ["chair", 0.7, -0.66, 0.0],
		["dresser", 4.53, 2.0, -PI / 2.0], ["lamp", 1.9, -2.9, 0.0]],
	2: [["bed", 3.85, -2.7, 0.0], ["bed", 3.85, 0.2, 0.0], ["counter", 0.0, -3.5, 0.0], ["sacks", -3.9, 1.5, 0.0],
		["rug_round", 0.4, 0.4, 0.0], ["table", 0.4, 0.3, 0.0], ["chair", -0.1, -0.46, 0.0], ["chair", 0.9, -0.46, 0.0],
		["plant", 4.35, 3.3, 0.0], ["barrel", -0.9, -3.45, 0.0]],
	5: [["millstone", 0.5, -1.2, 0.0], ["sacks", -2.6, -3.0, 0.0], ["sacks", -1.3, -3.2, 0.6], ["sacks", 2.2, 2.4, 0.0],
		["barrel", -3.9, -3.1, 0.0], ["barrel", -3.9, 1.7, 0.0], ["stool", 1.9, 0.9, 0.0], ["counter", -2.3, 3.0, PI]],
}
## A house to let at each level: For sale (bare), Plain, Cosy, Fine (each adds to the last).
const LETTING := [
	[["trunk", 3.85, -1.05, 0.0], ["sacks", -3.9, 1.5, 0.0], ["stool", 0.4, 0.2, 0.0]],
	[["bed", 3.85, -2.7, 0.0], ["trunk", 3.85, -1.05, 0.0], ["table", 0.4, 0.1, 0.0], ["stool", -0.2, -0.66, 0.0], ["stool", 1.0, -0.66, 0.0]],
	[["rug_round", 0.4, 0.2, 0.0], ["armchair", -2.5, -1.55, PI], ["lamp", -3.7, -1.9, 0.0], ["plant", 4.35, 3.3, 0.0],
		["dresser", 4.5, 1.1, -PI / 2.0]],
	[["bookshelf", -4.59, 1.4, PI / 2.0], ["potted_tree", -2.4, 2.4, 0.0], ["bench_seat", 2.3, 2.9, 0.0],
		["rug_long", -2.5, -1.2, 0.0], ["counter", 0.2, -3.5, 0.0]],
]
const HomeFolk := preload("res://scripts/world/home_folk.gd")

var _house := -1
var _feel := "lodge"
var _layout_id := "hearth"
var _people: Array[Node] = []
var _saving_was := false


func _init() -> void:
	origin = Vector3(-300, -300, 0)


## The action: go into house `index` (its room's `feel` and `layout`), coming back out at `door`.
func visit(index: int, feel: String, door: Vector3, layout := "hearth") -> void:
	if active:
		return
	_house = index
	_feel = feel
	_layout_id = layout
	door_out = door
	enter()


func _is_home() -> bool:
	return false


func _can_enter() -> bool:
	return _house >= 0


func _model() -> String:
	return "res://assets/interior/room_%s%s.glb" % [_feel, Home.LAYOUTS[_layout_id]["file"]]


func _layout() -> Dictionary:
	return Home.LAYOUTS[_layout_id]


func _furnishing() -> Array:
	var list: Array = FURNISH.get(_house, [])
	if Lettings.HOUSES.has(_house):
		list = []
		var lv := Lettings.level(_house)
		if lv == 0 and HomeFolk.family_of(_house) != "":
			lv = 2              # a family lives here: their own things (Cosy) until you buy it and do it up
		for k in range(1 if lv > 0 else 0, lv + 1):
			list.append_array(LETTING[k])
	return list.map(func(p: Array) -> Dictionary: return {"id": p[0], "x": p[1], "z": p[2], "turn": p[3]})


func _half() -> Vector2:
	return Home.ROOM_HALF


func _go_in() -> void:
	super()
	_saving_was = SaveGame.paused
	SaveGame.paused = true
	# Hilmi's villagers live in the houses now (6 Oct: Enea's residents and tenants left the village): whoever is
	# home is inside, asleep, at the table or about the room (world/home_folk.gd).
	var folk := HomeFolk.inside(get_tree(), _house)

	_people.append_array(HomeFolk.place(self, origin, _furnishing(), folk))
	var family := HomeFolk.family_of(_house)
	var owner := ("The %s family's home" % family) if family != "" else ("The mill" if _house == 5 else "An empty house")
	if Lettings.HOUSES.has(_house) and Lettings.level(_house) > 0:
		owner += ", let from you (%s)" % Lettings.mood_word(_house)
	var asleep := folk.filter(func(f: Dictionary) -> bool: return f.verb == "sleeping").size()
	var line := "Nobody's home." if folk.is_empty() else ("Everyone's asleep." if asleep == folk.size() else
		("%d at home" % folk.size()) + (", %d asleep." % asleep if asleep > 0 else "."))
	get_tree().call_group("hud", "hint", "%s. %s" % [owner, line])


func _back_outside() -> void:
	super()
	SaveGame.paused = _saving_was
	for n in _people:
		n.queue_free()
	_people.clear()
