extends Node3D
## A place you use with the action button (campfire, trader, project board): walk up to it and the
## button shows `verb`; pressing it asks the HUD to open `screen` (see hud.gd open_station).
## Optional model, collision box and a map marker.

const TREASURE := preload("res://scripts/world/treasure.gd")

var verb := "Use"
var reach := 2.4
var screen := {}         # properties for the shop panel, e.g. {"mode": "cook"}


func setup(at: Vector3, v: String, props: Dictionary, model: PackedScene = null, box := Vector3.ZERO) -> void:
	add_to_group("interactable")
	verb = v
	screen = props
	if model:
		add_child(TREASURE._solid(model.instantiate()))
	global_position = at
	if box != Vector3.ZERO:
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box
		col.shape = shape
		col.position = Vector3(0, box.y / 2.0, 0)
		body.add_child(col)
		add_child(body)


func interact() -> void:
	get_tree().call_group("hud", "open_station", screen)
