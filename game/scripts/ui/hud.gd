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
const CRAFTING_PANEL := preload("res://scripts/ui/crafting_panel.gd")
const MARGIN := Vector2(64, 24)   # clear of the iPhone's rounded corners and Dynamic Island
## Title camera: close on the character, who stands to the right of the title.
const TITLE_VIEW := {"distance": 5.0, "pitch": -7.0, "offset": Vector3(-1.35, 0.25, 0.0)}

@export var day_night: Node
@export var character: CharacterVisual
@export var camera_rig: Node3D
@export var player: Node3D

var _fps_label: Label
var _joystick: Control
var _action: Control
var _roll: Control
var _corner: HBoxContainer
var _feed: Control
var _title: Control
var _hearts: Control
var _map: Control
var _hint: Label
var _worst := 0.0
var _worst_shown := 0.0
var _timer := 0.0


func _ready() -> void:
	add_to_group("hud")
	_add_vignette()
	_joystick = Control.new()
	_joystick.set_script(preload("res://scripts/ui/joystick.gd"))
	add_child(_joystick)

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
	_roll.pressed.connect(player.roll)

	_corner = HBoxContainer.new()
	_corner.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_corner.position = Vector2(-MARGIN.x, MARGIN.y)
	_corner.add_theme_constant_override("separation", 12)
	add_child(_corner)
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

	show_title()


func _process(delta: float) -> void:
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


func open_crafting() -> void:
	_modal(CRAFTING_PANEL)


func open_bag() -> void:
	_modal(INVENTORY_PANEL)


func open_menu() -> void:
	var menu := _modal(MENU_PANEL, {"day_night": day_night, "character": character})
	menu.open_character.connect(open_look_picker)
	menu.open_settings.connect(open_settings)


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
	_action.visible = on
	_roll.visible = on
	_corner.visible = on
	_feed.visible = on
	_hearts.visible = on
	_map.visible = on and Settings.show_map


func _on_settings_changed() -> void:
	_fps_label.visible = Settings.show_stats
	if _map and _action.visible:
		_map.visible = Settings.show_map


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
func _knocked_out() -> void:
	var cover := ColorRect.new()
	cover.color = Color(0.03, 0.03, 0.06, 0.0)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cover)
	var text := UIStyle.label(cover, "Knocked out...", 40)
	text.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	text.grow_horizontal = Control.GROW_DIRECTION_BOTH
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var fade := create_tween()
	fade.tween_property(cover, "color:a", 0.85, 0.9).set_delay(0.6)
	fade.tween_interval(0.8)
	fade.tween_property(cover, "color:a", 0.0, 0.6)
	fade.parallel().tween_property(text, "modulate:a", 0.0, 0.4)
	fade.tween_callback(cover.queue_free)
