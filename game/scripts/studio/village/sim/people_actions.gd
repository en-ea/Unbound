extends RefCounted
## S/E fact authority. prepare(candidate, request, context) accepts one input-independent root.
## request {action_id opaque, actor opaque ref, target opaque ref, verb, village_id, logical_time, parameters}.
## context {authorized, distance_dm, reach_dm?, at/from metres [x,z], accounts?, defer_accounts?,
## have?, food?, water_contact?, can_carry?, consent?, measured_incident?}. Physical capability is not harm permission.
## Force/heat/strength 0..1000; hurt is the existing 0..100 rule injury. Ticks are active milliseconds.
## body_facts {kind,id,deed,cause_id,revision,since_tick,until_tick?,strength,at,from?,...}.
## advance() analytically accepts meaningful exposure/end/recovery facts, never presentation frames.
## Root event IDs and actor truth stay in people_facts; event_ref is opaque and safe in bounded accounts.
## Caller batches ready memories/progress and checks ONE save before publishing consequences.
const People := preload("res://scripts/studio/village/sim/people.gd")
const S := preload("res://scripts/studio/village/sim/state.gd")
const VillageImage := preload("res://scripts/studio/village/sim/image.gd")
const Rules := preload("res://scripts/studio/village/sim/village.gd")
const Events := preload("res://scripts/studio/village/sim/events.gd")
const VERBS := ["strike","shove","square_up","give","burn","fall","extinguish","carry","set_down"]
const FIRE_RATE := 100000 # milliseconds * heat per one injury point
static func handles(verb: String) -> bool:
	return verb in VERBS
static func rejected(reason: String) -> Dictionary:
	return {"accepted":false,"reason":reason}
static func incident(action: String) -> String:
	return "incident:"+action.sha256_text().substr(0,24)
static func down(v: S.Village, p: S.Person) -> bool:
	return p.body_facts.has("down") and int(p.body_facts.down.get("until_tick",0))>People.tick(v)
static func fact(v: S.Village, p: S.Person, kind: String, deed: String, fields: Dictionary) -> Dictionary:
	VillageImage.touch_person(p.id)
	var before: Dictionary=p.body_facts.get(kind,{})
	var row := {"kind":kind,"id":kind,"deed":deed,"cause_id":deed,"revision":int(before.get("revision",0))+1,
		"since_tick":People.tick(v),"strength":1000}
	row.merge(fields,true)
	p.body_facts[kind]=row
	return row
static func _location(p: S.Person, context: Dictionary) -> Array:
	var point: Array=context.get("at",p.body_facts.get("location",{}).get("at",[0.0,0.0]))
	return point.duplicate()
static func prepare(v: S.Village, request: Dictionary, context: Dictionary) -> Dictionary:
	var action := str(request.get("action_id",""))
	if action.is_empty() or action.length()>160:
		return rejected("invalid action")
	if v.people_facts.has(action):
		var previous: Dictionary=v.people_facts[action].receipt.duplicate(true)
		previous.duplicate=true
		return previous
	if not context.get("authorized",false) or request.get("village_id")!=v.runtime.village or request.get("logical_time")!=v.runtime.now:
		return rejected("stale context")
	var id := People.resident(v,str(request.get("target","")))
	if id<0:
		return rejected("no one there")
	var p := v.people[id]
	VillageImage.touch_person(id)
	var distance := float(context.get("distance_dm",INF))
	var verb := str(request.get("verb",""))
	var params: Dictionary=request.get("parameters",{})
	var reach := clampf(float(context.get("reach_dm",30)),0,120) if verb=="burn" else 30.0
	if not handles(verb) or str(request.get("actor","")).is_empty() or not p.present or not is_finite(distance) or distance<0 or distance>reach:
		return rejected("out of reach")
	if not p.alive and verb not in ["carry","set_down"]:
		return rejected("no living target")
	# The body can flinch/burn while held. Harm permissions remain separate from physical capability.
	if verb in ["strike","shove","burn","square_up"] and (Rules.age_of(v,p)<14 or p.authored!=""):
		return rejected("protected")
	if verb in ["strike","shove","square_up"] and (p.locked or down(v,p)):
		return rejected("held or down")
	if verb=="fall" and (not context.get("measured_incident",false) or str(request.actor)!=str(request.target)):
		return rejected("no measured independent fall")
	var burning: Dictionary=p.body_facts.get("burning",{})
	if verb=="extinguish":
		if burning.is_empty():
			return rejected("no flames")
		if str(params.get("cause_id",burning.deed))!=str(burning.deed):
			return rejected("changed fire")
		var method := str(params.get("method",""))
		if method=="water":
			if not context.get("water_contact",false):
				return rejected("no measured water contact")
		elif method=="beat":
			if distance>12:
				return rejected("no helping contact")
		elif method=="smother":
			if not down(v,p) or str(request.actor)!=str(request.target):
				return rejected("not grounded")
		else:
			return rejected("no extinguishing method")
	var at := _location(p,context)
	var from: Array=context.get("from",at).duplicate()
	var result := {"accepted":true,"action_id":action,"event_ref":incident(action),"target":id,"outcome":verb,"costs":[]}
	var force := clampi(int(params.get("force",850 if params.get("heavy",false) else 450)),0,1000)
	if verb in ["strike","shove","fall"]:
		var damage := clampi(int(params.get("damage",1)),0,5)
		p.hurt=clampi(p.hurt+(damage*14 if verb=="strike" else clampi(int(params.get("harm",0 if verb=="fall" else 4)),0,20)),0,100)
		fact(v,p,"hurt",action,{"strength":p.hurt*10,"at":at,"where":str(params.get("where","chest"))})
		# A directional force can cause down without inventing another health value.
		if verb=="fall" or p.hurt>=100 or force>=750:
			fact(v,p,"down",action,{"until_tick":People.tick(v)+6000,"strength":force,"from":from,"at":at})
		result.merge({"force":force,"from":from,"at":at,"hurt":p.hurt,"down":down(v,p)},true)
	if verb=="burn":
		var heat := clampi(int(params.get("heat",750)),1,1000)
		var duration := clampi(int(params.get("duration_ms",14000 if heat>=650 else 4000)),1000,30000)
		# Resolve earlier heat at this acceptance before replacing its exposure clock.
		_exposure(v,p,People.tick(v),at)
		if not p.alive:
			return rejected("already died")
		fact(v,p,"burning",action,{"until_tick":People.tick(v)+duration,"strength":heat,"heat":heat,
			"at":at,"from":from,"exposure_tick":People.tick(v),"applied_hurt":0,"base_hurt":p.hurt})
		# Heat and measured impulse belong to this same root. No synthetic strike/injury.
		var impulse := clampi(int(params.get("force",0)),0,1000)
		if impulse>=750 and not down(v,p):
			fact(v,p,"down",action,{"until_tick":People.tick(v)+6000,"strength":impulse,"from":from,"at":at})
		result.merge({"force":impulse,"from":from,"at":at,"down":down(v,p)},true)
		result.burning=true
	if verb=="extinguish":
		var method := str(params.get("method",""))
		_exposure(v,p,People.tick(v),at)
		if not p.alive:
			return rejected("too late")
		var cause := str(burning.deed)
		p.body_facts.erase("burning")
		fact(v,p,"doused",action,{"cause_id":cause,"until_tick":People.tick(v)+2500,"strength":int(burning.strength),"at":at,"method":method})
		result.merge({"extinguished":true,"fire_cause":cause,"method":method},true)
	if verb=="carry":
		if not context.get("can_carry",false) or p.locked or p.authored!="" or (p.alive and not down(v,p) and p.hurt<60 and not context.get("consent",false)):
			return rejected("cannot carry")
		if p.body_facts.has("carried"):
			return rejected("already carried")
		fact(v,p,"carried",action,{"carrier":str(request.actor),"at":at})
		result.carried=true
	if verb=="set_down":
		if not p.body_facts.has("carried") or str(p.body_facts.carried.carrier)!=str(request.actor):
			return rejected("not your load")
		p.body_facts.erase("carried")
		result.set_down=true
	if verb=="give":
		var item := str(params.get("item",""))
		var count := clampi(int(params.get("count",1)),1,20)
		if item.is_empty() or int(context.get("have",0))<count:
			return rejected("nothing to give")
		result.merge({"item":item,"count":count,"costs":[{"item":item,"count":count}]},true)
		if context.get("food",false) and p.household>=0:
			VillageImage.touch_field("households")
			v.households[p.household].food+=count*4
	# A carried placement is caused by its carrier; fire has a separate exposure cause.
	var location_cause := str(p.body_facts.carried.deed) if p.body_facts.has("carried") else action
	fact(v,p,"location",location_cause,{"at":at})
	var event := Events.log_event(v,"people_action",-1,-1,{"incident":result.event_ref,"verb":verb},PackedInt32Array(),"a physical act")
	VillageImage.touch_key("people_facts",action)
	v.people_facts[action]={"actor":str(request.actor),"target":str(request.target),"verb":verb,
		"tick":People.tick(v),"event":event,"event_ref":result.event_ref,"receipt":result.duplicate(true)}
	if not context.get("defer_accounts",false):
		for a: Dictionary in context.get("accounts",[]):
			VillageImage.touch_actor(v,str(a.observer))
			VillageImage.touch_fact(v,str(a.observer),str(a.deed)+":"+str(a.observer))
		People.admit(v,context.get("accounts",[]))
	v.runtime.sequence+=1
	return result
static func _exposure(v: S.Village, p: S.Person, now: int, at: Array) -> void:
	if not p.alive or not p.body_facts.has("burning"):
		return
	var burn: Dictionary=p.body_facts.burning
	var end := mini(now,int(burn.until_tick))
	var elapsed := maxi(0,end-int(burn.get("exposure_tick",burn.since_tick)))
	var amount: int=elapsed*int(burn.get("heat",burn.strength))/FIRE_RATE
	var previous := int(burn.get("applied_hurt",0))
	if amount>previous:
		p.hurt=clampi(p.hurt+amount-previous,0,100)
		burn.applied_hurt=amount
		fact(v,p,"hurt",str(burn.deed),{"strength":p.hurt*10,"at":at,"where":"burn"})
	if p.hurt>=70 and not down(v,p):
		fact(v,p,"down",str(burn.deed),{"until_tick":now+6000,"strength":int(burn.strength),"at":at,"from":burn.get("from",at)})
	if p.hurt>=100:
		var deed := str(burn.deed)
		var root: Dictionary=v.people_facts.get(deed,{})
		var causes := PackedInt32Array()
		if root.has("event"):
			causes.append(int(root.event))
		VillageImage.touch_person(-1) # the rules' death may change anyone
		var death_event := Rules.die(v,p.id,"burned",causes,"a burned body lying still")
		fact(v,p,"dead",deed,{"at":at,"strength":1000,"event":death_event})
		p.body_facts.erase("burning")
		p.body_facts.erase("down")
		VillageImage.touch(p.id)
		p.mind.plan={}
static func next_due(v: S.Village) -> int:
	var due := 9223372036854775807
	for p: S.Person in v.people:
		for kind: String in ["down","doused"]:
			if p.body_facts.has(kind):
				due=mini(due,int(p.body_facts[kind].until_tick))
		if p.alive and p.body_facts.has("burning"):
			var burn: Dictionary=p.body_facts.burning
			var applied := int(burn.get("applied_hurt",0))
			var next_amount := (applied/10+1)*10
			var heat := maxi(1,int(burn.get("heat",burn.strength)))
			var next_tick := int(burn.get("exposure_tick",burn.since_tick))+ceili(float(next_amount*FIRE_RATE)/heat)
			due=mini(due,mini(next_tick,int(burn.until_tick)))
	return due
static func advance(v: S.Village, locations: Dictionary = {}) -> Array:
	var out := []
	var now := People.tick(v)
	for p: S.Person in v.people:
		var actor := People.key(v,p.id)
		var at: Array=locations.get(actor,p.body_facts.get("location",{}).get("at",[0.0,0.0]))
		var had_fire := p.body_facts.has("burning")
		if had_fire or p.body_facts.has("down") or p.body_facts.has("doused"):
			VillageImage.touch_person(p.id)
		var fire: Dictionary=p.body_facts.get("burning",{}).duplicate(true)
		var was_alive := p.alive
		if had_fire:
			_exposure(v,p,now,at)
			if p.alive and now>=int(fire.until_tick):
				p.body_facts.erase("burning")
				fact(v,p,"doused",str(fire.deed),{"until_tick":now+2500,"strength":int(fire.strength),"at":at,"method":"burned_out"})
			if was_alive and not p.alive:
				out.append({"kind":"death","subject":actor,"cause_id":str(fire.deed),"fact_id":"dead","revision":int(p.body_facts.dead.revision)})
		for kind: String in ["down","doused"]:
			if p.body_facts.has(kind) and now>=int(p.body_facts[kind].until_tick):
				p.body_facts.erase(kind)
		if had_fire:
			var cause := str(p.body_facts.carried.deed) if p.body_facts.has("carried") else str(fire.get("deed",""))
			var prior: Dictionary=p.body_facts.get("location",{})
			if not cause.is_empty() and (prior.get("at",[])!=at or str(prior.get("deed",""))!=cause):
				fact(v,p,"location",cause,{"at":at})
	return out
