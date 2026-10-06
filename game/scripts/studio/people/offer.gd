extends RefCounted
## C1 offer: ID, ANSWERS kinds, ROLES metadata, PRIORITY tie break.
## can(me,account), score(me,account), effects(me,account), steps(me,account), lasts seconds.
## Inputs contain own inner state and bounded account; effects are saved intention metadata, steps are C4 primitives.
## No arbitrary effect interpreter in this slice: consequential acts use checked action/report doors.
## No raw deed, player singleton, direct body, save or global chooser access.
func can(_me: Dictionary, _a: Dictionary) -> bool:
	return false
func score(_me: Dictionary, _a: Dictionary) -> int:
	return 0
func effects(_me: Dictionary, _a: Dictionary) -> Dictionary:
	return {}
func steps(_me: Dictionary, _a: Dictionary) -> Array:
	return []
func lasts(_me: Dictionary, _a: Dictionary) -> float:
	return 10.0
