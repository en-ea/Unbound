extends Control
## The fishing screen (player/fisher.gd): the big button (Hook / Reel / Cast) where Attack sits, the
## line's tension on a bar beside it with the safe band in green, how close the fish is round the
## button's rim, a line of text, and a card for each catch. Stop ends it (so does walking away).

var fisher: Fisher

var _button: ActionButton
var _text: Label
var _card: PanelContainer
var _card_name: Label
var _card_size: Label
var _card_note: Label
var _card_icon: TextureRect
var _flash := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button = ActionButton.new()
	_button.id = "attack"
	_button.home_margin = Vector2(150, 150)
	_button.home_radius = 72.0
	_button.font_size = 26
	_button.meter_color = Color(0.5, 0.95, 0.5)
	add_child(_button)
	_button.place()
	_button.pressed.connect(func() -> void:
		fisher.reeling = true
		fisher.tap())
	_button.released.connect(func() -> void: fisher.reeling = false)
	_text = UIStyle.label(self, "", 26)
	_text.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.offset_top = -170
	_text.offset_bottom = -134
	_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	_text.add_theme_constant_override("outline_size", 8)
	var stop := UIStyle.button(self, "Stop fishing", Vector2(170, 50), 20)
	stop.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	stop.grow_horizontal = Control.GROW_DIRECTION_BOTH
	stop.offset_left = -85
	stop.offset_right = 85
	stop.offset_top = -74
	stop.offset_bottom = -24
	stop.pressed.connect(func() -> void: fisher.stop())
	_build_card()
	fisher.message.connect(func(t: String) -> void: _text.text = t)
	fisher.caught.connect(_show_catch)


func _build_card() -> void:
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", UIStyle.panel(18))
	_card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.position.y = 70
	_card.modulate.a = 0.0
	add_child(_card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_card.add_child(row)
	_card_icon = TextureRect.new()
	_card_icon.custom_minimum_size = Vector2(96, 96)
	_card_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_card_icon)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	_card_note = UIStyle.label(col, "", 18)
	_card_name = UIStyle.label(col, "", 30)
	_card_size = UIStyle.label(col, "", 20, true)


func _show_catch(id: String, size: int, note: String) -> void:
	var rarity: int = Items.DEFS[id]["rarity"]
	_card_icon.texture = ItemIcons.icon(id)
	_card_name.text = Items.name_of(id)
	_card_name.add_theme_color_override("font_color", Items.RARITY_COLORS[rarity] if rarity > 0 else Color(1, 0.97, 0.9))
	_card_size.text = "%d cm · %s" % [size, Items.RARITY_NAMES[rarity]] if id != "old_boot" else "Well, it's a boot"
	_card_note.text = {"first": "FIRST CATCH!", "record": "NEW RECORD!"}.get(note, "")
	_card_note.add_theme_color_override("font_color", Color(1.0, 0.82, 0.42))
	_card.modulate.a = 1.0
	_card.pivot_offset = _card.size / 2.0
	_card.scale = Vector2(0.8, 0.8)
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_card, "scale", Vector2.ONE, 0.25)
	t.tween_interval(2.6)
	t.tween_property(_card, "modulate:a", 0.0, 0.5)


func _process(delta: float) -> void:
	if fisher == null or not fisher.is_fishing():
		return
	_flash += delta
	var verb := ""
	match fisher.phase:
		Fisher.Phase.CASTING, Fisher.Phase.WAITING:
			verb = "Wait…"
			_button.dim = true
			_button.lit = false
		Fisher.Phase.BITE:
			verb = "HOOK!"
			_button.dim = false
			_button.lit = fmod(_flash, 0.2) < 0.1
			_button.lit_fill = Color(0.85, 0.55, 0.12, 0.9)
		Fisher.Phase.REEL:
			verb = "Reel"
			_button.dim = false
			_button.lit = fisher.reeling
			_button.lit_fill = Color(0.2, 0.45, 0.25, 0.85)
		Fisher.Phase.LANDED:
			verb = "Cast"
			_button.dim = false
			_button.lit = false
	if _button.verb != verb:
		_button.set_verb(verb)
	_button.set_meter(fisher.progress if fisher.phase == Fisher.Phase.REEL else 1.0)
	queue_redraw()


## The tension bar, left of the button: the green band to stay in, red at the top where it snaps.
func _draw() -> void:
	if fisher == null or fisher.phase != Fisher.Phase.REEL:
		return
	var c := _button.center()
	var h := 250.0
	var w := 26.0
	var rect := Rect2(c.x - _button.radius - 70.0, c.y - h * 0.62, w, h)
	draw_rect(rect.grow(4.0), Color(0.05, 0.06, 0.1, 0.7))
	draw_rect(rect, Color(0.18, 0.2, 0.26, 0.9))
	var y_of := func(v: float) -> float: return rect.end.y - v * h
	draw_rect(Rect2(rect.position.x, y_of.call(1.0), w, h * 0.1), Color(0.85, 0.2, 0.15, 0.85))
	var top: float = y_of.call(fisher.band.y)
	draw_rect(Rect2(rect.position.x, top, w, y_of.call(fisher.band.x) - top), Color(0.35, 0.85, 0.4, 0.8))
	var ty: float = y_of.call(clampf(fisher.tension, 0.0, 1.0))
	var inside := fisher.tension >= fisher.band.x and fisher.tension <= fisher.band.y
	var mark := Color(1, 1, 1) if inside else Color(1.0, 0.55, 0.3)
	draw_rect(Rect2(rect.position.x - 8.0, ty - 4.0, w + 16.0, 8.0), mark)
	var font := get_theme_default_font()
	draw_string(font, Vector2(rect.position.x - 6.0, rect.end.y + 26.0), "Line", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.97, 0.9, 0.85))
