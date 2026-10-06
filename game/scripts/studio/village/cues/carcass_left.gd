extends RefCounted
## His kill left lying by the village, him gone off: someone near who would use it comes for it - in sight, before
## the carcass's own timer would make it vanish behind a hint (world/carcass.gd: village_takes_after, 60 s) - and it
## is gone because a body took it (village/reactions/fetch_carcass.gd, answering "carcass").
## A cue source (village_reactions.gd scans each twice a second): scan(reactions) -> [[cue, ids], ...].
const AFTER := 24.0          # seconds alone before someone comes (the crows come at 25; the village's own timer is 60)
const REACH := 40.0          # metres: the nearest grown person this near comes
const VILLAGE := Vector2(0.0, 15.0)    # (world/carcass.gd's own: the village takes only what lies by it)
const VILLAGE_RADIUS := 26.0

var _cued := {}              # carcass instance id -> true


func scan(r) -> Array:
	var out: Array = []
	var v = VillageSession.village
	for n: Node in r.get_tree().get_nodes_in_group("carcass"):
		var c := n as Node3D
		if c == null or bool(c.get("dragged")) or float(c.get("_alone")) < AFTER or _cued.has(c.get_instance_id()):
			continue
		var at := Vector2(c.global_position.x, c.global_position.z)
		if at.distance_to(VILLAGE) >= VILLAGE_RADIUS:
			continue
		for x: Array in r.near(at, REACH):
			var id := int(x[0])
			if r.res._who_of(v, id).age_group != "child":
				_cued[c.get_instance_id()] = true
				out.append([{"kind": "carcass:" + str(c.get("kind")), "node": c, "place": at, "subject": -1, "who": [id],
					"thing": str(c.get("kind"))}, [id]])
				break
	return out
