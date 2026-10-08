extends Node
## The story's opening (Story start on the title screen), played in the game itself:
## 1. Black, a heartbeat of light, one line: the sun went out. Then a low, fast flight over the sleeping
##    meadow at night to the standing stones on the hill, breathing light. "Until today." Cut to black.
## 2. Dawn: you wake in the grass by Wren's field. Wren gives you a chore: three wild tobacco leaves.
## 3. You play: pick them, bring them to her.
## 4. As she takes them the ground shakes, a hum rises and a column of light bursts from the stones.
##    Wren sends you up the hill, and the first quest (A Strange Hum) takes over; at the stones the
##    awakening set-piece plays (world/shrine.gd, story/awakening.gd).
## Cinematic parts use the film kit (story/cinema.gd): bars, captions, a Skip button (skips a beat).

const HUM := preload("res://assets/sounds/hum.wav")
const WAKE_SOUND := preload("res://assets/sounds/shrine_wake.wav")
const BOOM := preload("res://assets/sounds/tendril_burst.wav")
const WAKE_AT := Vector2(-16.5, 33.5)       # where you nap, by the wild tobacco
const LEAVES := 3
const GLOW := Color(0.55, 0.9, 1.0)
const BEAM_SHADER := preload("res://shaders/story_beam.gdshader")

var hud: CanvasLayer
var player: CharacterBody3D
var day_night: Node
var camera_rig: Node3D

var _film: StoryCinema
var _goal: Label
var _hill: Vector3
var _shape := WorldShape.new()
var _hum: AudioStreamPlayer
var _pulse: OmniLight3D
var _breathe := 0.0


func _ready() -> void:
	_film = StoryCinema.new()
	_film.hud = hud
	_film.player = player
	_film.camera_rig = camera_rig
	add_child(_film)
	_goal = Label.new()
	_goal.position = Vector2(64, 140)
	_goal.add_theme_font_override("font", StoryCinema.ALMENDRA_BOLD)
	_goal.add_theme_font_size_override("font_size", 26)
	_goal.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5))
	_goal.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_goal.add_theme_constant_override("outline_size", 8)
	_goal.visible = false
	_film.layer().add_child(_goal)
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
	Music.story = "none"
	await _opening()
	Music.story = ""
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
	_film.set_black(1.0)
	_film.bars(true)
	day_night.set_time(0.97)
	_lay_down()
	_pulse = OmniLight3D.new()                # the stones, breathing in the dark
	_pulse.light_color = GLOW
	_pulse.omni_range = 16.0
	_pulse.light_energy = 0.0
	player.get_parent().add_child(_pulse)
	_pulse.global_position = _hill + Vector3(0, 2.5, 0)
	_hum.play()
	_hum.volume_db = -26.0
	_breathe = 1.0
	await _film.caption("Long ago, the sun went out.", 2.4)
	# A low, fast flight over the sleeping meadow, towards the hill.
	_film.fade_to(0.0, 1.4)
	_film.start_shot(Vector3(30, 9, 70), Vector3(4, 3, 30), Vector3(-6, 6.5, 6), _hill + Vector3(0, 2, 0), 7.5, 58.0, 46.0)
	await _film.caption("When it came back, something stayed behind.", 3.6, 0.6)
	await _film.shot_done()
	# Close on the stones, the light breathing faster.
	_breathe = 2.2
	_film.start_shot(_hill + Vector3(14, 3.0, 13), _hill + Vector3(0, 1.8, 0), _hill + Vector3(8.5, 2.2, 7.5), _hill + Vector3(0, 2.2, 0), 5.0, 44.0, 34.0)
	_hum.volume_db = -16.0
	await _film.caption("Under the stones on the hill. Sleeping.", 2.8, 0.2)
	await _film.shot_done()
	# One hard beat: the light flares, the ground jolts, black.
	if not _film.skipping:
		Music.sting(BOOM, -4.0)
		_film.shake = 0.25
		_pulse.light_energy = 9.0
		await _film.wait(0.25)
	_film.shake = 0.0
	_film.set_black(1.0)
	_hum.stop()
	_breathe = 0.0
	await _film.caption("Until today.", 1.8)
	_film.skipping = false


func _process(_delta: float) -> void:
	if _breathe > 0.0 and is_instance_valid(_pulse):
		var beat := pow(maxf(sin(Time.get_ticks_msec() / 1000.0 * _breathe * 2.2), 0.0), 6.0)
		_pulse.light_energy = 0.4 + beat * 3.5


# --- 2. Dawn by the tobacco ------------------------------------------------------------------------

func _waking() -> void:
	day_night.set_time(0.29)
	if is_instance_valid(_pulse):
		_pulse.queue_free()
	var at := _ground(WAKE_AT)
	_film.fade_to(0.0, 1.4)
	await _film.shot(at + Vector3(3.2, 1.0, 2.6), at + Vector3(0, 0.3, 0), at + Vector3(2.2, 1.6, 3.4), at + Vector3(0, 0.5, 0), 2.4)
	await _film.speak("Wren", "Oi! Sleeping in my leaf again?")
	player.visual.play_action("LayToIdle", 1.0)
	await _film.shot(at + Vector3(2.2, 1.6, 3.4), at + Vector3(0, 0.6, 0), at + Vector3(1.5, 2.0, 4.0), at + Vector3(0, 1.0, 0),
		player.visual.animation_length("LayToIdle"))
	await _film.speak("Wren", "The wild tobacco by the old tree's ready. Pick me three good leaves and I'll forget I saw you.")
	_film.skipping = false
	_film.bars(false)


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
	_film.bars(true)
	player.velocity = Vector3.ZERO
	var to_wren := w - player.global_position
	player.visual.rotation.y = atan2(to_wren.x, to_wren.z)
	Inventory.remove("tobacco", LEAVES)
	var side := (w - player.global_position).normalized().cross(Vector3.UP)
	var mid := (w + player.global_position) * 0.5
	await _film.shot(mid + side * 3.4 + Vector3(0, 1.8, 0), mid + Vector3(0, 1.2, 0), mid + side * 3.0 + Vector3(0, 1.6, 0), mid + Vector3(0, 1.3, 0), 1.2)
	await _film.speak("Wren", "Good leaves. You've got the knack, I'll give you th-")
	_hum.play()
	var t := 0.0
	while t < 1.6 and not _film.skipping:                # the hum rises and the ground starts to shake
		t += get_process_delta_time()
		_hum.volume_db = lerpf(-30.0, -4.0, t / 1.6)
		_film.shake = t / 1.6 * 0.12
		await get_tree().process_frame
	# Cut to the hill: a column of light bursts out of the stones.
	var look_from := mid + Vector3(0, 5.0, 0) + (mid - _hill).normalized() * 6.0
	_film.cut(look_from, _hill + Vector3(0, 6, 0))
	var beam := _beam()
	Music.sting(WAKE_SOUND, -1.0)
	_film.flash()
	_film.shake = 0.35
	var grow := 0.0
	while grow < 1.0 and not _film.skipping:
		grow = minf(grow + get_process_delta_time() / 1.4, 1.0)
		beam.scale = Vector3(lerpf(0.2, 1.0, grow), lerpf(0.05, 1.0, grow), lerpf(0.2, 1.0, grow))
		_film.shake = 0.35 * (1.0 - grow) + 0.05
		await get_tree().process_frame
	beam.scale = Vector3.ONE
	await _film.wait(1.4)
	_film.shake = 0.0
	_hum.volume_db = -14.0
	await _film.shot(mid + side * 3.0 + Vector3(0, 1.6, 0), mid + Vector3(0, 1.3, 0), mid - side * 2.6 + Vector3(0, 1.8, 0), _hill + Vector3(0, 6, 0), 2.0)
	await _film.speak("Wren", "...That's not the wind. Those stones haven't made a sound since my gran was a girl.")
	await _film.speak("Wren", "Go on. Somebody ought to look. I'll mind the leaf.")
	_film.skipping = false
	_film.bars(false)
	Banner.show_now(hud, "THE STONES ARE AWAKE", "Go to the standing stones on the hill", GLOW, null, 2.8)
	var fade_out := create_tween()
	fade_out.tween_interval(6.0)
	fade_out.tween_property(_hum, "volume_db", -60.0, 3.0)
	await fade_out.finished
	var shrink := beam.create_tween()
	shrink.tween_property(beam, "scale", Vector3(0.01, 1.0, 0.01), 2.5)
	shrink.tween_callback(beam.queue_free)


## A column of light out of the stones: the soft beam shader, wide and tall, with a light at its foot.
func _beam() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.6
	cyl.bottom_radius = 1.6
	cyl.height = 70.0
	cyl.radial_segments = 16
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	mi.mesh = cyl
	var m := ShaderMaterial.new()
	m.shader = BEAM_SHADER
	m.set_shader_parameter("tint", Color(0.75, 0.95, 1.0))
	m.set_shader_parameter("strength", 1.6)
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
