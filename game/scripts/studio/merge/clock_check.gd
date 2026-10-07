extends Node
## merge-enea M1: the one world clock (studio/world/world_clock.gd), in the live village.
##   --studio=village/live --merge-check=clock_check --save-guard --test-save=<fresh name>
## The sky and the village agree on the time of day; locked controls stop the clock and the village; a night's
## sleep (his bed: day_night.set_time) moves the clock, and the village and his day timers follow; the dev skip
## moves it 3 hours; the save holds the clock once ("clock", no "time_of_day"), and reading it back gives the same
## clock. Prints PASS/FAIL lines and "CLOCK complete failures=N".
const Journal := preload("res://scripts/studio/village/journal.gd")
var failed := 0


static func on_device(tree: SceneTree) -> void:
	if tree.root.has_node("ClockCheck"): # a region change reloads the scene and calls this again
		return
	if DisplayServer.get_name() == "headless":
		tree.root.get_node("ItemIcons").set_process(false)
	var probe: Node = load("res://scripts/studio/merge/clock_check.gd").new()
	probe.name = "ClockCheck"
	tree.root.add_child.call_deferred(probe)


func _ready() -> void:
	run.call_deferred()


func check(ok: bool, text: String) -> void:
	print(("PASS clock " if ok else "FAIL clock ") + text)
	if not ok:
		failed += 1


func frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func village_now() -> float:
	var r: Dictionary = VillageSession.village.runtime
	return float(r.now) + float(r.fraction)


func run() -> void:
	await frames(120)
	for _i in 900:
		if VillageSession.village != null and VillageSession.active and get_tree().current_scene.get_node_or_null("WorldEnvironment") != null:
			break
		await get_tree().process_frame
	var sky: Node = get_tree().current_scene.get_node("WorldEnvironment")
	await frames(30)
	var v_tod := fposmod(village_now(), 1440.0) / 1440.0
	check(absf(float(sky.time_of_day) - WorldClock.time_of_day()) < 0.0005 and absf(v_tod - WorldClock.time_of_day()) < 0.002,
		"the sky and the village show the world clock's time of day (%.4f, %.4f, %.4f)" % [float(sky.time_of_day), v_tod, WorldClock.time_of_day()])
	var m0 := float(WorldClock.minute) + WorldClock.fraction
	await frames(60)
	var m1 := float(WorldClock.minute) + WorldClock.fraction
	check(m1 - m0 > 1.5 and m1 - m0 < 6.0, "it runs at 2 game minutes a second (%.2f minutes in 60 frames)" % (m1 - m0))
	Controls.locked = true
	var held := float(WorldClock.minute) + WorldClock.fraction
	var vheld := village_now()
	await frames(45)
	check(float(WorldClock.minute) + WorldClock.fraction == held and village_now() == vheld, "locked controls (a menu) stop the clock and the village")
	Controls.locked = false
	await frames(5)
	var before_v := village_now()
	var before_c := WorldClock.minute
	var day_secs := float(Bounties.get("_day_secs"))
	var t := WorldClock.time_of_day()
	sky.set_time(fposmod(t + 0.4, 1.0))                # a sleep of about 9.6 hours, as his bed does it
	await frames(3)
	var slept := WorldClock.minute - before_c
	check(slept >= 570 and slept <= 580 and village_now() - before_v >= 570.0, "a night's sleep moves the clock (%d minutes) and the village catches up (%.0f)" % [slept, village_now() - before_v])
	check(float(Bounties.get("_day_secs")) - day_secs >= 280.0 or float(Bounties.get("_day_secs")) < day_secs,
		"his day timers follow the world clock (bounties: %.0f -> %.0f s)" % [day_secs, float(Bounties.get("_day_secs"))])
	var c2 := WorldClock.minute
	sky.skip(0.125)
	await frames(2)
	check(WorldClock.minute - c2 >= 180 and WorldClock.minute - c2 <= 182, "the dev skip moves it 3 hours (%d)" % (WorldClock.minute - c2))
	await frames(10)
	var error: int = SaveGame.save_game()
	await frames(3)
	var path: String = SaveGame.get("_path")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var replayed: Variant = Journal.replay(data, path + ".journal") if data is Dictionary else null
	var clock: Variant = replayed.get("clock") if replayed is Dictionary else null
	check(error == OK and clock is Dictionary and not (replayed as Dictionary).has("time_of_day"), "the save holds the clock once (\"clock\", no time_of_day)")
	if clock is Dictionary:
		var saved_minute := int(clock.minute)
		var minute := WorldClock.minute
		var off: Dictionary = WorldClock.offsets.duplicate()
		WorldClock.load_data(replayed)
		check(WorldClock.minute == saved_minute and absi(saved_minute - minute) <= 1 and WorldClock.offsets == off, "read back, it is the same clock with the same village offset")
	_done()


func _done() -> void:
	print("CLOCK complete failures=%d" % failed)
	get_tree().quit(0 if failed == 0 else 1)
