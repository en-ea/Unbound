extends Node
## Look check for props.gd: the six punishment and village props in a row, a villager in each device at
## its VICTIM spot (looping a pose with VillagerBody.play_loop), one more standing by for scale; or, with
## --props-small, the four throwables close up; --props-focus=stake frames one prop close. Prints each
## prop's triangle count; the game's own --shot saves the screenshot (frame 180) and quits.
## Run (open ground): --studio=village/props_lineup --frame=fight --at=4,-5 --shot=C:/path/props.png
## (--props-small reads best on the bare path at --at=2,24)

const Props := preload("res://scripts/studio/village/props.gd")
const VillagerBody := preload("res://scripts/studio/village/villager_body.gd")
const BIG := ["pillory", "stocks", "stake", "gallows", "shrine", "notice_board"]
const WIDTH := {"pillory": 1.5, "stocks": 1.4, "stake": 2.0, "gallows": 2.6, "shrine": 1.0, "notice_board": 1.6}
const SMALL := ["cabbage", "turnip", "mud", "stone"]
const INCIDENT := ["goose", "sack", "basket", "bread"]   # --props-incident: what the small scenes carry (Pass 2)
const POSES := Props.VICTIM_POSE
const GAP := 1.1              # metres between big props

var _frame := 0
var _small := false
var _incident := false
var _shot := false
var _focus := ""


static func on_device(tree: SceneTree) -> void:
	var probe: Node = (load("res://scripts/studio/village/props_lineup.gd") as GDScript).new()
	tree.root.add_child.call_deferred(probe)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_small = args.has("--props-small") or args.has("--props-incident")
	_incident = args.has("--props-incident")
	for arg in args:
		if arg.begins_with("--shot="):
			_shot = true
		elif arg.begins_with("--props-focus="):
			_focus = arg.trim_prefix("--props-focus=")


func _process(_delta: float) -> void:
	_frame += 1
	if _frame == 8:
		_build()        # the player has been placed (dev_args moves it on frame 2)
	elif _frame == 240 and not _shot:
		get_tree().quit()   # no --shot: nothing else ends the run


func _build() -> void:
	var player := get_tree().current_scene.get_node("Player") as Node3D
	player.visible = false
	var shape := WorldShape.new()
	var make := Props.all()
	var names: Array = INCIDENT if _incident else SMALL if _small else BIG
	var total := 0.0
	for n: String in names:
		total += (0.6 if _incident else 0.35) if _small else WIDTH[n] + GAP
	var x := -total / 2.0
	var focus_x := 0.0
	for n: String in names:
		var w: float = (0.6 if _incident else 0.35) if _small else WIDTH[n] + GAP
		var at := player.global_position + Vector3(x + w / 2.0, 0.0, 0.0)
		at.y = shape.height_at(at.x, at.z)
		var prop: Node3D = (make[n] as Callable).call()
		add_child(prop)
		prop.global_position = at
		var mesh := (prop as MeshInstance3D).mesh
		print("STUDIO prop %s: %d triangles, %d surface(s)" % [n, mesh.surface_get_array_len(0) / 3, mesh.get_surface_count()])
		if POSES.has(n):
			_villager(at + Props.VICTIM[n], POSES[n], n.length())
		if n == _focus:
			focus_x = x + w / 2.0
		x += w
	var rig := get_tree().current_scene.get_node("CameraRig")
	if _incident:
		rig.set_view(2.3, -10.0, Vector3(0.0, -0.62, 0.0), 0.01)
		return
	if _small:
		rig.set_view(1.5, -28.0, Vector3(0.0, -0.88, 0.0), 0.01)
		return
	var by := player.global_position + Vector3(total / 2.0 - WIDTH["notice_board"] - GAP * 0.9, 0.0, 1.0)   # one more, for scale
	by.y = shape.height_at(by.x, by.z)
	_villager(by, "Idle_FoldArms", 99)
	if _focus != "":
		rig.set_view(4.6, -8.0, Vector3(focus_x, 0.9, 0.0), 0.01)
	else:
		rig.set_view(10.5, -12.0, Vector3(0.0, 0.9, 0.0), 0.01)


func _villager(at: Vector3, pose: String, look_seed: int) -> void:
	var b := VillagerBody.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = look_seed
	b.hero_look = CharacterLook.new()
	b.hero_look.randomize_look(rng)
	b.hero_look.parts["head"] = "none"
	b.is_player_look = false
	add_child(b)
	b.global_position = at
	b.play_loop(pose)
