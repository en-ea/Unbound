extends Node
## E/P/S/C shared live adapter. perform(actor,targets,verb,parameters,geometry)->checked receipt.
## contacts()/action() are provisional player adapters, independent of button/gesture bindings.
## Geometry is actual actor/contact/effect/subject position, metres; requests use measured decimetres.
## register_actor(ref,node) supplies an existing generic body; senses use the ONE crowd snapshot.
## observe(record) measures event/subject/emitter/alleged-doer separately; rendering visibility is no sense.
## announce(emitter,{kind,subject,deed,fact_id,revision,transition?,notice_id?}) queues bounded evidence only.
## Discovered source NOTICE declares allowed saved facts/transition/posture/persistent discovery.
## Stable notices validate saved causes/fact revisions. One cause:observer account can gain evidence facets.
## No cause lookup exposes aggressor truth. Continued burning/dead facts are discoverable after rehydration.
## Roots, due facts, ready memories, reports, uses and semantic phases share ONE checked acceptance.
## Callbacks only queue. Failed batches publish nothing and keep stable keys; no frame/pose saves.
## semantic_changed() refreshes cached deadlines/active conditions after accepted changes or rehydration.
## source_folders/modifier_folders use normal discovery; idle _flush polls never scan saved people.
## S5 hints reach residents.express_body -> body.express; clips/layers remain Body/Claude-owned.
## People.expression projects the current active clock; measured attention never resolves private causes.
## First measured contacts/accounts survive failed-save retry per village/actor/press/verb/subject.
## Target-set delivery selects retained per-subject captures; overlapping cast sets accept each root once.
## quiesce parks captured pending evidence and actual semantic body locations in ONE checked save.
## C4 port adds use(step)->bool and affordance(kind)->{key,at,focus,reach}; real contact precedes acceptance.
## C4 say delegates body groups/capacity to Speech; accepted presentation queues do not globally hold travel.
## Checked carried placement keeps its carrier deed independently of any continuing fire exposure cause.
## refresh_steps(id,plan) binds accepted same-generation annotations without replaying a primitive.
## Arrived report receipts remain frozen in reports; refreshing future steps never rewrites those receipts.
const People := preload("res://scripts/studio/village/sim/people.gd")
const Actions := preload("res://scripts/studio/village/sim/people_actions.gd")
const Accept := preload("res://scripts/studio/village/acceptance.gd")
const Perception := preload("res://scripts/studio/people/perception.gd")
const Modules := preload("res://scripts/studio/people/modules.gd")
const Performer := preload("res://scripts/studio/people/performer.gd")
const Speech := preload("res://scripts/studio/people/speech.gd")
const Water := preload("res://scripts/studio/village/water.gd")
const VillageImage := preload("res://scripts/studio/village/sim/image.gd")
const Rules := preload("res://scripts/studio/village/sim/village.gd")
var res: Node
var player: Node3D
var runners := {}
var phase_requests := {}
var reports := {}
var uses := {}
var notices := {}
var witnesses := [] # an act's own witness accounts beyond its batch's share, admitted by the next frame batches
## Saturation (desk 6 Oct, rule 7: one star over a crowd built ~1,300 accounts in a frame). In a burst (BURST_MS of
## active time) an observer takes in at most SATURATE accounts of others' conditions and of an area act's targets -
## their own ties first (kin, spouse, friends), then the gravest (dead, down before hurt, hurt before a cry), then the
## nearest - and the rest as one summary account ("many fell there": the gravest left out, with the count). A person's
## own condition and an act on themselves are always taken in. Only the chosen pairs are observed, so the work is
## bounded by observers x (SATURATE + 1), not observers x bodies. Ordinary single acts and notices are unchanged.
var SATURATE := _saturate_arg()     # 3; a measurement may pass --saturate=N (999: nothing saturated, as before)
const BURST_MS := 1500
## Shorter sight and hearing (Hilmi, 6 Oct: "Shorter sight/hearing"; plan/SMOOTHNESS-TUNING-2026-10-06.md): every
## source's reach (8-36 m) and the people's sight (Balance.STEALTH.sight, 15 m) are scaled here, for villagers only (the
## player's stealth against foes keeps Enea's numbers). --perceive=F and --sight=F set them for measurement.
var PERCEIVE := _scale_arg("--perceive=",0.6)
var SIGHT := _scale_arg("--sight=",0.8)
## A villager's sight by day in metres (15 x 0.8 = 12): Body's regard and senses read this, not a copy.
static func villager_sight_m() -> float:
	return float(Balance.STEALTH.sight)*_scale_arg("--sight=",0.8)
## Bystanders notice through the think scheduler (Hilmi: "semi async processing"): an act's touched people (its target,
## its actor) and a notice's subject take theirs in at once, in the act's own batch (1f955df); every other onlooker is
## one Think job, run within the frame's think budget a frame or a few later, and learned in the next batch.
## --defer-sensing=off senses everyone at once, as before (measurement).
var DEFER := _scale_arg("--defer-sensing=",1.0)>0.0
var _seeing := {}            # pending onlooker jobs: key -> Callable (quiesce runs them before a save)
static func _scale_arg(prefix: String,default: float) -> float:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			var value := arg.trim_prefix(prefix)
			return 0.0 if value=="off" else (1.0 if value=="on" else float(value))
	return default
func _reach(stimulus: Dictionary) -> float:
	return float(stimulus.reach)*PERCEIVE
## One onlooker's sensing, later, within the think budget; what they take in waits with the act's other witnesses.
func _see_later(observer: String,stimulus: Dictionary,done: Callable) -> void:
	var key := observer+"|"+str(stimulus.get("notice_id",stimulus.get("deed","")))+"|"+str(stimulus.get("kind",""))
	var job := func(_elapsed: float) -> void:
		if not _seeing.has(key):return
		_seeing.erase(key)
		if VillageSession.village==null or not available():return
		done.call(observe(stimulus,{observer:true}))
	_seeing[key]=job
	Think.once("see:"+key,"see",job)   # one kind for every onlooker job (the scheduler keeps its stats by kind)
## Every onlooker job still waiting, run now (a save is about to take what is known).
func _see_now() -> void:
	while not _seeing.is_empty():       # (a selection run here schedules onlooker jobs: those run in the next pass)
		for key: String in _seeing.keys():
			if _seeing.has(key):
				(_seeing[key] as Callable).call(0.0)
static func _saturate_arg() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--saturate="):return int(arg.trim_prefix("--saturate="))
	return 3
const GRAVITY := {"death":4,"fall":3,"burning":3,"fire":3,"down":3,"injured":2,"contact":2,"cry":1,"doused":1}
var _bursts := {}            # observer -> {"until": tick, "taken": int, "summary": bool}
var _pending_notices := []   # this frame's condition notices, chosen and observed at the frame's end
var _flush_queued := false
var saturation := {"notices":0,"observed":0,"summaries":0}   # counts for the probes (accounts kept and folded)
var accounts_built := 0      # every account observe() has built (probes read the difference over a window)
func _burst_of(observer: String) -> Dictionary:
	var now := People.tick(VillageSession.village)
	var b: Dictionary=_bursts.get(observer,{})
	if b.is_empty() or now>int(b.until):
		b={"until":now+BURST_MS,"taken":0,"summary":false}
		_bursts[observer]=b
	return b
## The observers a stimulus could reach (the same rows observe() visits), without sensing them.
func _observers(stimulus: Dictionary) -> Array:
	var v=VillageSession.village
	var event_at := Vector2(float(stimulus.at[0]),float(stimulus.at[1]))
	var rows: Array=res._crowd.nearby.query(event_at,_reach(stimulus))
	var out := []
	var seen := {}
	for row: Dictionary in rows:
		var observer := str(row.key)
		var id := People.resident(v,observer)
		if seen.has(observer) or not is_instance_valid(row.get("body")):continue
		if id>=0 and (not v.people[id].alive or not v.people[id].present):continue
		if id<0 and not v.actor_minds.has(observer):continue
		seen[observer]=true
		out.append({"key":observer,"id":id,"distance":(row.body as Node3D).global_position.distance_to(Vector3(event_at.x,(row.body as Node3D).global_position.y,event_at.y))})
	return out
## Salience of what one observer would take in: [own, tie, gravity, -distance] (bigger first).
func _salience(observer: Dictionary,subject: String,kind: String) -> Array:
	var v=VillageSession.village
	var own := 1 if str(observer.key)==subject else 0
	var tie := 0
	var s := People.resident(v,subject)
	if int(observer.id)>=0 and s>=0 and own==0:
		var a: int=observer.id
		if Rules.is_kin(v,a,s) or v.people[a].spouse==s or Rules.opinion(v,a,s)>=30:tie=1
	return [own,tie,int(GRAVITY.get(kind,1)),-float(observer.distance)]
static func _before(x: Array,y: Array) -> bool:
	for i in x.size():
		if x[i]!=y[i]:return x[i]>y[i]
	return false
## One summary account for an observer: the gravest record they left out, marked many, with the count.
func _summary(record: Dictionary,observer: String,count: int) -> Array:
	return observe(_summary_record(record,observer,count),{observer:true})
func _summary_record(record: Dictionary,observer: String,count: int) -> Dictionary:
	var r: Dictionary=record.duplicate(true)
	var evidence: Dictionary=r.get("evidence",{})
	evidence.many=true
	evidence.count=count
	r.evidence=evidence
	r.notice_id="notice:"+(str(record.get("deed",""))+"|many|"+observer).sha256_text().substr(0,32)
	saturation.summaries+=1
	return r
var log: Array = []
var _actors := {}
var _contact_captures := {}
var _voice_until := 0 # Retired global admission timer; Speech owns body groups and presentation capacity.
var _retry_at := 0
var _scan_at := 0
var _publishing := false
var modifier_folders: Array=["res://scripts/studio/people/modifiers/"]
var source_folders: Array=["res://scripts/studio/people/sources/"]
var _scheduled_village
var _scheduled_writes := -1 # Accept.writes at the last rebuild: a checked batch keeps the village object (step 4)
var _wake_tick := 0
var _conditions: Array=[]
var _writer := Callable() # Optional checked-writer fixture; production uses SaveGame in Acceptance.
var schedule_scans := 0 # Transient diagnostic count, never saved.
var sense_usec: Array[int] = []
func _init(registry: Node,writer := Callable()) -> void:
	res=registry
	_writer=writer
	name="PeopleBridge"
## Step 4 (5 Oct): extension folders are discovered (their scripts loaded) when the village starts, not inside the
## first checked batch that needs them: the first chooser alone measured 17.9 ms there, a cold stall on a reaction.
const WARM_FOLDERS := ["res://scripts/studio/people/offers/","res://scripts/studio/people/modifiers/",
	"res://scripts/studio/people/temperaments/","res://scripts/studio/people/steps/","res://scripts/studio/people/sources/"]
func _ready() -> void:
	for folder: String in WARM_FOLDERS+source_folders+modifier_folders:
		Modules.discover(folder)
	add_to_group("people_bridge")
	player=get_tree().get_first_node_in_group("player")
	if player!=null:
		register_actor("player:local",player)
func available() -> bool:
	return VillageSession.village!=null and VillageSession.active and not VillageSession.background and not Controls.locked and not SaveGame.paused and not get_tree().paused
func register_actor(actor: String, body: Node3D) -> void:
	if not actor.is_empty() and is_instance_valid(body):
		_actors[actor]=body
func actor_node(actor: String) -> Node3D:
	var id := People.resident(VillageSession.village,actor)
	if id>=0 and res.bodies.has(id):
		return res.bodies[id]
	if _actors.has(actor) and is_instance_valid(_actors[actor]):
		return _actors[actor]
	for row: Dictionary in res._crowd.nearby.rows:
		if str(row.key)==actor and is_instance_valid(row.get("body")):
			return row.body
	return null
func action(verb: String,target: int,parameters: Dictionary) -> Dictionary:
	return contacts([{"id":target}],verb,parameters)
func contacts(targets: Array,verb: String,parameters: Dictionary,geometry: Dictionary = {}) -> Dictionary:
	return perform(str(geometry.get("actor",parameters.get("actor","player:local"))),targets,verb,parameters,geometry)
func perform(actor: String,targets: Array,verb: String,parameters: Dictionary,geometry: Dictionary = {}) -> Dictionary:
	if _publishing:
		return {"accepted":false,"reason":"notification acceptance"}
	if not available():
		return {"accepted":false,"reason":"unavailable"}
	var v=VillageSession.village
	var press := str(parameters.get("press_id","%d:%d" % [People.tick(v),int(v.runtime.sequence)]))
	var key := JSON.stringify([actor,press,verb])
	var selected := []
	for target: Dictionary in targets:
		var id := int(target.get("id",People.resident(v,str(target.get("actor","")))))
		if id>=0 and not selected.has(id):selected.append(id)
	var measured := []
	var touched := {}
	for id: int in selected:
		touched[People.key(v,id)]=true
	var area := selected.size()>SATURATE    # many touched at once: bystanders are saturated across the rows below
	for id: int in selected:
		var capture_key := JSON.stringify([key,People.key(v,id)])
		var prior: Dictionary=_contact_captures.get(capture_key,{})
		if str(prior.get("village",""))==str(v.runtime.village):measured.append_array(prior.rows)
		else:
			if _contact_captures.size()>=64:return {"accepted":false,"reason":"pending contact capacity"}
			var inline := {People.key(v,id):true,actor:true} if DEFER else {}
			var fresh := _measure_contacts(v,actor,[{"id":id}],verb,parameters,geometry,key,{People.key(v,id):true} if area else inline)
			if fresh.get("accepted",false):
				_contact_captures[capture_key]=fresh
				measured.append_array(fresh.rows)
	if area and not DEFER:
		_saturate_bystanders(measured,touched)
	var captured := {"accepted":not measured.is_empty(),"reason":"no measured contact","rows":measured}
	if not captured.get("accepted",false):
		return captured
	var result := accept(func(candidate)->Dictionary:
		var accepted := []
		var costs := []
		var duplicates := true
		var accounts := []
		for row: Dictionary in measured:
			var request: Dictionary=row.request.duplicate(true)
			# Validate at this candidate clock; sensing/occurred_tick/geometry remain the first capture.
			request.logical_time=candidate.runtime.now
			var answer := Actions.prepare(candidate,request,row.context)
			if not answer.get("accepted",false):
				continue
			accepted.append(answer)
			duplicates=duplicates and bool(answer.get("duplicate",false))
			costs.append_array(answer.get("costs",[]))
			if not answer.get("duplicate",false):
				accounts.append_array(row.accounts)
		if accepted.is_empty():
			return {"accepted":false,"reason":"ineligible contact"}
		var out: Dictionary=accepted[0].duplicate(true)
		out.merge({"contacts":accepted,"costs":costs,"duplicate":duplicates,"accounts":accounts},true)
		return out)
	if str(result.get("reason",""))!="save failed":
		for row: Dictionary in measured:_contact_captures.erase(JSON.stringify([key,str(row.request.target)]))
	if result.get("accepted",false) and not result.get("duplicate",false):
		_publishing=true
		for answer: Dictionary in result.get("contacts",[]):
			if answer.get("duplicate",false):
				continue
			if verb in ["strike","shove"] or (verb=="burn" and int(answer.get("force",0))>0):
				res.play_contact(int(answer.target),answer)
			for row: Dictionary in measured:
				if row.request.action_id==answer.action_id:
					res.stimuli.publish(row.stimulus)
					if DEFER and not area:_onlookers_later(row,actor)
			log.append(["accepted",str(answer.action_id),People.tick(VillageSession.village)])
		_publishing=false
		if DEFER and area:
			# An area act's onlookers are chosen out of the cast frame (desk 6 Oct: about 20 ms of a star's 81-94 ms
			# frame): the next frame with think budget, then each chosen pair sensed through Think as before. The act's
			# batch is unchanged: the touched took their own accounts in it.
			var accepted_rows: Array=measured.filter(func(row: Dictionary)->bool:
				return result.get("contacts",[]).any(func(a: Dictionary)->bool:return a.action_id==row.request.action_id and not a.get("duplicate",false)))
			var select := func(_elapsed: float) -> void:
				if not _seeing.has("select|"+key):return
				_seeing.erase("select|"+key)
				if VillageSession.village==null or not available():return
				_saturate_bystanders(accepted_rows,touched)
				for row: Dictionary in accepted_rows:_onlookers_later(row,actor)
			_seeing["select|"+key]=select
			Think.once("select:"+key,"select",select)
	return result
## Captures sensing once. Retry never uses the later observer positions as origin evidence.
## An area act's onlookers (bystanders, and the touched for the others' rows): each takes in up to SATURATE of its rows
## by salience, the rest as one summary account. Each touched person's own row is observed at once (1f955df).
func _saturate_bystanders(measured: Array,touched: Dictionary) -> void:
	var wants := {}
	for r in measured.size():
		var row: Dictionary=measured[r]
		if row.get("bystanders_done",false):continue
		row.bystanders_done=true
		for o: Dictionary in _observers(row.stimulus):
			if str(o.key)==str(row.request.target):continue   # their own account: taken in at once, above
			(wants.get_or_add(str(o.key),[]) as Array).append([_salience(o,str(row.request.target),str(row.stimulus.kind)),r])
	var chosen := {}
	for observer: String in wants:
		var list: Array=wants[observer]
		list.sort_custom(func(x: Array,y: Array)->bool:return _before(x[0],y[0]))
		var b := _burst_of(observer)
		var left := []
		for item: Array in list:
			if int(b.taken)<SATURATE:
				(chosen.get_or_add(item[1],{}) as Dictionary)[observer]=true
				b.taken=int(b.taken)+1
			else:
				left.append(item[1])
		if not left.is_empty() and not bool(b.summary):
			b.summary=true
			var gravest: Dictionary=measured[left[0]]
			if DEFER:(gravest.get_or_add("later_summaries",[]) as Array).append([observer,_summary_record(gravest.stimulus,observer,left.size())])
			else:gravest.accounts.append_array(_summary(gravest.stimulus,observer,left.size()))
	for r: int in chosen:
		if DEFER:measured[r].later=chosen[r]
		else:measured[r].accounts.append_array(observe(measured[r].stimulus,chosen[r]))
## An accepted act's onlookers, sensed later through the think scheduler: an area act's chosen pairs and summaries
## (saturated above), or every other observer in reach of an ordinary act.
func _onlookers_later(row: Dictionary,actor: String) -> void:
	var into := func(found: Array) -> void: witnesses.append_array(found)
	if row.has("later") or row.has("later_summaries") or row.get("bystanders_done",false):
		for observer: String in row.get("later",{}):
			_see_later(observer,row.stimulus,into)
		for pair: Array in row.get("later_summaries",[]):
			_see_later(str(pair[0]),pair[1],into)
		return
	for o: Dictionary in _observers(row.stimulus):
		var observer := str(o.key)
		if observer!=str(row.request.target) and observer!=actor:
			_see_later(observer,row.stimulus,into)
func _measure_contacts(v,actor: String,targets: Array,verb: String,parameters: Dictionary,geometry: Dictionary,key: String,only := {}) -> Dictionary:
	var area := Actions.area(verb,parameters)
	var rain := area and verb=="extinguish"    # rain under a cloud has no body of its own to measure
	var origin := at(actor,-1) if not rain else Vector2.INF
	if origin==Vector2.INF and not rain:
		return {"accepted":false,"reason":"no measured actor"}
	if area:      # an area act (fire, water, rain under a cloud) is measured from its own origin, not the actor's body
		origin=geometry.get("origin",Vector2.INF)
		if origin==Vector2.INF or not is_finite(float(geometry.get("reach",0))) or float(geometry.get("reach",0))<=0:
			return {"accepted":false,"reason":"unmeasured area"}
	var measured := []
	for target: Dictionary in targets:
		var id := int(target.get("id",People.resident(v,str(target.get("actor","")))))
		if id<0 or not res.bodies.has(id):
			continue
		var subject := People.key(v,id)
		var point: Vector2=res._movers[id].pos
		var deed := "deed:"+JSON.stringify([key,subject]).sha256_text().substr(0,32)
		var fields := parameters.duplicate(true)
		fields.act="gift" if verb=="give" else "threat" if verb=="square_up" else verb
		var source := "gift" if verb=="give" else "threat" if verb=="square_up" else "fire" if verb=="burn" else "help" if verb=="extinguish" else "fall" if verb=="fall" else "contact"
		var stimulus: Dictionary=res.stimuli.make(source,actor,subject,[point.x,point.y],fields)
		if stimulus.is_empty():
			continue
		stimulus.merge({"deed":deed,"cause_id":deed,"notice_id":deed,"event_ref":Actions.incident(deed),"tick":People.tick(v)},true)
		var context := {"authorized":true,"distance_dm":ceili(origin.distance_to(point)*10.0),"at":[point.x,point.y],
			"from":[origin.x,origin.y],"defer_accounts":true}
		if area:
			context.reach_dm=float(geometry.get("reach",0))*10.0
		if verb=="give":
			var item := str(parameters.get("item",""))
			context.have=Money.coins if item=="coins" else Inventory.count(item)
			context.food=Food.FOODS.has(item)
		if verb in ["extinguish","wet"]:
			context.water_contact=Water.contact(res,at(actor,-1),point,str(parameters.get("affordance","")))
		for permission: String in ["can_carry","consent","measured_incident"]:
			context[permission]=bool(geometry.get(permission,false))
		measured.append({"stimulus":stimulus,"request":{"action_id":deed,"actor":actor,"target":subject,"verb":verb,
			"village_id":v.runtime.village,"logical_time":v.runtime.now,"parameters":fields},"context":context,
			"accounts":observe(stimulus,only)})   # an area act: only the one it touched here, the others saturated after
	if measured.is_empty():
		return {"accepted":false,"reason":"no contact"}
	return {"accepted":true,"key":key,"village":str(v.runtime.village),"rows":measured}
## Common checked door for ordinary contact and unmigrated authored action adapters.
## prepare(candidate) returns receipt + costs + bounded accounts; no signals, bodies or save calls.
func accept(prepare: Callable) -> Dictionary:
	if _publishing:
		return {"accepted":false,"reason":"notification acceptance"}
	var queued := _queued()
	_trim_notices(queued) # the act's own batch takes the same share of crowd notices as a frame batch
	var later := []
	var result := Accept.transact(func(candidate)->Dictionary:
		VillageImage.hinting()
		var due := Actions.next_due(candidate)<=People.tick(candidate)
		Actions.advance(candidate,_locations())
		var root: Dictionary=prepare.call(candidate)
		var own: Array=root.get("accounts",[]) if root.get("accepted",false) else []
		# The people the act touched learn in its own batch, first; its other witnesses share the budget.
		var touched := {}
		for row: Dictionary in [root]+root.get("contacts",[]):
			if row.get("target") is int:touched[People.key(candidate,int(row.target))]=true
		var first: Array=own.filter(func(a: Dictionary)->bool:return touched.has(str(a.observer)))
		# What was done to them comes first and always in this batch: a person's own account of the act on them (observer
		# its target). Only what they saw of the others shares the budget. (Deferred, one's own burn could reach the mind
		# after the down notice of the same deed and never be learned: Mind's port-probe, Tomas, one run in three.)
		var mine: Array=first.filter(func(a: Dictionary)->bool:return str(a.observer)==str(a.get("target","")))
		first=mine+first.filter(func(a: Dictionary)->bool:return str(a.observer)!=str(a.get("target","")))
		var others: Array=own.filter(func(a: Dictionary)->bool:return not touched.has(str(a.observer)))
		# One admission share for the whole act: the touched first, then other witnesses; the rest wait their turn.
		var fshare := maxi(mine.size(),_witness_chunk(first))
		var share := _witness_chunk(others,NOTICE_ACCOUNTS-fshare) if fshare<NOTICE_ACCOUNTS else 0
		later.clear()   # (a lambda captures its locals by value: assigning `later` here left the outer one empty and dropped every witness past the share, since 1eeca64 - Mind's reading check)
		later.append_array(first.slice(fshare)+others.slice(share)) # the same accounts the act's notice would bring, a frame or more later
		var changed := _apply_queued(candidate,queued,others.slice(0,share),BATCH_LEARNS,first.slice(0,fshare))
		if not root.get("accepted",false) and not changed and not due:
			return root
		var out := root.duplicate(true)
		if not root.get("accepted",false):
			out={"accepted":true,"refused_root":root}
		out.duplicate=bool(root.get("duplicate",false)) and not changed and not due
		out.erase("accounts")
		return out,_writer)
	if result.get("accepted",false) and not result.get("duplicate",false):
		_published(queued)
		witnesses.append_array(later)
	if result.has("refused_root"):
		return result.refused_root
	return result
func appearance(actor: String) -> Dictionary:
	if actor.is_empty():
		return {"key":"unknown","name":"someone"}
	var v=VillageSession.village
	var resident := People.resident(v,actor)
	var shown := {"key":actor,"name":v.people[resident].name if resident>=0 else "you" if actor=="player:local" else "someone"}
	var modifiers := {}
	for folder: String in modifier_folders:
		modifiers.merge(Modules.discover(folder),false)
	var id := People.resident(v,actor)
	var m=v.people[id].mind if id>=0 else v.actor_minds.get(actor)
	if m!=null:
		for row: Dictionary in m.modifiers:
			if modifiers.has(str(row.id)):
				var patch: Dictionary=modifiers[str(row.id)].new().appearance(shown.duplicate(true),row)
				for field: String in ["key","name"]:
					if patch.get(field) is String and not str(patch[field]).is_empty():shown[field]=patch[field]
	return shown
func _seen(from: Vector3,yaw: float,to: Vector3,reach: float,exclude: Array[RID]) -> bool:
	var direction := to-from
	direction.y=0
	var distance := direction.length()
	var face := Vector3(sin(yaw),0,cos(yaw))
	if distance>reach or (distance>3 and face.dot(direction.normalized())<float(Balance.STEALTH.fov)):
		return false
	var ray := PhysicsRayQueryParameters3D.create(from,to,1)
	ray.exclude=exclude
	return get_world_space().intersect_ray(ray).is_empty()
func _sight_reach(node: Node3D) -> float:
	var reach := float(Balance.STEALTH.sight_sneak if node!=null and node.get("sneaking")==true else Balance.STEALTH.sight)
	var scene := get_tree().current_scene
	var environment := scene.get_node_or_null("WorldEnvironment") if scene!=null else null
	if environment!=null and environment.get("night")!=null and float(environment.night)>0.5:reach*=float(Balance.STEALTH.night)
	return reach*SIGHT
func _recognized(actor: String,node: Node3D,observer: String) -> bool:
	if People.resident(VillageSession.village,actor)>=0 or actor=="player:local" or actor==observer:return true
	return node!=null and observer in Array(node.get_meta("people_recognized_by",[]))
## Candidates are visible physical clues or this observer's bounded reports, never a cause lookup.
func _candidates(observer: String,rows: Array,from: Vector3,yaw: float,point: Vector2,exclude: Array[RID]) -> Array:
	var out := []
	var visited := {}
	for row: Dictionary in rows:
		var actor := str(row.key)
		var found: Variant=row.get("body")
		if not is_instance_valid(found):continue   # a body freed this frame may still be in the crowd's index
		var node: Node3D=found
		if visited.has(actor) or actor==observer or Vector2(node.global_position.x,node.global_position.z).distance_to(point)>4.0:continue
		visited[actor]=true
		if not _seen(from,yaw,node.global_position+Vector3(0,1,0),_sight_reach(node),exclude):continue
		var identity := Perception.recognized(appearance(actor),"seen",_recognized(actor,node,observer))
		if str(identity.key)=="unknown":continue
		var clues := []
		var visible: Dictionary=node.get_meta("people_observable",{})
		for clue: String in ["threatening","blood_on_hands","fleeing"]:
			if bool(visible.get(clue,false)):clues.append(clue)
		for hands: Node in get_tree().get_nodes_in_group("studio_hands"):
			if hands.get("player")!=node:continue
			var intent: Dictionary=hands.preview()
			if str(intent.get("phase",""))=="prepared" and str(intent.get("verb","")) in ["strike","heavy","shove"] and float(intent.get("strength",0))>0.3:clues.append("threatening")
		if not clues.is_empty():out.append({"identity":identity,"confidence":350,"basis":clues.slice(0,3),"via":"seen"})
		if out.size()>=3:break
	return out
func observe(stimulus: Dictionary,only := {}) -> Array:
	var started := Time.get_ticks_usec()
	var v=VillageSession.village
	var event_at := Vector2(float(stimulus.at[0]),float(stimulus.at[1]))
	var rows: Array=res._crowd.nearby.query(event_at,_reach(stimulus))
	var victim := People.resident(v,str(stimulus.target))
	if victim>=0 and res.bodies.has(victim) and not rows.any(func(row: Dictionary)->bool:return str(row.key)==People.key(v,victim)):
		rows.append({"key":People.key(v,victim),"body":res.bodies[victim],"at":res._movers[victim].pos})
	var out := []
	var visited := {}
	var emitter := actor_node(str(stimulus.source))
	var alleged := actor_node(str(stimulus.get("actor",stimulus.source)))
	var subject := actor_node(str(stimulus.get("subject",stimulus.target)))
	for row: Dictionary in rows:
		var observer := str(row.key)
		var id := People.resident(v,observer)
		if visited.has(observer) or not is_instance_valid(row.get("body")):
			continue
		if not only.is_empty() and not only.has(observer):
			continue
		if id>=0 and (not v.people[id].alive or not v.people[id].present):
			continue
		if id<0 and not v.actor_minds.has(observer):
			continue # Enea/creature adapters explicitly opt a generic observer in.
		visited[observer]=true
		var body: Node3D=row.body
		var from := body.global_position+Vector3(0,1.4,0)
		var eye_y := subject.global_position.y+1.0 if subject!=null else body.global_position.y+1.0
		var event_to := Vector3(event_at.x,eye_y,event_at.y)
		var exclude: Array[RID]=[]
		for node: Node3D in [body,emitter,alleged,subject]:
			if node is CollisionObject3D and not exclude.has(node.get_rid()):
				exclude.append(node.get_rid())
		var seen_event := _seen(from,body.global_rotation.y,event_to,minf(_sight_reach(emitter),_reach(stimulus)),exclude)
		var seen_actor := alleged!=null and _seen(from,body.global_rotation.y,alleged.global_position+Vector3(0,1,0),_sight_reach(alleged),exclude)
		var seen_subject := subject!=null and _seen(from,body.global_rotation.y,subject.global_position+Vector3(0,1,0),_sight_reach(subject),exclude)
		var seen_emitter := emitter!=null and _seen(from,body.global_rotation.y,emitter.global_position+Vector3(0,1,0),_sight_reach(emitter),exclude)
		var sound_ray := PhysicsRayQueryParameters3D.create(from,event_to,1)
		sound_ray.exclude=exclude
		var clear := get_world_space().intersect_ray(sound_ray).is_empty()
		var hearing_reach := float(stimulus.get("hearing_reach",stimulus.reach))*PERCEIVE*(1.0 if clear else 0.35)
		var carry := clampf(1.0-Vector2(from.x,from.z).distance_to(event_at)/hearing_reach,0,1) if hearing_reach>0 else 0.0
		var aftermath := str(stimulus.get("actor",stimulus.source)).is_empty()
		var sensor := {"seen":seen_event,"seen_event":seen_event,"seen_actor":seen_actor,
			"seen_subject":seen_subject,"seen_source":seen_emitter,"heard":carry>0,"carry":carry,
			"gain":0.7 if seen_event else carry,"tick":People.tick(v),"occurred_tick":int(stimulus.get("tick",People.tick(v))),
			"captured_tick":People.tick(v),"due":People.tick(v),"aftermath":aftermath,
			"recognized_actor":_recognized(str(stimulus.get("actor",stimulus.source)),alleged,observer),
			"recognized_subject":_recognized(str(stimulus.get("subject",stimulus.target)),subject,observer),
			"recognized_emitter":_recognized(str(stimulus.source),emitter,observer),
			"subject_identity":appearance(str(stimulus.get("subject",stimulus.target))) if seen_subject else {"key":"unknown","name":"someone"},
			"emitter_identity":appearance(str(stimulus.source)) if seen_emitter else {"key":"unknown","name":"someone"}}
		for pair: Array in [["actor_at",alleged],["subject_at",subject],["emitter_at",emitter]]:
			var node: Node3D=pair[1]
			if node!=null:sensor[pair[0]]=[node.global_position.x,node.global_position.z]
		if aftermath and seen_event:sensor.candidates=_candidates(observer,rows,from,body.global_rotation.y,event_at,exclude)
		var a := Perception.account(observer,stimulus,sensor,appearance(str(stimulus.get("actor",stimulus.source))),str(stimulus.deed)+":"+observer)
		if not a.is_empty():
			var due := int(a.captured_tick)+People.attention_delay(v,observer,a,modifier_folders)
			a.due=due
			for facet: Dictionary in a.facets.values():facet.due=due
			a.notice_quality=(1 if seen_event else 0)+(2 if seen_event and seen_actor else 0)+(4 if seen_subject else 0)+(8 if seen_emitter else 0)+(16 if observer==str(stimulus.target) else 0)+(32 if carry>0 else 0)
			a.event_ref=str(stimulus.get("event_ref",Actions.incident(str(stimulus.deed))))
			a.notice_id=str(stimulus.get("notice_id",stimulus.deed))
			a.cause_id=str(stimulus.get("cause_id",stimulus.deed))
			a.affordances={"water":Water.resolve(res,Vector2(from.x,from.z),id)} if observer==str(stimulus.target) and str(stimulus.kind) in ["fire","burning"] else {}
			out.append(a)
	accounts_built+=out.size()
	sense_usec.append(Time.get_ticks_usec()-started)
	if sense_usec.size()>128:
		sense_usec.pop_front()
	return out
func get_world_space() -> PhysicsDirectSpaceState3D:
	return res.get_world_3d().direct_space_state
func at(actor: Variant,id: int) -> Vector2:
	if actor is Vector2:
		return actor
	if actor is Array and actor.size()==2:
		return Vector2(float(actor[0]),float(actor[1]))
	var v=VillageSession.village
	if str(actor)=="home" and id>=0:
		return res.place(res._who_of(v,id).home)
	if str(actor).begins_with("water:"):
		return Water.point(res,str(actor),at(People.key(v,id),-1) if id>=0 else Vector2.INF,id)
	var other := People.resident(v,str(actor))
	if other>=0 and res.bodies.has(other):
		return res._movers[other].pos
	if _actors.has(str(actor)) and is_instance_valid(_actors[str(actor)]):
		var body: Node3D=_actors[str(actor)]
		return Vector2(body.global_position.x,body.global_position.z)
	for row: Dictionary in res._crowd.nearby.rows:
		if str(row.key)==str(actor):
			return row.at
	return Vector2.INF
func affordance(actor: String,kind: String) -> Dictionary:
	return Water.resolve(res,at(actor,-1),People.resident(VillageSession.village,actor)) if kind=="water" else {}
func announce(emitter: String,fields: Dictionary) -> bool:
	if not available():
		return false
	var v=VillageSession.village
	var cause := str(fields.get("deed",fields.get("cause_id","")))
	var subject := str(fields.get("subject",emitter))
	var id := People.resident(v,subject)
	if not v.people_facts.has(cause) or id<0 or emitter!=subject:
		return false
	var fact_id := str(fields.get("fact_id",""))
	var fact: Dictionary=v.people[id].body_facts.get(fact_id,{})
	var revision := int(fields.get("revision",fact.get("revision",0)))
	if fact.is_empty() or str(fact.get("deed",""))!=cause or int(fact.get("revision",0))!=revision:
		return false
	var kind := str(fields.get("kind",""))
	var source := _notice_source(kind)
	if source.is_empty() or fact_id not in source.declaration.facts:return false
	var posture := str(source.declaration.posture)
	if not posture.is_empty() and (not res._movers.has(id) or not res._movers[id].can_posture(posture)):return false
	if source.declaration.transition and not bool(fields.get("transition",false)):
		return false # Reloading a fact is not a newly begun physical transition.
	var point := at(subject,-1)
	if point==Vector2.INF:
		return false
	var record: Dictionary=res.stimuli.make(kind,emitter,subject,[point.x,point.y],fact,str(source.folder))
	if record.is_empty():
		return false
	record.actor="" # Condition evidence never reveals an aggressor through its cause.
	var notice := "notice:"+(cause+"|"+subject+"|"+kind+"|"+str(revision)).sha256_text().substr(0,32)
	if fields.has("notice_id") and str(fields.notice_id)!=notice:
		return false
	record.merge({"deed":cause,"cause_id":str(fact.get("cause_id",cause)),"notice_id":notice,"event_ref":Actions.incident(cause),"revision":revision,"tick":People.tick(v)},true)
	_pending_notices.append({"record":record,"notice":notice,"fact_id":fact_id,"revision":revision,"subject":subject,"kind":kind})
	if not _flush_queued:
		_flush_queued=true
		_flush_notices.call_deferred()   # this frame's notices are chosen together, at its end
	return true
## This frame's condition notices: each observer takes in its own, then up to SATURATE more by salience, the rest as
## one summary; only the chosen pairs are observed.
func _flush_notices() -> void:
	_flush_queued=false
	var jobs := _pending_notices
	_pending_notices=[]
	var v=VillageSession.village
	if v==null or not available():
		return
	var wants := {}      # observer -> [[salience, job index]]
	for j in jobs.size():
		for o: Dictionary in _observers(jobs[j].record):
			(wants.get_or_add(str(o.key),[]) as Array).append([_salience(o,str(jobs[j].subject),str(jobs[j].kind)),j])
	var chosen := {}     # job index -> {observer: true}
	var left := {}       # observer -> [job index]
	for observer: String in wants:
		var list: Array=wants[observer]
		list.sort_custom(func(x: Array,y: Array)->bool:return _before(x[0],y[0]))
		var b := _burst_of(observer)
		for item: Array in list:
			if int(item[0][0])==1 or int(b.taken)<SATURATE:
				(chosen.get_or_add(item[1],{}) as Dictionary)[observer]=true
				if int(item[0][0])==0:b.taken=int(b.taken)+1
			else:
				(left.get_or_add(observer,[]) as Array).append(item[1])
	saturation.notices+=jobs.size()
	for j: int in chosen:
		var job: Dictionary=jobs[j]
		if not DEFER:
			_notice_accounts(job,observe(job.record,chosen[j]))
			continue
		var own := {}        # the subject's own condition: at once; onlookers through the think budget
		for observer: String in chosen[j]:
			if observer==str(job.subject):own[observer]=true
			else:_see_later(observer,job.record,func(found: Array)->void:_notice_accounts(job,found,true))
		if not own.is_empty():_notice_accounts(job,observe(job.record,own))
	for observer: String in left:
		var b := _burst_of(observer)
		if bool(b.summary):continue
		b.summary=true
		var gravest: Dictionary=jobs[left[observer][0]]    # sorted: the first left out is the gravest
		var job := gravest.duplicate()
		var summarize := func(accounts: Array) -> void:
			if not accounts.is_empty():
				job.notice=str(accounts[0].notice_id)
				job.record=gravest.record.duplicate(true)
				job.summary=true
				_notice_accounts(job,accounts,true)
		if DEFER:_see_later(observer,_summary_record(gravest.record,observer,left[observer].size()),summarize)
		else:summarize.call(_summary(gravest.record,observer,left[observer].size()))
## `late`: an onlooker sensed through the think budget after the notice's record may already be published: learned,
## and the record published again only if no batch has taken this notice in yet.
func _notice_accounts(job: Dictionary,found: Array,late := false) -> void:
	var v=VillageSession.village
	var notice: String=job.notice
	var observed: Dictionary=v.people_notices.get(notice,{}).get("quality",{}).duplicate()
	if notices.has(notice):
		for a: Dictionary in notices[notice].accounts:
			observed[str(a.observer)]=int(observed.get(str(a.observer),0)) | int(a.get("notice_quality",0))
	var accounts: Array=found.filter(func(a: Dictionary)->bool:return (int(a.get("notice_quality",0)) & ~int(observed.get(str(a.observer),0)))!=0)
	saturation.observed+=accounts.size()
	if not accounts.is_empty():
		if not notices.has(notice):
			notices[notice]={"record":job.record,"accounts":[],"fact_id":job.fact_id,"revision":job.revision}
		notices[notice].accounts.append_array(accounts)
		if job.get("summary",false) or (late and v.people_notices.has(notice)):
			notices[notice].continued=true      # a summary is learned, never published again as a new event
		else:
			notices[notice].erase("continued") # new witnesses: the record is published again, as for a new row
func _locations() -> Dictionary:
	var out := {}
	var v=VillageSession.village
	for id: int in res.bodies:
		var point: Vector2=res._movers[id].pos
		out[People.key(v,id)]=[point.x,point.y]
	return out
## Source NOTICE declarations supply condition policy; no central kind/fact mapping.
func _notice_source(kind: String) -> Dictionary:
	for folder: String in source_folders:
		var declaration: Dictionary=res.stimuli.notice(kind,folder)
		if not declaration.is_empty():return {"folder":folder,"declaration":declaration}
	return {}
## Rebuild only on load/replacement, checked publication or an owner's semantic change.
## Mind extends People.next_due for its accepted work. No saved wake/presentation frames.
func semantic_changed() -> void:
	var v=VillageSession.village
	_scheduled_village=v
	_scheduled_writes=Accept.writes
	schedule_scans+=1
	_wake_tick=mini(Actions.next_due(v),People.next_due(v))
	_conditions=[]
	for folder: String in source_folders:
		for kind: String in Modules.discover(folder):
			var declaration: Dictionary=res.stimuli.notice(kind,folder)
			if declaration.is_empty() or not declaration.persistent:continue
			for id: int in res.bodies:
				for fact_id: String in declaration.facts:
					if v.people[id].body_facts.has(fact_id):
						_conditions.append({"id":id,"kind":kind,"fact_id":fact_id})
	_scan_at=People.tick(v)+1500 if not _conditions.is_empty() else 9223372036854775807
func _ensure_schedule() -> void:
	if _scheduled_village!=VillageSession.village or _scheduled_writes!=Accept.writes:semantic_changed()
func _discover_conditions() -> void:
	var v=VillageSession.village
	if People.tick(v)<_scan_at:
		return
	_scan_at=People.tick(v)+1500
	for row: Dictionary in _conditions:
		var id: int=row.id
		if not res.bodies.has(id):continue
		var fact: Dictionary=v.people[id].body_facts.get(str(row.fact_id),{})
		if not fact.is_empty():
			announce(People.key(v,id),{"kind":row.kind,"subject":People.key(v,id),
				"deed":fact.deed,"fact_id":row.fact_id,"revision":fact.revision})
## A near body's expression, for Body's sense beat to bind (desk 6 Oct, the seam: Body's Think beat asks, at its own
## cadence, and rebinds within one beat when the hints change; the bridge no longer works every near body out every
## frame). {} when the resident is not near the player, not live, or has no mind yet.
func expression_for(id: int) -> Dictionary:
	var v=VillageSession.village
	if v==null or not available() or not res.bodies.has(id) or id<0 or id>=v.people.size() or not v.people[id].alive or not v.people[id].present:
		return {}
	if player==null or res._movers[id].pos.distance_to(Vector2(player.global_position.x,player.global_position.z))>=14:
		return {}
	return People.expression(v,People.key(v,id))
func _process(dt: float) -> void:
	if not available():
		return
	var v=VillageSession.village
	_ensure_schedule()
	_discover_conditions()
	for id: int in res.bodies:
		if not v.people[id].alive or not v.people[id].present:
			if runners.has(id):
				runners[id].runner.stop()
				runners.erase(id)
			continue
		var plan: Dictionary=v.people[id].mind.plan
		if plan.is_empty():
			if runners.has(id):
				runners[id].runner.stop()
				runners.erase(id)
				res.release_to_day(id,"choice")
			continue
		if int(plan.until)<=People.tick(v) or int(plan.phase)>=plan.steps.size():
			phase_requests[id]={"deed":plan.deed,"generation":plan.generation,"phase":plan.steps.size()}
			continue
		if not runners.has(id) or int(runners[id].generation)!=int(plan.generation):
			if runners.has(id):
				runners[id].runner.stop()
			var actor := People.key(v,id)
			var port := {"actor":actor,"body":res.bodies[id],"mover":res._movers[id],
				"at":func(target: Variant)->Vector2:return at(target,id),"route":res._world.route,
				"affordance":func(kind: String)->Dictionary:return affordance(actor,kind),
				"use":func(step: Dictionary)->bool:return _use(id,step),
				"say":func(text: String)->bool:return _say(id,text),
				"report":func(target: String,a: Dictionary)->bool:return _report(id,target,a)}
			var world := {"port":port,"current":func()->int:return int(VillageSession.village.people[id].mind.plan.get("phase",9999)),
				"phase":func(next: int)->void:phase_requests[id]={"deed":plan.deed,"generation":plan.generation,"phase":next}}
			runners[id]={"deed":plan.deed,"offer":plan.offer,"generation":plan.generation,"runner":Performer.new(actor,res._movers[id],res.bodies[id],plan.steps,world)}
		refresh_steps(id,plan)
		res.owners.claim(id,"choice",4,Callable(),true,true)
		if res.owners.held(id,"choice") and res._movers[id].can_move():
			res._drop_stay(id)
			runners[id].runner.update(dt)
	if People.tick(v)>=_retry_at:
		_flush()
func refresh_steps(id: int,plan: Dictionary) -> bool:
	if not runners.has(id) or int(runners[id].generation)!=int(plan.get("generation",-1)) or str(runners[id].deed)!=str(plan.get("deed","")):
		return false
	runners[id].runner.steps=plan.steps
	return true
func _say(id: int,text: String) -> bool:
	var tick := People.tick(VillageSession.village)
	# Queue a line through the existing speech owner; a world-wide timer must not stall travel.
	var okay: bool=res.speech.say(res.bodies[id],text,Speech.SCENE,0,res.voice_of(id),3.0)
	if okay:
		log.append(["say",id,text,tick])
	return okay
func _report(id: int,target: String,a: Dictionary) -> bool:
	var v=VillageSession.village
	var helper := People.resident(v,target)
	if helper<0 or not res.bodies.has(helper) or res._movers[id].pos.distance_to(res._movers[helper].pos)>2.8:
		return false
	var key := "report:"+(str(a.deed)+"|"+People.key(v,id)+"|"+target).sha256_text().substr(0,32)
	if v.people_facts.has(key):
		return true
	if not reports.has(key):
		reports[key]={"speaker":id,"target":helper,"account":Perception.retell(a,str(appearance(People.key(v,id)).key),target,People.tick(v))}
	return false
func _use(id: int,step: Dictionary) -> bool:
	var v=VillageSession.village
	var plan: Dictionary=v.people[id].mind.plan
	var key := "use:"+(str(plan.get("deed",""))+"|"+People.key(v,id)+"|"+str(plan.get("generation",0))+"|"+str(plan.get("phase",0))).sha256_text().substr(0,32)
	if v.people_facts.has(key):
		return true
	uses[key]={"actor":People.key(v,id),"step":step.duplicate(true),"generation":int(plan.get("generation",0))}
	return false
## The aftermath saturated (desk 6 Oct, after Mind's reading check: a star's help rows built ~1,100 accounts in the
## windows after it). Each observer takes in a help row on themselves (helper or helped) always, then up to SATURATE
## others' per burst by the same salience (a tie to the helped or the helper, then the nearest); the rest of the burst's
## help rows come as one summary account of their own ("many were helped", the count), kept apart from the harm summary
## so a rescue is never read as a fall. Only the chosen pairs are observed.
func _observe_uses(fresh: Array) -> void:
	var wants := {}      # observer -> [[salience, row index]]
	for j in fresh.size():
		var record: Dictionary=fresh[j][1].record
		for o: Dictionary in _observers(record):
			var by_target := _salience(o,str(record.get("subject",record.get("target",""))),"help")
			var by_actor := _salience(o,str(record.get("actor",record.get("source",""))),"help")
			(wants.get_or_add(str(o.key),[]) as Array).append([by_target if _before(by_target,by_actor) else by_actor,j])
	var chosen := {}     # row index -> {observer: true}
	var left := {}       # observer -> [row index]
	for observer: String in wants:
		var list: Array=wants[observer]
		list.sort_custom(func(x: Array,y: Array)->bool:return _before(x[0],y[0]))
		var b := _burst_of(observer)
		for item: Array in list:
			if int(item[0][0])==1 or int(b.get("aid_taken",0))<SATURATE:
				(chosen.get_or_add(item[1],{}) as Dictionary)[observer]=true
				if int(item[0][0])==0:b.aid_taken=int(b.get("aid_taken",0))+1
			else:
				(left.get_or_add(observer,[]) as Array).append(item[1])
	var into := func(found: Array) -> void: witnesses.append_array(found)
	for j: int in chosen:
		var record: Dictionary=fresh[j][1].record
		if not DEFER:
			fresh[j][1].accounts.append_array(observe(record,chosen[j]))
			continue
		var own := {}         # the helper and the helped: in the help's own batch; onlookers through the think budget
		for observer: String in chosen[j]:
			if observer==str(record.get("subject",record.get("target",""))) or observer==str(record.get("actor",record.get("source",""))):own[observer]=true
			else:_see_later(observer,record,into)
		if not own.is_empty():fresh[j][1].accounts.append_array(observe(record,own))
	for observer: String in left:
		var b := _burst_of(observer)
		if bool(b.get("aid_summary",false)):continue
		b.aid_summary=true
		var first: int=left[observer][0]
		if DEFER:_see_later(observer,_summary_record(fresh[first][1].record,observer,left[observer].size()),into)
		else:fresh[first][1].accounts.append_array(_summary(fresh[first][1].record,observer,left[observer].size()))
func _queued() -> Dictionary:
	var v=VillageSession.village
	var told := reports.duplicate(true)
	var physical := []
	var fresh := []      # this batch's new help rows, observed together below (saturated per observer)
	for key: String in uses.keys():
		if v.people_facts.has(key):
			uses.erase(key)
			continue
		var row: Dictionary=uses[key]
		if row.has("measured"):
			var retained: Dictionary=row.measured.duplicate(true)
			retained.request.logical_time=v.runtime.now
			physical.append(retained)
			continue
		var id := People.resident(v,str(row.actor))
		var target := str(row.step.get("target",row.actor))
		var point := at(target,-1)
		var origin := at(row.actor,-1)
		if id<0 or int(v.people[id].mind.plan.get("generation",-1))!=int(row.generation) or point==Vector2.INF or origin==Vector2.INF:
			uses.erase(key)
			continue
		var params: Dictionary=row.step.duplicate(true)
		var record: Dictionary=res.stimuli.make("help",row.actor,target,[point.x,point.y],params)
		record.merge({"deed":key,"cause_id":key,"notice_id":key,"event_ref":Actions.incident(key),"tick":People.tick(v)},true)
		var measured := {"request":{"action_id":key,"actor":row.actor,"target":target,"verb":str(params.get("verb","extinguish")),
			"parameters":params,"village_id":v.runtime.village,"logical_time":v.runtime.now},
			"context":{"authorized":true,"distance_dm":ceili(point.distance_to(origin)*10),"at":[point.x,point.y],"from":[origin.x,origin.y],
				"defer_accounts":true,"water_contact":Water.contact(res,origin,point,str(params.get("affordance","")))},
			"record":record,"accounts":[]}
		fresh.append([key,measured])
	if not fresh.is_empty():
		_observe_uses(fresh)
		for item: Array in fresh:
			uses[item[0]].measured=item[1].duplicate(true)
			physical.append(item[1])
	return {"phases":phase_requests.duplicate(true),"reports":told,"notices":notices.duplicate(true),"uses":physical}
## 5 Oct (sustained play): one learn budget per checked batch, shared by every source of accounts: the oldest due
## memories first (People.ready, saved in each witness's pending), then the act's own witnesses, notices, reports
## and uses, which Mind admits whole and learns only within what is left (Mind M6: the rest wait saved as due-now
## pending). A witness's portions stay together; the first witness always learns. quiesce (every save, autosave
## included) admits everything waiting but learns within the same budget.
## Measured on the sustained session: a learn in a crowded village costs Mind 2.5-3 ms; a batch admitting 24-28
## accounts and learning 4 measured 28-40 ms (9c367fe), and an autosave that learned a 34-memory backlog 59 ms.
const BATCH_LEARNS := 3
var _more_ready := false
func _ready_now(candidate,limit: int) -> Array:
	var ready: Array=People.ready(candidate)
	if limit<0:
		return ready
	var count := {}
	for a: Dictionary in ready:
		count[str(a.observer)]=int(count.get(str(a.observer),0))+1
	var chosen := {}
	var taken := 0
	var out := []
	for a: Dictionary in ready:
		var who := str(a.observer)
		if not chosen.has(who):
			if not chosen.is_empty() and taken+int(count[who])>limit:
				continue
			chosen[who]=true
			taken+=int(count[who])
		out.append(a)
	return out
## 5 Oct: a notice seen by a crowd admits at most NOTICE_ACCOUNTS witness accounts per frame's batch (Mind admits
## one in about 0.2 ms, and each admitted witness's mind is saved: a 111-witness notice measured 25 ms in one batch). The admitted part is a prefix ending at
## a witness boundary; the rest stays queued for the next frame and the record is published once, with the first
## part. An act's own witnesses beyond the share wait the same way (`witnesses`). quiesce admits everything.
const NOTICE_ACCOUNTS := 12
func _trim_notices(queued: Dictionary) -> bool:
	var room := NOTICE_ACCOUNTS
	var rest := false
	for key: String in queued.notices.keys():
		var row: Dictionary=queued.notices[key]
		var n := 0
		var last := ""
		while n<row.accounts.size():
			var who := str(row.accounts[n].observer)
			if who!=last and room<=0:
				break
			last=who
			room-=1
			n+=1
		if n<row.accounts.size():
			rest=true
			if n==0:
				queued.notices.erase(key) # all of it waits
				continue
			row.accounts=row.accounts.slice(0,n)
			row.rest=true
	return rest
## The first `room` (NOTICE_ACCOUNTS) of a list of witness accounts, ending at a witness boundary (the first witness
## always fits, whatever its size).
func _witness_chunk(accounts: Array,room := NOTICE_ACCOUNTS) -> int:
	var n := 0
	var last := ""
	while n<accounts.size():
		var who := str(accounts[n].observer)
		if who!=last and n>=maxi(room,0) and n>0:
			break
		last=who
		n+=1
	return n
## `first`: the accounts of the people an act touched, learned ahead of everything else in its own batch.
func _apply_queued(candidate,queued: Dictionary,extra: Array,limit := BATCH_LEARNS,first: Array = []) -> bool:
	var accounts := first.duplicate()
	accounts.append_array(_ready_now(candidate,limit))
	var changed := not accounts.is_empty() or not extra.is_empty()
	accounts.append_array(extra)
	for row: Dictionary in queued.uses:
		var answer := Actions.prepare(candidate,row.request,row.context)
		if answer.get("accepted",false) and not answer.get("duplicate",false):
			accounts.append_array(row.accounts)
			changed=true
	for id: int in queued.phases:
		VillageImage.touch(id)
		var plan: Dictionary=candidate.people[id].mind.plan
		var phase: Dictionary=queued.phases[id]
		if not plan.is_empty() and str(plan.deed)==str(phase.deed) and int(plan.generation)==int(phase.generation):
			if int(phase.phase)>=plan.steps.size() or int(plan.until)<=People.tick(candidate):
				candidate.people[id].mind.plan={}
			else:
				plan.phase=int(phase.phase)
			changed=true
	for key: String in queued.notices:
		var row: Dictionary=queued.notices[key]
		var record: Dictionary=row.record
		var observers: Array=candidate.people_notices.get(key,{}).get("observers",[]).duplicate()
		var quality: Dictionary=candidate.people_notices.get(key,{}).get("quality",{}).duplicate()
		for a: Dictionary in row.accounts:
			if not observers.has(str(a.observer)):
				observers.append(str(a.observer))
			quality[str(a.observer)]=int(quality.get(str(a.observer),0)) | int(a.get("notice_quality",0))
		VillageImage.touch_key("people_notices",key)
		candidate.people_notices[key]={"deed":record.deed,"cause_id":record.get("cause_id",record.deed),"kind":record.kind,"subject":record.subject,
			"fact_id":row.fact_id,"revision":row.revision,"tick":People.tick(candidate),"observers":observers,"quality":quality}
		accounts.append_array(row.accounts)
		changed=changed or not row.accounts.is_empty()
	for key: String in queued.reports:
		if candidate.people_facts.has(key):
			continue
		var row: Dictionary=queued.reports[key]
		var a: Dictionary=row.account.duplicate(true)
		VillageImage.touch_key("people_facts",key)
		candidate.people_facts[key]={"speaker":People.key(candidate,int(row.speaker)),"tick":People.tick(candidate),"receipt":{"accepted":true}}
		accounts.append(a)
		changed=true
	if not accounts.is_empty():
		for a: Dictionary in accounts:
			VillageImage.touch_actor(candidate,str(a.observer))
			VillageImage.touch_fact(candidate,str(a.observer),str(a.deed)+":"+str(a.observer))
		People.flush(candidate,accounts,limit)
	_more_ready=limit>=0 and not People.ready(candidate).is_empty()
	return changed
func _published(queued: Dictionary) -> void:
	_publishing=true
	var v=VillageSession.village
	for id: int in queued.phases:
		phase_requests.erase(id)
	for key: String in queued.reports:
		if v.people_facts.has(key):
			reports.erase(key)
			log.append(["report",key,People.tick(v)])
	for key: String in queued.notices:
		var row: Dictionary=queued.notices[key]
		if row.get("rest",false) and notices.has(key):
			notices[key].accounts=notices[key].accounts.slice(row.accounts.size()) # the witnesses not yet admitted
			notices[key].continued=true
		else:
			notices.erase(key)
		if not row.get("continued",false):
			res.stimuli.publish(row.record)
	for row: Dictionary in queued.uses:
		if v.people_facts.has(str(row.request.action_id)):
			uses.erase(str(row.request.action_id))
			res.stimuli.publish(row.record)
	_publishing=false
	semantic_changed()
## Step 4 (4 Oct): at most one checked save per COALESCE_MS of active time. Ready memories and keyed world effects
## wait at most that long and share one acceptance; behaviour progress alone is not a world effect and advances
## the live plan at once, persisting with the next checked save or autosave. Effectful steps (report, use) keep their
## own keyed facts, so a reload that repeats a walk can never repeat a report or a rescue.
const COALESCE_MS := 100
var _batch_at := 0
func _advance_phases(v) -> void:
	for id: int in phase_requests.keys():
		var plan: Dictionary=v.people[id].mind.plan
		var phase: Dictionary=phase_requests[id]
		if not plan.is_empty() and str(plan.deed)==str(phase.deed) and int(plan.generation)==int(phase.generation):
			if int(phase.phase)>=plan.steps.size() or int(plan.until)<=People.tick(v):
				v.people[id].mind.plan={}
			else:
				plan.phase=int(phase.phase)
			VillageImage.drifted(id)
		phase_requests.erase(id)
	semantic_changed()
func _flush() -> void:
	_ensure_schedule()
	var v=VillageSession.village
	var tick := People.tick(v)
	if tick<_retry_at:return
	if tick<_wake_tick and phase_requests.is_empty() and reports.is_empty() and uses.is_empty() and notices.is_empty() and witnesses.is_empty():return
	var effects := not (reports.is_empty() and uses.is_empty() and notices.is_empty() and witnesses.is_empty())
	if (tick<_wake_tick and not effects) or tick<_batch_at:
		if not phase_requests.is_empty():_advance_phases(v)
		return
	_batch_at=tick+COALESCE_MS
	var due := Actions.next_due(v)<=People.tick(v)
	var queued := _queued()
	var split := _trim_notices(queued)
	var share := _witness_chunk(witnesses)
	var own: Array=witnesses.slice(0,share)
	split=split or share<witnesses.size()
	var result := Accept.transact(func(candidate)->Dictionary:
		VillageImage.hinting()
		if due:
			Actions.advance(candidate,_locations())
		var changed := _apply_queued(candidate,queued,own)
		return {"accepted":changed or due,"reason":"no ready change" if not changed and not due else ""},_writer)
	if result.get("accepted",false):
		_published(queued)
		witnesses=witnesses.slice(share)
		if _more_ready or split:
			_batch_at=tick # the witnesses left waiting learn in the next frame's batch
	else:
		_retry_at=People.tick(v)+500
## Autosave/exit/background owner calls before disposal. Future captures stay saved pending.
## Failure retains all queues; a controlled exit refuses. No presentation positions saved routinely.
func quiesce() -> Dictionary:
	if _publishing:return {"accepted":false,"reason":"notification acceptance"}
	if not _contact_captures.is_empty():return {"accepted":false,"reason":"pending failed contact"}
	while not _pending_notices.is_empty():
		_flush_notices()  # notices still waiting their slice are chosen now
	_see_now()          # onlookers still waiting their turn sense now, so the save holds what they took in
	var queued := _queued()
	var waiting := witnesses.duplicate()
	var locations := _locations()
	var result := Accept.transact(func(candidate)->Dictionary:
		VillageImage.hinting()
		Actions.advance(candidate,locations)
		_apply_queued(candidate,queued,waiting) # every waiting account admitted; learning within the budget (the rest is saved due-now pending)
		for id: int in res.bodies:
			var p=candidate.people[id]
			if not p.body_facts.has("carried"):continue
			VillageImage.touch_person(id)
			var at: Array=locations.get(People.key(candidate,id),[])
			if at.size()!=2:continue
			var carried: Dictionary=p.body_facts.carried
			carried.at=at.duplicate()
			var old: Dictionary=p.body_facts.get("location",{})
			if old.get("at",[])!=at or str(old.get("deed",""))!=str(carried.deed):Actions.fact(candidate,p,"location",str(carried.deed),{"at":at.duplicate()})
		return {"accepted":true},_writer)
	if result.get("accepted",false):
		_published(queued)
		witnesses=witnesses.slice(waiting.size())
	return result
func _exit_tree() -> void:
	for run: Dictionary in runners.values():
		run.runner.stop()
	runners.clear()
