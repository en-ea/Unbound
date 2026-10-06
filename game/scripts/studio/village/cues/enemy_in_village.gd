extends RefCounted
## A beast among the houses. A wolf, a bandit, or a boar that has turned to fight is an **enemy**: the bold arm and
## come, a parent takes the children in, the rest keep clear or flee indoors ("enemy:<kind>"). A boar only rooting
## about is a **beast**: those near and free step back and watch it ("beast:<kind>"; nobody leaves a conversation for
## it). Only within the village's bounds (the meadow's herders and the woods are the creatures' own).
## A cue source (village_reactions.gd scans each twice a second): scan(reactions) -> [[cue, ids], ...].
const SEES := 16.0           # metres: those this near an enemy see it
const SEES_BEAST := 8.0      # ... and a beast going about its business
const AMONG := 2             # people who see it, at least, for it to be among them (not a wolf passing a lone herder)
const AGAIN_S := 90.0        # seconds before the same creature cues anyone again
const FEARED := ["wolf", "boar", "bandit"]   # Enea's creatures (scripts by name) the village minds (the group "enemy"
                                             # also holds the stag, game, and studio/village/fight_target.gd's villager)
const CALM := 0              # creatures/boar.gd State.WANDER: rooting about
const VILLAGE := Vector2(0.0, 15.0)    # (world/carcass.gd's own bounds of the village)
const VILLAGE_RADIUS := 26.0

var _cued := {}              # creature instance id -> seconds it last cued


func scan(r) -> Array:
	var out: Array = []
	var now: float = r.res._age
	for n: Node in r.get_tree().get_nodes_in_group("enemy"):
		var body := n as Node3D
		if body == null or not body.is_visible_in_tree() or (body.has_method("is_alive") and not body.is_alive()):
			continue
		var kind := (body.get_script() as Script).resource_path.get_file().get_basename() if body.get_script() != null else ""
		if not FEARED.has(kind):
			continue
		var at := Vector2(body.global_position.x, body.global_position.z)
		if at.distance_to(VILLAGE) > VILLAGE_RADIUS:
			continue
		var key := body.get_instance_id()
		if now - float(_cued.get(key, -INF)) < AGAIN_S:
			continue
		var calm := kind == "boar" and int(body.get("state")) == CALM
		var near: Array = r.near(at, SEES_BEAST if calm else SEES, 24, calm)
		if near.size() < (1 if calm else AMONG):
			continue
		_cued[key] = now
		var ids: Array = near.map(func(x: Array) -> int: return int(x[0]))
		if body.is_in_group("boss"):
			kind = "duskmaw"
		out.append([{"kind": ("beast:" if calm else "enemy:") + kind, "node": body, "place": at, "subject": -1, "who": ids}, ids])
	return out
