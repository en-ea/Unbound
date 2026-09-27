extends Node3D
## The village workbench. Walk up to it and the action button says "Craft"; it opens the crafting
## screen (recipes and tools live in Gear). Also shows on the minimap like a building.

const MODEL := preload("res://assets/props/workbench.glb")
const TREASURE := preload("res://scripts/world/treasure.gd")

var verb := "Craft"
var reach := 2.6


func build(shape: WorldShape, at: Vector2) -> void:
	add_to_group("interactable")
	add_to_group("map_building")
	set_meta("map_size", Vector2(4.0, 3.0))
	add_child(TREASURE._solid(MODEL.instantiate()))
	global_position = Vector3(at.x, shape.height_at(at.x, at.y), at.y)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 1.2, 1.0)
	col.shape = box
	col.position = Vector3(0, 0.6, -0.3)
	body.add_child(col)
	add_child(body)


func interact() -> void:
	get_tree().call_group("hud", "open_crafting")
