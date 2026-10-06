extends Node
## Spike S3 (village costs): how many of the game's own animated characters (CharacterVisual on the
## Quaternius rig) the phone can show at once. Crowds of 0, 10, 20, 30, 45 and 60 villagers walk in
## rings around the player; every frame is timed (raw timestamps) after a settling pause.
## Run with a camera framing, e.g. on a phone: --studio=village/crowd_bench --frame=fight --at=2,24
## Result: log lines "STUDIO ..." and user://studio-village-crowd_bench.txt, then quits.
## --crowd-body: the villagers are VillagerBodies (one merged mesh each) instead of CharacterVisuals;
## the NEAR_FULL nearest the camera get detail tier 0 (full-rate animation, shadows), the rest tier 1
## (animation stepped at ~10 Hz, no shadows), re-sorted every RETIER seconds. --crowd-near=N changes how
## many are near (--crowd-near=99: every body at tier 0, to measure the merge alone).
## --crowd-uncapped: lift the game's 30 fps cap and vsync, so a fast PC shows its real frame cost.

const COUNTS: Array[int] = [0, 10, 20, 30, 45, 60]
const VillagerBody := preload("res://scripts/studio/village/villager_body.gd")
const NEAR_FULL := 12    # --crowd-body: this many nearest the camera animate at full rate and cast shadows
const RETIER := 1.0      # seconds between re-sorting who is near
## Variants that split the cost: --crowd-noshadow (villagers cast no shadows),
## --crowd-noanim (animation frozen, so no skeleton updates), --crowd-short (0, 30, 45 only).
var _counts: Array[int] = COUNTS
var _no_shadow := false
var _no_anim := false
var _bodies := false
var _near_full := NEAR_FULL
var _retier_t := 0.0
const SETTLE := 4.0      # seconds after spawning before measuring (shaders, animations settle)
const MEASURE := 8.0     # seconds measured per crowd size

var _phase := -1
var _t := 0.0
var _last := 0
var _frames: Array[float] = []
var _lines := PackedStringArray()
var _crowd: Array[Node3D] = []
var _angle: Array[float] = []
var _radius: Array[float] = []
var _center := Vector3.ZERO
var _shape: WorldShape


static func on_device(tree: SceneTree) -> void:
	var probe: Node = (load("res://scripts/studio/village/crowd_bench.gd") as GDScript).new()
	tree.root.add_child.call_deferred(probe)


func _ready() -> void:
	_shape = WorldShape.new()
	var args := OS.get_cmdline_user_args()
	_no_shadow = args.has("--crowd-noshadow")
	_no_anim = args.has("--crowd-noanim")
	_bodies = args.has("--crowd-body")
	for arg in args:
		if arg.begins_with("--crowd-near="):
			_near_full = int(arg.trim_prefix("--crowd-near="))
	if args.has("--crowd-uncapped"):
		Engine.max_fps = 0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if args.has("--crowd-short"):
		_counts = [0, 30, 45]
	_lines.append("device: %s; %s; Godot %s; %s; shadows %s, animation %s; fps cap %s" % [OS.get_model_name(), RenderingServer.get_current_rendering_method(), Engine.get_version_info()["string"],
		"VillagerBody (nearest %d full, rest ~10 Hz without shadows)" % _near_full if _bodies else "CharacterVisual",
		"off" if _no_shadow else "on", "frozen" if _no_anim else "on", Engine.max_fps if Engine.max_fps > 0 else "none"])


func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	var frame_ms := (now - _last) / 1000.0
	_last = now
	_t += delta
	if _phase == -1:
		if _t < 6.0:
			return   # the game loads and the start position settles
		_center = (get_tree().current_scene.get_node("Player") as Node3D).global_position
		_next_phase()
		return
	_walk(delta)
	if _bodies:
		_retier_t -= delta
		if _retier_t <= 0.0:
			_retier_t = RETIER
			_retier()
	if _t < SETTLE:
		return
	if _t < SETTLE + MEASURE:
		_frames.append(frame_ms)
		return
	_report_phase()
	_next_phase()


func _next_phase() -> void:
	_phase += 1
	_t = 0.0
	_frames.clear()
	if _phase >= _counts.size():
		for s in _lines:
			print("STUDIO ", s)
		var f := FileAccess.open("user://studio-village-crowd_bench.txt", FileAccess.WRITE)
		if f:
			f.store_string("\n".join(_lines) + "\n")
			f.close()
		get_tree().quit()
		set_process(false)
		return
	var outfits: Array = CharacterLook.OUTFITS.keys()
	while _crowd.size() < _counts[_phase]:
		var i := _crowd.size()
		var look := CharacterLook.new()
		look.set_outfit(outfits[i % outfits.size()])
		var v := _villager(look)
		add_child(v)
		if _no_shadow:
			for mi: MeshInstance3D in v.find_children("*", "MeshInstance3D", true, false):
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if _no_anim:
			for ap: AnimationPlayer in v.find_children("*", "AnimationPlayer", true, false):
				ap.pause()
		_crowd.append(v)
		_angle.append(i * 2.399)                 # golden-angle spread
		_radius.append(3.0 + (i % 6) * 1.6)      # rings from 3 m to 11 m around the player
	_retier_t = 0.0                              # sort the new crowd on the next frame


func _villager(look: CharacterLook) -> Node3D:
	if _bodies:
		var b := VillagerBody.new()
		b.hero_look = look
		b.is_player_look = false
		return b
	var v := CharacterVisual.new()
	v.hero_look = look
	v.is_player_look = false
	return v


## --crowd-body: the villagers nearest the camera at detail 0 (NEAR_FULL of them), the rest at 1.
func _retier() -> void:
	var eye := get_viewport().get_camera_3d().global_position
	var order: Array[int] = []
	for i in _crowd.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		return _crowd[a].global_position.distance_squared_to(eye) < _crowd[b].global_position.distance_squared_to(eye))
	for rank in order.size():
		var v := _crowd[order[rank]]
		v.set_detail(0 if rank < _near_full else 1)
		if _no_shadow:
			for mi: MeshInstance3D in v.find_children("*", "MeshInstance3D", true, false):
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _walk(delta: float) -> void:
	for i in _crowd.size():
		var v := _crowd[i]
		var r := _radius[i]
		_angle[i] += delta * 1.0 / r             # about 1 m/s along the ring
		var p := _center + Vector3(cos(_angle[i]), 0.0, sin(_angle[i])) * r
		p.y = _shape.height_at(p.x, p.z)
		v.global_position = p
		v.rotation.y = -_angle[i]                # face along the ring
		if not _no_anim:
			v.play_motion(1.0)


@warning_ignore("integer_division")
func _report_phase() -> void:
	var v := _frames.duplicate()
	v.sort()
	var n := v.size()
	var over := v.filter(func(x: float) -> bool: return x > 50.0).size()
	_lines.append("%2d walking villagers: %d frames, median %.1f ms, 95th %.1f ms, worst %.1f ms, over 50 ms: %d; draws %d, triangles %dk" % [
		_counts[_phase], n, v[n / 2], v[int(n * 0.95)], v[n - 1], over,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000])
