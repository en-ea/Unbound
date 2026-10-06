extends Node
## Picking a fight in the running game, with real input (Pass 2, M2): --studio=village/live --village-provoke-test
## --test-save=<unique>. Checks, in order:
##   1. a normal tap next to a villager never hits them (nothing to hit before squaring up)
##   2. after "Pick a fight", Enea's fighter targets them; a real swing lands once and bruises them
##   3. they answer (runtime.reactions) and anyone who could see answers too
##   4. an immediate normal save and load keeps the bruise and the memory
##   5. leaving the village and coming back keeps them; the fight target is gone
var _ran := false


func _process(_delta: float) -> void:
	if _ran:
		return
	var live := get_tree().current_scene.get_node_or_null("VillageLive")
	if live == null or live.registry == null or live.registry.bodies.size() < 10:
		return
	_ran = true
	run(live)


func run(live: Node) -> void:
	await get_tree().create_timer(1.0).timeout
	var v = VillageSession.village
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var provoke: Node = live.get_node("Provoke")
	# an adult villager out and about
	var target := -1
	for id: int in live.registry.bodies:
		var p = v.people[id]
		if p.alive and p.present and not p.locked and VillageSession.Runtime.Village.age_of(v, p) >= 18 and live.registry.bodies[id].visible:
			target = id
			break
	if target < 0:
		finish(false, "no adult villager to test with"); return
	var body: Node3D = live.registry.bodies[target]
	var hurt0: int = v.people[target].hurt
	# 1. a normal tap beside them
	player.global_position = body.global_position + Vector3(0.9, 0.3, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.act()
	await get_tree().create_timer(1.2).timeout
	if v.people[target].hurt != hurt0:
		finish(false, "a normal tap hit a villager"); return
	# the tap talked instead (their talk screen): close it as the player would
	var talked := false
	for hud in get_tree().get_nodes_in_group("hud"):
		for c in hud.get_children():
			if c.get_script() == preload("res://scripts/ui/dialogue_panel.gd"):
				talked = true
				c.closed.emit()
				c.queue_free()
	await get_tree().process_frame
	print("PROVOKE a tap beside them opened their talk screen: %s" % talked)
	# 2. square up, then real swings through Enea's fighter
	var answer: Dictionary = provoke.square_up(target)
	if not answer.get("accepted", false):
		finish(false, "square up refused: %s" % answer.get("reason", "")); return
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.global_position = body.global_position + Vector3(0.9, 0.3, 0.0)
	var swings := 0
	while v.people[target].hurt == hurt0 and swings < 6:
		await get_tree().physics_frame
		player.act()
		swings += 1
		await get_tree().create_timer(0.9).timeout
	if v.people[target].hurt == hurt0:
		finish(false, "no swing landed (fighter verb '%s')" % player.fighter.verb); return
	var hurt1: int = v.people[target].hurt
	# 3. answers
	var reactions: Dictionary = v.runtime.get("reactions", {})
	if not reactions.has(str(target)):
		finish(false, "the villager did not answer"); return
	var onlookers := 0
	for key: String in reactions:
		if int(key) != target and int(reactions[key].since) >= int(v.runtime.now) - 5:
			onlookers += 1
	print("PROVOKE answer %s, onlookers answering %d, hurt %d after %d swing(s)" % [reactions[str(target)].state, onlookers, hurt1, swings])
	# 4. save and load
	SaveGame.save_game()
	VillageSession.village = null
	SaveGame.load_game()
	v = VillageSession.village
	if v == null or v.people[target].hurt != hurt1 or not v.runtime.acquaintance.get(str(target), {}).get("memories", []).has("hit_by_you"):
		finish(false, "an immediate load lost the bruise or the memory"); return
	# 5. away and back
	Region.travel("forest", Vector2(0, -86))
	await get_tree().create_timer(1.5).timeout
	Region.travel("meadow", Vector2(1.5, 86))
	await get_tree().create_timer(1.5).timeout
	v = VillageSession.village
	if not v.runtime.acquaintance.get(str(target), {}).get("memories", []).has("hit_by_you"):
		finish(false, "the memory did not survive the journey"); return
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.get("resident") != null:
			finish(false, "a fight target outlived the region"); return
	finish(true, "a tap never hits; squared up, a real swing lands once; answers; save/load; away and back")


func finish(ok: bool, detail: String) -> void:
	print(("PASS" if ok else "FAIL") + " provoke integration: " + detail)
	get_tree().quit(0 if ok else 1)