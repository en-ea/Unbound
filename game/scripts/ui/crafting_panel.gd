extends Control
## The workbench screen: every tool recipe as a card (tier badge, name, what it does, its cost
## with what you have), grouped by tier, with a Craft button. Crafting goes through Gear.craft().

signal closed

var _list: VBoxContainer


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
	panel.offset_left = -380
	panel.offset_right = 380
	panel.offset_top = -255
	panel.offset_bottom = 255
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := UIStyle.label(header, "Workbench", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIStyle.button(header, "Close", Vector2(120, 46), 20).pressed.connect(_close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)
	Gear.changed.connect(_refresh)
	Inventory.changed.connect(_on_items)
	_refresh()


func _on_items(_item: String, _count: int) -> void:
	_refresh()


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var shown_tier := -1
	for r: Dictionary in Gear.RECIPES:
		if Gear.owns(r["slot"], r["tier"]):
			continue
		if r["tier"] != shown_tier:
			shown_tier = r["tier"]
			var t: Dictionary = Gear.TIERS[shown_tier]
			var head := UIStyle.label(_list, "%s tools" % t["name"], 18, true)
			head.add_theme_color_override("font_color", t["color"].lightened(0.2))
		_list.add_child(_card(r))
	if _list.get_child_count() == 0:
		UIStyle.label(_list, "You've made every tool there is. For now.", 20, true)


func _card(r: Dictionary) -> Control:
	var slot: String = r["slot"]
	var tier: int = r["tier"]
	var card := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, 0.06)
	box.set_corner_radius_all(16)
	box.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	row.add_child(badge(slot, tier, 56))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	row.add_child(info)
	UIStyle.label(info, Gear.tool_name(slot, tier), 21)
	var t: Dictionary = Gear.TIERS[tier]
	var now: Dictionary = Gear.TIERS[Gear.tier(slot)]
	UIStyle.label(info, "Power %d (now %d)  ·  Speed %d%% (now %d%%)" % [t["power"], now["power"], roundi(t["speed"] * 100), roundi(now["speed"] * 100)], 15, true)
	var costs := HBoxContainer.new()
	costs.add_theme_constant_override("separation", 14)
	info.add_child(costs)
	for item: String in r["cost"]:
		var need: int = r["cost"][item]
		var have := Inventory.count(item)
		var c := UIStyle.label(costs, "%s %d/%d" % [Items.name_of(item), mini(have, need), need], 16)
		c.add_theme_color_override("font_color", Color(0.75, 1.0, 0.7) if have >= need else Color(1.0, 0.6, 0.55))
	var can := Gear.can_afford(r)
	var button := UIStyle.button(row, "Craft", Vector2(120, 52), 20)
	button.disabled = not can
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(func() -> void:
		if Gear.craft(r):
			get_tree().call_group("hud", "hint", "Made a %s!" % Gear.tool_name(slot, tier)))
	return card


## A round badge in the tier's colour with the tool's first letter (the Bag uses it too).
static func badge(slot: String, tier: int, size: float) -> Control:
	var dot := PanelContainer.new()
	dot.custom_minimum_size = Vector2(size, size)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var box := StyleBoxFlat.new()
	box.bg_color = Gear.TIERS[tier]["color"]
	box.set_corner_radius_all(int(size))
	box.border_color = Color(1, 1, 1, 0.5)
	box.set_border_width_all(2)
	dot.add_theme_stylebox_override("panel", box)
	var l := UIStyle.label(dot, Gear.SLOTS[slot].left(1), int(size * 0.45))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color(0.12, 0.1, 0.12))
	return dot


func _close() -> void:
	Gear.changed.disconnect(_refresh)
	Inventory.changed.disconnect(_on_items)
	closed.emit()
	queue_free()
