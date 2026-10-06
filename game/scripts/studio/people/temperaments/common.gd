extends "res://scripts/studio/people/temperament.gd"
## Trait expression/settling lives here; no named temperament branch in the consumer.
const ID := "common"
func tune(me: Dictionary) -> Dictionary:
	var bold := clampi(int(me.get("courage",50)),0,100)
	var temper := clampi(int(me.get("temper",50)),0,100)
	var alert := clampi(int(me.get("alert",50)),0,100)
	var safety := clampi(int(me.get("safety",500)),0,1000)
	var history := mini(5,int(me.get("hits",0)))
	var concern := clampi(int(me.get("concern",0)),0,100)
	return {"anger_gain":700+temper*6,"fear_gain":1400-bold*8,
		"anger_rate":maxi(4,38-temper/3-history*2-concern/20),"fear_rate":maxi(4,8+safety/40-history+concern/20),
		"pain_rate":8,"interest_rate":25+alert/5,"alertness_rate":16+safety/50,
		"anger_build_rate":400+temper*12,"fear_build_rate":1600-bold*12,
		"interest_build_rate":500+alert*10,"alertness_build_rate":600+alert*12,
		"wary_rate":maxi(10,50-bold/3-history),"resentment_rate":maxi(1,7-temper/20-history/2),
		"attention_ms":1200-alert*9,"distraction_ms":2200 if alert<25 else 0,"show":450+temper*5,"steady":bold*8,
		"pace":bold*8-400,"lean":temper*10-500,"space_mm":2200-bold*12}
