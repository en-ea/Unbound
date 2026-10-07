extends "res://scripts/studio/people/source.gd"
const ID := "gift"
func make(actor: String,target: String,at: Array,fields: Dictionary) -> Dictionary:
	var count := clampi(int(fields.get("count",1)),1,20)
	var evidence := {"act":"gift","item":str(fields.get("item","")),"count":count}
	# A ported resident's gift (ported.gd): what it is worth to his tally, 2 a loved gift and 1 another, read from his entry.
	if fields.has("worth"):evidence.worth=clampi(int(fields.worth),0,2)
	return record(ID,actor,target,at,8.0,400,1500,evidence,
		{"assistance":mini(1000,count*220),"novelty":100},{})
