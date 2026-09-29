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
	player.act()
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
	finish(v == VillageSession.village and v.people[target].alive and not v.people[target].locked, "real input twice, immediate save/load, midnight, actual region reload and return")

func finish(ok: bool, detail: String) -> void:
	print(("PASS" if ok else "FAIL") + " rescue integration: " + detail)
	get_tree().quit(0 if ok else 1)
