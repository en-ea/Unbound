extends RefCounted
## B6-B8 runtime: play contacts, reconcile accepted facts, express FROM hints.
## Normal discovery. Actual fact identity/deed/revision/removal owns liveness.
## update(0) freezes steps. Rehydrated begin is silent; later active steps retain normal live callbacks.
## Named removable layers consumed by Claude's body.apply_elements.
const Modules := preload("res://scripts/studio/people/modules.gd")
var modules := {}
var playing := {}
var layers := {}
var completed := {}
var _facts := {}
var _tick := 0
func _init(folder := "res://scripts/studio/people/elements/") -> void:
	var scripts := Modules.discover(folder)
	for key: String in scripts:
		modules[key] = scripts[key].new()
func _version(fact: Dictionary) -> String:
	return JSON.stringify([fact.get("kind",""),fact.get("id",""),fact.get("deed",""),int(fact.get("revision",0))])
func _port(base: Dictionary, fact: Dictionary, hydrate: bool) -> Dictionary:
	var port := base.duplicate()
	port.merge({"tick":_tick,"age_ms":maxi(0,_tick-int(fact.get("since_tick",_tick))),
		"rehydrating":hydrate,"present":true,"hints":base.get("hints",{})},true)
	var constrained_mover=base.get("mover")
	port.pose = func(key: String, fields: Dictionary) -> void:
		var contribution := fields.duplicate(true)
		var posture: Dictionary=contribution.get("posture",{})
		if not posture.is_empty() and not constrained_mover.can_posture(str(posture.get("name",""))):
			contribution.erase("posture")
		layers[key]=contribution
	port.drop_pose = func(key: String) -> void: layers.erase(key)
	if hydrate:
		port.emit=func(_kind: String,_fields: Dictionary) -> void: pass
		port.announce=func(_kind: String,_fact: Dictionary,_transition := false) -> bool: return false
		port.vocal=func(_kind: String,_strength: float) -> void: pass
	return port
func _after_begin(port: Dictionary, base: Dictionary) -> void:
	if not bool(port.rehydrating):
		return
	# No origin kick/cry is replayed during begin. Ongoing fire can still cry after genuine active time.
	for field: String in ["emit","announce","vocal"]:
		if base.has(field):
			port[field]=base[field]
	port.rehydrating=false
func play(id: String, base: Dictionary, strength: float, fact: Dictionary) -> void:
	if not modules.has(id):
		return
	_finish(id)
	var port := _port(base,fact,bool(base.get("rehydrating",false)))
	playing[id] = {"port":port,"fact":fact.duplicate(true),"state":modules[id].begin(port,clampf(strength,0,1),fact),"saved":false}
	_after_begin(port,base)
func _finish(id: String) -> void:
	if playing.has(id):
		modules[id].end(playing[id].port,playing[id].state)
		playing.erase(id)
func reconcile(base: Dictionary, facts: Dictionary, tick: int, hydrate := false) -> void:
	_tick=tick
	_facts=facts.duplicate(true)
	for id: String in playing.keys():
		var item: Dictionary=playing[id]
		item.port.tick=tick
		item.port.age_ms=maxi(0,tick-int(item.fact.get("since_tick",tick)))
		item.port.visible=bool(base.get("visible",true))
		item.port.hints=base.get("hints",{})
		if item.saved:
			var current: Dictionary=facts.get(id,{})
			item.port.present=not current.is_empty() and _version(current)==_version(item.fact)
		if hydrate:
			_finish(id)
	for id: String in facts:
		if not modules.has(id):
			continue
		var fact: Dictionary=facts[id]
		if fact.has("until_tick") and int(fact.until_tick)<=tick:
			continue
		var version := _version(fact)
		var stamp := str(base.mover.constraints)
		if playing.has(id) and _version(playing[id].fact)==version:
			continue
		if not hydrate and completed.get(id,"")==version+"|"+stamp:
			continue
		_finish(id)
		var port := _port(base,fact,hydrate)
		playing[id]={"port":port,"fact":fact.duplicate(true),"state":modules[id].begin(port,float(fact.get("strength",1000))/1000.0,fact),"saved":true}
		_after_begin(port,base)
	for id: String in completed.keys():
		if not facts.has(id):
			completed.erase(id)
func express(base: Dictionary, hints: Dictionary) -> void:
	for id: String in modules:
		var from: Variant=modules[id].get_script().get_script_constant_map().get("FROM",null)
		if from==null or _facts.has(id):
			continue
		var strength := 0.0
		if from is String:
			strength=float(hints.get(from,0.0))
		elif from is Dictionary:
			for channel: String in from:
				var value := float(hints.get(channel,0.0))
				if value>=float(from[channel]):
					strength=maxf(strength,value)
		if strength<=0:
			_finish(id)
		elif not playing.has(id):
			play(id,base,strength,{"kind":id,"hint":true})
		elif playing[id].state.has("strength"):
			playing[id].state.strength=clampf(strength,0,1)
func update(dt: float) -> void:
	if dt<=0:
		return
	for id: String in playing.keys():
		var item: Dictionary=playing[id]
		if modules[id].step(item.port,item.state,dt):
			_finish(id)
			if item.saved:
				completed[id]=_version(item.fact)+"|"+str(item.port.mover.constraints)
func stop() -> void:
	for id: String in playing.keys():
		_finish(id)
	layers.clear()
	completed.clear()
	_facts.clear()
