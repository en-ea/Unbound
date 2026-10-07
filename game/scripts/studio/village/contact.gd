extends RefCounted
## B6/P1 measured actor-independent contact. P4 is broad phase; actual bodies, sweep and wall rays decide delivery.
## perform(tree,actor,source,verb,fields,origin,reach,forward,target=-1,end=INF)->checked receipt.
## target>=0 captures ONE target, -1 area, -2 explicit empty intent. Force 0..1000 is separate from harm.
## Legacy land/area remain Enea adapters. Pair IDs survive refused saves; no crowd separation creates an act.
const People := preload("res://scripts/studio/village/sim/people.gd")
const Rules := preload("res://scripts/studio/village/sim/village.gd")
const FactActions := preload("res://scripts/studio/village/sim/people_actions.gd")
const Modules := preload("res://scripts/studio/people/modules.gd")
const ThingActions := preload("res://scripts/studio/village/sim/thing_actions.gd")
const Things := preload("res://scripts/studio/village/things.gd")
const ThingFacts := preload("res://scripts/studio/village/sim/thing_facts.gd")
const Water := preload("res://scripts/studio/village/water.gd")
static var thing_usec := 0 # world-things time per frame, measured (rule 7)
static var thing_calls := 0
static var thing_roots := {} # world-things: accepted acts on things by action id (a press twice is one act; session only)
static var sweeps := {} # Cast->accepted target IDs, no repeated root or save for the same passed body.
static var _push_shoved := {} # actor -> {target: true}: those one held push has shoved (once a person; cleared as it ends)
static var pending := {} # Failed input delivery only; shared checked authority still owns facts/accounts.
var pairs := {}
var touches := {}
var _serial := 0
func _init(folder := "res://scripts/studio/people/contacts/") -> void:
	var discovered := Modules.discover(folder)
	for id: String in discovered:
		touches[id]=discovered[id].new()
static func registry(tree: SceneTree) -> Node:
	var scene := tree.current_scene
	var live := scene.get_node_or_null("VillageLive") if scene!=null else null
	return live.registry if live!=null else null
## Persistent generic actors opt in with owner-supplied people_actor; body:<instance> is session-only.
static func actor_of(node: Node3D) -> String:
	return str(node.get_meta("people_actor","player:local" if node.is_in_group("player") else "body:%d" % node.get_instance_id()))
static func capable(res: Node,v,id: int) -> bool:
	return id>=0 and id<v.people.size() and v.people[id].present and res.bodies.has(id) and is_instance_valid(res.bodies[id]) and not res._movers[id].indoors
## Compatibility eligibility; never used to decide whether a body can physically flinch or burn.
static func eligible(live: Node,v,id: int) -> bool:
	return capable(live.registry,v,id) and v.people[id].alive and not v.people[id].locked and v.people[id].authored=="" and not FactActions.down(v,v.people[id]) and Rules.age_of(v,v.people[id])>=14
static func closest(at: Vector2,start: Vector2,end: Vector2) -> Vector2:
	var travel := end-start
	var t := clampf((at-start).dot(travel)/travel.length_squared(),0,1) if travel.length_squared()>0.000001 else 0.0
	return start+travel*t
static func clear(source: Node3D,origin: Vector3,at: Vector3) -> bool:
	if origin.distance_squared_to(at)<0.000001:
		return true
	var ray := PhysicsRayQueryParameters3D.create(origin+Vector3(0,0.8,0),at+Vector3(0,0.8,0),1)
	if source is CollisionObject3D:
		ray.exclude=[source.get_rid()]
	return source.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
static func measure(tree: SceneTree,source: Node3D,origin: Vector3,reach: float,forward: Vector3,target := -1,end := Vector3.INF,aperture := 0.35) -> Array:
	var res := registry(tree)
	var v=VillageSession.village
	if res==null or v==null or not VillageSession.active or VillageSession.background or Controls.locked or not is_instance_valid(source) or target==-2 or not is_finite(reach) or reach<=0 or reach>12:
		return []
	var start2 := Vector2(origin.x,origin.z)
	var end2 := start2 if end==Vector3.INF else Vector2(end.x,end.z)
	if start2.distance_to(end2)>20:
		return []
	var out := []
	var seen := {}
	for row: Dictionary in res._crowd.nearby.query((start2+end2)*0.5,reach+start2.distance_to(end2)*0.5+1.0):
		var id := People.resident(v,str(row.key))
		if seen.has(id) or not capable(res,v,id) or (target>=0 and target!=id):
			continue
		var body: Node3D=res.bodies[id]
		var at := body.global_position
		var point := closest(Vector2(at.x,at.z),start2,end2)
		var to := Vector2(at.x,at.z)-point
		if to.length()>reach:
			continue
		if end==Vector3.INF and forward.length_squared()>0.001 and to.length()>0.65 and to.normalized().dot(Vector2(forward.x,forward.z).normalized())<aperture:
			continue
		var contact_origin := Vector3(point.x,origin.y,point.y)
		if clear(source,contact_origin,at):
			seen[id]=true
			out.append({"id":id,"actor":str(row.key),"at":at,"origin":contact_origin})
	return out
static func candidates(tree: SceneTree,source: Node3D,reach: float,forward: Vector3,aperture := -0.1) -> Array:
	return measure(tree,source,source.global_position,reach,forward,-1,Vector3.INF,aperture)
static func perform(tree: SceneTree,actor: String,source: Node3D,verb: String,fields: Dictionary,origin: Vector3,reach: float,forward := Vector3.ZERO,target := -1,end := Vector3.INF,permissions := {},omit: Dictionary = {}) -> Dictionary:
	var res := registry(tree)
	if res==null:
		return {"accepted":false,"reason":"no village"}
	res.people_bridge.register_actor(actor,source)
	var targets := measure(tree,source,origin,reach,forward,target,end).filter(func(row: Dictionary) -> bool: return not omit.has(int(row.id)))
	var bound := reach if end==Vector3.INF else minf(12.0,reach+origin.distance_to(end))
	var geometry := {"actor":actor,"origin":Vector2(origin.x,origin.z),"reach":bound}
	geometry.merge(permissions,true)
	var ids := targets.map(func(row: Dictionary) -> int: return int(row.id))
	ids.sort()
	var key := JSON.stringify([actor,str(fields.get("press_id","")),verb,ids])
	if pending.has(key):
		return {"accepted":false,"reason":"delivery pending"}
	var result: Dictionary=res.people_bridge.perform(actor,targets,verb,fields,geometry)
	if result.get("reason","")=="save failed" and not pending.has(key):
		pending[key]={"bridge":res.people_bridge,"village_id":str(VillageSession.village.runtime.village),"actor":actor,"targets":targets.duplicate(true),
			"verb":verb,"fields":fields.duplicate(true),"geometry":geometry.duplicate(true),"retry_tick":People.tick(VillageSession.village)+250}
	elif result.get("accepted",false):
		pending.erase(key)
	# world-things: fire reaches things as well as people; a blow or shove reaches a thing when no one is in its way.
	if ThingActions.handles(verb) and (verb in ["burn","extinguish"] or targets.is_empty()) and target==-1:
		var thing_result := things(tree,actor,source,verb,fields,origin,reach,forward,end)
		if not thing_result.is_empty() and not result.get("accepted",false):
			return thing_result
		if not thing_result.is_empty():
			result.things=thing_result
	if result.get("reason","")=="ineligible contact" and verb in ["strike","shove"]:
		for row: Dictionary in targets:
			res.play_contact(int(row.id),{"force":int(fields.get("force",450)),"from":[origin.x,origin.z]}) # Physical cue only; no accepted injury/announcement.
	return result
## world-things: an act on the things in reach, through the people's own checked door (bridge.accept: one
## transaction, one save). Facts live in the village's thing_facts; with no such home, nothing is accepted.
static func things(tree: SceneTree,actor: String,source: Node3D,verb: String,fields: Dictionary,origin: Vector3,reach: float,forward := Vector3.ZERO,end := Vector3.INF) -> Dictionary:
	var res := registry(tree)
	var v=VillageSession.village
	if res==null or v==null or v.get("thing_facts")==null or not VillageSession.active or VillageSession.background or Controls.locked:
		return {}
	var rows := Things.measure(tree,origin,reach,forward,end)
	if rows.is_empty():
		return {}
	var press := str(fields.get("press_id","%d:%d" % [People.tick(v),int(v.runtime.sequence)]))
	var carriers := Things.ids(tree)
	var me := Vector2(source.global_position.x,source.global_position.z) if is_instance_valid(source) else Vector2.INF
	var requests := []
	for row: Dictionary in rows:
		var at: Vector3=row.at
		var context := {"distance_dm":int(row.distance_dm),"reach_dm":reach*10.0}
		if verb=="extinguish":
			context.water_contact=Water.contact(res,me,Vector2(at.x,at.z),str(fields.get("affordance","")))
		requests.append({"request":{"action_id":"thing:"+JSON.stringify([actor,press,verb,row.thing]).sha256_text().substr(0,32),
			"actor":actor,"target":row.thing,"verb":verb,"parameters":fields.duplicate(true)},"context":context})
	return res.people_bridge.accept(func(candidate)->Dictionary:
		ThingActions.follow(candidate,ThingFacts.advance(candidate),carriers)
		var accepted := []
		for r: Dictionary in requests:
			var answer := ThingActions.prepare(candidate,thing_roots,r.request,r.context)
			if answer.get("accepted",false):
				accepted.append(answer)
		if accepted.is_empty():
			return {"accepted":false,"reason":"no thing answered"}
		var out: Dictionary=accepted[0].duplicate(true)
		out.merge({"things":accepted,"duplicate":accepted.all(func(a: Dictionary)->bool:return a.get("duplicate",false))},true)
		return out)
## world-things time: char, spread (from burning things and burning people), burn-out, drying, through the same
## checked door, and only when something is due: with nothing burning, wet or struck it costs a comparison.
static func thing_time(tree: SceneTree) -> Dictionary:
	var v=VillageSession.village
	if v==null or v.get("thing_facts")==null or not VillageSession.active or VillageSession.background or Controls.locked:
		return {}
	var due := ThingFacts.next_due(v)<=People.tick(v)
	if not due and Engine.get_process_frames()%10!=0: # a burning person against a thing is looked for 3-6 times a second
		return {}
	var fires := _burning_people(v)
	if not due and fires.is_empty():
		return {}
	var res := registry(tree)
	if res==null:
		return {}
	var carriers := Things.ids(tree)
	if not due and not ThingActions.reaches(v,fires,carriers):
		return {}
	return res.people_bridge.accept(func(candidate)->Dictionary:
		var ended := ThingFacts.advance(candidate)
		var changes := ThingActions.follow(candidate,ended,carriers)
		changes.append_array(ThingActions.exposed(candidate,_burning_people(candidate),carriers))
		return {"accepted":not ended.is_empty() or not changes.is_empty(),"reason":"nothing due","ended":ended.size(),"changes":changes})
static func _burning_people(v) -> Array:
	var out := []
	for p in v.people:
		if p.alive and p.present and p.body_facts.has("burning") and p.body_facts.has("location"):
			out.append({"at":p.body_facts.location.at,"deed":str(p.body_facts.burning.deed),"heat":int(p.body_facts.burning.get("heat",600))})
	return out
static func retry() -> void:
	if not Controls.locked and Engine.get_main_loop() is SceneTree:
		var began := Time.get_ticks_usec()
		thing_time(Engine.get_main_loop() as SceneTree)
		thing_usec+=Time.get_ticks_usec()-began
		thing_calls+=1
	if Controls.locked or VillageSession.background or SaveGame.paused or VillageSession.village==null or not VillageSession.active:
		return
	var budget := 2
	for key: String in pending.keys():
		var row: Dictionary=pending[key]
		if str(row.village_id)!=str(VillageSession.village.runtime.village) or not is_instance_valid(row.bridge) or not row.bridge.is_inside_tree() or row.bridge.is_queued_for_deletion():
			pending.erase(key)
			continue
		if budget<=0 or People.tick(VillageSession.village)<int(row.retry_tick):
			continue
		budget-=1
		var answer: Dictionary=row.bridge.perform(row.actor,row.targets,row.verb,row.fields,row.geometry)
		if answer.get("reason","")=="save failed" or answer.get("reason","")=="unavailable":
			row.retry_tick=People.tick(VillageSession.village)+250
		else:
			if answer.get("accepted",false):
				_mark_sweep(str(row.actor),str(row.fields.get("press_id","")),answer,str(row.verb))
			pending.erase(key)
static func land(tree: SceneTree,source: Node3D,damage: int,force: float,key: String,reach: float,forward: Vector3) -> int:
	var strength := 850 if force>1 else roundi(clampf(force,0,1)*1000)
	var result := perform(tree,actor_of(source),source,"strike",{"damage":damage,"force":strength,"press_id":key},source.global_position,reach,forward)
	return result.get("contacts",[]).size() if result.get("accepted",false) and not result.get("duplicate",false) else 0
static func area(tree: SceneTree,source: Node3D,origin: Vector3,reach: float,key: String,force := 900) -> Dictionary:
	return perform(tree,actor_of(source),source,"burn",{"press_id":key,"heat":750,"force":clampi(force,0,1000)},origin,reach)
static func sweep(tree: SceneTree,actor: String,source: Node3D,start: Vector3,end: Vector3,radius: float,key: String,verb := "burn",fields := {}) -> Dictionary:
	var parameters := fields.duplicate(true)
	parameters.press_id=key
	var group: Dictionary=sweeps.get_or_add(JSON.stringify([actor,key,verb]),{"ids":{}})
	var result := perform(tree,actor,source,verb,parameters,start,radius,Vector3.ZERO,-1,end,{},group.ids)
	if result.get("accepted",false):
		_mark_sweep(actor,key,result,verb)
	return result
static func _mark_sweep(actor: String,key: String,result: Dictionary,verb := "burn") -> void:
	var group: Dictionary=sweeps.get(JSON.stringify([actor,key,verb]),{})
	if group.is_empty():
		return
	for receipt: Dictionary in result.get("contacts",[]):
		group.ids[int(receipt.target)]=true
static func end_sweep(actor: String,key: String,verb := "burn") -> void:
	sweeps.erase(JSON.stringify([actor,key,verb]))

## Where someone walked into stumbles: back and aside, off the line he moves along. Straight back along it they stay in
## his way and are pushed ahead of him step after step (the crowd push held up short); aside, he gets through. On the
## line itself the side is theirs (by id), the same each time.
static func _aside(away: Vector2,motion: Vector2,id: int) -> Vector2:
	var along := motion.normalized() if motion.length()>0.1 else away.normalized()
	if along.length_squared()<0.0001:
		return away
	var lateral := away-along*away.dot(along)
	if lateral.length()<0.05:
		lateral=Vector2(-along.y,along.x)*(1.0 if id%2==0 else -1.0)
	return along*0.35+lateral.normalized()*0.94
## How far that stumble goes: its own distance, and at least far enough aside to clear his body (CLEAR_LANE m off the
## line he moves along), so a crowd pushed through parts instead of being pushed ahead of him.
const CLEAR_LANE := 0.8
static func _clearing(away: Vector2,motion: Vector2,stumble: float) -> float:
	var along := motion.normalized() if motion.length()>0.1 else away.normalized()
	var off := absf(away.x*along.y-away.y*along.x) if along.length_squared()>0.0001 else 0.0
	return clampf(maxf(stumble,(CLEAR_LANE-off)/0.94),0.0,0.9)
## Active pair episode. Near hysteresis is producer supplied; no cooldown-generated assault.
func pair(actor: String,target: String,near: bool,dt: float,how := "") -> Dictionary:
	var key := JSON.stringify([actor,how,target])
	if not near:
		pairs.erase(key)
		return {}
	if not pairs.has(key):
		_serial+=1
		pairs[key]={"actor":actor,"how":how,"press_id":"touch:%s:%d:%d" % [actor,Time.get_ticks_usec(),_serial],"age":0.0,"shown":false,"delivered":false}
	var row: Dictionary=pairs[key]
	row.age+=maxf(0,dt)
	return row
## Measured walking/load producer. Closing speed comes from actual player/load travel, not separation.
func walking(tree: SceneTree,actor: String,source: Node3D,before: Vector3,after: Vector3,dt: float,radius := 0.65,how := "walk") -> void:
	if dt<=0 or before.distance_to(after)>3:
		return
	var res := registry(tree)
	if res==null:
		return
	if how!="push":
		_push_shoved.erase(actor) # (the held push has ended: the next is a new push)
	var present := {}
	for contact: Dictionary in measure(tree,source,before,radius,Vector3.ZERO,-1,after):
		var id := int(contact.id)
		var fact: Dictionary=VillageSession.village.people[id].body_facts.get("carried",{})
		if str(fact.get("carrier",""))==actor:
			continue
		var key := JSON.stringify([actor,how,str(contact.actor)])
		present[key]=true
		var state := pair(actor,str(contact.actor),true,dt,how)
		var motion := Vector2(after.x-before.x,after.z-before.z)/dt
		var toward := Vector2(contact.at.x-before.x,contact.at.z-before.z).normalized()
		var sample := {"closing":maxf(0,motion.dot(toward)),"speed":motion.length(),"how":how,"at":contact.at}
		for touch: RefCounted in touches.values():
			var result: Dictionary=touch.measure(sample,state,dt)
			if result.is_empty():
				continue
			var again: bool=state.shown and how=="push" and float(result.get("stumble",0.0))>0.0 and float(state.age)-float(state.get("stumbled_at",0.0))>=0.6
			if (not state.shown and int(result.get("cue_force",0))>0) or again:
				state.shown=true
				state.stumbled_at=float(state.age)
				res.play_contact(int(contact.id),{"force":int(result.cue_force),"from":[before.x,before.z]})
				if float(result.get("stumble",0.0))>0.0 and res._movers.has(id):
					var away := Vector2(contact.at.x-before.x,contact.at.z-before.z)
					if res._movers[id].stagger(_aside(away,motion,id),_clearing(away,motion,float(result.stumble)),0.05,0.45) and float(result.stumble)>=0.45:
						res.bodies[id].vocal("grunt",0.35) # (a hard barge: a running one is knocked about)
			if how=="push" and (_push_shoved.get(actor,{}) as Dictionary).has(id):
				continue # This push has shoved them already; they only give ground.
			if not state.delivered and result.has("verb"):
				var fields: Dictionary=result.get("fields",{}).duplicate(true)
				fields.press_id=state.press_id
				var accepted := perform(tree,actor,source,str(result.verb),fields,after,2.8,Vector3.ZERO,int(contact.id))
				if accepted.get("accepted",false):
					state.delivered=true
					if how=="push":
						if not _push_shoved.has(actor):
							_push_shoved[actor]={}
						_push_shoved[actor][id]=true
	# Small leave margin; retries hold the same key while still touching.
	for key: String in pairs.keys():
		if str(pairs[key].actor)==actor and str(pairs[key].how)==how and not present.has(key):
			pairs[key].away=float(pairs[key].get("away",0))+dt
			if float(pairs[key].away)>0.25:
				pairs.erase(key)
		elif present.has(key):
			pairs[key].away=0.0
