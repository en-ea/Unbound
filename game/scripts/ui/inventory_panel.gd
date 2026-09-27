extends Control
## The Bag: a grid of item cards (icon colour, name, count, rarity edge). Reads Inventory.

signal closed

const COLUMNS := 4

var _grid: GridContainer
var _empty: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_close())
	add_child(shade)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.panel())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(700, 460)
	panel.offset_left = -350
	panel.offset_right = 350
	panel.offset_top = -240
	panel.offset_bottom = 240
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := UIStyle.label(header, "Bag", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIStyle.button(header, "Close", Vector2(120, 46), 20).pressed.connect(_close)
	_empty = UIStyle.label(column, "Nothing yet. Chop a tree, mine a rock, or pick a flower.", 20, true)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_grid)
	Inventory.changed.connect(_on_changed)
	_refresh()


func _on_changed(_item: String, _count: int) -> void:
	_refresh()


func _refresh() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var items := Inventory.items()
	_empty.visible = items.is_empty()
	for item in items:
		_grid.add_child(_card(item))


func _card(item: String) -> Control:
	var card := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, 0.06)
	box.set_corner_radius_all(16)
	box.border_color = Items.RARITY_COLORS[Items.rarity_of(item)]
	box.set_border_width_all(2)
	box.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", box)
	card.custom_minimum_size = Vector2(152, 136)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var icon := Panel.new()
	icon.custom_minimum_size = Vector2(52, 52)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var dot := StyleBoxFlat.new()
	dot.bg_color = Items.color_of(item)
	dot.set_corner_radius_all(26)
	dot.border_color = Items.color_of(item).lightened(0.35)
	dot.set_border_width_all(3)
	icon.add_theme_stylebox_override("panel", dot)
	v.add_child(icon)
	var name_label := UIStyle.label(v, Items.name_of(item), 17)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var count := UIStyle.label(v, "× %d" % Inventory.count(item), 20)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return card


func _close() -> void:
	Inventory.changed.disconnect(_on_changed)
	closed.emit()
	queue_free()
