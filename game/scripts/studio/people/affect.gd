extends RefCounted
## S1 integer build/fade on active time. Rates are units/second; remainders thousandths of a point.
## O(5) read-only projection. Candidate settlement allocates growth/loss in stable key order.
## Canonical capacity/unbuilt/remaining/faded/relief receipts survive saturation, gifts and revisions.
const CHANNELS := ["anger","fear","pain","interest","alertness"]
static func advance(value: int, remainder: int, rate: int, elapsed_ms: int) -> Dictionary:
	if value<=0:return {"value":0,"remainder":0,"lost":0}
	var amount := maxi(0,elapsed_ms)*maxi(0,rate)+remainder
	var lost := mini(value,amount/1000)
	return {"value":value-lost,"remainder":amount%1000 if lost<value else 0,"lost":lost}
## Piecewise integer rise to the accepted peak, then fade. Ceil crossing time is defined in whole ms.
## Splitting a fixed-rate interval gives the same phase, value and fractional point.
## in_place: settle owns the stored row and evolves it without a copy (same writes, same key order); project copies.
static func evolve(value: int, input: Dictionary, elapsed_ms: int, in_place := false) -> Dictionary:
	var row := input if in_place else input.duplicate(true)
	var left := maxi(0,elapsed_ms)
	var target := maxi(value,int(row.get("target",value)))
	var building := bool(row.get("building",false)) and target>value
	var growth := 0
	var lost := 0
	var remainder := int(row.get("build_remainder",0))
	if building:
		var rate := maxi(0,int(row.get("build_rate",1000)))
		if rate==0:left=0
		else:
			var gap := maxi(0,(target-value)*1000-remainder)
			var crossing := (gap+rate-1)/rate
			var duration := mini(left,crossing)
			var amount := duration*rate+remainder
			growth=mini(target-value,amount/1000)
			value+=growth;left-=duration
			building=value<target
			remainder=amount%1000 if building else 0
			if building:left=0
	if not building:
		var faded := advance(value,int(row.get("remainder",0)),int(row.get("rate",0)),left)
		value=int(faded.value);lost=int(faded.lost)
		row.remainder=int(faded.remainder);target=value;remainder=0
	row.merge({"target":target,"building":building,"build_remainder":remainder,"value":value,"grown":growth,"lost":lost},true)
	return row
static func project(m, now: int) -> Dictionary:
	var out := {}
	for name: String in CHANNELS:
		var row: Dictionary=m.fade_remainders.get(name,{"remainder":0,"rate":0})
		out[name]=evolve(int(m.affect.get(name,0)),row,maxi(0,now-int(m.affect_tick))).value
	return out
## Step 4 (M5): the receipt keys written since the caller last cleared, per mind: {mind instance id: {fact: true}}.
## Every write into m.appraised during play goes through note(); upgrade()/reshape() run at load, before any batch.
## Not saved and not a state field. The caller (acceptance) reads it and clears it with clear(), never by replacing it.
static var wrote := {}
static func note(m, fact: String) -> void:
	(wrote.get_or_add(m.get_instance_id(),{}) as Dictionary)[fact]=true
## keys: the receipts in sorted order, when the caller already has them (settle sorts once for all channels).
static func grow(m, name: String, amount: int, keys: Array = []) -> void:
	if amount<=0:return
	if keys.is_empty():keys=sorted_keys(m)
	for key: String in keys:
		var trace: Dictionary=m.appraised[key].get("channels",{}).get(name,{})
		var take := mini(amount,int(trace.get("unbuilt",0)))
		if take<=0:continue
		trace.unbuilt=int(trace.unbuilt)-take;trace.remaining=int(trace.get("remaining",0))+take;note(m,key)
		amount-=take
		if amount<=0:break
## Returns actual affect removed; relief may also cancel unbuilt accepted impetus.
static func drain(m, name: String, amount: int, reason: String, include_unbuilt := false, keys: Array = []) -> int:
	var removed := 0
	if keys.is_empty():keys=sorted_keys(m)
	for key: String in keys:
		var trace: Dictionary=m.appraised[key].get("channels",{}).get(name,{})
		if trace.is_empty():continue
		var take := mini(amount,int(trace.get("remaining",0)))
		# A trace changes when something is taken or a missing field is filled in (even a zero), and only then.
		if take>0 or not trace.has("remaining") or not trace.has(reason):note(m,key)
		trace.remaining=int(trace.get("remaining",0))-take
		trace[reason]=int(trace.get(reason,0))+take
		amount-=take;removed+=take
		if include_unbuilt and amount>0:
			var cancelled := mini(amount,int(trace.get("unbuilt",0)))
			if cancelled>0 or not trace.has("unbuilt"):note(m,key)
			trace.unbuilt=int(trace.get("unbuilt",0))-cancelled
			trace[reason]=int(trace.get(reason,0))+cancelled
			amount-=cancelled
		if amount<=0:break
	return removed
static func sorted_keys(m) -> Array:
	var keys: Array=m.appraised.keys();keys.sort()
	return keys
static func settle(m, now: int, tuning: Dictionary) -> void:
	var keys := sorted_keys(m)
	for name: String in CHANNELS:
		var row: Dictionary=m.fade_remainders.get(name,{"remainder":0,"rate":0})
		var changed := evolve(int(m.affect.get(name,0)),row,maxi(0,now-int(m.affect_tick)),true)
		grow(m,name,int(changed.grown),keys)
		drain(m,name,int(changed.lost),"faded",false,keys)
		m.affect[name]=int(changed.value)
		for field: String in ["value","grown","lost"]:changed.erase(field)
		changed.rate=int(tuning.get(name+"_rate",0))
		changed.build_rate=int(tuning.get(name+"_build_rate",1000))
		m.fade_remainders[name]=changed
	m.affect_tick=maxi(int(m.affect_tick),now)
static func replace(m, receipt: Dictionary, delta: Dictionary) -> void:
	var channels: Dictionary=receipt.get_or_add("channels",{})
	for name: String in CHANNELS:
		var wanted := int(delta.get(name,0))
		var old: Dictionary=channels.get(name,{})
		var row: Dictionary=m.fade_remainders.get(name,{"remainder":0,"rate":0,"build_remainder":0,"build_rate":1000,"target":int(m.affect.get(name,0)),"building":false})
		var target := int(row.get("target",m.affect.get(name,0)))
		if wanted<0:
			# Relief has only its original capacity; a calm-time gift cannot later soften a new assault.
			var capacity := int(old.get("capacity",mini(-wanted,target)))
			var allowance := maxi(0,mini(-wanted,capacity)-int(old.get("relieved",0)))
			var relief := mini(target,allowance)
			var removed := drain(m,name,relief,"relief",true)
			m.affect[name]=maxi(0,int(m.affect.get(name,0))-removed)
			row.target=maxi(0,target-relief)
			channels[name]={"wanted":wanted,"capacity":capacity,"remaining":0,"unbuilt":0,"relieved":int(old.get("relieved",0))+relief}
		else:
			var remaining := int(old.get("remaining",0));var unbuilt := int(old.get("unbuilt",0))
			var base := maxi(0,int(m.affect.get(name,0))-remaining)
			var base_target := maxi(base,target-remaining-unbuilt)
			var capacity := int(old.get("capacity",1000-base_target))
			var faded := int(old.get("faded",0));var relief := int(old.get("relief",0))
			var desired := maxi(0,mini(wanted,capacity)-faded-relief)
			var budget := mini(desired,1000-base_target)
			capacity=mini(capacity,wanted-(desired-budget)) if desired>budget else capacity
			var new_impetus := maxi(0,budget-remaining-unbuilt)
			var pulse := new_impetus*clampi(int(delta.get("pulse",{}).get(name,1000)),0,1000)/1000
			var applied := mini(budget,remaining+pulse)
			channels[name]={"wanted":wanted,"capacity":maxi(0,capacity),"remaining":applied,"unbuilt":budget-applied,"faded":faded,"relief":relief}
			m.affect[name]=clampi(base+applied,0,1000)
			row.target=base_target+budget
		row.building=int(row.target)>int(m.affect.get(name,0))
		if not row.building:row.build_remainder=0
		if int(row.target)==0:row.remainder=0
		m.fade_remainders[name]=row
