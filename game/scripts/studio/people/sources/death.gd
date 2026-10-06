extends "res://scripts/studio/people/source.gd"
## Sight establishes a corpse; no hearing claim or secretly known killer.
const ID := "death"
const NOTICE := {"facts":["dead"],"persistent":true}
func make(actor: String,target: String,at: Array,_fields: Dictionary) -> Dictionary:
	var s := record(ID,actor,target,at,24.0,900,2000,{"act":"death","condition":"dead"},
		{"harm":900,"novelty":800},{})
	s.actor=""
	s["hearing_reach"]=0.0
	return s
