extends Node3D
## A villager (see state/npcs.gd): built from their look, turns to face you when you come close, says a
## short line above their head, and shows a marker: "!" if they have a quest for you, "?" if one is
## ready to hand in. It is an "interactable", so the action button says "Talk" when you are in reach.

var verb := "Talk"
var reach := 2.6

var _id := ""
var _visual: CharacterVisual
var _bubble: Label3D
var _marker: Label3D
var _def: Dictionary
var _greeted := false
var _time := 0.0
var _shape: WorldShape
var _home := Vector2.ZERO
var _stop := 0                   # index of the route spot he is at or heading for
var _mode := "wait"              # "wait", "walk" or "work"
var _timer := 2.0

const WALK_SPEED := 1.05
const TALK_RANGE := 3.4          # he stops what he is doing when you come this close


func setup(id: String, shape: WorldShape) -> void:
	_id = id
	_shape = shape
	_def = Npcs.get_def(id)
	add_to_group("interactable")
	var at: Vector2 = _def["at"]
	_home = at
	global_position = Vector3(at.x, shape.height_at(at.x, at.y), at.y)
	_visual = CharacterVisual.new()
	var look := CharacterLook.new()
	for slot: String in _def["look"]["parts"]:
		look.parts[slot] = _def["look"]["parts"][slot]
	for slot: String in _def["look"]["colors"]:
		look.colors[slot] = _def["look"]["colors"][slot]
	_visual.hero_look = look
	_visual.is_player_look = false
	add_child(_visual)
	_visual.scale = _def["scale"]
	if _def.has("prop"):
		_visual.hold_prop.call_deferred(_def["prop"], Vector3(0, 0, 0), Vector3(0, 0.05, 0.0))
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape3 := CylinderShape3D.new()
	shape3.radius = 0.4
	shape3.height = 1.8
	col.shape = shape3
	col.position = Vector3(0, 0.9, 0)
	body.add_child(col)
	add_child(body)
	_bubble = _label(44, 2.55)
	_marker = _label(80, 2.95)
	_marker.modulate = Color(1.0, 0.85, 0.3)
	_marker.outline_modulate = Color(0.2, 0.12, 0.02)
	_marker.modulate.a = 0.0
	Quests.changed.connect(_update_marker)
	_update_marker()


func interact() -> void:
	get_tree().call_group("hud", "open_dialogue", _id)


func _label(size: int, height: float) -> Label3D:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = size
	l.outline_size = 14
	l.pixel_size = 0.005
	l.modulate = Color(1, 0.97, 0.88, 0.0)
	l.outline_modulate = Color(0.08, 0.06, 0.1, 0.0)
	l.position = Vector3(0, height, 0)
	add_child(l)
	return l


func _update_marker() -> void:
	_marker.text = Quests.marker(_id)


func _process(delta: float) -> void:
	_time += delta
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var to := player.global_position - global_position
	to.y = 0.0
	var near := to.length() < 4.0
	var busy := to.length() < TALK_RANGE or Controls.locked      # you are close, or in a menu
	if near:
		if busy:
			_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(to.x, to.z), clampf(delta * 5.0, 0.0, 1.0))
		if not _greeted:
			_greeted = true
			_bubble.text = _def["greetings"].pick_random()
	elif to.length() > 6.0:
		_greeted = false
	if _def.has("route"):
		_go_about(delta, busy)
	var a := move_toward(_bubble.modulate.a, 1.0 if near else 0.0, delta * 4.0)
	_bubble.modulate.a = a
	_bubble.outline_modulate.a = a * 0.8
	var m := 1.0 if _marker.text != "" else 0.0
	_marker.modulate.a = move_toward(_marker.modulate.a, m, delta * 4.0)
	_marker.outline_modulate.a = _marker.modulate.a * 0.9
	_marker.position.y = 2.95 + sin(_time * 3.0) * 0.06


## His round: wait a moment, walk to the next spot, do his work there, and on. He stops and turns to you
## when you come close.
func _go_about(delta: float, busy: bool) -> void:
	if busy:
		if _mode != "wait":
			_visual.stop_action()
			_mode = "wait"
			_timer = 1.5
		_visual.play_motion(0.0)
		return
	var route: Array = _def["route"]
	match _mode:
		"wait":
			_visual.play_motion(0.0)
			_timer -= delta
			if _timer <= 0.0:
				_stop = (_stop + 1) % route.size()
				_mode = "walk"
		"walk":
			var goal: Vector2 = _home + route[_stop]["at"]
			var here := Vector2(global_position.x, global_position.z)
			var step := goal - here
			if step.length() < 0.12:
				var work: String = route[_stop]["work"]
				if work == "":
					_mode = "wait"
					_timer = randf_range(2.0, 4.0)
					_visual.play_motion(0.0)
				else:
					_mode = "work"
					_timer = _visual.animation_length(work)
					_visual.play_action(work)
				return
			var dir := step.normalized()
			here += dir * minf(WALK_SPEED * delta, step.length())
			global_position = Vector3(here.x, _shape.height_at(here.x, here.y), here.y)
			_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(dir.x, dir.y), clampf(delta * 6.0, 0.0, 1.0))
			_visual.play_motion(WALK_SPEED)
		"work":
			_timer -= delta
			if _timer <= 0.0:
				_mode = "wait"
				_timer = randf_range(2.0, 4.0)
				_visual.stop_action()
