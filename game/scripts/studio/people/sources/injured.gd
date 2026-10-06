extends "res://scripts/studio/people/source.gd"
## P1 later sight of an accepted injury snapshot; no replayed contact, live-health query or culprit.
## The normal NOTICE discovery uses the hurt fact's validated deed/revision and current body geometry.
const ID := "injured"
const NOTICE := {"facts":["hurt"],"persistent":true}
func make(actor: String,target: String,at: Array,fields: Dictionary) -> Dictionary:
	var hurt := clampi(int(fields.get("strength",0)),0,1000)
	var s := record(ID,actor,target,at,18.0,hurt,1500,
		{"act":"bruise","condition":"injured","where":str(fields.get("where","body"))},
		{"harm":hurt,"felt_harm":hurt,"threat":0,"novelty":300},{})
	s.actor=""
	s["hearing_reach"]=0.0
	return s
