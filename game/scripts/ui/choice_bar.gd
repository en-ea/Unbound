extends PanelContainer
## A small row of choices near the bottom of the screen for something you walked up to (a body: carve it,
## drag it, put it in the cart). The game keeps running; it closes when you pick, or walk away.

var source: Node3D
var player: Node3D
var title := ""
var options: Array = []          # [{label, hint, do: Callable (invalid = shown but can't be picked)}]


func _ready() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel(18))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	add_child(col)
	var t := UIStyle.label(col, title, 18)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	for o: Dictionary in options:
		var b := UIStyle.button(row, "", Vector2(165, 64), 19)
		b.text = "%s\n%s" % [o["label"], o["hint"]]
		b.add_theme_font_size_override("font_size", 17)
		var action: Callable = o["do"]
		b.disabled = not action.is_valid()
		b.pressed.connect(func() -> void:
			queue_free()
			if action.is_valid():
				action.call())
	var x := UIStyle.button(row, "×", Vector2(56, 64), 24)
	x.pressed.connect(queue_free)


func _process(_delta: float) -> void:
	var view := get_viewport().get_visible_rect().size          # bottom middle, above the joystick row
	position = Vector2(view.x * 0.44 - size.x * 0.5, view.y - size.y - 24.0)     # clear of the Roll button
	if not is_instance_valid(source) or not is_instance_valid(player) \
			or player.global_position.distance_to(source.global_position) > 4.5:
		queue_free()
