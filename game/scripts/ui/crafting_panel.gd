extends Control
## The workbench: one card per tool (Axe, Pickaxe, Sword) showing the tool you have, the next
## upgrade glowing in its tier colour, what it improves in a few words, the cost as item pictures
## (have / need), and a big Craft button. Crafting goes through Gear.craft().

signal closed

const INVENTORY := preload("res://scripts/ui/inventory_panel.gd")
const DONE_SOUND := preload("res://assets/sounds/rare.wav")
const GAINS := {"axe": "Fells trees faster", "pickaxe": "Mines rock faster", "sword": "Hits harder"}

var _cards: HBoxContainer
var _audio: AudioStreamPlayer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_close())
	add_child(shade)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 16)
	add_child(column)
	var title := UIStyle.label(column, "Workbench", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color(0.25, 0.15, 0.08, 0.9))
	title.add_theme_constant_override("outline_size", 8)
	_cards = HBoxContainer.new()
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.add_theme_constant_override("separation", 18)
	column.add_child(_cards)
	var close := UIStyle.button(column, "Done", Vector2(160, 52), 22)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(_close)
	_audio = AudioStreamPlayer.new()
	_audio.stream = DONE_SOUND
	add_child(_audio)
	Gear.changed.connect(_refresh)
	Inventory.changed.connect(_on_items)
	ItemIcons.icon_ready.connect(_on_icon)
	_refresh()


func _on_items(_item: String, _count: int) -> void:
	_refresh()


func _on_icon(_item: String) -> void:
	_refresh()


func _refresh() -> void:
	for c in _cards.get_children():
		c.queue_free()
	for slot: String in Gear.SLOTS:
		_cards.add_child(_card(slot))


func _card(slot: String) -> Control:
	var now := Gear.tier(slot)
	var best_owned: int = Gear.owned[slot].max()
	var recipe := _next_recipe(slot, best_owned)
	var card := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.1, 0.09, 0.13, 0.88)
	box.set_corner_radius_all(22)
	box.border_color = Color(1, 1, 1, 0.12)
	box.set_border_width_all(2)
	box.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", box)
	card.custom_minimum_size = Vector2(250, 360)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	var head := UIStyle.label(v, Gear.SLOTS[slot].to_upper(), 15, true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pics := HBoxContainer.new()
	pics.alignment = BoxContainer.ALIGNMENT_CENTER
	pics.add_theme_constant_override("separation", 6)
	v.add_child(pics)
	if recipe.is_empty():
		pics.add_child(_glow_icon(slot, now, 118))
		_name(v, Gear.tool_name(slot, now), now)
		UIStyle.label(v, "The finest you can make", 16, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return card
	var next: int = recipe["tier"]
	var from := tool_picture(slot, now, 54)
	from.modulate = Color(1, 1, 1, 0.7)
	pics.add_child(from)
	var arrow := UIStyle.label(pics, "›", 40, true)
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pics.add_child(_glow_icon(slot, next, 104))
	_name(v, Gear.tool_name(slot, next), next)
	var gain: String = Gear.PERKS.get(slot, {}).get(next, GAINS[slot])
	UIStyle.label(v, gain, 16, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var costs := HBoxContainer.new()
	costs.alignment = BoxContainer.ALIGNMENT_CENTER
	costs.add_theme_constant_override("separation", 10)
	costs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(costs)
	for item: String in recipe["cost"]:
		costs.add_child(_cost_chip(item, recipe["cost"][item]))
	var can := Gear.can_afford(recipe)
	var button := UIStyle.button(v, "Craft" if can else "Need more", Vector2(0, 58), 22)
	button.disabled = not can
	if can:
		var style := StyleBoxFlat.new()
		style.bg_color = (Gear.TIERS[next]["color"] as Color).darkened(0.15)
		style.set_corner_radius_all(18)
		style.border_color = Color(1, 1, 1, 0.6)
		style.set_border_width_all(2)
		for s in ["normal", "hover", "focus"]:
			button.add_theme_stylebox_override(s, style)
		button.add_theme_color_override("font_color", Color(0.1, 0.07, 0.05))
	button.pressed.connect(func() -> void:
		if Gear.craft(recipe):
			_audio.play()
			get_tree().call_group("hud", "hint", "Made a %s!" % Gear.tool_name(slot, next)))
	return card


func _next_recipe(slot: String, best_owned: int) -> Dictionary:
	for r: Dictionary in Gear.RECIPES:
		if r["slot"] == slot and r["tier"] == best_owned + 1:
			return r
	return {}


func _name(parent: Control, text: String, tier: int) -> void:
	var l := UIStyle.label(parent, text, 22)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", (Gear.TIERS[tier]["color"] as Color).lightened(0.35))


## A tool picture on a soft disc in its tier colour.
func _glow_icon(slot: String, tier: int, size: float) -> Control:
	var disc := PanelContainer.new()
	var style := StyleBoxFlat.new()
	var c: Color = Gear.TIERS[tier]["color"]
	style.bg_color = Color(c.r, c.g, c.b, 0.28)
	style.border_color = Color(c.r, c.g, c.b, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(int(size))
	disc.add_theme_stylebox_override("panel", style)
	disc.custom_minimum_size = Vector2(size, size)
	disc.add_child(tool_picture(slot, tier, size * 0.9))
	return disc


## An item picture with "have/need" under it, green when you have enough.
func _cost_chip(item: String, need: int) -> Control:
	var have := Inventory.count(item)
	var chip := VBoxContainer.new()
	chip.add_theme_constant_override("separation", 0)
	chip.add_child(INVENTORY.item_icon(item, 44))
	var l := UIStyle.label(chip, "%d/%d" % [mini(have, need), need], 17)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color(0.72, 1.0, 0.66) if have >= need else Color(1.0, 0.58, 0.52))
	return chip


## The tool's rendered picture at a tier (from ItemIcons); a tier-coloured dot until it's ready.
static func tool_picture(slot: String, tier: int, size: float) -> Control:
	var tex := ItemIcons.tool_icon(slot, tier)
	if tex:
		var rect := TextureRect.new()
		rect.texture = tex
		rect.custom_minimum_size = Vector2(size, size)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return rect
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(size, size) * 0.5
	dot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Gear.TIERS[tier]["color"]
	box.set_corner_radius_all(int(size))
	dot.add_theme_stylebox_override("panel", box)
	return dot


func _close() -> void:
	Gear.changed.disconnect(_refresh)
	Inventory.changed.disconnect(_on_items)
	ItemIcons.icon_ready.disconnect(_on_icon)
	closed.emit()
	queue_free()
