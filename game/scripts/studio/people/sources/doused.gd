extends "res://scripts/studio/people/source.gd"
const ID := "doused"
const NOTICE := {"facts":["doused"]}
func make(actor: String,target: String,at: Array,fields: Dictionary) -> Dictionary:
	var s := record(ID,actor,target,at,12.0,500,1200,
		{"act":"doused","method":str(fields.get("method",""))},{"novelty":250},
		{"act":"water","features":{"novelty":150}})
	s.actor=""
	return s
