extends Node
## Real normal-save and input checks, explicitly isolated from the owner's files.
const Runtime := preload("res://scripts/studio/village/sim/runtime.gd")
const Fixtures := preload("res://scripts/studio/village/sim/actions_test.gd")
const Codec := preload("res://scripts/studio/village/sim/save.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok:
		failures.append(message)

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	if not SaveGame._path.begins_with("user://studio-test-"):
		push_error("Checks require --test-save=<unique-name>")
		get_tree().quit(1)
		return
	await get_tree().create_timer(2.0).timeout
	VillageSession.active = false
	VillageSession.background = false
	var player := get_tree().get_first_node_in_group("player")
	var v = VillageSession.village
	Money.load_data(31)
	Inventory.add("wood", 7)
	SaveGame.save_game()
	var original: Dictionary = SaveGame._read()
	check(original.has("village") and Codec.valid(original.village), "normal atomic save includes valid village")
	var legacy := original.duplicate(true)
	legacy.erase("village")
	FileAccess.open(SaveGame._path, FileAccess.WRITE).store_string(JSON.stringify(legacy))
	VillageSession.village = null
	SaveGame.load_game()
	check(Money.coins == 31 and VillageSession.village == null and Inventory.count("wood") >= 7, "old save retains economy and awaits fresh village")
	VillageSession.village = v
	SaveGame.save_game()
	SaveGame.save_game() # completed backup containing the same accepted state
	FileAccess.open(SaveGame._path, FileAccess.WRITE).store_string('{"version":1,"village":{"version":1,"state":null},"coins":0}')
	var backup: Dictionary = SaveGame._read()
	check(backup.get("coins", -1) == 31 and backup.has("village"), "malformed village falls back to valid atomic backup")
	FileAccess.open(SaveGame._path, FileAccess.WRITE).store_string('{"version":')
	check(SaveGame._read().get("coins", -1) == 31, "truncated normal file falls back to backup")
	var isolated := SaveGame._path
	SaveGame._path = isolated + "-damaged"
	var damaged := original.duplicate(true)
	damaged.village.state.fields.people = ["bad resident"]
	FileAccess.open(SaveGame._path, FileAccess.WRITE).store_string(JSON.stringify(damaged))
	VillageSession.village = null
	SaveGame.load_game()
	check(Money.coins == 31 and Inventory.count("wood") >= 7 and VillageSession.village == null and not VillageSession.recovery_notice.is_empty(), "no valid village backup preserves core progress and reports recovery")
	SaveGame._path = isolated
	VillageSession.village = v
	SaveGame.save_game()
	# Controls and background freeze the same clock, including stage projectile time.
	var minute := int(v.runtime.now)
	VillageSession.active = true
	Controls.locked = true
	await get_tree().create_timer(1.1).timeout
	check(int(v.runtime.now) == minute, "menu pause freezes authoritative minutes")
	Controls.locked = false
	VillageSession.background = true
	await get_tree().create_timer(1.1).timeout
	check(int(v.runtime.now) == minute, "background freezes authoritative minutes")
	VillageSession.background = false
	VillageSession.active = false
	# Existing gathering through the real player button, using a real resource away from stations.
	var resource := -1
	for i in WorldResources._nodes.size():
		var data := WorldResources.get_node_data(i)
		if data.hits_left > 0 and absf(data.pos.x) > 20.0:
			resource = i; break
	if resource >= 0:
		var data := WorldResources.get_node_data(resource)
		player.global_position = data.pos + Vector3(0.5, 0.0, 0.0)
		await get_tree().physics_frame
		await get_tree().physics_frame
		player.fighter.verb = ""
		player.gatherer._busy = 0.0
		var before := int(data.hits_left)
		player.act()
		await get_tree().create_timer(1.1).timeout
		check(int(data.hits_left) < before, "real action button still gathers a world resource")
	else:
		check(false, "no real gathering fixture")
	# Combat priority remains outside a rescue. A real swing must start; no enemy fixture is fabricated.
	player.fighter.verb = "Attack"
	player.fighter._busy = 0.0
	player.act()
	check(player.fighter.is_busy(), "combat action still starts outside a rescue")
	player.fighter.cancel()
	player._down = 1.0
	player.act()
	check(not player.fighter.is_busy(), "downed player cannot act")
	player._down = 0.0
	Controls.locked = true
	player.act()
	check(not player.fighter.is_busy(), "locked controls cannot act")
	Controls.locked = false
	# Accepted payment through the actual live adapter, twice, then the normal disk load.
	player.fighter.verb = ""
	for station in get_tree().get_nodes_in_group("interactable"):
		if station.verb == "Trade":
			player.global_position = station.global_position + Vector3(0, 0, 0.5)
			player.act()
			check(Controls.locked, "ordinary merchant opens from the real action button")
			var hud := get_tree().get_first_node_in_group("hud")
			for child in hud.get_children():
				if child.get_script() != null and child.get_script().resource_path.ends_with("shop_panel.gd"):
					child._close()
			check(not Controls.locked, "merchant closes back into play")
			break
	for accepts in [true, false]:
		var live := get_tree().current_scene.get_node("VillageLive")
		live._close()
		live.queue_free()
		await get_tree().process_frame
		var fixture := Fixtures._hearing()
		VillageSession.village = fixture[0]
		v = VillageSession.village
		var e: Dictionary = fixture[1]
		live = load("res://scripts/studio/village/live.gd").new()
		live.name = "VillageLive"
		get_tree().current_scene.add_child(live)
		live._open(e)
		var judge = v.people[int(Runtime.staging(v, int(e.id)).roles.authority)]
		judge.traits[Runtime.C.GREED] = 100 if accepts else 0
		judge.traits[Runtime.C.HONESTY] = 0 if accepts else 100
		judge.values[Runtime.C.V_LAW] = 50
		Money.load_data(31)
		var at: Vector2 = live._stage._authority.pos
		player.global_position = Vector3(at.x, WorldShape.new().height_at(at.x, at.y), at.y)
		var receipt: Dictionary = live._act("bribe", {})
		live._act("bribe", {})
		check(receipt.accepted and Money.coins == (26 if accepts else 31), "live bribe single debit, accepts=%s" % accepts)
		VillageSession.village = null
		SaveGame.load_game()
		check(Money.coins == (26 if accepts else 31) and VillageSession.village != null, "normal reload preserves bribe and wallet")
	print("CHECKS complete failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
