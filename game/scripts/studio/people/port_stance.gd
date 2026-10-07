extends RefCounted
## Mind's side of the port of Enea's meadow residents and tenants (plan MIND-PORT-PLAN-2026-10-06). Foundations' join
## (village/sim/ported.gd) makes them ordinary villagers; this file is what their minds hold for his rules:
##
##   upgrade(v, liking)      once per joined resident: his saved liking L becomes the stance's gift tally (marker
##                           runtime.port_liking, the ids converted)
##   liking(v, id)           what his rules read as liking, from the stance toward the player
##   gifts(v, id)            the stance's gift tally (+2 a loved gift, +1 another, once per accepted gift deed:
##                           people.gd replace_stance, the worth carried by sources/gift.gd)
##   sync_presence(v, owned) a tenant is present only while the player owns their house (his rule)
##
## One authoritative route (desk term 1): after the upgrade, liking is read only from the stance. His saved
## `residents` liking field is frozen: no code writes it, and only upgrade reads it, once per resident (the
## runtime.port_liking marker stops a second conversion). A tenant's contentment stays his `lettings` mood field.
const S := preload("res://scripts/studio/village/sim/state.gd")
const Ported := preload("res://scripts/studio/village/sim/ported.gd")
const People := preload("res://scripts/studio/village/sim/people.gd")

const Rules := preload("res://scripts/studio/village/sim/village.gd")
const C := preload("res://scripts/studio/village/sim/content.gd")

const PLAYER := "player:local"
const TENANTS := {"tenant_odo": 3, "tenant_mira": 4, "tenant_fen": 6}
## The rules' roles from his titles (accepted by the desk, 6 Oct 03:10), set once with the upgrade: woodcutter and
## miller are his own trades; the cook and the tenants take a trade that feeds their household (content.gd ROLES).
const ROLES := {"tomas": "woodcutter", "bram": "miller", "elsa": "merchant", "nell": "child", "tenant_odo": "gatherer",
	"tenant_mira": "merchant", "tenant_fen": "merchant"}
## Who they are (desk 6 Oct 04:36, Hilmi: "be creative with eneas villagers"), from his titles and lines: traits
## (content.gd TRAITS, 0..100: bold, piety, greed, compassion, honesty, temper, alert, sociable), law, temperament.
## The common temperament turns traits into how fast anger and fear rise and fade, pace and personal space.
const WHO := {
	"tomas": {"traits": [78, 35, 30, 55, 70, 74, 45, 28], "law": 45, "temperament": "gruff"},        # the gruff woodcutter
	"elsa": {"traits": [50, 55, 62, 60, 52, 40, 78, 80], "law": 72, "temperament": "common"},       # the shrewd cook
	"nell": {"traits": [62, 40, 20, 70, 75, 35, 85, 82], "law": 50, "temperament": "common"},       # the curious child
	"bram": {"traits": [45, 50, 40, 58, 66, 30, 30, 45], "law": 60, "temperament": "weary"},        # the tired miller
	"tenant_odo": {"traits": [80, 30, 35, 50, 60, 66, 50, 60], "law": 40, "temperament": "gruff"},  # the old sailor
	"tenant_mira": {"traits": [25, 55, 45, 65, 70, 35, 75, 50], "law": 65, "temperament": "common"},# the weaver, wary
	"tenant_fen": {"traits": [45, 40, 40, 55, 50, 40, 72, 88], "law": 55, "temperament": "common"}, # the scribe, talkative
}
## Ties with the village's own people: [his id, the village role they are tied to (the lowest-id living adult of it,
## not one of his), opinion both ways]. Bram and Tomas are old friends; the rest find their match by trade or age.
const TIES := [["tomas", "woodcutter", 60], ["bram", "miller", -45], ["elsa", "merchant", 55], ["nell", "child", 65],
	["tenant_fen", "sociable", 50], ["tenant_odo", "elder", 35]]


## liking: his saved Residents.liking ({id: int}); null reads the Residents autoload when the game has one.
## Call after Foundations' join and after his residents kind has loaded. Returns how many were converted.
## No memory, receipt or deed is invented: feeling 0, gifts L, so his rules read L exactly.
static func upgrade(v: S.Village, liking: Variant = null) -> int:
	if v.runtime.is_empty():
		return 0
	if liking == null:
		var residents := _autoload("Residents")
		liking = residents.liking if residents != null else {}
	var done: Array = v.runtime.get_or_add("port_liking", [])
	var converted := 0
	for id: String in Ported.PEOPLE:
		var p := person(v, id)
		if p == null or done.has(id):
			continue
		done.append(id)
		if p.role != "elder" and p.role != "priest":
			p.role = ROLES[id]
		var saved := int((liking as Dictionary).get(id, 0)) if liking is Dictionary else 0
		if saved == 0:
			continue
		var row: Dictionary = p.mind.stances.get_or_add(PLAYER, {"wary": 0, "trust": 0, "resentment": 0, "obligation": 0, "hits": 0,
			"feeling": 0, "tick": People.tick(v), "remainders": {}})
		row.gifts = int(row.get("gifts", 0)) + saved
		converted += 1
	characters(v)
	return converted


## Once per resident (marker runtime.port_who): their traits, law, temperament and ties. Called by upgrade, so the
## join's load path writes it before the image binds; never during play.
static func characters(v: S.Village) -> void:
	var done: Array = v.runtime.get_or_add("port_who", [])
	for id: String in WHO:
		var p := person(v, id)
		if p == null or done.has(id):
			continue
		done.append(id)
		var who: Dictionary = WHO[id]
		p.traits = PackedInt32Array(who.traits)
		p.values[C.V_LAW] = int(who.law)
		p.mind.temperament = str(who.temperament)
		for tie: Array in TIES:
			if tie[0] == id:
				var other := _match(v, str(tie[1]), p)
				if other >= 0:
					Rules.set_opinion(v, p.id, other, int(tie[2]))
					Rules.set_opinion(v, other, p.id, int(tie[2]))
	var tomas := person(v, "tomas")
	var bram := person(v, "bram")
	if tomas != null and bram != null and Rules.opinion(v, bram.id, tomas.id) == 0:
		Rules.set_opinion(v, bram.id, tomas.id, 60)
		Rules.set_opinion(v, tomas.id, bram.id, 60)


## The village person a tie goes to: the lowest-id living, present one of that role (a child near her age for
## "child", the most sociable adult for "sociable", the elder for "elder"), never one of his seven.
static func _match(v: S.Village, kind: String, me: S.Person) -> int:
	var his := {}
	for id: String in Ported.PEOPLE:
		var q := person(v, id)
		if q != null:
			his[q.id] = true
	if kind == "elder":
		return v.authority if v.authority >= 0 and not his.has(v.authority) else -1
	var best := -1
	for q: S.Person in v.people:
		if not q.alive or not q.present or his.has(q.id) or q.authored != "":
			continue
		var age := Rules.age_of(v, q)
		if kind == "child":
			if q.role == "child" and absi(age - Rules.age_of(v, me)) <= 3:
				return q.id
		elif kind == "sociable":
			if age >= 18 and (best < 0 or q.traits[C.SOCIABLE] > v.people[best].traits[C.SOCIABLE]):
				best = q.id
		elif q.role == kind and age >= 16:
			return q.id
	return best


## Whether upgrade or sync_presence would change anything (a cheap read, so callers run them only when needed).
static func unsettled(v: S.Village, owned: Dictionary) -> bool:
	var done: Array = v.runtime.get("port_liking", [])
	var unhoused: Dictionary = v.runtime.get("port_unhoused", {})
	for id: String in Ported.PEOPLE:
		var p := person(v, id)
		if p == null:
			continue
		if not done.has(id):
			return true
		if TENANTS.has(id):
			var housed := home(v, id, owned)
			if (not housed and p.present and not unhoused.has(id)) or (housed and unhoused.has(id)):
				return true
	return false


static func _autoload(name: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null(name) if tree != null else null


static func person(v: S.Village, id: String) -> S.Person:
	var pid := Ported.person_of(v, id)
	return v.people[pid] if pid >= 0 and pid < v.people.size() else null


static func toward_player(v: S.Village, id: String) -> Dictionary:
	var p := person(v, id)
	if p == null:
		return {}
	return People.stance_view(p.mind, People.tick(v), [PLAYER]).get(PLAYER, {})


static func gifts(v: S.Village, id: String) -> int:
	return int(toward_player(v, id).get("gifts", 0))


## max(0, gifts + feeling / 100), feeling counted only below zero: a gift already raises trust and obligation
## (appraisal), so counting a positive feeling too would give a gift-only player more than his numbers. Harm
## lowers it (feeling -300 takes three points of his discount away); a later gift's trust offsets that harm.
static func liking(v: S.Village, id: String) -> int:
	var row := toward_player(v, id)
	return maxi(0, int(row.get("gifts", 0)) + mini(0, int(row.get("feeling", 0))) / 100)


## Tenants live in the meadow only while their house is owned and they have not moved out (runtime.port_left, the
## village day they come back; port_adapter.gd tenant_day). Only absence this sets is undone here (marker
## runtime.port_unhoused): a tenant away for the rules' own reasons (a storm, exile) is left as the rules have them.
## owned: his Lettings.owned ({house: level}); null reads the Lettings autoload.
static func sync_presence(v: S.Village, owned: Variant = null) -> void:
	if v.runtime.is_empty():
		return
	if owned == null:
		var lettings := _autoload("Lettings")
		if lettings == null:
			return
		owned = lettings.owned
	for id: String in TENANTS:
		var p := person(v, id)
		if p == null:
			continue
		var unhoused: Dictionary = v.runtime.get_or_add("port_unhoused", {})
		var housed := home(v, id, owned)
		if not housed and p.present and not unhoused.has(id):
			p.present = false
			unhoused[id] = true
		elif housed and unhoused.has(id):
			p.present = true
			unhoused.erase(id)


## Whether one of his tenants lives in their house now: never while the port is on (Enea, 6 Oct, merge-fix: "Enea's
## tenants have left; the family in a house you buy pays the rent"; Hilmi agreed). The house's own village family are
## its tenants (family() below); his three stay absent, gated, not removed: with the port off his game is his.
static func home(_v: S.Village, _id: String, _owned: Dictionary) -> bool:
	return false


## The tenants of his house `house` (Lettings.HOUSES index): the village family living in that home (Ported.HOUSE_HOME),
## alive, not one of his seven. [] when nobody lives there.
static func family(v: S.Village, house: int) -> Array:
	var out := []
	var home_name: String = Ported.HOUSE_HOME.get(house, "")
	if home_name == "" or v == null:
		return out
	for h in v.households:
		if h.home != home_name:
			continue
		for pid: int in h.members:
			if pid >= 0 and pid < v.people.size() and v.people[pid].alive and not Ported.keeps_house(v, pid):
				out.append(pid)
	return out


## A family that has moved out (runtime.port_left["house:N"] = {back: day, pids: [...]}, port_adapter.gd tenant_day)
## is away until that day: only the members it took away are made present again, as for his tenants before.
static func sync_families(v: S.Village) -> void:
	for key: String in v.runtime.get("port_left", {}):
		if not key.begins_with("house:"):
			continue
		var row: Variant = v.runtime.port_left[key]
		if not row is Dictionary:
			continue
		var away: bool = int(row.get("back", 0)) > v.day
		for pid: int in row.get("pids", []):
			if pid >= 0 and pid < v.people.size() and v.people[pid].alive:
				v.people[pid].present = not away
