extends RefCounted
## S/C modifier: ID; gain(me,account,row)->1000-neutral fixed gain; score(offer,me,row)->delta;
## appearance(current,row)->key/name PATCH; {} is neutral. Fold attachments in saved order.
## delay(me,row)->additional active milliseconds; choose(me,account,row)->optional instruction.
## tune(me,row)->bounded temperament gain/rate/attention/style PATCH; {} neutral. C hooks retained.
## Modifiers receive bounded accounts, never raw deeds; one data row attaches one discovered file.
func gain(_me: Dictionary, _account: Dictionary, _row: Dictionary) -> int:
	return 1000
func score(_offer: String, _me: Dictionary, _row: Dictionary) -> int:
	return 0
func appearance(_current: Dictionary, _row: Dictionary) -> Dictionary:
	return {}
func delay(_me: Dictionary, _row: Dictionary) -> int:
	return 0
func choose(_me: Dictionary, _account: Dictionary, _row: Dictionary) -> Dictionary:
	return {}
func tune(_me: Dictionary, _row: Dictionary) -> Dictionary:
	return {}
