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


## Whether an item fits: you already carry some, or the bag has a free slot (Gear.bag_slots()).
func has_room(item: String) -> bool:
	return count(item) > 0 or items().size() < Gear.bag_slots()


func count(item: String) -> int:
	return _counts.get(item, 0)


## Items the player has, in the order they were first found.
func items() -> Array[String]:
	return _order.filter(func(i: String) -> bool: return _counts[i] > 0)


## Plain data for the save file, in found order.
func to_data() -> Dictionary:
	var out := {}
	for item in _order:
		out[item] = _counts[item]
	return out


## Replaces the whole inventory (loading a save).
func load_data(data: Dictionary) -> void:
	_counts.clear()
	_order.clear()
	for item: String in data:
		if Items.DEFS.has(item):
			_counts[item] = int(data[item])
			_order.append(item)
			changed.emit(item, _counts[item])
