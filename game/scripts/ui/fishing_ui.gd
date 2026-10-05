extends Control
## The fishing screen (player/fisher.gd): the big button (Hook / Reel / Cast) where Attack sits; in the
## middle, how close the fish is and the line's tension (the safe band in green, a tip under it); a line
## of text, and a card for each catch. Stop ends it (so does walking away).

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
	_text.offset_top = -190
	_text.offset_bottom = -154
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
	_text.visible = fisher.phase != Fisher.Phase.REEL          # the bars say it all then
	queue_redraw()


## The fight, in the middle of the screen where your eyes are: how close the fish is (a fish swimming in
## to the shore), and the line's tension below it (keep the marker in the green; red is where it snaps).
## While the fish surges, the bar flashes orange: ease off. While waiting, a small reminder; on a bite,
## a big HOOK! over the water.
func _draw() -> void:
	if fisher == null:
		return
	var view := get_viewport_rect().size
	var font := get_theme_default_font()
	var mid := view.x * 0.5
	if fisher.phase == Fisher.Phase.BITE and fmod(_flash, 0.3) < 0.2:
		draw_string_outline(font, Vector2(mid - 160, view.y * 0.42), "HOOK!", HORIZONTAL_ALIGNMENT_CENTER, 320, 72, 14, Color(0, 0, 0, 0.7))
		draw_string(font, Vector2(mid - 160, view.y * 0.42), "HOOK!", HORIZONTAL_ALIGNMENT_CENTER, 320, 72, Color(1.0, 0.75, 0.25))
	if fisher.phase != Fisher.Phase.REEL:
		return
	var w := minf(520.0, view.x * 0.42)
	var x0 := mid - w * 0.5
	# How close the fish is: a track from the water (left) to you (right).
	var track := Rect2(x0, view.y - 300.0, w, 16.0)
	draw_rect(track.grow(4.0), Color(0.05, 0.06, 0.1, 0.65))
	draw_rect(track, Color(0.16, 0.24, 0.34, 0.9))
	draw_rect(Rect2(track.position, Vector2(w * fisher.progress, track.size.y)), Color(0.4, 0.75, 1.0).lerp(Color(1.0, 0.82, 0.35), fisher.progress))
	var fx := x0 + w * fisher.progress
	draw_circle(Vector2(fx, track.get_center().y), 13.0, Color(1, 0.97, 0.9))
	draw_circle(Vector2(fx + 4.0, track.get_center().y - 3.0), 2.5, Color(0.1, 0.1, 0.15))
	draw_colored_polygon(PackedVector2Array([Vector2(fx - 10, track.get_center().y), Vector2(fx - 22, track.get_center().y - 9),
		Vector2(fx - 22, track.get_center().y + 9)]), Color(1, 0.97, 0.9))
	draw_string(font, Vector2(x0, track.position.y - 12.0), "Fish", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.97, 0.9, 0.85))
	draw_string(font, Vector2(x0, track.position.y - 12.0), "You", HORIZONTAL_ALIGNMENT_RIGHT, w, 18, Color(1, 0.97, 0.9, 0.85))
	# The line's tension.
	var bar := Rect2(x0, view.y - 250.0, w, 30.0)
	var surge := fisher.surging()
	var edge := Color(1.0, 0.55, 0.2, 0.95) if surge and fmod(_flash, 0.24) < 0.14 else Color(0.05, 0.06, 0.1, 0.75)
	draw_rect(bar.grow(5.0), edge)
	draw_rect(bar, Color(0.18, 0.2, 0.26, 0.92))
	var x_of := func(v: float) -> float: return bar.position.x + clampf(v, 0.0, 1.0) * w
	draw_rect(Rect2(x_of.call(0.9), bar.position.y, w * 0.1, bar.size.y), Color(0.85, 0.2, 0.15, 0.9))
	var band_x: float = x_of.call(fisher.band.x)
	draw_rect(Rect2(band_x, bar.position.y, x_of.call(fisher.band.y) - band_x, bar.size.y), Color(0.35, 0.85, 0.4, 0.85))
	var inside := fisher.tension >= fisher.band.x and fisher.tension <= fisher.band.y
	var tx: float = x_of.call(fisher.tension)
	draw_rect(Rect2(tx - 4.0, bar.position.y - 8.0, 8.0, bar.size.y + 16.0), Color(1, 1, 1) if inside else Color(1.0, 0.55, 0.3))
	draw_string(font, Vector2(x0, bar.end.y + 22.0), "slack", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.97, 0.9, 0.6))
	draw_string(font, Vector2(x0, bar.end.y + 22.0), "snaps", HORIZONTAL_ALIGNMENT_RIGHT, w, 16, Color(1.0, 0.6, 0.5, 0.8))
	var tip := "It's pulling! Ease off" if surge else ("Hold Reel" if fisher.tension < fisher.band.x else ("Let go a little" if not inside else "Good, keep it there"))
	draw_string(font, Vector2(x0, bar.end.y + 22.0), tip, HORIZONTAL_ALIGNMENT_CENTER, w, 18,
		Color(1.0, 0.7, 0.35) if surge else (Color(0.72, 1.0, 0.66) if inside else Color(1, 0.97, 0.9)))
