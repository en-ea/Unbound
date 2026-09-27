extends Node
## Background sound: wind and leaves by day, crickets by night, birds calling around the player
## (an owl at night), lapping water at the pond, and a low hum at the standing stones.

const DIR := "res://assets/sounds/"

@export var day_night: Node
@export var listener_target: Node3D
@export var landmark: Node3D

var _day: AudioStreamPlayer
var _night: AudioStreamPlayer
var _birds: Array[AudioStream] = []
var _bird_player: AudioStreamPlayer3D
var _bird_timer := 3.0
var _owl: AudioStream
var _owl_timer := 12.0


func _ready() -> void:
	_day = _loop_player("amb_day")
	_night = _loop_player("amb_night")
	for i in 6:
		_birds.append(load(DIR + "bird_%d.wav" % i))
	_owl = load(DIR + "owl.wav")
	var pond := AudioStreamPlayer3D.new()
	pond.stream = _looping(load(DIR + "amb_pond.wav"))
	pond.unit_size = 5.0
	pond.max_distance = 26.0
	pond.volume_db = -6.0
	pond.autoplay = true
	pond.position = Vector3(WorldShape.POND_CENTER.x, WorldShape.WATER_Y, WorldShape.POND_CENTER.y)
	add_child(pond)
	_bird_player = AudioStreamPlayer3D.new()
	_bird_player.unit_size = 12.0
	_bird_player.volume_db = -6.0
	add_child(_bird_player)
	var hum := AudioStreamPlayer3D.new()
	hum.stream = _looping(load(DIR + "hum.wav"))
	hum.unit_size = 4.0
	hum.max_distance = 22.0
	hum.volume_db = -4.0
	hum.autoplay = true
	landmark.add_child.call_deferred(hum)
	hum.position = Vector3(0, 1.5, 0)


func _process(delta: float) -> void:
	var night: float = day_night.night
	_day.volume_db = linear_to_db(lerpf(0.55, 0.12, night) + 0.0001)
	_night.volume_db = linear_to_db(lerpf(0.0, 0.5, night) + 0.0001)
	_bird_timer -= delta
	if _bird_timer <= 0.0:
		_bird_timer = randf_range(2.5, 7.0)
		if night < 0.3:
			var around := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * randf_range(6.0, 16.0)
			_bird_player.global_position = listener_target.global_position + around + Vector3(0, 5, 0)
			_bird_player.stream = _birds.pick_random()
			_bird_player.pitch_scale = randf_range(0.92, 1.1)
			_bird_player.volume_db = randf_range(-10.0, -4.0)
			_bird_player.play()
	_owl_timer -= delta
	if _owl_timer <= 0.0:
		_owl_timer = randf_range(15.0, 35.0)
		if night > 0.6:
			var far := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * 20.0
			_bird_player.global_position = listener_target.global_position + far + Vector3(0, 6, 0)
			_bird_player.stream = _owl
			_bird_player.pitch_scale = randf_range(0.95, 1.05)
			_bird_player.volume_db = -6.0
			_bird_player.play()


func _loop_player(sound: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = _looping(load(DIR + sound + ".wav"))
	p.volume_db = -80.0
	p.autoplay = true
	add_child(p)
	return p


func _looping(stream: AudioStreamWAV) -> AudioStreamWAV:
	var s := stream.duplicate() as AudioStreamWAV
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(s.get_length() * s.mix_rate)
	return s
