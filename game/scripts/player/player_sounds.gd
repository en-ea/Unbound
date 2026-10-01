extends AudioStreamPlayer3D
## Footsteps that match the ground (grass, the dirt path, water) and the dodge roll's own sound.
## Each footfall also kicks up a little puff at your feet (player_effects.gd).

const DIR := "res://assets/sounds/"
const KENNEY := "res://assets/kenney_impact/"

var shape: WorldShape        # set by main
var _sounds := {}
var _phase := 0.5          # through the current step; footsteps follow the animation, not the distance
var _left := true
var _layer: AudioStreamPlayer3D     # the recorded grass rustle, quietly under our own steps
var _roll: AudioStreamPlayer3D

@onready var player: CharacterBody3D = get_parent()


func _ready() -> void:
	# Our own footsteps (tools-src/make_sounds.py): a soft heel thump plus a grass rustle or a
	# gravel crunch. The recorded Kenney grass steps play very quietly underneath for texture.
	for surface in ["grass", "dirt"]:
		_sounds[surface] = [] as Array[AudioStream]
		for i in 6:
			_sounds[surface].append(load(DIR + "step_%s_%d.wav" % [surface, i]))
	_sounds["kenney"] = [] as Array[AudioStream]
	for i in 5:
		_sounds["kenney"].append(load(KENNEY + "footstep_grass_%03d.ogg" % i))
	_sounds["water"] = [] as Array[AudioStream]
	for i in 3:
		_sounds["water"].append(load(DIR + "step_water_%d.wav" % i))
	unit_size = 6.0
	_layer = AudioStreamPlayer3D.new()
	_layer.unit_size = 6.0
	player.add_child.call_deferred(_layer)
	_roll = AudioStreamPlayer3D.new()
	_roll.unit_size = 7.0
	_roll.stream = load(DIR + "roll.wav")
	player.add_child.call_deferred(_roll)
	# Hear the world from the player, not from the high camera. It faces screen-up.
	var ears := AudioListener3D.new()
	ears.position = Vector3(0, 1.6, 0)
	player.add_child.call_deferred(ears)
	ears.make_current.call_deferred()


func play_roll() -> void:
	_roll.pitch_scale = randf_range(0.92, 1.08)
	_roll.volume_db = -3.0
	_roll.play()


func _physics_process(delta: float) -> void:
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	var rate: float = player.visual.step_rate()
	if speed < 0.3 or rate <= 0.0 or not player.is_on_floor() or player.is_rolling():
		_phase = 0.5 if not player.is_rolling() else _phase
		return
	_phase += rate * delta
	if _phase >= 1.0:
		_phase -= 1.0
		_step(speed)


func _step(speed: float) -> void:
	var pos := player.global_position
	var surface := "grass"
	if pos.y < -100.0:                      # indoors or the build lab: a wooden or stone floor
		surface = "floor"
	elif pos.y < WorldShape.WATER_Y - 0.05:
		surface = "water"
	elif shape and shape.path_distance(Vector2(pos.x, pos.z)) < 1.8:
		surface = "dirt"
	var running := speed > 3.0
	var soft: bool = player.sneaking     # crouched: slow, muffled heel-to-toe steps, barely a rustle
	_left = not _left
	stream = _sounds["dirt" if surface == "floor" else surface].pick_random()
	pitch_scale = randf_range(0.94, 1.06) * (1.03 if _left else 0.97) * (0.72 if surface == "floor" else 1.0)
	volume_db = (-5.0 if running else -10.0) - (4.0 if surface == "floor" else 0.0)
	if soft:
		pitch_scale *= 0.82
		volume_db = -24.0 - (4.0 if surface == "floor" else 0.0)
	play()
	if surface == "grass":
		_layer.stream = _sounds["kenney"].pick_random()
		_layer.pitch_scale = randf_range(0.95, 1.05) * (0.9 if soft else 1.0)
		_layer.volume_db = -30.0 if soft else (-16.0 if running else -21.0)
		_layer.play()
	if surface in ["grass", "dirt"] and not soft:
		get_parent().get_node("Effects").kick(surface, running, _left)
