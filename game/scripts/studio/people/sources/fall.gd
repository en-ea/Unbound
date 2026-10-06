extends "res://scripts/studio/people/source.gd"
## A caused, physically begun fall is evidence about the sufferer; it names no aggressor.
const ID := "fall"
const NOTICE := {"facts":["down"],"transition":true,"posture":"down"}
func make(actor: String,target: String,at: Array,fields: Dictionary) -> Dictionary:
	var s := record(ID,actor,target,at,22.0,clampi(int(fields.get("strength",fields.get("force",600))),0,1000),1200,
		{"act":"fall","condition":"down"},{"harm":300,"novelty":500},
		{"act":"fall","features":{"novelty":400}})
	s.actor=""
	return s
