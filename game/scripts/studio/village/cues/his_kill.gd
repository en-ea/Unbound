extends RefCounted
## His kill brought among people (a carcass on his shoulders or dragged): those who see it come to look, hail him, or
## look up from their work a moment (village/reactions/ answering "kill"). Once a carcass.
## A cue source (village_reactions.gd scans each twice a second): scan(reactions) -> [[cue, ids], ...].
const SEES := 14.0           # metres: those this near him see it
const AMONG := 2             # people who see it, at least (among the houses, not one woodcutter in the forest)

var _cued := {}              # carcass instance id -> true


func scan(r) -> Array:
	var player: Node3D = r.res._player
	if player == null:
		return []
	var hauling: Variant = player.get("hauling")
	if hauling == null:
		return []
	var carcass: Variant = hauling.get("carrying")
	if carcass == null or not is_instance_valid(carcass) or _cued.has((carcass as Object).get_instance_id()):
		return []
	var at: Vector2 = r.res.player_xz()
	var near: Array = r.near(at, SEES)
	if near.size() < AMONG:
		return []
	_cued[(carcass as Object).get_instance_id()] = true
	var ids: Array = near.map(func(x: Array) -> int: return int(x[0]))
	return [[{"kind": "kill:" + str((carcass as Object).get("kind")), "node": carcass, "place": at, "subject": -1, "who": ids}, ids]]
