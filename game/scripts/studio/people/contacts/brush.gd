extends RefCounted
## B6 measured capability module. One file via contact's normal Modules.discover folder.
## Walking into someone: their shoulders rock (cue_force, under impact's BRUSH) and from STUMBLE_FROM m/s closing they
## stumble a step back (stumble metres: presentation only, Body's mover; no fact, no acceptance). A hard barge (running
## in), a long press, or a held push (how "push") asks for the checked shove, once a person (contact.gd's pair).
## Stood still (how "still"), it is only felt.
const ID := "brush"
const STUMBLE_FROM := 0.8     # m/s closing: slower is a touch, not a stumble
const PRESS_EVERY := 0.6      # s: a held push pressed against someone makes them give ground again this often
## how "still": the actor is not moving himself (someone walked into him, or he was pushed about): the touch is felt,
## and that is all - no stumble, no checked shove.
func measure(sample: Dictionary,pair: Dictionary,_dt: float) -> Dictionary:
	var closing := float(sample.closing)
	var out := {"cue_force":clampi(roundi(closing*70),50,240)}
	if str(sample.how)=="still":
		return out
	if closing>=STUMBLE_FROM:
		out.stumble=clampf(0.2+(closing-STUMBLE_FROM)*0.15,0.2,0.6)    # walking pace (1.6) 0.32 m, running (5.4) 0.6 m
	elif str(sample.how)=="push" and float(pair.age)>=PRESS_EVERY:
		out.stumble=0.4                                                 # pressed against them, pushing: they give ground
	if closing>=2.4 or (float(pair.age)>=1.2 and closing>0.3) or (str(sample.how)=="push" and closing>0.3):
		out.merge({"verb":"shove","fields":{"force":clampi(roundi(closing*110),250,700),"harm":0,"how":sample.how}},true)
	return out
