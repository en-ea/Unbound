extends "res://scripts/studio/people/source.gd"
## Generic non-player/world input through the same semantic appraisal; no content-wide wiring.
const ID := "cold"
func make(actor: String, target: String, at: Array, _fields: Dictionary) -> Dictionary:
	return record(ID,actor,target,at,8.0,350,900,{"act":"cold"},{"harm":0,"threat":150,"novelty":450},{"act":"rustling","features":{"novelty":250}})
