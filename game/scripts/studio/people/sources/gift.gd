extends "res://scripts/studio/people/source.gd"
const ID := "gift"
func make(actor: String,target: String,at: Array,fields: Dictionary) -> Dictionary:
	var count := clampi(int(fields.get("count",1)),1,20)
	return record(ID,actor,target,at,8.0,400,1500,
		{"act":"gift","item":str(fields.get("item","")),"count":count},
		{"assistance":mini(1000,count*220),"novelty":100},{})
