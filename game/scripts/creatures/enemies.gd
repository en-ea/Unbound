extends Node3D
## Spawns the meadow's creatures at their home spots.

const BOAR := preload("res://scenes/boar.tscn")
## Where boars live (x, z). Away from the start, near the woods.
const BOAR_HOMES := [Vector2(20, 28), Vector2(-24, 12)]

@export var player: Node3D


func spawn(shape: WorldShape) -> void:
	for h: Vector2 in BOAR_HOMES:
		var boar := BOAR.instantiate() as Boar
		boar.player = player
		boar.home = Vector3(h.x, shape.height_at(h.x, h.y), h.y)
		add_child(boar)
		boar.global_position = boar.home + Vector3(0, 0.5, 0)
