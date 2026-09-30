extends Node
## Deterministic generated scenarios, expressly separate from normal cadence. No invented outcomes.
const Runtime := preload("res://scripts/studio/village/sim/runtime.gd")
const Fixtures := preload("res://scripts/studio/village/sim/actions_test.gd")
var folder := "user://village-captures"
var _player: Node3D
var _index := []

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--village-capture="):
			folder = arg.trim_prefix("--village-capture=")
	DirAccess.make_dir_recursive_absolute(folder)
	run.call_deferred()

func photo(label: String, at: Vector2) -> void:
	_player.global_position = Vector3(at.x, WorldShape.new().height_at(at.x, at.y), at.y)
	get_tree().call_group("camera_rig", "snap")
	for _i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(folder.path_join(label + ".png"))
	var live := get_tree().current_scene.get_node("VillageLive")
	_index.append({"shot": label, "error": err, "seed": VillageSession.village.seed, "minute": VillageSession.village.runtime.now,
		"event": live._event, "cue": live._label.text})
	print("CAPTURE ", label, " ", err)

func replace(v: Runtime.S.Village, e: Dictionary) -> Node:
	var old := get_tree().current_scene.get_node("VillageLive")
	old._close()
	get_tree().current_scene.remove_child(old)
	old.queue_free()
	VillageSession.village = v
	var live := load("res://scripts/studio/village/live.gd").new() as Node
	live.name = "VillageLive"
	get_tree().current_scene.add_child(live)
	live._open(e)
	return live

func seek(live: Node, minute: int) -> void:
	var v = VillageSession.village
	var st := Runtime.staging(v, live._event)
	Runtime.advance(v, minute)
	live._stage._player = null
	live._stage.skip_to(float(minute - int(st.day) * 1440))
	live._stage._player = _player
	live._stage._offer_free()
	live._process(0.0)

func theft_hearing() -> Array:
	for seed in range(1, 25):
		var v := Runtime.create(seed, {"anchored": true})
		for _day in 100:
			Runtime.advance(v, Runtime.next_dawn(v))
			for e: Dictionary in v.runtime.events:
				if e.type != "hearing" or Runtime.terminal(e):
					continue
				var crime := v.crimes[v.cases[e.source.case_id].crime]
				if crime.act == "theft" and crime.trace_at >= 0:
					Runtime.advance(v, maxi(int(v.runtime.now), int(e.from)))
					return [v, e]
	return Fixtures._hearing()

func run() -> void:
	await get_tree().create_timer(4.0).timeout
	VillageSession.active = false
	VillageSession.background = false
	Controls.locked = false
	_player = get_tree().get_first_node_in_group("player")
	await photo("01-ordinary-residents", Vector2(0, 24))
	var pair := theft_hearing()
	var v: Runtime.S.Village = pair[0]
	var e: Dictionary = pair[1]
	var live := replace(v, e)
	seek(live, int(e.from) + 70)
	await photo("02-hearing", live._stage._authority.pos + Vector2(0, 2))
	var params: Dictionary = live._parameters("inspect")
	var trace: Vector2 = live.registry.place(params.get("place", "square"))
	await photo("03-evidence-opportunity", trace + Vector2(0, 1))
	# Generated public act; same action button as normal gameplay.
	v = Runtime.create(1)
	e = {}
	for _day in 150:
		Runtime.advance(v, Runtime.next_dawn(v))
		for candidate: Dictionary in v.runtime.events:
			if candidate.type == "public" and not Runtime.terminal(candidate) and candidate.place in ["pillory", "gallows", "stake"]:
				e = candidate; break
		if not e.is_empty():
			break
	if e.is_empty():
		push_error("No public capture fixture")
		get_tree().quit(1); return
	Runtime.advance(v, maxi(int(v.runtime.now), int(e.from)))
	live = replace(v, e)
	seek(live, int(e.deadline) - 1)
	await photo("04-public-act", live._stage.rescue_spot())
	live._stage._offer_free()
	_player.act()
	await photo("05-rescue-accepted", live._stage.rescue_spot())
	Runtime.advance(v, int(e.end) + 125)
	live._process(0.0)
	await photo("06-saved-resident-refuge", Vector2(-70, -37))
	var triple := Fixtures._rite()
	v = triple[0]; e = triple[1]
	live = replace(v, e)
	seek(live, int(e.deadline) - 5)
	Inventory.add("wood", 1)
	await photo("07-forebears-and-rite", live._stage.rescue_spot())
	live._stage._offer_free()
	_player.act()
	Runtime.Storm.storm_recedes(v, triple[2])
	Runtime.advance(v, int(v.runtime.now))
	live._process(0.0)
	await photo("08-storm-recedes-rescue-kept", Vector2(0, 24))
	FileAccess.open(folder.path_join("index.json"), FileAccess.WRITE).store_string(JSON.stringify(_index, "  "))
	get_tree().quit()
