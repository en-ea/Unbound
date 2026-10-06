extends Node
## A look at a spot for a look board (toolbox/lookboard): `--look-at=x,z[,distance,pitch,fov]` stands the player
## south of the spot, out of the way, and points the camera rig at it from above (as stuck_probe.gd's look does).
## The world goes on as ever; only the eye is placed. Made by session.gd when the argument is given.
const STAND := 14.0          # metres south of the spot the player stands

var _at := Vector2.ZERO
var _view := [26.0, -45.0, 40.0]
var _done := 0
var _after := INF            # --look-after=<game minutes>: the shot is taken this long after the scene's end (its
var _shot := ""              # deadline: a release, a fall), on the village's clock, whatever the frame rate (--shot=)
var _end := -1.0             # the scene's end, game minutes (found once the stage is up)
var _said_in := 0.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--look-at="):
			var v := arg.trim_prefix("--look-at=").split(",")
			_at = Vector2(float(v[0]), float(v[1]))
			for i in range(2, mini(v.size(), 5)):
				_view[i - 2] = float(v[i])
		elif arg.begins_with("--look-after="):
			_after = float(arg.trim_prefix("--look-after="))
		elif arg.begins_with("--shot="):
			_shot = arg.trim_prefix("--shot=")


func _process(_dt: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var rig := get_tree().current_scene.get_node_or_null("CameraRig") if get_tree().current_scene != null else null
	if player == null or rig == null:
		return
	var stand := _at + Vector2(0.0, STAND)
	if _done < 90:                            # (again for a while: the region's own start places him and the rig too)
		if _done < 3:
			player.global_position = Vector3(stand.x, player.global_position.y + 0.3, stand.y)
		rig.call("set_view", _view[0], _view[1], Vector3(_at.x - stand.x, 0.0, _at.y - stand.y), 0.01, _view[2])
		_done += 1
	if player.has_method("heal_full"):
		player.call("heal_full")              # (a wolf passing is the village's business, not a death for the look)
	var v = VillageSession.village
	if _after == INF or _shot == "" or v == null:
		return
	var live := get_tree().current_scene.get_node_or_null("VillageLive")
	if _end < 0.0 and live != null and int(live.get("_event")) >= 0:
		var e: Dictionary = VillageSession.Runtime.event_by_id(v, int(live.get("_event")))
		if not e.is_empty() and e.type != "incident":
			_end = float(e.deadline)
	_said_in -= _dt
	if _said_in <= 0.0:
		_said_in = 5.0                        # (a shot that never comes says why: the clock, the scene, what holds time)
		print("LOOK clock %.1f end %.1f event %s background %s locked %s fps %d" % [float(v.runtime.now) + float(v.runtime.fraction),
			_end, str(live.get("_event")) if live != null else "-", VillageSession.background, Controls.locked,
			Engine.get_frames_per_second()])
	if _end >= 0.0 and float(v.runtime.now) + float(v.runtime.fraction) >= _end + _after:
		get_viewport().get_texture().get_image().save_png(_shot)
		print("LOOK shot at %.1f game minutes after the end" % (float(v.runtime.now) + float(v.runtime.fraction) - _end))
		get_tree().quit()
