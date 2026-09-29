extends Control
## Building in your yard, or furnishing your home (`room` = true): a preview of the chosen piece stands
## in front of you, snapped to a grid (green outline = fits, red = doesn't). Walk to move it; pick a
## piece with ‹ ›, turn it, place it, or take down / put away the piece nearest the preview.
## Snap (on by default) lines things up. In the yard: fences join end to end or at a corner, lantern
## posts sit on fence ends, everything else keeps to a 1 m grid and square turns. Indoors: a half-metre
## grid, square turns, and beds, shelves, wardrobes and dressers back onto the nearest wall.
## Changes go through Home.place() / remove() (yard) and Home.furnish() / put_away() (room).

signal closed

const TREASURE := preload("res://scripts/world/treasure.gd")

var player: Node3D
var room := false                 # furnishing indoors instead of building in the yard
var origin := Vector3.ZERO        # indoors: the room's centre on the floor (world/home_interior.gd)
var _ids: Array
var _pick := 0
var _turn := 0.0
var _ghost: Node3D
var _ring: MeshInstance3D
var _name: Label
var _cost: Label
var _place: Button
var _snap := true
var _placed_turn := 0.0
var _placed := Vector2.ZERO       # yard: world x, z; room: room x, z
var _snap_button: Button


func _ready() -> void:
	add_to_group("build_mode")
	_ids = Home.FURNITURE.keys() if room else Home.PIECES.keys()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.panel())
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.offset_top = 12
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	UIStyle.button(row, "‹", Vector2(56, 50), 26).pressed.connect(_step.bind(-1))
	var mid := VBoxContainer.new()
	mid.custom_minimum_size.x = 260
	mid.add_theme_constant_override("separation", -2)
	row.add_child(mid)
	_name = UIStyle.label(mid, "", 22)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost = UIStyle.label(mid, "", 15, true)
	_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.button(row, "›", Vector2(56, 50), 26).pressed.connect(_step.bind(1))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(buttons)
	UIStyle.button(buttons, "Turn", Vector2(100, 48), 19).pressed.connect(func() -> void: _turn += PI / (2.0 if _snap else 4.0))
	_snap_button = UIStyle.button(buttons, "Snap: on", Vector2(120, 48), 19)
	_snap_button.pressed.connect(func() -> void:
		_snap = not _snap
		_snap_button.text = "Snap: on" if _snap else "Snap: off")
	_place = UIStyle.button(buttons, "Place", Vector2(110, 48), 19)
	_place.pressed.connect(_do_place)
	UIStyle.button(buttons, "Put away" if room else "Take down", Vector2(130, 48), 19).pressed.connect(_take_down)
	UIStyle.button(buttons, "Done", Vector2(100, 48), 19).pressed.connect(_close)
	_ring = MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring.material_override = mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	player.get_parent().add_child(_ring)
	Inventory.changed.connect(_on_items)
	Home.furniture_changed.connect(_show_piece)
	_show_piece()


func _on_items(_i: String, _c: int) -> void:
	_show_piece()


func _step(d: int) -> void:
	_pick = posmod(_pick + d, _ids.size())
	_show_piece()


func _info(id: String) -> Array:
	return Home.FURNITURE[id] if room else Home.PIECES[id]


func _price(id: String) -> Dictionary:
	return Balance.HOME_FURNITURE[id] if room else Balance.HOME_PIECES[id]


func _show_piece() -> void:
	var id: String = _ids[_pick]
	_name.text = _info(id)[0]
	if room and Home.stored.get(id, 0) > 0:
		_cost.text = "%d put away (free to place)" % Home.stored[id]
	else:
		var parts: Array[String] = []
		for item: String in _price(id):
			parts.append("%d/%d %s" % [mini(Inventory.count(item), _price(id)[item]), _price(id)[item], Items.name_of(item)])
		_cost.text = ", ".join(parts)
	if _ghost:
		_ghost.queue_free()
	_ghost = TREASURE._solid((load(_info(id)[1]) as PackedScene).instantiate())
	player.get_parent().add_child(_ghost)
	if room:                               # a flat outline of the piece's footprint
		var plate := BoxMesh.new()
		var size: Vector2 = Home.FURNITURE[id][2]
		plate.size = Vector3(size.x, 0.03, size.y)
		_ring.mesh = plate
	else:
		var disc := CylinderMesh.new()
		disc.height = 0.04
		disc.radial_segments = 24
		disc.top_radius = Home.PIECES[id][2]
		disc.bottom_radius = Home.PIECES[id][2]
		_ring.mesh = disc


func _process(_delta: float) -> void:
	if not _ghost:
		return
	var id: String = _ids[_pick]
	var face: float = player.visual.rotation.y
	var ahead := 1.9 if room else 2.6
	var p: Vector3 = player.global_position + Vector3(sin(face), 0, cos(face)) * ahead - origin
	var turn := _turn
	var grid := (0.5 if _snap else 0.25) if room else (1.0 if _snap else 0.5)
	p.x = snappedf(p.x, grid)
	p.z = snappedf(p.z, grid)
	if _snap:
		turn = snappedf(_turn, PI / 2.0)
		var hook := _wall_hook(id, Vector2(p.x, p.z)) if room else _hook(id, Vector2(p.x, p.z))
		if not hook.is_empty():
			p.x = hook[0].x
			p.z = hook[0].y
			turn = hook[1]
	var floor_y: float = origin.y if room else player.global_position.y - 0.05
	_ghost.global_position = Vector3(p.x, floor_y, p.z) + Vector3(origin.x, 0, origin.z)
	_ghost.rotation.y = turn
	_placed_turn = turn
	_placed = Vector2(p.x, p.z)
	_ghost.scale = Vector3.ONE * (0.8 if id == "tree" else 1.0)
	_ring.global_position = _ghost.global_position + Vector3(0, 0.03, 0)
	_ring.rotation.y = turn
	var ok := Home.room_fits(id, p.x, p.z, turn) if room else Home.fits(id, p.x, p.z)
	var afford := Home.can_furnish(id) if room else Gear.can_afford(Balance.HOME_PIECES[id])
	(_ring.material_override as StandardMaterial3D).albedo_color = Color(0.4, 1.0, 0.5, 0.45) if ok and afford else Color(1.0, 0.35, 0.3, 0.45)
	_place.disabled = not (ok and afford)


func _do_place() -> void:
	var id: String = _ids[_pick]
	if room:
		Home.furnish(id, _placed.x, _placed.y, _placed_turn)
	else:
		Home.place(id, _placed.x, _placed.y, _placed_turn)


func _take_down() -> void:
	if room:
		Home.put_away(Home.furniture_near(_placed.x, _placed.y))
	else:
		Home.remove(Home.nearest(_placed.x, _placed.y))


## Indoors: a bed, shelf, wardrobe or dresser near a wall backs onto it, facing into the room.
## Returns [spot, turn], or [] when it isn't a wall piece or no wall is near.
func _wall_hook(id: String, at: Vector2) -> Array:
	if Home.FURNITURE[id][3] != "wall":
		return []
	var depth: float = Home.FURNITURE[id][2].y
	var h := Home.ROOM_HALF
	var gaps := {"back": at.y + h.y, "west": at.x + h.x, "east": h.x - at.x}
	var wall: String = gaps.keys().reduce(func(a: String, b: String) -> String: return a if gaps[a] <= gaps[b] else b)
	if gaps[wall] > 1.4:
		return []
	match wall:
		"back":
			return [Vector2(at.x, -h.y + depth / 2.0), 0.0]
		"west":
			return [Vector2(-h.x + depth / 2.0, at.y), PI / 2.0]
		_:
			return [Vector2(h.x - depth / 2.0, at.y), -PI / 2.0]


## Snapping onto what's already built: a fence continues a fence (straight on, or round a corner),
## a lantern post goes on a fence end. Returns [spot, turn], or [] when nothing is near.
func _hook(id: String, at: Vector2) -> Array:
	if id not in ["fence", "lantern_post"]:
		return []
	var best: Array = []
	var best_d := 1.6
	for f: Dictionary in Home.pieces:
		if f["id"] != "fence":
			continue
		var t: float = f["turn"]
		var along := Vector2(cos(t), -sin(t))            # the fence's 2 m run (its local x)
		var across := Vector2(-along.y, along.x)
		var c := Vector2(f["x"], f["z"])
		var spots: Array = []
		for s: float in [-1.0, 1.0]:
			var end: Vector2 = c + along * s
			if id == "lantern_post":
				spots.append([end, t])
			else:
				spots.append([c + along * 2.0 * s, t])                           # straight on
				for k: float in [-1.0, 1.0]:
					spots.append([end + across * k, t + PI / 2.0])               # round a corner
		for sp: Array in spots:
			var d: float = at.distance_to(sp[0])
			if d < best_d and Home.fits(id, sp[0].x, sp[0].y):
				best_d = d
				best = sp
	return best


func _close() -> void:
	Inventory.changed.disconnect(_on_items)
	Home.furniture_changed.disconnect(_show_piece)
	if _ghost:
		_ghost.queue_free()
	_ring.queue_free()
	closed.emit()
	queue_free()
