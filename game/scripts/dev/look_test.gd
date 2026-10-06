extends Node
## Dev: --looktest=tomas,morrow. Stands the player in front of each named NPC in turn and saves a screenshot of
## them (user://looktest_<id>.png), then quits. For colour checks.

var ids: Array = []
var suffix := ""
var _t := 0.0
var _i := 0
var _placed := false


func _process(delta: float) -> void:
	_t += delta
	if _t < 4.0 or _i >= ids.size():
		if _i >= ids.size() and _t > 4.0:
			get_tree().quit()
		return
	var npc: Node3D = null
	for n in get_tree().get_nodes_in_group("interactable"):
		if n.get("_id") == ids[_i]:
			npc = n
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if npc == null:
		print("LOOKTEST no npc %s" % ids[_i])
		_i += 1
		return
	if not _placed:
		var fwd := Vector3(sin(npc.rotation.y), 0, cos(npc.rotation.y))
		var vis := npc.get("_visual") as Node3D
		if vis:
			fwd = Vector3(sin(vis.global_rotation.y), 0, cos(vis.global_rotation.y))
		var side := Vector3(fwd.z, 0, -fwd.x)
		player.global_position = npc.global_position + fwd * 1.6 + Vector3(0, 0.3, 0)
		player.get_node("Visual").visible = false
		npc.set_physics_process(false)
		npc.set_process(false)
		var look := npc.global_position - player.global_position
		get_tree().call_group("camera_rig", "_set_yaw", atan2(-look.x, -look.z))
		_placed = true
		_t = 2.5
		return
	if _t > 4.0:
		var img := get_viewport().get_texture().get_image()
		var path := "user://looktest_%s%s.png" % [ids[_i], suffix]
		img.save_png(path)
		print("LOOKTEST saved %s" % ProjectSettings.globalize_path(path))
		_i += 1
		_placed = false
		_t = 3.0
