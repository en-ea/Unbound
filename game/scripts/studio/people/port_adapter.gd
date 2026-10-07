extends RefCounted
## The one seam Enea's residents and lettings read the ported people through (plan MIND-PORT-PLAN-2026-10-06, layer E).
## His files call these from marked `# studio:` lines; each takes his own value as the fallback and returns it
## unchanged whenever the port does not route that character (the switch off, no live village, not joined), so
## with the switch off his game is exactly his.
##
##   routes(id)                     is his resident or tenant a person of the live village now?
##   liking(id, his)                his rules' liking: from the stance (port_stance.gd), else his own number
##   give(id, item, loved)          his gift as one checked act through the people system -> accepted
##   tenant_mood(house, his)        the mood his rent and words read: rent.gd over his contentment and the house's
##                                  family (the tenants since merge-fix), else his mood
##   tenant_pays(house)             false when the house's family are all dead or have moved out
##   tenant_day(house, his)         his new day for a let house: a family miserable for LEAVE_DAYS moves out, and
##                                  comes back after AWAY_DAYS (his buy rule's start then) -> "left", "back" or ""
##   remembered(id, text)           his talk line, after a line of what the resident remembers of the player
##
## The first read for a village runs the once-per-resident save upgrade (his saved liking into the stance) and the
## tenants' presence as one checked batch (people_bridge.accept, so the save image and journal see it); both are
## idempotent (port_stance.gd markers), so the order of his loads does not matter so long as his residents kind has
## loaded before the first talk, price or rent read. Until a resident is upgraded, his own liking is returned.
const Ported := preload("res://scripts/studio/village/sim/ported.gd")
const People := preload("res://scripts/studio/village/sim/people.gd")
const PortStance := preload("res://scripts/studio/people/port_stance.gd")
const Rent := preload("res://scripts/studio/people/rent.gd")
const PlayerActs := preload("res://scripts/studio/village/player_acts.gd")
const Contact := preload("res://scripts/studio/village/contact.gd")
const Houses := preload("res://scripts/world/village.gd")
const VillageImage := preload("res://scripts/studio/village/sim/image.gd")
const HomeFolk := preload("res://scripts/world/home_folk.gd")

const LEAVE_MOOD := 15        # a tenant whose rent mood stays below this ...
const LEAVE_DAYS := 3         # ... for this many of his days moves out ...
const AWAY_DAYS := 3          # ... for this many village days, then comes back
const STRONG := ["freed_by_you", "hit_by_you", "shoved_by_you", "threatened_by_you", "saw_you_hit", "saw_you_shove", "angered"]
const Lines := preload("res://scripts/studio/village/resident_lines.gd")
const View := preload("res://scripts/studio/village/sim/view.gd")

static var _press := 0


## The live village when the port routes his characters, else null.
static func village() -> Object:
	if not Ported.enabled() or not VillageSession.active or VillageSession.village == null:
		return null
	var v = VillageSession.village
	if v.runtime.is_empty() or not v.runtime.has("ported"):
		return null
	if PortStance.unsettled(v, Lettings.owned):
		_settle(v)
	return v


## The save upgrade belongs at load (People.upgrade's pattern); until Foundations calls it there, the first read does
## it here, once per village, and hands the image the whole village (VillageImage.rebase, not on disk), so the next
## save writes it in full: a stance written outside a learn is invisible to a batch's change finding. Tenants'
## presence (person fields, which a batch's change finding does see) changes in one checked batch.
static func _settle(v: Object) -> void:
	if v.runtime.get("port_liking", []).size() < Ported.PEOPLE.size():
		PortStance.upgrade(v, Residents.liking.duplicate())
		VillageImage.rebase(v, false)
	if not PortStance.unsettled(v, Lettings.owned):
		return
	var registry := Contact.registry(Engine.get_main_loop() as SceneTree)
	var bridge: Object = registry.get("people_bridge") if registry != null else null
	if bridge == null or not bridge.available():
		return
	var owned: Dictionary = Lettings.owned.duplicate()
	bridge.accept(func(candidate) -> Dictionary:
		VillageImage.touch_key("runtime", "port_unhoused")
		for id: String in PortStance.TENANTS:
			VillageImage.touch_person(Ported.person_of(candidate, id))
		PortStance.sync_presence(candidate, owned)
		return {"accepted": true})


static func routes(id: String) -> bool:
	var v = village()
	return v != null and PortStance.person(v, id) != null


static func liking(id: String, his: int) -> int:
	var v = village()
	if v == null or PortStance.person(v, id) == null or not v.runtime.get("port_liking", []).has(id):
		return his
	return PortStance.liking(v, id)


## One checked "give" act on the resident's village body (PlayerActs.perform, as PlayerActs.gift does) carrying his
## worth: 2 a loved gift, 1 another. The item leaves his Inventory only when the act is written; the resident and
## any witness learn it, and the resident's tally counts it once.
static func give(id: String, item: String, loved: bool) -> bool:
	var v = village()
	var registry := Contact.registry(Engine.get_main_loop() as SceneTree)
	var pid := Ported.person_of(v, id) if v != null else -1
	if pid < 0 or registry == null:
		return false
	_press += 1
	var receipt: Dictionary = PlayerActs.perform("player:local", registry, "give", pid,
		{"item": item, "count": 1, "press_id": "port-gift:%s:%d:%d" % [id, People.tick(v), _press], "worth": 2 if loved else 1})
	return bool(receipt.get("accepted", false)) and not bool(receipt.get("duplicate", false))


static func tenant_mood(house: int, his: int) -> int:
	var v = village()
	if v == null or house < 0 or house >= Houses.HOUSES.size() or PortStance.family(v, house).is_empty():
		return his
	return Rent.mood(v, house, Houses.HOUSES[house]["at"], his)


static func tenant_pays(house: int) -> bool:
	var v = village()
	return v == null or Rent.pays(v, house)


## His new day for a let house: the family (the tenants, merge-fix) miserable for LEAVE_DAYS packs up and leaves, the
## members then present taken away together until AWAY_DAYS have passed (runtime.port_left["house:N"] {back, pids}).
static func tenant_day(house: int, his: int) -> String:
	var v = village()
	if v == null:
		return ""
	var key := "house:%d" % house
	var family: Array = PortStance.family(v, house)
	var left: Variant = v.runtime.get("port_left", {}).get(key, null)
	if family.is_empty() and left == null:
		return ""
	var registry := Contact.registry(Engine.get_main_loop() as SceneTree)
	var bridge: Object = registry.get("people_bridge") if registry != null else null
	if bridge == null or not bridge.available():
		return ""
	var unhappy := int(v.runtime.get("port_unhappy", {}).get(key, 0))
	var event := ""
	if left is Dictionary:
		if int(left.get("back", 0)) <= int(v.day):
			event = "back"
	elif tenant_mood(house, his) < LEAVE_MOOD:
		unhappy += 1
		event = "left" if unhappy >= LEAVE_DAYS else "unhappy"
	elif unhappy > 0:
		event = "settled"
	if event == "":
		return ""
	var going: Array = family.filter(func(pid: int) -> bool: return v.people[pid].present)
	var touched: Array = going if event == "left" else (left.get("pids", []) if left is Dictionary else [])
	bridge.accept(func(candidate) -> Dictionary:
		for k: String in ["port_left", "port_unhappy"]:
			VillageImage.touch_key("runtime", k)
		for pid: int in touched:
			VillageImage.touch_person(pid)
		var gone: Dictionary = candidate.runtime.get_or_add("port_left", {})
		var sour: Dictionary = candidate.runtime.get_or_add("port_unhappy", {})
		match event:
			"back":
				PortStance.sync_families(candidate)       # (the day has come: they are made present again)
				gone.erase(key)
			"left":
				gone[key] = {"back": int(candidate.day) + AWAY_DAYS, "pids": going}
				sour.erase(key)
				PortStance.sync_families(candidate)
			"unhappy":
				sour[key] = unhappy
			"settled":
				sour.erase(key)
		return {"accepted": true})
	var name := HomeFolk.family_of(house)
	var who := ("The %s family" % name) if name != "" else "Your tenants"
	if event == "left":
		(Engine.get_main_loop() as SceneTree).call_group("hud", "hint", "%s have packed up and left %s. The house stands empty." % [who, Lettings.HOUSES[house]["name"]])
	elif event == "back":
		(Engine.get_main_loop() as SceneTree).call_group("hud", "hint", "%s are back at %s, giving it another try." % [who, Lettings.HOUSES[house]["name"]])
	return event if event in ["left", "back"] else ""


## His resident's talk line, after a line of what they remember of the player when it is strong (freed by you, hit,
## shoved, threatened, seen hitting someone): the studio's own resident lines (read only), chosen as for any villager.
static func remembered(id: String, text: String) -> String:
	var v = village()
	var pid := Ported.person_of(v, id) if v != null else -1
	if pid < 0:
		return text
	var d: Dictionary = View.describe(v, pid)
	var known: Array = (d.toward_player as Dictionary).memories
	if not STRONG.any(func(token: String) -> bool: return known.has(token)):
		return text
	var minute := int(v.runtime.now) % 1440
	return Lines.line(d, int(v.day), minute) + " " + text
