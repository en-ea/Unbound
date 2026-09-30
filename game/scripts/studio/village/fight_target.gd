extends Node3D
## A villager the player has squared up to, as Enea's combat sees an enemy (group "enemy": is_alive(), take_hit()).
## It follows the villager's body; its blows go to the village's rules through provoke.gd, never straight to a
## health bar. It exists only while squared up (provoke.gd), so a normal tap can never hit a villager.
var provoke: Node
var resident := -1
var body: Node3D


func _ready() -> void:
	add_to_group("enemy")


func _process(_delta: float) -> void:
	if is_instance_valid(body):
		global_position = body.global_position


func is_alive() -> bool:
	var v = VillageSession.village
	if v == null or resident < 0:
		return false
	var p = v.people[resident]
	return p.alive and p.present and p.down_until <= int(v.runtime.now)


## Villagers are not fighters: no fight music for a scuffle (Enea's music checks this).
func is_engaged() -> bool:
	return false


func take_hit(_from: Vector3, damage := 1, push := 1.0) -> void:
	var result: Dictionary = provoke.landed(resident, damage, push > 1.0)
	if result.get("accepted", false) and is_instance_valid(body) and body.has_method("flash"):
		body.flash()