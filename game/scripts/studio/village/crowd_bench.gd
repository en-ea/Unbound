extends Node
## Spike S3 (village costs): how many of the game's own animated characters (CharacterVisual on the
## Quaternius rig) the phone can show at once. Crowds of 0, 10, 20, 30, 45 and 60 villagers walk in
## rings around the player; every frame is timed (raw timestamps) after a settling pause.
## Run with a camera framing, e.g. on a phone: --studio=village/crowd_bench --frame=fight --at=2,24
## Result: log lines "STUDIO ..." and user://studio-village-crowd_bench.txt, then quits.

const COUNTS: Array[int] = [0, 10, 20, 30, 45, 60]
## Variants that split the cost: --crowd-noshadow (villagers cast no shadows),
## --crowd-noanim (animation frozen, so no skeleton updates), --crowd-short (0, 30, 45 only).
var _counts: Array[int] = COUNTS
var _no_shadow := false
var _no_anim := false
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
	if args.has("--crowd-short"):
		_counts = [0, 30, 45]
	_lines.append("device: %s; %s; Godot %s; shadows %s, animation %s" % [OS.get_model_name(), RenderingServer.get_current_rendering_method(), Engine.get_version_info()["string"], "off" if _no_shadow else "on", "frozen" if _no_anim else "on"])


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
		var v := CharacterVisual.new()
		v.hero_look = CharacterLook.new()
		v.hero_look.set_outfit(outfits[i % outfits.size()])
		v.is_player_look = false
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
