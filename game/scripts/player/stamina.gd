class_name Stamina
extends Node
## The player's stamina (numbers in Balance.STAMINA). Sprinting drains it; a roll or a heavy attack
## takes a chunk. It refills after a short pause. Emptied, you are winded until it is partly back.

signal changed(value: float, max_value: float, winded: bool)
signal refused(cost: String)     # tried to roll or heavy-attack without enough

var value: float = Balance.STAMINA["max"]
var winded := false
var _pause := 0.0


func max_value() -> float:
	return Balance.STAMINA["max"]


## True if there is enough for `cost` (any amount left is enough, so the last roll still works).
func can(cost: String) -> bool:
	return not winded and value > (1.0 if cost == "sprint" else 0.0)


## The action: pay for a roll or a heavy attack. False (and nothing paid) when winded.
func use(cost: String) -> bool:
	if not can(cost):
		refused.emit(cost)
		return false
	_spend(Balance.STAMINA[cost])
	return true


## Sprinting drains it a little each frame.
func drain(delta: float) -> void:
	_spend(Balance.STAMINA["sprint"] * delta)


func refill() -> void:
	value = max_value()
	winded = false
	changed.emit(value, max_value(), winded)


func _spend(amount: float) -> void:
	value = maxf(value - amount, 0.0)
	_pause = Balance.STAMINA["delay"]
	if value <= 0.0:
		winded = true
	changed.emit(value, max_value(), winded)


func _physics_process(delta: float) -> void:
	if _pause > 0.0:
		_pause -= delta
		return
	if value >= max_value():
		return
	value = minf(value + Balance.STAMINA["regen"] * delta, max_value())
	if winded and value >= Balance.STAMINA["winded_until"]:
		winded = false
	changed.emit(value, max_value(), winded)
