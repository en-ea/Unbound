class_name GearView
extends RefCounted
## Gear in the Bag, for weapons, tools and armour alike: a card per piece, one-line summaries, and
## the detail panel (main stat compared with what you have on, bonuses, Equip / Take off / Drop).
## Reads Gear and Armor; changes go through their actions.

const SLOT_ORDER := ["sword", "axe", "pickaxe", "helm", "chest", "boots"]
const UP := Color(0.5, 0.92, 0.45)
const DOWN := Color(1.0, 0.45, 0.4)


static func is_armor(slot: String) -> bool:
	return Armor.SLOTS.has(slot)


static func owned(slot: String) -> Array:
	return Armor.owned[slot] if is_armor(slot) else Gear.owned[slot]


static func equipped_index(slot: String) -> int:
	return Armor.equipped[slot] if is_armor(slot) else Gear.equipped[slot]


static func current(slot: String) -> Dictionary:
	return Armor.current(slot) if is_armor(slot) else Gear.current(slot)


## The piece's main number: damage for the weapon, gathering power for tools, defence for armour.
static func main_stat(slot: String, p: Dictionary) -> int:
	if is_armor(slot):
		return Armor.piece_defence(slot, p)
	if p.is_empty():
		return 1
	var b: Dictionary = p.get("bonuses", {})
	if slot == "sword":
		return roundi(Gear.TIERS[p["tier"]]["damage"] * Loot.stat(p["rarity"]) * (1.0 + b.get("sharp", 0) / 100.0))
	return roundi(Gear.TIERS[p["tier"]]["power"] * Loot.stat(p["rarity"])) + int(b.get("mighty", 0))


static func stat_word(slot: String) -> String:
	return "defence" if is_armor(slot) else ("damage" if slot == "sword" else "power")


static func icon(slot: String, p: Dictionary) -> Texture2D:
	return ItemIcons.tool_icon(slot, p.get("tier", 0))


## A square card: picture, short name, its edge in the rarity colour, "On" if you wear it.
static func card(slot: String, index: int, selected: bool, on_pick: Callable) -> Button:
	var p: Dictionary = owned(slot)[index]
	var rc := Loot.rarity_color(p["rarity"])
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(122, 122)
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	for state in ["normal", "hover", "pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(rc, 0.16 if selected else 0.07)
		box.set_corner_radius_all(16)
		box.border_color = Color(1.0, 0.9, 0.66) if selected else Color(rc, 0.9 if p["rarity"] > 0 else 0.3)
		box.set_border_width_all(3 if selected else 2)
		b.add_theme_stylebox_override(state, box)
	b.pressed.connect(on_pick)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	v.add_child(_picture(icon(slot, p), 58))
	var tiers: Array = Armor.TIERS if is_armor(slot) else Gear.TIERS
	var n := UIStyle.label(v, "%s %s" % [tiers[p["tier"]]["name"], (Armor.SLOTS if is_armor(slot) else Gear.SLOTS)[slot]], 13)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.clip_text = true
	n.custom_minimum_size.x = 110
	var s := UIStyle.label(v, "%d %s" % [main_stat(slot, p), stat_word(slot)], 12, true)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if index == equipped_index(slot):
		var on := UIStyle.label(b, "On", 13)
		on.position = Vector2(10, 6)
		on.add_theme_color_override("font_color", Color(1.0, 0.9, 0.66))
	return b


## The detail panel for one piece.
static func fill_detail(parent: Control, slot: String, index: int) -> void:
	var p: Dictionary = owned(slot)[index]
	var worn := index == equipped_index(slot)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	parent.add_child(h)
	h.add_child(_picture(icon(slot, p), 72))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	h.add_child(info)
	var name_label := UIStyle.label(info, Gear.name_of(slot, p), 20)
	name_label.add_theme_color_override("font_color", Loot.rarity_color(p["rarity"]).lightened(0.25))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	info.add_child(line)
	UIStyle.label(line, "%s%s" % [Loot.rarity_name(p["rarity"]), "  ·  on" if worn else ""], 14, true)
	var stat := main_stat(slot, p)
	UIStyle.label(line, "%d %s" % [stat, stat_word(slot)], 15)
	if not worn:                     # compared with what you have on now
		var now := current(slot)
		var diff := stat - (main_stat(slot, now) if not now.is_empty() else (0 if is_armor(slot) else 1))
		if diff != 0:
			var arrow := UIStyle.label(line, ("▲%d" if diff > 0 else "▼%d") % absi(diff), 15)
			arrow.add_theme_color_override("font_color", UP if diff > 0 else DOWN)
	var lines := Gear.bonus_lines(p)
	if not lines.is_empty():
		var bl := UIStyle.label(info, "  ·  ".join(lines), 14)
		bl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.6))
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(buttons)
	if not worn:
		UIStyle.button(buttons, "Equip", Vector2(120, 44), 18).pressed.connect(func() -> void:
			if is_armor(slot):
				Armor.equip(slot, index)
			else:
				Gear.equip(slot, index))
	elif is_armor(slot):
		UIStyle.button(buttons, "Take off", Vector2(120, 44), 17).pressed.connect(Armor.unequip.bind(slot))
	var drop := UIStyle.button(buttons, "Drop", Vector2(120, 40), 16)
	drop.pressed.connect(func() -> void:
		if drop.text != "Sure?":
			drop.text = "Sure?"
		elif is_armor(slot):
			Armor.drop(slot, index)
		else:
			Gear.drop_tool(slot, index))


## A compact row for the "On you" list: picture, name in its rarity colour, main stat.
static func worn_row(slot: String, on_pick: Callable) -> Button:
	var p := current(slot)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 50)
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	for state in ["normal", "hover", "pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(1, 1, 1, 0.06)
		box.set_corner_radius_all(12)
		box.border_color = Loot.rarity_color(p.get("rarity", 0)) if p.get("rarity", 0) > 0 else Color(1, 1, 1, 0.18)
		box.set_border_width_all(2)
		b.add_theme_stylebox_override(state, box)
	b.pressed.connect(on_pick)
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 6
	h.offset_right = -8
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	if p.is_empty():
		var none := UIStyle.label(h, "—", 16, true)
		none.custom_minimum_size = Vector2(42, 42)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	else:
		h.add_child(_picture(icon(slot, p), 42))
	var name_label := UIStyle.label(h, Gear.name_of(slot, p) if not p.is_empty() or not is_armor(slot) else "No %s" % Armor.SLOTS[slot].to_lower(), 14)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	if not p.is_empty():
		name_label.add_theme_color_override("font_color", Loot.rarity_color(p["rarity"]).lightened(0.3) if p["rarity"] > 0 else Color.WHITE)
	var s := UIStyle.label(h, str(main_stat(slot, p)) if not p.is_empty() else "", 15, true)
	s.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return b


static func _picture(tex: Texture2D, size: float) -> Control:
	var rect := TextureRect.new()
	rect.texture = tex
	rect.custom_minimum_size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect
