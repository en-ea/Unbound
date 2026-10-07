extends RefCounted
## The Tidecaller's water on villagers (studio: water class). Every effect on a person is a checked act through the
## one door: Contact.perform -> people_bridge -> acceptance (people_actions wet / hold / freeze / extinguish rain /
## strike). Area acts (wet, hold, freeze, rain) carry the measured origin and reach; the bodies and their looks are the
## doused, suspended and frozen elements. Nothing here writes a fact or keeps a private "wet".
##
## Two acts depend on other owners' lines, and are tried only once the door can take them:
## - wet needs measured water contact: Water.contact for the "tide:<press_id>" affordance (Body 4). Until Water.contact
##   answers a tide at the caster's own feet, wet is not sent (no refused batch, no cost).
## - lightning on a person beyond a hand's reach needs strike {source: lightning} as an area act (Foundations); until
##   people_actions.area() says so, a bolt only falls on someone within reach of the caster.
const Contact := preload("res://scripts/studio/village/contact.gd")
const Actions := preload("res://scripts/studio/village/sim/people_actions.gd")
const People := preload("res://scripts/studio/village/sim/people.gd")
const Water := preload("res://scripts/studio/village/water.gd")
const HAND := 2.8                # metres: a hand's reach, the door's limit for acts that are not area acts

static var last_wet := {}        # the door's last answer to a wet (the probe reads it)


static func ready(tree: SceneTree) -> bool:
	return Contact.registry(tree) != null and VillageSession.village != null and VillageSession.active and not VillageSession.background


## People whose bodies the area reaches from `origin` (walls block), nearest first: [{id, actor, at, origin}].
## `only_eligible`: just those the door may act on (adults, not Enea's named people, not down or held).
static func reached(tree: SceneTree, source: Node3D, origin: Vector3, reach: float, forward := Vector3.ZERO, aperture := 0.35,
		only_eligible := false) -> Array:
	if not ready(tree):
		return []
	var rows := Contact.measure(tree, source, origin, minf(reach, 12.0), forward, -1, Vector3.INF, aperture)
	if only_eligible:
		var live: Node = tree.current_scene.get_node_or_null("VillageLive")
		rows = rows.filter(func(r: Dictionary) -> bool: return live != null and Contact.eligible(live, VillageSession.village, int(r.id)))
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a.at as Vector3).distance_squared_to(origin) < (b.at as Vector3).distance_squared_to(origin))
	return rows


static func person(id: int):
	var v = VillageSession.village
	return v.people[id] if v != null and id >= 0 and id < v.people.size() else null


static func is_wet(id: int) -> bool:
	var p = person(id)
	return p != null and Actions.live(VillageSession.village, p, "doused")


static func is_burning(id: int) -> bool:
	var p = person(id)
	return p != null and p.body_facts.has("burning")


static func act(tree: SceneTree, caster: Node3D, verb: String, fields: Dictionary, origin: Vector3, reach: float, target := -1) -> Dictionary:
	if not ready(tree):
		return {"accepted": false, "reason": "no village"}
	# (an area act reaches everyone measured; the door accepts it for those it may act on and passes over the rest)
	return Contact.perform(tree, Contact.actor_of(caster), caster, verb, fields, origin, minf(reach, 12.0), Vector3.ZERO, target)


## Drown on a person: held in the water (suspended), slammed down when it ends; with Drowned, held the whole time,
## they drown (the rules' one death, "drowned"). The sphere and the lift are the suspended element.
static func hold(tree: SceneTree, caster: Node3D, id: int, at: Vector3, seconds: float, drown: bool, press: String) -> Dictionary:
	return act(tree, caster, "hold", {"press_id": press, "until_ms": roundi(seconds * 1000.0), "drown": drown, "harm": 6, "force": 700},
		at, 1.6, id)


## Soak those the water reaches (the slam's spray, the rain, the puddle). Tide water needs Body 4's contact line.
## Does the door measure the Tidecaller's water as contact yet (Body 4's Water.contact line for "tide:")?
static func wet_open(tree: SceneTree, caster: Node3D) -> bool:
	var res := Contact.registry(tree)
	if res == null:
		return false
	var here := Vector2(caster.global_position.x, caster.global_position.z)
	return Water.contact(res, here, here, "tide:check")


static func wet(tree: SceneTree, caster: Node3D, origin: Vector3, reach: float, method: String, press: String) -> Dictionary:
	if not wet_open(tree, caster):
		last_wet = {"accepted": false, "reason": "waits on Water.contact for tide (Body 4)"}
		return last_wet
	var live: Node = tree.current_scene.get_node_or_null("VillageLive") if ready(tree) else null
	var dry := reached(tree, caster, origin, reach).filter(func(r: Dictionary) -> bool:
		return not is_wet(int(r.id)) and live != null and Contact.eligible(live, VillageSession.village, int(r.id)))
	if dry.is_empty():
		return {}
	var r := act(tree, caster, "wet", {"press_id": press, "method": method, "affordance": "tide:" + press, "until_ms": wet_ms()}, origin, reach)
	last_wet = r
	return r


static func wet_ms() -> int:
	return 20000 if Classes.has_talent("still_water") else 15000


## The rain puts out the burning under the cloud (no water contact needed: the cloud is the contact).
static func rain(tree: SceneTree, caster: Node3D, origin: Vector3, reach: float, press: String) -> Dictionary:
	var burning := reached(tree, caster, origin, reach).filter(func(r: Dictionary) -> bool: return is_burning(int(r.id)))
	if burning.is_empty():
		return {}
	return act(tree, caster, "extinguish", {"press_id": press, "method": "rain"}, origin, reach)


## A bolt on a person: the existing strike (damage 5, force 900). Beyond a hand's reach only once the door takes
## lightning as an area act.
static func can_bolt(caster: Node3D, at: Vector3) -> bool:
	return Actions.area("strike", {"source": "lightning"}) or caster.global_position.distance_to(at) <= HAND


## Fighting you: squared up through the village's own fight (provoke.gd), the one hostile-to-you reading there is.
static func fighting_you(tree: SceneTree, id: int) -> bool:
	var live: Node = tree.current_scene.get_node_or_null("VillageLive") if tree.current_scene != null else null
	var provoke: Node = live.get_node_or_null("Provoke") if live != null else null
	return provoke != null and provoke.is_squared_up(id)


static func bolt(tree: SceneTree, caster: Node3D, id: int, at: Vector3, press: String) -> Dictionary:
	return act(tree, caster, "strike", {"press_id": press, "source": "lightning", "damage": 5, "force": 900}, at, 1.5, id)


## Rime Wave on people: the wet freeze (frozen), the dry are only chilled (a cue, no fact).
static func freeze(tree: SceneTree, caster: Node3D, id: int, seconds: float, press: String) -> Dictionary:
	return act(tree, caster, "freeze", {"press_id": press, "until_ms": roundi(seconds * 1000.0)}, caster.global_position, 9.5, id)
