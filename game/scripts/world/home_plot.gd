extends Node3D
## Your home plot in the meadow (state: Home). Before you buy it: corner stakes and a "For sale" sign
## (it opens the buying screen). After: the house you chose and everything you've built in the yard;
## your front door opens the home screen (build, or move into another house). A built campfire cooks
## and a built workbench crafts.

const TREASURE := preload("res://scripts/world/treasure.gd")
const STATION := preload("res://scripts/world/station.gd")
const BOARD := preload("res://assets/props/site_board.glb")


var _shape: WorldShape
var _stuff: Node3D


func build(shape: WorldShape) -> void:
	_shape = shape
	_stuff = Node3D.new()
	add_child(_stuff)
	Home.changed.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	for n in _stuff.get_children():
		n.queue_free()
	var c := Home.PLOT_CENTER
	if not Home.owned():
		var sale := Node3D.new()                        # a "For sale" sign at the front of the plot
		sale.set_script(STATION)
		_stuff.add_child(sale)
		sale.setup(_at(c.x + 6.0, c.y + 8.5), "Look", {"mode": "home"}, BOARD, Vector3(1.4, 1.6, 0.3))
		sale.add_child(SignLabel.make("For sale"))
		for sx in [-1, 1]:                              # corner stakes with a little flag
			for sz in [-1, 1]:
				var stake := MeshInstance3D.new()
				var m := BoxMesh.new()
				m.size = Vector3(0.12, 1.0, 0.12)
				stake.mesh = m
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(0.55, 0.37, 0.23)
				stake.material_override = mat
				_stuff.add_child(stake)
				stake.global_position = _at(c.x + sx * 9.5, c.y - 4.0 + sz * 8.0) + Vector3(0, 0.5, 0)
		return
	var house := TREASURE._solid((load(Home.HOUSES[Home.house][1]) as PackedScene).instantiate())
	_stuff.add_child(house)
	house.global_position = _at(c.x, c.y - 7.0)
	house.add_to_group("map_building")
	house.set_meta("map_size", Vector2(6, 5))
	_collide(house, Vector3(0, 2, 0), Vector3(5.5, 4, 4.5))
	var door := Node3D.new()                            # walk up to your front door for the home menu
	door.set_script(STATION)
	_stuff.add_child(door)
	door.setup(_at(c.x, c.y - 3.6), "Home", {"mode": "home"})
	door.reach = 2.2
	for p: Dictionary in Home.pieces:
		var info: Array = Home.PIECES[p["id"]]
		var at := _at(p["x"], p["z"])
		var node := Node3D.new()
		_stuff.add_child(node)
		if info[3] != "":
			node.set_script(STATION)
			node.setup(at, "Cook" if info[3] == "cook" else "Craft", {"mode": info[3]}, load(info[1]))
		else:
			node.add_child(TREASURE._solid((load(info[1]) as PackedScene).instantiate()))
			node.global_position = at
		node.rotation.y = p["turn"]
		if p["id"] == "tree":
			node.scale = Vector3.ONE * 0.8
		if p["id"] not in ["flower_bed"]:
			_collide(node, Vector3(0, 0.6, 0), Vector3.ONE * info[2] * 1.2)


func _at(x: float, z: float) -> Vector3:
	return Vector3(x, _shape.height_at(x, z), z)


func _collide(n: Node3D, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position = at
	body.add_child(col)
	n.add_child(body)
