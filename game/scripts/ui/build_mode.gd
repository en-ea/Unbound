extends Control
## Building in your yard: a preview of the chosen piece stands in front of you, snapped to a half-metre
## grid (green ring = fits, red = doesn't). Walk to move it; pick a piece with ‹ ›, turn it, place it,
## or take down the piece nearest the preview. Changes go through Home.place() and Home.remove().

signal closed

const TREASURE := preload("res://scripts/world/treasure.gd")
const AHEAD := 2.6

var player: Node3D
var _ids: Array = Home.PIECES.keys()
var _pick := 0
var _turn := 0.0
var _ghost: Node3D
var _ring: MeshInstance3D
var _name: Label
var _cost: Label
var _place: Button


func _ready() -> void:
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
	UIStyle.button(buttons, "Turn", Vector2(100, 48), 19).pressed.connect(func() -> void: _turn += PI / 4.0)
	_place = UIStyle.button(buttons, "Place", Vector2(110, 48), 19)
	_place.pressed.connect(_do_place)
	UIStyle.button(buttons, "Take down", Vector2(130, 48), 19).pressed.connect(func() -> void:
		var g := _ghost.global_position
		Home.remove(Home.nearest(g.x, g.z)))
	UIStyle.button(buttons, "Done", Vector2(100, 48), 19).pressed.connect(_close)
	_ring = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.height = 0.04
	disc.radial_segments = 24
	_ring.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring.material_override = mat
	player.get_parent().add_child(_ring)
	Inventory.changed.connect(_on_items)
	_show_piece()


func _on_items(_i: String, _c: int) -> void:
	_show_piece()


func _step(d: int) -> void:
	_pick = posmod(_pick + d, _ids.size())
	_show_piece()


func _show_piece() -> void:
	var id: String = _ids[_pick]
	_name.text = Home.PIECES[id][0]
	var parts: Array[String] = []
	for item: String in Balance.HOME_PIECES[id]:
		parts.append("%d/%d %s" % [mini(Inventory.count(item), Balance.HOME_PIECES[id][item]), Balance.HOME_PIECES[id][item], Items.name_of(item)])
	_cost.text = ", ".join(parts)
	if _ghost:
		_ghost.queue_free()
	_ghost = TREASURE._solid((load(Home.PIECES[id][1]) as PackedScene).instantiate())
	player.get_parent().add_child(_ghost)
	(_ring.mesh as CylinderMesh).top_radius = Home.PIECES[id][2]
	(_ring.mesh as CylinderMesh).bottom_radius = Home.PIECES[id][2]


func _process(_delta: float) -> void:
	if not _ghost:
		return
	var face: float = player.visual.rotation.y
	var p: Vector3 = player.global_position + Vector3(sin(face), 0, cos(face)) * AHEAD
	p.x = snappedf(p.x, 0.5)
	p.z = snappedf(p.z, 0.5)
	_ghost.global_position = Vector3(p.x, player.global_position.y - 0.05, p.z)
	_ghost.rotation.y = _turn
	_ghost.scale = Vector3.ONE * (0.8 if _ids[_pick] == "tree" else 1.0)
	_ring.global_position = _ghost.global_position + Vector3(0, 0.05, 0)
	var id: String = _ids[_pick]
	var ok := Home.fits(id, p.x, p.z)
	var afford := Gear.can_afford(Balance.HOME_PIECES[id])
	(_ring.material_override as StandardMaterial3D).albedo_color = Color(0.4, 1.0, 0.5, 0.45) if ok and afford else Color(1.0, 0.35, 0.3, 0.45)
	_place.disabled = not (ok and afford)


func _do_place() -> void:
	var g := _ghost.global_position
	Home.place(_ids[_pick], g.x, g.z, _turn)


func _close() -> void:
	Inventory.changed.disconnect(_on_items)
	if _ghost:
		_ghost.queue_free()
	_ring.queue_free()
	closed.emit()
	queue_free()
