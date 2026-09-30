extends RefCounted
## The one door presentation uses for world actions (talk, square_up, strike, shove, give): builds
## the request, measures the distance from the player's body to the resident's body, asks the village, then
## charges any costs and saves the normal game at once (accepted state and belongings share one save).
##
##   PlayerActs.request(player, registry, "talk", resident_id) -> result (world_actions.gd)
##
## A new action id per press ("verb:target:minute:sequence", or the caller's press_id): pressing again is a
## new action; a repeated delivery of the same press (the same id) is harmless.
const WorldActions := preload("res://scripts/studio/village/sim/world_actions.gd")


static func request(player: Node3D, registry: Node, verb: String, target: int, parameters: Dictionary = {}) -> Dictionary:
	var v = VillageSession.village
	if v == null or not VillageSession.active or VillageSession.background or Controls.locked:
		return {"accepted": false, "reason": "unavailable"}
	if not registry.bodies.has(target):
		return {"accepted": false, "reason": "no one there"}
	var body: Node3D = registry.bodies[target]
	var distance := Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(body.global_position.x, body.global_position.z))
	# a caller with its own press identity (a swing) passes parameters.press_id, so a re-delivered press is a duplicate
	var press: String = str(parameters.get("press_id", "%d:%d" % [int(v.runtime.now), int(v.runtime.sequence)]))
	var req := {"action_id": "%s:%d:%s" % [verb, target, press],
		"player_id": "player:local", "village_id": v.runtime.village, "logical_time": v.runtime.now,
		"verb": verb, "target": target, "parameters": parameters}
	var context := {"distance_dm": int(ceil(distance * 10.0)), "witnesses": parameters.get("witnesses", [])}
	if verb == "give":
		var item: String = parameters.get("item", "")
		context.have = Money.coins if item == "coins" else Inventory.count(item)
		context.food = Food.FOODS.has(item)
	var result := WorldActions.act(v, req, context)
	if result.accepted and not result.get("duplicate", false):
		if int(result.get("coins", 0)) > 0:
			Money.spend(int(result.coins))
		if verb == "give":   # the gift leaves the player's bag or purse
			if result.item == "coins":
				Money.spend(int(result.count))
			else:
				Inventory.remove(str(result.item), int(result.count))
		SaveGame.save_game()
	return result
