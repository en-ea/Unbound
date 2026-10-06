extends RefCounted
## C2/C4 regression through actual offers, People, reflective codec and checked Acceptance.
## No physical travel/report arrival claim: integration exercises the live runner with these saved plans.
const F := preload("res://scripts/studio/people/foundation_state_test.gd")
const M := preload("res://scripts/studio/people/mind_state_test.gd")
const People := preload("res://scripts/studio/village/sim/people.gd")
const P := preload("res://scripts/studio/people/perception.gd")
const Codec := preload("res://scripts/studio/village/sim/save.gd")
const Accept := preload("res://scripts/studio/village/acceptance.gd")
const Modules := preload("res://scripts/studio/people/modules.gd")
const C := preload("res://scripts/studio/village/sim/content.gd")
const Rules := preload("res://scripts/studio/village/sim/village.gd")
const Chooser := preload("res://scripts/studio/people/chooser.gd")
class ContextSpy extends RefCounted:
	var keys: Array[String]=[]
	var engine=preload("res://scripts/studio/people/chooser.gd").new()
	func pick_many(accounts: Array, profile: Callable) -> Dictionary:
		keys.clear()
		for a: Dictionary in accounts:keys.append(str(a.key))
		return engine.pick_many(accounts,profile)
static func check(out: PackedStringArray, okay: bool, label: String) -> void:
	out.append(("PASS" if okay else "FAIL")+" "+label)
static func other(v, avoid: Array) -> int:
	for p in v.people:
		if p.alive and p.present and not int(p.id) in avoid:return int(p.id)
	return -1
static func fetching() -> Dictionary:
	var v=F.fixture();var witness := F.adult(v)
	var victim := other(v,[witness,v.authority])
	v.people[witness].authored="";v.people[witness].locked=false
	v.people[witness].traits[C.BOLD]=20
	var who := People.key(v,witness);var target := People.key(v,victim)
	var a := M.capture(target,who,"choice:one",{"seen_actor":false})
	People.learn(v,a)
	return {"v":v,"witness":witness,"victim":victim,"actor":who,"target":target,"account":a}
static func improvement(d: Dictionary, revision: int) -> Dictionary:
	var a := M.capture(str(d.target),str(d.actor),"choice:one")
	for f: Dictionary in a.facets.values():f.revision=revision
	return a
static func condition(d: Dictionary, kind: String) -> Dictionary:
	var source=Modules.discover("res://scripts/studio/people/sources/")[kind].new()
	var s: Dictionary=source.make(str(d.target),str(d.target),[2.0,3.0],{"strength":480})
	s.deed="choice:one";s.actor="";s.revision=1
	s.notice_id="notice:"+kind
	var now := People.tick(d.v)
	return P.account(str(d.actor),s,{"seen_event":true,"seen_subject":true,"seen_source":true,"aftermath":true,
		"gain":1.0,"tick":now,"due":now,"subject_identity":{"key":d.target},"emitter_identity":{"key":d.target}},
		{"key":"unknown"},"choice:one:"+str(d.actor))
static func report() -> PackedStringArray:
	var out := PackedStringArray()
	check(out,_retention(),"same-deed cry/down/injury/recognition save richer evidence without restarting fetch progress")
	check(out,_checked_retry(),"checked failure/retry and codec retain one episode, phase, generation and richer pending report")
	check(out,_replacement(),"different actionable helper destination or deed replaces intent once")
	check(out,_control(),"actual discovered puppet order changes replace intent; stable order and freed memory persist")
	check(out,_split_time(),"split-time incidental witness account competes with continuing felt harm; stronger fire choice may replace it")
	check(out,_bounded_context(),"only keyed continuing/self context competes; compacted memories persist and expired plans retire")
	return out
static func _retention() -> bool:
	var d := fetching();var v=d.v;var m=People.mind(v,str(d.actor))
	if str(m.plan.get("offer",""))!="fetch_help":return false
	m.plan.phase=1
	var generation := int(m.generation);var until := int(m.plan.until)
	var spoken: Dictionary=m.plan.steps[0].duplicate(true)
	for kind: String in ["cry","fall","injured"]:
		v.runtime.now+=1
		People.admit(v,[condition(d,kind)])
		if int(m.plan.phase)!=1 or int(m.generation)!=generation or int(m.plan.until)!=until:return false
	v.runtime.now+=1;People.admit(v,[improvement(d,2)])
	var report: Dictionary=m.plan.steps[2].account
	return m.episodes.size()==1 and m.plan.steps[0]==spoken and report.identity.key=="player:local" and report.facets.has("condition:down") and report.facets.has("condition:injured") and int(m.appraised["choice:one:"+str(d.actor)].revision)==5
static func _checked_retry() -> bool:
	if not People.same_value({"seconds":2.0,"at":[1.0,2.5]},{"seconds":2,"at":[1,2.5]}) or People.same_value({"seconds":2},{"seconds":3}):return false
	var d := fetching();var v=d.v;var actor := str(d.actor)
	var m=People.mind(v,actor);m.plan.phase=2
	var generation := int(m.generation);var until := int(m.plan.until)
	v=Codec.from_data(Codec.to_data(v,false))
	var previous=VillageSession.village;VillageSession.village=v
	var a := improvement(d,1)
	var writes := [0]
	var failed := Accept.transact(func(candidate)->Dictionary:
		return {"accepted":People.learn(candidate,a),"costs":[]},func()->int:writes[0]+=1;return ERR_CANT_CREATE)
	var saved=VillageSession.village.people[int(d.witness)].mind
	var rolled_back: bool=not failed.accepted and saved.plan.phase==2 and saved.plan.generation==generation and saved.known[a.key].identity.key=="unknown"
	var okay := Accept.transact(func(candidate)->Dictionary:
		return {"accepted":People.learn(candidate,a),"costs":[]},func()->int:writes[0]+=1;return OK)
	var replay := Accept.transact(func(candidate)->Dictionary:
		return {"accepted":People.learn(candidate,a),"costs":[]},func()->int:writes[0]+=1;return OK)
	var restored=Codec.from_data(Codec.to_data(VillageSession.village,false))
	var current=restored.people[int(d.witness)].mind
	var result: bool=rolled_back and okay.accepted and not replay.accepted and writes[0]==2 and current.episodes.size()==1 and current.plan.phase==2 and current.generation==generation and current.plan.until==until and current.plan.steps[2].account.identity.key=="player:local"
	VillageSession.village=previous
	return result
static func _replacement() -> bool:
	var d := fetching();var v=d.v;var m=People.mind(v,str(d.actor))
	m.plan.phase=1
	var generation := int(m.generation)
	v.authority=other(v,[int(d.witness),int(d.victim),v.authority])
	var helper := People.key(v,v.authority)
	People.learn(v,improvement(d,1))
	if m.plan.offer!="fetch_help" or m.plan.phase!=0 or m.generation!=generation+1 or m.plan.steps[1].target!=helper:return false
	var another := M.capture(str(d.target),str(d.actor),"choice:two")
	People.learn(v,another)
	return m.generation==generation+2 and m.plan.phase==0 and m.plan.deed=="choice:two" and m.episodes.size()==2
static func _control() -> bool:
	var d := fetching();var v=d.v;var m=People.mind(v,str(d.actor))
	m.plan={};v.authority=-1
	var controller := "actor:hidden-fourth"
	m.modifiers.append({"id":"puppeted","controller":controller,"order":{"actor":controller,"key":"order:1","offer":"settle"}})
	var engine=Chooser.new("res://scripts/studio/people/offers/","res://scripts/studio/people/proofs/forward/")
	People.decide(v,str(d.actor),[m.known["choice:one:"+str(d.actor)]],engine)
	if m.plan.offer!="settle":return false
	m.plan.phase=1;var generation := int(m.generation)
	v=Codec.from_data(Codec.to_data(v,false));m=People.mind(v,str(d.actor))
	People.learn(v,improvement(d,1),engine)
	if m.generation!=generation or m.plan.phase!=1:return false
	m.modifiers[0].order.key="order:2"
	People.learn(v,improvement(d,2),engine)
	if m.plan.offer!="settle" or m.generation!=generation+1 or m.plan.phase!=0:return false
	m.modifiers.clear()
	People.learn(v,improvement(d,3),engine)
	var restored=Codec.from_data(Codec.to_data(v,false))
	var r=restored.people[int(d.witness)].mind
	return r.generation==generation+2 and r.plan.offer=="settle" and r.episodes.size()==1 and r.known["choice:one:"+str(d.actor)].identity.key=="player:local" and r.modifiers.is_empty()
static func hurt() -> Dictionary:
	var v=F.fixture();var victim := F.adult(v);var friend := other(v,[victim])
	v.people[victim].authored="";v.people[victim].locked=false
	v.people[victim].traits[C.BOLD]=45
	Rules.set_opinion(v,victim,friend,80)
	var who := People.key(v,victim);var target := People.key(v,friend)
	var own := M.capture(who,who,"split:own",{},1000)
	People.admit(v,[own])
	return {"v":v,"victim":victim,"actor":who,"friend":target,"own":own}
static func _split_time() -> bool:
	var d := hurt();var v=d.v;var who := str(d.actor);var m=People.mind(v,who)
	if str(m.plan.get("offer",""))!="retreat":return false
	m.plan.phase=1;var generation := int(m.generation);var until := int(m.plan.until)
	var later := M.capture(str(d.friend),who,"split:friend",{"due":People.tick(v)+1000})
	People.admit(v,[later]);v=Codec.from_data(Codec.to_data(v,false));v.runtime.now+=2
	People.flush(v,People.ready(v));m=People.mind(v,who)
	if m.plan.offer!="retreat" or m.plan.phase!=1 or m.generation!=generation or m.plan.until!=until or m.pending.size()!=0 or m.known.size()!=2:return false
	var source=Modules.discover("res://scripts/studio/people/sources/")["fire"].new()
	var s: Dictionary=source.make("player:local",who,[2.0,3.0],{"strength":750})
	s.deed="split:fire"
	var burn := P.account(who,s,{"seen":true,"gain":1.0,"due":People.tick(v),"tick":People.tick(v)},{"key":"player:local","name":"you"},"split:fire:"+who)
	burn.affordances={"water":{"key":"water:well"}}
	People.admit(v,[burn])
	return m.plan.offer=="escape_fire" and m.plan.phase==0 and m.generation==generation+1 and m.known.size()==3
static func _bounded_context() -> bool:
	var d := hurt();var v=d.v;var who := str(d.actor);var m=People.mind(v,who)
	var friend := M.capture(str(d.friend),who,"context:friend")
	People.learn(v,friend,null,false)
	var controller := "actor:controller"
	m.modifiers.append({"id":"puppeted","controller":controller,"order":{"actor":controller,"key":"order:help","offer":"intervene"}})
	var controlled=Chooser.new("res://scripts/studio/people/offers/","res://scripts/studio/people/proofs/forward/")
	People.decide(v,who,[friend],controlled)
	if m.plan.offer!="intervene" or str(m.plan.self_account)!=str(d.own.key):return false
	m.modifiers.clear()
	for i in 20:
		var quiet := M.capture(str(d.friend),who,"quiet:"+str(i),{},0)
		People.learn(v,quiet,null,false)
	var newer := M.capture(str(d.friend),who,"context:new")
	People.learn(v,newer,null,false)
	var probe := ContextSpy.new()
	People.decide(v,who,[newer],probe)
	if probe.keys.size()!=3 or not probe.keys.has(str(d.own.key)) or m.plan.offer!="retreat" or not m.known[d.own.key].get("compacted",false):return false
	m.plan.until=People.tick(v)
	People.decide(v,who,[newer],probe)
	return probe.keys.size()==1 and m.plan.offer=="intervene" and str(m.plan.self_account).is_empty()
