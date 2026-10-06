extends "res://scripts/studio/people/source.gd"
## One-file proof: a new observable condition uses an existing accepted injury fact.
const ID := "chill"
const NOTICE := {"facts":["hurt"],"persistent":true}
func make(actor: String,subject: String,at: Array,_fields: Dictionary) -> Dictionary:
	var s := record(ID,actor,subject,at,16.0,350,800,{"act":"chill"},{"novelty":300},{})
	s.actor=""
	s.hearing_reach=0.0
	return s
