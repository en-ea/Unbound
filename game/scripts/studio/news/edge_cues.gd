extends Control
## Edge cues (plan VILLAGE-LIFE-AND-NEWS section 7): a sound out of view - raised voices, a fight, the bell - shows as
## a small arrow at the edge of the screen toward it, fading in a few seconds. It says "something is happening over
## there" without a word, and with the sound off (Hilmi plays without it). Generic: the source (the group "news")
## gives sounds() -> [{id, at: Vector2 on the ground, kind}]; the camera says where they are on screen.
const SHOW_FOR := 3.0           # seconds an arrow stays (fading)
const INSET := 46.0             # pixels in from the edge
const SIZE := 13.0

var _cues := {}                 # sound id -> {at, born, kind}
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	var source := get_tree().get_first_node_in_group("news")
	if source != null and source.has_method("sounds"):
		for s: Dictionary in source.sounds():
			if not _cues.has(int(s.id)):
				_cues[int(s.id)] = {"at": s.at, "born": _t, "kind": str(s.kind)}
	for id: int in _cues.keys():
		if _t - float(_cues[id].born) > SHOW_FOR:
			_cues.erase(id)
	if not _cues.is_empty() or _drawn:
		queue_redraw()


var _drawn := false


func _draw() -> void:
	_drawn = false
	var camera := get_viewport().get_camera_3d()
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if camera == null or player == null or not visible:
		return
	var rect := get_viewport_rect().grow(-INSET)
	var centre := rect.get_center()
	for c: Dictionary in _cues.values():
		var world := Vector3((c.at as Vector2).x, player.global_position.y + 1.4, (c.at as Vector2).y)
		var behind := camera.is_position_behind(world)
		var p := camera.unproject_position(world)
		if not behind and rect.has_point(p):
			continue                         # in view: the bodies show it
		var dir := (p - centre) * (-1.0 if behind else 1.0)
		if dir.length() < 0.001:
			continue
		dir = dir.normalized()
		var tx := absf(rect.size.x * 0.5 / dir.x) if absf(dir.x) > 0.0001 else INF
		var ty := absf(rect.size.y * 0.5 / dir.y) if absf(dir.y) > 0.0001 else INF
		var at := centre + dir * minf(tx, ty)
		var fade := clampf(1.0 - (_t - float(c.born)) / SHOW_FOR, 0.0, 1.0)
		var col := (Color(1.0, 0.85, 0.45) if c.kind == "bell" else Color(1.0, 0.6, 0.4)) * Color(1, 1, 1, 0.85 * fade)
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([at + dir * SIZE, at - dir * SIZE * 0.6 + side * SIZE * 0.8,
			at - dir * SIZE * 0.6 - side * SIZE * 0.8]), col)
		draw_circle(at - dir * SIZE * 1.6, 3.0, col)
		_drawn = true
