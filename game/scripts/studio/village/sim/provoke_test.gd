extends RefCounted
## Provoking a villager (Pass 2, M2 rules side), checked headless: run.gd -- village/sim/provoke_test
##   - a child can never be struck or threatened
##   - a blow is accepted once (the same swing again is a duplicate); it bruises and is remembered
##   - a timid, a middling and a bold villager answer the same first and second blows differently
##   - a witness answers in their own way and remembers; someone tells the elder half an hour later
##   - a gift is a way back: the feeling of the one struck improves
##   - a save and load between the blow and the report continues the same way
const S := preload("res://scripts/studio/village/sim/state.gd")
const Runtime := preload("res://scripts/studio/village/sim/runtime.gd")
const Village := preload("res://scripts/studio/village/sim/village.gd")
const WorldActions := preload("res://scripts/studio/village/sim/world_actions.gd")
const View := preload("res://scripts/studio/village/sim/view.gd")
const Save := preload("res://scripts/studio/village/sim/save.gd")
const C := preload("res://scripts/studio/village/sim/content.gd")

static var _out := PackedStringArray()
static var _fails := 0
static var _press := 0


static func _check(ok: bool, what: String) -> void:
	_out.append(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails += 1


static func _act(v: S.Village, verb: String, target: int, params: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	_press += 1
	var press: String = params.get("press_id", "p%d" % _press)
	var req := {"action_id": "%s:%d:%s" % [verb, target, press], "player_id": "player:local", "village_id": v.runtime.village,
		"logical_time": v.runtime.now, "verb": verb, "target": target, "parameters": params}
	var ctx := {"distance_dm": 10}
	ctx.merge(context, true)
	return WorldActions.act(v, req, ctx)


static func _village() -> S.Village:
	var v := Runtime.create(31)
	Runtime.advance(v, int(v.runtime.now) + 120)
	return v


static func _adults(v: S.Village, n: int) -> Array[int]:
	var out: Array[int] = []
	for p in v.people:
		if p.alive and p.present and not p.locked and Village.age_of(v, p) >= 20 and Village.age_of(v, p) < 55 and p.id != v.authority and p.id != v.priest:
			out.append(p.id)
			if out.size() == n:
				break
	return out


static func report() -> PackedStringArray:
	_out = PackedStringArray()
	_fails = 0
	var v := _village()
	# children
	var child := -1
	for p in v.people:
		if p.alive and p.present and Village.age_of(v, p) < 14:
			child = p.id
			break
	if child >= 0:
		_check(not _act(v, "strike", child).accepted and not _act(v, "square_up", child).accepted, "a child can never be struck or threatened")
	# one blow, once
	var target := _adults(v, 1)[0]
	var first := _act(v, "strike", target, {"press_id": "swing-1", "damage": 1})
	var again := _act(v, "strike", target, {"press_id": "swing-1", "damage": 1})
	_check(first.accepted and again.get("duplicate", false) and v.people[target].hurt == 14, "a blow lands once (the same swing again changes nothing)")
	_check(View.toward_player(v, target).memories.has("hit_by_you") and View.toward_player(v, target).feeling < 0, "the one struck remembers")
	# three temperaments, the same blows
	var v2 := _village()
	var three := _adults(v2, 3)
	var shapes := [[20, 30], [50, 50], [90, 80]]   # [boldness, temper]: timid, middling, bold
	var answers := []
	for i in 3:
		var p := v2.people[three[i]]
		p.traits[C.BOLD] = shapes[i][0]
		p.traits[C.TEMPER] = shapes[i][1]
		var a := str(_act(v2, "strike", p.id, {"damage": 1}).reaction)
		var b := str(_act(v2, "strike", p.id, {"damage": 1}).reaction)
		answers.append("%s then %s" % [a, b])
	_check(answers[0] != answers[1] and answers[1] != answers[2] and answers[0] != answers[2], "timid, middling and bold answer differently: %s" % " / ".join(answers))
	# a witness, and word reaching the elder
	var v3 := _village()
	var pair := _adults(v3, 2)
	var victim := pair[0]
	var onlooker := pair[1]
	v3.people[onlooker].traits[C.COMPASSION] = 80
	var hit := _act(v3, "strike", victim, {"damage": 1}, {"witnesses": [onlooker]})
	var said: String = hit.witnesses.get(onlooker, "")
	_check(said in ["shout", "intervene"] and View.toward_player(v3, onlooker).memories.has("saw_you_hit"), "a caring onlooker speaks up (%s) and remembers" % said)
	var saved: S.Village = Save.from_data(JSON.parse_string(JSON.stringify(Save.to_data(v3))))
	for village: S.Village in [v3, saved]:
		Runtime.advance(village, int(village.runtime.now) + 45)
	var told: bool = View.toward_player(v3, v3.authority).memories.has("told_about_you")
	_check(told, "someone told the elder within the hour")
	var canon := func(x: S.Village) -> String: return JSON.stringify(JSON.parse_string(JSON.stringify(Save.to_data(x))))
	_check(canon.call(v3) == canon.call(saved), "a save and load between the blow and the report continues the same way")
	# a way back
	var before: int = View.toward_player(v3, victim).feeling
	var gift := _act(v3, "give", victim, {"item": "bread", "count": 3}, {"have": 5, "food": true})
	_check(gift.accepted and View.toward_player(v3, victim).feeling > before, "a gift softens the one struck (%d -> %d)" % [before, View.toward_player(v3, victim).feeling])
	# knocked down, then no more blows while down
	var v4 := _village()
	var t4 := _adults(v4, 1)[0]
	var last := {}
	for i in 8:
		last = _act(v4, "strike", t4, {"damage": 5})
		if last.get("down", false):
			break
	_check(last.get("down", false) and not _act(v4, "strike", t4, {"damage": 1}).accepted, "enough blows knock them down; no more blows while they are down")
	_out.append("PROVOKE: %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	return _out