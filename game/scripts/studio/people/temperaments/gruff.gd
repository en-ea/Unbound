extends "res://scripts/studio/people/temperament.gd"
const Common := preload("res://scripts/studio/people/temperaments/common.gd")
## Gruff (Enea's Tomas the woodcutter, Odo the old sailor): slow to fear, quick to anger, slow to let a grudge go,
## and he says less of it. The common reading of their traits, then this lean.
const ID := "gruff"
func tune(me: Dictionary) -> Dictionary:
	var t: Dictionary = Common.new().tune(me)
	t.fear_gain = int(t.fear_gain) * 7 / 10
	t.anger_gain = int(t.anger_gain) * 12 / 10
	t.anger_build_rate = int(t.anger_build_rate) * 13 / 10
	t.resentment_rate = maxi(1, int(t.resentment_rate) / 2)
	t.show = int(t.show) * 8 / 10
	return t
