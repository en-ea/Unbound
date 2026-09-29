extends PanelContainer
## The card that pops in at the top when you pick up found gear: its picture, name in its rarity
## colour, rarity and main number (with ▲/▼ against what you have on), its bonuses, and whether you
## put it on. Rarer finds glow brighter. One card at a time; it fades after a few seconds.

const SHOW_FOR := 3.8


func show_piece(slot: String, piece: Dictionary) -> void:
	var rc := Loot.rarity_color(piece["rarity"])
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.08, 0.12, 0.9)
	box.set_corner_radius_all(18)
	box.border_color = rc
	box.set_border_width_all(3)
	box.shadow_color = Color(rc, 0.15 + 0.07 * piece["rarity"])
	box.shadow_size = 6 + 3 * piece["rarity"]
	box.set_content_margin_all(12)
	add_theme_stylebox_override("panel", box)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	add_child(h)
	h.add_child(GearView._picture(GearView.icon(slot, piece), 64))
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 1)
	h.add_child(info)
	var worn := GearView.current(slot) == piece
	UIStyle.label(info, "Equipped!" if worn else "Found", 13, true)
	var name_label := UIStyle.label(info, Gear.name_of(slot, piece), 20)
	name_label.add_theme_color_override("font_color", rc.lightened(0.25))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	info.add_child(line)
	UIStyle.label(line, Loot.rarity_name(piece["rarity"]), 14, true)
	var stat := GearView.main_stat(slot, piece)
	UIStyle.label(line, "%d %s" % [stat, GearView.stat_word(slot)], 15)
	if not worn:
		var now := GearView.current(slot)
		var diff := stat - (GearView.main_stat(slot, now) if not now.is_empty() else 0)
		if diff != 0:
			var arrow := UIStyle.label(line, ("▲%d" if diff > 0 else "▼%d") % absi(diff), 15)
			arrow.add_theme_color_override("font_color", GearView.UP if diff > 0 else GearView.DOWN)
	for text in Gear.bonus_lines(piece):
		var b := UIStyle.label(info, text, 13)
		b.add_theme_color_override("font_color", Color(1.0, 0.88, 0.6))
	# Top centre, sliding down a little as it appears.
	reset_size()
	position = Vector2((get_viewport_rect().size.x - size.x) / 2.0, 70.0)
	modulate.a = 0.0
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.2)
	t.parallel().tween_property(self, "position:y", 86.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(SHOW_FOR)
	t.tween_property(self, "modulate:a", 0.0, 0.5)
	t.tween_callback(queue_free)
