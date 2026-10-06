extends "res://scripts/studio/people/source.gd"
const ID := "threat"
func make(actor: String,target: String,at: Array,_fields: Dictionary) -> Dictionary:
	return record(ID,actor,target,at,18.0,600,1000,{"act":"threat"},
		{"threat":600,"novelty":400},{"act":"commotion","features":{"novelty":150}})
