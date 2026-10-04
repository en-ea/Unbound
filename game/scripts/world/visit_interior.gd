extends "res://scripts/world/home_interior.gd"
## Inside a resident's house in the meadow village (the Enter spots by their doors, world/village.gd):
## the same kind of room as your home, in that house's feel, with its own furniture, and whoever lives
## there inside when they're home (Residents: at night, or before they head out). You can talk to them
## and use their hearth; no furnishing, no sleeping in their bed, and the game doesn't save in here.

const FURNISH := {
	0: [{"id": "bed", "x": 3.85, "z": -2.7, "turn": 0.0}, {"id": "trunk", "x": 3.85, "z": -1.05, "turn": 0.0},
		{"id": "rug_long", "x": 0.4, "z": 0.4, "turn": 0.0}, {"id": "table", "x": 0.4, "z": 0.1, "turn": 0.0},
		{"id": "stool", "x": -0.2, "z": -0.66, "turn": 0.0}, {"id": "stool", "x": 1.0, "z": -0.66, "turn": 0.0}],
	1: [{"id": "bed", "x": 3.85, "z": -2.7, "turn": 0.0}, {"id": "dresser", "x": 3.85, "z": -1.05, "turn": 0.0},
		{"id": "rug_round", "x": 0.4, "z": 0.2, "turn": 0.0}, {"id": "table", "x": 0.4, "z": 0.1, "turn": 0.0},
		{"id": "chair", "x": 0.4, "z": -0.66, "turn": 0.0}],
	2: [{"id": "bed", "x": 3.85, "z": -2.7, "turn": 0.0}, {"id": "bed", "x": 3.85, "z": 0.2, "turn": 0.0},
		{"id": "rug_round", "x": 0.4, "z": 0.2, "turn": 0.0}, {"id": "table", "x": 0.4, "z": 0.1, "turn": 0.0},
		{"id": "chair", "x": -0.1, "z": -0.66, "turn": 0.0}, {"id": "chair", "x": 0.9, "z": -0.66, "turn": 0.0}],
}
const SPOTS := [Vector3(1.6, 0.0, 1.2), Vector3(-1.0, 0.0, 1.4)]     # where the people inside stand

var _house := -1
var _feel := "lodge"
var _people: Array[Node] = []
var _saving_was := false


func _init() -> void:
	origin = Vector3(-300, -300, 0)


## The action: go into house `index` (its room's `feel`), coming back out at `door`.
func visit(index: int, feel: String, door: Vector3) -> void:
	if active:
		return
	_house = index
	_feel = feel
	door_out = door
	enter()


func _is_home() -> bool:
	return false


func _can_enter() -> bool:
	return _house >= 0


func _model() -> String:
	return "res://assets/interior/room_%s.glb" % _feel


func _layout() -> Dictionary:
	return Home.LAYOUTS["hearth"]


func _furnishing() -> Array:
	return FURNISH.get(_house, [])


func _go_in() -> void:
	super()
	_saving_was = SaveGame.paused
	SaveGame.paused = true
	var spot := 0
	for id: String in Residents.ids():
		if Residents.def(id)["house"] != _house or Residents.activity(id) != "home" or spot >= SPOTS.size():
			continue
		var npc := Node3D.new()
		npc.set_script(preload("res://scripts/world/npc.gd"))
		add_child(npc)
		npc.setup(id, null, origin + SPOTS[spot])
		_people.append(npc)
		spot += 1
	if _people.is_empty():
		get_tree().call_group("hud", "hint", "Nobody's home.")


func _back_outside() -> void:
	super()
	SaveGame.paused = _saving_was
	for n in _people:
		n.queue_free()
	_people.clear()
