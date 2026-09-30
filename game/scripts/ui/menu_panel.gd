extends Control
## The in-game menu (gear button): resume, save, change your look, settings, back to the title
## screen, and the dev tools.

signal closed
signal open_character
signal open_settings
signal open_class
signal open_quests
signal to_title

@export var day_night: Node
@export var character: CharacterVisual


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
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
	var save := UIStyle.menu_button(column, "Save")
	save.pressed.connect(func() -> void:
		SaveGame.save_game()
		save.text = "Saved")
	UIStyle.menu_button(column, "Quests").pressed.connect(func() -> void:
		open_quests.emit()
		queue_free())
	UIStyle.menu_button(column, "Character").pressed.connect(func() -> void:
		open_character.emit()
		queue_free())
	if Classes.awakened:
		var free := Classes.points_free()
		UIStyle.menu_button(column, "Class" + ("  (%d talent point%s)" % [free, "" if free == 1 else "s"] if free > 0 else "")).pressed.connect(func() -> void:
			open_class.emit()
			queue_free())
	UIStyle.menu_button(column, "Settings").pressed.connect(func() -> void:
		open_settings.emit()
		queue_free())
	var lab := get_tree().get_first_node_in_group("build_lab")
	if lab and lab.active:
		UIStyle.menu_button(column, "Leave build lab").pressed.connect(func() -> void:
			lab.leave()
			_close())
	UIStyle.menu_button(column, "Title screen").pressed.connect(func() -> void:
		to_title.emit()
		queue_free())
	var dev_title := UIStyle.label(column, "Dev tools", 16, true)
	dev_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var dev := HBoxContainer.new()
	dev.alignment = BoxContainer.ALIGNMENT_CENTER
	dev.add_theme_constant_override("separation", 10)
	column.add_child(dev)
	UIStyle.button(dev, "Time +", Vector2(140, 44), 18).pressed.connect(func() -> void: day_night.skip(0.125))
	# Wipes the save; asks for a second tap first.
	var wipe := UIStyle.button(dev, "Start over", Vector2(160, 44), 18)
	wipe.pressed.connect(func() -> void:
		if wipe.text == "Sure? Tap again":
			SaveGame.start_over()
		else:
			wipe.text = "Sure? Tap again")


func _close() -> void:
	closed.emit()
	queue_free()
