extends Control
## The in-game menu (gear button): resume, change your look, settings, and the dev tools.

signal closed
signal open_character
signal open_settings

@export var day_night: Node
@export var character: CharacterVisual


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.4)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 14)
	add_child(column)
	var title := UIStyle.label(column, "Paused", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.menu_button(column, "Resume", true).pressed.connect(_close)
	UIStyle.menu_button(column, "Character").pressed.connect(func() -> void:
		open_character.emit()
		queue_free())
	UIStyle.menu_button(column, "Settings").pressed.connect(func() -> void:
		open_settings.emit()
		queue_free())
	var dev_title := UIStyle.label(column, "Dev tools", 16, true)
	dev_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var dev := HBoxContainer.new()
	dev.alignment = BoxContainer.ALIGNMENT_CENTER
	dev.add_theme_constant_override("separation", 10)
	column.add_child(dev)
	UIStyle.button(dev, "Time +", Vector2(140, 44), 18).pressed.connect(func() -> void: day_night.skip(0.125))
	UIStyle.button(dev, "Swap look", Vector2(140, 44), 18).pressed.connect(func() -> void: character.next_look())


func _close() -> void:
	closed.emit()
	queue_free()
