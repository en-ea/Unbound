extends RefCounted
## Daily life you can see: what a resident's body does while it stands somewhere, chosen from what the
## resident view says they are doing (sim/view.gd activity), their trade and the minute. Pure: the same
## inputs give the same loop, so the village looks the same to every observer.
##
##   pick(verb, role, age_group, id, minute, partner, inside) -> {loop, tool, hidden, face}
##
##   loop    an animation the villager body can loop (VillagerBody.play_loop): UAL1 and UAL2 names
##   tool    a tool in the hand ("axe", "pickaxe") or "" (VillagerBody.show_tool)
##   hidden  indoors: asleep (night) or away; the body is not drawn and costs nothing
##   face    where a standing body looks: "partner" (whoever they chat with), "place" (the work, the shrine,
##           the well), "home" (their own house), or "" (as they were)
##
## The loops were chosen from a line-up of the rig's animations (anim_lineup.gd): the ones that read as the
## work at a glance from the game's camera, and no seated pose (there is nothing to sit on).

const LOOPS := {
	"farming": ["Farm_Harvest", "Farm_PlantSeed", "Farm_Harvest"],
	"herding": ["Idle_FoldArms", "Idle", "Idle_FoldArms"],
	"woodcutting": ["TreeChopping"],
	"hunting": ["Crouch_Idle", "Idle_FoldArms", "Crouch_Idle"],
	"gathering": ["Farm_PlantSeed", "Farm_Harvest"],
	"milling": ["Push", "Fixing_Kneeling", "Push"],
	"smithing": ["TreeChopping"],
	"praying": ["Spell_Simple_Idle", "Crouch_Idle", "Spell_Simple_Idle"],
	"fetching_water": ["Farm_Watering", "Farm_Watering", "Idle"],
	"trading": ["Idle_Talking", "Yes", "Idle_FoldArms", "Idle_Talking"],
	"eating": ["Consume"],
	"at_home": ["Idle_FoldArms", "Fixing_Kneeling", "Farm_Watering"],
	"visiting": ["Idle_Talking", "Idle_FoldArms"],
	"loitering": ["Idle_FoldArms", "Idle", "Idle_FoldArms"],
	"hiding": ["Crouch_Idle"],
	"idle": ["Idle"],
}
const CHILD_LOOPS := {
	"at_home": ["Idle", "Farm_PlantSeed", "Crouch_Idle", "Idle", "Dance"],   # playing at the door
	"eating": ["Consume"],
	"chatting": ["Idle_Talking", "Idle_No", "Yes"],
	"loitering": ["Idle", "Farm_PlantSeed", "Idle"],
}
## Tools in the hand for a trade (VillagerBody.show_tool: made once, on first use).
const TOOLS := {"woodcutting": "axe", "smithing": "pickaxe"}
## The trades whose body faces its work, and the ones that face wherever they stand.
const FACES_WORK := ["farming", "woodcutting", "milling", "smithing", "praying", "fetching_water", "gathering", "trading"]
## A loop is kept for this many minutes, then the next in the list (so a farmer plants, then harvests).
const SPELL := 45


## verb, role, age_group as sim/view.gd gives them; id the resident's id; minute the minute of the game;
## partner the resident they are chatting with (-1 none).
static func pick(verb: String, role: String, age_group: String, id: int, minute: int, partner := -1, inside := false) -> Dictionary:
	if verb in ["sleeping", "away", "held"]:
		return {"loop": "Idle", "tool": "", "hidden": verb != "held", "face": ""}
	if inside and verb in ["at_home", "eating"]:
		return {"loop": "Idle", "tool": "", "hidden": true, "face": ""}        # indoors, at their own door
	var loop := "Idle"
	if verb == "chatting":
		loop = _chat(id, minute, partner, age_group)
	elif age_group == "child" and CHILD_LOOPS.has(verb):
		loop = _cycle(CHILD_LOOPS[verb], id, minute)
	elif LOOPS.has(verb):
		loop = _cycle(LOOPS[verb], id, minute)
	elif verb in ["walking", "travelling"]:
		loop = "Idle"
	var face := ""
	if verb == "chatting" and partner >= 0:
		face = "partner"
	elif verb in FACES_WORK:
		face = "place"
	elif verb in ["at_home", "eating", "visiting"]:
		face = "home"
	if role == "priest" and verb == "praying":
		loop = "Spell_Simple_Idle"                # the keeper of the shrine keeps to the prayer; the others come and go
	return {"loop": loop, "tool": String(TOOLS.get(verb, "")), "hidden": false, "face": face}


## Whether someone at their own home stays indoors for this stretch (out of sight) or is out in the yard about a chore.
## By id and day, and always indoors when the day is over (evening, night) or not yet begun.
static func stays_in(id: int, minute: int, day: int) -> bool:
	if minute >= 1080 or minute < 420:
		return true
	return posmod(id * 7 + day * 3, 10) < 5


## Two who chat take turns: one speaks (Idle_Talking) while the other listens (arms folded, a nod), swapping
## every few minutes. Alone, they just talk.
static func _chat(id: int, minute: int, partner: int, age_group: String) -> String:
	if partner < 0:
		return "Idle_Talking"
	var slot := minute / 6
	var speaking := (slot % 2 == 0) == (id < partner)
	if speaking:
		return "Idle_Talking"
	return ["Idle_FoldArms", "Yes", "Idle_FoldArms", "Idle_No"][((slot / 2) + id) % 4] if age_group != "child" else "Idle"


static func _cycle(list: Array, id: int, minute: int) -> String:
	return list[posmod(minute / SPELL + id, list.size())]
