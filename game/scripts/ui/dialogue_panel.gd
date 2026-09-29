extends Control
## Talking to a villager: a card at the bottom of the screen with their name, what they say and the
## buttons to answer (from Quests.talk). Set `npc` before adding it. The words appear a few letters at
## a time; tapping the text shows it all.

signal closed

const CHARS_PER_SEC := 60.0

var npc := ""

var _name: Label
var _text: Label
var _buttons: HBoxContainer
var _shown := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var def := Npcs.get_def(npc)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.panel())
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = -400
	panel.offset_right = 400
	panel.offset_bottom = -24
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	column.add_child(head)
	_name = UIStyle.label(head, def["name"], 28)
	_name.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5))
	var title := UIStyle.label(head, def["title"], 17, true)
	title.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_text = UIStyle.label(column, "", 21)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(0, 96)
	_text.mouse_filter = Control.MOUSE_FILTER_STOP
	_text.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_shown = 9999.0)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 12)
	_buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(_buttons)
	_show(Quests.talk(npc))


func _show(screen: Dictionary) -> void:
	if screen.is_empty():
		closed.emit()
		queue_free()
		return
	_text.text = screen["text"]
	_text.visible_characters = 0
	_shown = 0.0
	for c in _buttons.get_children():
		c.queue_free()
	for o: Dictionary in screen["options"]:
		var b := UIStyle.button(_buttons, o["label"], Vector2(150, 52), 20)
		b.pressed.connect(func() -> void: _show(o["do"].call()))


func _process(delta: float) -> void:
	_shown += delta * CHARS_PER_SEC
	_text.visible_characters = int(_shown)
