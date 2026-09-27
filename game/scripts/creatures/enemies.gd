extends Node3D
## Spawns the meadow's creatures at their home spots.

const BOAR := preload("res://scenes/boar.tscn")
const WOLF := preload("res://scenes/wolf.tscn")
## Where boars live (x, z). Away from the start, near the woods.
const BOAR_HOMES := [Vector2(20, 28), Vector2(-24, 12)]
## Wolf packs (two wolves each), deeper in, north of the start.
const WOLF_HOMES := [Vector2(6, -38), Vector2(-44, -4)]

@export var player: Node3D


func spawn(shape: WorldShape) -> void:
	for h: Vector2 in BOAR_HOMES:
		var boar := BOAR.instantiate() as Boar
		boar.player = player
		boar.home = Vector3(h.x, shape.height_at(h.x, h.y), h.y)
		add_child(boar)
		boar.global_position = boar.home + Vector3(0, 0.5, 0)
	for h: Vector2 in WOLF_HOMES:
		for i in 2:
			var wolf := WOLF.instantiate() as Wolf
			wolf.player = player
			wolf.home = Vector3(h.x, shape.height_at(h.x, h.y), h.y)
			add_child(wolf)
			wolf.global_position = wolf.home + Vector3(i * 1.5, 0.5, i)
