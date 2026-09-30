extends CanvasLayer
## HUD and screen flow: the title screen first, then the play UI (joystick, action and roll
## buttons, Bag and Menu icons, pickup feed, stats), and the Bag / Menu / Settings / Look screens.

const LOOK_PICKER := preload("res://scripts/ui/look_picker.gd")
const ACTION_BUTTON := preload("res://scripts/ui/action_button.gd")
const INVENTORY_PANEL := preload("res://scripts/ui/inventory_panel.gd")
const PICKUP_FEED := preload("res://scripts/ui/pickup_feed.gd")
const TITLE_SCREEN := preload("res://scripts/ui/title_screen.gd")
const MENU_PANEL := preload("res://scripts/ui/menu_panel.gd")
const SETTINGS_PANEL := preload("res://scripts/ui/settings_panel.gd")
const CLASS_PANEL := preload("res://scripts/ui/class_panel.gd")
const CRAFTING_PANEL := preload("res://scripts/ui/crafting_panel.gd")
const HOLD_TO_SPRINT := 0.18     # Roll button: shorter than this is a roll, longer is a sprint
const MARGIN := Vector2(64, 24)   # clear of the iPhone's rounded corners and Dynamic Island
## Title camera: close on the character, who stands to the right of the title.
const TITLE_VIEW := {"distance": 5.0, "pitch": -7.0, "offset": Vector3(-1.35, 0.25, 0.0)}

@export var day_night: Node
@export var character: CharacterVisual
@export var camera_rig: Node3D
@export var player: Node3D

var _fps_label: Label
var _joystick: Control
var _camera_drag: Control
var _action: Control
var _roll: Control
var _heavy: Control
var _parry: Control
var _sneak: Control
var _ability_buttons := {}         # ability id -> button (your class's abilities)
var _slow_tint: ColorRect
var _loot_card: Control
var _corner: HBoxContainer
var _furnish: Button               # only indoors, in your home
var _indoors := false
var _feed: Control
var _title: Control
var _buffs: HBoxContainer
var _buff_tick := 0.0
var _hearts: Control
var _map: Control
var _hint: Label
var _tracker: Control
var _down_cover: ColorRect
var _skill_box: VBoxContainer          # "Woodcutting  Lv 3" with a bar, shown briefly on gaining xp
var _skill_label: Label
var _skill_fill: ColorRect
var _skill_tween: Tween
var _fanfare: AudioStreamPlayer
var _worst := 0.0
var _worst_shown := 0.0
var _timer := 0.0


func _ready() -> void:
	add_to_group("hud")
	_add_vignette()
	_joystick = Control.new()
	_joystick.set_script(preload("res://scripts/ui/joystick.gd"))
	add_child(_joystick)
	_camera_drag = Control.new()
	_camera_drag.set_script(preload("res://scripts/ui/camera_drag.gd"))
	_camera_drag.camera_rig = camera_rig
	add_child(_camera_drag)

	_action = Control.new()
	_action.set_script(ACTION_BUTTON)
	add_child(_action)
	_action.pressed.connect(player.act)
	player.verb_changed.connect(_action.set_verb)
	_roll = Control.new()
	_roll.set_script(ACTION_BUTTON)
	_roll.radius = 46.0
	_roll.margin = Vector2(285, 100)
	_roll.font_size = 20
	add_child(_roll)
	_roll.set_verb("Roll")
	_roll.sub = "hold: sprint"
	# A tap rolls (on release); holding it sprints instead (see _process).
	_roll.released.connect(func() -> void:
		if _roll.held_for() < HOLD_TO_SPRINT:
			player.roll())
	_heavy = Control.new()
	_heavy.set_script(ACTION_BUTTON)
	_heavy.radius = 40.0
	_heavy.margin = Vector2(285, 225)
	_heavy.font_size = 17
	add_child(_heavy)
	_heavy.set_verb("Heavy")
	_heavy.pressed.connect(player.heavy)
	# Every button keeps its spot (a ring round Attack); Compact hides Heavy and Parry for flicks on Attack.
	_parry = Control.new()
	_parry.set_script(ACTION_BUTTON)
	_parry.radius = 40.0
	_parry.margin = Vector2(180, 295)
	_parry.font_size = 17
	add_child(_parry)
	_parry.set_verb("Parry")
	_parry.pressed.connect(player.guard)
	_sneak = Control.new()
	_sneak.set_script(ACTION_BUTTON)
	_sneak.radius = 36.0
	_sneak.margin = Vector2(72, 300)
	_sneak.font_size = 16
	add_child(_sneak)
	_sneak.set_verb("Sneak")
	_sneak.pressed.connect(player.sneak)
	_action.swiped.connect(func(dir: String) -> void:
		if dir == "up":
			player.heavy()
		elif dir == "left":
			player.guard())
	Settings.changed.connect(_show_heavy)
	var spots := [Vector2(385, 290), Vector2(300, 385), Vector2(178, 430)]
	for i in 3:
		var b := Control.new()
		b.set_script(ACTION_BUTTON)
		b.radius = 42.0
		b.margin = spots[i]
		b.font_size = 16
		b.visible = false
		add_child(b)
		b.set_meta("slot", i)
		b.pressed.connect(func() -> void:
			var list := Classes.abilities()
			if b.get_meta("slot") < list.size():
				player.abilities.use(list[b.get_meta("slot")]))
		_ability_buttons[i] = b
	Classes.changed.connect(_update_ability_buttons)
	player.stamina.refused.connect(func(cost: String) -> void:
		({"heavy": _heavy, "guard": _parry}.get(cost, _roll) as Control).refuse())
	_slow_tint = ColorRect.new()
	_slow_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slow_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slow_tint.color = Color(0.35, 0.6, 1.0, 0.0)
	add_child(_slow_tint)
	move_child(_slow_tint, 0)

	_corner = HBoxContainer.new()
	_corner.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_corner.position = Vector2(-MARGIN.x, MARGIN.y)
	_corner.add_theme_constant_override("separation", 12)
	add_child(_corner)
	_furnish = UIStyle.button(_corner, "Furnish", Vector2(120, 60), 20)
	_furnish.visible = false
	_furnish.pressed.connect(start_build_mode.bind(true))
	UIStyle.icon_button(_corner, "menuGrid").pressed.connect(open_bag)
	UIStyle.icon_button(_corner, "gear").pressed.connect(open_menu)

	_map = Control.new()
	_map.set_script(preload("res://scripts/ui/minimap.gd"))
	_map.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_map.position = Vector2(-MARGIN.x - 150.0, MARGIN.y + 72.0)
	_map.player = player
	_map.visual = character
	add_child(_map)

	_hearts = Control.new()
	_hearts.set_script(preload("res://scripts/ui/hearts.gd"))
	add_child(_hearts)
	player.health_changed.connect(_hearts.show_health)
	player.knocked_out.connect(_knocked_out)
	player.got_up.connect(_got_up)

	_buffs = HBoxContainer.new()
	_buffs.position = MARGIN + Vector2(0, 96)
	_buffs.add_theme_constant_override("separation", 8)
	add_child(_buffs)
	Food.changed.connect(_show_buffs)

	Quests.completed.connect(show_quest_complete)
	_tracker = PanelContainer.new()
	_tracker.set_script(preload("res://scripts/ui/quest_tracker.gd"))
	_tracker.position = MARGIN + Vector2(0, 140)
	add_child(_tracker)

	_feed = Control.new()
	_feed.set_script(PICKUP_FEED)
	add_child(_feed)

	_fps_label = Label.new()
	_fps_label.position = MARGIN
	_fps_label.add_theme_font_size_override("font_size", 16)
	_fps_label.modulate = Color(1, 1, 1, 0.7)
	_fps_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_fps_label.add_theme_constant_override("outline_size", 6)
	add_child(_fps_label)
	Settings.changed.connect(_on_settings_changed)
	_on_settings_changed()

	_hint = UIStyle.label(self, "", 24)
	_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.position.y = 110
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_hint.add_theme_constant_override("outline_size", 8)
	_hint.modulate.a = 0.0

	_skill_box = VBoxContainer.new()
	_skill_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_skill_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_skill_box.position = Vector2(-110, -92)
	_skill_box.custom_minimum_size = Vector2(220, 0)
	_skill_box.add_theme_constant_override("separation", 4)
	_skill_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_skill_box)
	_skill_label = UIStyle.label(_skill_box, "", 18)
	_skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skill_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_skill_label.add_theme_constant_override("outline_size", 6)
	var track := ColorRect.new()
	track.color = Color(0, 0, 0, 0.45)
	track.custom_minimum_size = Vector2(220, 8)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skill_box.add_child(track)
	_skill_fill = ColorRect.new()
	_skill_fill.color = Color(1.0, 0.84, 0.46)
	_skill_fill.size = Vector2(0, 8)
	_skill_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(_skill_fill)
	_skill_box.modulate.a = 0.0
	_fanfare = AudioStreamPlayer.new()
	_fanfare.stream = preload("res://assets/sounds/rare.wav")
	add_child(_fanfare)
	Skills.gained.connect(_on_skill_gained)
	Skills.leveled.connect(_on_skill_leveled)

	if Region.arrive != Vector2.INF:      # just travelled to another region: straight back to playing
		start_game.call_deferred(true)
	else:
		show_title()


## Running food buffs as small coloured tags with the seconds left.
func _show_buffs() -> void:
	for c in _buffs.get_children():
		c.queue_free()
	for b: String in Food.active():
		var tag := UIStyle.label(_buffs, "%s %ds" % [Food.BUFFS[b]["name"], ceili(Food.left(b))], 17)
		tag.add_theme_color_override("font_color", Food.BUFFS[b]["color"])
		tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		tag.add_theme_constant_override("outline_size", 6)


func _process(delta: float) -> void:
	_update_roll_button()
	_update_ability_buttons()
	_buff_tick -= delta
	if _buff_tick <= 0.0 and _buffs.get_child_count() > 0:
		_buff_tick = 1.0
		_show_buffs()
	_worst = maxf(_worst, delta)
	_timer += delta
	if _timer < 1.0:
		return
	_worst_shown = _worst
	_worst = 0.0
	_timer = 0.0
	_fps_label.text = "%d fps · worst %d ms\n%d draws · %dk tris" % [
		Engine.get_frames_per_second(), roundi(_worst_shown * 1000.0),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000]


## Paints the minimap once the world is built (main calls this).
func setup_map(shape: WorldShape, trees: Array[Vector2], landmark: Node3D) -> void:
	_map.landmark = landmark
	_map.setup(shape, trees)


# --- screen flow ---------------------------------------------------------------------------

func show_title() -> void:
	_set_play_ui(false)
	Controls.locked = true
	_title = Control.new()
	_title.set_script(TITLE_SCREEN)
	add_child(_title)
	_title.play.connect(start_game)
	_title.open_character.connect(open_look_picker)
	_title.open_settings.connect(open_settings)
	_title.build_lab.connect(func() -> void:
		start_game(true)
		get_tree().call_group("build_lab", "enter"))
	_title_camera()


## Leaves the title and hands control to the player (`instant` skips the fade; dev tests use it).
func start_game(instant := false) -> void:
	if instant and is_instance_valid(_title):
		_title.queue_free()
	_title = null
	Controls.locked = false
	camera_rig.reset_view(0.01 if instant else 0.9)
	_set_play_ui(true)


## A short message at the top of the screen ("Needs a Stone Pickaxe", "Made a Copper Axe!").
func hint(text: String) -> void:
	_hint.text = text
	_hint.modulate.a = 1.0
	if _hint.has_meta("tween"):
		(_hint.get_meta("tween") as Tween).kill()
	var t := create_tween()
	t.tween_interval(1.6)
	t.tween_property(_hint, "modulate:a", 0.0, 0.5)
	_hint.set_meta("tween", t)


func _on_skill_gained(skill: String, _amount: int) -> void:
	_skill_label.text = "%s  Lv %d" % [Skills.SKILLS[skill], Skills.level(skill)]
	_skill_fill.size.x = 220.0 * Skills.progress(skill)
	_skill_box.modulate.a = 1.0
	if _skill_tween:
		_skill_tween.kill()
	_skill_tween = create_tween()
	_skill_tween.tween_interval(1.8)
	_skill_tween.tween_property(_skill_box, "modulate:a", 0.0, 0.5)


func _on_skill_leveled(skill: String, level: int) -> void:
	hint(Skills.perk_text(skill))
	Banner.show_now(self, "LEVEL UP", "%s  %d" % [Skills.SKILLS[skill], level], Color(1.0, 0.82, 0.38), preload("res://assets/sounds/level_up.wav"))
	get_tree().call_group("player", "level_glow")


## Gear turned up in a chest or on an enemy: a card with its stats (see loot_card.gd). Rarer finds
## play the fanfare higher.
func found_tool(slot: String, tool: Dictionary) -> void:
	if is_instance_valid(_loot_card):
		_loot_card.queue_free()
	_loot_card = PanelContainer.new()
	_loot_card.set_script(preload("res://scripts/ui/loot_card.gd"))
	add_child(_loot_card)
	_loot_card.show_piece(slot, tool)
	_fanfare.pitch_scale = 0.9 + 0.06 * tool["rarity"]
	_fanfare.play()


func open_crafting() -> void:
	_modal(CRAFTING_PANEL)


## A campfire, the trader or a project board: the shop panel with those settings.
func open_station(props: Dictionary) -> void:
	if props.get("mode", "") == "craft":
		open_crafting()
		return
	if props.get("mode", "") == "lab":       # the build lab's board (dev/lab_menu.gd)
		_modal(preload("res://scripts/dev/lab_menu.gd"), {"lab": props["lab"]})
		return
	var panel := _modal(preload("res://scripts/ui/shop_panel.gd"), props)
	panel.build_home.connect(start_build_mode)


## Inside your home or back outside (world/home_interior.gd): the Furnish button, no minimap.
func set_indoors(on: bool) -> void:
	_indoors = on
	_furnish.visible = on
	_map.visible = _action.visible and Settings.show_map and not on


## Building in your yard, or furnishing your home (`room`): joystick stays, the build bar replaces
## the other buttons.
func start_build_mode(room := false) -> void:
	_set_play_ui(true)
	_action.visible = false
	_roll.visible = false
	_heavy.visible = false
	_parry.visible = false
	_sneak.visible = false
	_corner.visible = false
	Controls.locked = false
	var ui := Control.new()
	ui.set_script(preload("res://scripts/ui/build_mode.gd"))
	ui.player = player
	ui.room = room
	if room:
		ui.origin = get_tree().get_first_node_in_group("home_interior").global_position
	add_child(ui)
	ui.closed.connect(func() -> void: _set_play_ui(true))


## The reward banner when a quest is handed in (Quests.completed).
func show_quest_complete(id: String) -> void:
	var banner := Control.new()
	banner.set_script(preload("res://scripts/ui/quest_complete.gd"))
	banner.quest = id
	add_child(banner)


## Talking to a villager (world/npc.gd).
func open_dialogue(npc: String) -> void:
	_tracker.set("hidden_for_talk", true)                       # it would sit behind the portrait
	_tracker.call("refresh")
	var panel := _modal(preload("res://scripts/ui/dialogue_panel.gd"), {"npc": npc})
	panel.closed.connect(func() -> void:
		_tracker.set("hidden_for_talk", false)
		_tracker.call("refresh"))


func open_bag() -> void:
	_modal(INVENTORY_PANEL)


func open_menu() -> void:
	var menu := _modal(MENU_PANEL, {"day_night": day_night, "character": character})
	menu.open_character.connect(open_look_picker)
	menu.open_class.connect(func() -> void: open_class_panel(false))
	menu.open_settings.connect(open_settings)
	menu.open_quests.connect(open_quests)
	menu.to_title.connect(func() -> void:
		SaveGame.save_game()
		show_title())


## The quest log: every quest you're on and have done; pick the one to follow.
func open_quests() -> void:
	_modal(preload("res://scripts/ui/quest_log.gd"))


func open_settings() -> void:
	_modal(SETTINGS_PANEL)


func open_look_picker() -> void:
	_set_play_ui(false)
	if _title:
		_title.visible = false
	var picker := Control.new()
	picker.set_script(LOOK_PICKER)
	add_child(picker)
	picker.open(character, camera_rig)
	picker.closed.connect(_back_from_screen)


## Opens a panel over the game (controls locked until it closes).
func _modal(script: Script, props := {}) -> Control:
	_set_play_ui(false)
	if _title:
		_title.visible = false
	Controls.locked = true
	var panel := Control.new()
	panel.set_script(script)
	for key: String in props:
		panel.set(key, props[key])
	add_child(panel)
	panel.closed.connect(_back_from_screen)
	return panel


func _back_from_screen() -> void:
	if _title:
		_title.visible = true
		Controls.locked = true
		_title_camera()
	else:
		Controls.locked = false
		_set_play_ui(true)


func _title_camera() -> void:
	camera_rig.set_view(TITLE_VIEW["distance"], TITLE_VIEW["pitch"], TITLE_VIEW["offset"], 0.8)
	var turn := create_tween().set_trans(Tween.TRANS_SINE)
	turn.tween_method(func(a: float) -> void: character.rotation.y = a, character.rotation.y, 0.35, 0.6)


func _set_play_ui(on: bool) -> void:
	_joystick.visible = on
	_camera_drag.visible = on
	_action.visible = on
	_roll.visible = on
	if not on:
		Controls.sprint_button = false
	_show_heavy()
	_corner.visible = on
	_feed.visible = on
	_hearts.visible = on
	_map.visible = on and Settings.show_map and not _indoors


## Roll button: sprint while held, its rim shows stamina, it lights up while sprinting.
func _update_roll_button() -> void:
	Controls.sprint_button = _roll.visible and _roll.held_for() >= HOLD_TO_SPRINT
	var sprinting: bool = player.sprinting
	if sprinting != _roll.lit:
		_roll.lit = sprinting
		_roll.set_verb("Sprint" if sprinting else "Roll")
	var st: Stamina = player.stamina
	_roll.meter_color = Color(1.0, 0.45, 0.26) if st.winded else Color(0.62, 0.9, 0.38)
	_roll.set_meter(st.value / st.max_value())
	var dim := not st.can("heavy")
	if dim != _heavy.dim:
		_heavy.dim = dim
		_heavy.queue_redraw()


## The fight buttons are always there while you play (Compact: flicks on Attack instead of Heavy and Parry).
func _show_heavy() -> void:
	var compact := Settings.compact_controls
	_heavy.visible = _action.visible and not compact
	_parry.visible = _action.visible and not compact
	_sneak.visible = _action.visible
	_action.swipes = {"up": "Heavy", "left": "Parry"} if compact else {}
	_action.queue_redraw()


## Sneaking on or off: the Sneak button lights up while you're crouched.
func sneak_changed(on: bool) -> void:
	_sneak.lit = on
	_sneak.set_verb("Sneaking" if on else "Sneak")


## Your class's ability buttons: named, with a ring that fills back up as the cooldown ends.
func _update_ability_buttons() -> void:
	var list := Classes.abilities()
	for i: int in _ability_buttons:
		var b: Control = _ability_buttons[i]
		var show: bool = i < list.size() and _action.visible
		b.visible = show
		if not show:
			continue
		var id: String = list[i]
		if b.get_meta("id", "") != id:
			b.set_meta("id", id)
			b.set_verb(Classes.ABILITIES[id]["short"])
			b.meter_color = Classes.color()
			b.lit_fill = Color(Classes.color().darkened(0.55), 0.8)
		var left := Classes.cooldown_left(id)
		b.set_meter(1.0 - left)
		var dim := left > 0.0
		if dim != b.dim:
			b.dim = dim
			b.queue_redraw()
		b.lit = not dim


func open_class_panel(from_shrine: bool) -> void:
	var panel := _modal(CLASS_PANEL, {"from_shrine": from_shrine})
	panel.chosen.connect(_on_class_chosen)


## You took a class: its name across the screen and fire bursting out around you.
func _on_class_chosen(id: String) -> void:
	var def: Dictionary = Classes.CLASSES[id]
	Banner.show_now(self, String(def["name"]).to_upper(), "The flame answers you", def["color"], preload("res://assets/sounds/fire_burst.wav"), 2.4)
	player.get_node("Effects").glow_burst(def["color"], 120)
	FireFX.flames(player.get_parent(), player.global_position + Vector3(0, 0.4, 0), 1.2, 60, 1.0, true, 0.8)
	get_tree().call_group("camera_rig", "shake", 0.15)
	_update_ability_buttons()


## Slow motion (a perfect dodge or parry): a cool blue wash over the screen that fades as time returns.
func slow_tint(seconds: float) -> void:
	_slow_tint.color.a = 0.16
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_property(_slow_tint, "color:a", 0.0, seconds)


func _on_settings_changed() -> void:
	_fps_label.visible = Settings.show_stats
	if _map and _action.visible:
		_map.visible = Settings.show_map and not _indoors


func _add_vignette() -> void:
	# A soft vignette: slightly darker corners pull the eye to the middle.
	var vignette := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_color(1, Color(0.02, 0.03, 0.08, 0.32))
	grad.add_point(0.55, Color(0, 0, 0, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.05, 1.05)
	vignette.texture = tex
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)


## A dark fade with a message while the player is down, lifting as they get back up.
## Knocked out: a beat of slow motion with a red flash, the camera leans in, then a fade to black
## with "KNOCKED OUT" in the title's style. It lifts when the player gets up (player.got_up).
func _knocked_out() -> void:
	_set_play_ui(false)
	Engine.time_scale = 0.35
	get_tree().call_group("camera_rig", "shake", 0.25)
	camera_rig.set_view(11.0, -58.0, Vector3.ZERO, 0.8)
	var flash := ColorRect.new()
	flash.color = Color(0.75, 0.08, 0.06, 0.45)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	_down_cover = ColorRect.new()
	_down_cover.color = Color(0.02, 0.02, 0.05, 0.0)
	_down_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_down_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_down_cover)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 14)
	column.modulate.a = 0.0
	_down_cover.add_child(column)
	var title := UIStyle.label(column, "K N O C K E D   O U T", 52)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.93, 0.82))
	title.add_theme_color_override("font_outline_color", Color(0.45, 0.12, 0.08, 0.9))
	title.add_theme_constant_override("outline_size", 6)
	var line := ColorRect.new()
	line.color = Color(0.93, 0.8, 0.52, 0.85)
	line.custom_minimum_size = Vector2(0, 3)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(line)
	var sub := UIStyle.label(column, "Waking up in the village...", 22, true)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_property(flash, "color:a", 0.0, 0.7)
	t.tween_callback(func() -> void: Engine.time_scale = 1.0)
	t.tween_property(_down_cover, "color:a", 0.92, 0.6)
	t.parallel().tween_property(column, "modulate:a", 1.0, 0.6)
	t.parallel().tween_property(line, "custom_minimum_size:x", 260.0, 0.9).set_trans(Tween.TRANS_SINE)
	t.tween_callback(flash.queue_free)


func _got_up() -> void:
	Engine.time_scale = 1.0
	if not is_instance_valid(_down_cover):
		return
	var cover := _down_cover
	_down_cover = null
	camera_rig.reset_view(0.01)
	_set_play_ui(true)
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_property(cover, "modulate:a", 0.0, 0.8)
	t.tween_callback(cover.queue_free)
