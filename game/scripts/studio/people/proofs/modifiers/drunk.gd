extends "res://scripts/studio/people/modifier.gd"
const ID := "drunk"
func gain(_me: Dictionary, _a: Dictionary, _row: Dictionary) -> int:
	return 1400
func score(offer: String, _me: Dictionary, _row: Dictionary) -> int:
	return 30 if offer=="protest" else 0
