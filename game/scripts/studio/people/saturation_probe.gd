extends Node
## Saturation reading probe (desk 6 Oct 10:24, Foundations' saturation e9dbfcd): a star over a crowd, as its witnesses
## read it. In the live village with the port's switch on (headless is fine):
##   --studio=village/live --merge-check=../people/saturation_probe --port-residents=on --save-guard --test-save=<fresh name>
## A crowd of up to 20 grown villagers (those who can be stood at this hour) stands in a ring under the star; two witnesses stand 7 m out behind the caster facing it, one of them
## with a tie (kin, spouse or friend) in the crowd. The player drops the star from 5 m. Checked: each witness reads it
## as grave toward the player (as a killing reads, not one blow: the few taken in one by one and "many fell there", the
## summary of the rest, appraisal.gd MASS), the tied witness takes in their own among the fallen first, and the summary
## is one account with its count. Prints "SAT ..." stance lines, PASS/FAIL lines and "SATURATION PROBE complete failures=N".
const People := preload("res://scripts/studio/village/sim/people.gd")
const Contact := preload("res://scripts/studio/village/contact.gd")
const Rules := preload("res://scripts/studio/village/sim/village.gd")
const PeopleActions := preload("res://scripts/studio/village/sim/people_actions.gd")
const CROWD := 20
const MIN_CROWD := 5
const WITNESSES := 2
const OUT := 7.0                  # witnesses this far from the ring's centre: its far side within sight (12 m since perceive)
const CAST := 5.0                # the caster, between them and the ring (outside the star's 4.2 m)
var failed := 0
var res: Node
var player: Node3D


static func on_device(tree: SceneTree) -> void:
	if tree.root.has_node("SaturationProbe"):
		return
	if DisplayServer.get_name() == "headless":
		tree.root.get_node("ItemIcons").set_process(false)
	var probe: Node = load("res://scripts/studio/people/saturation_probe.gd").new()
	probe.name = "SaturationProbe"
	tree.root.add_child.call_deferred(probe)


func _ready() -> void:
	run.call_deferred()


func check(ok: bool, text: String) -> void:
	print(("PASS saturation " if ok else "FAIL saturation ") + text)
	if not ok:
		failed += 1


func frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func stand(pid: int, at: Vector2, face: Vector2) -> void:
	res._movers[pid].place(at, atan2(face.x - at.x, face.y - at.y))
	res._movers[pid].hold(at, face)


func stance(v, pid: int) -> Dictionary:
	return People.stance_view(v.people[pid].mind, People.tick(v), ["player:local"]).get("player:local", {})


func tied(v, a: int, b: int) -> bool:
	return Rules.is_kin(v, a, b) or v.people[a].spouse == b or Rules.opinion(v, a, b) >= 30


func run() -> void:
	await frames(120)
	for _i in 900:
		res = Contact.registry(get_tree())
		if res != null and VillageSession.village != null and VillageSession.active and res.call("all_built") \
				and get_tree().get_first_node_in_group("player") != null:
			break
		await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	var v = VillageSession.village
	# Who can be stood: a body that cannot be put where the probe puts it is left out (indoors at this hour, asleep
	# or away, or held by a scene: its mover is not active and the body stays).
	var people := []
	for id: int in res.bodies:
		var p = v.people[id]
		if p.alive and p.present and p.authored == "":
			people.append(id)
	var trial := Vector2(player.global_position.x, player.global_position.z) + Vector2(3.0, 0.0)
	var spots := {}
	for i in people.size():
		spots[people[i]] = trial + Vector2(float(i % 6), float(i / 6)) * 1.5
		stand(people[i], spots[people[i]], spots[people[i]] + Vector2(0, 1))
	await frames(30)
	var left_out := []
	for id: int in people.duplicate():
		var body: Node3D = res.bodies[id]
		if Vector2(body.global_position.x, body.global_position.z).distance_to(spots[id]) > 2.0:
			left_out.append(v.people[id].name)
			people.erase(id)
	print("SAT %d can be stood; left out %d: %s" % [people.size(), left_out.size(), ", ".join(PackedStringArray(left_out))])
	var grown := people.filter(func(id: int) -> bool: return Rules.age_of(v, v.people[id]) >= 14)
	# The tied witness first (grown): someone with a tie among the rest, that tie put in the crowd.
	var tie_witness := -1
	var tie := -1
	for a: int in grown:
		for b: int in grown:                   # (a child is no target of a burn: people_actions)
			if a != b and tied(v, a, b):
				tie_witness = a
				tie = b
				break
		if tie_witness >= 0:
			break
	var crowd := [tie] if tie >= 0 else []
	var witnesses := [tie_witness] if tie_witness >= 0 else []
	for id: int in grown:
		if id != tie and id != tie_witness and witnesses.size() < WITNESSES:
			witnesses.append(id)
	for id: int in grown:
		if not crowd.has(id) and not witnesses.has(id) and crowd.size() < CROWD:
			crowd.append(id)
	check(crowd.size() >= MIN_CROWD and witnesses.size() == WITNESSES and tie >= 0, "a crowd of %d grown (of the %d wanted; %d at least, more than one burst takes in), %d witnesses, one tied to %s in the crowd" % [
		crowd.size(), CROWD, MIN_CROWD, WITNESSES, v.people[tie].name if tie >= 0 else "-"])
	var centre := Vector2(player.global_position.x, player.global_position.z)
	for i in crowd.size():
		var a := TAU * float(i) / float(crowd.size())
		var r := 1.2 + 0.8 * float(i % 3)
		stand(crowd[i], centre + Vector2(cos(a), sin(a)) * r, centre)   # held: place() alone leaves a walker's path
	# The tie at the far side of the ring from the tied witness: everyone else in the crowd is nearer to them.
	# The witnesses stand behind the caster, facing the crowd: they see him cast and the star land.
	var side := PI * 0.75
	for i in witnesses.size():
		var a := side + 0.18 * (float(i) - 1.0)
		stand(witnesses[i], centre + Vector2(cos(a), sin(a)) * OUT, centre)
	stand(tie, centre - Vector2(cos(side - 0.18), sin(side - 0.18)) * 2.0, centre)
	player.global_position = Vector3(centre.x + cos(side) * CAST, player.global_position.y, centre.y + sin(side) * CAST)
	await frames(30)
	for i in witnesses.size():               # again: the half second can have walked someone off
		var a := side + 0.18 * (float(i) - 1.0)
		stand(witnesses[i], centre + Vector2(cos(a), sin(a)) * OUT, centre)
	await frames(2)
	for w: int in witnesses:
		var body: Node3D = res.bodies[w]
		var to := player.global_position - body.global_position
		var look := Vector3(sin(body.global_rotation.y), 0, cos(body.global_rotation.y))
		print("SAT witness %s at %.1f m from the player, %.1f m from the centre, facing dot %.2f" % [v.people[w].name, to.length(),
			Vector2(body.global_position.x, body.global_position.z).distance_to(centre), look.dot(to.normalized())])
	var before := {}
	for w: int in witnesses:
		before[w] = stance(v, w)
	var bridge: Node = res.get("people_bridge")
	var built0: int = int(bridge.get("accounts_built")) if bridge.get("accounts_built") != null else -1
	player.abilities._drop_star(null, Vector3(centre.x, player.global_position.y, centre.y), 1.0, "saturation-probe:star")
	# The first burst (1.5 s of active time), then the minutes after: the fallen burn, fall, and some die.
	var first := {}
	var dead := {}
	for f in 30 * 25:
		await get_tree().process_frame
		if f == 30 * 4:
			for w: int in witnesses:
				first[w] = _known(v, w)
		for c: int in crowd:
			if not v.people[c].alive and not dead.has(c):
				dead[c] = f / 30.0
	var built: int = int(bridge.get("accounts_built")) - built0 if built0 >= 0 else -1
	print("SAT crowd=%d dead=%d (%s) accounts_built=%d saturation=%s" % [crowd.size(), dead.size(),
		", ".join(PackedStringArray(dead.keys().map(func(c: int) -> String: return "%s %.1fs" % [v.people[c].name, dead[c]]))), built, str(bridge.get("saturation"))])
	for w: int in witnesses:
		var s := stance(v, w)
		var k := _known(v, w)
		print("SAT witness %s%s wary %d->%d trust %d->%d resentment %d->%d | first burst %d accounts (%s) many %s | after %d accounts, many %s, deaths known %d, saw the caster %s" % [
			v.people[w].name, " (tied to %s)" % v.people[tie].name if w == tie_witness else "",
			int(before[w].get("wary", 0)), int(s.get("wary", 0)), int(before[w].get("trust", 0)), int(s.get("trust", 0)),
			int(before[w].get("resentment", 0)), int(s.get("resentment", 0)),
			first[w].accounts, ", ".join(PackedStringArray(first[w].subjects)), str(first[w].many), k.accounts, str(k.many), k.deaths, str(k.named)])
	for w: int in witnesses:
		for key: String in v.people[w].mind.known:
			var a: Dictionary = v.people[w].mind.known[key]
			print("SAT known %s %s: act %s target %s identity %s many %s count %s via %s" % [v.people[w].name, key.left(16), str(a.get("evidence", {}).get("act", "")),
				str(a.get("target", "")), str(a.get("identity", {}).get("key", "")), str(a.get("evidence", {}).get("many", false)), str(a.get("evidence", {}).get("count", "")), str(a.get("via", ""))])
	for w: int in witnesses:
		var s := stance(v, w)
		var k := _known(v, w)
		var wary := int(s.get("wary", 0)) - int(before[w].get("wary", 0))
		var resent := int(s.get("resentment", 0)) - int(before[w].get("resentment", 0))
		# Grave: as a killing reads (wary and resentment 700 at full confidence), not one blow (about 250 and 270).
		check(bool(k.named) and wary >= 600 and resent >= 600, "%s saw the caster and reads the star as grave toward the player (wary +%d, trust %+d, resentment +%d, deaths known %d)" % [
			v.people[w].name, wary, int(s.get("trust", 0)) - int(before[w].get("trust", 0)), resent, k.deaths])
	# More rows than a burst takes in (a witness can see fewer: a body in the way): the rest as one summary with its count.
	var summed := witnesses.filter(func(w: int) -> bool: return first[w].many.size() == 1 and int(first[w].many[0]) > 0)
	check(not summed.is_empty(), "the rest comes as one summary with its count (%s)" % ", ".join(PackedStringArray(witnesses.map(func(w: int) -> String:
		return "%s %s" % [v.people[w].name, str(first[w].many)]))))
	var aid := 0
	var aid_harm := 0
	for w: int in witnesses:
		aid += int(_known(v, w).aid)
		aid_harm += int(_known(v, w).aid_harm)
	check(aid_harm == 0, "a rescue never reads as harm: %d help summaries (\"many were helped\") known to the witnesses, %d read as harm" % [aid, aid_harm])
	if tie_witness >= 0:
		var mine := first[tie_witness].subjects as Array
		check(mine.has(v.people[tie].name), "%s takes in %s among the fallen first, from the far side of the ring (%s)" % [v.people[tie_witness].name,
			v.people[tie].name, ", ".join(PackedStringArray(mine))])
	print("SATURATION PROBE complete failures=%d" % failed)
	get_tree().quit(0 if failed == 0 else 1)


## What a witness knows of the star's fallen: accounts by subject name, the summaries' counts, the deaths, and whether
## they saw who cast it (an account naming the player).
func _known(v, w: int) -> Dictionary:
	var out := {"accounts": 0, "subjects": [], "many": [], "deaths": 0, "named": false, "aid": 0, "aid_harm": 0}
	for key: String in v.people[w].mind.known:         # the aftermath's help summaries: read as help, never as harm
		var h: Dictionary = v.people[w].mind.known[key]
		if str(h.get("evidence", {}).get("act", "")) == "help" and bool(h.get("evidence", {}).get("many", false)):
			out.aid += 1
			var name := str(v.people[w].mind.appraised.get(key, {}).get("meaning", {}).get("name", ""))
			if name in ["was hurt", "witnessed suffering", "noticed danger"]:
				out.aid_harm += 1
	for key: String in v.people[w].mind.known:
		var a: Dictionary = v.people[w].mind.known[key]
		var ev: Dictionary = a.get("evidence", {})
		var subject := People.resident(v, str(a.get("target", "")))
		if subject < 0 or subject == w:
			continue
		out.accounts += 1
		out.named = out.named or str(a.get("identity", {}).get("key", "")) == "player:local"
		if bool(ev.get("many", false)):
			out.many.append(int(ev.get("count", 0)))
		elif not out.subjects.has(v.people[subject].name):
			out.subjects.append(v.people[subject].name)
		if str(ev.get("act", "")) == "death" or str(ev.get("condition", "")) == "dead":
			out.deaths += 1
	return out
