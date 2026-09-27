extends Node3D
## Builds the meadow slice and places the player.

@onready var terrain: Node = $Terrain
@onready var scatter: Node = $Scatter
@onready var player: CharacterBody3D = $Player
@onready var camera_rig: Node3D = $CameraRig


func _ready() -> void:
	var shape := WorldShape.new()
	terrain.build(shape)
	scatter.build(shape)
	terrain.bake_shade(scatter.shade_spots)
	$Landmark.place(shape)
	$ResourceVisuals.setup(scatter.gatherables)
	$OcclusionFader.setup(scatter.trees)
	$Enemies.spawn(shape)
	$Village.build(shape)
	$HUD.setup_map(shape, scatter.tree_points(), $Landmark)
	var treasure := Node3D.new()
	treasure.set_script(preload("res://scripts/world/treasure.gd"))
	treasure.player = player
	add_child(treasure)
	treasure.build(shape)
	var workbench := Node3D.new()
	workbench.set_script(preload("res://scripts/world/workbench.gd"))
	add_child(workbench)
	workbench.build(shape, Vector2(-1.0, 7.0))
	var lab := Node3D.new()
	lab.set_script(preload("res://scripts/dev/build_lab.gd"))
	lab.player = player
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
	SaveGame.attach(player, $WorldEnvironment)
	camera_rig.snap()
