extends RefCounted
## S/P adapter. Candidate-only admit/flush/learn before the owner's single checked save.
## Opaque deed:observer authority survives recent-detail cap16. C chooser/semantic plans remain owners.
## Captures wait for processing, not admission after processing. Presentation projection never writes.
## C boundary: one chooser sees new accounts + at most two keyed ongoing contexts; no episode scan.
## Same deed/offer/actionable suffix/control keeps phase, generation and deadline, refreshing only future steps.
## report.account and say.text annotate an intent. Bridge must rebind retained runner.steps after publication.
const S := preload("res://scripts/studio/village/sim/state.gd")
const Rules := preload("res://scripts/studio/village/sim/village.gd")
const C := preload("res://scripts/studio/village/sim/content.gd")
const Appraisal := preload("res://scripts/studio/people/appraisal.gd")
const Chooser := preload("res://scripts/studio/people/chooser.gd")
const Modules := preload("res://scripts/studio/people/modules.gd")
const Perception := preload("res://scripts/studio/people/perception.gd")
const Temperament := preload("res://scripts/studio/people/temperament.gd")
const Attention := preload("res://scripts/studio/people/attention.gd")
const Affect := preload("res://scripts/studio/people/affect.gd")
const STANCES := ["wary","trust","resentment","obligation"]
static func tick(v: S.Village) -> int:
	return roundi((float(v.runtime.get("now",0))+float(v.runtime.get("fraction",0)))*500.0)
static func key(v: S.Village, id: int) -> String:
	return "res:%d:%d" % [v.seed,id]
static func resident(v: S.Village, actor: String) -> int:
	var parts := actor.split(":")
	if parts.size()!=3 or parts[0]!="res" or int(parts[1])!=v.seed or not parts[2].is_valid_int():return -1
	var id := int(parts[2])
	return id if id>=0 and id<v.people.size() else -1
## Load boundary (studio rotation 4 Oct, Mind-file exception approved by Hilmi): Foundations-r2 receipts were
## flat {anger,fear,pain,interest,stance:int}, applied straight into totals that have since faded or been rebuilt.
## Upgrade once into residual receipts that own nothing still removable: harm counts as already faded, granted
## relief as already relieved, stance channels have no capacity. A later upgrade of the same deed can then add
## new knowledge without charging the original harm, hit or relief again. r2 accounts gain facets the same way.
## Then every mind takes the M3 shape (reshape below). Idempotent; returns receipts, accounts and minds changed.
static func upgrade(v: S.Village) -> int:
	var minds: Array=[]
	for p: S.Person in v.people:minds.append(p.mind)
	minds.append_array(v.actor_minds.values())
	var upgraded := 0
	for m: S.Mind in minds:
		# r2 accounts carried one flat channel; give them the facets merge/flatten read, through the existing door.
		for fact: String in m.known:
			var a: Variant=m.known[fact]
			if a is Dictionary and not a.has("facets") and a.has("via"):m.known[fact]=r2_account(a);upgraded+=1
		for episode: S.Episode in m.episodes:
			if not episode.account.is_empty() and not episode.account.has("facets") and episode.account.has("via"):episode.account=r2_account(episode.account)
		var order: Array=m.known.keys()
		var facts: Array=m.appraised.keys();facts.sort()
		for fact: String in facts:
			var old: Variant=m.appraised[fact]
			if old is Dictionary and old.has("revision") and old.get("stance",{}) is Dictionary and old.get("channels",{}) is Dictionary:continue
			var r: Dictionary=old if old is Dictionary else {}
			var account: Variant=m.known.get(fact,{})
			if not account is Dictionary:account={}
			var identity: Variant=account.get("identity",{})
			var who := str(identity.get("key","unknown")) if identity is Dictionary else "unknown"
			var channels := {}
			for name: String in Affect.CHANNELS:
				var amount := int(r.get(name,0)) if (r.get(name,0) is int or r.get(name,0) is float) else 0
				if amount<0:channels[name]={"wanted":amount,"capacity":-amount,"remaining":0,"unbuilt":0,"relieved":-amount}
				elif amount>0:channels[name]={"wanted":amount,"capacity":amount,"remaining":0,"unbuilt":0,"faded":amount,"relief":0}
			var stance := {}
			if who not in ["unknown",""]:
				stance={"identity":who,"channels":{}}
				for name: String in STANCES:stance.channels[name]={"wanted":0,"remaining":0,"capacity":0,"neutralized":0,"faded":0,"relief":0}
			var evidence: Variant=account.get("evidence",{})
			var struck: bool=evidence is Dictionary and str(evidence.get("act",""))=="strike"
			var at := 0
			for episode: S.Episode in m.episodes:
				if episode.key==fact:at=episode.tick
			var feeling: Variant=r.get("stance",0)
			m.appraised[fact]={"revision":1,"channels":channels,"stance":stance,"counted":struck and not stance.is_empty(),
				"tick":at,"ordinal":order.find(fact) if order.has(fact) else order.size(),"meaning":{},
				"upgraded":{"from":"foundations-r2","feeling":int(feeling) if (feeling is int or feeling is float) else 0,"original":old}}
			upgraded+=1
		if reshape(m):upgraded+=1
	return upgraded
## M3 shape (agreed with Foundations, mind.md "M3 proposal"), exact: nothing it removes is ever read.
## Accounts keep sorted keys, so a mind encodes to the same bytes live and after reload; an episode whose account
## equals its known account keeps none (episode_account reads it); a receipt basis keeps no derived context
## (BASIS_DERIVED is recomputed by learn before every read). Returns whether anything changed.
static func reshape(m: S.Mind) -> bool:
	var changed := false
	for fact: String in m.known:
		var a: Variant=m.known[fact]
		if a is Dictionary and not sorted(a):m.known[fact]=ordered(a);changed=true
	for episode: S.Episode in m.episodes:
		if not episode.account.is_empty() and episode.account==m.known.get(episode.key):episode.account={};changed=true
	for fact: String in m.appraised:
		var basis: Variant=m.appraised[fact].get("basis") if m.appraised[fact] is Dictionary else null
		if basis is Dictionary and BASIS_DERIVED.any(func(k: String)->bool:return basis.has(k)):
			for k: String in BASIS_DERIVED:basis.erase(k)
			changed=true
	return changed
## Learn re-resolves tuning, fetches prior stances and reads provocation from the account before any use.
const BASIS_DERIVED := ["tuning","prior_stances","provocation"]
## What an episode's account is: its own copy when it differs, otherwise the known account it names.
static func episode_account(m: S.Mind, episode: S.Episode) -> Dictionary:
	return episode.account if not episode.account.is_empty() else m.known.get(episode.key,{})
## Recursively key-sorted copy; array order is kept. StringName keys (from a.field=... writes) become the String
## keys a reload gives, so live and reloaded minds encode alike (handover gap b).
static func ordered(value: Variant) -> Variant:
	if value is Dictionary:
		var d: Dictionary=value
		var keys: Array=d.keys()
		for i in keys.size():
			if keys[i] is StringName:keys[i]=String(keys[i])
		keys.sort()
		var out := {}
		for k: Variant in keys:
			var x: Variant=d[k]
			out[k]=ordered(x) if (x is Dictionary or x is Array) else x
		return out
	if value is Array:
		var list: Array=value.duplicate()
		for i in list.size():
			if list[i] is Dictionary or list[i] is Array:list[i]=ordered(list[i])
		return list
	return value
static func sorted(value: Variant) -> bool:
	if value is Dictionary:
		var keys: Array=value.keys()
		var expect: Array=keys.duplicate();expect.sort()
		return keys==expect and not keys.any(func(k: Variant)->bool:return k is StringName) and value.values().all(sorted)
	if value is Array:return value.all(sorted)
	return true
## One r2 account in facet shape. r2 saved no features, so they stay unknown (empty), never derived from the act;
## the apparent identity, including an unknown one and how it was learned, is kept exactly as saved.
static func r2_account(old: Dictionary) -> Dictionary:
	var a := old.duplicate(true)
	a.features={}
	a=Perception.flatten(Perception.normalized(a))
	if old.get("identity") is Dictionary:a.identity=old.identity.duplicate(true)
	return a
## Acceptance precondition: every receipt and stance row has the residual shape its consumers read.
## Returns "" or the first defect, sorted so the same defect always reports the same way.
static func invalid(v: S.Village) -> String:
	var owners := {}
	for p: S.Person in v.people:owners[key(v,p.id)]=p.mind
	for actor: String in v.actor_minds:owners[actor]=v.actor_minds[actor]
	var names: Array=owners.keys();names.sort()
	for actor: String in names:
		var m: S.Mind=owners[actor]
		for fact: String in m.appraised:
			var r: Variant=m.appraised[fact]
			if not r is Dictionary or not r.has("revision") or not r.get("stance",{}) is Dictionary or not r.get("channels",{}) is Dictionary:
				return "%s receipt %s" % [actor,fact]
		for who: String in m.stances:
			if not m.stances[who] is Dictionary:return "%s stance %s" % [actor,who]
	return ""
## Mutation helper only. Read-only profile/expression never create a generic observer.
static func mind(v: S.Village, actor: String) -> S.Mind:
	var id := resident(v,actor)
	if id>=0:return v.people[id].mind
	if not v.actor_minds.has(actor):v.actor_minds[actor]=S.Mind.new()
	return v.actor_minds[actor]
static func existing_mind(v: S.Village, actor: String) -> S.Mind:
	var id := resident(v,actor)
	return v.people[id].mind if id>=0 else v.actor_minds.get(actor)
static func profile(v: S.Village, actor: String, a: Dictionary, temperament_folders: Array = ["res://scripts/studio/people/temperaments/"], modifier_folders: Array = ["res://scripts/studio/people/modifiers/"]) -> Dictionary:
	var id := resident(v,actor)
	var m := existing_mind(v,actor)
	var target := resident(v,str(a.get("target","unknown")))
	var me := {"key":actor,"courage":50,"temper":50,"alert":50,"law":50,"concern":0,"helper":"","safety":500,
		"modifiers":[],"hits":0,"prior_stances":{}}
	if id>=0:
		var p := v.people[id]
		me.courage=int(p.traits[C.BOLD]);me.temper=int(p.traits[C.TEMPER]);me.alert=int(p.traits[C.ALERT]);me.law=int(p.values[C.V_LAW])
		me.safety=clampi(700-int(p.hurt)*5-int(v.fear)/3,0,1000)
		if target>=0 and target!=id:me.concern=maxi(Rules.opinion(v,id,target),50 if Rules.is_kin(v,id,target) else 0)
		if v.authority>=0 and v.authority!=id and v.people[v.authority].alive and v.people[v.authority].present:me.helper=key(v,v.authority)
	if m!=null:
		me.modifiers=m.modifiers
		var identities: Array=[str(a.get("identity",{}).get("key","unknown"))]
		for candidate: Dictionary in a.get("candidates",[]):identities.append(str(candidate.get("identity",{}).get("key","unknown")))
		me.prior_stances=stance_view(m,tick(v),identities)
		me.hits=int(me.prior_stances.get(str(a.get("identity",{}).get("key","unknown")),{}).get("hits",0))
	me.tuning=Temperament.resolve(me,m.temperament if m!=null else "common",temperament_folders,modifier_folders)
	me.merge(Affect.project(m,tick(v)) if m!=null else {"anger":0,"fear":0,"pain":0,"interest":0,"alertness":0},true)
	me.distraction=distraction(m,int(me.alert)) if m!=null else 0
	return me
## Discovered temperament trait delay plus additive modifiers. No distracted/low-alert branch here.
## The temperament's own delay depends only on (temperament, alert); resolved once per pair (temperaments are data).
static var _base_delay := {}
static func distraction(m: S.Mind, alert := 50, folders: Array = ["res://scripts/studio/people/modifiers/"]) -> int:
	var pair := "%s:%d" % [m.temperament,alert]
	if not _base_delay.has(pair):
		_base_delay[pair]=int(Temperament.resolve({"alert":alert,"modifiers":[]},m.temperament,["res://scripts/studio/people/temperaments/"],[]).get("distraction_ms",0))
	var delay_ms: int=_base_delay[pair]
	var modifiers := {}
	for folder: String in folders:modifiers.merge(Modules.discover(folder),false)
	for row: Dictionary in m.modifiers:
		if modifiers.has(str(row.id)):delay_ms+=clampi(int(modifiers[str(row.id)].new().delay({"alertness":alert},row)),0,30000)
	return mini(delay_ms,30000)
## Integration calls after bounded capture; capture's due is active time, felt harm is immediate.
static func attention_delay(v: S.Village, actor: String, a: Dictionary, folders: Array = ["res://scripts/studio/people/modifiers/"]) -> int:
	var m := existing_mind(v,actor)
	if m==null:return 0
	var me := profile(v,actor,a)
	var tuning := Temperament.resolve(me,m.temperament,["res://scripts/studio/people/temperaments/"],folders)
	return Attention.delay(me,a,m.habituation,tuning,distraction(m,int(me.alert),folders),tick(v))
## S5 consumer contract: unit channels/style, apparent identities only; no clip, destination or helper.
static func hints(m: S.Mind, now := -1, tuning: Dictionary = {}) -> Dictionary:
	var affect := Affect.project(m,int(m.affect_tick) if now<0 else now)
	var out := {}
	for name: String in Affect.CHANNELS:out[name]=float(affect[name])/1000.0
	out.tension=maxf(float(out.anger),float(out.fear))
	out.style={"show":float(tuning.get("show",700))/1000.0,"steady":float(tuning.get("steady",500))/1000.0,
		"pace":float(tuning.get("pace",0))/1000.0,"lean":float(tuning.get("lean",0))/1000.0}
	out.attention=m.attention.duplicate(true)
	out.attention.erase("regard")
	out.regard=[]
	var keys: Array=m.attention.get("regard",[])
	var stances := stance_view(m,int(m.affect_tick) if now<0 else now,keys)
	for who: String in keys:
		if who in ["unknown",""]:continue
		var stance: Dictionary=stances[who]
		out.regard.append({"identity":who,"keep_m":clampf(float(tuning.get("space_mm",1400))/1000.0+float(stance.get("wary",0))/500.0-float(stance.get("trust",0))/2000.0,0.6,4.0),
			"watch":clampf(float(stance.get("wary",0))/1000.0,0,1)})
	return out
static func expression(v: S.Village, actor: String) -> Dictionary:
	var m := existing_mind(v,actor)
	if m==null:return {}
	var me := profile(v,actor,{})
	var out := hints(m,tick(v),me.tuning)
	if tick(v)>int(m.attention.get("until",0)):out.attention={}
	return out
static func learn(v: S.Village, incoming: Dictionary, chooser: RefCounted = null, choose := true, temperament_folders: Array = ["res://scripts/studio/people/temperaments/"], modifier_folders: Array = ["res://scripts/studio/people/modifiers/"]) -> bool:
	var a := Perception.normalized(incoming)
	var m := mind(v,str(a.observer))
	var fact := str(a.deed)+":"+str(a.observer)
	a.key=fact
	var prior: Dictionary=m.known.get(fact,{})
	a=Perception.merge(prior,a,true)
	if a.is_empty():return false
	var receipt: Dictionary=m.appraised.get(fact,{})
	# Revision context excludes its own aggression, and remains the original appraisal basis.
	# profile() is read-only, so it is built only when there is no basis to use instead.
	var me: Dictionary
	if receipt.has("basis"):me=receipt.basis.duplicate(true)
	else:
		me=profile(v,str(a.observer),a,temperament_folders,modifier_folders)
		me.novelty_gain=Attention.novelty_gain(m.habituation,a,tick(v))
	# Observable provocation may be understood later; original context is not a veto on new evidence.
	me.provocation=int(a.get("features",{}).get("provocation",0))
	if str(me.get("identity","unknown"))!=str(a.identity.key):
		me.hits=prior_hits(m,str(a.identity.key),int(receipt.get("ordinal",m.known.size())))
		me.identity=str(a.identity.key)
	if str(me.get("target","unknown"))!=str(a.target):
		me.concern=profile(v,str(a.observer),a).concern
		me.target=str(a.target)
	me.tuning=Temperament.resolve(me,m.temperament,temperament_folders,modifier_folders)
	# Only measured candidate identities need prior beliefs here; never copy a growing stance ledger.
	var candidates := {}
	for candidate: Dictionary in a.get("candidates",[]):
		var who := str(candidate.get("identity",{}).get("key","unknown"))
		candidates[who]=stance_view(m,tick(v),[who]).get(who,{}).duplicate(true)
	me.prior_stances=candidates
	var tuning: Dictionary=me.tuning
	Affect.settle(m,tick(v),tuning)
	settle_stances(m,tick(v))
	var gain := 1000
	var modifiers := {}
	for folder: String in modifier_folders:modifiers.merge(Modules.discover(folder),false)
	for row: Dictionary in me.get("modifiers",[]):
		if modifiers.has(str(row.id)):gain=clampi(gain*int(modifiers[str(row.id)].new().gain(me,a,row))/1000,0,3000)
	var delta := Appraisal.evaluate(me,a,gain)
	var basis := me.duplicate(true)
	for k: String in BASIS_DERIVED:basis.erase(k)
	if receipt.is_empty():receipt={"basis":basis,"revision":0,"channels":{},"stance":{},"counted":false,"tick":tick(v),"ordinal":m.known.size()}
	else:receipt.basis=basis
	Affect.replace(m,receipt,delta)
	replace_stance(m,receipt,a,delta,tick(v),tuning)
	receipt.revision=int(receipt.revision)+1
	receipt.meaning=delta.meaning.duplicate(true)
	m.appraised[fact]=receipt;Affect.note(m,fact)
	a.claim=delta.claim.duplicate(true)
	m.known[fact]=ordered(a)
	var episode: S.Episode=null
	for existing: S.Episode in m.episodes:
		if existing.key==fact:episode=existing
	if episode==null:
		episode=S.Episode.new();episode.key=fact;episode.tick=int(a.get("occurred_tick",tick(v)));m.episodes.append(episode)
	episode.tick=int(a.get("occurred_tick",episode.tick))
	episode.account={};episode.meaning=delta.meaning.duplicate(true)
	episode.place=str(a.get("place",""));episode.severity=int(delta.meaning.severity);episode.event_ref=str(a.get("event_ref",""))
	if m.episodes.size()>16:
		var evicted: S.Episode=m.episodes.pop_front()
		compact(m.known[evicted.key]);m.known[evicted.key]=ordered(m.known[evicted.key])
	if prior.is_empty():Attention.accepted(m.habituation,a,tick(v))
	# Orient to the newly captured observation, never track an actor through an old merged position.
	var actor_facet: Dictionary=incoming.get("facets",{}).get("actor",{})
	var focus: Array=actor_facet.get("at",[]) if str(actor_facet.get("via",""))=="seen" else []
	if focus.size()!=2:focus=incoming.get("at",[])
	m.attention={"at":focus.duplicate(),"watch":minf(1.0,float(delta.alertness)/600.0),"until":tick(v)+3500,"identity":str(actor_facet.get("identity",{}).get("key","unknown")),"regard":regard(m)}
	m.last_tick=tick(v)
	if choose:decide(v,str(a.observer),[a],chooser)
	return true
## Prior knowledge at original admission, not future aggression and never this receipt itself.
static func prior_hits(m: S.Mind, identity: String, before: int) -> int:
	var hits := 0
	if identity in ["unknown",""]:return hits
	for row: Dictionary in m.appraised.values():
		if int(row.get("ordinal",before))<before and row.get("counted",false) and str(row.get("stance",{}).get("identity","unknown"))==identity:hits+=1
	return hits
## Detail beyond16 is removed; semantic facet/revision/provenance keys and residual authority persist.
static func compact(a: Dictionary) -> void:
	for field: String in ["at","candidates","affordances"]:a.erase(field)
	a.compacted=true
	for slot: String in a.get("facets",{}):
		var f: Dictionary=a.facets[slot]
		f.erase("at")
		if f.has("evidence"):f.evidence={"act":str(f.evidence.get("act","")),"condition":str(f.evidence.get("condition",""))}
	a.evidence={"act":str(a.evidence.get("act","")),"condition":str(a.evidence.get("condition",""))}
static func rank(a: Dictionary) -> int:
	return int(Perception.CHANNEL.get(str(a.via),0))
## Selection happens at acceptance, never as another per-frame population scan.
static func regard(m: S.Mind) -> Array:
	var keys: Array=m.stances.keys().filter(func(k)->bool:return str(k) not in ["unknown",""] and int(m.stances[k].get("wary",0))+absi(int(m.stances[k].get("trust",0)))+int(m.stances[k].get("resentment",0))+int(m.stances[k].get("obligation",0))>0)
	keys.sort_custom(func(a,b)->bool:
		var left := int(m.stances[a].get("wary",0))+int(m.stances[a].get("resentment",0))
		var right := int(m.stances[b].get("wary",0))+int(m.stances[b].get("resentment",0))
		return left>right if left!=right else str(a)<str(b))
	return keys.slice(0,3)
## Slow stance rate is integer units/million active ms; fraction survives rate changes.
static func stance_view(m: S.Mind, now: int, identities: Variant = null) -> Dictionary:
	var out := {}
	var keys: Array=m.stances.keys() if identities==null else identities
	for who: String in keys:
		if not m.stances.has(who):continue
		var row: Dictionary=m.stances[who].duplicate(true)
		var elapsed := maxi(0,now-int(row.get("tick",now)))
		var rests: Dictionary=row.get("remainders",{})
		for name: String in STANCES:
			var rate := int(row.get("rates",{}).get(name,33 if name=="wary" else 3))
			var n := int(row.get(name,0))
			var amount := elapsed*rate+int(rests.get(name,0))
			var loss := mini(absi(n),amount/1000000)
			row[name]=n-signi(n)*loss
		row.feeling=clampi(int(row.get("trust",0))+int(row.get("obligation",0))/4-int(row.get("resentment",0))-int(row.get("wary",0))/2,-1000,1000)
		out[who]=row
	return out
## parts: this identity's stance parts in sorted receipt order (stance_parts), when the caller already has them.
static func drain_stance(m: S.Mind, who: String, name: String, amount: int, direction: int, reason: String, parts: Variant = null) -> void:
	if parts==null:parts=stance_parts(m).get(who,[])
	for pair: Array in parts:
		var part: Dictionary=pair[1]
		var trace: Dictionary=part.get("channels",{}).get(name,{})
		var n := int(trace.get("remaining",0))
		if signi(n)!=direction:continue
		var take := mini(amount,absi(n))
		if take>0 or not trace.has("remaining") or not trace.has(reason):Affect.note(m,pair[0])
		trace.remaining=n-direction*take;trace[reason]=int(trace.get(reason,0))+take
		amount-=take
		if amount<=0:break
## Every receipt's stance part as [fact, part], grouped by identity, in sorted receipt order: one sort per settle,
## not per channel.
static func stance_parts(m: S.Mind) -> Dictionary:
	var keys: Array=m.appraised.keys();keys.sort()
	var parts := {}
	for fact: String in keys:
		var part: Dictionary=m.appraised[fact].get("stance",{})
		parts.get_or_add(str(part.get("identity","")),[]).append([fact,part])
	return parts
## Step 4 (M5): receipt keys each mind's learning wrote since clear_written(), {mind instance id: {fact: true}}.
## Mind records every receipt write made during play (learn, Affect.grow/drain, drain_stance); see Affect.note.
static func written() -> Dictionary:
	return Affect.wrote
static func clear_written() -> void:
	Affect.wrote.clear()
## Each channel is projected inline exactly as stance_view does (it depends only on its own value, rate and remainder),
## so no stance row is copied.
static func settle_stances(m: S.Mind, now: int) -> void:
	var parts := stance_parts(m)
	for who: String in m.stances:
		var row: Dictionary=m.stances[who]
		var elapsed := maxi(0,now-int(row.get("tick",now)))
		var rests: Dictionary=row.get_or_add("remainders",{})
		var rates: Dictionary=row.get("rates",{})
		for name: String in STANCES:
			var before := int(row.get(name,0))
			var rate := int(rates.get(name,33 if name=="wary" else 3))
			var after := before-signi(before)*mini(absi(before),(elapsed*rate+int(rests.get(name,0)))/1000000)
			drain_stance(m,who,name,absi(before-after),signi(before),"faded",parts.get(who,[]))
			rests[name]=(elapsed*rate+int(rests.get(name,0)))%1000000 if after!=0 else 0
			row[name]=after
		row.feeling=clampi(int(row.get("trust",0))+int(row.get("obligation",0))/4-int(row.get("resentment",0))-int(row.get("wary",0))/2,-1000,1000)
		row.tick=maxi(now,int(row.get("tick",now)))
static func replace_stance(m: S.Mind, receipt: Dictionary, a: Dictionary, delta: Dictionary, now: int, tuning: Dictionary) -> void:
	var who := str(a.identity.key)
	if who in ["unknown",""]:who=str(delta.claim.get("identity",{}).get("key","unknown"))
	if who in ["unknown",""]:return
	var part: Dictionary=receipt.get_or_add("stance",{})
	var previous := str(part.get("identity",who))
	if previous!=who:
		var previous_row: Dictionary=m.stances.get(previous,{})
		for name: String in STANCES:previous_row[name]=clampi(int(previous_row.get(name,0))-int(part.get("channels",{}).get(name,{}).get("remaining",0)),-1000,1000)
		if receipt.get("counted",false):previous_row.hits=maxi(0,int(previous_row.get("hits",0))-1)
		part.clear();receipt.counted=false
	part.identity=who
	var row: Dictionary=m.stances.get_or_add(who,{"wary":0,"trust":0,"resentment":0,"obligation":0,"hits":0,"feeling":0,"tick":now,"remainders":{}})
	row.rates={}
	for name: String in STANCES:row.rates[name]=int(tuning.get(name+"_rate",33 if name=="wary" else 3))
	var channels: Dictionary=part.get_or_add("channels",{})
	for name: String in STANCES:
		var wanted := int(delta.stance.get(name,0))
		var trace: Dictionary=channels.get(name,{})
		var old := int(trace.get("remaining",0))
		var base := int(row.get(name,0))-old
		var direction := signi(wanted)
		var lower := -1000 if name=="trust" else 0
		var capacity := int(trace.get("capacity",1000-base if direction>=0 else base-lower))
		var used := int(trace.get("neutralized",0))+int(trace.get("faded",0))+int(trace.get("relief",0))
		var desired := maxi(0,mini(absi(wanted),capacity)-used)
		var relief := mini(desired,absi(base)) if signi(base)!=direction and base!=0 else 0
		if relief>0:
			drain_stance(m,who,name,relief,signi(base),"relief")
			base+=direction*relief;desired-=relief
		var applied := clampi(base+direction*desired,lower,1000)-base
		channels[name]={"wanted":wanted,"remaining":applied,"capacity":maxi(0,capacity-(desired-absi(applied))),"neutralized":int(trace.get("neutralized",0))+relief,
			"faded":int(trace.get("faded",0)),"relief":int(trace.get("relief",0))}
		row[name]=base+applied
	if bool(delta.aggression) and not bool(receipt.counted):
		row.hits=int(row.hits)+1;receipt.counted=true;row.last_deed=str(a.deed)
	row.feeling=clampi(int(row.trust)+int(row.obligation)/4-int(row.resentment)-int(row.wary)/2,-1000,1000)
static func ongoing(plan: Dictionary, now: int) -> bool:
	return not plan.is_empty() and int(plan.get("until",0))>now and int(plan.get("phase",0))<Array(plan.get("steps",[])).size()
## Bounded working context is a reference to an accepted felt need, not another choice/urgency policy.
static func self_context(m: S.Mind, actor: String, accounts: Array, now: int) -> String:
	var key := str(m.plan.get("self_account","")) if ongoing(m.plan,now) else ""
	for a: Dictionary in accounts:
		if str(a.get("target","unknown"))!=actor:continue
		for f: Dictionary in a.get("facets",{}).values():
			var features: Dictionary=f.get("features",{})
			if str(f.get("via",""))=="felt" and maxi(int(features.get("felt_harm",0)),int(features.get("threat",0)))>0:
				key=str(a.deed)+":"+actor;break
	return key
static func decision_accounts(m: S.Mind, actor: String, accounts: Array, now: int) -> Array:
	var out := [];var seen := {}
	for a: Dictionary in accounts:
		var key := str(a.deed)+":"+actor
		if not seen.has(key):out.append(m.known.get(key,a));seen[key]=true
	if not ongoing(m.plan,now):return out
	var keys: Array=[str(m.plan.get("account",""))]
	var affect := Affect.project(m,now)
	if int(affect.pain)>0 or int(affect.fear)>0:keys.append(str(m.plan.get("self_account","")))
	for key: String in keys:
		if key.is_empty() or seen.has(key) or not m.known.has(key):continue
		out.append(m.known[key]);seen[key]=true
	return out
## Cosmetic wording/observation payload can change without replacing a physical or report destination.
## Codec canonicalizes whole floats to ints. Numeric values of semantic parameters remain equivalent.
static func same_value(left: Variant, right: Variant) -> bool:
	if (left is int or left is float) and (right is int or right is float):return left==right
	if left is Dictionary and right is Dictionary:
		if left.size()!=right.size():return false
		for key in left:
			if not right.has(key) or not same_value(left[key],right[key]):return false
		return true
	if left is Array and right is Array:
		if left.size()!=right.size():return false
		for i in left.size():
			if not same_value(left[i],right[i]):return false
		return true
	return left==right
static func actionable(step: Dictionary) -> Dictionary:
	var out := step.duplicate(true)
	if str(out.get("op",""))=="report":out.erase("account")
	if str(out.get("op",""))=="say":out.erase("text")
	return out
static func same_intent(plan: Dictionary, choice: Dictionary, control: Dictionary, now: int) -> bool:
	if not ongoing(plan,now) or str(plan.offer)!=str(choice.offer) or str(plan.deed)!=str(choice.account.deed):return false
	if not same_value(plan.get("control",control),control) or not same_value(plan.get("effects",{}),choice.get("effects",{})):return false
	var duration := roundi(float(choice.lasts)*1000.0)
	if int(plan.get("duration_ms",duration))!=duration:return false
	var steps: Array=choice.steps
	if Array(plan.steps).size()!=steps.size():return false
	for i in range(int(plan.phase),steps.size()):
		if not same_value(actionable(plan.steps[i]),actionable(steps[i])):return false
	return true
static func decide(v: S.Village, actor: String, accounts: Array, chooser: RefCounted = null) -> void:
	var id := resident(v,actor)
	if id>=0 and not v.people[id].alive:return
	var m := mind(v,actor)
	var engine = Chooser.new() if chooser==null else chooser
	var contexts := decision_accounts(m,actor,accounts,tick(v))
	var choice: Dictionary=engine.pick_many(contexts,func(a: Dictionary)->Dictionary:return profile(v,actor,a))
	if not choice.is_empty():
		var a: Dictionary=choice.account
		# Chooser owns instruction evaluation. Until it exposes the effective instruction, changed
		# saved modifier inputs conservatively replace; no second call to modifier.choose here.
		var control: Dictionary={"instruction":choice.instruction.duplicate(true)} if choice.has("instruction") else {"inputs":m.modifiers.duplicate(true)}
		var self_account := self_context(m,actor,accounts,tick(v))
		if same_intent(m.plan,choice,control,tick(v)):
			for i in range(int(m.plan.phase),Array(choice.steps).size()):m.plan.steps[i]=choice.steps[i].duplicate(true)
			m.plan.self_account=self_account;m.plan.control=control
			return
		m.generation+=1
		m.plan={"offer":choice.offer,"deed":str(a.deed),"account":str(a.deed)+":"+actor,"phase":0,"generation":m.generation,
			"steps":choice.steps,"effects":choice.effects,"self_account":self_account,"control":control,
			"duration_ms":roundi(float(choice.lasts)*1000.0),"until":tick(v)+roundi(float(choice.lasts)*1000.0)}
## learn_limit >= 0 (step 4 frame budget): learn at most that many ready-now portions, whole witnesses at a time in the
## order given (the first witness always, so one with more portions than the budget still progresses). Every other
## ready-now portion is stored, unchanged and already due, in its observer's saved pending, as a waiting portion is, and
## People.ready hands it back on a later frame. A deferred portion learns at that frame's tick, as every attention-delayed portion
## does; its account keeps the captured and occurred ticks. Returns the accounts learned.
static func admit(v: S.Village, accounts: Array, learn_limit := -1) -> Array:
	var ready_accounts := [];var observers := {};var ready_by_key := {}
	# An incoming account identical to one already taken in this call changes nothing (its waiting part is covered,
	# its ready part merges to nothing, attention is set to the same values), so it is not processed again.
	var taken := {}
	for incoming: Dictionary in accounts:
		var same: Array=taken.get_or_add(str(incoming.get("deed",""))+":"+str(incoming.get("observer","")),[])
		if same.any(func(x: Dictionary)->bool:return x==incoming):continue
		same.append(incoming)
		var a := Perception.normalized(incoming)
		a.key=str(a.deed)+":"+str(a.observer)
		var m := mind(v,str(a.observer))
		var waiting := Perception.portion(a,tick(v),false)
		if not waiting.is_empty():
			var covered := false
			for pending: Dictionary in m.pending:
				if str(pending.key)==str(a.key) and Perception.covers(pending,waiting):covered=true;break
			if not covered:m.pending.append(waiting)
			# Orient to a captured location without yet accusing or choosing a destination.
			m.attention={"at":a.get("at",[]).duplicate(),"watch":0.3,"until":int(waiting.due)+3500,"identity":"unknown","regard":m.attention.get("regard",[])}
		a=Perception.portion(a,tick(v),true)
		if a.is_empty():continue
		var joined := Perception.merge(ready_by_key.get(str(a.key),{}),a,Perception.normal(a))
		if not joined.is_empty():ready_by_key[str(a.key)]=joined
	# Join only ready evidence; one appraisal and one chooser batch per observer at this acceptance.
	var order: Array=ready_by_key.values()
	if learn_limit>=0:order=budgeted(v,order,learn_limit)
	for a: Dictionary in order:
		var m := mind(v,str(a.observer))
		if learn(v,a,null,false):
			var accepted: Dictionary=m.known[a.key]
			ready_accounts.append(accepted)
			(observers.get_or_add(str(a.observer),[]) as Array).append(accepted)
	for actor: String in observers:decide(v,actor,observers[actor])
	return ready_accounts
## The ready portions to learn now under a limit, whole witnesses in first-appearance order; the rest wait in their
## observer's pending, already due (unless an equal or stronger pending version already covers them).
static func budgeted(v: S.Village, portions: Array, limit: int) -> Array:
	var groups := {}
	for a: Dictionary in portions:(groups.get_or_add(str(a.observer),[]) as Array).append(a)
	var now := [];var taken := 0;var open := true
	for observer: String in groups:
		var group: Array=groups[observer]
		if open and (taken+group.size()<=limit or (taken==0 and limit>0)):
			now.append_array(group);taken+=group.size();continue
		open=false # in order: once a witness waits, every later one waits too
		var m := mind(v,observer)
		for a: Dictionary in group:
			# A ready portion's due is already at or before now, so People.ready returns it; it is kept as captured.
			var covered := false
			for pending: Dictionary in m.pending:
				if str(pending.key)==str(a.key) and Perception.covers(pending,a):covered=true;break
			if not covered:m.pending.append(a)
	return now
static func ready(v: S.Village) -> Array:
	var accounts := []
	for p in v.people:
		for a: Dictionary in p.mind.pending:
			if int(a.due)<=tick(v):accounts.append(a)
	for m: S.Mind in v.actor_minds.values():
		for a: Dictionary in m.pending:
			if int(a.due)<=tick(v):accounts.append(a)
	return accounts
## Cached by bridge after checked changes/load. Settling has no deadline/frame save.
static func next_due(v: S.Village) -> int:
	var due := 9223372036854775807
	var minds: Array=[]
	for p in v.people:minds.append(p.mind)
	minds.append_array(v.actor_minds.values())
	for m: S.Mind in minds:
		for a: Dictionary in m.pending:due=mini(due,int(a.due))
	return due
## learn_limit: see admit. -1 learns everything ready now (the path before step 4's frame budget).
static func flush(v: S.Village, accounts: Array, learn_limit := -1) -> Array:
	# Keep differently timed versions intact until admit partitions them. Later sight cannot defer a cry.
	var captures := accounts.duplicate(true);var touched := {}
	for a: Dictionary in accounts:
		var fact := str(a.deed)+":"+str(a.observer)
		var m := mind(v,str(a.observer))
		if touched.has(fact):continue
		touched[fact]=true
		for pending: Dictionary in m.pending:
			if str(pending.key)==fact:captures.append(pending)
		m.pending=m.pending.filter(func(p: Dictionary)->bool:return str(p.key)!=fact)
	return admit(v,captures,learn_limit)
## Bounded consumer record for later Choice/Justice mapping. No fake numeric crime or truth lookup.
static func witness_record(v: S.Village, observer: String, deed: String) -> Dictionary:
	var m := existing_mind(v,observer)
	if m==null:return {}
	var a: Dictionary=m.known.get(deed+":"+observer,{})
	if a.is_empty():return {}
	return {"deed":deed,"event_ref":str(a.get("event_ref","")),"observer":observer,"identity":a.identity.duplicate(true),
		"subject":a.get("subject",{}).duplicate(true),"via":str(a.via),"facets":a.get("facets",{}).duplicate(true),"claim":a.get("claim",{}).duplicate(true),
		"reported_claim":a.get("reported_claim",{}).duplicate(true),
		"transmissions":a.get("transmissions",[]).duplicate(true)}
