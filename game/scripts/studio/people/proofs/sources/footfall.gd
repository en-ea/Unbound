extends "res://scripts/studio/people/source.gd"
const ID := "footfall"
func make(actor: String, target: String, at: Array, _fields: Dictionary) -> Dictionary:
	return {"kind":ID,"source":actor,"target":target,"at":at,"reach":8.0,"strength":350,"evidence":{"act":"step"}}
