extends RefCounted
## The rent rule of the port (plan MIND-PORT-PLAN-2026-10-06, "The rent rule"): the mood Enea's rent reads is the
## tenant's contentment with the house (his lettings `mood` field, his drift its only writer), moved by how they feel
## about the player and by harm to the home. His formula and words then read it unchanged (state/lettings.gd).
##
##   mood = clamp(contentment + feeling_toward_player / 10 - home_damage, 0, 100)
##
## feeling: the grown family's mean stance feeling toward the player, -1000..1000, as projected now (it fades). One shove that
## sours a tenant (about -250) costs about 25 points; a gift raises it.
## home_damage: accepted thing facts on the house (thing id "house@<x dm>,<z dm>" at the house's centre, thing_facts.gd):
## burning or burnt through (scorched 1000) 40, broken 25, the worse of them; 0 when no fact exists (houses are not things yet).
## A family all dead, or moved out, pays nothing (pays() below; lettings.gd rent reads it).
const S := preload("res://scripts/studio/village/sim/state.gd")
const People := preload("res://scripts/studio/village/sim/people.gd")
const ThingFacts := preload("res://scripts/studio/village/sim/thing_facts.gd")
const PortStance := preload("res://scripts/studio/people/port_stance.gd")
const Rules := preload("res://scripts/studio/village/sim/village.gd")
const GROWN := 14

const BURNT := 40
const BROKEN := 25


static func mood(v: S.Village, house: int, house_at: Vector2, contentment: int) -> int:
	return clampi(contentment + feeling(v, house) / 10 - home_damage(v, house_at), 0, 100)


## The tenants' feeling toward the player: the mean over the house's grown family (PortStance.family; merge-fix, the
## family are the tenants), as projected now. 0 with no grown member.
static func feeling(v: S.Village, house: int) -> int:
	var total := 0
	var n := 0
	for pid: int in PortStance.family(v, house):
		if Rules.age_of(v, v.people[pid]) < GROWN:
			continue
		total += int(People.stance_view(v.people[pid].mind, People.tick(v), [PortStance.PLAYER]).get(PortStance.PLAYER, {}).get("feeling", 0))
		n += 1
	return total / n if n > 0 else 0


static func home_damage(v: S.Village, house_at: Vector2) -> int:
	var id := ThingFacts.id_at("house", house_at.x, house_at.y)
	var damage := 0
	if not ThingFacts.get_fact(v, id, "burning").is_empty() or int(ThingFacts.get_fact(v, id, "scorched").get("level", 0)) >= 1000:
		damage = BURNT
	elif not ThingFacts.get_fact(v, id, "broken").is_empty():
		damage = BROKEN
	return damage


## Whether the tenants are there to pay: someone of the family alive, and the family not moved out.
static func pays(v: S.Village, house: int) -> bool:
	var left: Variant = v.runtime.get("port_left", {}).get("house:%d" % house, {})
	if left is Dictionary and int(left.get("back", 0)) > v.day:
		return false
	return not PortStance.family(v, house).is_empty()
