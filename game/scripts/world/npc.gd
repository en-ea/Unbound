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


func setup(id: String, shape: WorldShape) -> void:
	_id = id
	_def = Npcs.get_def(id)
	add_to_group("interactable")
	var at: Vector2 = _def["at"]
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
	if near:
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(to.x, to.z), clampf(delta * 5.0, 0.0, 1.0))
		if not _greeted:
			_greeted = true
			_bubble.text = _def["greetings"].pick_random()
	elif to.length() > 6.0:
		_greeted = false
	var a := move_toward(_bubble.modulate.a, 1.0 if near else 0.0, delta * 4.0)
	_bubble.modulate.a = a
	_bubble.outline_modulate.a = a * 0.8
	var m := 1.0 if _marker.text != "" else 0.0
	_marker.modulate.a = move_toward(_marker.modulate.a, m, delta * 4.0)
	_marker.outline_modulate.a = _marker.modulate.a * 0.9
	_marker.position.y = 2.95 + sin(_time * 3.0) * 0.06
