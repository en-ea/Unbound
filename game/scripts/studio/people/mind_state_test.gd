extends RefCounted
## Owned narrow evidence/attention/residual proofs; no substituted animation/world or phone verdict.
const F := preload("res://scripts/studio/people/foundation_state_test.gd")
const People := preload("res://scripts/studio/village/sim/people.gd")
const P := preload("res://scripts/studio/people/perception.gd")
const Affect := preload("res://scripts/studio/people/affect.gd")
const Attention := preload("res://scripts/studio/people/attention.gd")
const Temperament := preload("res://scripts/studio/people/temperament.gd")
const Appraisal := preload("res://scripts/studio/people/appraisal.gd")
const Codec := preload("res://scripts/studio/village/sim/save.gd")
const Accept := preload("res://scripts/studio/village/acceptance.gd")
const View := preload("res://scripts/studio/village/sim/view.gd")
const Modules := preload("res://scripts/studio/people/modules.gd")
static func check(out: PackedStringArray, ok: bool, description: String) -> void:
	out.append(("PASS" if ok else "FAIL")+" "+description)
static func record(target: String, deed: String, harm := 480) -> Dictionary:
	return {"kind":"contact","source":"actor:any","actor":"actor:any","target":target,"at":[2.0,3.0],"strength":harm,"evidence":{"act":"strike"},
		"features":{"harm":harm,"threat":harm,"novelty":200},"deed":deed,"event_ref":"incident:opaque"}
static func capture(target: String, observer: String, deed: String, sensor: Dictionary = {}, harm := 480) -> Dictionary:
	var measured := {"seen_event":true,"seen_actor":true,"seen_subject":true,"tick":0,"captured_tick":0,"occurred_tick":0,"due":0,"gain":1.0,
		"subject_identity":{"key":target,"name":"Oswin"}}
	measured.merge(sensor,true)
	return P.account(observer,record(target,deed,harm),measured,{"key":"player:local","name":"you"},deed+":"+observer)
static func report() -> PackedStringArray:
	var out := PackedStringArray()
	var v=F.fixture();var id := F.adult(v);var actor := People.key(v,id)
	v.people[id].authored="";v.people[id].locked=false
	var heard := capture(actor,"actor:listener","heard",{"seen_event":false,"seen_actor":true,"seen_subject":false,"heard":true,"carry":0.2})
	People.learn(v,heard,null,false)
	check(out,heard.identity.key=="unknown" and heard.target=="unknown" and not heard.facets.has("actor") and heard.features.harm==0 and not v.actor_minds["actor:listener"].stances.has("unknown"),"hearing neither identifies the aggressor nor copies unseen harm")
	var unrecognized := capture(actor,"actor:listener","facet",{"seen_actor":false})
	var unnamed := capture(actor,"actor:listener","unnamed",{"recognized_actor":false})
	var recognized := capture(actor,"actor:listener","facet")
	var merged := P.merge(unrecognized,recognized)
	check(out,unnamed.identity.key=="unknown" and not merged.is_empty() and merged.identity.key=="player:local" and P.merge(merged,recognized).is_empty(),"visibility and recognition separate; same-channel actor facet upgrades once")
	var processing=F.fixture()
	var first := unrecognized.duplicate(true);first.observer="actor:processing"
	var later := recognized.duplicate(true);later.observer=first.observer;later.due=People.tick(processing)+1000
	for slot: String in later.facets:later.facets[slot].due=later.due
	People.flush(processing,[first,later])
	var pm=processing.actor_minds[first.observer]
	var separately_pending: bool=pm.known["facet:actor:processing"].identity.key=="unknown" and pm.pending.size()==1
	processing.runtime.now+=2
	People.flush(processing,People.ready(processing))
	check(out,separately_pending and pm.known["facet:actor:processing"].identity.key=="player:local" and pm.pending.is_empty() and _timed_capture(actor),"new actor and stronger sight retain deadlines without swallowing an earlier captured cry")
	var delayed := capture(actor,"actor:captured-witness","delayed",{"due":People.tick(v)+2500,"captured_tick":People.tick(v),"occurred_tick":People.tick(v)})
	People.admit(v,[delayed])
	var loaded=Codec.from_data(Codec.to_data(v,false))
	loaded.runtime.now+=5
	People.flush(loaded,People.ready(loaded))
	var m=loaded.actor_minds["actor:captured-witness"]
	check(out,m.pending.is_empty() and m.known["delayed:actor:captured-witness"].via=="seen" and m.episodes[0].tick==int(delayed.occurred_tick),"captured evidence survives interrupted processing and real codec reload")
	var after := record(actor,"report");after.actor="";after.source=actor;after.kind="bruise";after.evidence={"act":"bruise","condition":"bruise"}
	var late := P.account("actor:listener",after,{"seen_event":true,"seen_actor":true,"seen_subject":true,"aftermath":true,"subject_identity":{"key":actor},
		"candidates":[{"identity":{"key":"res:bryn","name":"Bryn"},"confidence":200,"basis":["nearby"]}]},{"key":"player:local"},"report:listener")
	var me := {"key":"actor:listener","tuning":{},"prior_stances":{}}
	check(out,late.identity.key=="unknown" and not late.facets.has("act") and Appraisal.evaluate(me,late).claim.is_empty(),"late aftermath does not invent a blow or convict the nearest person")
	late.candidates[0].basis=["blood_on_hands"];late.candidates[0].confidence=300
	var inferred := Appraisal.evaluate(me,late)
	var dispute := P.account("actor:listener",after,{"seen_event":true,"aftermath":true,
		"candidates":[{"identity":{"key":"res:bryn"},"confidence":450,"basis":["reported_dispute"],"via":"told","speaker":"res:maud"}]},{"key":"unknown"},"dispute")
	var disputed := Appraisal.evaluate(me,dispute)
	check(out,inferred.claim.inferred and inferred.claim.confidence==300 and not inferred.aggression and inferred.stance.resentment==0 and disputed.claim.confidence==225 and disputed.claim.speaker=="res:maud","qualified suspicion preserves seen or reported clues, confidence and only wariness")
	var report := P.retell(capture(actor,"actor:witness","reported"),"actor:witness",actor,People.tick(v))
	var bruise := late.duplicate(true);bruise.deed="reported";bruise.observer=actor;bruise.key="reported:"+actor;bruise.due=People.tick(v)
	var reported_then_seen := P.merge(report,bruise)
	check(out,reported_then_seen.via=="told" and reported_then_seen.facets.act.via=="told" and reported_then_seen.facets["condition:bruise"].via=="seen","a later bruise does not upgrade a report to eyewitness")
	var fresh=F.fixture();var fid := F.adult(fresh);var own := People.key(fresh,fid)
	fresh.people[fid].authored="";fresh.people[fid].locked=false
	var a := capture(own,own,"one")
	People.learn(fresh,a,null,false)
	var fm=fresh.people[fid].mind
	var analytical := Affect.advance(617,123,23,1789)
	var stepped := Affect.advance(617,123,23,321)
	stepped=Affect.advance(int(stepped.value),int(stepped.remainder),23,1468)
	var before := JSON.stringify(Codec.to_data(fresh,false))
	var projected := Affect.project(fm,People.tick(fresh)+1789)
	var rising := Affect.project(fm,People.tick(fresh)+100)
	var settled := Affect.project(fm,People.tick(fresh)+60000)
	check(out,analytical.value==stepped.value and analytical.remainder==stepped.remainder and before==JSON.stringify(Codec.to_data(fresh,false)) and rising.anger>int(fm.affect.anger) and settled.anger<int(projected.anger) and _partition(fresh,fid),"analytical and partitioned build/fade match with remainders and projection is read-only")
	fresh.runtime.now+=10
	var gift := P.account(own,{"kind":"gift","source":"player:local","actor":"player:local","target":own,"at":[2.0,3.0],"strength":400,
		"evidence":{"act":"gift"},"features":{"assistance":220,"novelty":100},"deed":"gift"},
		{"seen":true,"due":People.tick(fresh),"tick":People.tick(fresh),"gain":1.0},{"key":"player:local","name":"you"},"gift:"+own)
	People.learn(fresh,gift,null,false)
	var relieved := int(fm.affect.anger);var wary := int(fm.stances["player:local"].wary)
	var improved := a.duplicate(true);improved.facets.act.revision=1;improved.facets.act.confidence=1000
	People.learn(fresh,improved,null,false)
	check(out,int(fm.affect.anger)==relieved and int(fm.stances["player:local"].wary)==wary and fm.stances["player:local"].hits==1 and fm.known.size()==2 and _provocation(own),"stronger evidence revises interpretation after decay and gift without replaying aggression or revoking relief")
	var repeat := capture(own,own,"two")
	People.learn(fresh,repeat,null,false)
	var first_resentment := int(fm.stances["player:local"].resentment)
	People.learn(fresh,repeat,null,false)
	check(out,fm.stances["player:local"].hits==2 and fm.stances["player:local"].resentment==first_resentment and View.toward_player(fresh,fid).memories.has("hit_by_you"),"distinct repeat aggression compounds once and gift preserves named deeds")
	var saturated=F.fixture();var sid := F.adult(saturated);var skey := People.key(saturated,sid)
	var high := capture(skey,skey,"saturate:a",{},1000)
	People.learn(saturated,high,null,false);People.learn(saturated,capture(skey,skey,"saturate:b",{},1000),null,false)
	saturated.runtime.now+=20
	var sm=saturated.people[sid].mind;var at_after := Affect.project(sm,People.tick(saturated))
	var revision := capture(skey,skey,"saturate:b",{},1000);revision.facets.act.revision=1
	People.learn(saturated,revision,null,false)
	check(out,int(sm.affect.anger)==int(at_after.anger) and sm.stances["player:local"].hits==2,"an upgrade cannot resurrect harm rejected by saturation")
	var calm=F.fixture();var cid := F.adult(calm);var ckey := People.key(calm,cid)
	var early_gift := gift.duplicate(true);early_gift.observer=ckey;early_gift.target=ckey;early_gift.key="early:"+ckey;early_gift.deed="early";early_gift.facets.subject.identity.key=ckey
	People.learn(calm,early_gift,null,false)
	People.learn(calm,capture(ckey,ckey,"later harm"),null,false)
	var cm=calm.people[cid].mind
	var after_harm := int(cm.affect.anger);var after_wary := int(cm.stances["player:local"].wary)
	early_gift.facets.act.revision=1
	People.learn(calm,early_gift,null,false)
	check(out,int(cm.affect.anger)==after_harm and int(cm.stances["player:local"].wary)==after_wary,"a calm-time gift upgrade cannot relieve subsequent aggression")
	var quiet := P.account("actor:listener",{"kind":"rustle","source":"actor:tree","actor":"","target":"","at":[0,0],"strength":200,"features":{"novelty":300},"evidence":{"act":"rustle"},"deed":"quiet"},
		{"heard":true,"tick":0,"due":0},{"key":"unknown"},"quiet")
	var habit := {}
	for i in 6:Attention.accepted(habit,quiet,i*500)
	var noisy := capture(own,own,"fresh harm")
	check(out,Attention.novelty_gain(habit,quiet,3000)<1000 and Attention.novelty_gain(habit,noisy,3000)==1000 and People.attention_delay(fresh,own,noisy)==0,"harmless repetition habituates; felt fresh harm remains immediate")
	check(out,_save_retry(fresh,own) and _extensions(fresh,fid) and _detail(fresh,own),"checked failure retry, generic extension/temperament codec and honest sixteen-detail cap")
	check(out,_r2_conversion(),"r2 accounts convert once keeping identity and how learned, with unknown features left unknown")
	check(out,_deferred(),"a limited flush learns whole witnesses in order and defers the rest into saved pending, learned once after reload")
	check(out,_written(),"every receipt a learn changes, its own and older ones it settles, is named in People.written()")
	return out
## Step 4 (M6): flush under a learn limit, then People.ready over later batches and a save and load, ends byte for
## byte where one unlimited flush ends (same tick); limit 0 learns nothing and loses nothing.
static func _deferred() -> bool:
	var v=F.fixture();var own := People.key(v,F.adult(v))
	var accounts := [capture(own,"actor:w1","d:one"),capture(own,"actor:w1","d:two"),capture(own,"actor:w2","d:one"),capture(own,"actor:w3","d:one")]
	var twin=Codec.from_data(Codec.to_data(v,false));var zero=Codec.from_data(Codec.to_data(v,false))
	var all: Array=People.flush(twin,accounts.duplicate(true))
	var first: Array=People.flush(v,accounts.duplicate(true),2)
	var ok: bool=all.size()==4 and first.size()==2 and v.actor_minds["actor:w2"].pending.size()==1 and v.actor_minds["actor:w3"].pending.size()==1
	v=Codec.from_data(Codec.to_data(v,false))
	var second: Array=People.flush(v,People.ready(v),1)
	var third: Array=People.flush(v,People.ready(v))
	ok=ok and second.size()==1 and str(second[0].observer)=="actor:w2" and third.size()==1 and str(third[0].observer)=="actor:w3" and People.ready(v).is_empty()
	for who: String in ["actor:w1","actor:w2","actor:w3"]:
		for fact: String in v.actor_minds[who].appraised:ok=ok and int(v.actor_minds[who].appraised[fact].revision)==1
	var a: Dictionary=Codec.to_data(v,false).state.fields;var b: Dictionary=Codec.to_data(twin,false).state.fields
	ok=ok and JSON.stringify(a.actor_minds)==JSON.stringify(b.actor_minds) and JSON.stringify(a.people)==JSON.stringify(b.people)
	var none: Array=People.flush(zero,accounts.duplicate(true),0)
	var waiting := 0
	for who: String in zero.actor_minds:waiting+=zero.actor_minds[who].pending.size()
	return ok and none.is_empty() and waiting==4
## Step 4 (M5): over harm, a gift and repeat harm with time passing, the record names every receipt that changed.
static func _written() -> bool:
	var v=F.fixture();var id := F.adult(v);var own := People.key(v,id);var m=v.people[id].mind
	var ok := true
	var steps := [capture(own,own,"w:one"),capture(own,own,"w:two",{},700),capture(own,own,"w:three",{},300)]
	var gift := P.account(own,{"kind":"gift","source":"player:local","actor":"player:local","target":own,"at":[2.0,3.0],"strength":400,
		"evidence":{"act":"gift"},"features":{"assistance":220,"novelty":100},"deed":"w:gift"},{"seen":true,"due":0,"tick":0,"gain":1.0},{"key":"player:local","name":"you"},"w:gift:"+own)
	steps.insert(2,gift)
	var named := 0
	for a: Dictionary in steps:
		v.runtime.now+=40
		var before: Dictionary=m.appraised.duplicate(true)
		People.clear_written()
		People.learn(v,a,null,false)
		var wrote: Dictionary=People.written().get(m.get_instance_id(),{})
		for fact: String in m.appraised:
			if not before.has(fact) or JSON.stringify(before[fact])!=JSON.stringify(m.appraised[fact]):
				ok=ok and wrote.has(fact);named+=1
	People.clear_written()
	return ok and named>=6 and People.written().is_empty()
## Exact r2 shapes from the owner's saves: flat accounts with no features, flat numeric receipts.
static func _r2_conversion() -> bool:
	var v=F.fixture();var id := F.adult(v);var own := People.key(v,id);var m=v.people[id].mind
	var seen := {"deed":"square_up:r2","due":3380430,"evidence":{"act":"threat"},"identity":{"key":"player:local","learned":"seen","name":"player:local"},
		"key":"square_up:r2:"+own,"kind":"threat","observer":own,"strength":420,"target":"res:1:20","via":"seen","at":[12.1,7.8]}
	var heard := {"deed":"cry:r2","due":3380500,"evidence":{"act":"strike"},"identity":{"key":"unknown","learned":"heard","name":"someone"},
		"key":"cry:r2:"+own,"kind":"contact","observer":own,"strength":300,"target":"unknown","via":"heard","speaker":"","compacted":true}
	for a: Dictionary in [seen,heard]:
		m.known[a.key]=a.duplicate(true);m.appraised[a.key]={"anger":120,"fear":40,"pain":0,"interest":60,"stance":-90}
	var episode=People.S.Episode.new()
	episode.key=seen.key;episode.tick=3380430;episode.account=seen.duplicate(true);m.episodes.append(episode)
	var affect: Dictionary=m.affect.duplicate(true);var stances: Dictionary=m.stances.duplicate(true)
	var converted := People.upgrade(v)
	var ok: bool = converted>=4 and People.upgrade(v)==0 and People.invalid(v)=="" and m.affect==affect and m.stances==stances
	for a: Dictionary in [seen,heard]:
		var b: Dictionary=m.known[a.key]
		ok=ok and b.has("facets") and b.features.is_empty() and b.identity==a.identity and b.deed==a.deed and b.via==a.via and b.target==a.target \
			and int(b.strength)==int(a.strength) and b.evidence==a.evidence and m.appraised[a.key].upgraded.original=={"anger":120,"fear":40,"pain":0,"interest":60,"stance":-90}
	ok=ok and episode.account.is_empty() and People.episode_account(m,episode)==m.known[seen.key] and People.sorted(m.known[seen.key])
	var back = Codec.from_data(Codec.to_data(v,false))
	return ok and back!=null and back.people[id].mind.known[heard.key].identity==heard.identity and back.people[id].mind.known[seen.key].features.is_empty()
static func _timed_capture(target: String) -> bool:
	var v=F.fixture();var now := People.tick(v)
	var cry := capture(target,"actor:timed","timed",{"seen_event":false,"seen_actor":false,"seen_subject":false,"heard":true,"due":now+500})
	var sight := capture(target,"actor:timed","timed",{"due":now+1500})
	People.admit(v,[cry,sight,cry])
	if v.actor_minds["actor:timed"].pending.size()!=2:return false
	v=Codec.from_data(Codec.to_data(v,false));v.runtime.now+=1
	People.flush(v,People.ready(v))
	var m=v.actor_minds["actor:timed"]
	if m.known["timed:actor:timed"].via!="heard" or m.pending.size()!=1 or m.appraised["timed:actor:timed"].revision!=1:return false
	v.runtime.now+=2
	People.flush(v,People.ready(v))
	return m.known["timed:actor:timed"].via=="seen" and m.pending.is_empty() and m.appraised["timed:actor:timed"].revision==2 and m.stances["player:local"].hits==1
static func _partition(v, id: int) -> bool:
	var once=Codec.from_data(Codec.to_data(v,false));var steps=Codec.from_data(Codec.to_data(v,false))
	var one=once.people[id].mind;var two=steps.people[id].mind
	var now := People.tick(v);var tuning: Dictionary=People.profile(v,People.key(v,id),one.known["one:"+People.key(v,id)]).tuning
	Affect.settle(one,now+67891,tuning);People.settle_stances(one,now+67891)
	Affect.settle(two,now+333,tuning);People.settle_stances(two,now+333)
	Affect.settle(two,now+67891,tuning);People.settle_stances(two,now+67891)
	return one.affect==two.affect and one.fade_remainders==two.fade_remainders and one.stances==two.stances and one.appraised==two.appraised
static func _provocation(actor: String) -> bool:
	var v=F.fixture();var a := capture(actor,actor,"provocation")
	People.learn(v,a,null,false)
	var m=People.mind(v,actor);var initial := int(m.appraised["provocation:"+actor].channels.anger.wanted)
	a.facets.act.features.provocation=800;a.facets.act.revision=1
	People.learn(v,a,null,false)
	return int(m.appraised["provocation:"+actor].channels.anger.wanted)<initial and m.stances["player:local"].hits==1
static func _save_retry(v, actor: String) -> bool:
	var previous=VillageSession.village;VillageSession.village=v
	var a := capture(actor,actor,"checked")
	var writes := [0]
	var failed := Accept.transact(func(candidate)->Dictionary:
		return {"accepted":People.learn(candidate,a,null,false),"costs":[]},func()->int:writes[0]+=1;return ERR_CANT_CREATE)
	var no_leak: bool=not failed.accepted and not VillageSession.village.people[F.adult(v)].mind.known.has("checked:"+actor)
	var passed := Accept.transact(func(candidate)->Dictionary:
		return {"accepted":People.learn(candidate,a,null,false),"costs":[]},func()->int:writes[0]+=1;return OK)
	var again := Accept.transact(func(candidate)->Dictionary:
		return {"accepted":People.learn(candidate,a,null,false),"costs":[]},func()->int:writes[0]+=1;return OK)
	var restored=Codec.from_data(Codec.to_data(VillageSession.village,false))
	var ok: bool=no_leak and passed.accepted and not again.accepted and writes[0]==2 and restored.people[F.adult(v)].mind.known.has("checked:"+actor)
	VillageSession.village=previous
	return ok
static func _extensions(v, id: int) -> bool:
	var source=Modules.discover("res://scripts/studio/people/proofs/sources/")["cold"].new()
	var patient := People.mind(v,"actor:creature")
	patient.temperament="patient"
	var s: Dictionary=source.make("world:wind","actor:creature",[0,0],{})
	s.deed="cold"
	var a := P.account("actor:creature",s,{"seen":true,"due":0},{"key":"look:wind","name":"wind"},"cold:creature")
	People.learn(v,a,null,false,["res://scripts/studio/people/proofs/temperaments/"])
	var common := People.mind(v,"actor:common")
	s.target="actor:common";s.subject=s.target
	var b := P.account("actor:common",s,{"seen":true,"due":0},{"key":"look:wind","name":"wind"},"cold:common")
	People.learn(v,b,null,false)
	var me := People.profile(v,"actor:creature",a,["res://scripts/studio/people/proofs/temperaments/"])
	var output := People.hints(patient,People.tick(v),me.tuning)
	var distinct: bool=output.style.show==0.3 and patient.affect.anger<common.affect.anger and patient.fade_remainders.anger.rate==40
	var restored=Codec.from_data(Codec.to_data(v,false))
	return distinct and restored.actor_minds["actor:creature"].temperament=="patient" and restored.actor_minds["actor:creature"].affect.pain==0 and preload("res://scripts/studio/people/proofs/forward/masked.gd").prove()
static func _detail(v, actor: String) -> bool:
	for i in 20:People.learn(v,capture(actor,actor,"detail:"+str(i)),null,false)
	var m=People.mind(v,actor)
	var restored=Codec.from_data(Codec.to_data(v,false))
	return m.episodes.size()==16 and m.known.size()>16 and m.appraised.size()==m.known.size() and m.known["one:"+actor].get("compacted",false) and restored.people[F.adult(v)].mind.appraised.size()==m.appraised.size()
