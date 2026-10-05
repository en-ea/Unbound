extends Control
## The stash in your home's trunk (Home.stash): your Bag on the left, the stash on the right. Tap a row's
## buttons to move one or all of a thing across. The stash holds Home.stash_room() different things
## (more in a grand home). Opened from the trunk indoors (world/home_interior.gd).

signal closed

const INVENTORY := preload("res://scripts/ui/inventory_panel.gd")

var _bag: VBoxContainer
var _box: VBoxContainer
var _room: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_close())
	add_child(shade)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.panel())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -540
	panel.offset_right = 540
	panel.offset_top = -310
	panel.offset_bottom = 310
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	var title := UIStyle.label(top, "Stash", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room = UIStyle.label(top, "", 17, true)
	_room.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIStyle.button(top, "Close", Vector2(120, 46), 20).pressed.connect(_close)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(cols)
	_bag = _side(cols, "Your bag")
	_box = _side(cols, "Kept at home")
	Inventory.changed.connect(_on_items)
	Home.stash_changed.connect(_refresh)
	_refresh()


func _side(parent: Node, heading: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	parent.add_child(v)
	UIStyle.label(v, heading, 20)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 8
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	return list


func _on_items(_i: String, _c: int) -> void:
	_refresh()


func _refresh() -> void:
	for list: VBoxContainer in [_bag, _box]:
		for c in list.get_children():
			c.queue_free()
	_room.text = "%d / %d kinds   " % [Home.stash.size(), Home.stash_room()]
	var full := Home.stash.size() >= Home.stash_room()
	for item: String in Inventory.items():
		if not Items.QUEST_ITEMS.has(item):
			_row(_bag, item, Inventory.count(item), "Store", func(n: int) -> void: Home.store(item, n), full and not Home.stash.has(item))
	if Home.stash.is_empty():
		UIStyle.label(_box, "Nothing kept here yet. Store things from your bag to free up room.", 16, true).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for item: String in Home.stash:
		_row(_box, item, Home.stash[item], "Take", func(n: int) -> void: Home.take_out(item, n), not Inventory.has_room(item))


## One line: picture, name and count, then "<verb> 1" and "<verb> all".
func _row(list: VBoxContainer, item: String, count: int, verb: String, move: Callable, blocked: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	list.add_child(row)
	row.add_child(INVENTORY.item_icon(item, 40))
	var n := UIStyle.label(row, "%s  ×%d" % [Items.name_of(item), count], 17)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	n.clip_text = true
	var one := UIStyle.button(row, verb + " 1", Vector2(84, 42), 16)
	var all := UIStyle.button(row, "All", Vector2(64, 42), 16)
	one.disabled = blocked
	all.disabled = blocked
	one.pressed.connect(func() -> void: move.call(1))
	all.pressed.connect(func() -> void: move.call(count))


func _close() -> void:
	Inventory.changed.disconnect(_on_items)
	Home.stash_changed.disconnect(_refresh)
	closed.emit()
	queue_free()
