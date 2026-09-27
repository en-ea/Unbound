extends Control
## The title screen: the living world behind, the game's name, and Play / Character / Settings.
## The camera frames your character on the right; the title sits on the left.

signal play
signal open_character
signal open_settings
signal build_lab

const VERSION := "early build"

var _buttons: VBoxContainer
var _deco: Control
var _time := 0.0
var _motes: Array[Vector3] = []     # x, y, speed


func _process(delta: float) -> void:
	_time += delta
	_deco.queue_redraw()


## Drifting motes of light, a gold emblem above the title and ornamental rules.
func _draw_deco() -> void:
	var size := _deco.size
	if _motes.is_empty():
		for i in 40:
			_motes.append(Vector3(randf() * size.x, randf() * size.y, randf_range(8.0, 22.0)))
	for m in _motes:
		var y := fposmod(m.y - _time * m.z, size.y)
		var x := m.x + sin(_time * 0.6 + m.y) * 12.0
		var a := 0.25 + 0.25 * sin(_time * 2.0 + m.x)
		_deco.draw_circle(Vector2(x, y), 2.2, Color(1.0, 0.88, 0.6, a))
		_deco.draw_circle(Vector2(x, y), 5.0, Color(1.0, 0.85, 0.5, a * 0.25))
	var gold := Color(0.95, 0.8, 0.5, 0.95)
	var c := Vector2(310, size.y * 0.5 - 300)
	var spin := _time * 0.2
	_deco.draw_arc(c, 34, 0, TAU, 64, gold, 2.5, true)
	_deco.draw_arc(c, 26, 0, TAU, 64, Color(gold, 0.5), 1.5, true)
	for k in 4:
		var a := spin + k * PI / 2
		_deco.draw_line(c + Vector2.from_angle(a) * 36, c + Vector2.from_angle(a) * 52, gold, 2.0, true)
	var d := PackedVector2Array([c + Vector2(0, -16), c + Vector2(11, 0), c + Vector2(0, 16), c + Vector2(-11, 0)])
	_deco.draw_colored_polygon(d, Color(1.0, 0.86, 0.55))
	for s in [-1, 1]:
		_deco.draw_line(c + Vector2(s * 60, 0), c + Vector2(s * 200, 0), Color(gold, 0.5), 1.5, true)
		_deco.draw_circle(c + Vector2(s * 205, 0), 3.0, Color(gold, 0.7))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# A soft dark wash on the left so the title reads over the world.
	var wash := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.03, 0.04, 0.09, 0.72))
	grad.set_color(1, Color(0.03, 0.04, 0.09, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0.62, 0)
	wash.texture = tex
	wash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wash.stretch_mode = TextureRect.STRETCH_SCALE
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)

	_deco = Control.new()
	_deco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deco.draw.connect(_draw_deco)
	add_child(_deco)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	column.position = Vector2(110, -250)
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	var title := UIStyle.label(column, "U N B O U N D", 82)
	title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.84))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.45))
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.add_theme_constant_override("shadow_outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color(0.55, 0.38, 0.18, 0.9))
	title.add_theme_constant_override("outline_size", 6)
	var line := ColorRect.new()
	line.color = Color(0.93, 0.8, 0.52, 0.85)
	line.custom_minimum_size = Vector2(120, 3)
	line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(line)
	var tagline := UIStyle.label(column, "A quiet land, waiting to wake.", 24, true)
	tagline.add_theme_color_override("font_color", Color(1.0, 0.95, 0.84, 0.75))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 26)
	column.add_child(gap)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 14)
	column.add_child(_buttons)
	UIStyle.menu_button(_buttons, "Play", true).pressed.connect(_on_play)
	UIStyle.menu_button(_buttons, "Character").pressed.connect(func() -> void: open_character.emit())
	UIStyle.menu_button(_buttons, "Settings").pressed.connect(func() -> void: open_settings.emit())

	# Bottom-left: the build lab (compare every building style on a flat floor).
	var lab := UIStyle.button(self, "Build lab", Vector2(150, 44), 18)
	lab.anchor_top = 1.0
	lab.anchor_bottom = 1.0
	lab.offset_left = 110
	lab.offset_top = -120
	lab.offset_bottom = -76
	lab.pressed.connect(func() -> void:
		_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
		build_lab.emit()
		queue_free())

	var version := UIStyle.label(self, VERSION, 16, true)
	version.anchor_top = 1.0
	version.anchor_bottom = 1.0
	version.offset_left = 110
	version.offset_top = -56
	version.offset_bottom = -30

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.8)


func _on_play() -> void:
	_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.45)
	fade.tween_callback(func() -> void:
		play.emit()
		queue_free())
