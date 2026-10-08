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
	"sands": {"boars": [Vector2(-50, 10), Vector2(40, -10), Vector2(-20, -60)],
		"wolves": [Vector2(-60, -20), Vector2(30, -70), Vector2(60, -30), Vector2(-30, 0)],
		"shadow": [Vector2(-70, -70)], "stags": []},
}

@export var player: Node3D

const ELITE := {"hp": 3.0, "damage": 1, "size": 1.4}
var _shape: WorldShape
var _wanted := {}            # bounty id -> its beast


func spawn(shape: WorldShape) -> void:
	_shape = shape
	Bounties.changed.connect(_ensure_wanted)
	_ensure_wanted.call_deferred()
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


## Wanted beasts (state/bounties.gd): while you hold the bounty, its beast waits at its spot in this
## region, bigger, tougher and named. Gone once it's dead (it doesn't come back) or you give it up.
func _ensure_wanted() -> void:
	if _shape == null:
		return
	for id: int in _wanted.keys():
		var b := Bounties.find(id)
		if b.is_empty() or Bounties.is_ready(b) or not is_instance_valid(_wanted[id]):
			if is_instance_valid(_wanted[id]):
				_wanted[id].queue_free()
			_wanted.erase(id)
	for b in Bounties.wanted_here():
		if _wanted.has(b["id"]):
			continue
		var at: Vector2 = b["at"]
		var e: CharacterBody3D
		if b["target"] == "boar":
			e = BOAR.instantiate()
		else:
			e = WOLF.instantiate()
			e.shadow = b["target"] == "shadow_wolf"
		e.player = player
		e.home = Vector3(at.x, _shape.height_at(at.x, at.y), at.y)
		e.set_meta("bounty_id", b["id"])
		add_child(e)
		e.global_position = e.home + Vector3(0, 0.5, 0)
		_make_elite(e, b["plural"])
		_wanted[b["id"]] = e


func _make_elite(e: CharacterBody3D, beast_name: String) -> void:
	e.max_health = roundi(e.max_health * ELITE["hp"])
	e.health = e.max_health
	e._damage += ELITE["damage"]
	e.visual.scale *= ELITE["size"]
	for c in e.get_children():                 # a bigger body to hit and be hit by
		if c is CollisionShape3D:
			c.scale = Vector3.ONE * ELITE["size"]
	e.add_to_group("elite")
	var label := Label3D.new()
	label.text = beast_name
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 56
	label.pixel_size = 0.006
	label.outline_size = 14
	label.modulate = Color(1.0, 0.8, 0.35)
	label.outline_modulate = Color(0.25, 0.08, 0.04)
	label.position = Vector3(0, 2.6, 0)
	label.visibility_range_end = 40.0
	e.add_child(label)
