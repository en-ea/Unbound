extends Node
## Sword fighting: finds an enemy in reach and, on the action button, swings a 3-hit combo
## (Quaternius UAL2 sword animations). The hit lands mid-swing with a freeze and a camera shake.

signal target_changed(verb: String)     # "Attack", or "" when no enemy is in reach

const REACH := 2.2
const COMBO := ["Sword_Regular_A", "Sword_Regular_B", "Sword_Regular_C"]
const SPEED := 1.25
const CHAIN_WINDOW := 0.45     # tap again within this long after a swing to continue the combo
const HIT_SOUNDS := "res://assets/kenney_impact/impactPunch_heavy_%03d.ogg"

@onready var player: CharacterBody3D = get_parent()
@onready var visual: CharacterVisual = get_parent().get_node("Visual")

var target: Node3D = null
var verb := ""
var _busy := 0.0
var _impact := -1.0
var _swing_target: Node3D = null
var _step := 0
var _since := 99.0
var _queued := false
var _audio: AudioStreamPlayer3D
var _hits: Array[AudioStream] = []
var _whoosh: AudioStream = preload("res://assets/sounds/swing.wav")


func _ready() -> void:
	_audio = AudioStreamPlayer3D.new()
	_audio.unit_size = 6.0
	player.add_child.call_deferred(_audio)
	for i in 5:
		_hits.append(load(HIT_SOUNDS % i))


func is_busy() -> bool:
	return _busy > 0.0


func _physics_process(delta: float) -> void:
	_since += delta
	if _busy > 0.0:
		_busy -= delta
		if _busy <= 0.0:
			if _queued:
				_queued = false
				attack()
			if _busy <= 0.0:
				visual.show_tool("")
	if _impact >= 0.0:
		_impact -= delta
		if _impact < 0.0:
			_land_hit()
	target = _nearest_enemy()
	var new_verb := "Attack" if target else ""
	if new_verb != verb:
		verb = new_verb
		target_changed.emit(verb)


## The action button near an enemy: one swing of the combo.
func attack() -> void:
	if _busy > 0.0:
		_queued = _busy < 0.25
		return
	if target == null:
		return
	_step = (_step + 1) % COMBO.size() if _since < CHAIN_WINDOW else 0
	var anim: String = COMBO[_step]
	var length := visual.animation_length(anim) / SPEED
	var to := target.global_position - player.global_position
	visual.rotation.y = atan2(to.x, to.z)
	visual.show_tool("sword")
	visual.play_action(anim, SPEED)
	_busy = length * 0.85
	_impact = length * 0.45
	_swing_target = target
	_since = -length * 0.85      # the chain window opens when this swing ends
	_audio.stream = _whoosh
	_audio.pitch_scale = randf_range(0.9, 1.15)
	_audio.play()


func _land_hit() -> void:
	var t := _swing_target
	if t == null or not is_instance_valid(t) or not t.is_alive():
		return
	if t.global_position.distance_to(player.global_position) > REACH + 0.8:
		return
	t.take_hit(player.global_position)
	visual.hit_stop(0.06)
	get_tree().call_group("camera_rig", "shake", 0.06)
	_audio.stream = _hits.pick_random()
	_audio.pitch_scale = randf_range(0.9, 1.05)
	_audio.play()


func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_d := REACH
	for e in get_tree().get_nodes_in_group("enemy"):
		if not e.is_alive():
			continue
		var d: float = (e as Node3D).global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best
