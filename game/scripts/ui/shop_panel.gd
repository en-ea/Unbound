extends Control
## One screen for the places you trade materials for something: the campfire (cooking), the trader
## (buy and sell for coins) and village projects (fund a building). Set `mode` ("cook", "trade" or
## "project") and, for a project, `project` before adding it. Each offer is a card: picture, name,
## what it does, the cost as item pictures (have / need) and coins, and a button.

signal closed

const INVENTORY := preload("res://scripts/ui/inventory_panel.gd")
const CRAFTING := preload("res://scripts/ui/crafting_panel.gd")
const DONE_SOUND := preload("res://assets/sounds/rare.wav")
const COIN := Color(1.0, 0.82, 0.35)

var mode := "cook"
var project := ""

var _tab := 0
var _tabs: HBoxContainer
var _grid: GridContainer
var _coins: Label
var _note: Label
var _audio: AudioStreamPlayer


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
	panel.offset_left = -450
	panel.offset_right = 450
	panel.offset_top = -320
	panel.offset_bottom = 320
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	column.add_child(header)
	var title := UIStyle.label(header, {"cook": "Campfire", "trade": "Trader", "project": "Village project"}[mode], 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_coins = UIStyle.label(header, "", 24)
	_coins.add_theme_color_override("font_color", COIN)
	_coins.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIStyle.button(header, "Close", Vector2(120, 46), 20).pressed.connect(_close)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 8)
	column.add_child(_tabs)
	_note = UIStyle.label(column, "", 16, true)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 8
	column.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(_grid)
	_audio = AudioStreamPlayer.new()
	_audio.stream = DONE_SOUND
	_audio.volume_db = -6.0
	add_child(_audio)
	Inventory.changed.connect(_on_items)
	Money.changed.connect(_on_coins)
	ItemIcons.icon_ready.connect(_on_icon)
	_refresh()


func _on_items(_i: String, _c: int) -> void:
	_refresh.call_deferred()


func _on_coins(_c: int) -> void:
	_refresh.call_deferred()


func _on_icon(_i: String) -> void:
	_refresh.call_deferred()


func _refresh() -> void:
	if not is_inside_tree():
		return
	_coins.text = "%d coins" % Money.coins
	for c in _tabs.get_children():
		c.queue_free()
	for c in _grid.get_children():
		c.queue_free()
	match mode:
		"cook":
			_note.text = "Cook food here. Eat it from your Bag: it heals, and some food gives a short boost."
			for r: Dictionary in Food.RECIPES:
				var out: String = r["out"]
				_offer(out, Items.name_of(out), Food.describe(out), r["cost"], 0, "Cook",
					Food.cook.bind(r).unbind(0))
		"trade":
			var names := ["Buy", "Sell"]
			for i in names.size():
				var b := UIStyle.button(_tabs, names[i], Vector2(130, 44), 20)
				b.modulate = Color(1.0, 0.9, 0.66) if i == _tab else Color(1, 1, 1, 0.55)
				b.pressed.connect(func() -> void:
					_tab = i
					_refresh())
			if _tab == 0:
				_note.text = "New stock in %d min." % ceili(Money.restock_in() / 60.0)
				for offer: Dictionary in Money.stock():
					var item: String = offer["item"]
					var label := "%s × %d" % [Items.name_of(item), offer["amount"]] if item != "tool" \
						else Gear.name_of(offer["tool"][0], offer["tool"][1])
					var text := "Sold out" if offer["sold"] else ("A found tool with a bonus" if item == "tool" else "")
					_offer("" if item == "tool" else item, label, text, {}, offer["price"], "Buy",
						Money.buy.bind(offer).unbind(0), offer["sold"], offer.get("tool", []))
			else:
				_note.text = "Tap Sell for one, or Sell all."
				for item: String in Inventory.items():
					_sell_card(item)
		"project":
			var d: Dictionary = Projects.DEFS[project]
			if Projects.is_built(project):
				_note.text = "Built! " + d["text"]
			else:
				_note.text = "Help the village build this. " + d["text"]
				_offer("", d["name"], "", Projects.cost(project), Projects.coins(project), "Build",
					Projects.fund.bind(project).unbind(0))


## A card with a picture, a name, some text, a cost and a button that runs `action`.
func _offer(item: String, title: String, text: String, cost: Dictionary, coins: int, verb: String, action: Callable, done := false, tool: Array = []) -> void:
	var v := _card()
	if item != "":
		v.add_child(INVENTORY.item_icon(item, 64))
	elif not tool.is_empty():
		var pic := CRAFTING.tool_picture(tool[0], tool[1]["tier"], 64)
		pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(pic)
	var t := UIStyle.label(v, title, 20)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if text != "":
		var l := UIStyle.label(v, text, 15, true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var costs := HFlowContainer.new()
	costs.alignment = FlowContainer.ALIGNMENT_CENTER
	costs.add_theme_constant_override("h_separation", 8)
	costs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(costs)
	for c: String in cost:
		costs.add_child(_cost_chip(c, cost[c]))
	if coins > 0:
		var cl := UIStyle.label(costs, "%d coins" % coins, 19)
		cl.add_theme_color_override("font_color", COIN if Money.coins >= coins else Color(1.0, 0.58, 0.52))
	var can := not done and Money.coins >= coins and Gear.can_afford(cost)
	var b := UIStyle.button(v, verb if can or done else "Need more", Vector2(0, 50), 20)
	if done:
		b.text = "Sold out"
	b.disabled = not can
	b.pressed.connect(func() -> void:
		if action.call():
			_audio.play()
		_refresh())


func _sell_card(item: String) -> void:
	var v := _card()
	v.add_child(INVENTORY.item_icon(item, 56))
	var t := UIStyle.label(v, "%s × %d" % [Items.name_of(item), Inventory.count(item)], 18)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var p := UIStyle.label(v, "%d coins each" % Items.value_of(item), 16)
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_theme_color_override("font_color", COIN)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	UIStyle.button(row, "Sell", Vector2(80, 46), 18).pressed.connect(func() -> void:
		Money.sell(item, 1))
	UIStyle.button(row, "Sell all", Vector2(100, 46), 18).pressed.connect(func() -> void:
		Money.sell(item, Inventory.count(item))
		_audio.play())


func _card() -> VBoxContainer:
	var card := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, 0.06)
	box.set_corner_radius_all(18)
	box.border_color = Color(1, 1, 1, 0.12)
	box.set_border_width_all(2)
	box.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", box)
	card.custom_minimum_size = Vector2(270, 250)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	_grid.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	return v


## An item picture with "have/need" under it, green when you have enough.
func _cost_chip(item: String, need: int) -> Control:
	var have := Inventory.count(item)
	var chip := VBoxContainer.new()
	chip.add_theme_constant_override("separation", 0)
	chip.add_child(INVENTORY.item_icon(item, 40))
	var l := UIStyle.label(chip, "%d/%d" % [mini(have, need), need], 15)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color(0.72, 1.0, 0.66) if have >= need else Color(1.0, 0.58, 0.52))
	return chip


func _close() -> void:
	Inventory.changed.disconnect(_on_items)
	Money.changed.disconnect(_on_coins)
	ItemIcons.icon_ready.disconnect(_on_icon)
	closed.emit()
	queue_free()
