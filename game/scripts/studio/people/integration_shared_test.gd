extends RefCounted
## Integration-owned narrow checks: real consequence/save owners, no body/animation substitute.
const F := preload("res://scripts/studio/people/foundation_state_test.gd")
const People := preload("res://scripts/studio/village/sim/people.gd")
const Actions := preload("res://scripts/studio/village/sim/people_actions.gd")
const Accept := preload("res://scripts/studio/village/acceptance.gd")
const Codec := preload("res://scripts/studio/village/sim/save.gd")
const Stimuli := preload("res://scripts/studio/people/stimuli.gd")
const Bridge := preload("res://scripts/studio/village/people_bridge.gd")
const PlayerActs := preload("res://scripts/studio/village/player_acts.gd")
const Water := preload("res://scripts/studio/village/water.gd")
class NoticeRegistry extends Node3D:
	var bodies := {}
	var _movers := {}
	var _crowd := {"nearby":preload("res://scripts/studio/people/nearby.gd").new()}
	var stimuli := Stimuli.new()
	var feedback_count := 0
	func play_contact(_id: int,_receipt: Dictionary) -> void:
		feedback_count+=1 # Publication count only; actual Body presentation has its own checks.
	func focus(_place: String) -> Vector2:
		return Vector2.INF # This proof exercises sensing, with no water place in its scene.
static func _request(v,id: int,key: String,verb: String,parameters: Dictionary = {}) -> Dictionary:
	return {"action_id":key,"actor":"actor:measured","target":People.key(v,id),"verb":verb,
		"village_id":v.runtime.village,"logical_time":v.runtime.now,"parameters":parameters}
static func _context() -> Dictionary:
	return {"authorized":true,"distance_dm":10,"at":[4.0,25.0],"from":[3.0,25.0],"defer_accounts":true}
static func report() -> PackedStringArray:
	var out := PackedStringArray()
	out.append(("PASS" if _retained_runner_proof() else "FAIL")+" richer accepted report reaches the retained live runner without replaying speech or frozen receipts")
	var v=F.fixture()
	var id := F.adult(v)
	v.people[id].locked=false
	v.people[id].authored=""
	var request := _request(v,id,"deed:force","strike",{"damage":1,"force":850})
	var answer := Actions.prepare(v,request,_context())
	out.append(("PASS" if answer.accepted and v.people[id].hurt==14 and Actions.down(v,v.people[id]) and v.people[id].body_facts.down.deed==request.action_id else "FAIL")+" force causes sourced down independently of existing injury")
	var logged=v.events[-1]
	out.append(("PASS" if logged.who==-1 and logged.other==-1 and not str(answer.event_ref).contains("actor:measured") else "FAIL")+" event reference and public root event expose no actor truth")
	var before_hurt: int=v.people[id].hurt
	var replay := Actions.prepare(v,request,_context())
	out.append(("PASS" if replay.duplicate and v.people[id].hurt==before_hurt else "FAIL")+" accepted physical root replays without injury")
	v.runtime.now+=12
	Actions.advance(v)
	out.append(("PASS" if not v.people[id].body_facts.has("down") else "FAIL")+" active semantic recovery removes down without a pose frame")
	var fall := _request(v,id,"deed:fall","fall",{"force":400})
	fall.actor=fall.target
	var context := _context()
	var refused := Actions.prepare(v,fall,context)
	context.measured_incident=true
	var fallen := Actions.prepare(v,fall,context)
	out.append(("PASS" if not refused.accepted and fallen.accepted and v.people[id].body_facts.down.deed==fall.action_id else "FAIL")+" independent fall requires its own measured checked root")
	var fire=F.fixture()
	var burned := F.adult(fire)
	fire.people[burned].authored=""
	fire.people[burned].locked=true
	var ignition := _request(fire,burned,"deed:fire","burn",{"heat":750})
	var burning := Actions.prepare(fire,ignition,_context())
	fire.runtime.now+=8
	Actions.advance(fire)
	var injury: int=fire.people[burned].hurt
	var help := _request(fire,burned,"deed:help","extinguish",{"method":"water","cause_id":ignition.action_id})
	var dry := Actions.prepare(fire,help,_context())
	var wet_context := _context()
	wet_context.water_contact=true
	var wet := Actions.prepare(fire,help,wet_context)
	out.append(("PASS" if burning.accepted and injury==30 and not dry.accepted and wet.accepted and not fire.people[burned].body_facts.has("burning") else "FAIL")+" held bodies receive fire and real checked water ends continuing exposure")
	var restored=Codec.from_data(Codec.to_data(fire,false))
	out.append(("PASS" if restored!=null and restored.people[burned].hurt==injury and restored.people[burned].body_facts.doused.cause_id==ignition.action_id and restored.people_facts.has(help.action_id) else "FAIL")+" cause, accepted help and injury survive reflective save codec")
	var doomed=F.fixture()
	var dead := F.adult(doomed)
	doomed.people[dead].authored=""
	Actions.prepare(doomed,_request(doomed,dead,"deed:neglected","burn",{"heat":750}),_context())
	doomed.runtime.now+=28
	Actions.advance(doomed)
	out.append(("PASS" if not doomed.people[dead].alive and doomed.people[dead].body_facts.dead.deed=="deed:neglected" and not doomed.people[dead].body_facts.has("burning") else "FAIL")+" neglected exposure reuses real rule death with persistent causal corpse")
	var sources := Stimuli.new()
	var proof := sources.make("footfall","actor:any",People.key(v,id),[0.0,0.0],{},"res://scripts/studio/people/proofs/sources/")
	var notice := sources.make("burning",People.key(v,id),People.key(v,id),[0.0,0.0],{"strength":750})
	out.append(("PASS" if proof.kind=="footfall" and proof.actor=="actor:any" and notice.actor=="" and notice.source==People.key(v,id) else "FAIL")+" normal one-file discovery preserves emitter and anonymous condition roles")
	var previous=VillageSession.village
	var coins := Money.coins
	VillageSession.village=v
	var wrote := [0]
	var failed := Accept.transact(func(candidate)->Dictionary:
		candidate.people_facts["proof:checked"]={"receipt":{"accepted":true}}
		return {"accepted":true,"costs":[]},func()->int:wrote[0]+=1;return ERR_CANT_CREATE)
	var failure_held: bool=not failed.accepted and not VillageSession.village.people_facts.has("proof:checked")
	var success := Accept.transact(func(candidate)->Dictionary:
		candidate.people_facts["proof:checked"]={"receipt":{"accepted":true}}
		return {"accepted":true,"costs":[]},func()->int:wrote[0]+=1;return OK)
	var saved := Codec.from_data(Codec.to_data(VillageSession.village,false))
	var duplicate := Accept.transact(func(_candidate)->Dictionary:return {"accepted":true,"duplicate":true},func()->int:wrote[0]+=1;return OK)
	out.append(("PASS" if failure_held and success.accepted and duplicate.duplicate and wrote[0]==2 and saved.people_facts.has("proof:checked") and Money.coins==coins else "FAIL")+" failed save rolls back; checked retry persists once; replay does not write")
	VillageSession.village=previous
	out.append(("PASS" if _notice_proof() else "FAIL")+" checked later sight persists one anonymous episode after failure retry and reload")
	out.append_array(_boundary_proof())
	out.append_array(_retry_capture_proof())
	out.append_array(_park_and_sweep_proof())
	var injured := sources.make("injured","actor:sufferer","actor:sufferer",[0.0,0.0],{"strength":140})
	out.append(("PASS" if sources.notice("injured").get("persistent",false) and injured.actor=="" and injured.evidence.condition=="injured" and injured.features.felt_harm==140 and injured.hearing_reach==0.0 and notice.features.felt_harm==750 else "FAIL")+" one-file injury and continuing heat declare honest condition features")
	return out
static func _retry_capture_proof() -> PackedStringArray:
	var out := PackedStringArray()
	var tree: SceneTree=Engine.get_main_loop()
	var prior_v=VillageSession.village
	var prior_scene=tree.current_scene
	var flags := [VillageSession.active,VillageSession.background,Controls.locked,SaveGame.paused]
	var v=F.fixture()
	var victim := F.adult(v)
	var witness := -1
	for p in v.people:
		if p.id!=victim and p.alive and p.present:witness=p.id;break
	v.people[victim].locked=false
	v.people[victim].authored=""
	v.people[victim].hurt=0
	v.people[witness].traits[People.C.ALERT]=80
	VillageSession.village=v
	VillageSession.active=true
	VillageSession.background=false
	Controls.locked=false
	SaveGame.paused=false
	var registry := NoticeRegistry.new()
	tree.root.add_child(registry)
	tree.current_scene=registry
	var sufferer := Node3D.new()
	var observer := Node3D.new()
	var actor := Node3D.new()
	registry.add_child(sufferer)
	registry.add_child(observer)
	registry.add_child(actor)
	actor.position=Vector3(1,0,0)
	observer.position=Vector3(5,0,0)
	observer.rotation.y=PI/2
	registry.bodies={victim:sufferer,witness:observer}
	registry._movers={victim:{"pos":Vector2.ZERO},witness:{"pos":Vector2(5,0)}}
	registry._crowd.nearby.snapshot(PackedVector2Array([Vector2.ZERO,Vector2(5,0)]),
		[{"key":People.key(v,victim),"body":sufferer},{"key":People.key(v,witness),"body":observer}])
	var writes := [0]
	var bridge := Bridge.new(registry,func()->int:writes[0]+=1;return ERR_CANT_CREATE if writes[0]==1 else OK)
	registry.add_child(bridge)
	bridge.set_process(false)
	var doer := "actor:captured"
	bridge.register_actor(doer,actor)
	var fields := {"press_id":"proof:first-contact","force":450,"damage":1}
	var failed := bridge.perform(doer,[{"id":victim}],"strike",fields)
	var held: bool=not failed.get("accepted",false) and VillageSession.village.people[victim].hurt==0 and registry.feedback_count==0
	var captured: Dictionary=bridge._contact_captures.get(JSON.stringify([JSON.stringify([doer,str(fields.press_id),"strike"]),People.key(v,victim)]),{})
	var deed: String=str(captured.get("rows",[{}])[0].get("request",{}).get("action_id",""))
	observer.rotation.y=-PI/2 # A later eyewitness must not strengthen the failed original capture.
	v.runtime.now+=4
	var retry := bridge.perform(doer,[{"id":victim}],"strike",{"press_id":fields.press_id,"force":850,"damage":5})
	var loaded=Codec.from_data(Codec.to_data(VillageSession.village,false))
	var canonical := deed+":"+People.key(v,witness)
	var remembered: Dictionary=loaded.people[witness].mind.known.get(canonical,{})
	var replay := bridge.perform(doer,[{"id":victim}],"strike",fields)
	out.append(("PASS" if held and retry.get("accepted",false) and replay.get("duplicate",false) and writes[0]==2 and registry.feedback_count==1 and loaded.people[victim].hurt==14 and remembered.get("via","")=="heard" and remembered.get("identity",{}).get("key","")=="unknown" and bridge._contact_captures.is_empty() else "FAIL")+" failed contact retry saves first measured evidence/force once across a clock change and codec reload")
	bridge.register_actor("actor:other",actor)
	var other := bridge._measure_contacts(VillageSession.village,"actor:other",[{"id":victim}],"strike",fields,{},"actor:other|"+str(fields.press_id)+"|strike")
	var shove := bridge._measure_contacts(VillageSession.village,doer,[{"id":victim}],"shove",fields,{},doer+"|"+str(fields.press_id)+"|shove")
	var other_deed: String=str(other.get("rows",[{}])[0].get("request",{}).get("action_id",""))
	var shove_deed: String=str(shove.get("rows",[{}])[0].get("request",{}).get("action_id",""))
	out.append(("PASS" if not deed.is_empty() and not other_deed.is_empty() and not shove_deed.is_empty() and deed!=other_deed and deed!=shove_deed and other_deed!=shove_deed else "FAIL")+" physical root keys separate actor and semantic verb despite identical input press")
	tree.current_scene=prior_scene
	registry.free()
	VillageSession.village=prior_v
	VillageSession.active=flags[0]
	VillageSession.background=flags[1]
	Controls.locked=flags[2]
	SaveGame.paused=flags[3]
	return out
static func _park_and_sweep_proof() -> PackedStringArray:
	var out := PackedStringArray()
	var tree: SceneTree=Engine.get_main_loop()
	var prior=VillageSession.village
	var scene=tree.current_scene
	var flags := [VillageSession.active,VillageSession.background,Controls.locked,SaveGame.paused]
	var v=F.fixture()
	var ids := []
	for p in v.people:
		if p.alive and p.present and People.Rules.age_of(v,p)>=14:
			p.locked=false;p.authored="";p.hurt=0
			ids.append(p.id)
		if ids.size()==2:break
	if ids.size()!=2:return PackedStringArray(["FAIL sweep fixture needs two physical adults"])
	VillageSession.village=v;VillageSession.active=true;VillageSession.background=false;Controls.locked=false;SaveGame.paused=false
	var registry := NoticeRegistry.new()
	tree.root.add_child(registry);tree.current_scene=registry
	var actor := Node3D.new()
	registry.add_child(actor);actor.position=Vector3(1,0,0)
	for i in ids.size():
		var body := Node3D.new()
		registry.add_child(body);body.position=Vector3(0,0,i)
		registry.bodies[ids[i]]=body;registry._movers[ids[i]]={"pos":Vector2(0,i)}
	registry._crowd.nearby.snapshot(PackedVector2Array([Vector2.ZERO,Vector2(0,1)]),[
		{"key":People.key(v,ids[0]),"body":registry.bodies[ids[0]]},{"key":People.key(v,ids[1]),"body":registry.bodies[ids[1]]}])
	var fail := [true]
	var writes := [0]
	var bridge := Bridge.new(registry,func()->int:writes[0]+=1;return ERR_CANT_CREATE if fail[0] else OK)
	registry.add_child(bridge);bridge.set_process(false);bridge.register_actor("actor:sweep",actor)
	var geometry := {"origin":Vector2(1,0),"reach":8.0}
	var fields := {"press_id":"one-cast","force":400,"heat":500}
	var failed := bridge.perform("actor:sweep",[{"id":ids[0]}],"burn",fields,geometry)
	var refused_exit := bridge.quiesce()
	fail[0]=false
	var next := bridge.perform("actor:sweep",[{"id":ids[1]}],"burn",{"press_id":"one-cast","force":900,"heat":750},geometry)
	var retry := bridge.perform("actor:sweep",[{"id":ids[0]},{"id":ids[1]}],"burn",{"press_id":"one-cast","force":900,"heat":750},geometry)
	v=VillageSession.village
	var a=v.people[ids[0]];var b=v.people[ids[1]]
	out.append(("PASS" if not failed.accepted and not refused_exit.accepted and next.accepted and retry.accepted and v.people_facts.size()==2 and a.hurt==0 and b.hurt==0 and not a.body_facts.has("down") and b.body_facts.down.deed==b.body_facts.burning.deed and a.body_facts.burning.heat==500 and registry.feedback_count==2 else "FAIL")+" changing sweep sets retain first target evidence and burn impulse under one root per cast/subject")
	var account: Dictionary=a.mind.known[str(a.body_facts.burning.deed)+":"+People.key(v,ids[0])]
	bridge._report(ids[0],People.key(v,ids[1]),account)
	var queued: Dictionary=bridge.reports.duplicate(true)
	fail[0]=true
	var park_failed := bridge.quiesce()
	var retained: bool=not park_failed.accepted and bridge.reports==queued
	fail[0]=false
	var before: int = writes[0]
	var parked := bridge.quiesce()
	var restored=Codec.from_data(Codec.to_data(VillageSession.village,false))
	var report_key := str(a.body_facts.burning.deed)+":"+People.key(v,ids[1])
	var pending: Array=restored.people[ids[1]].mind.pending
	var report: Dictionary=restored.people[ids[1]].mind.known.get(report_key,{})
	var provenance: bool=not report.is_empty() and report.facets.values().all(func(f: Dictionary)->bool:return f.via=="told")
	out.append(("PASS" if retained and parked.accepted and writes[0]==before+1 and not pending.is_empty() and provenance and bridge.reports.is_empty() else "FAIL")+" one checked park retains pending attention and downgrades every report facet after save failure")
	var carried := bridge.perform("actor:sweep",[{"id":ids[1]}],"carry",{"press_id":"load"},{"can_carry":true})
	registry._movers[ids[1]].pos=Vector2(9,8)
	registry.bodies[ids[1]].position=Vector3(9,0,8)
	var located := bridge.quiesce()
	restored=Codec.from_data(Codec.to_data(VillageSession.village,false))
	var facts: Dictionary=restored.people[ids[1]].body_facts
	# The reflective codec canonically writes whole-valued coordinates as integers.
	var carried_at: Array=facts.get("carried",{}).get("at",[])
	var saved_at: Array=facts.get("location",{}).get("at",[])
	var same_place: bool=carried_at.size()==2 and saved_at.size()==2 and Vector2(float(carried_at[0]),float(carried_at[1]))==Vector2(9,8) and Vector2(float(saved_at[0]),float(saved_at[1]))==Vector2(9,8)
	if not (carried.accepted and located.accepted and same_place and facts.location.deed==facts.carried.deed):
		print("DIAGNOSTIC carried park ",carried," located=",located," facts=",facts)
	out.append(("PASS" if carried.accepted and located.accepted and same_place and facts.location.deed==facts.carried.deed and facts.carried.carrier=="actor:sweep" else "FAIL")+" checked exit saves actual carried location and carrier cause through the existing codec")
	tree.current_scene=scene;registry.free();VillageSession.village=prior
	VillageSession.active=flags[0];VillageSession.background=flags[1];Controls.locked=flags[2];SaveGame.paused=flags[3]
	return out
static func _retained_runner_proof() -> bool:
	var phase := [0]
	var spoken := []
	var delivered := []
	var old_steps: Array=[{"op":"say","text":"Fetch help"},{"op":"report","target":"actor:helper","account":{"deed":"deed:one","identity":{"key":"unknown"}}}]
	var world := {"current":func()->int:return int(phase[0]),"phase":func(next: int)->void:phase[0]=next,
		"port":{"say":func(text: String)->bool:spoken.append(text);return true,
		"report":func(_target: String,account: Dictionary)->bool:delivered.append(account.duplicate(true));return false}}
	var runner=preload("res://scripts/studio/people/performer.gd").new("actor:witness",null,null,old_steps,world)
	runner.update(0.1)
	var bridge := Bridge.new(null)
	bridge.runners[1]={"deed":"deed:one","generation":2,"runner":runner}
	var frozen := {"speaker":1,"target":2,"account":old_steps[1].account.duplicate(true)}
	bridge.reports["report:arrived"]=frozen.duplicate(true)
	var fresh := old_steps.duplicate(true)
	fresh[0].text="Richer words must not repeat"
	fresh[1].account.identity.key="appearance:masked-stranger"
	var kept := bridge.refresh_steps(1,{"deed":"deed:one","generation":2,"steps":fresh})
	runner.update(0.1)
	var refused := not bridge.refresh_steps(1,{"deed":"deed:other","generation":3,"steps":old_steps})
	var okay: bool=kept and refused and phase[0]==1 and spoken==["Fetch help"] and delivered.size()==1 and delivered[0].identity.key=="appearance:masked-stranger" and bridge.reports["report:arrived"]==frozen and runner.steps==fresh
	bridge.free()
	return okay
static func _notice_proof() -> bool:
	var tree: SceneTree=Engine.get_main_loop()
	var prior_v=VillageSession.village
	var prior_scene=tree.current_scene
	var prior_active: bool=VillageSession.active
	var prior_background: bool=VillageSession.background
	var prior_locked: bool=Controls.locked
	var prior_pause: bool=SaveGame.paused
	var v=F.fixture()
	var victim := F.adult(v)
	var witness := -1
	for p in v.people:
		if p.id!=victim and p.alive and p.present:
			witness=p.id
			break
	if witness<0:
		return false
	v.people[victim].locked=false
	v.people[victim].authored=""
	v.people[witness].traits[People.C.ALERT]=80
	var root := _request(v,victim,"deed:notice-root","burn",{"heat":500})
	Actions.prepare(v,root,_context())
	VillageSession.village=v
	VillageSession.active=true
	VillageSession.background=false
	Controls.locked=false
	SaveGame.paused=false
	var registry := NoticeRegistry.new()
	tree.root.add_child(registry)
	tree.current_scene=registry
	var sufferer := Node3D.new()
	var observer := Node3D.new()
	registry.add_child(sufferer)
	registry.add_child(observer)
	observer.position=Vector3(5,0,0)
	observer.rotation.y=PI/2 # Hearing while facing away; later actually turns toward the condition.
	registry.bodies={victim:sufferer,witness:observer}
	registry._movers={victim:{"pos":Vector2.ZERO},witness:{"pos":Vector2(5,0)}}
	registry._crowd.nearby.snapshot(PackedVector2Array([Vector2.ZERO,Vector2(5,0)]),
		[{"key":People.key(v,victim),"body":sufferer},{"key":People.key(v,witness),"body":observer}])
	var bridge := Bridge.new(registry)
	registry.add_child(bridge)
	bridge.set_process(false)
	var fields := {"kind":"burning","subject":People.key(v,victim),"deed":root.action_id,"fact_id":"burning","revision":1}
	var writes_before := Accept.writes
	bridge.announce(People.key(v,victim),fields)
	var first := bridge._queued()
	v.runtime.now+=4 # Captured attention matures; no later origin measurement.
	var no_recursive_save: bool=Accept.writes==writes_before
	var callback_refused := [false]
	registry.stimuli.accepted_event.connect(func(_record: Dictionary)->void:
		var nested := bridge.accept(func(_candidate)->Dictionary:return {"accepted":true})
		callback_refused[0]=not nested.accepted)
	var accepted := Accept.transact(func(candidate)->Dictionary:
		return {"accepted":bridge._apply_queued(candidate,first,[])},func()->int:return OK)
	if accepted.accepted:
		bridge._published(first)
	var notice_keys: Array=VillageSession.village.people_notices.keys()
	var first_key: String=str(notice_keys[0]) if not notice_keys.is_empty() else ""
	var hurt_before: int=VillageSession.village.people[victim].hurt
	bridge.announce(People.key(v,victim),fields)
	var repeated_empty: bool=bridge.notices.is_empty()
	observer.rotation.y=-PI/2
	bridge.announce(People.key(v,victim),fields)
	var upgraded: bool=bridge.notices.has(first_key) and bridge.notices[first_key].accounts.any(func(a: Dictionary)->bool:return a.observer==People.key(v,witness))
	var privacy := true
	for row: Dictionary in bridge.notices.values():
		for a: Dictionary in row.accounts:
			privacy=privacy and a.identity.key=="unknown" and not a.has("actor") and not a.has("source")
	var second := bridge._queued()
	VillageSession.village.runtime.now+=4
	var failed := Accept.transact(func(candidate)->Dictionary:return {"accepted":bridge._apply_queued(candidate,second,[])},func()->int:return ERR_CANT_CREATE)
	var canonical := str(root.action_id)+":"+People.key(v,witness)
	var old_channel: bool=VillageSession.village.people[witness].mind.known[canonical].via=="heard"
	var checked := Accept.transact(func(candidate)->Dictionary:return {"accepted":bridge._apply_queued(candidate,second,[])},func()->int:return OK)
	if checked.accepted:bridge._published(second)
	var loaded=Codec.from_data(Codec.to_data(VillageSession.village,false))
	var learned: Dictionary=loaded.people[witness].mind.known[canonical]
	var episodes := 0
	for episode in loaded.people[witness].mind.episodes:
		if episode.key==canonical:episodes+=1
	bridge.announce(People.key(v,victim),fields)
	# Seeing current flames adds a condition facet; it cannot upgrade the earlier heard origin.
	var qualified: bool=learned.facets.get("condition:burning",{}).get("via","")=="seen" and learned.facets.get("condition:fire",{}).get("via","")=="heard" and not learned.facets.has("actor")
	var okay: bool=no_recursive_save and callback_refused[0] and accepted.accepted and repeated_empty and upgraded and privacy and not failed.accepted and old_channel and checked.accepted and qualified and learned.identity.key=="unknown" and episodes==1 and bridge.notices.is_empty() and loaded.people_facts.size()==1 and loaded.people[victim].hurt==hurt_before
	if not okay:
		print("DIAGNOSTIC notice flags ",[no_recursive_save,callback_refused[0],accepted.accepted,repeated_empty,upgraded,privacy,not failed.accepted,old_channel,checked.accepted,episodes,bridge.notices.is_empty(),loaded.people_facts.size()==1,loaded.people[victim].hurt==hurt_before]," learned=",learned)
	tree.current_scene=prior_scene
	registry.free()
	VillageSession.village=prior_v
	VillageSession.active=prior_active
	VillageSession.background=prior_background
	Controls.locked=prior_locked
	SaveGame.paused=prior_pause
	return okay
static func _boundary_proof() -> PackedStringArray:
	var out := PackedStringArray()
	var tree: SceneTree=Engine.get_main_loop()
	var prior_v=VillageSession.village
	var prior_scene=tree.current_scene
	var flags := [VillageSession.active,VillageSession.background,Controls.locked,SaveGame.paused]
	var v=F.fixture()
	var victim := F.adult(v)
	var witness := -1
	for p in v.people:
		if p.id!=victim and p.alive and p.present:witness=p.id;break
	v.people[victim].locked=false
	v.people[victim].authored=""
	v.people[witness].traits[People.C.ALERT]=80
	var strike := _request(v,victim,"deed:boundary","strike",{"damage":1,"force":450})
	Actions.prepare(v,strike,_context())
	VillageSession.village=v
	VillageSession.active=true
	VillageSession.background=false
	Controls.locked=false
	SaveGame.paused=false
	var registry := NoticeRegistry.new()
	tree.root.add_child(registry)
	tree.current_scene=registry
	var sufferer := Node3D.new()
	var observer := Node3D.new()
	registry.add_child(sufferer)
	registry.add_child(observer)
	observer.position=Vector3(5,0,0)
	observer.rotation.y=-PI/2
	registry.bodies={victim:sufferer,witness:observer}
	registry._movers={victim:{"pos":Vector2.ZERO},witness:{"pos":Vector2(5,0)}}
	registry._crowd.nearby.snapshot(PackedVector2Array([Vector2.ZERO,Vector2(5,0)]),
		[{"key":People.key(v,victim),"body":sufferer},{"key":People.key(v,witness),"body":observer}])
	var bridge := Bridge.new(registry)
	bridge.source_folders.append("res://scripts/studio/people/proofs/sources/")
	bridge.modifier_folders.append("res://scripts/studio/people/proofs/forward/")
	registry.add_child(bridge)
	bridge.set_process(false)
	var generic := "actor:private-masked"
	v.actor_minds[generic]=preload("res://scripts/studio/village/sim/state.gd").Mind.new()
	v.actor_minds[generic].modifiers.assign([{"id":"masked"},{"id":"veiled_attention"}])
	var shown := bridge.appearance(generic)
	var delay := People.distraction(v.actor_minds[generic],80,bridge.modifier_folders)
	out.append(("PASS" if shown.key=="look:masked:red" and shown.name=="a masked stranger" and delay==275 else "FAIL")+" live mask survives unrelated discovered attention modifier")
	var fields := {"kind":"chill","subject":People.key(v,victim),"deed":strike.action_id,"fact_id":"hurt","revision":1}
	var invalid := fields.duplicate();invalid.deed="missing-root"
	var stale := fields.duplicate();stale.revision=99
	var refused: bool=not bridge.announce(People.key(v,victim),invalid) and not bridge.announce(People.key(v,victim),stale)
	var announced := bridge.announce(People.key(v,victim),fields)
	var queued := bridge._queued()
	v.runtime.now+=4
	var accepted := Accept.transact(func(candidate)->Dictionary:return {"accepted":bridge._apply_queued(candidate,queued,[])},func()->int:return OK)
	if accepted.accepted:bridge._published(queued)
	var loaded=Codec.from_data(Codec.to_data(VillageSession.village,false))
	var canonical := str(strike.action_id)+":"+People.key(v,witness)
	out.append(("PASS" if refused and announced and accepted.accepted and loaded.people[witness].mind.known.has(canonical) and loaded.people[witness].mind.known[canonical].kind=="chill" else "FAIL")+" one source file passes validated live notice and checked saved memory")
	VillageSession.village=loaded
	var masked_body := Node3D.new()
	registry.add_child(masked_body)
	masked_body.position=Vector3(1,0,0)
	bridge.register_actor(generic,masked_body)
	var masked_root := _request(loaded,victim,"deed:masked-compose","strike",{"damage":0,"force":200})
	masked_root.actor=generic
	Actions.prepare(loaded,masked_root,_context())
	var contact := registry.stimuli.make("contact",generic,People.key(loaded,victim),[0.0,0.0],{"act":"strike","damage":0,"force":200})
	contact.deed=masked_root.action_id
	var observed := bridge.observe(contact)
	loaded.runtime.now+=4
	var masked_save := Accept.transact(func(candidate)->Dictionary:return {"accepted":bridge._apply_queued(candidate,bridge._queued(),observed)},func()->int:return OK)
	loaded=Codec.from_data(Codec.to_data(VillageSession.village,false))
	canonical=str(masked_root.action_id)+":"+People.key(loaded,witness)
	var masked_memory: Dictionary=loaded.people[witness].mind.known.get(canonical,{})
	out.append(("PASS" if masked_save.accepted and not masked_memory.is_empty() and masked_memory.identity.key=="look:masked:red" and not JSON.stringify(masked_memory).contains(generic) else "FAIL")+" composed mask passes live sensing and checked remembered identity")
	VillageSession.village=loaded
	var burn := _request(loaded,victim,"deed:corpse","burn",{"heat":750})
	Actions.prepare(loaded,burn,_context())
	loaded.runtime.now+=28
	Actions.advance(loaded)
	bridge.announce(People.key(loaded,victim),{"kind":"death","subject":People.key(loaded,victim),"deed":burn.action_id,"fact_id":"dead","revision":1})
	queued=bridge._queued()
	loaded.runtime.now+=4
	var corpse := Accept.transact(func(candidate)->Dictionary:return {"accepted":bridge._apply_queued(candidate,queued,[])},func()->int:return OK)
	if corpse.accepted:bridge._published(queued)
	loaded=Codec.from_data(Codec.to_data(VillageSession.village,false))
	canonical=str(burn.action_id)+":"+People.key(loaded,witness)
	var memory: Dictionary=loaded.people[witness].mind.known.get(canonical,{})
	out.append(("PASS" if corpse.accepted and not memory.is_empty() and memory.via=="seen" and memory.evidence.act=="death" and memory.identity.key=="unknown" and not JSON.stringify(memory).contains("actor:measured") else "FAIL")+" visible silent corpse becomes saved anonymous evidence")
	v=F.fixture()
	VillageSession.village=v
	registry.bodies={}
	bridge.semantic_changed()
	var scans := bridge.schedule_scans
	var writes := Accept.writes
	for frame in range(120):bridge._flush()
	out.append(("PASS" if bridge.schedule_scans==scans and Accept.writes==writes else "FAIL")+" 120 idle polls perform no population scheduling scan or save")
	tree.current_scene=prior_scene
	registry.free()
	VillageSession.village=prior_v
	VillageSession.active=flags[0]
	VillageSession.background=flags[1]
	Controls.locked=flags[2]
	SaveGame.paused=flags[3]
	return out
