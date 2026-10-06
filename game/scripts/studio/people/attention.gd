extends RefCounted
## P3 pure processing delay and saved harmless habituation. Captured evidence is never remeasured.
## Habituation reduces novelty only; fresh harm/escalation/aid is never muted.
static func harmless(a: Dictionary) -> bool:
	var f: Dictionary=a.get("features",{})
	return int(f.get("harm",0))==0 and int(f.get("threat",0))==0 and int(f.get("assistance",0))==0
static func channel(a: Dictionary) -> String:
	return str(a.kind)+":"+str(a.get("emitter",{}).get("key","unknown"))
static func familiarity(habituation: Dictionary, a: Dictionary, now: int) -> int:
	if not harmless(a):return 0
	var row: Dictionary=habituation.get(channel(a),{})
	return clampi(int(row.get("count",0)),0,8) if now-int(row.get("tick",now))<30000 else 0
static func delay(me: Dictionary, a: Dictionary, habituation: Dictionary, tuning: Dictionary, extra_ms: int, now: int) -> int:
	if str(a.via)=="felt":return 0
	var f: Dictionary=a.get("features",{})
	var salience := maxi(int(f.get("harm",0)),maxi(int(f.get("threat",0)),int(f.get("novelty",0))))
	var milliseconds := clampi(int(tuning.get("attention_ms",650))-salience/2+familiarity(habituation,a,now)*90,200,1500)
	return milliseconds+clampi(extra_ms,0,30000)
static func novelty_gain(habituation: Dictionary, a: Dictionary, now: int) -> int:
	return maxi(200,1000-familiarity(habituation,a,now)*100)
static func accepted(habituation: Dictionary, a: Dictionary, now: int) -> void:
	if not harmless(a):return
	var count := familiarity(habituation,a,now)+1
	habituation[channel(a)]={"count":mini(count,8),"tick":now}
	# Harmless attention detail is a bounded working set, not accepted-deed authority.
	if habituation.size()>16:
		var oldest := ""
		for key: String in habituation:
			if oldest.is_empty() or int(habituation[key].tick)<int(habituation[oldest].tick):oldest=key
		habituation.erase(oldest)
