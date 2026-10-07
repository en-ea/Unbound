extends RefCounted
## C4 affordance: resolve(registry,from,id)->{key,at,focus,reach,kind}; empty means unavailable.
## Layout place + free stand point + complete clear route. Concrete water:<place> keys survive plans.
## contact() rechecks real actor/subject arrival. Another water kind is one data row in KINDS.
const KINDS := ["well","trough","water"]
static func _water(name: String) -> bool:
	return KINDS.has(name) or name.begins_with("well_") or name.begins_with("trough_")
static func _candidate(registry: Node,name: String,from: Vector2,id: int) -> Dictionary:
	if not _water(name) or from==Vector2.INF:
		return {}
	var focus: Vector2=registry.focus(name)
	if focus==Vector2.INF:
		return {}
	var stand: Vector2=registry._spot_by(focus,1.7,from,id)
	if stand==Vector2.INF:
		return {}
	var route: PackedVector2Array=registry._world.route.call(from,stand)
	if route.is_empty() or route[route.size()-1].distance_to(stand)>0.45:
		return {}
	var prior := from
	var length := 0.0
	var passable: Callable=registry._world.get("passable",registry._world.standable) # his villagers on the way are stepped round
	for point: Vector2 in route:
		var leg := prior.distance_to(point)
		var samples := maxi(1,ceili(leg/0.35))
		for sample: int in range(1,samples+1):
			if not passable.call(prior.lerp(point,float(sample)/samples)):
				return {}
		length+=leg
		prior=point
	return {"key":"water:"+name,"kind":"water","at":[stand.x,stand.y],"focus":[focus.x,focus.y],"reach":2.4,"distance":length}
static func resolve(registry: Node,from: Vector2,id := -1) -> Dictionary:
	var best := {}
	var v=VillageSession.village
	if v==null:
		return best
	for place: String in v.place_names:
		var row := _candidate(registry,place,from,id)
		if not row.is_empty() and (best.is_empty() or float(row.distance)<float(best.distance) or (row.distance==best.distance and row.key<best.key)):
			best=row
	return best
static func point(registry: Node,key: String,from: Vector2,id := -1) -> Vector2:
	var row := _candidate(registry,key.trim_prefix("water:"),from,id)
	return Vector2(float(row.at[0]),float(row.at[1])) if not row.is_empty() else Vector2.INF
## A caster's own water (the Tidecaller's: affordance "tide:<press_id>") reaches what Contact measured for that press,
## up to Contact's 12 m bound (TIDE_REACH); it needs no place. Then wet goes the well's route: one checked contact.
const TIDE_REACH := 12.0
static func contact(registry: Node,actor: Vector2,subject: Vector2,key: String) -> bool:
	if key.begins_with("tide:") and key.length()>5 and actor!=Vector2.INF and subject!=Vector2.INF:
		return actor.distance_to(subject)<=TIDE_REACH
	if not key.begins_with("water:") or actor==Vector2.INF or subject==Vector2.INF:
		return false
	var place := key.trim_prefix("water:")
	if not _water(place) or not VillageSession.village.place_ids.has(place):
		return false
	var focus: Vector2=registry.focus(place)
	return focus!=Vector2.INF and actor.distance_to(focus)<=2.4 and subject.distance_to(focus)<=2.4 and actor.distance_to(subject)<=1.2
