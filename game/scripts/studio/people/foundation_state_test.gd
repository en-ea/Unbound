extends RefCounted
const F := preload("res://scripts/studio/village/sim/actions_test.gd")
const People := preload("res://scripts/studio/village/sim/people.gd")
const Actions := preload("res://scripts/studio/village/sim/people_actions.gd")
const Codec := preload("res://scripts/studio/village/sim/save.gd")
const P := preload("res://scripts/studio/people/perception.gd")
const Modules := preload("res://scripts/studio/people/modules.gd")
static func report() -> PackedStringArray:
	var out := PackedStringArray()
	var v = fixture()
	var target := adult(v)
	v.people[target].locked=false
	v.people[target].authored=""
	var actor := People.key(v,target)
	var stimulus := {"kind":"contact","source":"player:local","target":actor,"at":[0,0],"strength":480,
		"evidence":{"act":"strike"},"deed":"test:contact"}
	var account := P.account(actor,stimulus,{"seen":true,"due":People.tick(v)},{"key":"player:local","name":"you"},"test:contact:"+actor)
	var heard := P.account(actor+"x",stimulus,{"heard":true,"due":0},{"key":"player:local","name":"you"},"heard")
	out.append(("PASS" if heard.identity.key=="unknown" and not heard.evidence.has("heavy") else "FAIL")+" hearing cannot identify actor")
	var upgrade_v=fixture()
	var upgrade_id:=adult(upgrade_v)
	var upgrade:=heard.duplicate(true)
	upgrade.observer=People.key(upgrade_v,upgrade_id)
	People.learn(upgrade_v,upgrade)
	upgrade=account.duplicate(true)
	upgrade.observer=People.key(upgrade_v,upgrade_id)
	upgrade.target=upgrade.observer
	People.learn(upgrade_v,upgrade)
	People.learn(upgrade_v,upgrade)
	var upgraded=upgrade_v.people[upgrade_id].mind
	out.append(("PASS" if upgraded.known.size()==1 and upgraded.episodes.size()==1 and upgraded.stances["player:local"].hits==1 and upgraded.affect.pain==480 else "FAIL")+" stronger evidence replaces one appraisal and episode")
	People.learn(v,account)
	out.append(("PASS" if v.people[target].mind.known.size()==1 and v.people[target].mind.plan.offer=="protest" else "FAIL")+" one appraisal and victim offer")
	People.learn(v,account)
	out.append(("PASS" if v.people[target].mind.known.size()==1 and v.people[target].mind.stances["player:local"].hits==1 else "FAIL")+" keyed account idempotent")
	var original := int(v.people[target].mind.affect.anger)
	var gift := account.duplicate(true)
	gift.key="test:gift"
	gift.deed="test:gift"
	gift.kind="gift"
	gift.evidence={"act":"gift"}
	People.learn(v,gift)
	out.append(("PASS" if int(v.people[target].mind.affect.anger)<original and v.people[target].mind.known.has(str(account.key)) else "FAIL")+" gift softens without erasure")
	var restored = Codec.from_data(Codec.to_data(v,false))
	out.append(("PASS" if restored!=null and restored.people[target].mind.known.size()==2 and restored.people[target].mind.plan.offer=="settle" else "FAIL")+" reflective codec carries minds and semantic phases")
	var delayed := account.duplicate(true)
	delayed.key="delayed"
	delayed.deed="delayed"
	delayed.due=People.tick(v)+2200
	People.admit(v,[delayed])
	out.append(("PASS" if v.people[target].mind.pending.size()==1 and not v.people[target].mind.known.has("delayed:"+actor) else "FAIL")+" pending attention saved distinctly")
	out.append(("PASS" if People.distraction(v.people[target].mind,10)==2200 and People.distraction(v.people[target].mind,70)==0 else "FAIL")+" ordinary low alertness delays attention without a fixture")
	v.runtime.now += 5
	People.flush(v,People.ready(v))
	out.append(("PASS" if v.people[target].mind.pending.is_empty() and v.people[target].mind.known.has("delayed:"+actor) else "FAIL")+" ready attention admitted once")
	var other:=delayed.duplicate(true)
	other.key="outside"
	other.deed="outside"
	other.observer="actor:other-land"
	other.due=People.tick(v)+500
	People.admit(v,[other])
	v.runtime.now+=1
	People.flush(v,People.ready(v))
	out.append(("PASS" if v.actor_minds[other.observer].pending.is_empty() and v.actor_minds[other.observer].known.size()==1 else "FAIL")+" general actor pending attention reaches checked batch")
	var req := {"action_id":"deed:one","actor":"actor:other","target":actor,"verb":"strike","village_id":v.runtime.village,"logical_time":v.runtime.now,"parameters":{"damage":1}}
	var ctx := {"authorized":true,"distance_dm":10,"accounts":[]}
	var r := Actions.prepare(v,req,ctx)
	var hurt := int(v.people[target].hurt)
	var duplicate := Actions.prepare(v,req,ctx)
	out.append(("PASS" if r.accepted and duplicate.duplicate and v.people[target].hurt==hurt else "FAIL")+" general actor deed ledger idempotent")
	out.append(("PASS" if not Actions.prepare(v,dict(req,"far"),dict(ctx,"",80)).accepted else "FAIL")+" actual eligibility enforced")
	var element := preload("res://scripts/studio/people/body_elements.gd").new("res://scripts/studio/people/proofs/elements/")
	var emitted := []
	element.play("shiver",{"emit":func(kind: String,_fields:Dictionary)->void:emitted.append(kind)},0.5,{})
	element.update(0.2)
	out.append(("PASS" if emitted==["shiver"] and element.playing.is_empty() else "FAIL")+" one-file body element")
	var source = Modules.discover("res://scripts/studio/people/proofs/sources/")["footfall"].new()
	var foot: Dictionary=source.make("actor:other",actor,[0,0],{})
	out.append(("PASS" if foot.kind=="footfall" and foot.reach==8.0 else "FAIL")+" one-file source")
	var me := People.profile(v,actor,account)
	var choice := preload("res://scripts/studio/people/chooser.gd").new("res://scripts/studio/people/proofs/offers/").pick(me,dict(account,"",-1,"footfall"))
	out.append(("PASS" if choice.offer=="listen" else "FAIL")+" one-file offer")
	var modifier = Modules.discover("res://scripts/studio/people/proofs/modifiers/")["drunk"].new()
	out.append(("PASS" if modifier.gain(me,account,{})==1400 and modifier.score("protest",me,{})==30 else "FAIL")+" one-file modifier")
	out.append(("PASS" if preload("res://scripts/studio/people/proofs/forward/masked.gd").prove() else "FAIL")+" masked source bounded account")
	var fresh = fixture()
	var victim := adult(fresh)
	var puppet := account.duplicate(true)
	puppet.observer=People.key(fresh,victim)
	puppet.target=puppet.observer
	out.append(("PASS" if preload("res://scripts/studio/people/proofs/forward/puppeted.gd").prove(fresh,victim,puppet) else "FAIL")+" freed puppet retains episode through codec")
	return out
static func fixture():
	return preload("res://scripts/studio/village/sim/runtime.gd").create(16838,{"anchored":true})
static func adult(v) -> int:
	for p in v.people:
		if p.alive and p.present and p.authored=="" and preload("res://scripts/studio/village/sim/village.gd").age_of(v,p)>=18:
			return int(p.id)
	return -1
static func dict(from: Dictionary, action_id := "", distance_dm := -1, kind := "") -> Dictionary:
	var copy := from.duplicate(true)
	if not action_id.is_empty():copy.action_id=action_id
	if distance_dm>=0:copy.distance_dm=distance_dm
	if not kind.is_empty():copy.kind=kind
	return copy
