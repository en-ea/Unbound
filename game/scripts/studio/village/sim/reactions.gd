extends RefCounted
## How a villager answers being struck or shoved, and how someone who saw it answers: small, readable choices from
## who they are (boldness, temper, compassion, age, role), how hurt they are, how often it has happened, who is on
## their side nearby, and what they already thought of the player. No dice beyond a keyed tie-break, so the same
## situation gets the same answer and a tester can see why.
##
##   struck(v, id, context) -> "puzzled" | "startled" | "protest" | "flee" | "call_help" | "fight_back" | "plead" | "down"
##   witness(v, w, target, context) -> "intervene" | "shout" | "flee" | "back_away" | "watch"
##
## context: {hits: blows from the player in the last hour (this one included), allies: [ids of kin or friends who can
## see], k: a keyed number for ties}
const S := preload("res://scripts/studio/village/sim/state.gd")
const Village := preload("res://scripts/studio/village/sim/village.gd")
const C := preload("res://scripts/studio/village/sim/content.gd")
const R := preload("res://scripts/studio/village/sim/rng.gd")
const View := preload("res://scripts/studio/village/sim/view.gd")


static func struck(v: S.Village, id: int, context: Dictionary) -> String:
	var p := v.people[id]
	if p.down_until > int(v.runtime.get("now", 0)):
		return "down"
	var bold := p.traits[C.BOLD]
	var temper := p.traits[C.TEMPER]
	var hits := int(context.get("hits", 1))
	var allies: Array = context.get("allies", [])
	var age := Village.age_of(v, p)
	var feeling: int = View.toward_player(v, id).feeling
	# the first blow from someone they had no quarrel with: surprise before anything else
	if hits <= 1 and feeling > -20:
		if id == v.authority or id == v.priest:
			return "protest"   # the village's authority answers with words first
		if temper >= 60:
			return "protest"
		if bold < 45:
			return "startled"
		return "puzzled"
	# it keeps happening: now it is about safety
	if p.hurt >= 80:
		return "plead" if bold < 70 else "flee"
	if age >= 60:
		return "call_help" if allies.size() > 0 else "plead"
	if bold >= 65 and temper >= 55 and p.hurt < 60:
		return "fight_back"
	if allies.size() > 0 and bold < 65:
		return "call_help"
	if bold < 40 or p.hurt >= 60:
		return "flee"
	return "protest" if R.pick(int(context.get("k", 0)), 2) == 0 else "flee"


static func witness(v: S.Village, w: int, target: int, context: Dictionary) -> String:
	var q := v.people[w]
	var bold := q.traits[C.BOLD]
	var compassion := q.traits[C.COMPASSION]
	var close := Village.is_kin(v, w, target) or Village.opinion(v, w, target) >= 30
	var dislikes := Village.opinion(v, w, target) <= -30
	if Village.age_of(v, q) < 14:
		return "flee"   # children run home
	if close and bold >= 55:
		return "intervene"
	if close or compassion >= 65:
		return "shout"
	if dislikes:
		return "watch"
	if bold < 35:
		return "flee"
	return "back_away" if R.pick(R.key(int(context.get("k", 0)), w), 3) == 0 else "watch"


## How much a witness's feeling for the player changes (who they are to the one struck matters).
static func witness_feeling(v: S.Village, w: int, target: int) -> int:
	if Village.is_kin(v, w, target):
		return -35
	var o := Village.opinion(v, w, target)
	if o >= 30:
		return -25
	if o <= -30:
		return 5
	return -10