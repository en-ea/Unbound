extends "res://scripts/studio/people/temperament.gd"
const Common := preload("res://scripts/studio/people/temperaments/common.gd")
## Weary (Enea's Bram the tired miller): slow to anger, slow to move, and slow to forget a loss or a wrong.
const ID := "weary"
func tune(me: Dictionary) -> Dictionary:
	var t: Dictionary = Common.new().tune(me)
	t.anger_gain = int(t.anger_gain) * 8 / 10
	t.anger_rate = maxi(4, int(t.anger_rate) * 6 / 10)
	t.fear_rate = maxi(4, int(t.fear_rate) * 6 / 10)
	t.resentment_rate = maxi(1, int(t.resentment_rate) / 2)
	t.wary_rate = maxi(10, int(t.wary_rate) * 7 / 10)
	t.pace = int(t.pace) - 150
	return t
