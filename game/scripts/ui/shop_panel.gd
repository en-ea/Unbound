extends Control
## One screen for the places you trade materials for something: the campfire (cooking), the trader
## (buy and sell for coins) and village projects (fund a building). Set `mode` ("cook", "trade" or
## "project") and, for a project, `project` before adding it. Each offer is a card: picture, name,
## what it does, the cost as item pictures (have / need) and coins, and a button.

signal closed
signal build_home

const INVENTORY := preload("res://scripts/ui/inventory_panel.gd")
const CRAFTING := preload("res://scripts/ui/crafting_panel.gd")
const DONE_SOUND := preload("res://assets/sounds/rare.wav")
const COIN := Color(1.0, 0.82, 0.35)

var mode := "cook"
var project := ""
var letting := -1                 # mode "letting": the village house (Lettings.HOUSES)

var _tab := 0
var _tabs: HBoxContainer
var _grid: GridContainer
var _coins: Label
var _note: Label
var _audio: AudioStreamPlayer


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
	var title := UIStyle.label(header, {"cook": "Campfire", "trade": "Trader", "project": "Village project", "home": "Your home",
		"letting": Lettings.HOUSES.get(letting, {}).get("name", "")}[mode], 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIStyle.coin(header, 22)
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
	_coins.text = str(Money.coins)
	for c in _tabs.get_children():
		c.queue_free()
	for c in _grid.get_children():
		c.queue_free()
	match mode:
		"cook":
			_note.text = "Cook food here. Eat it from your Bag: it heals, and some food gives a short boost."
			for r: Dictionary in Food.RECIPES:
				var out: String = r["out"]
				var title := Items.name_of(out) + (" × %d" % r["n"] if r.has("n") else "")
				_offer(out, title, Food.describe(out), r["cost"], 0, "Roll" if out == "cigarette" else "Cook",
					Food.cook.bind(r))
		"trade":
			var names := ["Buy", "Sell"]
			_grid.columns = 3 if _tab == 0 else 1
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
						Money.buy.bind(offer), offer["sold"], offer.get("tool", []))
			else:
				var worth := 0
				var loot := 0
				for item: String in Inventory.items():
					worth += Items.value_of(item) * Inventory.count(item)
					if Items.kind_of(item) == "loot":
						loot += Items.value_of(item) * Inventory.count(item)
				_note.text = "Everything you carry is worth %d coins." % worth
				var all_loot := UIStyle.button(_tabs, "Sell all loot (%d)" % loot, Vector2(220, 44), 18)
				all_loot.disabled = loot == 0
				all_loot.pressed.connect(func() -> void:
					for item: String in Inventory.items():
						if Items.kind_of(item) == "loot":
							Money.sell(item, Inventory.count(item))
					_audio.play())
				for item: String in Inventory.items():
					_sell_row(item)
		"home":
			if Home.owned():
				_note.text = "Your %s. Build in the yard, change the inside, or move into another house (all free; the yard stays)." % Home.house_name()
				_rent_offers()
				if Home.can_upgrade():
					var up: Dictionary = Balance.HOME_UPGRADE
					_offer("house:" + Home.UPGRADES[Home.house], "Do it up: " + Home.HOUSES[Home.UPGRADES[Home.house]][0],
						_grand_perks(), up["cost"], up["coins"], "Do it up", Home.upgrade)
				elif Home.is_grand():
					_offer("", "Grand home perks", _grand_perks(), {}, 0, "Yours", func() -> bool: return false, false, [], true)
				_offer("", "Build in the yard", "Fences, lanterns, benches, flower beds, a campfire, a workbench and more.", {}, 0, "Start building", func() -> bool:
					_close()
					build_home.emit()
					return false)
				_inside_offers()
				for h: String in Home.HOUSES:
					if h != Home.house and Home.choosable(h):
						_offer("house:" + h, Home.HOUSES[h][0], "Done up, waiting for you" if h in Home.upgraded else "", {}, 0, "Move in", Home.change_house.bind(h))
			else:
				var miss := Home.missing()
				_note.text = "A plot of your own, with a house you choose, and the inside you like (change it any time). " + ("Ready to buy!" if miss.is_empty() else "Still needed: " + "; ".join(miss) + ".")
				for h: String in Home.HOUSES:
					if Home.choosable(h):
						_offer("house:" + h, Home.HOUSES[h][0], "Can be done up later into the " + Home.HOUSES[Home.UPGRADES[h]][0] if Home.UPGRADES.has(h) else "",
							{}, Balance.HOME["coins"], "Buy" if miss.is_empty() else "Not yet", Home.buy.bind(h), false, [], not miss.is_empty())
				_inside_offers()
		"letting":
			_letting_offers()
		"project":
			var d: Dictionary = Projects.DEFS[project]
			if Projects.is_built(project):
				_note.text = "Built! " + d["text"]
			else:
				_note.text = "Help the village build this. " + d["text"]
				_offer("", d["name"], "", Projects.cost(project), Projects.coins(project), "Build",
					Projects.fund.bind(project))


## What the grand home gives you, in a few lines.
func _grand_perks() -> String:
	var up: Dictionary = Balance.HOME_UPGRADE
	var r: Dictionary = Balance.REST
	return "A much bigger room. The stash holds %d kinds (not %d). Sleep leaves you Well Rested for %d min (not %d). A lodger pays %d coins a day." % [
		Balance.HOME_STASH["grand"], Balance.HOME_STASH["kinds"], roundi(r["grand_secs"] / 60.0), roundi(r["secs"] / 60.0), up["rent"]]


## Rent waiting in the mailbox (the lodger, and any village houses you let).
func _rent_offers() -> void:
	var total := Home.mail_coins + Lettings.waiting
	if total > 0:
		_offer("", "Rent to collect", "%d coins waiting." % total, {}, 0, "Collect", func() -> bool:
			Home.collect_rent()
			Lettings.collect()
			return true)


## A village house to let: buy it, look inside, collect its rent, do it up.
func _letting_offers() -> void:
	var i := letting
	var lv := Lettings.level(i)
	if lv == 0:
		_note.text = "For sale. Buy it and a tenant moves in, paying %d coins every day (do it up for more). Rent waits for you here or at your mailbox." % Lettings.rent(i, 1)
		_offer("", "Buy the " + Lettings.HOUSES[i]["name"], "Rent: %d a day" % Lettings.rent(i, 1), {}, Lettings.price(i), "Buy",
			Lettings.buy.bind(i))
		return
	var tenant: Dictionary = Npcs.get_def(Lettings.TENANTS[i])
	var ask: Array = Lettings.asks.get(i, [])
	_note.text = "Yours, let out (%s) to %s, who is %s. Rent: %d coins a day (a happier tenant pays more); all your lettings: %d a day.%s" % [
		Lettings.LEVELS[lv].to_lower(), tenant["name"], Lettings.mood_word(i), Lettings.rent(i), Lettings.daily(),
		(" %s would like %d %s: bring it and talk to them inside." % [tenant["name"], ask[1], Items.name_of(ask[0])]) if not ask.is_empty() else ""]
	_rent_offers()
	if Lettings.waiting + Home.mail_coins == 0:
		_offer("", "Rent", "Nothing waiting yet. Tenants pay each new day (or when you sleep through the night).", {}, 0, "Collect",
			func() -> bool: return false, false, [], true)
	var c := Lettings.do_up_cost(i)
	if c.is_empty():
		_offer("", "Fully done up", "As fine as it gets. Rent: %d a day." % Lettings.rent(i), {}, 0, "Done", func() -> bool: return false, true)
	else:
		_offer("", "Do it up: " + Lettings.LEVELS[lv + 1], "Better furniture. Rent goes up to %d a day." % Lettings.rent(i, lv + 1),
			c["cost"], c["coins"], "Do it up", Lettings.do_up.bind(i))


## The inside: its layout (where the fire and windows are) and its feel (walls, floor, cloth). Free to change.
func _inside_offers() -> void:
	if Home.is_grand():
		_offer("", "Inside: " + Home.LAYOUTS["grand"]["name"], Home.LAYOUTS["grand"]["blurb"], {}, 0, "Chosen", func() -> bool: return true, false, [], true)
	for id: String in Home.LAYOUTS:
		if id == "grand" or Home.is_grand():
			continue
		var lay: Dictionary = Home.LAYOUTS[id]
		var chosen := Home.layout == id
		_offer("", "Inside: " + lay["name"], lay["blurb"] + (" Furniture in the way moves aside." if Home.owned() else ""), {}, 0,
			"Chosen" if chosen else "Choose", func() -> bool:
				Home.set_layout(id)
				return true, false, [], chosen)
	for id: String in Home.FEELS:
		var chosen := Home.room_feel() == id
		var blurb: String = Home.FEEL_BLURBS[id]
		_offer("", "Feel: " + Home.FEELS[id], blurb, {}, 0, "Chosen" if chosen else "Choose", func() -> bool:
			Home.set_feel(id)
			return true, false, [], chosen)


## A card with a picture, a name, some text, a cost and a button that runs `action`.
func _offer(item: String, title: String, text: String, cost: Dictionary, coins: int, verb: String, action: Callable, done := false, tool: Array = [], locked := false) -> void:
	var edge := Color(1, 1, 1, 0.12)
	if item != "" and Items.DEFS.has(item) and Items.rarity_of(item) > 0:
		edge = Items.RARITY_COLORS[Items.rarity_of(item)]
	elif not tool.is_empty() and tool[1]["rarity"] > 0:
		edge = Loot.rarity_color(tool[1]["rarity"])
	var v := _card(edge)
	if item.begins_with("house:"):             # a home: its picture
		var pic := TextureRect.new()
		pic.custom_minimum_size = Vector2(0, 120)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.texture = ItemIcons.icon(item)
		if pic.texture == null:
			ItemIcons.icon_ready.connect(func(i: String) -> void:
				if i == item and is_instance_valid(pic):
					pic.texture = ItemIcons.icon(item))
		v.add_child(pic)
	elif item != "":
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
	if mode == "trade" and item != "" and Items.DEFS.has(item):
		var have := UIStyle.label(v, "You have %d" % Inventory.count(item), 14, true)
		have.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var costs := HFlowContainer.new()
	costs.alignment = FlowContainer.ALIGNMENT_CENTER
	costs.add_theme_constant_override("h_separation", 8)
	costs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(costs)
	for c: String in cost:
		costs.add_child(_cost_chip(c, cost[c]))
	if coins > 0:
		UIStyle.price(costs, coins, 20, Money.coins >= coins)
	var can := not done and not locked and Money.coins >= coins and Gear.can_afford(cost)
	var b := UIStyle.button(v, verb if can or done or locked else "Need more", Vector2(0, 50), 20)
	if coins > 0 and can and mode == "trade":
		b.text = "%s  ·  %d" % [verb, coins]
	if done:
		b.text = "Sold out"
	b.disabled = not can
	b.pressed.connect(func() -> void:
		if action.call():
			_audio.play()
		_refresh())


## One line per item: picture, name and count, price each, Sell 1 and Sell all (with the total).
func _sell_row(item: String) -> void:
	var row_box := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, 0.05)
	box.set_corner_radius_all(14)
	box.set_content_margin_all(6)
	box.border_color = Items.RARITY_COLORS[Items.rarity_of(item)]
	box.set_border_width_all(2 if Items.rarity_of(item) > 0 else 0)
	row_box.add_theme_stylebox_override("panel", box)
	row_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_box.custom_minimum_size.x = 820
	row_box.mouse_filter = Control.MOUSE_FILTER_PASS
	_grid.add_child(row_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row_box.add_child(row)
	row.add_child(INVENTORY.item_icon(item, 44))
	var n := UIStyle.label(row, "%s  ×%d" % [Items.name_of(item), Inventory.count(item)], 19)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIStyle.price(row, Items.value_of(item), 18)
	UIStyle.label(row, "each", 14, true).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIStyle.button(row, "Sell 1", Vector2(96, 44), 17).pressed.connect(func() -> void:
		Money.sell(item, 1))
	UIStyle.button(row, "Sell all (%d)" % (Items.value_of(item) * Inventory.count(item)), Vector2(150, 44), 17).pressed.connect(func() -> void:
		Money.sell(item, Inventory.count(item))
		_audio.play())


func _card(edge := Color(1, 1, 1, 0.12)) -> VBoxContainer:
	var card := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, 0.06)
	box.set_corner_radius_all(18)
	box.border_color = edge
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
