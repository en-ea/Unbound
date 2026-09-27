extends AudioStreamPlayer3D
## Footsteps that match the ground: grass, the dirt path, or water.

const DIR := "res://assets/sounds/"
const WALK_STRIDE := 0.7     # metres between steps
const RUN_STRIDE := 1.45

var shape: WorldShape        # set by main
var _sounds := {}
var _travelled := 0.0

@onready var player: CharacterBody3D = get_parent()


func _ready() -> void:
	for surface in ["grass", "dirt"]:
		_sounds[surface] = [] as Array[AudioStream]
		for i in 4:
			_sounds[surface].append(load(DIR + "step_%s_%d.wav" % [surface, i]))
	_sounds["water"] = [] as Array[AudioStream]
	for i in 3:
		_sounds["water"].append(load(DIR + "step_water_%d.wav" % i))
	unit_size = 6.0
	volume_db = -4.0
	# Hear the world from the player, not from the high camera. It faces screen-up.
	var ears := AudioListener3D.new()
	ears.position = Vector3(0, 1.6, 0)
	player.add_child.call_deferred(ears)
	ears.make_current.call_deferred()


func _physics_process(delta: float) -> void:
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	if speed < 0.3 or not player.is_on_floor():
		_travelled = 0.0
		return
	_travelled += speed * delta
	var stride := RUN_STRIDE if speed > 3.0 else WALK_STRIDE
	if _travelled >= stride:
		_travelled -= stride
		_step(speed)


func _step(speed: float) -> void:
	var pos := player.global_position
	var surface := "grass"
	if pos.y < WorldShape.WATER_Y - 0.05:
		surface = "water"
	elif shape and shape.path_distance(Vector2(pos.x, pos.z)) < 1.8:
		surface = "dirt"
	stream = _sounds[surface].pick_random()
	pitch_scale = randf_range(0.9, 1.1)
	volume_db = -2.0 if speed > 3.0 else -7.0
	play()
