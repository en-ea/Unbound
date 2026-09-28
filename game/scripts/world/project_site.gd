extends Node3D
## A village project's spot (Projects.DEFS): scaffolding and a notice board until it's funded, then
## the finished building. The board opens the project screen; once built it stays as a sign.

const BOARD := preload("res://assets/props/site_board.glb")
const SCAFFOLD := preload("res://assets/props/scaffold.glb")
const MODELS := {"smithy": preload("res://assets/props/smithy.glb")}
const STATION := preload("res://scripts/world/station.gd")
const TREASURE := preload("res://scripts/world/treasure.gd")

var _id := ""
var _shape: WorldShape
var _building: Node3D


func build(shape: WorldShape, id: String) -> void:
	_id = id
	_shape = shape
	var at: Vector2 = Projects.DEFS[id]["at"]
	global_position = Vector3(at.x, shape.height_at(at.x, at.y), at.y)
	add_to_group("map_building")
	set_meta("map_size", Vector2(4.6, 3.6))
	var board := Node3D.new()
	board.set_script(STATION)
	add_child(board)
	board.setup(global_position + Vector3(0.5, 0, 3.0), "Look", {"mode": "project", "project": id}, BOARD, Vector3(1.4, 1.6, 0.3))
	var sign := Label3D.new()
	sign.text = Projects.DEFS[id]["name"]
	sign.font_size = 44
	sign.outline_size = 12
	sign.pixel_size = 0.008
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = Vector3(0, 2.3, 0)
	board.add_child(sign)
	_show(false)
	Projects.built.connect(func(b: String) -> void:
		if b == _id:
			_show(true))


func _show(animate: bool) -> void:
	if _building:
		_building.queue_free()
	var model: PackedScene = MODELS[_id] if Projects.is_built(_id) else SCAFFOLD
	_building = TREASURE._solid(model.instantiate())
	add_child(_building)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.4, 3.0, 3.4)
	col.shape = box
	col.position = Vector3(0, 1.5, 0.2)
	body.add_child(col)
	_building.add_child(body)
	if animate:
		_building.scale = Vector3(1, 0.01, 1)
		create_tween().tween_property(_building, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
