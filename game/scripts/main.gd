extends Node3D
## Builds the current region (Region.current: the meadow, the forest...) and places the player.

@onready var terrain: Node = $Terrain
@onready var scatter: Node = $Scatter
@onready var player: CharacterBody3D = $Player
@onready var camera_rig: Node3D = $CameraRig


func _ready() -> void:
	var first_load := Region.arrive == Vector2.INF
	if first_load:
		Region.current = SaveGame.saved_region()
	var meadow := Region.current == "meadow"
	var shape := WorldShape.new()
	terrain.build(shape)
	scatter.build(shape)
	terrain.bake_shade(scatter.shade_spots)
	$Landmark.place(shape)
	$ResourceVisuals.setup(scatter.gatherables)
	$OcclusionFader.setup(scatter.trees)
	$Enemies.spawn(shape)
	if meadow:
		$Village.build(shape)
	$HUD.setup_map(shape, scatter.tree_points(), $Landmark)
	var treasure := Node3D.new()
	treasure.set_script(preload("res://scripts/world/treasure.gd"))
	treasure.player = player
	add_child(treasure)
	treasure.build(shape)
	if meadow:
		var workbench := Node3D.new()
		workbench.set_script(preload("res://scripts/world/workbench.gd"))
		add_child(workbench)
		workbench.build(shape, Vector2(-1.0, 7.0))
	var fire := Node3D.new()
	fire.set_script(preload("res://scripts/world/campfire.gd"))
	add_child(fire)
	fire.build(shape, Vector2(-3.5, 27.0) if meadow else Vector2(4.0, -81.5))
	for id: String in Projects.DEFS:
		if Projects.DEFS[id]["region"] == Region.current:
			var site := Node3D.new()
			site.set_script(preload("res://scripts/world/project_site.gd"))
			add_child(site)
			site.build(shape, id)
	if meadow:
		var plot := Node3D.new()
		plot.set_script(preload("res://scripts/world/home_plot.gd"))
		plot.player = player
		plot.day_night = $WorldEnvironment
		add_child(plot)
		plot.build(shape)
	var places := Node3D.new()
	places.set_script(preload("res://scripts/world/places.gd"))
	places.player = player
	add_child(places)
	places.build(shape)
	var gates := Node3D.new()
	gates.set_script(preload("res://scripts/world/region_gates.gd"))
	gates.player = player
	add_child(gates)
	gates.build(shape)
	var lab := Node3D.new()
	lab.set_script(preload("res://scripts/dev/build_lab.gd"))
	lab.player = player
	lab.scatter = scatter
	lab.visuals = $ResourceVisuals
	lab.treasure = treasure
	add_child(lab)
	var critters := Node3D.new()
	critters.set_script(preload("res://scripts/world/critters.gd"))
	critters.player = player
	critters.day_night = $WorldEnvironment
	add_child(critters)
	critters.build(shape)
	$Player/Sounds.shape = shape
	var spawn := WorldShape.SPAWN
	player.global_position = Vector3(spawn.x, shape.height_at(spawn.x, spawn.y) + 0.3, spawn.y)
	player.spawn_point = player.global_position
	var arrive := Region.arrive
	SaveGame.attach(player, $WorldEnvironment)
	VillageSession.attach(self) # studio: persistent authority, disposable presentation
	if arrive != Vector2.INF:          # came through a gate: stand just inside it, facing in
		player.global_position = Vector3(arrive.x, shape.height_at(arrive.x, arrive.y) + 0.3, arrive.y)
		player.visual.rotation.y = atan2(-arrive.x, -arrive.y)
	camera_rig.snap()
	Region.arrived(not first_load)
