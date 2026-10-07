extends Node
## Studio: water class probe. Fires each Tidecaller ability on his enemies (and, from unit 5, on villagers and
## things) in the live village, through the same player path the arc row uses (abilities.use with an aim).
##   --studio=village/live --merge-check=../water/water_probe --save-guard --water=all --test-save=<fresh name>
## --water=<parts>: drown, tempest, rime, trait (comma separated) or all. Prints "PASS water ..." / "FAIL water ..."
## lines and "WATER complete failures=N".
const Wet := preload("res://scripts/studio/water/wet.gd")
const BOAR := preload("res://scenes/boar.tscn")

var failed := 0
var player: CharacterBody3D
var tide: Tidecaller
var parts: PackedStringArray = []
var _spawned: Array[Node] = []
var start_yaw := 0.0            # the player's facing at the start: the camera behind it sees a clear meadow
var shots := ""                  # --water-shots=<dir>: save a frame at each big moment (rendered runs only)


static func on_device(tree: SceneTree) -> void:
	if tree.root.has_node("WaterProbe"):
		return
	if DisplayServer.get_name() == "headless":
		tree.root.get_node("ItemIcons").set_process(false)
	var probe: Node = load("res://scripts/studio/water/water_probe.gd").new()
	probe.name = "WaterProbe"
	tree.root.add_child.call_deferred(probe)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--water="):
			parts = arg.trim_prefix("--water=").split(",")
		if arg.begins_with("--water-shots="):
			shots = arg.trim_prefix("--water-shots=")
	if parts.is_empty() or "all" in parts:
		parts = ["drown", "tempest", "rime", "trait", "talents", "people"]
	run.call_deferred()


## The probe tests the water, not the fight: your hearts stay full (bandits do fight back).
func _process(_delta: float) -> void:
	if player != null and not player.is_down() and player.health < player.MAX_HEALTH:
		player.heal_full()


func check(ok: bool, text: String) -> void:
	print(("PASS water " if ok else "FAIL water ") + text)
	if not ok:
		failed += 1


func frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout


func run() -> void:
	await frames(120)
	for _i in 900:
		if VillageSession.village != null and VillageSession.active and get_tree().get_first_node_in_group("player") != null:
			break
		await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	await frames(30)
	Classes.choose("tidecaller")
	tide = player.abilities.tidecaller
	start_yaw = player.visual.rotation.y
	check(Classes.current == "tidecaller" and Classes.abilities() == ["drown", "tempest", "rime_wave"], "the Tidecaller is chosen with its three abilities")
	if "drown" in parts:
		await drown_part()
	if "tempest" in parts:
		await tempest_part()
	if "rime" in parts:
		await rime_part()
	if "trait" in parts:
		await trait_part()
	if "talents" in parts:
		await talents_part()
	if "people" in parts:
		await people_part()
	if "cost" in parts:
		await cost_part()
	print("WATER complete failures=%d" % failed)
	get_tree().quit(1 if failed > 0 else 0)


# --- helpers -------------------------------------------------------------------------------------

func shot(name: String) -> void:
	if shots == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	print("WATER shot %s %s" % [name, error_string(img.save_png(shots.path_join(name + ".png")))])


## The camera behind the player, looking at `at` (so a board frames the act).
func frame(at: Vector3, turn := PI) -> void:
	var to := at - player.global_position
	player.visual.rotation.y = atan2(to.x, to.z)
	get_tree().call_group("camera_rig", "_set_yaw", player.visual.rotation.y + turn)
	get_tree().call_group("camera_rig", "snap")

func ahead(d: float, side := 0.0) -> Vector3:
	var f := Vector3(sin(player.visual.rotation.y), 0, cos(player.visual.rotation.y))
	var at := player.global_position + f * d + f.cross(Vector3.UP) * side
	if Carcass.shape:
		at.y = Carcass.shape.height_at(at.x, at.z)
	return at


func bandit(at: Vector3) -> Node3D:
	var b := Bandit.new()
	b.kind = "cutthroat"
	b.player = player
	b.post = at
	b.look = BanditLooks.make(0, 7)
	player.get_parent().add_child(b)
	b.global_position = at + Vector3(0, 0.3, 0)
	_spawned.append(b)
	return b


func boar(at: Vector3) -> Node3D:
	var e: CharacterBody3D = BOAR.instantiate()
	e.player = player
	e.home = at
	player.get_parent().add_child(e)
	e.global_position = at + Vector3(0, 0.5, 0)
	_spawned.append(e)
	return e


## Foes leave the fight first (out of the enemy group, so his lock-on and the hands let go of them), then go.
func clear_foes() -> void:
	var gone: Array[Node] = []
	for e in _spawned:
		if is_instance_valid(e) and not e.scene_file_path.ends_with(".glb"):     # carriers stay (their facts are saved)
			e.remove_from_group("enemy")
			gone.append(e)
	_spawned.clear()
	await seconds(0.7)        # past the village crowd's 0.5 s look for nearby animals (residents.gd OTHERS_EVERY)
	for e in gone:
		if is_instance_valid(e):
			e.queue_free()
	Wet.clear()
	await frames(5)


func cast(ability: String, at: Vector3) -> void:
	Classes.start_cooldown(ability, 0.0)
	player.abilities.use(ability, {"at": at, "dir": (at - player.global_position).normalized(), "press_id": "water-probe:%s:%d" % [ability, Time.get_ticks_usec()]})


# --- Drown ---------------------------------------------------------------------------------------

func drown_part() -> void:
	var a := bandit(ahead(6.0))
	var b := bandit(ahead(6.0, 1.6))
	frame(a.global_position)
	await seconds(1.0)
	var rest: float = a.visual.position.y
	var h0: int = a.health
	check(not Wet.is_wet(b), "the bystander starts dry")
	cast("drown", a.global_position)
	await seconds(0.9)
	check(tide.is_held(a) and not a.is_physics_processing(), "Drown holds the marked bandit (its own brain paused)")
	check(a.visual.position.y > rest + 1.2, "it is lifted into the air (%.2f m up)" % (a.visual.position.y - rest))
	check(not tide.is_held(b), "only the marked one is taken")
	await shot("drown-held")
	var h1: int = a.health
	await seconds(2.0)
	var h2: int = a.health
	check(h1 < h0 or h2 < h1, "the water trickles at its health while held (%d -> %d -> %d)" % [h0, h1, h2])
	check(tide.is_held(a), "still held at 2.9 s")
	await seconds(2.8)
	check(not is_instance_valid(a) or not tide.is_held(a), "let go after the hold")
	await shot("drown-slam")
	if is_instance_valid(a):
		check(a.is_physics_processing() and absf(a.visual.position.y - rest) < 0.05, "slammed back to the ground, its brain back on")
		check(a.health < h2, "the slam hurts (%d -> %d)" % [h2, a.health])
		check(Wet.is_wet(a) and Wet.wet_left(a) > 10.0, "it is wet, the clock starting at the slam (%.1f s left)" % Wet.wet_left(a))
	check(is_instance_valid(b) and Wet.is_wet(b), "the slam's spray wets the bandit standing beside it")
	await clear_foes()
	var c := boar(ahead(5.0))
	await seconds(0.8)
	FireFX.ignite(c, 8.0)
	await frames(2)
	check(c.get_node_or_null("Burning") != null, "the boar is burning")
	cast("drown", c.global_position)
	await frames(3)
	check(c.get_node_or_null("Burning") == null or c.get_node("Burning").is_queued_for_deletion(), "Drown puts the burning boar out at once")
	await seconds(6.0)
	await clear_foes()
	cast("drown", ahead(6.0))
	await frames(2)
	check(Classes.cooldown_left("drown") * Classes.cooldown_of("drown") <= 1.05, "with no one there, Drown splashes and comes back in a second")


# --- Tempest -------------------------------------------------------------------------------------

func tempest_part() -> void:
	await clear_foes()
	var a := bandit(ahead(3.0))
	var b := bandit(ahead(3.0, 1.8))
	var c := boar(ahead(3.5, -2.0))
	frame(a.global_position)
	await seconds(1.0)
	Wet.mark(a)
	FireFX.ignite(c, 10.0)
	var ha: int = a.health
	var hb: int = b.health
	var hearts: int = player.health
	cast("tempest", player.global_position)
	await seconds(0.62)
	await shot("tempest-bolt")
	await seconds(0.18)
	check(tide.bolts >= 1 and tide.struck[0] == a, "the first bolt seeks the wet bandit (%d bolt(s))" % tide.bolts)
	check(a.health < ha and b.health == hb, "it strikes hard (%d -> %d), the dry one untouched yet" % [ha, a.health])
	check(not Wet.is_wet(b), "the dry bandit is still dry before the rain")
	await shot("tempest")
	await seconds(1.2)
	check(Wet.is_wet(b) and Wet.is_wet(c), "the rain soaks everyone under the cloud")
	check(c.get_node_or_null("Burning") == null or c.get_node("Burning").is_queued_for_deletion(), "the rain puts out the burning boar")
	check(b.health < hb, "the rain stings (%d -> %d)" % [hb, b.health])
	await seconds(3.0)
	check(tide.chains >= 1, "lightning leapt between wet foes (%d chain(s) in %d bolts)" % [tide.chains, tide.bolts])
	check(not tide.struck.has(player) and tide.struck.all(func(e: Node) -> bool: return not is_instance_valid(e) or not e.get_meta("crowd_ignore", false)),
		"lightning never struck the caster or a villager's body")
	await seconds(3.5)
	check(not is_instance_valid(tide.storm), "the storm passes after its time")
	check(not player.is_down(), "the caster is standing after the storm (hearts kept full by the probe: %d at the start)" % hearts)
	await clear_foes()
	await things_part()


## Rain on things: a burning fence (lit by the Pyromancer's own route, Contact.things burn) goes out and is soaked.
func things_part() -> void:
	const Things := preload("res://scripts/studio/village/things.gd")
	const Contact := preload("res://scripts/studio/village/contact.gd")
	const ThingFacts := preload("res://scripts/studio/village/sim/thing_facts.gd")
	# A fence in front of you, built as the game builds a yard's carriers (Body's things_play does the same).
	var at := ahead(2.6)
	var thing: Node3D = preload("res://scripts/world/treasure.gd")._solid((load("res://assets/props/fence.glb") as PackedScene).instantiate())
	get_tree().current_scene.add_child(thing)
	thing.global_position = Vector3(at.x, WorldShape.new().height_at(at.x, at.z), at.z)
	_spawned.append(thing)
	await frames(2)
	var pick := ""
	for id: String in Things.found(get_tree()):
		if Things.found(get_tree())[id] == thing:
			pick = id
	check(pick != "", "a fence stands in front of you (%s)" % pick)
	if pick == "":
		return
	frame(thing.global_position)
	get_tree().call_group("camera_rig", "_set_yaw", player.visual.rotation.y + PI * 0.75)    # the fence from the side
	await seconds(0.6)
	var lit: Dictionary = Contact.things(get_tree(), "player:local", player, "burn", {"press_id": "water-probe:light", "heat": 650},
		thing.global_position, 1.0)
	await frames(2)
	var v = VillageSession.village
	check(not ThingFacts.get_fact(v, pick, "burning").is_empty(), "%s is burning (%s)" % [pick, str(lit.get("reason", "accepted"))])
	cast("tempest", player.global_position)
	await seconds(2.4)
	await shot("tempest-fence")
	check(ThingFacts.get_fact(v, pick, "burning").is_empty(), "the rain puts the burning %s out" % pick.get_slice("@", 0))
	var soaked: Dictionary = ThingFacts.get_fact(v, pick, "soaked")
	check(not soaked.is_empty() and str(soaked.get("method", "")) == "rain", "and it is soaked by rain (the world's rain, thing_actions.rain)")
	await seconds(6.0)


# --- Rime Wave -----------------------------------------------------------------------------------

func rime_part() -> void:
	await clear_foes()
	var w := bandit(ahead(1.5))
	var d := bandit(ahead(4.0, -1.2))
	var behind := bandit(ahead(-4.0))
	frame(w.global_position, PI * 0.72)               # from the side: the cone, the ice and the dry one in view
	await seconds(1.0)
	Wet.mark(w)
	check(Wet.is_wet(w) and not Wet.is_wet(d), "one bandit wet, one dry")
	cast("rime_wave", (w.global_position + d.global_position) * 0.5)
	await seconds(0.7)
	check(Wet.is_frozen(w) and tide.is_iced(w) and tide.is_held(w), "the wet bandit freezes solid (held, in ice)")
	check(w.visual.process_mode == Node.PROCESS_MODE_DISABLED, "its pose stops in the ice")
	check(not Wet.is_frozen(d) and Wet.is_chilled(d), "the dry bandit is only chilled")
	check(not Wet.is_frozen(behind) and not Wet.is_chilled(behind), "the one behind you is outside the cone")
	await shot("rime-frozen")
	# A normal weapon hit through his own sword: the fighter's swing, Abilities.passive_strike, take_hit.
	var normal: int = Gear.hit_damage(1.0)[0]
	var before: int = w.health
	player.visual.rotation.y = atan2(w.global_position.x - player.global_position.x, w.global_position.z - player.global_position.z)
	await get_tree().physics_frame
	# The swing is aimed at the frozen bandit as a lock-on would aim it: his fighter commits the swing to `target`
	# when it starts (attack -> _swing_target), so a villager wandering nearer cannot take the blow. His targeting
	# code is untouched; the probe only sets the field in the same frame, before his next physics step.
	player.fighter.target = w
	player.fighter.attack()
	check(player.fighter._swing_target == w, "his sword's swing is committed to the frozen bandit")
	for _i in 60:
		await get_tree().physics_frame
		if not is_instance_valid(w) or w.health != before:
			break
	var dealt: int = before - (w.health if is_instance_valid(w) and w.is_alive() else 0)
	check(dealt >= normal * 3 or not w.is_alive(), "his sword lands x3 on the frozen bandit (%d dealt, a normal hit is %d)" % [dealt, normal])
	check(not is_instance_valid(w) or (not Wet.is_frozen(w) and not tide.is_iced(w)), "and the blow cracks the ice")
	check(not is_instance_valid(w) or not w.is_alive() or (w.is_physics_processing() and w.visual.process_mode == Node.PROCESS_MODE_INHERIT), "it moves again once the ice cracks")
	await shot("rime-shatter")
	# The x3 is the frozen state's, not the sword's: the same hook on a dry and a wet bandit.
	var dry := Abilities.passive_strike(d, [10, false], player)
	Wet.mark(d)
	var wet := Abilities.passive_strike(d, [10, false], player)
	check(dry[0] == 10 and wet[0] == 13, "Tidebound: a dry blow lands as it is (%d), a wet one harder (%d of 10)" % [dry[0], wet[0]])
	# Frozen runs out on its own.
	cast("rime_wave", d.global_position)
	await seconds(0.6)
	check(Wet.is_frozen(d), "the now-wet bandit freezes on a second wave")
	await seconds(3.6)
	check(not Wet.is_frozen(d) and not tide.is_iced(d) and d.is_physics_processing(), "the ice melts after its time and it moves again")
	await clear_foes()


# --- Tidebound -----------------------------------------------------------------------------------

func trait_part() -> void:
	await clear_foes()
	player.visual.rotation.y = start_yaw              # (the opening view: no tree between the camera and the puddle)
	var b := bandit(ahead(-0.3, 0.9))                  # beside where you set off
	get_tree().call_group("camera_rig", "_set_yaw", start_yaw + PI)
	get_tree().call_group("camera_rig", "snap")
	await seconds(0.8)
	check(not Wet.is_wet(b), "a dry bandit beside you")
	player.roll(Vector3(sin(start_yaw), 0, cos(start_yaw)))   # away from the camera (rolling back put it in a tree)
	await seconds(0.6)
	check(Wet.is_wet(b), "your roll leaves a puddle that soaks whoever stands in it")
	await shot("puddle")
	await clear_foes()


# --- Talents -------------------------------------------------------------------------------------

func talents_part() -> void:
	await clear_foes()
	Classes.bonus_points = 20
	for branch: Dictionary in Classes.tree():
		for id: String in branch["talents"]:
			Classes.learn(id)
	check(Classes.talents.size() == 12, "all twelve Tidecaller talents can be learned in order (%d)" % Classes.talents.size())
	if shots != "" and DisplayServer.get_name() != "headless":
		var panel: Node = get_tree().get_first_node_in_group("hud")._modal(preload("res://scripts/ui/talent_panel.gd"))
		await seconds(0.6)
		await shot("talent-screen")
		panel._close()                              # his own close: the controls come back
		await frames(2)
	var talent_rows := Classes.TALENTS.keys().filter(func(k: String) -> bool: return k in ["long_hold", "riptide", "drowned", "downpour", "conductive",
		"eye_of_storm", "ring_of_rime", "brittle", "deep_freeze", "spring", "flood", "still_water"])
	check(talent_rows.size() == 12, "each has a name and words for the talent screen")
	# Still Water
	var a := bandit(ahead(5.0))
	await seconds(0.8)
	Wet.mark(a)
	check(Wet.wet_left(a) > 19.0, "Still Water: wet lasts 20 s (%.1f left)" % Wet.wet_left(a))
	# Downpour, Ring of Rime (the arc row's previews read the same numbers)
	check(absf(tide.tempest_radius() - 7.98) < 0.01, "Downpour: the cloud is a third wider (%.2f m)" % tide.tempest_radius())
	var pv: Dictionary = tide.preview("rime_wave", ahead(4.0))
	check(pv.shape == "ring" and is_equal_approx(float(pv.angle_deg), 360.0), "Ring of Rime: the preview is a full ring")
	check(tide.preview("drown", ahead(4.0)).shape == "ring" and tide.preview("tempest", ahead(4.0)).radius == tide.tempest_radius(), "previews: Drown a ring on the target, Tempest the cloud's reach")
	# Undertow and Drowned: held 7 s; a weak foe held the whole time drowns
	a.health = 5
	cast("drown", a.global_position)
	await seconds(6.2)
	check(not is_instance_valid(a) or not a.is_alive() or tide.is_held(a), "Undertow: still held at 6.2 s")
	await seconds(1.6)
	check(not is_instance_valid(a) or not a.is_alive(), "Drowned: the weak one held the whole time drowns")
	await clear_foes()
	# Ring of Rime + Deep Freeze: the one behind you freezes too, and stays frozen past 3.5 s
	var behind := bandit(ahead(-3.0))
	await seconds(0.8)
	Wet.mark(behind)
	cast("rime_wave", ahead(4.0))
	await seconds(0.5)
	check(Wet.is_frozen(behind), "Ring of Rime: the wave reaches behind you")
	await seconds(4.0)
	check(Wet.is_frozen(behind), "Deep Freeze: still frozen at 4.5 s")
	await seconds(3.2)
	check(not Wet.is_frozen(behind), "and thawed by 7.7 s")
	await clear_foes()
	# Eye of the Storm: the cloud follows you
	cast("tempest", player.global_position)
	await seconds(0.3)
	var start: Vector3 = tide.storm_at
	player.global_position += Vector3(3.0, 0.0, 0.0)
	await seconds(1.5)
	check(_flat(tide.storm_at, player.global_position) < 1.0 and _flat(tide.storm_at, start) > 2.0, "Eye of the Storm: the cloud follows you (%.1f m behind)" % _flat(tide.storm_at, player.global_position))
	await seconds(7.0)
	Classes.reset_talents()
	Classes.bonus_points = 0


static func _flat(p: Vector3, q: Vector3) -> float:
	return Vector2(p.x - q.x, p.z - q.z).length()


# --- Cost: interleaved A/B on one machine -------------------------------------------------------

## A = the same foes standing, nothing cast; B = Drown, Tempest and Rime Wave cast on them. Four rounds, A then B,
## 3 s each. Per window: draw calls a frame (mean, max) and the engine's own process and physics time (mean ms).
## Rendered runs only (headless draws nothing). Prints "WATER COST <window> ..." lines.
func cost_part() -> void:
	await clear_foes()
	if DisplayServer.get_name() == "headless":
		print("WATER COST skipped (headless draws nothing)")
		return
	var foes: Array[Node3D] = [bandit(ahead(5.0)), bandit(ahead(5.5, 2.0)), bandit(ahead(5.5, -2.0))]
	frame(foes[0].global_position)
	await seconds(1.5)
	var rows := {"A": [], "B": []}
	for round in 4:
		rows.A.append(await _window())
		for e in foes:
			if is_instance_valid(e):
				e.health = e.max_health          # keep them standing round after round
		cast("drown", foes[0].global_position)
		cast("tempest", player.global_position)
		cast("rime_wave", foes[1].global_position)
		rows.B.append(await _window())
		await seconds(6.0)                       # let the storm and the hold end before the next idle window
	for w: String in ["A", "B"]:
		var d := 0.0
		var dmax := 0
		var pr := 0.0
		var ph := 0.0
		for r: Dictionary in rows[w]:
			d += r.draws / 4.0
			dmax = maxi(dmax, r.draws_max)
			pr += r.process / 4.0
			ph += r.physics / 4.0
		print("WATER COST %s draws_mean=%.1f draws_max=%d process_ms=%.2f physics_ms=%.2f rounds=4" % [w, d, dmax, pr, ph])
	for round in 4:
		print("WATER COST round %d A draws %.1f/%d process %.2f | B draws %.1f/%d process %.2f" % [round, rows.A[round].draws, rows.A[round].draws_max,
			rows.A[round].process, rows.B[round].draws, rows.B[round].draws_max, rows.B[round].process])
	check(true, "cost A/B measured (see WATER COST lines)")


func _window() -> Dictionary:
	var n := 0
	var draws := 0.0
	var dmax := 0
	var pr := 0.0
	var ph := 0.0
	var until := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < until:
		await RenderingServer.frame_post_draw
		var dc := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		draws += dc
		dmax = maxi(dmax, dc)
		pr += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		ph += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		n += 1
	n = maxi(n, 1)
	return {"draws": draws / n, "draws_max": dmax, "process": pr / n, "physics": ph / n}


# --- Villagers: every effect a checked act through the one door ----------------------------------

const People := preload("res://scripts/studio/village/sim/people.gd")
const Contact := preload("res://scripts/studio/village/contact.gd")
const Actions := preload("res://scripts/studio/village/sim/people_actions.gd")
const WP := preload("res://scripts/studio/water/water_people.gd")


func resident(id: int):
	return VillageSession.village.people[id]


func live(id: int, kind: String) -> bool:
	return Actions.live(VillageSession.village, resident(id), kind)


## An adult villager the door may act on, standing within `near` metres (nearest first), not in `skip`.
func villager(near: float, skip: Array = []) -> int:
	var res := Contact.registry(get_tree())
	var v = VillageSession.village
	var best := -1
	var best_d := near
	for id: int in res.bodies:
		if id in skip or not Contact.eligible(get_tree().current_scene.get_node("VillageLive"), v, id):
			continue
		var d: float = (res.bodies[id] as Node3D).global_position.distance_to(player.global_position)
		if d < best_d and Contact.clear(player, player.global_position, res.bodies[id].global_position):
			best = id
			best_d = d
	return best


## Wait (up to 40 s) for a villager to come near enough.
func wait_villager(near: float, skip: Array = []) -> int:
	for _i in 80:
		var id := villager(near, skip)
		if id >= 0:
			return id
		await seconds(0.5)
	return -1


## How every other villager feels about you now: {id: [fear, wary]} (Mind's affect and stance).
func feelings(skip: int) -> Dictionary:
	const Affect := preload("res://scripts/studio/people/affect.gd")
	var v = VillageSession.village
	var out := {}
	for q in v.people:
		if q.alive and q.present and q.id != skip:
			out[q.id] = [int(Affect.project(q.mind, People.tick(v)).get("fear", 0)), int(q.mind.stances.get("player:local", {}).get("wary", 0))]
	return out


## Those whose fear or wariness of you rose since `before`.
func shaken(before: Dictionary, skip: int) -> Array:
	var now := feelings(skip)
	return now.keys().filter(func(id: int) -> bool:
		return before.has(id) and (now[id][0] > before[id][0] + 50 or now[id][1] > before[id][1]))


func body(id: int) -> Node3D:
	return Contact.registry(get_tree()).bodies[id]


## Walk up to a body with his own stick (teleporting him is undone by the game).
func walk_to(id: int, within: float) -> void:
	for _i in 150:
		var to: Vector3 = body(id).global_position - player.global_position
		to.y = 0.0
		if to.length() < within:
			break
		Controls.joystick = Vector2(to.x, to.z).normalized().rotated(Controls.cam_yaw) * 0.6
		await get_tree().physics_frame
	Controls.joystick = Vector2.ZERO


func people_part() -> void:
	await clear_foes()
	Classes.reset_talents()
	var v = VillageSession.village
	var a := -1
	for _i in 300:
		a = villager(9.0)
		if a >= 0:
			break
		await seconds(0.5)
	check(a >= 0, "a villager within reach of Drown (%d)" % a)
	if a < 0:
		return
	# Drown on a person: a checked hold; the slam is a fall when it ends (people_actions.advance)
	var hurt0: int = resident(a).hurt
	frame(body(a).global_position, PI * 0.6)
	cast("drown", body(a).global_position)
	await frames(3)
	check(tide.last_person.get("accepted", false), "Drown on a villager is an accepted hold (%s)" % str(tide.last_person.get("reason", "ok")))
	check(live(a, "suspended"), "they hang in the water (suspended fact; the element shows the sphere)")
	await seconds(1.0)
	await shot("people-drown")
	await seconds(4.6)
	check(not live(a, "suspended") and live(a, "down") and resident(a).hurt > hurt0, "the water lets go: slammed down, hurt %d -> %d" % [hurt0, resident(a).hurt])
	# Burning person: Drown puts the fire out (hold on the burning)
	var b := await wait_villager(10.0, [a])
	check(b >= 0, "a second villager (%d)" % b)
	if b < 0:
		return
	var lit := Contact.perform(get_tree(), "player:local", player, "burn", {"press_id": "water-probe:light-b", "heat": 650}, body(b).global_position, 1.5, Vector3.ZERO, b)
	await frames(2)
	check(resident(b).body_facts.has("burning"), "the second villager is burning (%s)" % str(lit.get("reason", "ok")))
	cast("drown", body(b).global_position)
	await frames(3)
	check(not resident(b).body_facts.has("burning") and live(b, "doused") and live(b, "suspended"), "Drown on a burning person puts the fire out (doused) as it lifts them")
	await seconds(5.6)
	# Rime Wave on the wet: frozen, a checked act; on the dry: only chilled (no fact)
	for _i in 120:                                   # (the slam's down passes first: a downed body is not frozen standing)
		if not live(b, "down"):
			break
		await seconds(0.1)
	check(live(b, "doused"), "still wet from the water when they get up")
	await walk_to(b, 2.2)                              # within a hand's reach before the wave: the blow follows at once
	frame(body(b).global_position, PI * 0.6)
	var dry_now: Array = VillageSession.village.people.filter(func(q) -> bool:
		return q.alive and q.present and q.id != b and not Actions.live(VillageSession.village, q, "doused")).map(func(q) -> int: return q.id)
	var calm := feelings(b)
	print("water note: before the wave b=%d eligible=%s wet=%s dist=%.1f" % [b, Contact.eligible(get_tree().current_scene.get_node("VillageLive"), VillageSession.village, b), live(b, "doused"), body(b).global_position.distance_to(player.global_position)])
	cast("rime_wave", body(b).global_position)
	await seconds(0.8)
	check(live(b, "frozen"), "Rime Wave freezes the wet villager (%s)" % str(tide.last_person.get("reason", "ok")))
	var froze_dry := dry_now.filter(func(id: int) -> bool: return live(id, "frozen"))
	check(froze_dry.is_empty(), "no villager who was dry when the wave rolled is frozen (%d dry)" % dry_now.size())
	await shot("people-frozen")
	# A blow on the frozen: x3 and the ice cracks (people_actions strike), the hand's own route
	var walk_from := Time.get_ticks_msec()
	await walk_to(b, 2.4)                              # (already there unless they moved before the ice took them)
	var frozen_left: int = int(resident(b).body_facts.get("frozen", {}).get("until_tick", 0)) - People.tick(VillageSession.village)
	print("water note: before the blow frozen=%s left_ms=%d dist=%.1f walk_ms=%d" % [live(b, "frozen"), frozen_left,
		body(b).global_position.distance_to(player.global_position), Time.get_ticks_msec() - walk_from])
	var hurt1: int = resident(b).hurt
	var blow := Contact.perform(get_tree(), "player:local", player, "strike", {"press_id": "water-probe:blow", "damage": 1, "force": 450},
		player.global_position, 2.8, Vector3.ZERO, b)
	await frames(2)
	check(blow.get("accepted", false) and bool(blow.get("shattered", false)) and resident(b).hurt - hurt1 == mini(42, 100 - hurt1) and not live(b, "frozen"),
		"a blow on the frozen lands three times over and cracks the ice (hurt %d -> %d, three blows' 42 up to the cap)" % [hurt1, resident(b).hurt])
	print("water note: the freezing seen: %d villager(s) more afraid or wary of you (depends on who is looking)" % shaken(calm, b).size())
	# Rain on a burning person: put out by the cloud (extinguish rain, an area act)
	var d := await wait_villager(5.0, [a, b])
	check(d >= 0, "a villager within the cloud's reach (%d)" % d)
	if d >= 0:
		Contact.perform(get_tree(), "player:local", player, "burn", {"press_id": "water-probe:light-d", "heat": 650}, body(d).global_position, 1.5, Vector3.ZERO, d)
		await frames(2)
		var was: bool = resident(d).body_facts.has("burning")
		tide.last_person = {}
		var hurt_before := {}
		for q in VillageSession.village.people:
			hurt_before[q.id] = q.hurt
		var ground0: int = tide.ground_bolts
		cast("tempest", player.global_position)
		await seconds(2.6)
		check(was, "the third villager is burning")
		check(not resident(d).body_facts.has("burning") and str(resident(d).body_facts.get("doused", {}).get("method", "")) == "rain",
			"the rain puts a burning villager out (doused by rain)")
		await shot("people-storm")
		await seconds(3.0)
		var struck := VillageSession.village.people.filter(func(q) -> bool: return q.hurt > int(hurt_before.get(q.id, q.hurt)) and q.id != d)
		check(tide.last_person.is_empty() and struck.is_empty() and tide.ground_bolts > ground0,
			"with no foe under the cloud and nobody fighting you, the bolts fall on open ground: no villager is struck (%d ground bolts)" % (tide.ground_bolts - ground0))
		await seconds(3.0)
	# Rain on the dry: a villager dry when the storm forms soaks under it (wet, method rain, through the door). Run before
	# the drowning (which scatters the village); any of those under the cloud at the cast counts, polled through the storm.
	if WP.wet_open(get_tree(), player):
		var dry_set := []
		for _i in 80:
			var live_node: Node = get_tree().current_scene.get_node("VillageLive")
			dry_set = VillageSession.village.people.filter(func(q) -> bool:
				return q.alive and q.present and q.id not in [a, b, d] and not Actions.live(VillageSession.village, q, "doused") \
					and Contact.eligible(live_node, VillageSession.village, q.id) \
					and body(q.id).global_position.distance_to(player.global_position) < 5.0).map(func(q) -> int: return q.id)
			if not dry_set.is_empty():
				break
			await seconds(0.5)
		if not dry_set.is_empty():
			cast("tempest", player.global_position)
			var soaked_id := -1
			for _i in 75:                                  # the whole storm, a tenth of a second at a time
				await seconds(0.1)
				for id: int in dry_set:
					if live(id, "doused") and str(resident(id).body_facts.doused.get("method", "")) in ["rain", "tide"]:
						soaked_id = id
				if soaked_id >= 0:
					break
			check(soaked_id >= 0, "a dry villager under the rain is soaked through the door (%d of %d dry under the cloud: %s)" % [
				1 if soaked_id >= 0 else 0, dry_set.size(), str(WP.last_wet.get("reason", "ok"))])
			await seconds(8.0)
		else:
			check(false, "a dry villager within the cloud's reach for the rain")
	else:
		check(false, "Body 4's Water.contact takes \"tide:\" keys (merged on merge-enea b17a1bf)")
	# Drowned: held the whole time with the talent, they drown through the rules' one death
	Classes.bonus_points = 3
	for id: String in ["long_hold", "riptide", "drowned"]:
		Classes.learn(id)
	var e := await wait_villager(10.0, [a, b, d])
	check(e >= 0, "a villager to drown (%d)" % e)
	if e >= 0:
		frame(body(e).global_position, PI * 0.6)
		var before := feelings(e)
		cast("drown", body(e).global_position)
		await frames(3)
		check(live(e, "suspended") and bool(resident(e).body_facts.suspended.get("drown", false)), "held with Drowned")
		await seconds(7.6)
		var p = resident(e)
		check(not p.alive and p.death_cause == "drowned" and p.body_facts.has("dead"), "held the whole time, they drown: the rules' one death, cause \"drowned\" (%s)" % p.death_cause)
		await seconds(1.5)
		print("water note: the drowning seen: %d villager(s) more afraid or wary of you (depends on who is looking)" % shaken(before, e).size())
	Classes.reset_talents()
	Classes.bonus_points = 0
	print("water note: the door's last answer to wet: %s (accepted=%s)" % [str(WP.last_wet.get("reason", "none sent" if WP.last_wet.is_empty() else "ok")), str(WP.last_wet.get("accepted", false))])
	print("water note: lightning on a person beyond reach %s" % ("open" if Actions.area("strike", {"source": "lightning"}) else "waits on Foundations' area strike"))
