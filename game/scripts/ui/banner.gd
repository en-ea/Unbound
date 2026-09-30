class_name Banner
extends Control
## A big moment across the top of the screen: a title in Cinzel, a line under it, a sound and a burst of
## sparks, then it fades. Level-ups, a class awakening, a target taken down, being spotted.
## Banner.show_now(parent, "LEVEL UP", "Combat 12", Color.GOLD, sound)

const DISPLAY_FONT := preload("res://assets/fonts/Cinzel-Variable.ttf")
const TITLE_FONT := preload("res://assets/fonts/Almendra-Bold.ttf")

var title := ""
var subtitle := ""
var color := Color(1.0, 0.82, 0.38)
var sound: AudioStream
var hold := 2.2
var top := 110.0

static var _current: Banner


static func show_now(parent: Node, title_text: String, sub: String, tint: Color, stream: AudioStream = null, seconds := 2.2) -> void:
	if is_instance_valid(_current):
		_current.queue_free()
	var b := Banner.new()
	b.title = title_text
	b.subtitle = sub
	b.color = tint
	b.sound = stream
	b.hold = seconds
	parent.add_child(b)
	_current = b


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var banner := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.05, 0.06, 0.9)
	box.set_corner_radius_all(24)
	box.border_color = color
	box.set_border_width_all(3)
	box.shadow_color = Color(color, 0.35)
	box.shadow_size = 26
	box.content_margin_left = 48
	box.content_margin_right = 48
	box.content_margin_top = 14
	box.content_margin_bottom = 18
	banner.add_theme_stylebox_override("panel", box)
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.offset_top = top
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	banner.add_child(column)
	if title != "":
		var t := _label(column, title, 40, color, DISPLAY_FONT)
		t.add_theme_color_override("font_outline_color", Color(color.darkened(0.75), 1.0))
		t.add_theme_constant_override("outline_size", 8)
	if subtitle != "":
		_label(column, subtitle, 28, Color(1, 0.96, 0.88), TITLE_FONT)
	if sound:
		var p := AudioStreamPlayer.new()
		p.stream = sound
		p.volume_db = -3.0
		add_child(p)
		p.play()
	banner.modulate.a = 0.0
	banner.scale = Vector2(0.6, 0.6)
	await get_tree().process_frame
	banner.pivot_offset = banner.size / 2.0
	var tw := create_tween()
	tw.tween_property(banner, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(banner, "modulate:a", 1.0, 0.18)
	tw.tween_callback(_sparkle.bind(banner))
	tw.tween_interval(hold)
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)


func _label(parent: Node, text: String, size: int, tint: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", tint)
	l.add_theme_font_override("font", font)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


func _sparkle(banner: Control) -> void:
	for side in [-1.0, 1.0]:
		var p := CPUParticles2D.new()
		p.position = Vector2(banner.position.x + banner.size.x * (0.5 + side * 0.45), banner.position.y + banner.size.y * 0.5)
		p.emitting = true
		p.one_shot = true
		p.amount = 28
		p.lifetime = 1.1
		p.explosiveness = 1.0
		p.direction = Vector2(side * 0.6, -1.0)
		p.spread = 55.0
		p.initial_velocity_min = 120.0
		p.initial_velocity_max = 340.0
		p.gravity = Vector2(0, 420)
		p.scale_amount_min = 4.0
		p.scale_amount_max = 8.0
		var fade := Gradient.new()
		fade.set_color(0, Color(color.lightened(0.3), 1.0))
		fade.set_color(1, Color(color, 0.0))
		p.color_ramp = fade
		add_child(p)
