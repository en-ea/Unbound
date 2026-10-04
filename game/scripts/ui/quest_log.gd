extends Control
## The quest log (tap the tracker): the quests you're on and the ones you've finished. Pick one to read what
## it's about, who gave it, the steps so far, and follow it (the tracker and guide beam switch to it).

signal closed

const TAG_COLORS := {"story": Color(1.0, 0.78, 0.35), "job": Color(0.55, 0.8, 1.0), "bounty": Color(1.0, 0.5, 0.38)}

var _list: VBoxContainer
var _detail: VBoxContainer
var _selected := ""


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
	panel.offset_left = -520
	panel.offset_right = 520
	panel.offset_top = -300
	panel.offset_bottom = 300
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := UIStyle.label(header, "Quests", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIStyle.button(header, "Close", Vector2(120, 46), 20).pressed.connect(_close)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var left := ScrollContainer.new()
	left.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.scroll_deadzone = 8
	left.custom_minimum_size.x = 330
	body.add_child(left)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_list)
	var right := ScrollContainer.new()
	right.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 10)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(_detail)
	_selected = Quests.tracked_quest()
	if _selected == "" and not Quests.finished().is_empty():
		_selected = Quests.finished()[-1]
	_refresh()


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var on := Quests.active()
	var done := Quests.finished()
	if on.is_empty() and done.is_empty():
		UIStyle.label(_list, "No quests yet. Talk to people in the village.", 16, true).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not on.is_empty():
		UIStyle.label(_list, "On it", 16, true)
		for id in on:
			_row(id)
	if not done.is_empty():
		UIStyle.label(_list, "Done", 16, true)
		for id in done:
			_row(id)
	_show_detail()


func _row(id: String) -> void:
	var following := id == Quests.tracked_quest()
	var b := UIStyle.button(_list, ("> " if following else "") + Quests.name_of(id), Vector2(0, 48), 18)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.button_pressed = id == _selected
	b.toggle_mode = true
	if Quests.status(id) == "done":
		b.modulate = Color(1, 1, 1, 0.6)
	b.add_theme_color_override("font_color", TAG_COLORS[Quests.type_of(id)])
	b.pressed.connect(func() -> void:
		_selected = id
		_refresh())


func _show_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()
	if _selected == "":
		return
	var id := _selected
	var type := Quests.type_of(id)
	if type == "bounty" and Quests.status(id) == "done":     # claimed or given up since
		return
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	_detail.add_child(top)
	var tag := UIStyle.label(top, Quests.TYPE_NAMES[type].to_upper(), 13)
	tag.add_theme_color_override("font_color", Color(0.08, 0.08, 0.1))
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg := StyleBoxFlat.new()
	bg.bg_color = TAG_COLORS[type]
	bg.set_corner_radius_all(6)
	bg.content_margin_left = 7
	bg.content_margin_right = 7
	tag.add_theme_stylebox_override("normal", bg)
	var name_label := UIStyle.label(top, Quests.name_of(id), 26)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5))
	if type == "bounty":
		_bounty_detail(id)
		return
	var def: Dictionary = Quests.DEFS[id]
	var kind := "The main story." if type == "story" else "A job from %s." % Npcs.get_def(def["giver"])["name"]
	UIStyle.label(_detail, kind, 15, true)
	var about := UIStyle.label(_detail, Quests.about(id), 17)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var steps: Array = def["steps"]
	var at := Quests.step_index(id)
	for i in mini(at + 1, steps.size()):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_detail.add_child(row)
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(12, 12)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.color = Color(0.45, 0.85, 0.45) if i < at else Color(1.0, 0.86, 0.5)
		row.add_child(dot)
		var text: String = steps[i]["text"] if i < at else Quests.step_text(id)
		var l := UIStyle.label(row, text, 16, i < at)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if Quests.is_active(id):
		var following := id == Quests.tracked_quest()
		var track := UIStyle.button(_detail, "Following" if following else "Follow this quest", Vector2(240, 50), 19)
		track.disabled = following
		track.pressed.connect(func() -> void:
			Quests.track(id)
			_refresh())
	else:
		UIStyle.label(_detail, "Finished.", 16, true)


## A bounty: what it's about, how far along, follow it or give it up.
func _bounty_detail(id: String) -> void:
	var b := Bounties.find(int(id.trim_prefix("bounty:")))
	UIStyle.label(_detail, "From the bounty board in the %s (%d-star)." % [Region.NAMES[b["region"]], b["stars"]], 15, true)
	var about := UIStyle.label(_detail, b["about"], 17)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var step := UIStyle.label(_detail, Bounties.step_text(b), 17)
	step.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5))
	step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIStyle.price(_detail, b["coins"], 18)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_detail.add_child(row)
	var following := id == Quests.tracked_quest()
	var track := UIStyle.button(row, "Following" if following else "Follow this", Vector2(200, 50), 19)
	track.disabled = following
	track.pressed.connect(func() -> void:
		Quests.track(id)
		_refresh())
	UIStyle.button(row, "Give up", Vector2(140, 50), 19).pressed.connect(func() -> void:
		Bounties.give_up(b)
		_selected = Quests.tracked_quest()
		_refresh())


func _close() -> void:
	closed.emit()
	queue_free()
