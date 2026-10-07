extends RefCounted
## A ported resident's body and day (Mind's port, unit 3). Enea's world/npc.gd node for a ported resident stops
## walking his round (a marked line there calls follow()): it is hidden, its solid body off, and it stands where the
## village body is, so his talk stays his, on the one body the player sees. The village
## body (villager_body, moved by the mover) walks his day: for his hour (Residents.activity: work, lunch, evening) a
## routine plan (offers/routine.gd) takes it to his anchor (Sites.anchors) and keeps it there. Any reaction replaces
## that plan (a shove interrupts his woodcutter's day); once the mind has no ongoing plan again, the next look writes
## the routine back. At home (night) no routine is written: the village's own day takes the body indoors.
const Ported := preload("res://scripts/studio/village/sim/ported.gd")
const People := preload("res://scripts/studio/village/sim/people.gd")
const Contact := preload("res://scripts/studio/village/contact.gd")
const Sites := preload("res://scripts/studio/village/sites.gd")
const VillageImage := preload("res://scripts/studio/village/sim/image.gd")
const PeopleActions := preload("res://scripts/studio/village/sim/people_actions.gd")
const Routine := preload("res://scripts/studio/people/offers/routine.gd")
const Tell := preload("res://scripts/studio/people/offers/tell.gd")
const PortStance := preload("res://scripts/studio/people/port_stance.gd")
const TELL_FEELING := 300        # how strongly a tenant must feel about the player to talk about it
const TELL_REACH := 20.0         # metres: a neighbour this near is told
const LOOK_EVERY := 5.0            # seconds between looks at one resident's day (desk 05:00, rule 7: from 1 s)
const TICKS_PER_DAY := 1440 * 500  # People.tick per village day (a village minute is 500)

static var _next_look := {}
static var _next_village_look := 0.0
static var _tell_seen := {}       # tenant -> [village day, receipts, plan generation, busy, pending]: the tell check runs
                                  # only when one of them moves (a reaction ending frees the mind without a new generation)


## Called every frame from his npc.gd for a resident; false when the port does not route them (his round goes on).
static func follow(npc: Node3D, id: String) -> bool:
	if not Ported.enabled() or not VillageSession.active or VillageSession.village == null:
		return false
	var v = VillageSession.village
	var pid := Ported.person_of(v, id)
	var registry := Contact.registry(npc.get_tree())
	if pid < 0 or registry == null or not registry.bodies.has(pid):
		return false
	var body: Node3D = registry.bodies[pid]
	var at: Vector2 = registry._movers[pid].pos
	npc.global_position = Vector3(at.x, body.global_position.y, at.y)
	# His whole node is hidden: the village's crowd steps round every visible npc.gd node, and one standing on the
	# body pushed it off its way (6 Oct probe: Tomas circling his cottage). His talk stays (the player's reach does not
	# need it visible); his marker and greeting come back when Body's crowd honours crowd_ignore (asked of the desk).
	if npc.visible:
		npc.visible = false
		npc.set_meta("crowd_ignore", true)
		var solid: Node = npc.get("_body")
		if solid != null:
			solid.process_mode = Node.PROCESS_MODE_DISABLED
	var p = v.people[pid]
	# Downed, dead or away: no talk or gift panel (the desk's term 2); his marker and words go with the node.
	var talks: bool = p.alive and p.present and body.is_visible_in_tree() and not PeopleActions.down(v, p)
	if talks != npc.is_in_group("interactable"):
		if talks:
			npc.add_to_group("interactable")
		else:
			npc.remove_from_group("interactable")
	# His day and the tenants' tellings are looked at every LOOK_EVERY seconds: on Foundations' think scheduler where
	# it is (smoothness, desk 6 Oct: staggered, within the frame's think budget), else polled here as before.
	if _think != null:
		var tree := npc.get_tree()          # (the scene tree outlives his node; a look never touches the node)
		if not _think.has("port:" + id, "day"):
			_think.every("port:" + id, "day", LOOK_EVERY, func(_elapsed: float) -> void: _look_day(tree, id))
			_think.now("port:" + id, "day", "first look")      # the first look at once, as the poll did
		if not _think.has("port", "tell"):
			_think.every("port", "tell", LOOK_EVERY, func(_elapsed: float) -> void: _look_village(tree))
		return true
	var now := Time.get_ticks_msec() / 1000.0
	if now >= float(_next_look.get(id, 0.0)):
		_next_look[id] = now + LOOK_EVERY
		keep_day(v, registry, id, pid)
	if now >= _next_village_look:                 # the tenants have no node of his in the meadow: looked at from here
		_next_village_look = now + LOOK_EVERY
		_look_village(npc.get_tree())
	return true


## Foundations' think scheduler (studio/village/think.gd, branch think bf0cc6a) when this build has it.
static var _think: Variant = load("res://scripts/studio/village/think.gd") if ResourceLoader.exists("res://scripts/studio/village/think.gd") else null


## One look at a resident's day, as follow() made it: the village and his body read afresh (a scheduled look may run
## after a load or with the port switched off).
static func _look_day(tree: SceneTree, id: String) -> void:
	if tree == null or not Ported.enabled() or not VillageSession.active or VillageSession.village == null:
		return
	var v = VillageSession.village
	var pid := Ported.person_of(v, id)
	var registry := Contact.registry(tree)
	if pid >= 0 and registry != null and registry.bodies.has(pid):
		keep_day(v, registry, id, pid)


## The tenants have no node of his in the meadow: looked at from here, only on a new day, a new receipt (a stance
## change comes with one) or a telling still pending.
static func _look_village(tree: SceneTree) -> void:
	if tree == null or not Ported.enabled() or not VillageSession.active or VillageSession.village == null:
		return
	var v = VillageSession.village
	var registry := Contact.registry(tree)
	if registry == null:
		return
	var lettings := tree.root.get_node_or_null("Lettings")
	if lettings == null:
		return
	for house: int in lettings.owned:            # the tenants of a let house are its village family (merge-fix)
		var key := "house:%d" % house
		var family: Array = PortStance.family(v, house).filter(func(pid: int) -> bool: return Rules_age(v, v.people[pid]) >= 14)
		if family.is_empty():
			continue
		var mark := [v.day, v.runtime.get("port_telling", {}).has(key)]
		for pid: int in family:
			mark.append_array([v.people[pid].mind.appraised.size(), v.people[pid].mind.generation, People.ongoing(v.people[pid].mind.plan, People.tick(v))])
		if mark == _tell_seen.get(key) and not mark[1]:
			continue
		_tell_seen[key] = mark
		# The one who tells: the speaker of a telling still pending, else the one who feels most strongly.
		var pending: Dictionary = v.runtime.get("port_telling", {}).get(key, {})
		var speaker := int(pending.get("speaker", -1)) if int(pending.get("day", -1)) == v.day else -1
		if speaker < 0:
			var most := 0
			for pid: int in family:
				var f := absi(int(People.stance_view(v.people[pid].mind, People.tick(v), [PortStance.PLAYER]).get(PortStance.PLAYER, {}).get("feeling", 0)))
				if f > most:
					most = f
					speaker = pid
		if speaker >= 0:
			tell(v, registry, speaker, key, family)


## A tenant (a grown member of a let house's family) who feels strongly about the player (feeling at or past
## TELL_FEELING either way) tells the nearest neighbour outside the family what the player did, once a village day
## per house (`id`, "house:N"; runtime.port_told: the day it was told), while their mind is
## idle. The telling is done when the neighbour has heard it (the report's people_facts entry); a reaction that cuts it
## short leaves it pending (runtime.port_telling), and it is tried again when the mind is idle, up to TELL_TRIES a day.
const TELL_TRIES := 3
static func tell(v, registry: Node, pid: int, id: String, family: Array = []) -> void:
	if pid < 0 or not registry.bodies.has(pid):
		return
	var p = v.people[pid]
	if not p.alive or not p.present or int(v.runtime.get("port_told", {}).get(id, -1)) == v.day:
		return
	var bridge: Object = registry.get("people_bridge")
	if bridge == null or not bridge.available():
		return
	var pending: Dictionary = v.runtime.get("port_telling", {}).get(id, {})
	if int(pending.get("day", -1)) != v.day:
		pending = {}
	if not pending.is_empty():
		var key := "report:" + (str(pending.deed) + "|" + People.key(v, pid) + "|" + str(pending.target)).sha256_text().substr(0, 32)
		if v.people_facts.has(key) or int(pending.tries) >= TELL_TRIES:
			bridge.accept(func(candidate) -> Dictionary:       # told (or tried enough today)
				VillageImage.touch_key("runtime", "port_told")
				VillageImage.touch_key("runtime", "port_telling")
				candidate.runtime.get_or_add("port_told", {})[id] = candidate.day
				candidate.runtime.get_or_add("port_telling", {}).erase(id)
				return {"accepted": true})
			return
	var m = p.mind
	if People.ongoing(m.plan, People.tick(v)):
		return
	var feeling := int(People.stance_view(m, People.tick(v), [PortStance.PLAYER]).get(PortStance.PLAYER, {}).get("feeling", 0))
	if pending.is_empty() and absi(feeling) < TELL_FEELING:
		return
	var account := {}                              # their own latest account of something the player did
	for episode in m.episodes:
		var a: Dictionary = People.episode_account(m, episode)
		if str(a.get("identity", {}).get("key", "")) == PortStance.PLAYER and str(a.get("via", "")) in ["felt", "seen"]:
			account = a
	if account.is_empty():
		return
	var here: Vector2 = registry._movers[pid].pos
	var listener := -1
	var best := TELL_REACH
	for other: int in registry.bodies:
		var q = v.people[other]
		if other == pid or family.has(other) or not q.alive or not q.present or q.authored != "" or Rules_age(v, q) < 14 or PortStance.TENANTS.has(Ported_id(v, other)):
			continue                               # a grown neighbour, not of the family, not one of Enea's story people
		var d: float = here.distance_to(registry._movers[other].pos)
		if d < best:
			best = d
			listener = other
	if listener < 0:
		return
	var key := People.key(v, listener)
	var tries := int(pending.get("tries", 0)) + 1
	bridge.accept(func(candidate) -> Dictionary:
		VillageImage.touch(pid)
		VillageImage.touch_key("runtime", "port_telling")
		var mind = candidate.people[pid].mind
		var offer := Tell.new()
		var a := {"kind": "tell", "listener": key, "account": account}
		mind.generation += 1
		var lasts := roundi(offer.lasts({}, a) * 1000.0)
		mind.plan = {"offer": "tell", "deed": str(account.deed), "account": "", "phase": 0, "generation": mind.generation,
			"steps": offer.steps({}, a), "effects": {}, "self_account": "", "control": {}, "duration_ms": lasts,
			"until": People.tick(candidate) + lasts}
		candidate.runtime.get_or_add("port_telling", {})[id] = {"deed": str(account.deed), "target": key, "day": candidate.day, "tries": tries, "speaker": pid}
		return {"accepted": true})


static func Rules_age(v, q) -> int:
	return preload("res://scripts/studio/village/sim/village.gd").age_of(v, q)


static func Ported_id(v, pid: int) -> String:
	for entry: Dictionary in v.runtime.get("ported", []):
		if int(entry.person) == pid:
			return str(entry.id)
	return ""


## Called every frame from his npc.gd for an indoor copy (world/visit_interior.gd: a resident at home, a tenant in
## the house you let). A ported resident or tenant who is dead or away is not there: no figure, no talk or gift panel.
static func still(npc: Node3D, id: String) -> void:
	if not Ported.enabled() or not VillageSession.active or VillageSession.village == null:
		return
	var v = VillageSession.village
	var pid := Ported.person_of(v, id)
	if pid < 0:
		return
	var p = v.people[pid]
	var there: bool = p.alive and p.present
	if npc.visible != there:
		npc.visible = there
	if there != npc.is_in_group("interactable"):
		if there:
			npc.add_to_group("interactable")
		else:
			npc.remove_from_group("interactable")


## The routine for his hour, written when the mind is idle (no ongoing plan) or its routine is for another hour.
static func keep_day(v, registry: Node, id: String, pid: int) -> void:
	var p = v.people[pid]
	if not p.alive or not p.present:
		return
	var act: String = Residents.activity(id)
	var m = p.mind
	var tick := People.tick(v)
	var ongoing := People.ongoing(m.plan, tick)
	if ongoing and (str(m.plan.get("offer", "")) != "routine" or str(m.plan.get("effects", {}).get("act", "")) == act):
		return                     # a reaction is playing, or his hour's routine already is
	if act == "home":
		return                     # night: the village's day takes him in at his door
	var anchor: Vector2 = Sites.anchors(Residents.def(id))[act]
	var bridge: Object = registry.get("people_bridge")
	if bridge == null or not bridge.available():
		return
	var t: float = Residents.now()
	var until := tick + roundi(maxf(0.0, end_of(id, act, t) - t) * TICKS_PER_DAY)
	bridge.accept(func(candidate) -> Dictionary:
		VillageImage.touch(pid)
		var mind = candidate.people[pid].mind
		var offer := Routine.new()
		var a := {"kind": "routine", "act": act, "at": [anchor.x, anchor.y]}
		mind.generation += 1
		mind.plan = {"offer": "routine", "deed": "routine:%s:%s:%d" % [id, act, until], "account": "", "phase": 0,
			"generation": mind.generation, "steps": offer.steps({}, a), "effects": offer.effects({}, a), "self_account": "",
			"control": {}, "duration_ms": until - People.tick(candidate), "until": until}
		return {"accepted": true})


## When his activity ends (his hours: lunch 0.50-0.56, the evening from 0.76, bed).
static func end_of(id: String, act: String, t: float) -> float:
	var bed: float = Residents.def(id).get("bed", 0.85)
	match act:
		"lunch":
			return 0.56
		"evening":
			return bed
		"work":
			return 0.5 if t < 0.5 else 0.76
	return t
