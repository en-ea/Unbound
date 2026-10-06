extends "res://scripts/studio/people/source.gd"
const ID := "cry"
const NOTICE := {"facts":["hurt","down","burning"]}
func make(actor: String,target: String,at: Array,fields: Dictionary) -> Dictionary:
	var s := record(ID,actor,target,at,36.0,clampi(int(fields.get("strength",600)),0,1000),800,
		{"act":"cry"},{"harm":250,"novelty":600},
		{"act":"cry","features":{"threat":250,"novelty":600}})
	s.actor=""
	return s
