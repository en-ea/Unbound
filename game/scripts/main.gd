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
	var spawn := WorldShape.SPAWN
	player.global_position = Vector3(spawn.x, shape.height_at(spawn.x, spawn.y) + 0.3, spawn.y)
	camera_rig.snap()
