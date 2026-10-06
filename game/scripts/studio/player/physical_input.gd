extends RefCounted
## E/P1 adapter, not a chooser. Captures intent/target once, commits measured acts and preserves press IDs.
## People never enter carcass APIs. Rules own carry/extinguish/harm; Body owns actual geometry/capability.
const Contact := preload("res://scripts/studio/village/contact.gd")
const Talk := preload("res://scripts/studio/village/resident_talk.gd")
const Acts := preload("res://scripts/studio/village/player_acts.gd")
const Water := preload("res://scripts/studio/village/water.gd")
const View := preload("res://scripts/studio/village/sim/view.gd")
const TapRule := preload("res://scripts/studio/player/tap_rule.gd")
var player
var touch := Contact.new()
var _before := Vector3.INF
var _load_before := Vector3.INF
var _load: Node3D
var pushing := false # Hands: a push held on the thumb area (walking contact is then a push: brush.gd)
func _init(actor) -> void:
	player=actor
func actor() -> String:
	return Contact.actor_of(player)
func direction(stroke: Vector2,yaw: float) -> Vector3:
	var dir := stroke.normalized().rotated(-yaw)
	return Vector3(dir.x,0,dir.y)
func capture(role: String) -> Dictionary:
	var intent := {"press_id":"hand:%d" % Time.get_ticks_usec(),"yaw":Controls.cam_yaw,"role":role,
		"target":-2,"native":null,"forward":Vector3(sin(player.visual.rotation.y),0,cos(player.visual.rotation.y))}
	if role=="hand":
		intent.context=context()
	if role=="grip":
		intent.context=grip()
	if role=="act":
		var chosen := tap_context()
		intent.tap=chosen.tap
		intent.context=chosen.context
	if intent.has("context"):
		intent.context_view=describe_context(intent.context)
	return intent
## Display-only capture; it never supplies or substitutes the strike target.
func describe_context(context_row: Dictionary) -> Dictionary:
	var res := Contact.registry(player.get_tree())
	var node: Node3D=context_row.get("node")
	var id := int(context_row.get("id",-1))
	var reach := 1.8 if str(context_row.get("kind","")) in ["person","person_down","carcass","lower"] else 1.2
	if node is Talk.Spot:
		id=node.resident
	if str(context_row.get("kind",""))=="station" and is_instance_valid(node):
		reach=float(node.reach)
	if str(context_row.get("kind",""))=="lower":
		node=player.hauling.carrying
	if res!=null and id>=0 and res.bodies.has(id):
		node=res.bodies[id]
		return {"node":node,"id":id,"label":label_for(id),"reach":reach}
	return {"node":node,"id":-2,"label":str(node.kind).capitalize() if node is Carcass else "","reach":reach}
func label_for(id: int) -> String:
	var res := Contact.registry(player.get_tree())
	if res==null:
		return "someone"
	var ref: String=preload("res://scripts/studio/village/sim/people.gd").key(VillageSession.village,id)
	var shown: Dictionary=res.people_bridge.appearance(ref)
	var label := str(shown.get("name","someone"))
	if str(shown.get("key",""))==ref and label==ref:
		label=str(View.describe(VillageSession.village,id).name)
	return label
func aim_target(intent: Dictionary,forward: Vector3) -> void:
	# One capture, including empty. Nothing entering the cone later can become this strike.
	if intent.get("captured",false):
		return
	intent.captured=true
	intent.forward=forward
	var reach := 3.0
	for row: Dictionary in Contact.candidates(player.get_tree(),player,reach,forward,0.35):
		var distance: float=player.global_position.distance_to(row.at)
		if distance<reach:
			reach=distance
			intent.target=int(row.id)
			intent.label=label_for(int(row.id))
	for enemy in player.get_tree().get_nodes_in_group("enemy"):
		if not enemy.is_alive() or bool(enemy.get_meta("studio_villager",false)) or bool(enemy.get_meta("crowd_ignore",false)):
			continue
		var to: Vector3=enemy.global_position-player.global_position
		to.y=0
		if to.length()<reach and (to.length()<0.65 or to.normalized().dot(forward)>=0.35):
			reach=to.length()
			intent.target=-2
			intent.native=enemy
			intent.label=str(enemy.name)
func context() -> Dictionary:
	return TapRule.use_of(facts())
## What is in reach this frame, by TapRule's slots (the rule decides; this only looks).
func facts() -> Dictionary:
	var out := {}
	if player.burrowed():
		out.erupt={"kind":"erupt","verb":"Emerge"}
	var station = player._nearest_station()
	if is_instance_valid(station):
		out["village_station" if station.get_meta("village_action",false) else "station"]={"kind":"station","node":station,"verb":station.verb}
	var res := Contact.registry(player.get_tree())
	if res!=null:
		for row: Dictionary in Contact.candidates(player.get_tree(),player,1.2,Vector3.ZERO):
			var fact: Dictionary=VillageSession.village.people[int(row.id)].body_facts.get("burning",{})
			if not fact.is_empty():
				out.extinguish={"kind":"extinguish","id":int(row.id),"cause_id":fact.deed,"verb":"Put out"}
				break
	if player.hauling.riding:
		out.get_off={"kind":"get_off","verb":"Get off"}
	if player.hauling.carrying:
		out.lower={"kind":"lower","verb":"Lower"}
	if player.gatherer.verb!="":
		out.gather={"kind":"gather","target":player.gatherer.target,"verb":player.gatherer.verb}
	if player.fighter.verb=="Takedown" and is_instance_valid(player.fighter.target):
		out.takedown={"kind":"takedown","node":player.fighter.target,"verb":"Takedown"}
	return out
## One thumb area's tap (TapRule): urgent use first, then picking up or setting down, then talk and stations.
func tap_context() -> Dictionary:
	return TapRule.tap(facts(),grip())
## What is carried, for TapRule: "person", "carcass" or "".
func load_kind() -> String:
	return "person" if player.has_meta("studio_people_load") else "carcass" if player.hauling.carrying else ""
func grip() -> Dictionary:
	var res0 := Contact.registry(player.get_tree())
	if res0!=null and player.has_meta("studio_people_load"):
		return {"kind":"person_down","id":int(player.get_meta("studio_people_load")),"verb":"Lower"}
	if player.hauling.carrying:
		return {"kind":"lower","verb":"Lower"}
	var res := Contact.registry(player.get_tree())
	if res!=null:
		var v=VillageSession.village
		for row: Dictionary in res._crowd.nearby.query(Vector2(player.global_position.x,player.global_position.z),1.6):
			var id := preload("res://scripts/studio/village/sim/people.gd").resident(v,str(row.key))
			if id<0 or not Contact.capable(res,v,id):
				continue
			var p=v.people[id]
			if p.body_facts.has("carried") and str(p.body_facts.carried.carrier)==actor():
				return {"kind":"person_down","id":id,"verb":"Lower"}
			if p.body_facts.has("carried"): # merge-fix: someone else's load (the ox cart's bed): the cart's Take out
				continue
			if (not p.alive or p.body_facts.has("down") or p.hurt>=60) and not res.bodies[id].hands_held():
				return {"kind":"person","id":id,"verb":"Lift"}
	for node in player.get_tree().get_nodes_in_group("interactable"):
		if node is Carcass and not node.dragged and node.global_position.distance_to(player.global_position)<1.8:
			return {"kind":"carcass","node":node,"verb":"Lift"}
	return {"kind":"empty","verb":"Grip"}
func use(intent: Dictionary) -> void:
	var c: Dictionary=intent.get("context",{})
	match str(c.get("kind","empty")):
		"erupt": player.abilities.delver.erupt()
		"station":
			var node: Node3D=c.get("node")
			if is_instance_valid(node) and node.global_position.distance_to(player.global_position)<=float(node.reach):
				node.interact()
		"extinguish":
			var res := Contact.registry(player.get_tree())
			if res==null:
				return
			var water: Dictionary=res.people_bridge.affordance(actor(),"water")
			var fields := {"press_id":intent.press_id,"cause_id":c.cause_id,"method":"beat"}
			var victim: Node3D=res.bodies.get(int(c.id))
			if is_instance_valid(victim) and not water.is_empty() and Water.contact(res,Vector2(player.global_position.x,player.global_position.z),
				Vector2(victim.global_position.x,victim.global_position.z),str(water.key)):
				fields.method="water"
				fields.affordance=water.key
			contact(intent,"extinguish",fields,1.2,int(c.id))
		"get_off": player.hauling.get_off()
		"lower": player.hauling.drop()
		"gather":
			if player.gatherer.target==c.target:
				player.gatherer.act()
		"takedown":
			var node: Node3D=c.get("node")
			if is_instance_valid(node) and player.fighter.target==node and player.fighter.verb=="Takedown":
				player.fighter.attack()
func contact(intent: Dictionary,verb: String,fields: Dictionary,reach: float,target: int,permissions := {}) -> Dictionary:
	var result := Contact.perform(player.get_tree(),actor(),player,verb,fields,player.global_position,reach,
		intent.get("forward",Vector3.ZERO) if verb in ["strike","shove"] else Vector3.ZERO,target,Vector3.INF,permissions)
	return result
func commit(verb: String,intent: Dictionary,strength := 0.0,offset := Vector2.ZERO) -> void:
	if Controls.locked or VillageSession.background or player.is_down():
		return
	match verb:
		"use": use(intent)
		"strike","heavy":
			if TapRule.strikes_while(load_kind()): # Carrying (a carcass or a person), a flick does not strike.
				player.studio_strike(intent,verb=="heavy")
		"shove":
			contact(intent,"shove",{"press_id":intent.press_id,"force":clampi(roundi(250+strength*400),250,700),"harm":4},2.2,int(intent.target))
		"dodge": player.roll(direction(offset,intent.yaw))
		"grip":
			var c: Dictionary=intent.get("context",{})
			match str(c.get("kind","empty")):
				"lower": player.hauling.drop()
				"carcass":
					var node: Node3D=c.get("node")
					if is_instance_valid(node) and node.global_position.distance_to(player.global_position)<1.8:
						player.hauling.start_carry(node)
				"person","person_down":
					contact(intent,"carry" if c.kind=="person" else "set_down",{"press_id":intent.press_id},1.8,int(c.id),
						{"can_carry":not player.hauling.busy() and not player.has_meta("studio_people_load") and player.stamina.can("heavy")})
		_:
			if verb.begins_with("power:"):
				var point := aim_point(intent,offset)
				var dir: Vector3=intent.get("forward",Vector3.FORWARD)
				player.abilities.use(verb.trim_prefix("power:"),{"at":point,"dir":dir,"press_id":intent.press_id})
func aim_point(intent: Dictionary,offset: Vector2) -> Vector3:
	var forward: Vector3=intent.get("forward",Vector3.FORWARD)
	var distance := clampf(offset.length()/maxf(1.0,float(intent.get("scale",1.0)))/8.0,2,16)
	var point: Vector3=player.global_position+forward*distance
	point.y=WorldShape.new().height_at(point.x,point.z)
	return point
func live(verb: String,on: bool) -> void:
	if verb=="guard":
		player.studio_hold_guard(on)
	elif verb=="crouch" and (not on or (not player.hauling.busy() and not player.burrowed())):
		player.set_sneaking(on)
func step(dt: float) -> void:
	# Physical capability loss requests the same checked carry consequence; no goal/chooser here.
	if player.is_down() and not Controls.locked and not VillageSession.background and player.has_meta("studio_people_load"):
		var res0 := Contact.registry(player.get_tree())
		var id := int(player.get_meta("studio_people_load"))
		if res0!=null and VillageSession.village!=null and id>=0 and id<VillageSession.village.people.size():
			var carried: Dictionary=VillageSession.village.people[id].body_facts.get("carried",{})
			if not carried.is_empty() and str(carried.carrier)==actor():
				contact({"forward":Vector3.ZERO},"set_down",{"press_id":"load-release:"+str(carried.deed),"how":"capability_lost"},1.8,id)
	if Controls.locked or VillageSession.background or player.is_down():
		_before=Vector3.INF
		_load_before=Vector3.INF
		return
	Contact.retry()
	var at: Vector3=player.global_position
	if _before!=Vector3.INF and not player.is_rolling():
		# 0.8 m: his capsule stops him about 0.7 m from someone's centre, so a smaller reach missed a walk into them.
		touch.walking(player.get_tree(),actor(),player,_before,at,dt,0.8,"push" if pushing else "walk")
	_before=at
	var carried: Node3D=player.hauling.carrying
	var res := Contact.registry(player.get_tree())
	if carried==null and res!=null and player.has_meta("studio_people_load"):
		carried=res.bodies.get(int(player.get_meta("studio_people_load")))
	if is_instance_valid(carried):
		if carried==_load and _load_before!=Vector3.INF:
			touch.walking(player.get_tree(),actor(),player,_load_before,carried.global_position,dt,0.9,"load")
		_load=carried
		_load_before=carried.global_position
	else:
		_load=null
		_load_before=Vector3.INF
