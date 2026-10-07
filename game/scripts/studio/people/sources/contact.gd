extends "res://scripts/studio/people/source.gd"
## P1 actual contact. Act/force/harm are independent of input binding.
const ID := "contact"
func make(actor: String, target: String, at: Array, fields: Dictionary) -> Dictionary:
	var damage := clampi(int(fields.get("damage",1)),0,5)
	var act := str(fields.get("act","strike"))
	var force := clampi(int(fields.get("force",(850 if fields.get("heavy",false) else 450) if act in ["strike","shove"] else 0)),0,1000)
	var harm := clampi(damage*140 if act=="strike" else int(fields.get("harm",4))*10 if act=="shove" else 0,0,1000)
	# Hold Heavy on a downed person (people_actions "finish", 6 Oct): a killing, the gravest harm a hand does.
	if act=="finish":
		force=1000;harm=1000
	# The Tidecaller (6 Oct, desk 06:10): a person lifted in a water sphere is an assault like a blow; held to drown,
	# a killing. Ice on a person is an assault. A soaking (wet) is neither: no harm, no threat.
	var drown: bool=act=="hold" and bool(fields.get("drown",false))
	if act=="hold":
		force=1000 if drown else 700;harm=1000 if drown else 420
	elif act=="freeze":
		force=600;harm=420
	var evidence := {"act":act,"force":force,"harm":harm,"heavy":force>=750}
	if drown:evidence.drown=true
	# What carries to those who only hear it: a killing is a scream, not a scuffle; water is a splash, ice a crack, a
	# bolt thunder (6 Oct: a heard finish and a heard soaking were both voiced "arguing with their fists").
	var heard := "scream" if act=="finish" or drown else "splash" if act in ["wet","hold"] else "crack" if act=="freeze" \
		else "thunder" if str(fields.get("source",""))=="lightning" else "impact"
	var carried := 800 if heard=="scream" else 0 if act=="wet" else 200
	return record(ID,actor,target,at,18.0,maxi(force,harm),600,
		evidence,
		{"harm":harm,"threat":force,"novelty":500},
		{"act":heard,"features":{"novelty":500,"threat":carried}})
