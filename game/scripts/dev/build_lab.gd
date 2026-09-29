extends Node3D
## The build lab: a small walled stone floor far below the world, for looking at buildings and
## testing things. One building stands on the showcase pad; the Lab board by the entrance opens the
## lab menu (dev/lab_menu.gd): switch the building, spawn enemies, trees, rocks, ores and chests in
## front of you, drop loot. Everything spawned is removed again when you leave (it never reaches a
## save). The title screen's "Build lab" button enters it; the pause menu's "Leave build lab" puts
## you back where you were. Saving pauses while you're here.

const TREASURE := preload("res://scripts/world/treasure.gd")
const STATION := preload("res://scripts/world/station.gd")
const TOOL_DROP := preload("res://scripts/world/tool_drop.gd")
const BOAR := preload("res://scenes/boar.tscn")
const WOLF := preload("res://scenes/wolf.tscn")
const BOARD := preload("res://assets/props/site_board.glb")
const AT := Vector3(0, -300, 0)
const RADIUS := 21.0              # the wall ring
const PAD := Vector3(0, 0, -4)    # the showcase pad's centre
const ENTRY := Vector2(0.0, 8.0)
## [name, model, footprint]: newest styles first.
const BUILDINGS := [["Smithy", "smithy", 7.0], ["Market round house", "house_market", 8.5], ["Large swoop home", "house_swoophome", 8.5],
	["Dual ring house", "house_ring", 8.5], ["Stump house (forest)", "house_stump", 8.0], ["Swoop lodge", "house_lodge", 6.0],
	["Hill house", "house_hill", 6.5], ["Skep cottage", "house_skep", 7.0], ["Lantern house", "house_lantern", 6.5],
	["Hull house", "house_hull", 6.5], ["Turret cottage", "house_turret", 6.5], ["Storybook cottage", "house_storybook", 6.5],
	["Gable house", "house_gable", 5.5], ["Arch cottage", "house_arch", 6.0], ["Round house", "house_round", 5.0],
	["Cottage", "house_cottage", 6.0], ["Cabin", "house_cabin", 6.0], ["Loaf cottage", "house_loaf", 6.0], ["Windmill", "windmill", 5.0],
	["Hex house (later)", "house_hex", 6.5], ["Rune tower (later)", "house_tower", 6.0], ["Grotto house (later)", "house_grotto", 6.5]]
## What the menu can spawn: gatherables are [model, scatter kind, resource type, scale].
const GATHERABLES := {"tree": ["tree_oak_1", "tree", "tree", 1.0], "pine": ["tree_pine_1", "tree", "pine", 1.1],
	"apple": ["tree_apple_1", "tree", "apple_tree", 1.0], "rock": ["rock_2", "rock", "rock", 0.9],
	"copper": ["ore_copper", "rock", "copper_rock", 0.8], "iron": ["ore_iron", "rock", "iron_rock", 0.8]}

@export var player: CharacterBody3D
var scatter: Node         # set by main.gd: for tree and rock models
var visuals: Node         # ResourceVisuals
var treasure: Node        # chests

var active := false
var building := 0
var _return_to := Vector3.ZERO
var _built := false
var _fog_was := true
var _shown: Node3D
var _label: Label3D
var _spawns: Node3D       # enemies, drops and gatherables spawned here
var _first_id := -1       # the first resource id spawned in the lab (all later ones are ours)


func _ready() -> void:
	add_to_group("build_lab")


func enter(spot := ENTRY) -> void:
	if active:
		return
	if not _built:
		_build()
	_return_to = player.global_position
	SaveGame.paused = true
	active = true
	var env := get_viewport().world_3d.environment      # the world's height fog would wash the lab out
	if env:
		_fog_was = env.fog_enabled
		env.fog_enabled = false
	player.global_position = AT + Vector3(spot.x, 0.6, spot.y)
	player.velocity = Vector3.ZERO
	get_tree().call_group("camera_rig", "snap")


func leave() -> void:
	if not active:
		return
	clear_spawns()
	active = false
	var env := get_viewport().world_3d.environment
	if env:
		env.fog_enabled = _fog_was
	player.global_position = _return_to
	player.velocity = Vector3.ZERO
	SaveGame.paused = false
	get_tree().call_group("camera_rig", "snap")


## The action: show another building on the pad.
func show_building(index: int) -> void:
	building = posmod(index, BUILDINGS.size())
	if is_instance_valid(_shown):
		_shown.queue_free()
	var entry: Array = BUILDINGS[building]
	_shown = TREASURE._solid((load("res://assets/buildings/%s.glb" % entry[1]) as PackedScene).instantiate())
	_shown.position = PAD
	add_child(_shown)
	if entry[1] == "windmill":
		var sails := TREASURE._solid((load("res://assets/buildings/windmill_sails.glb") as PackedScene).instantiate())
		sails.position = Vector3(0, 5.75, 2.75)
		_shown.add_child(sails)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(entry[2] * 0.7, 4, entry[2] * 0.7)
	col.shape = box
	col.position.y = 2
	body.add_child(col)
	_shown.add_child(body)
	_label.text = entry[0]
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_shown.scale = Vector3(1, 0.05, 1)
	t.tween_property(_shown, "scale", Vector3.ONE, 0.4)


## The action: spawn something 3.5 m in front of you (kept inside the walls).
func spawn(kind: String) -> void:
	var at := _spot()
	match kind:
		"boar", "wolf", "shadow":
			var e: CharacterBody3D = (BOAR if kind == "boar" else WOLF).instantiate()
			e.player = player
			e.home = at
			if kind == "shadow":
				e.shadow = true
			_spawns.add_child(e)
			e.global_position = at + Vector3(0, 0.5, 0)
		"chest":
			_note_first()
			treasure.add_chest(at, rad_to_deg(atan2(player.global_position.x - at.x, player.global_position.z - at.z)))
		"gear", "sword":
			var found: Array = Gear.roll_found("elite") if kind == "gear" else ["sword", Gear._tool(randi_range(1, 4), Loot.roll_rarity("elite"))]
			if kind == "sword":
				found[1]["bonuses"] = Loot.roll_bonuses("weapon", found[1]["rarity"])
			TOOL_DROP.spawn(_spawns, found[0], found[1], at, player)
		_:
			if GATHERABLES.has(kind):
				_note_first()
				var g: Array = GATHERABLES[kind]
				visuals.add_gatherable(scatter.make_single(_spawns, g[0], g[1], at, g[3], g[2]))


## The action: remove everything spawned here (also done on leaving).
func clear_spawns() -> void:
	if _first_id >= 0:
		for id in range(_first_id, WorldResources.node_count()):
			visuals.forget(id)
			treasure.remove_chest(id)
		WorldResources.truncate(_first_id)
		_first_id = -1
	if is_instance_valid(_spawns):
		for c in _spawns.get_children():
			c.queue_free()


func _note_first() -> void:
	if _first_id < 0:
		_first_id = WorldResources.node_count()


func _spot() -> Vector3:
	var facing := Vector3(sin(player.visual.rotation.y), 0, cos(player.visual.rotation.y))
	var p := player.global_position + facing * 3.5 - AT
	p.y = 0.0
	if Vector2(p.x, p.z).length() > RADIUS - 3.0:
		p = p.normalized() * (RADIUS - 3.0)
	return AT + p


func _build() -> void:
	_built = true
	global_position = AT
	# A dark hexagonal stone floor, a lighter showcase pad, and a low stone wall all round.
	_disc(RADIUS + 1.5, 0.2, Color(0.2, 0.22, 0.26), Vector3(0, -0.1, 0))
	_disc(7.8, 0.06, Color(0.32, 0.34, 0.38), PAD + Vector3(0, 0.01, 0))
	var body := StaticBody3D.new()
	add_child(body)
	var floor := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(60, 1, 60)
	floor.shape = floor_box
	floor.position.y = -0.5
	body.add_child(floor)
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.36, 0.37, 0.4)
	wall_mat.roughness = 0.95
	var n := 24
	for i in n:
		var a := i * TAU / n
		var seg := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(TAU * RADIUS / n + 0.1, 0.6, 0.7)
		mesh.material = wall_mat
		seg.mesh = mesh
		seg.position = Vector3(sin(a) * RADIUS, 0.3, cos(a) * RADIUS)
		seg.rotation.y = a
		add_child(seg)
		var col := CollisionShape3D.new()       # invisible, taller than the wall: no falling off
		var box := BoxShape3D.new()
		box.size = Vector3(TAU * RADIUS / n + 0.3, 4.0, 0.8)
		col.shape = box
		col.position = Vector3(sin(a) * RADIUS, 2.0, cos(a) * RADIUS)
		col.rotation.y = a
		body.add_child(col)
	_label = Label3D.new()
	_label.font_size = 64
	_label.outline_size = 16
	_label.pixel_size = 0.01
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate = Color(1.0, 0.92, 0.76)
	_label.position = PAD + Vector3(0, 0.6, 5.2)
	add_child(_label)
	var board := Node3D.new()
	board.set_script(STATION)
	add_child(board)
	board.setup(AT + Vector3(-3.2, 0, 7.0), "Lab", {"mode": "lab", "lab": self}, BOARD, Vector3(1.4, 1.6, 0.3))
	board.add_child(SignLabel.make("Lab"))
	_spawns = Node3D.new()
	add_child(_spawns)
	show_building(building)


func _disc(radius: float, height: float, color: Color, at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 6            # hexagonal, like the style
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mesh.material = mat
	mi.mesh = mesh
	mi.position = at
	add_child(mi)
