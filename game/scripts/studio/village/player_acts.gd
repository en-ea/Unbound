extends RefCounted
## E general action seam, independent of bindings/hold modes/gesture directions.
## perform(actor,registry,verb,target,parameters,geometry)->checked receipt; request is the player adapter.
## Physical verbs use bridge.perform. Ordinary talk/step_in/learn retain WorldActions as their ONE owner.
## Authored Free/Testify use event_action(bridge,event_id,verb,parameters,measured_context).
## All three routes batch ready people facts/memories/progress through bridge.accept before publishing.
## press_id identifies a caller intent; Body retains it across save-failure retries.
## Opaque receipt keys persist in people_facts even when an old runtime receipt view is compacted.
const WorldActions := preload("res://scripts/studio/village/sim/world_actions.gd")
const Runtime := preload("res://scripts/studio/village/sim/runtime.gd")
const People := preload("res://scripts/studio/village/sim/people.gd")
const PeopleActions := preload("res://scripts/studio/village/sim/people_actions.gd")
const VillageImage := preload("res://scripts/studio/village/sim/image.gd")
static func request(_player: Node3D,registry: Node,verb: String,target: int,parameters: Dictionary = {}) -> Dictionary:
	return perform("player:local",registry,verb,target,parameters)
static func perform(actor: String,registry: Node,verb: String,target: Variant,parameters: Dictionary = {},geometry: Dictionary = {}) -> Dictionary:
	var bridge=registry.get("people_bridge")
	if bridge==null or not bridge.available():
		return {"accepted":false,"reason":"unavailable"}
	var v=VillageSession.village
	var id := int(target) if target is int else People.resident(v,str(target))
	if PeopleActions.handles(verb):
		return bridge.perform(actor,[{"id":id}],verb,parameters,geometry)
	if actor!="player:local" or id<0 or not registry.bodies.has(id):
		return {"accepted":false,"reason":"unavailable authored actor"}
	var from: Vector2=bridge.at(actor,-1)
	var to: Vector2=bridge.at(People.key(v,id),-1)
	if from==Vector2.INF or to==Vector2.INF:
		return {"accepted":false,"reason":"unmeasured target"}
	var press := str(parameters.get("press_id","%d:%d" % [People.tick(v),int(v.runtime.sequence)]))
	var key := "act:"+(actor+"|"+verb+"|"+str(id)+"|"+press).sha256_text().substr(0,32)
	var req := {"action_id":key,"player_id":actor,"village_id":v.runtime.village,"logical_time":v.runtime.now,
		"verb":verb,"target":id,"parameters":parameters}
	var context := {"distance_dm":ceili(from.distance_to(to)*10),"witnesses":parameters.get("witnesses",[])}
	return bridge.accept(func(candidate)->Dictionary:
		if candidate.people_facts.has(key):
			var previous: Dictionary=candidate.people_facts[key].receipt.duplicate(true)
			previous.duplicate=true
			return previous
		VillageImage.touch_person(-1) # rules acts may change anyone
		var result := WorldActions.act(candidate,req,context)
		if result.get("accepted",false) and not result.get("duplicate",false):
			result.costs=[] if int(result.get("coins",0))==0 else [{"item":"coins","count":int(result.coins)}]
			VillageImage.touch_key("people_facts",key)
			candidate.people_facts[key]={"actor":actor,"target":People.key(candidate,id),"verb":verb,"tick":People.tick(candidate),"receipt":result.duplicate(true)}
		return result)
## Scope: urgent authored Free/Testify; Runtime remains their decision authority. Body connects live._act.
## measured_context {authorized,distance_dm,witnesses?,coins?,wood?}; preserves in-talk eligibility.
static func event_action(bridge: Node,event_id: int,verb: String,parameters: Dictionary,context: Dictionary) -> Dictionary:
	if verb not in ["free","testify"] or not context.get("authorized",false):
		return {"accepted":false,"reason":"unavailable"}
	var v=VillageSession.village
	var key := "event-act:"+(str(event_id)+"|"+verb+"|"+JSON.stringify(parameters)).sha256_text().substr(0,32)
	var req := {"action_id":key,"player_id":"player:local","village_id":v.runtime.village,"logical_time":v.runtime.now,
		"event_id":event_id,"verb":verb,"parameters":parameters}
	return bridge.accept(func(candidate)->Dictionary:
		if candidate.people_facts.has(key):
			var previous: Dictionary=candidate.people_facts[key].receipt.duplicate(true)
			previous.duplicate=true
			return previous
		VillageImage.touch_person(-1)
		var result := Runtime.act(candidate,req,context)
		if result.get("accepted",false) and not result.get("duplicate",false):
			VillageImage.touch_key("people_facts",key)
			candidate.people_facts[key]={"actor":"player:local","event":event_id,"verb":verb,"tick":People.tick(candidate),"receipt":result.duplicate(true)}
		return result)
