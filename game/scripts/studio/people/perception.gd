extends RefCounted
## P2/P3 bounded capture; no source truth, world query or choice crosses this boundary.
## Facets separate act/condition/apparent roles/report. Delayed processing preserves genuine capture.
## merge joins per-facet evidence; retell downgrades every facet, preserving origin and speaker.
const UNKNOWN := {"key":"unknown","name":"someone","learned":"unknown"}
const CHANNEL := {"unknown":0,"heard":1,"told":2,"seen":3,"felt":4}
static func account(observer: String, stimulus: Dictionary, sensor: Dictionary, appearance: Dictionary, key: String) -> Dictionary:
	var seen := bool(sensor.get("seen_event",sensor.get("seen",false)))
	var felt := observer == str(stimulus.get("target",""))
	var heard := bool(sensor.get("heard",false))
	if not seen and not felt and not heard:return {}
	var via := "felt" if felt else "seen" if seen else "heard"
	var actor_seen := seen and bool(sensor.get("seen_actor",sensor.get("seen",false))) and not bool(sensor.get("aftermath",false))
	var shown := recognized(appearance,"seen",bool(sensor.get("recognized_actor",true))) if actor_seen else UNKNOWN.duplicate()
	var subject := recognized(sensor.get("subject_identity",{"key":str(stimulus.get("target","unknown")),"name":"someone"}),"seen",bool(sensor.get("recognized_subject",true))) if bool(sensor.get("seen_subject",seen)) else UNKNOWN.duplicate()
	if felt:subject=identity({"key":observer,"name":"me"},"felt")
	var emitter := recognized(sensor.get("emitter_identity",UNKNOWN),"seen",bool(sensor.get("recognized_emitter",true))) if bool(sensor.get("seen_source",false)) else UNKNOWN.duplicate()
	var full := seen or felt
	var evidence: Dictionary=stimulus.get("evidence",{}).duplicate(true) if full else {"act":str(stimulus.get("heard",{}).get("act","commotion"))}
	var features: Dictionary=stimulus.get("features",{}) if full else stimulus.get("heard",{}).get("features",{})
	features=bounded_features(features)
	if features.is_empty():features=legacy_features(evidence,int(stimulus.get("strength",0)))
	# Hearing carry already includes distance/walls; render/camera visibility grants no hearing identity.
	if not felt:
		var gain := clampf(float(sensor.get("gain",sensor.get("carry",0.5))),0.0,1.0)
		for name: String in features:features[name]=roundi(float(features[name])*gain)
	# Source declares felt_harm for anonymous conditions; a cry is distress, not a second injury.
	features.felt_harm=int(features.get("felt_harm",features.get("harm",0) if felt and not str(stimulus.get("actor",stimulus.get("source",""))).is_empty() else 0)) if felt else 0
	var captured := int(sensor.get("captured_tick",sensor.get("tick",0)))
	var occurred := int(sensor.get("occurred_tick",stimulus.get("tick",captured)))
	var a := {"key":key,"observer":observer,"deed":str(stimulus.get("deed","")),"kind":str(stimulus.get("kind","")),
		"identity":shown,"subject":subject,"emitter":emitter,"target":str(subject.key),"at":stimulus.get("at",[]).duplicate(),
		"strength":clampi(int(stimulus.get("strength",0)) if felt else roundi(float(stimulus.get("strength",0))*float(sensor.get("gain",0.5))),0,1000),
		"evidence":evidence,"features":features,"via":via,"captured_tick":captured,"occurred_tick":occurred,
		"due":captured if felt else int(sensor.get("due",captured)),"event_ref":str(stimulus.get("event_ref","")),"place":str(sensor.get("place",stimulus.get("place",""))),
		"notice_id":str(stimulus.get("notice_id",stimulus.get("deed",""))),"revision":int(stimulus.get("revision",0)),"facets":{},"candidates":[]}
	var condition := str(evidence.get("condition",""))
	if condition.is_empty() and (bool(sensor.get("aftermath",false)) or str(stimulus.get("actor",stimulus.get("source",""))).is_empty()):condition=str(evidence.get("act","condition"))
	var slot := "act" if condition.is_empty() else "condition:"+condition
	a.facets[slot]=facet(a,via)
	if str(shown.key)!="unknown":a.facets.actor=role(shown,a,"seen")
	if str(subject.key)!="unknown":a.facets.subject=role(subject,a,str(subject.learned))
	if str(emitter.key)!="unknown":a.facets.emitter=role(emitter,a,"seen")
	for pair: Array in [["actor","actor_at"],["subject","subject_at"],["emitter","emitter_at"]]:
		if a.facets.has(pair[0]) and sensor.get(pair[1]) is Array and sensor[pair[1]].size()==2:a.facets[pair[0]].at=sensor[pair[1]].duplicate()
	if bool(sensor.get("aftermath",false)):
		for row: Dictionary in sensor.get("candidates",[]).slice(0,3):
			var who := identity(row.get("identity",UNKNOWN),"inferred")
			if str(who.key)=="unknown":continue
			var learned := str(row.get("via","seen"))
			if learned not in ["seen","heard","told"]:learned="seen"
			a.candidates.append({"identity":who,"confidence":clampi(int(row.get("confidence",0)),0,450),"basis":Array(row.get("basis",[])).slice(0,3),
				"via":learned,"speaker":str(row.get("speaker","")) if learned=="told" else ""})
	return a
static func identity(shown: Dictionary, via: String) -> Dictionary:
	var who := str(shown.get("key","unknown"))
	return {"key":who,"name":str(shown.get("name","someone")),"learned":via,"recognition":"unknown" if who=="unknown" else "appearance" if who.begins_with("look:") else "known"}
static func recognized(shown: Dictionary, via: String, named: bool) -> Dictionary:
	# An unrecognised body grants no civil identity. A distinguishable mask remains an appearance.
	return identity(shown,via) if named or str(shown.get("key","unknown")).begins_with("look:") else UNKNOWN.duplicate()
static func bounded_features(input: Dictionary) -> Dictionary:
	var out := {}
	for name: String in ["harm","felt_harm","threat","assistance","novelty","provocation"]:
		if input.has(name):out[name]=clampi(int(input[name]),0,1000)
	return out
## Narrow direct-fixture adapter, not an old-format save migration.
static func legacy_features(e: Dictionary, strength: int) -> Dictionary:
	var act := str(e.get("act",""))
	return {"harm":strength if act in ["strike","burn"] else 0,"felt_harm":strength if act in ["strike","burn"] else 0,"threat":strength if act in ["strike","shove","threat","burn"] else 0,
		"assistance":220 if act=="gift" else 0,"novelty":200}
static func facet(a: Dictionary, via: String) -> Dictionary:
	return {"via":via,"origin_via":str(a.get("origin_via",via)),"speaker":str(a.get("speaker","")),"confidence":1000 if via in ["seen","felt"] else 500,
		"kind":str(a.kind),"evidence":a.evidence.duplicate(true),"features":a.get("features",{}).duplicate(true),"strength":int(a.strength),
		"captured_tick":int(a.get("captured_tick",0)),"occurred_tick":int(a.get("occurred_tick",0)),"due":int(a.get("due",0)),
		"notice_id":str(a.get("notice_id",a.deed)),"revision":int(a.get("revision",0))}
static func role(who: Dictionary, a: Dictionary, via: String) -> Dictionary:
	var f := facet(a,via)
	f.identity=who.duplicate(true)
	f.erase("evidence");f.erase("features")
	return f
static func normalized(input: Dictionary) -> Dictionary:
	var a := input.duplicate(true)
	# Direct conformance callers can deliberately create another act from a fixture copy.
	# A production condition has its own condition facet and never changes an act's semantic kind.
	if a.has("facets") and a.facets.has("act") and str(a.facets.act.kind)!=str(a.kind) and not a.facets.keys().any(func(k)->bool:return str(k).begins_with("condition:")):
		a.erase("facets");a.erase("features")
	if not a.has("facets"):
		a.features=bounded_features(a.get("features",legacy_features(a.get("evidence",{}),int(a.get("strength",0)))))
		a.facets={"act":facet(a,str(a.via))}
		if str(a.identity.key)!="unknown":a.facets.actor=role(a.identity,a,str(a.via))
		if str(a.get("target","unknown"))!="unknown":a.facets.subject=role(identity({"key":a.target},str(a.via)),a,str(a.via))
	# Existing report adapter changes top-level via; direct facets inside that copy must downgrade.
	if str(a.via)=="told" and a.facets.values().any(func(f: Dictionary)->bool:return str(f.via)!="told"):
		a=retell(a,str(a.get("speaker","unknown")),str(a.observer),int(a.get("due",0)))
	return a
static func better(fresh: Dictionary, old: Dictionary) -> bool:
	if old.is_empty():return true
	var n := int(CHANNEL.get(str(fresh.via),0));var o := int(CHANNEL.get(str(old.via),0))
	if n!=o:return n>o
	if int(fresh.get("revision",0))!=int(old.get("revision",0)):return int(fresh.get("revision",0))>int(old.get("revision",0))
	for name: String in fresh.get("features",{}):
		if int(fresh.features[name])>int(old.get("features",{}).get(name,0)):return true
	return int(fresh.get("confidence",0))>int(old.get("confidence",0)) or int(fresh.get("strength",0))>int(old.get("strength",0))
## Pending coverage also requires an earlier processing deadline. Future sight cannot swallow ready hearing.
static func covers(existing: Dictionary, incoming: Dictionary) -> bool:
	for slot: String in incoming.facets:
		var old: Dictionary=existing.get("facets",{}).get(slot,{})
		var fresh: Dictionary=incoming.facets[slot]
		if old.is_empty() or better(fresh,old):return false
		if maxi(int(existing.due),int(old.get("due",existing.due)))>maxi(int(incoming.due),int(fresh.get("due",incoming.due))):return false
	return true
## normal: incoming already came through normalized() (idempotent), so it is not copied and normalized again.
static func merge(prior: Dictionary, incoming: Dictionary, normal := false) -> Dictionary:
	var a := incoming if normal else normalized(incoming)
	if prior.is_empty():return flatten(a)
	var out := prior.duplicate(true)
	var changed := false
	for slot: String in a.facets:
		if better(a.facets[slot],out.get("facets",{}).get(slot,{})):
			out.facets[slot]=a.facets[slot].duplicate(true);changed=true
	if not changed:return {}
	for field: String in ["event_ref","place","at","affordances","candidates"]:
		if a.has(field) and not a[field] in ["",[],{}]:out[field]=a[field].duplicate(true) if a[field] is Array or a[field] is Dictionary else a[field]
	out.due=mini(int(prior.get("due",0)),int(a.get("due",0)))
	return flatten(out)
static func flatten(a: Dictionary) -> Dictionary:
	var facts: Dictionary=a.facets
	var chosen: Dictionary=facts.get("act",{})
	var features := {}
	var feature_via := {}
	for slot: String in facts:
		var f: Dictionary=facts[slot]
		if not f.has("features"):continue
		for name: String in f.features:
			if int(f.features[name])>int(features.get(name,-1)) or (int(f.features[name])==int(features.get(name,0)) and int(CHANNEL.get(str(f.via),0))>int(CHANNEL.get(str(feature_via.get(name,"unknown")),0))):
				features[name]=int(f.features[name]);feature_via[name]=str(f.via)
		if chosen.is_empty() or (slot!="act" and not facts.has("act") and int(f.get("strength",0))>int(chosen.get("strength",0))):chosen=f
	if not chosen.is_empty():
		a.kind=chosen.kind;a.evidence=chosen.evidence.duplicate(true);a.via=chosen.via;a.strength=chosen.strength
		a.occurred_tick=int(chosen.get("occurred_tick",a.get("occurred_tick",0)))
	a.features=features
	a.feature_via=feature_via
	a.identity=facts.get("actor",{}).get("identity",UNKNOWN).duplicate(true)
	a.subject=facts.get("subject",{}).get("identity",UNKNOWN).duplicate(true)
	a.emitter=facts.get("emitter",{}).get("identity",UNKNOWN).duplicate(true)
	a.target=str(a.subject.key)
	return a
## Processing portions retain capture provenance; a fresh facet never inherits an earlier deadline.
static func portion(input: Dictionary, now: int, ready: bool) -> Dictionary:
	# Choose the facets first: nothing is copied when none qualifies, and the facets are copied once.
	var base := int(input.get("due",0))
	var slots := []
	var next := 9223372036854775807
	for slot: String in input.facets:
		var due := maxi(base,int(input.facets[slot].get("due",base)))
		if (due<=now)==ready:slots.append(slot);next=mini(next,due)
	if slots.is_empty():return {}
	var a := {}
	for k: Variant in input:
		var x: Variant=input[k]
		a[k]={} if str(k)=="facets" else x.duplicate(true) if (x is Dictionary or x is Array) else x
	for slot: Variant in slots:a.facets[slot]=input.facets[slot].duplicate(true)
	a.due=next
	if base>now:a.candidates=[]
	return flatten(a)
## True when normalized(a) would change nothing but make a copy: a caller that owns a may then skip that copy.
static func normal(a: Dictionary) -> bool:
	if not a.has("facets"):return false
	if a.facets.has("act") and str(a.facets.act.kind)!=str(a.kind) and not a.facets.keys().any(func(k)->bool:return str(k).begins_with("condition:")):return false
	return not (str(a.via)=="told" and a.facets.values().any(func(f: Dictionary)->bool:return str(f.via)!="told"))
static func retell(input: Dictionary, speaker: String, listener: String, now: int) -> Dictionary:
	var a := input.duplicate(true)
	var origin := str(a.get("origin_via",a.get("via","heard")))
	var claimed: Dictionary=a.get("claim",{}).duplicate(true)
	if not claimed.is_empty():
		claimed.merge({"speaker":speaker,"via":"told"},true);a.reported_claim=claimed
	for candidate: Dictionary in a.get("candidates",[]):
		candidate.origin_via=str(candidate.get("origin_via",candidate.get("via","seen")))
		candidate.via="told";candidate.speaker=speaker
		candidate.confidence=mini(450,int(candidate.get("confidence",0)))
	var chain: Array=a.get("transmissions",[]).duplicate(true)
	var hop := {"speaker":speaker,"tick":now,"origin_via":origin}
	if chain.is_empty() or chain[-1]!=hop:chain.append(hop)
	if chain.size()>4:chain.pop_front()
	a.merge({"key":str(a.deed)+":"+listener,"observer":listener,"via":"told","origin_via":origin,"speaker":speaker,"transmissions":chain,"due":now,"captured_tick":now},true)
	a.identity=identity(a.identity,"told")
	if not a.has("facets"):a.facets={"act":facet(a,"told")}
	for slot: String in a.facets:
		var f: Dictionary=a.facets[slot]
		f.origin_via=str(f.get("origin_via",f.via));f.via="told";f.speaker=speaker;f.confidence=mini(500,int(f.get("confidence",500)))
		f.due=now;f.captured_tick=now
		if f.has("identity"):f.identity.learned="told"
	return flatten(a)
