extends Control
## Talking to a villager (see state/npcs.gd, Quests.talk): a live portrait of them in a framed window
## (a warm glow behind them, in their colour) beside a card in their own colours and lettering. Their words type out with their own little voice (blips), tap to
## show it all; the answer buttons appear when the words are done. Set `npc` before adding it.

signal closed

const CHARS_PER_SEC := 46.0
const PAUSES := {",": 0.14, ".": 0.28, "!": 0.28, "?": 0.28, ":": 0.2, ";": 0.2}
const PORTRAIT_SIZE := Vector2(300, 340)
const RenderGate := preload("res://scripts/studio/render_gate.gd")   # studio
const EDGE := 24.0                   # gap to the screen edges

var npc := ""

var _def: Dictionary
var _theme: Dictionary
var _font: Font
var _name_font: Font
var _card: PanelContainer
var _text: Label
var _buttons: HBoxContainer
var _portrait: CharacterVisual
var _voice: AudioStreamPlayer
var _voices: Array[AudioStream] = []
var _shown := 0.0
var _pause := 0.0
var _blip_at := 0
var _typing := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_def = Npcs.get_def(npc)
	_theme = _def.get("theme", {})
	_font = load(_theme.get("font", "")) if _theme.has("font") else null
	_name_font = load(_theme.get("name_font", "")) if _theme.has("name_font") else _font
	var accent: Color = _theme.get("accent", Color(1.0, 0.86, 0.5))
	_build_card(accent)
	_build_portrait()
	_voice = AudioStreamPlayer.new()
	_voice.volume_db = -9.0
	add_child(_voice)
	for i in 8:                 # up to 8 clips per voice
		var path := "res://assets/sounds/voice_%s_%d.wav" % [_theme.get("voice", "wren"), i]
		if ResourceLoader.exists(path):
			_voices.append(load(path))
	_show(Quests.talk(npc))
	_slide_in()


func _build_card(accent: Color) -> void:
	_card = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = _theme.get("bg", Color(0.06, 0.08, 0.13, 0.94))
	box.set_corner_radius_all(26)
	box.border_color = accent
	box.set_border_width_all(3)
	box.border_width_bottom = 5
	box.shadow_color = Color(0, 0, 0, 0.5)
	box.shadow_size = 18
	box.content_margin_left = 44
	box.content_margin_right = 30
	box.content_margin_top = 18
	box.content_margin_bottom = 20
	_card.add_theme_stylebox_override("panel", box)
	_card.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_card.offset_left = EDGE + PORTRAIT_SIZE.x - 18
	_card.offset_right = -EDGE
	_card.offset_bottom = -EDGE
	_card.gui_input.connect(_on_card_input)
	add_child(_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_card.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	column.add_child(head)
	var name_label := Label.new()
	name_label.text = _def["name"]
	name_label.add_theme_font_size_override("font_size", 40)
	name_label.add_theme_color_override("font_color", accent)
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	name_label.add_theme_constant_override("outline_size", 6)
	if _name_font:
		name_label.add_theme_font_override("font", _name_font)
	head.add_child(name_label)
	var title := Label.new()
	title.text = String(_def["title"]).to_upper()
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(accent, 0.75))
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _name_font:
		title.add_theme_font_override("font", _name_font)
	head.add_child(title)
	var fade := Gradient.new()
	fade.set_color(0, accent)
	fade.set_color(1, Color(accent, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = fade
	tex.fill_from = Vector2(0, 0.5)
	tex.fill_to = Vector2(1, 0.5)
	var line := TextureRect.new()                          # a thin line under the name that fades out
	line.texture = tex
	line.custom_minimum_size = Vector2(0, 3)
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	column.add_child(line)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 27)
	_text.add_theme_color_override("font_color", _theme.get("text", Color(1, 0.97, 0.9)))
	_text.custom_minimum_size = Vector2(0, 118)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _font:
		_text.add_theme_font_override("font", _font)
	column.add_child(_text)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 12)
	_buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(_buttons)


## A live picture of them from the chest up in a rounded window: their colour glowing behind them, a
## thin frame in their accent, and a darker edge so they stand out.
func _build_portrait() -> void:
	var port: Dictionary = _def.get("portrait", {})
	var accent: Color = _theme.get("accent", Color(1.0, 0.86, 0.5))
	var bg: Color = _theme.get("bg", Color(0.06, 0.08, 0.13))
	var holder := Control.new()
	holder.name = "Portrait"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	holder.offset_left = EDGE
	holder.offset_right = EDGE + PORTRAIT_SIZE.x
	holder.offset_top = -PORTRAIT_SIZE.y - EDGE
	holder.offset_bottom = -EDGE
	add_child(holder)
	var window := Panel.new()                              # its rounded shape clips everything inside
	window.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	window.set_anchors_preset(Control.PRESET_FULL_RECT)
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shape := StyleBoxFlat.new()
	shape.bg_color = Color(bg, 1.0)
	shape.set_corner_radius_all(28)
	window.add_theme_stylebox_override("panel", shape)
	holder.add_child(window)
	var glow := Gradient.new()                             # warm light behind them, dark at the edges
	glow.set_color(0, accent.lerp(Color(1, 1, 1), 0.15))
	glow.set_color(1, Color(bg, 1.0).darkened(0.2))
	glow.add_point(0.45, accent.darkened(0.45))
	var glow_tex := GradientTexture2D.new()
	glow_tex.gradient = glow
	glow_tex.fill = GradientTexture2D.FILL_RADIAL
	glow_tex.fill_from = Vector2(0.5, 0.38)
	glow_tex.fill_to = Vector2(1.15, 1.0)
	var back := TextureRect.new()
	back.texture = glow_tex
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.add_child(back)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	window.add_child(container)
	var view := SubViewport.new()
	view.transparent_bg = true
	view.own_world_3d = true
	view.size = Vector2i(PORTRAIT_SIZE)
	view.msaa_3d = RenderGate.msaa(Viewport.MSAA_2X)   # studio: no 3D MSAA where it leaks (render_gate.gd)
	container.add_child(view)
	var shade := Gradient.new()                            # a soft dark fade at the bottom of the window
	shade.set_color(0, Color(0, 0, 0, 0))
	shade.set_color(1, Color(0, 0, 0, 0.55))
	var shade_tex := GradientTexture2D.new()
	shade_tex.gradient = shade
	shade_tex.fill_from = Vector2(0.5, 0.62)
	shade_tex.fill_to = Vector2(0.5, 1.0)
	var bottom := TextureRect.new()
	bottom.texture = shade_tex
	bottom.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bottom.set_anchors_preset(Control.PRESET_FULL_RECT)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.add_child(bottom)
	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := StyleBoxFlat.new()
	line.draw_center = false
	line.set_corner_radius_all(28)
	line.border_color = accent
	line.set_border_width_all(3)
	line.shadow_color = Color(0, 0, 0, 0.45)
	line.shadow_size = 16
	frame.add_theme_stylebox_override("panel", line)
	holder.add_child(frame)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.74, 0.74, 0.84)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	view.add_child(world_env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-24, 32, 0)
	key.light_energy = 1.3
	key.light_color = Color(1, 0.93, 0.8)
	view.add_child(key)
	var rim := DirectionalLight3D.new()                    # an edge light from behind, in their colour
	rim.rotation_degrees = Vector3(-15, 200, 0)
	rim.light_energy = 1.1
	rim.light_color = accent.lerp(Color.WHITE, 0.4)
	view.add_child(rim)
	_portrait = Npcs.make_visual(npc)
	view.add_child(_portrait)
	Npcs.dress_visual(npc, _portrait, true)
	_portrait.rotation_degrees.y = port.get("turn", -15.0)
	var cam := Camera3D.new()
	cam.fov = port.get("fov", 34.0)
	view.add_child(cam)
	cam.position = port.get("cam", Vector3(0.7, 1.7, 2.6))
	cam.look_at(port.get("look_at", Vector3(0, 1.6, 0)))
	holder.pivot_offset = Vector2(0, PORTRAIT_SIZE.y)


func _slide_in() -> void:
	var portrait := get_node("Portrait") as Control
	portrait.modulate.a = 0.0
	portrait.scale = Vector2(0.85, 0.85)
	_card.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(portrait, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(portrait, "modulate:a", 1.0, 0.25)
	t.tween_property(_card, "modulate:a", 1.0, 0.25)


func _show(screen: Dictionary) -> void:
	if screen.is_empty():
		closed.emit()
		queue_free()
		return
	_text.text = screen["text"]
	_text.visible_characters = 0
	_shown = 0.0
	_pause = 0.0
	_blip_at = 0
	_typing = true
	_portrait.talk(true)
	for c in _buttons.get_children():
		c.queue_free()
	_buttons.modulate.a = 0.0
	for o: Dictionary in screen["options"]:
		var b := _button(o["label"])
		b.pressed.connect(func() -> void: _show(o["do"].call()))
	if screen.has("emote"):
		_portrait.play_action(screen["emote"])


func _button(label: String) -> Button:
	var accent: Color = _theme.get("accent", Color(1.0, 0.86, 0.5))
	var b := UIStyle.button(_buttons, label, Vector2(160, 56), 23)
	b.add_theme_color_override("font_color", accent.lightened(0.5))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	if _name_font:
		b.add_theme_font_override("font", _name_font)
	for state in ["normal", "hover", "pressed"]:
		var box := b.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		box.bg_color = Color(accent, 0.28) if state == "pressed" else Color(accent, 0.1)
		box.border_color = accent
		box.set_border_width_all(2)
		b.add_theme_stylebox_override(state, box)
	return b


func _on_card_input(e: InputEvent) -> void:
	if _typing and e is InputEventMouseButton and e.pressed:
		_shown = 99999.0


func _process(delta: float) -> void:
	if not _typing:
		return
	var total := _text.get_total_character_count()
	if _pause > 0.0:
		_pause -= delta
	else:
		_shown += delta * CHARS_PER_SEC
	var count := mini(int(_shown), total)
	if count > _text.visible_characters:
		var raw: String = _text.text
		for i in range(_text.visible_characters, count):     # a blip every second letter; a pause at punctuation
			var ch := raw[i]
			if PAUSES.has(ch):
				_pause = PAUSES[ch]
			elif ch != " ":
				_blip_at += 1
				if _blip_at % 2 == 0:
					_blip()
		_text.visible_characters = count
	if count >= total:
		_typing = false
		_portrait.talk(false)
		create_tween().tween_property(_buttons, "modulate:a", 1.0, 0.25)


func _blip() -> void:
	if _voices.is_empty():
		return
	_voice.stream = _voices[randi() % _voices.size()]
	_voice.pitch_scale = randf_range(0.88, 1.18)
	_voice.play()
