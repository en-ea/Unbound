extends Control
## The build lab's menu (from the Lab board): a panel on the right, so the showcase building stays in
## view. Switch the building with ‹ ›, spawn things in front of you, drop loot, clear, or leave.
## Spawning an enemy closes the menu so you can fight it.

signal closed

const PANEL_W := 470.0
const SPAWNS := [["Boar", "boar"], ["Wolf", "wolf"], ["Shadow wolf", "shadow"], ["Tree", "tree"], ["Pine", "pine"],
	["Apple tree", "apple"], ["Rock", "rock"], ["Copper ore", "copper"], ["Iron ore", "iron"], ["Chest", "chest"],
	["Bandit", "cutthroat"], ["Shield bandit", "shield"], ["Bandit archer", "archer"], ["Varek", "leader"]]
const ENEMIES := ["boar", "wolf", "shadow", "cutthroat", "shield", "archer", "leader"]

var lab: Node
var _name: Label
var _vname: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.panel())
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -PANEL_W - 40.0
	panel.offset_right = -40.0
	panel.offset_top = 12.0
	panel.offset_bottom = -12.0
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 8
	panel.add_child(scroll)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(col)
	var top := HBoxContainer.new()
	col.add_child(top)
	var title := UIStyle.label(top, "Build lab", 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIStyle.button(top, "Close", Vector2(110, 44), 18).pressed.connect(_close)
	_frame_pad()
	_head(col, "BUILDING ON THE PAD")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	UIStyle.button(row, "‹", Vector2(60, 50), 26).pressed.connect(func() -> void: _step(-1))
	_name = UIStyle.label(row, "", 18)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIStyle.button(row, "›", Vector2(60, 50), 26).pressed.connect(func() -> void: _step(1))
	_show_name()
	_head(col, "VILLAGERS")
	var vrow := HBoxContainer.new()
	vrow.add_theme_constant_override("separation", 8)
	col.add_child(vrow)
	UIStyle.button(vrow, "‹", Vector2(60, 50), 26).pressed.connect(func() -> void: _step_villager(-1))
	_vname = UIStyle.label(vrow, "", 18)
	_vname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vname.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.button(vrow, "›", Vector2(60, 50), 26).pressed.connect(func() -> void: _step_villager(1))
	var vgrid := _grid(col)
	UIStyle.button(vgrid, "Close-up", Vector2(0, 46), 16).pressed.connect(func() -> void: _frame_villager(true))
	UIStyle.button(vgrid, "Whole body", Vector2(0, 46), 16).pressed.connect(func() -> void: _frame_villager(false))
	UIStyle.button(vgrid, "Spin on/off", Vector2(0, 46), 16).pressed.connect(func() -> void: lab.spin = not lab.spin)
	UIStyle.button(vgrid, "Show building", Vector2(0, 46), 16).pressed.connect(_frame_pad)
	_show_villager_name()
	_head(col, "SPAWN IN FRONT OF YOU")
	var grid := _grid(col)
	for s: Array in SPAWNS:
		UIStyle.button(grid, s[0], Vector2(0, 46), 16).pressed.connect(func() -> void:
			lab.spawn(s[1])
			if s[1] in ENEMIES:
				_close())
	_head(col, "LOOT")
	var loot := _grid(col)
	UIStyle.button(loot, "Drop gear", Vector2(0, 46), 16).pressed.connect(func() -> void: lab.spawn("gear"))
	UIStyle.button(loot, "Drop sword", Vector2(0, 46), 16).pressed.connect(func() -> void: lab.spawn("sword"))
	UIStyle.button(loot, "Armour set", Vector2(0, 46), 16).pressed.connect(func() -> void:
		for slot: String in Armor.SLOTS:
			Armor.give(slot, Armor.piece(3, Loot.EPIC, Loot.roll_bonuses("armor", Loot.EPIC))))
	_head(col, "OTHER")
	var other := _grid(col)
	UIStyle.button(other, "Full hearts", Vector2(0, 46), 16).pressed.connect(func() -> void:
		get_tree().call_group("player", "heal_full"))
	UIStyle.button(other, "Clear spawns", Vector2(0, 46), 16).pressed.connect(func() -> void: lab.clear_spawns())
	UIStyle.button(other, "Leave lab", Vector2(0, 46), 16).pressed.connect(func() -> void:
		_close()
		lab.leave())


func _head(parent: Control, text: String) -> void:
	UIStyle.label(parent, text, 14, true)


func _grid(parent: Control) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.child_entered_tree.connect(func(b: Node) -> void: (b as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL)
	parent.add_child(g)
	return g


func _step(d: int) -> void:
	lab.show_building(lab.building + d)
	_show_name()


func _step_villager(d: int) -> void:
	var n: int = Npcs.NPCS.size()
	var next: int = lab.villager + d                 # -1 (nobody) sits between the last and the first
	if next >= n:
		next = -1
	elif next < -1:
		next = n - 1
	lab.show_villager(next)
	_show_villager_name()
	if next >= 0:
		_frame_villager(true)
	else:
		_frame_pad()


func _show_villager_name() -> void:
	_vname.text = "Nobody" if lab.villager < 0 else String(Npcs.NPCS.values()[lab.villager]["name"])


## The camera frames the villager beside the panel: close on the face, or the whole body.
func _frame_villager(close: bool) -> void:
	if lab.villager < 0:
		return
	var rig := get_tree().get_first_node_in_group("camera_rig")
	var h: float = lab.villager_height()
	var target: Vector3 = lab.AT + lab.VILLAGER_SPOT - lab.player.global_position
	target += Vector3(0.9 if close else 2.0, (h * 0.88 if close else h * 0.5) - 1.0, 0.0)
	rig.set_view(2.6 * h / 1.8 if close else 7.5, -6.0 if close else -12.0, target, 0.7)


func _show_name() -> void:
	_name.text = "%s  (%d / %d)" % [lab.BUILDINGS[lab.building][0], lab.building + 1, lab.BUILDINGS.size()]


## The camera pulls back to show the showcase building beside the panel.
func _frame_pad() -> void:
	var rig := get_tree().get_first_node_in_group("camera_rig")
	var target: Vector3 = lab.AT + lab.PAD - lab.player.global_position + Vector3(3.0, 0, 0)
	target.y = 0.0
	rig.set_view(19.0, -34.0, target, 0.7)


func _close() -> void:
	get_tree().get_first_node_in_group("camera_rig").reset_view()
	closed.emit()
	queue_free()
