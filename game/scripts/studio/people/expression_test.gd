extends RefCounted
## Smoothness (desk 6 Oct): a body's expression resolves its tuning without the whole profile. The light tuning must be
## exactly what profile(v, actor, {}) resolved, for every villager - hurt, frightened, with a modifier, after an
## unattributed blow - so faces and gaits do not change.
##   godot --headless --path game --script res://scripts/studio/run.gd -- people/expression_test
const F := preload("res://scripts/studio/people/foundation_state_test.gd")
const People := preload("res://scripts/studio/village/sim/people.gd")


static func report() -> PackedStringArray:
	var out := PackedStringArray()
	var v = F.fixture()
	var ids := []
	for p in v.people:
		if p.alive and p.present:
			ids.append(p.id)
	# Variety: one hurt, one with a modifier, one struck by someone unseen, and the village afraid.
	v.people[ids[0]].hurt = 60
	People.mind(v, People.key(v, ids[1])).modifiers = [{"id": "distracted", "until": People.tick(v) + 60000}]
	People.mind(v, People.key(v, ids[2])).stances["unknown"] = {"hits": 2, "wary": 300, "tick": People.tick(v)}
	v.fear = 240
	var same := 0
	var differ := []
	for id: int in ids:
		var key := People.key(v, id)
		var m := People.mind(v, key)
		var full: Dictionary = People.profile(v, key, {}).tuning
		var light: Dictionary = People.expression_tuning(v, key, m)
		if full == light:
			same += 1
		else:
			differ.append(v.people[id].name)
	out.append(("PASS" if differ.is_empty() and same == ids.size() else "FAIL") + " expression the light tuning equals the whole profile's for all %d villagers (differ: %s)" % [ids.size(), ", ".join(PackedStringArray(differ))])
	var expressed: Dictionary = People.expression(v, People.key(v, ids[1]))
	out.append(("PASS" if expressed.has("style") and expressed.has("regard") else "FAIL") + " expression still gives the style and regard (%s)" % str(expressed.get("style", {})))
	return out
