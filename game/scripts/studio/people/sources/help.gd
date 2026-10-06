extends "res://scripts/studio/people/source.gd"
const ID := "help"
func make(actor: String,target: String,at: Array,fields: Dictionary) -> Dictionary:
	return record(ID,actor,target,at,12.0,600,1200,
		{"act":"help","method":str(fields.get("method",""))},
		{"assistance":600,"novelty":300},{"act":"water","features":{"novelty":200}})
