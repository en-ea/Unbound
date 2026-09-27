extends Control
## The Bag: your tools (tap a tier you own to use it) and a grid of item cards (icon, name, count,
## rarity edge). Reads Inventory and Gear.

signal closed

const COLUMNS := 4
const CRAFTING := preload("res://scripts/ui/crafting_panel.gd")

var _grid: GridContainer
var _empty: Label
var _gear: VBoxContainer


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
	_gear = VBoxContainer.new()
	_gear.add_theme_constant_override("separation", 6)
	column.add_child(_gear)
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
	ItemIcons.icon_ready.connect(_on_icon_ready)
	Gear.changed.connect(_refresh_gear)
	_refresh()
	_refresh_gear()


## One row per tool slot: a badge for every tier you own; the equipped one is bigger.
func _refresh_gear() -> void:
	for c in _gear.get_children():
		c.queue_free()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	_gear.add_child(row)
	for slot: String in Gear.SLOTS:
		var group := HBoxContainer.new()
		group.add_theme_constant_override("separation", 6)
		row.add_child(group)
		for t: int in Gear.owned[slot]:
			var on := Gear.tier(slot) == t
			var b := Button.new()
			b.flat = true
			b.custom_minimum_size = Vector2(52, 52)
			var badge := CRAFTING.badge(slot, t, 44 if on else 32)
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(badge)
			badge.position = Vector2(4, 4) if on else Vector2(10, 10)
			b.pressed.connect(Gear.equip.bind(slot, t))
			group.add_child(b)
	var names: Array[String] = []
	for slot: String in Gear.SLOTS:
		names.append(Gear.tool_name(slot, Gear.tier(slot)))
	UIStyle.label(_gear, "Using: " + ", ".join(names) + "  (tap a badge to switch)", 16, true)


func _on_icon_ready(_item: String) -> void:
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
	v.add_child(item_icon(item, 64))
	var name_label := UIStyle.label(v, Items.name_of(item), 17)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var count := UIStyle.label(v, "× %d" % Inventory.count(item), 20)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return card


## The item's rendered picture, or a colour dot while it is still being drawn.
static func item_icon(item: String, size: float) -> Control:
	var tex := ItemIcons.icon(item)
	if tex:
		var rect := TextureRect.new()
		rect.texture = tex
		rect.custom_minimum_size = Vector2(size, size)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return rect
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(size, size) * 0.6
	dot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Items.color_of(item)
	box.set_corner_radius_all(int(size))
	dot.add_theme_stylebox_override("panel", box)
	return dot


func _close() -> void:
	Inventory.changed.disconnect(_on_changed)
	ItemIcons.icon_ready.disconnect(_on_icon_ready)
	Gear.changed.disconnect(_refresh_gear)
	closed.emit()
	queue_free()
