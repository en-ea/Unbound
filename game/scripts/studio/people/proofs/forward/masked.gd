extends "res://scripts/studio/people/modifier.gd"
## One-file forward rule: appearances are copied before perception; true actor stays in the deed authority.
const ID := "masked"
func appearance(_current: Dictionary, row: Dictionary) -> Dictionary:
	return {"key":str(row.get("look","look:masked:red")),"name":"a masked stranger"}
static func prove() -> bool:
	var stimulus := {"kind":"contact","source":"player:local","target":"res:1:0","at":[1,2],"strength":400,
		"evidence":{"act":"strike"},"deed":"masked-proof"}
	var a := preload("res://scripts/studio/people/perception.gd").account("res:1:0",stimulus,
		{"seen":true,"due":0},load("res://scripts/studio/people/proofs/forward/masked.gd").new().appearance({"key":"player:local","name":"player"},{}),"masked-proof:0")
	var v=preload("res://scripts/studio/village/sim/runtime.gd").create(16838,{"anchored":true})
	var target := -1
	for person in v.people:
		if person.alive and person.present and person.authored=="" and preload("res://scripts/studio/village/sim/village.gd").age_of(v,person)>=18:
			target=person.id
			break
	if target<0:return false
	a.observer=preload("res://scripts/studio/village/sim/people.gd").key(v,target)
	a.target=a.observer
	preload("res://scripts/studio/village/sim/people.gd").learn(v,a)
	var decoded=preload("res://scripts/studio/village/sim/save.gd").from_data(preload("res://scripts/studio/village/sim/save.gd").to_data(v,false))
	return a.identity.key=="look:masked:red" and not JSON.stringify(a).contains("player:local") and decoded.people[target].mind.stances.has("look:masked:red") and not decoded.people[target].mind.stances.has("player:local")
