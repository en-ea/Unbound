class_name StoryCinema
extends Node
## The story's film kit, shared by the opening (story/intro.gd) and the awakening (story/awakening.gd):
## black bars, a story camera that glides between shots and shakes, captions, a big spoken word, a talk
## box, a white flash, the title card, and a Skip button. The HUD is hidden while the bars are up.
## `skipping` turns true when Skip is pressed: every wait below then returns at once, and the scene using
## this decides what a skip means (the opening skips a beat, the awakening jumps to its end).

signal skipped

const CINZEL := preload("res://assets/fonts/Cinzel-Variable.ttf")
const ALMENDRA := preload("res://assets/fonts/Almendra-Regular.ttf")
const ALMENDRA_BOLD := preload("res://assets/fonts/Almendra-Bold.ttf")
const BAR := 86.0

var hud: CanvasLayer
var player: CharacterBody3D
var camera_rig: Node3D

var cam: Camera3D
var shake := 0.0
var skipping := false
var on := false

var _layer: CanvasLayer
var _top: ColorRect
var _bottom: ColorRect
var _fade: ColorRect
var _caption: Label
var _word: Label
var _speech: PanelContainer
var _speaker: Label
var _line: Label
var _more: Label
var _skip: Button
var _tap := false
var _sh := {}


func _ready() -> void:
	_build_ui()
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.far = 400.0
	player.get_parent().add_child(cam)


func _exit_tree() -> void:
	if is_instance_valid(cam):
		cam.queue_free()


## Cinematic mode: bars, the HUD away, the story camera; or back to play (the follow camera snaps to you).
func bars(show: bool, lock := true) -> void:
	on = show
	hud.visible = not show
	Controls.locked = show and lock
	_skip.visible = show
	if show:
		cam.make_current()
	else:
		camera_rig.camera.make_current()
		camera_rig.snap()
	var t := create_tween().set_parallel()
	t.tween_property(_top, "offset_bottom", BAR if show else 0.0, 0.5)
	t.tween_property(_bottom, "offset_top", -BAR if show else 0.0, 0.5)


## Skip stays on screen without the bars too (during the fight).
func show_skip(show: bool) -> void:
	_skip.visible = show


func wait(secs: float) -> void:
	var t := 0.0
	while t < secs and not skipping:
		await get_tree().process_frame
		t += get_process_delta_time()


## The camera glides from one spot (looking at one point) to another, eased. start_shot runs it in the
## background (while captions play); shot waits for it.
func start_shot(from: Vector3, look_from: Vector3, to: Vector3, look_to: Vector3, secs: float, fov_from := -1.0, fov_to := -1.0) -> void:
	_sh = {"from": from, "look_from": look_from, "to": to, "look_to": look_to, "secs": maxf(secs, 0.01), "t": 0.0,
		"fov_from": fov_from if fov_from > 0.0 else cam.fov, "fov_to": fov_to if fov_to > 0.0 else (fov_from if fov_from > 0.0 else cam.fov)}
	cam.fov = _sh["fov_from"]
	cam.global_position = from
	_look(look_from)


func shot_done() -> void:
	while not _sh.is_empty() and _sh["t"] < _sh["secs"] and not skipping:
		await get_tree().process_frame
	if not _sh.is_empty():
		cam.global_position = _sh["to"]
		_look(_sh["look_to"])
		cam.fov = _sh["fov_to"]
		_sh = {}


func shot(from: Vector3, look_from: Vector3, to: Vector3, look_to: Vector3, secs: float, fov_from := -1.0, fov_to := -1.0) -> void:
	start_shot(from, look_from, to, look_to, secs, fov_from, fov_to)
	await shot_done()


## A still frame (the camera holds).
func cut(at: Vector3, look: Vector3, fov := -1.0) -> void:
	_sh = {}
	if fov > 0.0:
		cam.fov = fov
	cam.global_position = at
	_look(look)


func _look(at: Vector3) -> void:
	if not at.is_equal_approx(cam.global_position):
		var up := Vector3.UP if absf((at - cam.global_position).normalized().y) < 0.98 else Vector3.FORWARD
		cam.look_at(at, up)


func fade_to(alpha: float, secs: float, color := Color.BLACK) -> void:
	_fade.color = Color(color, _fade.color.a)
	var start := _fade.color.a
	var t := 0.0
	while t < secs and not skipping:
		_fade.color.a = lerpf(start, alpha, t / secs)
		await get_tree().process_frame
		t += get_process_delta_time()
	_fade.color.a = alpha


func set_black(alpha: float) -> void:
	_fade.color = Color(0, 0, 0, alpha)


## A line of the story across the screen: fades in, stays, fades out.
func caption(text: String, secs: float, gap := 0.3) -> void:
	_caption.text = text
	var t := 0.0
	while t < secs + 1.2 and not skipping:
		_caption.modulate.a = clampf(minf(t / 0.6, (secs + 1.2 - t) / 0.6), 0.0, 1.0)
		await get_tree().process_frame
		t += get_process_delta_time()
	_caption.modulate.a = 0.0
	await wait(gap)


## Something enormous speaks: one word, huge and red, the screen trembling.
func word(text: String, secs: float, tint := Color(1.0, 0.36, 0.24)) -> void:
	_word.text = text
	_word.add_theme_color_override("font_color", tint)
	_word.pivot_offset = _word.size / 2.0
	var t := 0.0
	while t < secs and not skipping:
		var k := t / secs
		_word.modulate.a = clampf(minf(t / 0.35, (secs - t) / 0.8), 0.0, 1.0)
		_word.scale = Vector2.ONE * lerpf(1.18, 1.0, sqrt(k))
		await get_tree().process_frame
		t += get_process_delta_time()
	_word.modulate.a = 0.0


## Someone speaks: their name and the line typing out; tap to go on (or it goes on by itself).
func speak(who: String, text: String) -> void:
	if skipping:
		return
	_speech.visible = true
	_speaker.text = who
	_line.text = text
	_more.visible = false
	_tap = false
	var t := 0.0
	var typing := text.length() * 0.03
	while t < typing + 5.0 and not skipping:
		_line.visible_ratio = clampf(t / typing, 0.0, 1.0)
		_more.visible = t >= typing
		if _tap:
			_tap = false
			if t < typing:
				t = typing
			else:
				break
		await get_tree().process_frame
		t += get_process_delta_time()
	_speech.visible = false


func flash(color := Color(0.9, 0.97, 1.0, 0.85), secs := 0.9) -> void:
	var white := ColorRect.new()
	white.color = color
	white.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(white)
	_layer.move_child(white, 1)
	var t := white.create_tween()
	t.tween_property(white, "color:a", 0.0, secs)
	t.tween_callback(white.queue_free)


## The title card: the name of the game, huge, with a line under it. Holds, then fades (or on Skip).
func title_card(title: String, line: String, secs := 5.0) -> void:
	var card := Control.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(card)
	_layer.move_child(card, _layer.get_child_count() - 2)          # under the Skip button
	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0, 0, 0, 0.35)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vignette)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)
	var font := FontVariation.new()
	font.base_font = CINZEL
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800}
	font.spacing_glyph = 46
	var big := Label.new()
	big.text = title
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.add_theme_font_override("font", font)
	big.add_theme_font_size_override("font_size", 132)
	big.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82))
	big.add_theme_color_override("font_shadow_color", Color(1.0, 0.72, 0.3, 0.55))
	big.add_theme_constant_override("shadow_outline_size", 28)
	big.add_theme_constant_override("shadow_offset_x", 0)
	big.add_theme_constant_override("shadow_offset_y", 0)
	big.add_theme_color_override("font_outline_color", Color(0.22, 0.12, 0.04, 0.9))
	big.add_theme_constant_override("outline_size", 6)
	col.add_child(big)
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 2)
	rule.color = Color(1.0, 0.82, 0.45, 0.85)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(rule)
	var under := Label.new()
	under.text = line
	under.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	under.add_theme_font_override("font", ALMENDRA)
	under.add_theme_font_size_override("font_size", 34)
	under.add_theme_color_override("font_color", Color(1.0, 0.93, 0.8))
	under.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	under.add_theme_constant_override("outline_size", 8)
	col.add_child(under)
	card.modulate.a = 0.0
	under.modulate.a = 0.0
	var tw := card.create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(font, "spacing_glyph", 18, 3.2).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(rule, "custom_minimum_size:x", 560.0, 1.6).set_delay(0.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(under, "modulate:a", 1.0, 1.0).set_delay(1.3)
	await wait(secs)
	var out := card.create_tween()
	out.tween_property(card, "modulate:a", 0.0, 0.3 if skipping else 1.2)
	out.tween_callback(card.queue_free)
	if not skipping:
		await out.finished


func _process(delta: float) -> void:
	if not _sh.is_empty() and _sh["t"] < _sh["secs"]:
		_sh["t"] += delta
		var k := smoothstep(0.0, 1.0, _sh["t"] / _sh["secs"])
		cam.global_position = (_sh["from"] as Vector3).lerp(_sh["to"], k)
		_look((_sh["look_from"] as Vector3).lerp(_sh["look_to"], k))
		cam.fov = lerpf(_sh["fov_from"], _sh["fov_to"], k)
	if shake > 0.0 and cam and cam.current:
		cam.h_offset = randf_range(-1.0, 1.0) * shake
		cam.v_offset = randf_range(-1.0, 1.0) * shake
	elif cam:
		cam.h_offset = 0.0
		cam.v_offset = 0.0


func _input(event: InputEvent) -> void:
	if _speech and _speech.visible and (event is InputEventScreenTouch and event.pressed or event is InputEventMouseButton and event.pressed):
		_tap = true


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 40
	add_child(_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_fade)
	_top = ColorRect.new()
	_top.color = Color.BLACK
	_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_top.offset_bottom = 0.0
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_top)
	_bottom = ColorRect.new()
	_bottom.color = Color.BLACK
	_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom.offset_top = 0.0
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_bottom)
	_caption = Label.new()
	_caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.add_theme_font_override("font", CINZEL)
	_caption.add_theme_font_size_override("font_size", 38)
	_caption.add_theme_color_override("font_color", Color(0.95, 0.92, 0.84))
	_caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_caption.add_theme_constant_override("outline_size", 10)
	_caption.modulate.a = 0.0
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_caption)
	_word = Label.new()
	_word.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var heavy := FontVariation.new()
	heavy.base_font = CINZEL
	heavy.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 900}
	heavy.spacing_glyph = 10
	_word.add_theme_font_override("font", heavy)
	_word.add_theme_font_size_override("font_size", 96)
	_word.add_theme_color_override("font_outline_color", Color(0.06, 0.0, 0.02, 0.95))
	_word.add_theme_constant_override("outline_size", 18)
	_word.add_theme_color_override("font_shadow_color", Color(0.9, 0.15, 0.1, 0.45))
	_word.add_theme_constant_override("shadow_outline_size", 30)
	_word.add_theme_constant_override("shadow_offset_x", 0)
	_word.add_theme_constant_override("shadow_offset_y", 0)
	_word.modulate.a = 0.0
	_word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_word)
	_speech = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.11, 0.07, 0.92)
	box.border_color = Color(0.96, 0.74, 0.32, 0.8)
	box.set_border_width_all(2)
	box.set_corner_radius_all(14)
	box.set_content_margin_all(18)
	_speech.add_theme_stylebox_override("panel", box)
	_speech.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_speech.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_speech.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_speech.offset_bottom = -BAR - 14.0
	_speech.offset_left = -360
	_speech.offset_right = 360
	_speech.visible = false
	_layer.add_child(_speech)
	var col := VBoxContainer.new()
	_speech.add_child(col)
	_speaker = Label.new()
	_speaker.add_theme_font_override("font", ALMENDRA_BOLD)
	_speaker.add_theme_font_size_override("font_size", 26)
	_speaker.add_theme_color_override("font_color", Color(0.96, 0.74, 0.32))
	col.add_child(_speaker)
	_line = Label.new()
	_line.add_theme_font_override("font", ALMENDRA)
	_line.add_theme_font_size_override("font_size", 26)
	_line.add_theme_color_override("font_color", Color(1.0, 0.96, 0.84))
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size.x = 680
	col.add_child(_line)
	_more = Label.new()
	_more.text = "tap ›"
	_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_more.add_theme_font_size_override("font_size", 16)
	_more.modulate.a = 0.7
	col.add_child(_more)
	_skip = Button.new()
	_skip.text = "Skip ›"
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_skip.offset_left = -170
	_skip.offset_right = -60
	_skip.offset_top = 20
	_skip.offset_bottom = 64
	_skip.visible = false
	_skip.pressed.connect(func() -> void:
		skipping = true
		skipped.emit())
	_layer.add_child(_skip)


## The layer, for a scene's own pieces (the goal line, the power prompt).
func layer() -> CanvasLayer:
	return _layer
