extends Node
## A quarrel the society starts (residents.gd _instead -> WorldActions "argue") is one checked batch: the runtime, the
## chronicle and both people are written through acceptance, never straight onto the live village (merge-enea 6 Oct:
## the 105739e port-probe guard line "field runtime [receipts, happenings, argued, stances], field events, ...").
##   --studio=village/live --merge-check=argue_check --save-guard --test-save=<fresh name>
## Prints PASS/FAIL lines and "ARGUE complete failures=N".
const Contact := preload("res://scripts/studio/village/contact.gd")
const VillageImage := preload("res://scripts/studio/village/sim/image.gd")
const Rules := preload("res://scripts/studio/village/sim/village.gd")
var failed := 0


static func on_device(tree: SceneTree) -> void:
	if tree.root.has_node("ArgueCheck"):
		return
	if DisplayServer.get_name() == "headless":
		tree.root.get_node("ItemIcons").set_process(false)
	var probe: Node = load("res://scripts/studio/merge/argue_check.gd").new()
	probe.name = "ArgueCheck"
	tree.root.add_child.call_deferred(probe)


func _ready() -> void:
	run.call_deferred()


func check(ok: bool, text: String) -> void:
	print(("PASS argue " if ok else "FAIL argue ") + text)
	if not ok:
		failed += 1


func frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


## The guard's compare, less the live clock (fraction, news: they move every frame and the next line writes them).
func drift(v) -> Array:
	return VillageImage.verify(v).filter(func(x: Variant) -> bool:
		var t := str(x)
		if not t.begins_with("field runtime "):
			return true
		var keys: Variant = JSON.parse_string(t.trim_prefix("field runtime "))
		return not (keys is Array and (keys as Array).all(func(k: Variant) -> bool: return str(k) in ["fraction", "news", "now", "player"])))


func run() -> void:
	await frames(120)
	var res: Node = null
	for _i in 900:
		res = Contact.registry(get_tree())
		if res != null and VillageSession.village != null and res.call("all_built"):
			break
		await get_tree().process_frame
	var v = VillageSession.village
	var pair := []
	for id: int in res.bodies:
		var p = v.people[id]
		if p.alive and p.present and p.authored == "" and Rules.age_of(v, p) >= 16:
			pair.append(id)
			if pair.size() == 2:
				break
	check(pair.size() == 2, "two grown villagers with bodies (%s)" % str(pair))
	if pair.size() < 2:
		_done()
		return
	# They dislike each other (a fixture: written through acceptance, so the guard stays exact).
	res.people_bridge.accept(func(candidate) -> Dictionary:
		VillageImage.touch_person(-1)
		Rules.set_opinion(candidate, pair[0], pair[1], -80)
		Rules.set_opinion(candidate, pair[1], pair[0], -80)
		return {"accepted": true})
	await frames(5)
	var before: int = v.runtime.get("happenings", []).size()
	var answer: String = res.call("_instead", "quarrel", pair[0], pair[1], 0)
	await frames(5)
	var left := drift(v)
	check(answer == "" and v.runtime.get("happenings", []).size() == before + 1 and left.is_empty(),
		"the society's quarrel is one checked batch: an argument, the guard silent (answer '%s', happenings %d -> %d, %s)" % [answer, before, v.runtime.get("happenings", []).size(), str(left)])
	var count: int = v.runtime.get("happenings", []).size()
	res.call("_instead", "quarrel", pair[0], pair[1], 0)
	await frames(5)
	check(v.runtime.get("happenings", []).size() == count and drift(v).is_empty(), "asked again: no second argument (a replay or not twice a day), nothing written")
	_done()


func _done() -> void:
	print("ARGUE complete failures=%d" % failed)
	get_tree().quit(0 if failed == 0 else 1)
