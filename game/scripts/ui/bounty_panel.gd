extends Control
## The bounty board's screen (world/bounty_board.gd): this region's jobs on the left (take one), yours on
## the right (how far along, claim the reward). New jobs go up every in-game day.

signal closed

const KIND_COLORS := {"hunt": Color(1.0, 0.78, 0.45), "gather": Color(0.6, 0.86, 0.55), "wanted": Color(1.0, 0.45, 0.35)}
const KIND_NAMES := {"hunt": "HUNT", "gather": "GATHER", "wanted": "WANTED"}

var _offers: VBoxContainer
var _mine: VBoxContainer
var _header: Label
var _footer: Label


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
	var title := UIStyle.label(top, "Bounty Board", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5))
	_header = UIStyle.label(top, "", 16, true)
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIStyle.button(top, "Close", Vector2(120, 46), 20).pressed.connect(_close)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	_offers = _side(body, "On the board")
	_mine = _side(body, "Yours")
	_footer = UIStyle.label(column, "", 14, true)
	Bounties.changed.connect(_refresh)
	Inventory.changed.connect(func(_i: String, _c: int) -> void: _refresh())
	_refresh()


func _side(parent: Node, heading: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	parent.add_child(box)
	UIStyle.label(box, heading, 16, true)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 8
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	return list


func _refresh() -> void:
	if not is_inside_tree():
		return
	for c in _offers.get_children() + _mine.get_children():
		c.queue_free()
	_header.text = "   %s  ·  Renown %d" % [Region.NAMES[Region.current], Bounties.renown]
	var full := Bounties.taken.size() >= Bounties.MAX_TAKEN
	var on_board := Bounties.board(Region.current)
	if on_board.is_empty():
		UIStyle.label(_offers, "All taken. New ones go up tomorrow.", 16, true)
	for b: Dictionary in on_board:
		var card := _card(_offers, b)
		var take := UIStyle.button(card, "Take it" if not full else "You have three already", Vector2(0, 46), 18)
		take.disabled = full
		take.pressed.connect(func() -> void: Bounties.take(b))
	if Bounties.taken.is_empty():
		var hint := UIStyle.label(_mine, "None yet. Take up to three; they show with your quests.", 16, true)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for b: Dictionary in Bounties.taken:
		var card := _card(_mine, b)
		var step := UIStyle.label(card, Bounties.step_text(b), 16)
		step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if Bounties.is_ready(b):
			var claim := UIStyle.button(card, "Claim reward", Vector2(0, 46), 18)
			claim.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5))
			claim.pressed.connect(func() -> void: _claim(b))
	_footer.text = "New bounties in %d min. Gathers can be handed in at any board; hunts count in their own region." % ceili(Bounties.next_day_in() / 60.0)


## One bounty: kind tag, stars, name, what it's about, the reward.
func _card(parent: Node, b: Dictionary) -> VBoxContainer:
	var frame := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.1, 0.11, 0.15, 0.85)
	box.border_color = Color(KIND_COLORS[b["kind"]], 0.5)
	box.border_width_left = 4
	box.set_corner_radius_all(10)
	box.content_margin_left = 12
	box.content_margin_right = 10
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	frame.add_theme_stylebox_override("panel", box)
	parent.add_child(frame)
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 4)
	frame.add_child(card)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	card.add_child(top)
	var tag := UIStyle.label(top, KIND_NAMES[b["kind"]], 12)
	tag.add_theme_color_override("font_color", KIND_COLORS[b["kind"]])
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var name_label := UIStyle.label(top, b["title"], 20)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stars(top, b["stars"])
	var about := UIStyle.label(card, b["about"], 14, true)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var reward := HBoxContainer.new()
	reward.add_theme_constant_override("separation", 10)
	card.add_child(reward)
	UIStyle.price(reward, b["coins"], 18)
	if b["kind"] == "wanted":
		var gear := UIStyle.label(reward, "+ a gear find (often rare)", 15)
		gear.add_theme_color_override("font_color", Color(0.72, 0.6, 1.0))
	return card


## Little gold stars, drawn (the font has no star).
func _stars(parent: Node, count: int) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(20 * count, 20)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.draw.connect(func() -> void:
		for k in count:
			var mid := Vector2(10 + k * 20, 10)
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI * 0.5 + i * PI / 5.0
				pts.append(mid + Vector2(cos(a), sin(a)) * (8.5 if i % 2 == 0 else 3.8))
			c.draw_colored_polygon(pts, Color(1.0, 0.8, 0.3)))
	parent.add_child(c)


func _claim(b: Dictionary) -> void:
	var gear := Bounties.claim(b)
	get_tree().call_group("hud", "hint", "Bounty claimed: +%d coins" % b["coins"])
	if not gear.is_empty():
		get_tree().call_group("hud", "found_tool", gear[0], gear[1])


func _close() -> void:
	closed.emit()
	queue_free()
