extends Node
## merge-enea M1: a save written by Enea's own build (8b5fbef) loads on the merged line, nothing lost.
##   --studio=village/live --merge-check=enea_save_check --save-guard --enea-save=<his save.json> --test-save=<fresh name>
## The runner copies his file to the test save first; this compares what the game loaded with his file, section by
## section (his six saved kinds and his belongings, numbers as JSON gives them), then saves through the studio path
## (a full save that starts the journal chain, the village added) and reads the file back: every section of his is
## still there, unchanged, and the village is valid. With --port-residents=on (Mind's port) one more check: his seven
## joined from his saved liking and lettings. Prints PASS/FAIL lines and "ENEA SAVE complete failures=N".
const Codec := preload("res://scripts/studio/village/sim/save.gd")
const Ported := preload("res://scripts/studio/village/sim/ported.gd")
const PortStance := preload("res://scripts/studio/people/port_stance.gd")
const SECTIONS := ["bounties", "residents", "lettings", "waystones", "companions", "fishing", "inventory", "gear", "armor",
	"skills", "coins", "projects", "home", "quests", "classes", "hunting"]
var failed := 0


static func on_device(tree: SceneTree) -> void:
	if tree.root.has_node("EneaSaveCheck"): # a region change reloads the scene and calls this again
		return
	if DisplayServer.get_name() == "headless":
		tree.root.get_node("ItemIcons").set_process(false)
	var probe: Node = load("res://scripts/studio/merge/enea_save_check.gd").new()
	probe.name = "EneaSaveCheck"
	tree.root.add_child.call_deferred(probe)


func _ready() -> void:
	run.call_deferred()


func check(ok: bool, text: String) -> void:
	print(("PASS enea-save " if ok else "FAIL enea-save ") + text)
	if not ok:
		failed += 1


func frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


## What the game holds now for one section, as his save would write it.
func live(section: String) -> Variant:
	match section:
		"bounties": return Bounties.to_data()
		"residents": return Residents.to_data()
		"lettings": return Lettings.to_data()
		"waystones": return Waystones.to_data()
		"companions": return Companions.to_data()
		"fishing": return FishData.to_data()
		"inventory": return Inventory.to_data()
		"gear": return Gear.to_data()
		"armor": return Armor.to_data()
		"skills": return Skills.to_data()
		"coins": return Money.coins
		"projects": return Projects.to_data()
		"home": return Home.to_data()
		"quests": return Quests.to_data()
		"classes": return Classes.to_data()
		"hunting": return Hunting.to_data()
	return null


## JSON's view of a value (what the disk holds): numbers as floats, keys as text. His clocks run from the moment
## the game is up (a board's day, a house's rent day), so "day_secs" is left out of the comparison.
static func norm(v: Variant) -> String:
	return JSON.stringify(_strip(JSON.parse_string(JSON.stringify(v))), "", true)


static func _strip(v: Variant) -> Variant:
	if v is Dictionary:
		var out := {}
		for k: Variant in v:
			if k != "day_secs":
				out[k] = _strip(v[k])
		return out
	if v is Array:
		return (v as Array).map(func(x: Variant) -> Variant: return _strip(x))
	return v


## Residents make goods while they work: what he had is still there, and only more has been made since.
static func goods_kept(his: Dictionary, now: Dictionary) -> bool:
	var a: Dictionary = JSON.parse_string(JSON.stringify(his))
	var b: Dictionary = JSON.parse_string(JSON.stringify(now))
	for k: String in a:
		if k != "goods" and JSON.stringify(a[k], "", true) != JSON.stringify(b.get(k), "", true):
			return false
	for who: String in a.get("goods", {}):
		for item: String in a.goods[who]:
			if float(b.get("goods", {}).get(who, {}).get(item, -1)) < float(a.goods[who][item]):
				return false
	return true


func run() -> void:
	var source := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--enea-save="):
			source = arg.trim_prefix("--enea-save=")
	var his: Variant = JSON.parse_string(FileAccess.get_file_as_string(source)) if FileAccess.file_exists(source) else null
	check(his is Dictionary and not (his as Dictionary).has("village"), "his save is read (%d sections, no village of ours)" % (his.size() if his is Dictionary else 0))
	if not his is Dictionary:
		_done()
		return
	await frames(120)
	for _i in 900:
		if VillageSession.village != null and get_tree().get_first_node_in_group("player") != null:
			break
		await get_tree().process_frame
	check(VillageSession.village != null and VillageSession.recovery_notice.is_empty(), "the game is up on his save with a village of ours and no recovery")
	var differ := []
	for s: String in SECTIONS:
		if his.has(s) and norm(live(s)) != norm(his[s]) and not (s == "residents" and goods_kept(his[s], live(s))):
			differ.append(s)
	for s: String in differ:
		print("DIFF %s\n  his:  %s\n  live: %s" % [s, norm(his[s]).substr(0, 400), norm(live(s)).substr(0, 400)])
	print("SESSION active=%s village=%s living=%s region=%s" % [str(VillageSession.active), str(VillageSession.village != null), str(Settings.living_village), Region.current])
	check(differ.is_empty(), "every section of his loaded unchanged: his six kinds and his belongings (differ: %s)" % str(differ))
	check(Companions.level("cinder") >= 1 and Bounties.taken.size() == 1 and Waystones.is_found("meadow") and not Lettings.owned.is_empty(),
		"his state is live: Cinder with you, a bounty taken, the meadow waystone woken, a house let")
	if Ported.enabled():                         # with Mind's port on: his seven join from his saved liking and lettings
		var v = VillageSession.village
		var joined: bool = Ported.PEOPLE.keys().all(func(id: String) -> bool: return Ported.person_of(v, id) >= 0)
		var liking_same: bool = (his.residents.get("liking", {}) as Dictionary).keys().all(
			func(id: String) -> bool: return PortStance.liking(v, id) == int(his.residents.liking[id]))
		# Enea's merge-fix (Hilmi agreed): with the port on his three tenants have left (gated absent), and the village
		# family living in a house he let is its tenants (PortStance.family).
		var gone: bool = PortStance.TENANTS.keys().all(func(id: String) -> bool: return not PortStance.person(v, id).present)
		var owned: Dictionary = his.lettings.get("owned", {})
		var families := owned.keys().map(func(k: Variant) -> int: return PortStance.family(v, int(k)).size())
		check(joined and liking_same and gone and families.all(func(n: int) -> bool: return n > 0),
			"with the port on, his seven join: liking as he saved it; his tenants have left, and each let house's tenants are its village family (sizes %s)" % str(families))
	var error: int = SaveGame.save_game()
	await frames(5)
	var path: String = SaveGame.get("_path")
	var mine: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var replayed: Variant = preload("res://scripts/studio/village/journal.gd").replay(mine, path + ".journal") if mine is Dictionary else null
	var kept := []
	for s: String in SECTIONS:
		if his.has(s) and replayed is Dictionary and norm(replayed.get(s)) != norm(his[s]) and not (s == "residents" and goods_kept(his[s], replayed.get(s))):
			kept.append(s)
	check(error == OK and replayed is Dictionary and kept.is_empty(), "saved through the studio path and read back: his sections unchanged (differ: %s)" % str(kept))
	var village: Variant = replayed.get("village") if replayed is Dictionary else null
	check(village is Dictionary and Codec.valid(village), "the save now holds a valid village")
	_done()


func _done() -> void:
	print("ENEA SAVE complete failures=%d" % failed)
	get_tree().quit(0 if failed == 0 else 1)
