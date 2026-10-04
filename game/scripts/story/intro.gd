extends Node
## The story's opening (Story start on the title screen), played in the game itself:
## 1. The Long Night, told over black, then a slow flight over the sleeping meadow at night to the
##    standing stones on the hill, pulsing faintly.
## 2. Dawn: you wake in the grass by Wren's field. Wren gives you a chore: three wild tobacco leaves.
## 3. You play: pick them, bring them to her.
## 4. As she takes them the ground shakes, a hum rises and a column of light bursts from the stones.
##    Wren sends you up the hill, and the first quest (A Strange Hum) takes over.
## Cinematic parts have black bars, captions and a Skip button; the HUD is hidden while they play.

const CINZEL := preload("res://assets/fonts/Cinzel-Variable.ttf")
const ALMENDRA := preload("res://assets/fonts/Almendra-Regular.ttf")
const ALMENDRA_BOLD := preload("res://assets/fonts/Almendra-Bold.ttf")
const HUM := preload("res://assets/sounds/hum.wav")
const WAKE_SOUND := preload("res://assets/sounds/shrine_wake.wav")
const WAKE_AT := Vector2(-16.5, 33.5)       # where you nap, by the wild tobacco
const LEAVES := 3
const BAR := 86.0
const GLOW := Color(0.55, 0.9, 1.0)

var hud: CanvasLayer
var player: CharacterBody3D
var day_night: Node
var camera_rig: Node3D

var _layer: CanvasLayer
var _top: ColorRect
var _bottom: ColorRect
var _fade: ColorRect
var _caption: Label
var _speech: PanelContainer
var _speaker: Label
var _line: Label
var _more: Label
var _goal: Label
var _skip: Button
var _cam: Camera3D
var _shake := 0.0
var _skipping := false
var _tap := false
var _hill: Vector3
var _shape := WorldShape.new()
var _hum: AudioStreamPlayer
var _pulse: OmniLight3D


func _ready() -> void:
	_build_ui()
	_cam = Camera3D.new()
	_cam.fov = 50.0
	_cam.far = 400.0
	player.get_parent().add_child(_cam)
	var h := WorldShape.HILL_CENTER
	_hill = Vector3(h.x, _shape.height_at(h.x, h.y), h.y)
	_hum = AudioStreamPlayer.new()
	_hum.stream = HUM
	_hum.volume_db = -40.0
	add_child(_hum)
	_run()


func _run() -> void:
	var quest_guide := player.get_parent().get_node_or_null("QuestGuide")
	if quest_guide:
		quest_guide.visible = false
	hud._tracker.visible = false
	var landmark := player.get_parent().get_node_or_null("Landmark")      # its beam would give the ending away
	if landmark:
		landmark.visible = false
	await _opening()
	await _waking()
	await _chore()
	await _stones_wake()
	if landmark:
		landmark.visible = true
	if quest_guide:
		quest_guide.visible = true
	hud._tracker.visible = true
	queue_free()


# --- 1. The Long Night -----------------------------------------------------------------------------

func _opening() -> void:
	_fade.color.a = 1.0
	_cinema(true)
	day_night.set_time(0.97)
	_lay_down()
	_pulse = OmniLight3D.new()                # the stones, breathing faintly in the dark
	_pulse.light_color = GLOW
	_pulse.omni_range = 14.0
	player.get_parent().add_child(_pulse)
	_pulse.global_position = _hill + Vector3(0, 2.5, 0)
	await _caption_for("Long ago, the sun went out.", 2.6)
	await _caption_for("The old ones call it the Long Night.", 2.8)
	_fade_to(0.0, 2.0)
	_start_shot(Vector3(26, 26, 78), Vector3(0, 2, 22), Vector3(8, 16, 46), Vector3(-6, 2, 12), 8.0)
	await _caption_for("When the light came back, something stayed behind.", 3.4, 0.8)
	await _shot_done()
	_start_shot(Vector3(-2, 12, -8), _hill + Vector3(0, 1, 0), Vector3(-15, 7.5, -17), _hill + Vector3(0, 1.5, 0), 7.0)
	await _caption_for("Under the stones on the hill. Sleeping.", 3.2, 0.6)
	await _shot_done()
	await _caption_for("Until today.", 2.0)
	await _fade_to(1.0, 1.2)
	_skipping = false


# --- 2. Dawn by the tobacco ------------------------------------------------------------------------

func _waking() -> void:
	day_night.set_time(0.29)
	_pulse.queue_free()
	var at := _ground(WAKE_AT)
	_fade_to(0.0, 1.6)
	await _shot(at + Vector3(3.2, 1.0, 2.6), at + Vector3(0, 0.3, 0), at + Vector3(2.2, 1.6, 3.4), at + Vector3(0, 0.5, 0), 3.0)
	await _speak("Wren", "Oi! Sleeping in my leaf again?")
	player.visual.play_action("LayToIdle", 1.0)
	await _shot(at + Vector3(2.2, 1.6, 3.4), at + Vector3(0, 0.6, 0), at + Vector3(1.5, 2.0, 4.0), at + Vector3(0, 1.0, 0),
		player.visual.animation_length("LayToIdle"))
	await _speak("Wren", "The wild tobacco by the old tree's ready. Pick me three good leaves and I'll forget I saw you.")
	_skipping = false
	_cinema(false)


# --- 3. The chore ----------------------------------------------------------------------------------

func _chore() -> void:
	var start := Inventory.count("tobacco")
	_goal.visible = true
	while Inventory.count("tobacco") - start < LEAVES:
		_goal.text = "Pick wild tobacco  %d/%d" % [mini(Inventory.count("tobacco") - start, LEAVES), LEAVES]
		await get_tree().process_frame
	var wren := _wren()
	_goal.text = "Bring the leaves to Wren"
	get_tree().call_group("hud", "hint", "That's three. Back to Wren.")
	while wren and player.global_position.distance_to(wren.global_position) > 3.6:
		await get_tree().process_frame
	_goal.visible = false


# --- 4. The stones wake ----------------------------------------------------------------------------

func _stones_wake() -> void:
	var wren := _wren()
	var w: Vector3 = wren.global_position if wren else player.global_position + Vector3(1.5, 0, 0)
	_cinema(true)
	player.velocity = Vector3.ZERO
	var to_wren := w - player.global_position
	player.visual.rotation.y = atan2(to_wren.x, to_wren.z)
	Inventory.remove("tobacco", LEAVES)
	var side := (w - player.global_position).normalized().cross(Vector3.UP)
	var mid := (w + player.global_position) * 0.5
	await _shot(mid + side * 3.4 + Vector3(0, 1.8, 0), mid + Vector3(0, 1.2, 0), mid + side * 3.0 + Vector3(0, 1.6, 0), mid + Vector3(0, 1.3, 0), 1.2)
	await _speak("Wren", "Good leaves. You've got the knack, I'll give you th-")
	_hum.play()
	var t := 0.0
	while t < 1.6 and not _skipping:                     # the hum rises and the ground starts to shake
		t += get_process_delta_time()
		_hum.volume_db = lerpf(-30.0, -4.0, t / 1.6)
		_shake = t / 1.6 * 0.12
		await get_tree().process_frame
	# Cut to the hill: a column of light bursts out of the stones.
	var look_from := mid + Vector3(0, 5.0, 0) + (mid - _hill).normalized() * 6.0
	_cam.global_position = look_from
	_cam.look_at(_hill + Vector3(0, 6, 0))
	var beam := _beam()
	Music.sting(WAKE_SOUND, -1.0)
	_flash()
	_shake = 0.35
	var grow := 0.0
	while grow < 1.0 and not _skipping:
		grow = minf(grow + get_process_delta_time() / 1.4, 1.0)
		beam.scale = Vector3(lerpf(0.2, 1.0, grow), lerpf(0.05, 1.0, grow), lerpf(0.2, 1.0, grow))
		_shake = 0.35 * (1.0 - grow) + 0.05
		await get_tree().process_frame
	beam.scale = Vector3.ONE
	await _wait(1.6)
	_shake = 0.0
	_hum.volume_db = -14.0
	await _shot(mid + side * 3.0 + Vector3(0, 1.6, 0), mid + Vector3(0, 1.3, 0), mid - side * 2.6 + Vector3(0, 1.8, 0), _hill + Vector3(0, 6, 0), 2.0)
	await _speak("Wren", "...That's not the wind.")
	await _speak("Wren", "Those stones haven't made a sound since my gran was a girl.")
	await _speak("Wren", "Go on. Somebody ought to look. I'll mind the leaf.")
	_skipping = false
	_cinema(false)
	Banner.show_now(hud, "THE STONES ARE AWAKE", "Go to the standing stones on the hill", GLOW, null, 2.8)
	var fade_out := create_tween()
	fade_out.tween_interval(6.0)
	fade_out.tween_property(_hum, "volume_db", -60.0, 3.0)
	await fade_out.finished
	var shrink := beam.create_tween()
	shrink.tween_property(beam, "scale", Vector3(0.01, 1.0, 0.01), 2.5)
	shrink.tween_callback(beam.queue_free)


func _beam() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.2
	cyl.bottom_radius = 1.4
	cyl.height = 70.0
	cyl.radial_segments = 10
	cyl.rings = 1
	mi.mesh = cyl
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(GLOW, 0.55)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	player.get_parent().add_child(mi)
	mi.global_position = _hill + Vector3(0, 35.0, 0)
	var light := OmniLight3D.new()
	light.light_color = GLOW
	light.light_energy = 4.0
	light.omni_range = 30.0
	mi.add_child(light)
	light.position = Vector3(0, -32.0, 0)
	return mi


# --- the pieces ------------------------------------------------------------------------------------

## Cinematic mode: black bars, the HUD away, our camera; or back to play.
func _cinema(on: bool) -> void:
	hud.visible = not on
	Controls.locked = on
	_skip.visible = on
	if on:
		_cam.make_current()
	else:
		camera_rig.camera.make_current()
		camera_rig.snap()
	var t := create_tween().set_parallel()
	t.tween_property(_top, "offset_bottom", BAR if on else 0.0, 0.5)
	t.tween_property(_bottom, "offset_top", -BAR if on else 0.0, 0.5)


func _lay_down() -> void:
	var at := _ground(WAKE_AT)
	player.global_position = at + Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
	player.visual.rotation.y = 2.4
	player.visual.play_action("LayToIdle", 0.0001)


func _ground(p: Vector2) -> Vector3:
	return Vector3(p.x, _shape.height_at(p.x, p.y), p.y)


func _wren() -> Node3D:
	for n in get_tree().get_nodes_in_group("interactable"):
		if n.get("_id") == "wren":
			return n
	return null


func _wait(secs: float) -> void:
	var t := 0.0
	while t < secs and not _skipping:
		await get_tree().process_frame
		t += get_process_delta_time()


## The camera glides from one spot (looking at one point) to another, eased. _start_shot runs it in
## the background (while captions play); _shot waits for it.
var _sh := {}


func _start_shot(from: Vector3, look_from: Vector3, to: Vector3, look_to: Vector3, secs: float) -> void:
	_sh = {"from": from, "look_from": look_from, "to": to, "look_to": look_to, "secs": maxf(secs, 0.01), "t": 0.0}
	_cam.global_position = from
	_cam.look_at(look_from)


func _shot_done() -> void:
	while not _sh.is_empty() and _sh["t"] < _sh["secs"] and not _skipping:
		await get_tree().process_frame
	if not _sh.is_empty():
		_cam.global_position = _sh["to"]
		_cam.look_at(_sh["look_to"])
		_sh = {}


func _shot(from: Vector3, look_from: Vector3, to: Vector3, look_to: Vector3, secs: float) -> void:
	_start_shot(from, look_from, to, look_to, secs)
	await _shot_done()


func _fade_to(alpha: float, secs: float) -> void:
	var start := _fade.color.a
	var t := 0.0
	while t < secs and not _skipping:
		_fade.color.a = lerpf(start, alpha, t / secs)
		await get_tree().process_frame
		t += get_process_delta_time()
	_fade.color.a = alpha


## A line of the story across the screen: fades in, stays, fades out.
func _caption_for(text: String, secs: float, gap := 0.3) -> void:
	_caption.text = text
	var t := 0.0
	while t < secs + 1.2 and not _skipping:
		_caption.modulate.a = clampf(minf(t / 0.6, (secs + 1.2 - t) / 0.6), 0.0, 1.0)
		await get_tree().process_frame
		t += get_process_delta_time()
	_caption.modulate.a = 0.0
	await _wait(gap)


## Someone speaks: their name and the line typing out; tap to go on (or it goes on by itself).
func _speak(who: String, text: String) -> void:
	if _skipping:
		return
	_speech.visible = true
	_speaker.text = who
	_line.text = text
	_more.visible = false
	_tap = false
	var t := 0.0
	var typing := text.length() * 0.03
	while t < typing + 6.0 and not _skipping:
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


func _flash() -> void:
	var white := ColorRect.new()
	white.color = Color(0.9, 0.97, 1.0, 0.85)
	white.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(white)
	_layer.move_child(white, 0)
	var t := white.create_tween()
	t.tween_property(white, "color:a", 0.0, 0.9)
	t.tween_callback(white.queue_free)


func _process(delta: float) -> void:
	if not _sh.is_empty() and _sh["t"] < _sh["secs"]:
		_sh["t"] += delta
		var k := smoothstep(0.0, 1.0, _sh["t"] / _sh["secs"])
		_cam.global_position = (_sh["from"] as Vector3).lerp(_sh["to"], k)
		_cam.look_at((_sh["look_from"] as Vector3).lerp(_sh["look_to"], k))
	if _shake > 0.0 and _cam and _cam.current:
		_cam.h_offset = randf_range(-1.0, 1.0) * _shake
		_cam.v_offset = randf_range(-1.0, 1.0) * _shake
	elif _cam:
		_cam.h_offset = 0.0
		_cam.v_offset = 0.0


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
	_goal = Label.new()
	_goal.position = Vector2(64, 140)
	_goal.add_theme_font_override("font", ALMENDRA_BOLD)
	_goal.add_theme_font_size_override("font_size", 26)
	_goal.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5))
	_goal.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_goal.add_theme_constant_override("outline_size", 8)
	_goal.visible = false
	_layer.add_child(_goal)
	_skip = Button.new()
	_skip.text = "Skip ›"
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_skip.offset_left = -170
	_skip.offset_right = -60
	_skip.offset_top = 20
	_skip.offset_bottom = 64
	_skip.visible = false
	_skip.pressed.connect(func() -> void: _skipping = true)
	_layer.add_child(_skip)
