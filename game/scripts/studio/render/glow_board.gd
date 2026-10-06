extends SceneTree
## Graphics S2's one visible change, shown on its own (not inside the parity claim): villagers' masks glow again.
## The villager merge drew every part on one plain material, so the glowing parts of three masks (aurum's gem SunGlow,
## hollow's eyes MaskGlow, raven's lenses LensGlow) lost the glow Enea's CharacterVisual gives them (glow 1.2). S2's
## merge puts them on a second, glowing surface, only on bodies that have one.
## Each mask is shown twice side by side: a villager body (VillagerBody, left) and Enea's own CharacterVisual (right,
## his parts: the reference). By day, then at night (22:30 on the village clock), where glow shows most.
## Dev-only. Runs on any commit that has VillagerBody, so the same board can be made before and after:
##   godot --rendering-driver opengl3 --fixed-fps 30 --path game --resolution 1560x720 \
##     --script res://scripts/studio/render/glow_board.gd -- --test-save=<fresh> --board-out=<absolute dir> \
##     --board-name=<before|after> --studio-merge=off
## Writes <name>-day.png and <name>-night.png, and <name>-faces.txt (each head's box on screen, x,y,w,h a line, in
## row order) for close-ups; prints GLOWBOARD lines. The night's fireflies are hidden: they are random particles that
## land somewhere else in every launch, and the two launches are compared.

const SPOT := Vector2(-6.0, 44.0)
const MASKS := ["aurum", "hollow", "raven"]
const PAIR := 0.55      # villager left, his CharacterVisual right, this far from the pair's centre
const STEP := 1.9       # metres between pairs

var _out := ""
var _name := "board"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--board-out="):
			_out = arg.trim_prefix("--board-out=")
		elif arg.begins_with("--board-name="):
			_name = arg.trim_prefix("--board-name=")
	if _out == "":
		print("GLOWBOARD REFUSE no --board-out=<absolute dir>")
		quit(3)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _run() -> void:
	for i in 240:
		await process_frame
		if current_scene != null and current_scene.name == "Main" and i > 150:
			break
	var main := current_scene
	var shape: RefCounted = load("res://scripts/world/world_shape.gd").new()
	var Look: GDScript = load("res://scripts/player/character_look.gd")
	var CV: GDScript = load("res://scripts/player/character_visual.gd")
	var VB: GDScript = load("res://scripts/studio/village/villager_body.gd")
	var player: Node3D = main.get_node("Player")
	# The camera follows the player; he stands 4 m south of the row, hidden, and the view's offset puts the focus on it.
	player.global_position = Vector3(SPOT.x, shape.call("height_at", SPOT.x, SPOT.y + 4.0) + 0.3, SPOT.y + 4.0)
	(player.get("visual") as Node3D).visible = false
	var bodies: Array = []
	for i in MASKS.size():
		var cx := SPOT.x + (i - 1) * STEP
		for side in [-1, 1]:
			var look: RefCounted = Look.new()
			look.get("parts")["mask"] = MASKS[i]
			look.get("parts")["head"] = "none"
			var v: Node3D = VB.new() if side < 0 else CV.new()
			v.set("hero_look", look)
			v.set("is_player_look", false)
			main.add_child(v)
			var x: float = cx + side * PAIR
			v.global_position = Vector3(x, shape.call("height_at", x, SPOT.y), SPOT.y)
			bodies.append(v)
	var rig: Node3D = main.get_node("CameraRig")
	for _i in 30:
		await process_frame
	var lift: float = shape.call("height_at", SPOT.x, SPOT.y) + 1.3 - (player.global_position.y + 1.0)   # focus = player + 1 m + offset
	if rig.get_method_argument_count("set_view") >= 5:
		rig.set_view(3.4, -4.0, Vector3(0.0, lift, -4.0), 0.01, 50.0)
	else:
		rig.set_view(3.4, -4.0, Vector3(0.0, lift, -4.0), 0.01)
	await _capture(main, bodies, "day")
	var session: Node = root.get_node_or_null("VillageSession")
	var day_night: Node = main.get_node("WorldEnvironment")
	var village = session.get("village") if session != null else null
	var now := int(village.runtime.now) if village != null else int(float(day_night.get("time_of_day")) * 1440.0)
	var to := (now - now % 1440) + 1350
	if to <= now:
		to += 1440
	day_night.call("skip", float(to - now) / 1440.0)
	for _i in 90:
		await process_frame
	await _capture(main, bodies, "night")
	print("GLOWBOARD done %s" % _name)
	quit(0)


## Everyone in the same idle frame, paused, the HUD hidden.
func _capture(main: Node, bodies: Array, when: String) -> void:
	paused = false
	for _i in 20:
		await process_frame
	paused = true
	for v: Node3D in bodies:
		var ap: AnimationPlayer = v.find_children("*", "AnimationPlayer", true, false)[0]
		ap.play("Idle")
		ap.seek(0.5, true)
		ap.pause()
	var hud: CanvasLayer = main.get_node("HUD")
	hud.visible = false
	var flies: Node3D = main.get_node_or_null("Fireflies")
	if flies != null:
		flies.visible = false
	for _i in 4:
		await process_frame
	var png := "%s/%s-%s.png" % [_out, _name, when]
	root.get_texture().get_image().save_png(png)
	hud.visible = true
	if flies != null:
		flies.visible = true
	if when == "day":
		var cam: Camera3D = root.get_camera_3d()
		var lines: PackedStringArray = []
		for v: Node3D in bodies:
			var c := cam.unproject_position(v.global_position + Vector3(0.0, 1.62, 0.0))
			lines.append("%d,%d,%d,%d" % [int(c.x) - 70, int(c.y) - 70, 140, 140])
		var f := FileAccess.open("%s/%s-faces.txt" % [_out, _name], FileAccess.WRITE)
		f.store_string("\n".join(lines))
		f.close()
	print("GLOWBOARD %s" % png)
