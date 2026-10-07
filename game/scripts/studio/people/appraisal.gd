extends RefCounted
## S2 one appraisal over observable features and this observer's beliefs/traits/history.
## No body/offer decision. Pain is experienced harm; witnessed suffering builds distress/fear.
## Inferred attribution remains qualified and never becomes eyewitness or a confirmed assault.
const MASS := 2   # a summary standing for at least this many others harmed reads as mass harm
static func evaluate(me: Dictionary, a: Dictionary, gain := 1000) -> Dictionary:
	var f: Dictionary=a.get("features",{})
	var victim := str(a.get("target","unknown"))==str(me.key)
	var tuning: Dictionary=me.get("tuning",{})
	var harm := clampi(int(f.get("harm",0)),0,1000)
	var threat := clampi(int(f.get("threat",0)),0,1000)
	var assistance := clampi(int(f.get("assistance",0)),0,1000)
	var novelty := clampi(int(f.get("novelty",0))*int(me.get("novelty_gain",1000))/1000,0,1000)
	var concern := clampi(int(me.get("concern",0)),0,100)
	var provocation := clampi(int(me.get("provocation",f.get("provocation",0))),0,1000)
	var history := mini(400,int(me.get("hits",0))*100)
	var confidence := certainty(str(a.get("facets",{}).get("actor",{}).get("via",a.via)))
	var observable := {}
	for facet: Dictionary in a.get("facets",{}).values():
		for name: String in facet.get("features",{}):
			observable[name]=maxi(int(observable.get(name,0)),int(facet.features[name])*certainty(str(facet.via))/1000)
	if not observable.is_empty():
		harm=int(observable.get("harm",0));threat=int(observable.get("threat",0));assistance=int(observable.get("assistance",0))
		novelty=int(observable.get("novelty",0))*int(me.get("novelty_gain",1000))/1000
	var experienced := 0
	for facet: Dictionary in a.get("facets",{}).values():
		if str(facet.get("via",""))=="felt":experienced=maxi(experienced,int(facet.get("features",{}).get("felt_harm",0)))
	var aggression := (harm>0 or threat>=200) and assistance==0
	var identified := str(a.identity.key) not in ["unknown",""]
	var act: Dictionary=a.get("facets",{}).get("act",{})
	var confirmed := identified and aggression and str(act.get("via","")) in ["seen","felt","told"]
	var claim := suspicion(me,a) if not identified else {}
	var anger := (harm+threat/3)*(1000 if victim else 200+concern*6)/1000
	anger=anger*(1000-provocation/2)/1000*(1000+history)/1000
	var fear := (threat+harm/2)*(1500-int(me.get("safety",500)))/1000
	var delta := {"anger":anger,"fear":fear,"pain":experienced if victim else 0,
		"interest":novelty/2,"alertness":maxi(threat,novelty)/2,"stance":{},"aggression":confirmed,"claim":claim,
		"pulse":{"anger":int(tuning.get("anger_pulse",500)) if victim else int(tuning.get("anger_pulse",500))/2,
			"fear":int(tuning.get("fear_pulse",400)),"pain":1000,"interest":500,"alertness":600}}
	if assistance>0:
		delta.anger=-assistance;delta.fear=-assistance/3;delta.interest=maxi(80,novelty/2)
	for name: String in ["anger","fear","pain","interest","alertness"]:
		delta[name]=clampi(int(delta[name])*gain/1000*int(tuning.get(name+"_gain",1000))/1000,-1000,1000)
	if identified:
		if assistance>0:delta.stance={"wary":-assistance/4,"trust":assistance/3,"resentment":-assistance/2,"obligation":assistance/2}
		elif aggression:delta.stance={"wary":(100+threat/5)*confidence/1000,"trust":-100*confidence/1000,"resentment":(120+harm/5+history/3)*confidence/1000,"obligation":0}
		# A killing seen or felt (act "finish", or a hold to drown) is not a harder blow: the killer is feared and hated
		# as nothing else.
		var seen_act: Dictionary=act.get("evidence",a.get("evidence",{}))
		# Nor is "many fell there": a crowd's summary account (people_bridge saturation, evidence.many) stands for the
		# many harmed at once, and reads as the gravest harm too, not as one more blow.
		var mass: bool=bool(seen_act.get("many",false)) and int(seen_act.get("count",0))>=MASS
		if aggression and (mass or str(seen_act.get("act",""))=="finish" or (str(seen_act.get("act",""))=="hold" and bool(seen_act.get("drown",false)))):
			delta.stance={"wary":700*confidence/1000,"trust":-500*confidence/1000,"resentment":(700+history/3)*confidence/1000,"obligation":0}
			delta.pulse.fear=maxi(int(delta.pulse.fear),900)   # horror: the fear lands at once, not in a blow's measure
	elif not claim.is_empty():
		delta.stance={"wary":int(claim.confidence)/3,"trust":0,"resentment":0,"obligation":0}
	var name := "received help" if assistance>0 else "was hurt" if victim and harm>0 else "witnessed suffering" if harm>0 else "noticed danger" if threat>0 else "noticed something"
	if not claim.is_empty():name="suspects a cause"
	delta.meaning={"name":name,"how":str(a.via),"actor":str(a.identity.key) if identified else str(claim.get("identity",{}).get("key","unknown")),
		"act":str(a.evidence.get("act","")),"subject":str(a.get("target","unknown")),
		"inferred":not claim.is_empty(),"confidence":int(claim.get("confidence",confidence)),"severity":maxi(harm,threat)}
	return delta
static func certainty(via: String) -> int:
	return 500 if via=="told" else 700 if via=="heard" else 1000
static func suspicion(me: Dictionary, a: Dictionary) -> Dictionary:
	var best := {}
	for candidate: Dictionary in a.get("candidates",[]):
		var basis: Array=candidate.get("basis",[])
		# Standing nearby is never enough, even for a resentful observer.
		var qualified := basis.any(func(clue)->bool:return str(clue) in ["threatening","blood_on_hands","fleeing","reported_dispute"])
		if not qualified:continue
		var identity: Dictionary=candidate.get("identity",{})
		var who := str(identity.get("key","unknown"))
		if who in ["unknown",""]:continue
		var own: Dictionary=me.get("prior_stances",{}).get(who,{})
		var confidence := clampi(int(candidate.get("confidence",0))*certainty(str(candidate.get("via","seen")))/1000+mini(100,int(own.get("wary",0))/5),0,450)
		if confidence<200:continue
		if best.is_empty() or confidence>int(best.confidence):best={"identity":identity.duplicate(true),"confidence":confidence,"inferred":true,"basis":basis.slice(0,3),"via":str(candidate.get("via","seen")),"speaker":str(candidate.get("speaker",""))}
	return best
