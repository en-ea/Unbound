extends "res://scripts/studio/people/modifier.gd"
## One-file proof: changes attention only, inheriting the neutral appearance patch.
const ID := "veiled_attention"
func delay(_me: Dictionary,row: Dictionary) -> int:
	return int(row.get("delay_ms",275))
