extends Control
## Settings: frame rate, the stats overlay and sound. Changes save straight away.
## "Codes": type the code (Paladin) to open a test menu that hands you coins, items, tools and more.

signal closed

const CODE := "paladin"

var _rows: VBoxContainer
var _page := "settings"      # settings / code / cheats
var _msg: Label
var _typed := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.panel())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(560, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	UIStyle.label(column, "Settings", 28)
	var scroll := ScrollContainer.new()                    # more rows than fit a phone screen
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 8
	scroll.custom_minimum_size.y = 460
	column.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 10)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(footer)
	UIStyle.button(footer, "Done", Vector2(140, 50)).pressed.connect(_close)
	_refresh()


func _refresh() -> void:
	for c in _rows.get_children():
		c.queue_free()
	if _page != "settings":
		_page_first()
		return
	_row("Frame rate", "%d FPS" % Settings.fps_cap, Settings.next_fps_cap)
	_row("Minimap", "On" if Settings.show_map else "Off", func() -> void: Settings.set_show_map(not Settings.show_map))
	_row("Performance stats", "On" if Settings.show_stats else "Off", func() -> void: Settings.set_show_stats(not Settings.show_stats))
	_row("Camera", Settings.ZOOMS.get(Settings.zoom, "Normal"), Settings.next_zoom)
	_row("Buttons", "Compact (flicks)" if Settings.compact_controls else "All shown",
		func() -> void: Settings.set_compact_controls(not Settings.compact_controls))
	_row("Sword", "Always in hand" if Settings.sword_in_hand else "On back till a fight",
		func() -> void: Settings.set_sword_in_hand(not Settings.sword_in_hand))
	if _page == "code":
		_code_page()
		return
	if _page == "cheats":
		_cheat_page()
		return
	_row("Sound", "On" if Settings.sound_on else "Off", func() -> void: Settings.set_sound_on(not Settings.sound_on))
	_row("Music", "On" if Settings.music_on else "Off", func() -> void: Settings.set_music_on(not Settings.music_on))
	_row("Update log", "Open", func() -> void: UpdateLog.open(self))
	_row("Codes", "Enter", func() -> void: _page = "code")


func _page_first() -> void:
	match _page:
		"code":
			_code_page()
		"cheats":
			_cheat_page()


## The iPhone keyboard doesn't open for web text boxes, so the code is typed on letter buttons.
func _code_page() -> void:
	UIStyle.label(_rows, "Enter a code", 22)
	var shown := UIStyle.label(_rows, _typed if _typed != "" else "_", 30)
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg = UIStyle.label(_rows, "", 18, true)
	for line: String in ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM<"]:    # a phone-style keyboard
		var keys := HBoxContainer.new()
		keys.alignment = BoxContainer.ALIGNMENT_CENTER
		keys.add_theme_constant_override("separation", 5)
		_rows.add_child(keys)
		for letter in line:
			if letter == "<":
				UIStyle.button(keys, "⌫", Vector2(76, 50), 22).pressed.connect(func() -> void:
					_typed = _typed.left(-1)
					shown.text = _typed if _typed != "" else "_")
				continue
			UIStyle.button(keys, letter, Vector2(48, 50), 21).pressed.connect(func() -> void:
				if _typed.length() < 16:
					_typed += letter
				shown.text = _typed)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_rows.add_child(row)
	UIStyle.button(row, "Back", Vector2(140, 50)).pressed.connect(func() -> void:
		_typed = ""
		_page = "settings"
		_refresh())
	UIStyle.button(row, "Enter", Vector2(140, 50)).pressed.connect(func() -> void:
		if _typed.to_lower() == CODE:
			_typed = ""
			_page = "cheats"
			_refresh()
		else:
			_typed = ""
			shown.text = "_"
			_msg.text = "That code doesn't do anything.")


## Test helpers: each button gives you something straight away.
func _cheat_page() -> void:
	UIStyle.label(_rows, "Test menu", 22)
	_msg = UIStyle.label(_rows, "Tap to give yourself things.", 16, true)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_rows.add_child(grid)
	var cheats := [
		["+500 coins", func() -> void: Money.earn(500)],
		["Materials ×25", func() -> void:
			for i: String in ["wood", "stone", "flint", "resin", "shard", "copper", "iron", "hide", "pelt", "fang", "pinewood", "shadow_pelt", "tusk"]:
				Inventory.add(i, 25)],
		["Food ×5", func() -> void:
			for i: String in ["roast_meat", "skewer", "apple_tart", "stew"]:
				Inventory.add(i, 5)
			for i: String in ["raw_meat", "mushroom", "apple", "flower", "glowcap", "tobacco", "cigarette"]:
				Inventory.add(i, 10)],
		["Every item ×10", func() -> void:
			for i: String in Items.DEFS:
				Inventory.add(i, 10)],
		["Biggest bag", func() -> void:
			Gear.bag = Gear.BAGS.size() - 1
			Gear.changed.emit()],
		["Steel tools", func() -> void:
			for slot: String in Gear.SLOTS:
				Gear.give(slot, Gear._tool(Gear.TIERS.size() - 1))],
		["Random gear ×6", func() -> void:
			for i in 6:
				var found := Gear.roll_found("elite")
				Gear.take(found[0], found[1])],
		["One of each rarity", func() -> void:           # swords, Common to Mythic
			for r in Loot.MYTHIC + 1:
				Gear.take("sword", Gear._tool(3, r, Loot.roll_bonuses("weapon", r)))],
		["Armour set (Epic)", func() -> void:
			for slot: String in Armor.SLOTS:
				Armor.give(slot, Armor.piece(3, Loot.EPIC, Loot.roll_bonuses("armor", Loot.EPIC)))],
		["Build all projects", func() -> void:
			for id: String in Projects.DEFS:
				if not Projects.is_built(id):
					Money.earn(Projects.coins(id))
					for i: String in Projects.cost(id):
						Inventory.add(i, Projects.cost(id)[i])
					Projects.fund(id)],
		["Undo all projects", func() -> void:
			for id: String in Projects.DEFS:
				Projects.unbuild(id)],
		["Undo home + yard", func() -> void: Home.reset()],
		["One of each furniture", func() -> void:        # put away, so placing them is free
			for id: String in Home.FURNITURE:
				Home.stored[id] = Home.stored.get(id, 0) + 1
			Home.furniture_changed.emit()],
		["Skills +5 levels", func() -> void:
			for sk: String in Skills.SKILLS:
				var target := mini(Skills.level(sk) + 5, Skills.MAX_LEVEL)
				Skills.add(sk, Skills.xp_for(target) - Skills.xp[sk])],
		["Unlock home (all needs)", func() -> void:
			for id: String in Projects.DEFS:
				if not Projects.is_built(id):
					Money.earn(Projects.coins(id))
					for i: String in Projects.cost(id):
						Inventory.add(i, Projects.cost(id)[i])
					Projects.fund(id)
			for sk: String in Skills.SKILLS:
				var target := mini(Skills.level(sk) + 9, Skills.MAX_LEVEL)
				Skills.add(sk, Skills.xp_for(target) - Skills.xp[sk])
			Money.earn(Balance.HOME["coins"])],
		["Full hearts", func() -> void: get_tree().call_group("player", "heal_full")],
		["Become Pyromancer", func() -> void:
			Classes.choose("pyromancer")
			get_tree().call_group("hud", "_on_class_chosen", "pyromancer")],
		["Become Delver", func() -> void:
			Classes.choose("delver")
			get_tree().call_group("hud", "_on_class_chosen", "delver")],
		["Reset story (shrine)", func() -> void: Classes.reset()],
		["+5 talent points", func() -> void:
			Classes.bonus_points += 5
			Classes.changed.emit()],
		["Morrow's job: done up to the seal", func() -> void:
			if Quests.status("morrow_seal") == "new":
				Quests.accept("morrow_seal")
			Inventory.add("black_seal", 1)],
		["Go to other area", func() -> void:
			var gate: Dictionary = Region.GATES[Region.current][0]
			_close()
			Region.travel(gate["to"], gate["arrive"])],
	]
	for c: Array in cheats:
		var b := UIStyle.button(grid, c[0], Vector2(250, 50), 19)
		b.pressed.connect(func() -> void:
			c[1].call()
			if is_instance_valid(_msg):
				_msg.text = "Done: " + c[0])
	var back := UIStyle.button(_rows, "Back", Vector2(140, 50))
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(func() -> void:
		_page = "settings"
		_refresh())


func _row(label: String, value: String, action: Callable) -> void:
	var row := HBoxContainer.new()
	_rows.add_child(row)
	var l := UIStyle.label(row, label, 22)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIStyle.button(row, value, Vector2(160, 50)).pressed.connect(func() -> void:
		action.call()
		_refresh())


func _close() -> void:
	closed.emit()
	queue_free()
