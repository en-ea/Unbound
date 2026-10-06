extends "res://scripts/studio/people/source.gd"
## P1 actual contact. Act/force/harm are independent of input binding.
const ID := "contact"
func make(actor: String, target: String, at: Array, fields: Dictionary) -> Dictionary:
	var damage := clampi(int(fields.get("damage",1)),0,5)
	var act := str(fields.get("act","strike"))
	var force := clampi(int(fields.get("force",(850 if fields.get("heavy",false) else 450) if act in ["strike","shove"] else 0)),0,1000)
	var harm := clampi(damage*140 if act=="strike" else int(fields.get("harm",4))*10 if act=="shove" else 0,0,1000)
	return record(ID,actor,target,at,18.0,maxi(force,harm),600,
		{"act":act,"force":force,"harm":harm,"heavy":force>=750},
		{"harm":harm,"threat":force,"novelty":500},
		{"act":"impact","features":{"novelty":500,"threat":200}})
