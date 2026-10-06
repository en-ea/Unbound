extends RefCounted
## P1 pure producer: ID, make(actor,subject,at [x,z] metres,fields)->record.
## Record {kind,source emitter ref,actor alleged doer ref or "",subject,target,at,reach,
## strength 0..1000,window_ms,features,evidence,heard}. Only observable features, no hidden histories.
## Bridge adds opaque deed/cause_id/notice_id/event_ref, geometry and occurrence time.
## Body notices name their emitter/subject, never infer an aggressor from the authoritative cause.
## features {harm,threat,assistance,novelty,felt_harm?} are bounded 0..1000 semantic cues.
## felt_harm declares experienced harm; anonymous cries/falls default0, continuing heat declares it.
## One new stimulus is one file in sources/ through Modules.discover; publish only after checked acceptance.
## Optional NOTICE={facts:[saved kind IDs],transition?:bool,posture?:String,persistent?:bool}.
## It authorises observation of a validated accepted fact, never creation of the fact or culpability.
func make(actor: String, target: String, at: Array, fields: Dictionary) -> Dictionary:
	return record(str(get_script().get_script_constant_map().get("ID","")),actor,target,at,
		18.0,1000,600,fields,{},{})
func record(kind: String, actor: String, subject: String, at: Array, reach: float, strength: int,
		window_ms: int, evidence: Dictionary, features: Dictionary, heard: Dictionary) -> Dictionary:
	return {"kind":kind,"source":actor,"actor":actor,"subject":subject,"target":subject,
		"at":at.duplicate(),"reach":reach,"strength":clampi(strength,0,1000),"window_ms":window_ms,
		"evidence":evidence.duplicate(true),"features":features.duplicate(true),"heard":heard.duplicate(true)}
