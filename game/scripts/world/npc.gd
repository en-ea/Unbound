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
var _clang: AudioStreamPlayer3D
var _marker_y := 2.9
var _shape: WorldShape
var _home := Vector2.ZERO
var _stop := 0                   # index of the route spot he is at or heading for
var _speed := 0.0                # eases in and out of walking
var _mode := "wait"              # "wait", "walk" or "work"
var _timer := 2.0

var _route: Array = []           # the round being walked (a resident's changes with the time of day)
var _still := false              # an indoor copy (world/visit_interior.gd): stands, turns, talks
var _act := ""                   # a resident's current activity (Residents.activity)
var _inside := false             # a resident who has gone indoors
var _body: StaticBody3D

const WALK_SPEED := 1.05
const TALK_RANGE := 3.4          # he stops what he is doing when you come this close


func setup(id: String, shape: WorldShape, fixed := Vector3.INF) -> void:
	_id = id
	_shape = shape
	_def = Npcs.get_def(id)
	add_to_group("interactable")
	var at: Vector2 = _def["at"]
	_home = at
	_route = _def.get("route", [])
	if fixed != Vector3.INF:
		_still = true
		global_position = fixed
	else:
		global_position = Vector3(at.x, shape.height_at(at.x, at.y), at.y)
	_visual = Npcs.make_visual(id)
	_visual.merge = true
	add_child(_visual)
	Npcs.dress_visual(id, _visual, false, true)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape3 := CylinderShape3D.new()
	shape3.radius = 0.4 * maxf(_def["scale"].x, 1.0)
	shape3.height = 1.8
	col.shape = shape3
	col.position = Vector3(0, 0.9, 0)
	body.add_child(col)
	add_child(body)
	_body = body
	for thing: Dictionary in _def.get("scenery", []):        # things that stand beside him (an anvil)
		var mesh := MeshInstance3D.new()
		mesh.mesh = Items.mesh(thing["model"])
		var spot: Vector2 = _home + thing["at"]
		mesh.top_level = true
		mesh.scale = Vector3.ONE * thing.get("scale", 1.0)
		mesh.position = Vector3(spot.x, shape.height_at(spot.x, spot.y), spot.y)
		mesh.rotation_degrees.y = thing.get("turn", 0.0)
		add_child(mesh)
		var block := StaticBody3D.new()
		var box_col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.9, 0.9, 0.5) * thing.get("scale", 1.0)
		box_col.shape = box
		box_col.position = Vector3(0, 0.45, 0)
		block.top_level = true
		block.position = mesh.position
		block.rotation_degrees.y = mesh.rotation_degrees.y
		block.add_child(box_col)
		add_child(block)
	if _def.has("work_sound"):
		_clang = AudioStreamPlayer3D.new()
		_clang.stream = load(_def["work_sound"])
		_clang.unit_size = 8.0
		_clang.max_distance = 30.0
		_clang.volume_db = -3.0
		add_child(_clang)
	_marker_y = 2.75 * _def["scale"].y
	_bubble = _label(44, 2.4 * _def["scale"].y)
	_marker = _label(80, _marker_y)
	_marker.modulate = Color(1.0, 0.85, 0.3)
	_marker.outline_modulate = Color(0.2, 0.12, 0.02)
	_marker.modulate.a = 0.0
	Quests.changed.connect(_update_marker)
	Quests.completed.connect(func(quest: String) -> void:      # a nod when you finish their quest
		if Quests.DEFS[quest]["giver"] == _id:
			_visual.play_action("Yes"))
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
	if _still:
		pass
	elif _def.has("resident"):
		_live(delta, busy)
	elif _def.has("route"):
		_go_about(delta, busy)
	var a := move_toward(_bubble.modulate.a, 1.0 if near else 0.0, delta * 4.0)
	_bubble.modulate.a = a
	_bubble.outline_modulate.a = a * 0.8
	var m := 1.0 if _marker.text != "" else 0.0
	_marker.modulate.a = move_toward(_marker.modulate.a, m, delta * 4.0)
	_marker.outline_modulate.a = _marker.modulate.a * 0.9
	_marker.position.y = _marker_y + sin(_time * 3.0) * 0.06


## His round: wait a moment, walk to the next spot, do his work there, and on. He stops and turns to you
## when you come close.
func _go_about(delta: float, busy: bool) -> void:
	if busy:
		if _mode != "wait":
			_visual.stop_action()
			_visual.set_two_hand(true)
			_mode = "wait"
			_timer = 1.5
		_speed = 0.0
		_visual.play_motion(0.0)
		return
	var route: Array = _route
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
					_speed = 0.0
					_timer = _visual.animation_length(work)
					_visual.set_two_hand(false)
					_visual.play_action(work)
					if _clang:                                   # the blow lands about half way through the swing
						get_tree().create_timer(_timer * 0.5).timeout.connect(func() -> void:
							if _mode == "work":
								_clang.play())
				return
			var dir := step.normalized()
			# Turn towards the next spot first, then ease into the walk and slow down on arrival.
			var facing := atan2(dir.x, dir.y)
			_visual.rotation.y = lerp_angle(_visual.rotation.y, facing, clampf(delta * 5.0, 0.0, 1.0))
			var top: float = _def.get("walk_speed", WALK_SPEED)
			var want := 0.0 if absf(angle_difference(_visual.rotation.y, facing)) > 0.7 else minf(top, 0.35 + step.length() * 1.5)
			_speed = move_toward(_speed, want, delta * 2.2)
			here += dir * minf(_speed * delta, step.length())
			global_position = Vector3(here.x, _shape.height_at(here.x, here.y), here.y)
			_visual.play_motion(_speed)
		"work":
			_timer -= delta
			if _timer <= 0.0:
				_mode = "wait"
				_timer = randf_range(2.0, 4.0)
				_visual.stop_action()
				_visual.set_two_hand(true)


## A resident's day (state/residents.gd): walk to where the time of day wants them (work, the green
## at noon, the fire in the evening, home at night), then go about their round there. At home they
## go in through their front door and are gone until morning (you'll find them inside).
func _live(delta: float, busy: bool) -> void:
	var act := Residents.activity(_id)
	if act != _act:
		_act = act
		if _inside and act != "home":                # morning: out of the door
			var d := Residents.door(_id)
			global_position = Vector3(d.x, _shape.height_at(d.x, d.y), d.y)
			_set_inside(false)
		_mode = "travel"
	if _inside:
		return
	if _mode == "travel":
		if busy and act != "home":
			_visual.play_motion(0.0)
			_speed = 0.0
			return
		var goal := Residents.anchor(_id, act)
		if _walk_to(goal, delta):
			if act == "home":
				_set_inside(true)
				return
			_home = goal
			_route = _def["route"] if act == "work" else [{"at": Vector2(0, 0), "work": ""}, {"at": Vector2(0.6, 0.4), "work": ""}]
			_stop = 0
			_mode = "wait"
			_timer = randf_range(0.5, 2.0)
		return
	_go_about(delta, busy)


## A step towards `goal`; true on arrival.
func _walk_to(goal: Vector2, delta: float) -> bool:
	var here := Vector2(global_position.x, global_position.z)
	var step := goal - here
	if step.length() < 0.15:
		_speed = 0.0
		_visual.play_motion(0.0)
		return true
	var dir := step.normalized()
	var facing := atan2(dir.x, dir.y)
	_visual.rotation.y = lerp_angle(_visual.rotation.y, facing, clampf(delta * 5.0, 0.0, 1.0))
	var top: float = _def.get("walk_speed", WALK_SPEED) * 1.25
	var want := 0.0 if absf(angle_difference(_visual.rotation.y, facing)) > 0.7 else minf(top, 0.35 + step.length() * 1.5)
	_speed = move_toward(_speed, want, delta * 2.2)
	here += dir * minf(_speed * delta, step.length())
	global_position = Vector3(here.x, _shape.height_at(here.x, here.y), here.y)
	_visual.play_motion(_speed)
	return false


func _set_inside(on: bool) -> void:
	_inside = on
	visible = not on
	if on:
		remove_from_group("interactable")
		_body.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		add_to_group("interactable")
		_body.process_mode = Node.PROCESS_MODE_INHERIT
