extends "res://scripts/studio/people/modifier.gd"
## P3 attention delay is milliseconds in one saved modifier row, independent of animation and frame rate.
const ID := "distracted"
func delay(_me: Dictionary, row: Dictionary) -> int:
	return clampi(int(row.get("delay_ms",2200)),0,30000)
func tune(_me: Dictionary, row: Dictionary) -> Dictionary:
	return {"attention_ms":clampi(int(row.get("attention_ms",1200)),200,1500),"show":350,"steady":350}
