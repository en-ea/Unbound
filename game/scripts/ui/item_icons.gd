extends Node
## Renders each item's 3D model once into a small picture, for the Bag and the pickup feed; also
## every tool at every tier ("tool:axe:2"), its head tinted in the tier's colour.
## Works through a queue, one item every couple of frames, starting at game load.

signal icon_ready(item: String)

const SIZE := 128

var _icons := {}
var _queue: Array[String] = []
var _viewport: SubViewport
var _holder: Node3D
var _current := ""
var _frames := 0


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(SIZE, SIZE)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.9)
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -35, 0)
	light.light_energy = 1.7
	light.light_color = Color(1, 0.96, 0.88)
	_viewport.add_child(light)
	var cam := Camera3D.new()
	cam.fov = 30.0
	_viewport.add_child(cam)
	cam.look_at_from_position(Vector3(0, 0.22, 0.82), Vector3.ZERO)
	_holder = Node3D.new()
	_viewport.add_child(_holder)
	for slot: String in Gear.SLOTS:
		for t in Gear.TIERS.size():
			_queue.append("tool:%s:%d" % [slot, t])
	for slot: String in Armor.SLOTS:
		for t in Armor.TIERS.size():
			_queue.append("tool:%s:%d" % [slot, t])
	for item: String in Items.DEFS:
		_queue.append(item)


## An item's picture (null until drawn). "house:<id>" draws a home's model, on first ask.
func icon(item: String) -> Texture2D:
	if item.begins_with("house:") and not _icons.has(item) and item != _current and not item in _queue:
		_queue.push_front(item)
		set_process(true)
	return _icons.get(item)


func tool_icon(slot: String, tier: int) -> Texture2D:
	return _icons.get("tool:%s:%d" % [slot, tier])


func _process(_delta: float) -> void:
	if _current == "":
		if _queue.is_empty():
			set_process(false)
			return
		_current = _queue.pop_front()
		for c in _holder.get_children():
			c.queue_free()
		if _current.begins_with("house:"):
			_house_model(_current.trim_prefix("house:"))
			_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			_frames = 0
			return
		var mi := MeshInstance3D.new()
		var tilt := Vector3(8, 35, 0)
		if _current.begins_with("tool:"):
			var bits := _current.split(":")
			_tool_mesh(mi, bits[1], int(bits[2]))
			if not Armor.SLOTS.has(bits[1]):
				tilt = Vector3(0, 20, -42)     # a tool lies diagonally, head up and right
		else:
			mi.mesh = Items.mesh(_current)
		var box := mi.mesh.get_aabb()
		var fit := 0.42 / maxf(box.size.x, maxf(box.size.y, box.size.z))
		mi.scale = Vector3.ONE * fit
		mi.position = -box.get_center() * fit
		var turn := Node3D.new()
		turn.rotation_degrees = tilt
		turn.add_child(mi)
		_holder.add_child(turn)
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		_frames = 0
	else:
		_frames += 1
		if _frames >= 2:
			_icons[_current] = ImageTexture.create_from_image(_viewport.get_texture().get_image())
			icon_ready.emit(_current)
			_current = ""


## The tool's (or armour piece's) own model, its metal tinted for the tier.
func _tool_mesh(mi: MeshInstance3D, slot: String, tier: int) -> void:
	var armor := Armor.SLOTS.has(slot)
	var scene := (load("res://assets/items/%s.glb" % (("armor_" + slot) if armor else slot)) as PackedScene).instantiate()
	var src := scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	mi.mesh = src.mesh
	for s in mi.mesh.get_surface_count():
		var mat := mi.mesh.surface_get_material(s)
		if mat and mat.resource_name == "Metal":
			var tinted := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
			tinted.albedo_color = (Armor.TIERS if armor else Gear.TIERS)[tier]["color"]
			mi.set_surface_override_material(s, tinted)
	scene.free()


## A home's whole model, fitted into the picture and turned a little so you see its front and side.
func _house_model(id: String) -> void:
	var turn := Node3D.new()
	turn.rotation_degrees = Vector3(10, -30, 0)
	_holder.add_child(turn)
	var scene := preload("res://scripts/world/treasure.gd")._solid((load(Home.HOUSES[id][1]) as PackedScene).instantiate()) as Node3D
	turn.add_child(scene)
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var b := (scene.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var fit := 0.46 / maxf(box.size.x, maxf(box.size.y, box.size.z))
	scene.scale = Vector3.ONE * fit
	scene.position = -box.get_center() * fit
