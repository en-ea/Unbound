extends Node3D
## Something you use with the action button that runs a function straight away (a door, a bed),
## rather than opening a screen like station.gd. Walk up to it and the button shows `verb`.

var verb := "Use"
var reach := 1.8
var on_use: Callable


func setup(at: Vector3, v: String, action: Callable, r := 1.8) -> void:
	add_to_group("interactable")
	verb = v
	on_use = action
	reach = r
	global_position = at


func interact() -> void:
	if on_use.is_valid():
		on_use.call()
