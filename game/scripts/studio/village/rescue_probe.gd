extends Node
## Exercises the real button, atomic save and region lifecycle with --test-save=rescue.
var _ran := false

func _process(_delta: float) -> void:
	if _ran:
		return
	var live := get_tree().current_scene.get_node_or_null("VillageLive")
	if live == null or live._stage == null:
		return
	_ran = true
	run(live)

func run(live: Node) -> void:
	var runtime = VillageSession.Runtime
	var v = VillageSession.village
	var e: Dictionary = runtime.event_by_id(v, live._event)
	var target := int(e.victim)
	var st: Dictionary = runtime.staging(v, int(e.id))
	runtime.advance(v, int(e.deadline) - 1)
	live._stage._player = null
	live._stage.skip_to(float(int(v.runtime.now) - int(st.day) * 1440))
	var player := get_tree().get_first_node_in_group("player")
	live._stage._player = player
	var victim = live._stage._victim
	player.global_position = Vector3(victim.pos.x, victim.y, victim.pos.y + 0.9)
	Controls.locked = false
	live._stage._offer_free()
	player.fighter.verb = "Attack" # a nearby combat opportunity must not steal an offered rescue
	player.fighter._busy = 0.0
	player.act()
	if player.fighter.is_busy():
		finish(false, "combat stole the rescue action")
		return
	player.fighter.verb = ""
	player.act()
	if e.outcome != "rescued" or v.people[target].locked or victim.locked:
		finish(false, "button did not immediately release the same resident")
		return
	SaveGame.save_game()
	var saved: Dictionary = SaveGame._read()
	if not saved.has("village"):
		finish(false, "real save path omitted village (use --test-save=rescue)")
		return
	VillageSession.village = null
	SaveGame.load_game()
	v = VillageSession.village
	if v == null or not v.people[target].alive or not v.runtime.residents.has(str(target)):
		finish(false, "immediate load lost rescue")
		return
	runtime.advance(v, int(v.runtime.now) + 1441)
	Region.travel("forest", Vector2(0, -86))
	await get_tree().create_timer(1.5).timeout
	if Region.current != "forest" or not v.people[target].alive:
		finish(false, "region departure lost rescue")
		return
	Region.travel("meadow", Vector2(1.5, 86))
	await get_tree().create_timer(1.5).timeout
	if v != VillageSession.village or not v.people[target].alive or v.people[target].locked:
		finish(false, "region return changed rescued resident")
		return
	print("PASS rescue integration: real input twice, immediate save/load, midnight, actual region reload and return")
	await boundaries()

func boundaries() -> void:
	# A generated throw in the real renderer, not a fabricated projectile or a clock-only assertion.
	var runtime = VillageSession.Runtime
	var fixtures = load("res://scripts/studio/village/sim/lifecycle_test.gd")
	var codec = VillageSession.Save
	var pair: Array = fixtures._find("public", 2)
	if pair.is_empty():
		finish(false, "no generated throw fixture"); return
	VillageSession.active = false
	var live := get_tree().current_scene.get_node("VillageLive")
	live._close()
	get_tree().current_scene.remove_child(live)
	live.queue_free()
	VillageSession.village = pair[0]
	var v = VillageSession.village
	var e: Dictionary = pair[1]
	live = load("res://scripts/studio/village/live.gd").new()
	live.name = "VillageLive"
	get_tree().current_scene.add_child(live)
	live._open(e)
	var player := get_tree().get_first_node_in_group("player")
	player.global_position = Vector3(1, 0, 24)
	var shot = null
	# Run the existing staging in small logical increments until an actual prop is airborne.
	for _i in 6000:
		v.runtime.fraction += 0.1
		if v.runtime.fraction >= 1.0:
			v.runtime.fraction -= 1.0
			runtime.advance(v, int(v.runtime.now) + 1)
		live._process(0.0)
		if live._stage == null or runtime.terminal(e): break
		live._stage._process(0.0)
		for candidate in live._stage._shots:
			if candidate.phase == 1:
				shot = candidate; break
		if shot != null: break
	if shot == null:
		finish(false, "generated prop never became airborne"); return
	var stage = live._stage
	var before := [int(v.runtime.now), float(v.runtime.fraction), shot.phase, shot.t, shot.node.position, player.health, str(e.outcome)]
	Controls.locked = true
	VillageSession.active = true
	await get_tree().create_timer(0.8).timeout
	var paused := [int(v.runtime.now), float(v.runtime.fraction), shot.phase, shot.t, shot.node.position, player.health, str(e.outcome)]
	if before != paused:
		finish(false, "menu pause advanced an airborne prop, health or consequence"); return
	VillageSession.background = true
	Controls.locked = false
	await get_tree().create_timer(0.8).timeout
	var background := [int(v.runtime.now), float(v.runtime.fraction), shot.phase, shot.t, shot.node.position, player.health, str(e.outcome)]
	if before != background:
		finish(false, "background advanced an airborne prop, health or consequence"); return
	VillageSession.active = false
	VillageSession.background = false
	print("PASS rescue integration: actual airborne prop, player health and outcome frozen by menu and background")
	# Leave an untouched active event, return before the deadline, then resolve while away.
	var event_id := int(e.id)
	Region.travel("forest", Vector2(0, -86))
	await get_tree().create_timer(1.5).timeout
	VillageSession.active = false
	Region.travel("meadow", Vector2(1.5, 86))
	await get_tree().create_timer(1.5).timeout
	VillageSession.active = false
	live = get_tree().current_scene.get_node("VillageLive")
	if VillageSession.village != v or runtime.terminal(e) or live._event != event_id or live._stage == stage:
		finish(false, "active event failed to restore before deadline"); return
	# The headless clone and region-absent world take the same logical jump.
	var headless = codec.from_data(JSON.parse_string(JSON.stringify(codec.to_data(v))))
	Region.travel("forest", Vector2(0, -86))
	await get_tree().create_timer(1.5).timeout
	VillageSession.active = false
	runtime.set_player(headless, false, 0, 0)   # (the player has left the village; the clone must know that too)
	runtime.advance(v, int(e.deadline) + 1)
	runtime.advance(headless, int(e.deadline) + 1)
	# Scene frames may have advanced fractions while fading in. Only logical advances are compared.
	headless.runtime.fraction = v.runtime.fraction
	if not fixtures._same(v, headless):
		finish(false, "offscreen resolution differs from headless continuation"); return
	var outcome := str(e.outcome)
	Region.travel("meadow", Vector2(1.5, 86))
	await get_tree().create_timer(1.5).timeout
	VillageSession.active = false
	live = get_tree().current_scene.get_node("VillageLive")
	if not runtime.terminal(e) or str(e.outcome) != outcome or live._event == event_id:
		finish(false, "return after deadline resurrected expired stage"); return
	finish(true, "active region departure and return before/after deadline; headless canonical consequence; no stale stage")

func finish(ok: bool, detail: String) -> void:
	print(("PASS" if ok else "FAIL") + " rescue integration: " + detail)
	get_tree().quit(0 if ok else 1)
