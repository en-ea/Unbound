extends "res://scripts/studio/people/source.gd"
## Persistent flames can be newly sensed. Cause deduplication conveys no culpability.
const ID := "burning"
const NOTICE := {"facts":["burning"],"persistent":true}
func make(actor: String,target: String,at: Array,fields: Dictionary) -> Dictionary:
	var heat := clampi(int(fields.get("strength",600)),0,1000)
	var s := record(ID,actor,target,at,26.0,heat,1500,{"act":"burning","condition":"burning","heat":heat},
		{"harm":heat,"felt_harm":heat,"threat":heat,"novelty":600},
		{"act":"fire","features":{"threat":250,"novelty":400}})
	s.actor=""
	return s
