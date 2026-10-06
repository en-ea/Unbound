extends "res://scripts/studio/people/offer.gd"
const ID := "listen"
const ANSWERS := ["footfall"]
const PRIORITY := 1
func can(_me: Dictionary, _a: Dictionary) -> bool:
	return true
func score(_me: Dictionary, _a: Dictionary) -> int:
	return 500
func steps(_me: Dictionary, a: Dictionary) -> Array:
	return [{"op":"face","target":a.identity.key},{"op":"wait","seconds":0.8}]
