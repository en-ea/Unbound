extends Node
## Mind port probe, in the live village with the port's switch on (headless is fine):
##   --studio=village/live --merge-check=../people/port_probe --port-residents=on --save-guard --test-save=<fresh name>
## Unit 2 (the adapter, rent.gd and the marked lines in his files): his saved liking reads back exactly after the
## upgrade; a loved gift through his own Residents.give is one checked act - the apple leaves once, Tomas's gift tally
## and stance rise, he says his loved line and his present comes at liking 4, his price falls, and his own liking field
## stays frozen; a shove sours a tenant (Hill House's family, merge-fix) and the next day's rent is lower; the letting
## sign still collects.
## Prints PASS/FAIL lines and "PORT PROBE complete failures=N".
const PlayerActs := preload("res://scripts/studio/village/player_acts.gd")
const Ported := preload("res://scripts/studio/village/sim/ported.gd")
const People := preload("res://scripts/studio/village/sim/people.gd")
const Contact := preload("res://scripts/studio/village/contact.gd")
const PortAdapter := preload("res://scripts/studio/people/port_adapter.gd")
const PortStance := preload("res://scripts/studio/people/port_stance.gd")
const Rules := preload("res://scripts/studio/village/sim/village.gd")
const PeopleActions := preload("res://scripts/studio/village/sim/people_actions.gd")
const VillageImage := preload("res://scripts/studio/village/sim/image.gd")
const Lines := preload("res://scripts/studio/village/resident_lines.gd")
const Sites := preload("res://scripts/studio/village/sites.gd")
var failed := 0
var res: Node
var player: Node3D


static func on_device(tree: SceneTree) -> void:
	if tree.root.has_node("PortProbe"):
		return
	if DisplayServer.get_name() == "headless":
		tree.root.get_node("ItemIcons").set_process(false)
	var probe: Node = load("res://scripts/studio/people/port_probe.gd").new()
	probe.name = "PortProbe"
	tree.root.add_child.call_deferred(probe)


func _ready() -> void:
	run.call_deferred()


func check(ok: bool, text: String) -> void:
	print(("PASS port-probe " if ok else "FAIL port-probe ") + text)
	if not ok:
		failed += 1


func frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


## Stands the player beside a villager's village body, facing them.
func beside(id: int) -> void:
	var body: Node3D = res.bodies[id]
	res._movers[id].place(Vector2(body.global_position.x, body.global_position.z), PI)
	player.global_position = body.global_position + Vector3(0, 0.1, -2.2)   # within give reach (3 m), out of bumping
	await frames(10)


func run() -> void:
	# He buys Hill House: its village family are his tenants (merge-fix), and his Odo stays away.
	Lettings.owned[3] = 1
	Lettings.mood[3] = 70
	await frames(120)
	for _i in 900:
		res = Contact.registry(get_tree())
		if res != null and VillageSession.village != null and res.call("all_built"):
			break
		await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	var v = VillageSession.village
	var tomas := Ported.person_of(v, "tomas")
	var odo: int = await tenant(v)            # (named for the tenant he was: a grown one of Hill House's family who can be stood)
	check(tomas >= 0 and odo >= 0 and res != null and res.bodies.has(tomas), "his Tomas is a person of the village, and Hill House's family are its tenants (%d, %s %d)" % [tomas, v.people[odo].name if odo >= 0 else "-", odo])
	if tomas < 0 or odo < 0 or res == null or not res.bodies.has(tomas):
		_done()
		return
	# The join upgraded his liking as loaded (his Residents load before the village); the adapter reads it back exactly.
	var his := {}
	for id: String in Ported.PEOPLE:
		his[id] = int(Residents.liking.get(id, 0))
	check(PortAdapter.routes("tomas") and v.runtime.port_liking.size() == 7 and Ported.PEOPLE.keys().all(func(id: String) -> bool: return PortAdapter.liking(id, -1) == his[id])
		and v.people[odo].present and (Ported.person_of(v, "tenant_odo") < 0 or not v.people[Ported.person_of(v, "tenant_odo")].present),
		"his liking reads back exactly from the stance after the join's upgrade (%s); the family is home, his Odo away" % str(his))
	# Two loved gifts through his own panel's function.
	await beside(tomas)
	var hits0 := int(PortStance.toward_player(v, "tomas").get("hits", 0))
	var l0: int = his["tomas"]
	var g0: int = Residents._gifted["tomas"]
	var dear := ""                 # the dearest thing he could sell: a price whose discount shows in whole coins
	for item: String in Balance.VALUES:
		if dear == "" or Balance.VALUES[item] > Balance.VALUES[dear]:
			dear = item
	var price0 := Residents.price("tomas", dear)
	var loved: String = Residents.def("tomas")["likes"][0]
	Inventory.add(loved, 3)
	var have := Inventory.count(loved)
	var says := Residents.give("tomas", loved)
	await frames(5)
	says += " / " + Residents.give("tomas", loved)
	await frames(5)
	check(says.begins_with(Residents.def("tomas")["loved"]) and Inventory.count(loved) == have - 2,
		"two loved gifts are two checked acts: two %s leave the bag and Tomas says his loved line (%s)" % [loved, says])
	check(int(PortStance.toward_player(v, "tomas").get("hits", 0)) == hits0 and PortStance.gifts(v, "tomas") == l0 + 4 and PortAdapter.liking("tomas", -1) == l0 + 4
		and int(Residents.liking["tomas"]) == l0 and int(PortStance.toward_player(v, "tomas").get("trust", 0)) > 0,
		"his tally +2 each (liking %d -> %d), trust from appraisal, and his own liking field frozen at %d (%s)" % [l0, PortAdapter.liking("tomas", -1), int(Residents.liking["tomas"]), str(PortStance.toward_player(v, "tomas"))])
	var crossed := l0 < 4 and l0 + 4 >= 4
	check(not crossed or (Residents._gifted["tomas"] == g0 + 1 and says.contains(Items.DEFS[Residents.def("tomas")["present"][g0]]["name"].to_lower())),
		"crossing liking 4 brings his present, as his rules give it")
	check(Residents.price("tomas", dear) < price0, "his price falls with liking (%s %d -> %d)" % [dear, price0, Residents.price("tomas", dear)])
	# A shove sours the tenant; the next day's rent is lower; the letting sign still collects.
	var rent0 := Lettings.rent(3)
	var word0 := Lettings.mood_word(3)
	await beside(odo)
	var shove: Dictionary = PlayerActs.perform("player:local", res, "shove", odo, {"press_id": "port-probe-shove"})
	for _i in 90:                         # until the tenant has felt it (a learn can wait its turn a frame or two)
		if feel(v, odo) < -100:
			break
		await get_tree().process_frame
	var feeling := feel(v, odo)
	var rent1 := Lettings.rent(3)
	check(shove.get("accepted", false) and feeling < 0 and rent1 < rent0 and int(Lettings.mood[3]) == 70,
		"a shove sours the tenant %s (feeling %d): rent %d -> %d, %s -> %s; his contentment stays 70 (%s)" % [v.people[odo].name, feeling, rent0, rent1, word0, Lettings.mood_word(3), str(shove.get("reason", ""))])
	Lettings.waiting = 0
	Lettings.new_day()
	var waiting := Lettings.waiting
	var coins := Money.coins
	var got := Lettings.collect()
	check(waiting > 0 and waiting <= rent1 + 1 and got == waiting and Money.coins == coins + got,
		"the letting sign still collects the day's rent (%d)" % got)
	await day_and_reaction(v, tomas)
	await creative(v, tomas, odo)
	await downed_and_dead(v, tomas, odo)
	_done()


## His npc.gd node for a resident (not an indoor copy).
func his_node(id: String) -> Node3D:
	var stack: Array[Node] = [get_tree().current_scene]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Node3D and n.get("_id") == id and not n.get("_still"):
			return n
		stack.append_array(n.get_children())
	return null


## Unit 3: his round is unrouted, the village body walks his day to his anchor, and a reaction outranks it.
func day_and_reaction(v, tomas: int) -> void:
	var node := his_node("tomas")
	var body: Node3D = res.bodies[tomas]
	player.global_position = body.global_position + Vector3(8, 0.1, 8)       # out of the way
	await frames(30)
	var on := Vector2(node.global_position.x, node.global_position.z).distance_to(res._movers[tomas].pos) if node != null else -1.0
	check(node != null and not node.visible and on < 0.2 and node.is_in_group("interactable"),
		"his npc.gd Tomas stops his round: his node hidden, his talk standing on the village body (%.2f m)" % on)
	var act: String = Residents.activity("tomas")
	var anchor: Vector2 = Sites.anchors(Residents.def("tomas"))[act] if act != "home" else Vector2.INF
	var plan: Dictionary = {}
	for _i in 20 * 30:                    # (the gift's own reaction may still be ending; a day is looked at every 5 s)
		plan = v.people[tomas].mind.plan
		if str(plan.get("offer", "")) == "routine":
			break
		await get_tree().process_frame
	check(act != "home" and str(plan.get("offer", "")) == "routine" and str(plan.get("effects", {}).get("act", "")) == act,
		"his hour (%s) is a routine plan to his anchor %s (%s)" % [act, str(anchor), str(plan.get("offer", "none"))])
	# Evening: by the fire. The routine for the new hour takes the village body there, and it stays.
	var sky: Node = get_tree().current_scene.get_node("WorldEnvironment")
	sky.set_time(0.765)
	var lunch: Vector2 = Sites.anchors(Residents.def("tomas"))["evening"]
	var start := -1.0
	for _i in 10 * 30:
		if str(v.people[tomas].mind.plan.get("effects", {}).get("act", "")) == "evening":
			start = res._movers[tomas].pos.distance_to(lunch)
			break
		await get_tree().process_frame
	for _i in 90 * 30:
		if res._movers[tomas].pos.distance_to(lunch) < 1.5:
			break
		await get_tree().process_frame
	var arrived: float = res._movers[tomas].pos.distance_to(lunch)
	await frames(60)
	var stayed: float = res._movers[tomas].pos.distance_to(lunch)
	check(Residents.activity("tomas") == "evening" and start > 5.0 and arrived < 1.5 and stayed < 1.5,
		"in the evening his routine walks the village body to his place by the fire %s and it stays (%.1f m -> %.1f m, then %.1f m)" % [str(lunch), start, arrived, stayed])
	# A shove: the reaction replaces the routine; when it is over, his day comes back.
	await beside(tomas)
	var shove: Dictionary = PlayerActs.perform("player:local", res, "shove", tomas, {"press_id": "port-probe-shove-tomas"})
	await frames(20)
	var reacted := str(v.people[tomas].mind.plan.get("offer", ""))
	player.global_position = body.global_position + Vector3(8, 0.1, 8)
	var back := false
	for _i in 120 * 30:
		if str(v.people[tomas].mind.plan.get("offer", "")) == "routine":
			back = true
			break
		await get_tree().process_frame
	check(shove.get("accepted", false) and reacted != "routine" and reacted != "" and back,
		"a shove interrupts his day (%s outranks the routine) and his routine comes back after (%s)" % [reacted, str(shove.get("reason", ""))])


## Unit 4: a downed or dead resident or tenant leaves his UI consistent. The death and the fall are fixtures, written
## through one checked batch each (a thumb cannot make them quickly: a death here comes from burning).
func downed_and_dead(v, tomas: int, odo: int) -> void:
	var bridge: Object = res.get("people_bridge")
	var nell := Ported.person_of(v, "nell")
	var node := his_node("nell")
	await beside(nell)
	await knock_down(nell)
	await frames(10)
	check(PeopleActions.down(v, v.people[nell]) and node != null and not node.is_in_group("interactable"),
		"Nell downed: no talk or gift panel on her")
	var bram := Ported.person_of(v, "bram")
	var odo_house := 3
	for pid: int in [bram] + PortStance.family(v, odo_house):   # Bram, and the whole tenant family
		bridge.accept(func(c) -> Dictionary:   # fixture: a death
			VillageImage.touch_person(-1)
			Rules.die(c, pid, "fixture", PackedInt32Array(), "a fixture's death")
			return {"accepted": true})
	await frames(10)
	var bram_node := his_node("bram")
	var item: String = Residents.def("bram")["likes"][0]
	Inventory.add(item, 1)
	var have := Inventory.count(item)
	var said := Residents.give("bram", item)
	check(not v.people[bram].alive and bram_node != null and not bram_node.is_in_group("interactable") and said == "" and Inventory.count(item) == have,
		"Bram dead: no talk on him, and a gift to him is refused with nothing taken")
	var waiting := Lettings.waiting
	Lettings.new_day()
	check(not v.people[odo].alive and Lettings.rent(odo_house) == 0 and Lettings.waiting == waiting,
		"the tenant family dead: the house pays no rent (the next day adds %d)" % (Lettings.waiting - waiting))
	var inside: Array = preload("res://scripts/world/home_folk.gd").inside(get_tree(), odo_house)
	check(not inside.any(func(f: Dictionary) -> bool: return not v.people[int(f.id)].alive),
		"inside Hill House (world/home_folk.gd), none of the dead is at home: no figure, no talk (%d inside)" % inside.size())


## Fixture: a person knocked down, through one checked batch (in play a heavy blow or a fall does it).
func knock_down(pid: int) -> void:
	res.get("people_bridge").accept(func(c) -> Dictionary:
		PeopleActions.fact(c, c.people[pid], "down", "fixture:down:%d" % pid, {"until_tick": People.tick(c) + 60000, "strength": 1000,
			"at": [res._movers[pid].pos.x, res._movers[pid].pos.y], "from": [player.global_position.x, player.global_position.z]})
		return {"accepted": true})
	await frames(2)


## Puts a body somewhere at once and holds it there (a fixture's stand-in for where the day has taken them).
func stand(pid: int, at: Vector2, face := Vector2.INF) -> void:
	var look := face if face != Vector2.INF else at + Vector2(0, 1)
	res._movers[pid].place(at, atan2(look.x - at.x, look.y - at.y))
	res._movers[pid].hold(at, look)
	await frames(2)


## The creative unit (desk 6 Oct 04:36): a greeting that remembers, Tomas at a fire, a killing by hand in his old
## friend's sight, a tenant's tongue, and a tenant who has had enough.
func creative(v, tomas: int, odo: int) -> void:
	var bram := Ported.person_of(v, "bram")
	var elsa := Ported.person_of(v, "elsa")
	var nell := Ported.person_of(v, "nell")
	# A greeting that remembers: shove Bram, then talk to him.
	await beside(bram)
	PlayerActs.perform("player:local", res, "shove", bram, {"press_id": "port-probe-shove-bram"})
	for _i in 90:
		if int(PortStance.toward_player(v, "bram").get("hits", 0)) > 0:
			break
		await get_tree().process_frame
	var greeting: String = Residents.talk("bram")["text"]
	var cold := false
	for list: Array in [Lines.SHOVED, Lines.HIT, Lines.SAW_SHOVE, Lines.SAW_HIT, Lines.ANGERED, Lines.MENDING]:
		for line: String in list:
			cold = cold or greeting.begins_with(line.replace("{name}", "Bram"))
	check(cold and int(PortStance.toward_player(v, "bram").get("hits", 0)) > 0, "Bram, shoved, greets you with it before his own line (%s)" % greeting)
	# Tomas at a fire: his friend, a village woodcutter, catches fire beside him. (The others are sent off first: a
	# fire draws helpers, and helpers burn.)
	var friend := -1
	for q in v.people:
		if q.alive and q.present and q.role == "woodcutter" and q.id != tomas and res.bodies.has(q.id) and Rules.opinion(v, tomas, q.id) >= 30:
			friend = q.id
	var spot: Vector2 = res._movers[tomas].pos
	for other: int in [bram, elsa, nell, odo]:
		await stand(other, spot + Vector2(-30, 25))
	var bram0: int = v.people[bram].stress
	if friend >= 0:
		await stand(friend, spot + Vector2(2.6, 0))
		player.global_position = Vector3(spot.x - 6, player.global_position.y, spot.y - 6)
		await frames(10)
		player.abilities._drop_star(null, res.bodies[friend].global_position, 1.0)
		var offers := {}
		var caught := false
		var stood := -1                        # frames: first alight and able to move, beat_out the plan, downed again alight
		var beat := -1
		var redowned := false
		for _i in 30 * 30:
			var now_offer := str(v.people[tomas].mind.plan.get("offer", ""))
			if now_offer != "":
				offers[now_offer] = true
			var alight: bool = not v.people[tomas].body_facts.get("burning", {}).is_empty()
			var downed: bool = PeopleActions.down(v, v.people[tomas])
			caught = caught or alight
			if alight and not downed and stood < 0:
				stood = _i                     # the first moment alight that he can move
			if stood >= 0 and beat < 0 and now_offer == "beat_out":
				beat = _i
			redowned = redowned or (stood >= 0 and alight and downed)
			if not v.people[tomas].alive or (_i > 300 and v.people[tomas].body_facts.get("burning", {}).is_empty() and v.people[friend].body_facts.get("burning", {}).is_empty()):
				break
			if _i % 15 == 0:                   # the helper's half-seconds at the fire, for the desk's question
				print("PROBE fire t=%.1f tomas offer=%s phase=%s burning=%s hurt=%d down=%s | %s burning=%s hurt=%d alive=%s" % [_i / 30.0,
					now_offer, str(v.people[tomas].mind.plan.get("phase", "")),
					str(not v.people[tomas].body_facts.get("burning", {}).is_empty()), v.people[tomas].hurt, str(PeopleActions.down(v, v.people[tomas])),
					v.people[friend].name, str(not v.people[friend].body_facts.get("burning", {}).is_empty()), v.people[friend].hurt, str(v.people[friend].alive)])
			await get_tree().process_frame
		for key: String in v.people[tomas].mind.known:         # what Tomas knew of the fire, for the record
			var a: Dictionary = v.people[tomas].mind.known[key]
			print("PROBE fire known %s target %s act %s facets %s" % [key.left(24), str(a.get("target", "")), str(a.get("evidence", {}).get("act", "")),
				str(a.get("facets", {}).keys().map(func(k: Variant) -> String: return str(k) + "/" + str(a.facets[k].get("via", ""))))])
		var helped := offers.has("help_fire") or offers.has("intervene") or offers.has("fetch_help")
		check(helped or offers.has("beat_out"), "his friend %s on fire beside him, gruff Tomas answers it (%s)" % [v.people[friend].name, ", ".join(PackedStringArray(offers.keys()))])
		# The design (desk 12:53, asserted as design, not one outcome of a knife-edge): alight, beat_out is his plan as soon
		# as he can move (half a second at most), and his flames are out unless he is downed again while still burning -
		# downed alight he cannot act, and that is death unless someone else puts him out. Downed alight the whole time
		# (never able to move) is that same branch. The line says which branch happened, and the hurt.
		var out_now: bool = v.people[tomas].body_facts.get("burning", {}).is_empty()
		var chose := stood >= 0 and beat >= 0 and beat - stood <= 15
		var branch := "never caught" if not caught else "downed alight throughout" if stood < 0 \
			else "beat out his flames and lived" if chose and out_now and v.people[tomas].alive \
			else "downed again alight before the flames were out" if chose and redowned else "none of the design's branches"
		check(branch != "none of the design's branches",
			"a helper who catches fire beats out his own flames as soon as he can move, unless downed alight (%s: beat_out %s s after he could move, alive %s, flames out %s, hurt %d)" % [
			branch, "%.1f" % ((beat - stood) / 30.0) if stood >= 0 and beat >= 0 else "-", str(v.people[tomas].alive), str(out_now), v.people[tomas].hurt])
	else:
		check(false, "Tomas has a woodcutter friend in the village")
	# A killing by hand in Bram's sight (the checked finish verb on a knocked-down person: the knock-down is a fixture).
	# Tomas if he came through the fire (his old friend: grief and hate), else Elsa (hate), and then Bram grieves Tomas.
	var victim := tomas if v.people[tomas].alive else elsa
	var grieved := false
	if not v.people[tomas].alive:
		grieved = v.people[bram].stress >= bram0 + 40
	var at: Vector2 = res._movers[victim].pos
	player.global_position = Vector3(at.x, player.global_position.y, at.y - 1.5)
	await stand(bram, at + Vector2(1.2, 1.0), at)          # near, facing it, within 3 m of the killer: he sees who did it
	await knock_down(victim)
	var stress0: int = v.people[bram].stress
	var resent0 := int(PortStance.toward_player(v, "bram").get("resentment", 0))
	var finish: Dictionary = {}
	for attempt in 3:                          # (stand over them again: a downed body can still slide a little)
		var lying: Vector2 = res._movers[victim].pos
		player.global_position = Vector3(lying.x, player.global_position.y, lying.y - 1.2)
		if not PeopleActions.down(v, v.people[victim]):
			await knock_down(victim)
		await frames(3)
		finish = PlayerActs.perform("player:local", res, "finish", victim, {"press_id": "port-probe-finish-%d" % attempt})
		if finish.get("accepted", false):
			break
		print("PROBE finish refused (%s): down %s, alive %s, %.1f m" % [str(finish.get("reason", "")), str(PeopleActions.down(v, v.people[victim])), str(v.people[victim].alive), lying.distance_to(Vector2(player.global_position.x, player.global_position.z))])
	for _i in 120:
		if int(PortStance.toward_player(v, "bram").get("resentment", 0)) >= resent0 + 300:
			break
		await get_tree().process_frame
	if victim == tomas:
		grieved = v.people[bram].stress >= stress0 + 40
	var row := PortStance.toward_player(v, "bram")
	var deed_k := str(finish.get("action_id", finish.get("deed", "")))
	var saw: Array = v.people[bram].mind.known.keys().filter(func(k: String) -> bool: return str(v.people[bram].mind.known[k].get("evidence", {}).get("act", "")) == "finish")
	print("PROBE bram after the killing: alive %s present %s saw %s pos %s victim %s plan %s finish %s" % [v.people[bram].alive, v.people[bram].present, str(saw), str(res._movers[bram].pos), str(res._movers[victim].pos), str(v.people[bram].mind.plan.get("offer", "")), str(finish.keys())])
	var answer2: String = str(v.people[bram].mind.plan.get("offer", ""))
	var node := his_node("tomas" if victim == tomas else "elsa")
	check(finish.get("accepted", false) and not v.people[victim].alive and int(row.resentment) >= resent0 + 300 and answer2 != "routine"
		and node != null and not node.is_in_group("interactable"),
		"%s finished by hand in Bram's sight: the talk closes, Bram hates the killer (resentment %d -> %d) and answers it (%s) %s" % [v.people[victim].name, resent0, row.resentment, answer2, str(finish.get("reason", ""))])
	check(grieved, "Bram grieves Tomas, his old friend (stress %d -> %d; Tomas %s)" % [bram0, v.people[bram].stress, "finished" if victim == tomas else "died in the fire"])
	# A tenant's tongue: Odo (shoved earlier) tells a neighbour what his landlord did.
	print("PROBE odo before the telling: told %s pending %s alive %s cause %s died %d hurt %d at %s" % [str(v.runtime.get("port_told", {})), str(v.runtime.get("port_telling", {})), str(v.people[odo].alive), v.people[odo].death_cause, v.people[odo].died, v.people[odo].hurt, str(res._movers[odo].pos)])
	var neighbour := -1
	for q in v.people:
		if q.alive and q.present and q.authored == "" and Rules.age_of(v, q) >= 18 and res.bodies.has(q.id) and Ported_id(v, q.id) == "" and not PortStance.family(v, 3).has(q.id):   # (not of the family: one tells outside it)
			neighbour = q.id
			break
	# A fresh shove, away from the neighbour (his stance from the first one has faded with the hours the probe
	# skipped; he tells while he feels it at or past 300), then he stands near them.
	var odo_key := People.key(v, odo)
	# A telling is once a village day: his day's telling (told, or tried TELL_TRIES times in the probe's earlier
	# turmoil) is cleared first, a fixture's new day for him, so this shove's telling is the one checked.
	res.get("people_bridge").accept(func(c) -> Dictionary:
		VillageImage.touch_key("runtime", "port_told")
		VillageImage.touch_key("runtime", "port_telling")
		c.runtime.get_or_add("port_told", {}).erase("house:3")
		c.runtime.get_or_add("port_telling", {}).erase("house:3")
		return {"accepted": true})
	var family_keys: Array = PortStance.family(v, 3).map(func(pid: int) -> String: return People.key(v, pid))
	var reports_before: int = v.people_facts.keys().filter(func(k: Variant) -> bool: return str(k).begins_with("report:") and family_keys.has(str(v.people_facts[k].get("speaker", "")))).size()
	await stand(odo, res._movers[neighbour].pos + Vector2(-25, 20))
	await beside(odo)
	PlayerActs.perform("player:local", res, "shove", odo, {"press_id": "port-probe-shove-odo-2"})
	await frames(30)
	player.global_position += Vector3(10, 0, 10)
	await stand(odo, res._movers[neighbour].pos + Vector2(4, 0))
	var anyone := false
	for _i in 90 * 30:                        # the report is written when he has told someone (people_facts "report:")
		anyone = v.people_facts.keys().filter(func(k: Variant) -> bool: return str(k).begins_with("report:") and family_keys.has(str(v.people_facts[k].get("speaker", "")))).size() > reports_before
		if anyone:
			break
		await get_tree().process_frame
	print("PROBE odo telling: pending %s told %s" % [str(v.runtime.get("port_telling", {}).get("house:3", {})), str(v.runtime.get("port_told", {}))])
	check(anyone, "%s, a tenant shoved, tells the village what the landlord did (feeling %d, plan %s, told on day %s)" % [v.people[odo].name,
		feel(v, odo), str(v.people[odo].mind.plan.get("offer", "none")), str(v.runtime.get("port_told", {}).get("house:3", "-"))])
	# A tenant who has had enough: his contentment at nothing (fixture) for three of his days.
	Lettings.mood[3] = 0
	for _i in 3:
		Lettings.new_day()
		await frames(2)
	check(v.runtime.get("port_left", {}).has("house:3") and not v.people[odo].present and Lettings.rent(3) == 0,
		"the tenant family, miserable three days running, moves out: the house pays nothing while they are away (left %s, unhappy %s, present %s, alive %s, mood %d)" % [
		str(v.runtime.get("port_left", {})), str(v.runtime.get("port_unhappy", {})), str(v.people[odo].present), str(v.people[odo].alive), PortAdapter.tenant_mood(3, 0)])


## The tenant the probe follows: a grown one (14, as the rent rule counts) of Hill House's family whose body can be stood (indoors at this hour,
## asleep or away, a body stays where it is).
func tenant(v) -> int:
	for pid: int in PortStance.family(v, 3):
		if Rules.age_of(v, v.people[pid]) < 14 or not v.people[pid].present or not res.bodies.has(pid):
			continue
		var spot: Vector2 = Vector2(player.global_position.x, player.global_position.z) + Vector2(3, 0)
		await stand(pid, spot)
		await frames(30)
		if Vector2(res.bodies[pid].global_position.x, res.bodies[pid].global_position.z).distance_to(spot) < 2.0:
			return pid
	return -1


func feel(v, pid: int) -> int:
	return int(People.stance_view(v.people[pid].mind, People.tick(v), [PortStance.PLAYER]).get(PortStance.PLAYER, {}).get("feeling", 0))


func Ported_id(v, pid: int) -> String:
	for entry: Dictionary in v.runtime.get("ported", []):
		if int(entry.person) == pid:
			return str(entry.id)
	return ""


func _done() -> void:
	print("PORT PROBE complete failures=%d" % failed)
	get_tree().quit(0 if failed == 0 else 1)
