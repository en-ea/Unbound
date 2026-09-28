extends Control
## The Bag. Left: your equipped tools (tap another one you own to switch; Drop) and your skills.
## Right: your items as a tidy grid, filtered by All / Materials / Food / Loot. Tap an item to see
## what it's for, what the trader pays, and (for food) eat it. Reads Inventory, Gear and Skills.

signal closed

const COLUMNS := 5
const CRAFTING := preload("res://scripts/ui/crafting_panel.gd")
const FILTERS := {"all": "All", "material": "Materials", "food": "Food", "loot": "Loot"}

var _grid: GridContainer
var _empty: Label
var _gear: VBoxContainer
var _slots: Label
var _tabs: HBoxContainer
var _detail: PanelContainer
var _filter := "all"
var _selected := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.4)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_close())
	add_child(shade)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.panel())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -560
	panel.offset_right = 560
	panel.offset_top = -330
	panel.offset_bottom = 330
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	column.add_child(header)
	var title := UIStyle.label(header, "Bag", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIStyle.price(header, Money.coins, 24)
	UIStyle.button(header, "Close", Vector2(120, 46), 20).pressed.connect(_close)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	_gear = VBoxContainer.new()
	_gear.add_theme_constant_override("separation", 8)
	_gear.custom_minimum_size.x = 300
	body.add_child(_gear)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	right.add_child(top)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_tabs)
	_slots = UIStyle.label(top, "", 15, true)
	_slots.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty = UIStyle.label(right, "Nothing here yet.", 18, true)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 8
	right.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(_grid)
	_detail = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, 0.06)
	box.set_corner_radius_all(16)
	box.set_content_margin_all(10)
	_detail.add_theme_stylebox_override("panel", box)
	_detail.custom_minimum_size.y = 96
	right.add_child(_detail)
	Inventory.changed.connect(_on_changed)
	ItemIcons.icon_ready.connect(_on_icon_ready)
	Gear.changed.connect(_refresh_gear)
	_refresh()
	_refresh_gear()


## "Equipped": a tile per tool (picture, full name, a frame in its rarity colour, a small Drop
## button); your other tools sit under it as small pictures, tap one to switch. Then the skills.
func _refresh_gear() -> void:
	for c in _gear.get_children():
		c.queue_free()
	UIStyle.label(_gear, "EQUIPPED", 15, true)
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_gear.add_child(row)
	for slot: String in Gear.SLOTS:
		var tool := Gear.current(slot)
		var tile := PanelContainer.new()
		var box := StyleBoxFlat.new()
		box.bg_color = Color(1, 1, 1, 0.07)
		box.set_corner_radius_all(16)
		box.border_color = Items.RARITY_COLORS[tool.get("rarity", 0)] if tool.get("rarity", 0) > 0 else Color(1, 1, 1, 0.25)
		box.set_border_width_all(3)
		box.set_content_margin_all(8)
		tile.add_theme_stylebox_override("panel", box)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(tile)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		tile.add_child(h)
		if tool.is_empty():
			var fist := UIStyle.label(h, "Hands", 15, true)
			fist.custom_minimum_size = Vector2(64, 64)
			fist.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			fist.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		else:
			h.add_child(CRAFTING.tool_picture(slot, tool["tier"], 56))
		var info := VBoxContainer.new()
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(info)
		var name_label := UIStyle.label(info, Gear.name_of(slot, tool), 16)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.custom_minimum_size.x = 120
		var others := HBoxContainer.new()
		others.add_theme_constant_override("separation", 4)
		info.add_child(others)
		for k in Gear.owned[slot].size():
			if k == Gear.equipped[slot]:
				continue
			var o: Dictionary = Gear.owned[slot][k]
			var b := Button.new()
			b.flat = true
			b.custom_minimum_size = Vector2(38, 38)
			b.icon = ItemIcons.tool_icon(slot, o["tier"])
			b.expand_icon = true
			if o["rarity"] > 0:
				b.modulate = Items.RARITY_COLORS[o["rarity"]].lightened(0.3)
			b.pressed.connect(Gear.equip.bind(slot, k))
			others.add_child(b)
		if not tool.is_empty():
			var drop := UIStyle.button(others, "Drop", Vector2(64, 34), 14)
			drop.pressed.connect(func() -> void:
				if drop.text == "Sure?":
					Gear.drop_tool(slot)
				else:
					drop.text = "Sure?")
	# Skills: name, level and a bar each.
	UIStyle.label(_gear, "SKILLS", 15, true)
	var skills := VBoxContainer.new()
	skills.add_theme_constant_override("separation", 6)
	_gear.add_child(skills)
	for skill: String in Skills.SKILLS:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 3)
		skills.add_child(cell)
		UIStyle.label(cell, "%s  Lv %d" % [Skills.SKILLS[skill], Skills.level(skill)], 16)
		var track := ColorRect.new()
		track.color = Color(1, 1, 1, 0.1)
		track.custom_minimum_size = Vector2(0, 7)
		cell.add_child(track)
		var fill := ColorRect.new()
		fill.color = Color(1.0, 0.84, 0.46)
		fill.anchor_bottom = 1.0
		fill.anchor_right = Skills.progress(skill)
		track.add_child(fill)
		var perk := UIStyle.label(cell, Skills.perk_text(skill), 13, true)
		perk.clip_text = true
	_slots.text = "%d / %d slots" % [Inventory.items().size(), Gear.bag_slots()]


func _on_icon_ready(item: String) -> void:
	if item.begins_with("tool:"):
		_refresh_gear()
	else:
		_refresh()


func _on_changed(_item: String, _count: int) -> void:
	_refresh()
	_refresh_gear()


func _refresh() -> void:
	for c in _tabs.get_children():
		c.queue_free()
	for f: String in FILTERS:
		var b := UIStyle.button(_tabs, FILTERS[f], Vector2(0, 42), 17)
		b.custom_minimum_size.x = 96
		b.modulate = Color(1.0, 0.9, 0.66) if f == _filter else Color(1, 1, 1, 0.55)
		b.pressed.connect(func() -> void:
			_filter = f
			_refresh())
	for c in _grid.get_children():
		c.queue_free()
	var items := Inventory.items().filter(func(i: String) -> bool: return _filter == "all" or Items.kind_of(i) == _filter)
	_empty.visible = items.is_empty()
	for item: String in items:
		_grid.add_child(_card(item))
	if _selected != "" and Inventory.count(_selected) <= 0:
		_selected = ""
	_show_detail()


## A square tile: picture, a count badge and the name; its edge in the item's rarity colour.
func _card(item: String) -> Control:
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(122, 122)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	for state in ["normal", "hover", "pressed"]:
		var box := StyleBoxFlat.new()
		var rc: Color = Items.RARITY_COLORS[Items.rarity_of(item)]
		box.bg_color = Color(1, 1, 1, 0.12 if item == _selected else 0.05)
		box.set_corner_radius_all(16)
		box.border_color = Color(1.0, 0.9, 0.66) if item == _selected else rc
		box.set_border_width_all(3 if item == _selected else 2)
		card.add_theme_stylebox_override(state, box)
	card.pressed.connect(func() -> void:
		_selected = item
		_refresh())
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	v.add_child(item_icon(item, 58))
	var name_label := UIStyle.label(v, Items.name_of(item), 14)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.custom_minimum_size.x = 110
	var count := UIStyle.label(card, "×%d" % Inventory.count(item), 16)
	count.position = Vector2(8, 4)
	count.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	count.add_theme_constant_override("outline_size", 5)
	return card


## The selected item: picture, name, rarity, what it's for, value, and Eat for food.
func _show_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()
	if _selected == "":
		var hint := UIStyle.label(_detail, "Tap an item to see what it's for.", 16, true)
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		return
	var item := _selected
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	_detail.add_child(h)
	h.add_child(item_icon(item, 72))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	h.add_child(info)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	info.add_child(name_row)
	UIStyle.label(name_row, "%s  ×%d" % [Items.name_of(item), Inventory.count(item)], 21)
	var r := Items.rarity_of(item)
	var rl := UIStyle.label(name_row, Items.RARITY_NAMES[r], 15)
	rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rl.add_theme_color_override("font_color", Items.RARITY_COLORS[r] if r > 0 else Color(1, 1, 1, 0.6))
	var text: String = Food.describe(item) if Food.is_food(item) else Items.DESC.get(item, "")
	var d := UIStyle.label(info, text, 15, true)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var worth := HBoxContainer.new()
	worth.add_theme_constant_override("separation", 6)
	info.add_child(worth)
	UIStyle.label(worth, "Trader pays", 14, true)
	UIStyle.price(worth, Items.value_of(item), 15)
	if Food.is_food(item):
		var eat := UIStyle.button(h, "Eat", Vector2(110, 56), 20)
		eat.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		eat.pressed.connect(func() -> void: get_tree().call_group("player", "eat", item))


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
