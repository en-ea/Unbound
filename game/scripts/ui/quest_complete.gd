extends Control
## The "Quest complete" moment: a banner drops in at the top with a fanfare and a burst of sparkles, then the
## rewards pop in one by one (coins, then each item with its picture). Set `quest` before adding it; it
## removes itself after a few seconds. (Quests.completed -> hud.show_quest_complete.)

const FANFARE := preload("res://assets/sounds/rare.wav")
const POP := preload("res://assets/sounds/pickup.wav")
const GOLD := Color(1.0, 0.82, 0.38)
const DISPLAY_FONT := preload("res://assets/fonts/Cinzel-Variable.ttf")
const TITLE_FONT := preload("res://assets/fonts/Almendra-Bold.ttf")

var quest := ""

var _chips: Array[Control] = []
var _audio: AudioStreamPlayer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var def: Dictionary = Quests.DEFS[quest]
	_audio = AudioStreamPlayer.new()
	add_child(_audio)
	var banner := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.06, 0.04, 0.93)
	box.set_corner_radius_all(24)
	box.border_color = GOLD
	box.set_border_width_all(3)
	box.shadow_color = Color(1.0, 0.8, 0.3, 0.35)
	box.shadow_size = 26
	box.content_margin_left = 44
	box.content_margin_right = 44
	box.content_margin_top = 16
	box.content_margin_bottom = 22
	banner.add_theme_stylebox_override("panel", box)
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.offset_top = 110
	add_child(banner)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	banner.add_child(column)
	var top := _label(column, "QUEST COMPLETE", 40, GOLD, DISPLAY_FONT)
	top.add_theme_color_override("font_outline_color", Color(0.35, 0.2, 0.0))
	top.add_theme_constant_override("outline_size", 8)
	_label(column, def["name"], 30, Color(1, 0.96, 0.85), TITLE_FONT)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	column.add_child(row)
	var reward: Dictionary = def["reward"]
	if reward.get("coins", 0) > 0:
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 8)
		UIStyle.coin(chip, 40)
		_label(chip, "+%d" % reward["coins"], 34, Color(1.0, 0.82, 0.35), TITLE_FONT)
		row.add_child(chip)
		_chips.append(chip)
	for item: String in reward.get("items", {}):
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 8)
		chip.add_child(preload("res://scripts/ui/inventory_panel.gd").item_icon(item, 56))
		_label(chip, "%s × %d" % [Items.name_of(item), reward["items"][item]], 26, Color(1, 0.96, 0.85), TITLE_FONT)
		row.add_child(chip)
		_chips.append(chip)
	for chip in _chips:
		chip.modulate.a = 0.0
	# Banner drops in with a bounce, sparkles burst from it, then the rewards pop in.
	banner.pivot_offset = Vector2(300, 60)
	banner.scale = Vector2(0.6, 0.6)
	banner.modulate.a = 0.0
	_play(FANFARE, -3.0)
	var t := create_tween()
	t.tween_property(banner, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(banner, "modulate:a", 1.0, 0.2)
	t.tween_callback(_sparkle)
	for i in _chips.size():
		t.tween_interval(0.4)
		t.tween_callback(_pop.bind(_chips[i]))
	t.tween_interval(3.2)
	t.tween_property(self, "modulate:a", 0.0, 0.6)
	t.tween_callback(queue_free)


func _label(parent: Node, text: String, size: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_override("font", font)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


func _pop(chip: Control) -> void:
	chip.pivot_offset = chip.size / 2.0
	chip.scale = Vector2(0.4, 0.4)
	chip.modulate.a = 1.0
	create_tween().tween_property(chip, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_play(POP, -6.0)


func _play(stream: AudioStream, db: float) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


## A burst of small gold sparks from the banner.
func _sparkle() -> void:
	for side in [-1.0, 1.0]:
		var p := CPUParticles2D.new()
		p.position = Vector2(get_viewport_rect().size.x / 2.0 + side * 250.0, 170.0)
		p.emitting = true
		p.one_shot = true
		p.amount = 34
		p.lifetime = 1.3
		p.explosiveness = 1.0
		p.direction = Vector2(side * 0.6, -1.0)
		p.spread = 55.0
		p.initial_velocity_min = 140.0
		p.initial_velocity_max = 380.0
		p.gravity = Vector2(0, 420)
		p.scale_amount_min = 4.0
		p.scale_amount_max = 9.0
		var fade := Gradient.new()
		fade.set_color(0, Color(1.0, 0.9, 0.5, 1.0))
		fade.set_color(1, Color(1.0, 0.6, 0.2, 0.0))
		p.color_ramp = fade
		add_child(p)
