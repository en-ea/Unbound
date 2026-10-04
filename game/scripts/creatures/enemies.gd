extends Node3D
## Spawns the current region's creatures at their home spots.

const BOAR := preload("res://scenes/boar.tscn")
const WOLF := preload("res://scenes/wolf.tscn")
## Per region: where boars live, wolf packs (two wolves each), lone shadow wolves (tougher), and stag
## herds (two each: prey that runs).
const HOMES := {
	"meadow": {"boars": [Vector2(20, 28), Vector2(-24, 12), Vector2(58, 20), Vector2(-60, 30)],
		"wolves": [Vector2(6, -38), Vector2(-44, -4), Vector2(-62, -76), Vector2(70, -60)], "shadow": [],
		"stags": [Vector2(46, -22), Vector2(-50, -50)]},
	"forest": {"boars": [Vector2(26, -40), Vector2(70, -20)],
		"wolves": [Vector2(-20, -30), Vector2(30, 6), Vector2(-56, 40), Vector2(60, -64), Vector2(-80, 10), Vector2(40, 80)],
		"shadow": [Vector2(10, 40), Vector2(-40, -10), Vector2(-50, 64), Vector2(80, 66)],
		"stags": [Vector2(-10, 62), Vector2(-62, -52)]},
	"highlands": {"boars": [Vector2(-20, -40), Vector2(50, -10)],
		"wolves": [Vector2(40, -60), Vector2(-50, -50), Vector2(60, 30), Vector2(-20, 60)],
		"shadow": [Vector2(-60, 40), Vector2(70, 70)],
		"stags": [Vector2(30, -20), Vector2(-40, -10), Vector2(50, 50)]},
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
	for h: Vector2 in homes.get("stags", []):
		for i in 2:
			var stag := Stag.new()
			stag.player = player
			stag.home = Vector3(h.x, shape.height_at(h.x, h.y), h.y)
			add_child(stag)
			stag.global_position = stag.home + Vector3(i * 2.5, 0.6, i * 1.5)
	_limit_range.call_deferred()


## Far creatures are only specks in the fog: stop drawing them past this (saves draw calls).
func _limit_range() -> void:
	for g in find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).visibility_range_end = 55.0
