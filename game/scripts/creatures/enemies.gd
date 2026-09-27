extends Node3D
## Spawns the current region's creatures at their home spots.

const BOAR := preload("res://scenes/boar.tscn")
const WOLF := preload("res://scenes/wolf.tscn")
## Per region: where boars live, wolf packs (two wolves each), and lone shadow wolves (tougher).
const HOMES := {
	"meadow": {"boars": [Vector2(20, 28), Vector2(-24, 12)], "wolves": [Vector2(6, -38), Vector2(-44, -4)], "shadow": []},
	"forest": {"boars": [Vector2(26, -40)], "wolves": [Vector2(-20, -30), Vector2(30, 6), Vector2(-30, 20)],
		"shadow": [Vector2(10, 40), Vector2(-40, -10)]},
}

@export var player: Node3D


func spawn(shape: WorldShape) -> void:
	var homes: Dictionary = HOMES.get(Region.current, HOMES["meadow"])
	for h: Vector2 in homes["boars"]:
		var boar := BOAR.instantiate() as Boar
		boar.player = player
		boar.home = Vector3(h.x, shape.height_at(h.x, h.y), h.y)
		add_child(boar)
		boar.global_position = boar.home + Vector3(0, 0.5, 0)
	for h: Vector2 in homes["wolves"] + homes["shadow"]:
		var shadow: bool = h in homes["shadow"]
		for i in (1 if shadow else 2):
			var wolf := WOLF.instantiate() as Wolf
			wolf.player = player
			wolf.shadow = shadow
			wolf.home = Vector3(h.x, shape.height_at(h.x, h.y), h.y)
			add_child(wolf)
			wolf.global_position = wolf.home + Vector3(i * 1.5, 0.5, i)
