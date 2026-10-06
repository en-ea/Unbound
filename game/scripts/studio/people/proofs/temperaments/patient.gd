extends "res://scripts/studio/people/temperament.gd"
## Permanent one-file extension through production discovery, only the supplied proof folder differs.
const ID := "patient"
func tune(_me: Dictionary) -> Dictionary:
	return {"anger_gain":600,"anger_rate":40,"fear_gain":700,"attention_ms":800,"show":300,"steady":850}
