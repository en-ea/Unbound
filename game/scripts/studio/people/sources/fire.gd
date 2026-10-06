extends "res://scripts/studio/people/source.gd"
## P1 root heat contact; observing flames later uses burning, without replaying ignition.
const ID := "fire"
func make(actor: String,target: String,at: Array,fields: Dictionary) -> Dictionary:
	var heat := clampi(int(fields.get("heat",750)),1,1000)
	return record(ID,actor,target,at,24.0,heat,1000,{"act":"burn","heat":heat},
		{"harm":heat,"threat":heat,"novelty":700},
		{"act":"fire","features":{"threat":300,"novelty":500}})
