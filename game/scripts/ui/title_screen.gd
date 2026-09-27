extends Control
## The title screen: the living world behind, the game's name, and Play / Character / Settings.
## The camera frames your character on the right; the title sits on the left.

signal play
signal open_character
signal open_settings

const VERSION := "early build"

var _buttons: VBoxContainer


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

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	column.position = Vector2(110, -250)
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	var title := UIStyle.label(column, "U N B O U N D", 74)
	title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.84))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.45))
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.add_theme_constant_override("shadow_outline_size", 10)
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
