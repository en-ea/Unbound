extends Node
## The player's items (game state, no visuals). Change it only through add() and remove(),
## so later a network peer can apply the same actions.

signal changed(item: String, count: int)
signal added(item: String, amount: int)     # for the pickup feed

var _counts := {}      # item id -> count
var _order: Array[String] = []   # first-found order, for a stable inventory screen


func add(item: String, amount := 1) -> void:
	if not _counts.has(item):
		_counts[item] = 0
		_order.append(item)
	_counts[item] += amount
	changed.emit(item, _counts[item])
	added.emit(item, amount)


func remove(item: String, amount := 1) -> bool:
	if count(item) < amount:
		return false
	_counts[item] -= amount
	changed.emit(item, _counts[item])
	return true


func count(item: String) -> int:
	return _counts.get(item, 0)


## Items the player has, in the order they were first found.
func items() -> Array[String]:
	return _order.filter(func(i: String) -> bool: return _counts[i] > 0)
