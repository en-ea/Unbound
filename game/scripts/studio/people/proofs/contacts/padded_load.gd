extends RefCounted
## Permanent one-file contact extension: a padded load brushes softly through the SAME producer loop.
## It supplies measured cue/force only; it chooses no target, goal, injury or witness.
const ID := "padded_load"
func measure(sample: Dictionary,_pair: Dictionary,_dt: float) -> Dictionary:
	if sample.get("how","")!="padded_load":
		return {}
	return {"cue_force":90,"verb":"shove","fields":{"force":120,"harm":0,"how":"padded_load"}}

