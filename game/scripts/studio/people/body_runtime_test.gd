extends RefCounted
## Owned narrow Body checks. report through studio/run; engine_batch owns every engine invocation.
const Gesture := preload("res://scripts/studio/player/gesture.gd")
const Runner := preload("res://scripts/studio/people/body_elements.gd")
const Mover := preload("res://scripts/studio/people/mover.gd")
const Persona := preload("res://scripts/studio/people/persona.gd")
const Crowd := preload("res://scripts/studio/people/crowd.gd")
const Contact := preload("res://scripts/studio/village/contact.gd")
const Codec := preload("res://scripts/studio/village/sim/save.gd")
const Fixture := preload("res://scripts/studio/people/foundation_state_test.gd")
const Facts := preload("res://scripts/studio/village/sim/people_actions.gd")
const People := preload("res://scripts/studio/village/sim/people.gd")
const Steer := preload("res://scripts/studio/people/steer.gd")
class Probe extends RefCounted:
	var begins := 0
	var cries := 0
	func begin(port: Dictionary,strength: float,fact: Dictionary) -> Dictionary:
		begins+=1
		port.pose.call("probe",{"weight":strength,"posture":{"name":"down"}})
		port.mover.constraints["probe"]={"move":false}
		port.vocal.call("cry",strength)
		return {"age":float(port.age_ms)/1000.0,"fact":fact}
	func step(port: Dictionary,state: Dictionary,dt: float) -> bool:
		state.age+=dt
		if port.present and state.fact.get("continue_voice",false) and not state.get("sounded",false):
			state.sounded=true
			port.vocal.call("ongoing",0.3)
		return not port.present
	func end(port: Dictionary,_state: Dictionary) -> void:
		port.drop_pose.call("probe")
		port.mover.constraints.erase("probe")
class RetryBridge extends Node:
	var calls := []
	func perform(actor: String,targets: Array,verb: String,fields: Dictionary,geometry: Dictionary) -> Dictionary:
		calls.append({"actor":actor,"targets":targets.duplicate(true),"verb":verb,"fields":fields.duplicate(true),"geometry":geometry})
		return {"accepted":true}
static func check(ok: bool,words: String) -> String:
	return ("PASS " if ok else "FAIL ")+words
static func gesture(role: String) -> RefCounted:
	var g := Gesture.new()
	g.begin(7,role,Vector2.ZERO,Vector2(1280,720),{"target":-2,"press_id":"prepared"})
	return g
static func report() -> PackedStringArray:
	var out := PackedStringArray()
	var loaded := true
	for path: String in ["player/player","player/fighter","player/abilities","ui/hud","ui/joystick","studio/player/hands","studio/player/physical_input","studio/player/power_contact","studio/village/live","studio/village/resident_talk"]:
		var script := load("res://scripts/"+path+".gd") as Script
		loaded=loaded and script!=null and script.can_instantiate()
	out.append(check(loaded,"native player/UI and studio intent adapters compile through their actual paths"))
	var g=gesture("hand")
	g.drag(7,Vector2(60,0),Vector2(60,0))
	out.append(check(g.intent=="strike" and int(g.target.target)==-2 and g.release(7)=="strike","prepared empty strike never substitutes dodge/target"))
	g=gesture("hand")
	g.drag(7,Vector2(50,0),Vector2(50,0))
	g.drag(7,Vector2(5,0),Vector2(-45,0))
	out.append(check(g.release(7)=="cancel","return cancels before strike commitment"))
	g=gesture("hand")
	var ignored: bool=not g.drag(8,Vector2(70,0),Vector2(70,0))
	g.tick(0.3)
	out.append(check(ignored and g.intent=="guard" and g.release(7)=="guard","pointer stays at its origin role, still Hand holds guard"))
	g=gesture("feet")
	g.drag(7,Vector2(40,0),Vector2(40,0))
	out.append(check(g.release(7)=="dodge","Feet stroke stays dodge independently of neighbours"))
	g=gesture("hand")
	g.drag(7,Vector2(50,0),Vector2(50,0))
	g.tick(0.5)
	g.drag(7,Vector2(60,0),Vector2(10,0))
	out.append(check(g.release(7)=="heavy","edge dwell Heavy remains committed while its finger continues moving"))
	g=Gesture.new()
	g.begin(2,"hand",Vector2.ZERO,Vector2(720,360),{})
	g.drag(2,Vector2(20,0),Vector2(20,0))
	out.append(check(g.armed and not g.drag(3,Vector2(40,0),Vector2(20,0)),"scaled viewport thresholds tolerate a small phone and reject another finger"))
	var tree := Engine.get_main_loop() as SceneTree
	var body := Node3D.new()
	tree.root.add_child(body)
	var mv := Mover.new(body,Persona.motion({"key":8,"age":30}))
	mv.actor_key="actor:test"
	mv.go([Vector2(5,0)],4.0)
	mv.constraints["held"]={"move":false,"postures":["upright"]}
	mv.constraints["hurt"]={"pace":0.7}
	out.append(check(not mv.can_move() and not mv.can_posture("down") and is_equal_approx(mv.speed_cap(),0.7) and not mv.stagger(Vector2.RIGHT,1),"restraint/pace compose and refuse another displacement owner"))
	var crowd := Crowd.new()
	crowd.drawn_only=false
	tree.root.add_child(crowd)
	crowd.add(mv)
	var other := Node3D.new()
	other.position=Vector3(0.02,0,0)
	tree.root.add_child(other)
	crowd.others=func() -> Array: return [[other,0.5]]
	body.position=Vector3(2,0,3)
	other.position=Vector3(2.02,0,3)
	crowd._process(0.05)
	out.append(check(body.position==Vector3(2,0,3) and mv.pos==Vector2(2,3) and mv.vel==Vector2.ZERO,"integration AND separation preserve the actual fixed body"))
	mv.constraints.erase("held")
	mv.constraints.erase("hurt")
	other.position=Vector3(10,0,10)
	mv.go([Vector2(5,3)],3.0)
	out.append(check(mv.stagger(Vector2.LEFT,0.4,0.1,0.3) and mv.want(0.05)==Vector2.ZERO,"planted impact delays its physical step"))
	for i in 12:
		crowd._process(0.05)
	out.append(check(not mv._stagger.size() and mv.pos.y>2.9 and mv.path[-1]==Vector2(5,3),"recovery reroutes from actual position to the existing goal"))
	var personal := Steer.Agents.new()
	personal.add(Vector2.ZERO,0.3,0.4,1.0,2.0,1.5,Steer.STANDING)
	personal.add(Vector2(1,0),0.3,0.4,1.0,2.0,1.5,Steer.STANDING)
	var neutral := Steer._avoid(personal,0,Steer.STANDING,Steer.grid_of(personal))
	personal.regard[0][1]=3.0
	var wary := Steer._avoid(personal,0,Steer.STANDING,Steer.grid_of(personal))
	out.append(check(neutral==Vector2.ZERO and wary.x < -Mover.ASIDE_PUSH and personal.want[0]==Vector2.ZERO,"visible personal-space pressure uses the existing step-aside mover, without another goal"))
	var r := Runner.new()
	var probe := Probe.new()
	r.modules={"probe":probe}
	var calls := []
	var port := {"mover":mv,"visible":true,"hints":{},"vocal":func(kind: String,_strength: float) -> void: calls.append(kind)}
	var fact := {"kind":"probe","id":"probe","deed":"one","revision":1,"strength":600,"since_tick":1000,"continue_voice":true}
	mv.constraints["held"]={"move":false,"postures":["upright"]}
	r.reconcile(port,{"probe":fact},1600,true)
	r.update(0)
	out.append(check(calls.is_empty() and not r.layers.probe.has("posture") and is_equal_approx(float(r.playing.probe.state.age),0.6),"rehydration respects fact age/posture constraints without replaying cries or kicks"))
	r.update(0.05)
	out.append(check(calls==["ongoing"],"hydration mutes the origin, then ongoing expression resumes only with active time"))
	r.reconcile(port,{},1650)
	r.update(0.05)
	out.append(check(r.playing.is_empty() and r.layers.is_empty() and not mv.constraints.has("probe"),"actual fact removal clears named pose and physical constraint"))
	var touch := Contact.new("res://scripts/studio/people/proofs/contacts/")
	var received := touch.touches.padded_load.measure({"how":"padded_load","closing":3.0},{},0.05) as Dictionary
	var first: String=touch.pair("actor:any:load","subject:any",true,0.1).press_id
	var again: String=touch.pair("actor:any:load","subject:any",true,0.1).press_id
	touch.pair("actor:any:load","subject:any",false,0.0)
	var next: String=touch.pair("actor:any:load","subject:any",true,0.1).press_id
	var punctuation_a: String=touch.pair("actor:one|extra","target:any",true,0.1).press_id
	var punctuation_b: String=touch.pair("actor:one","extra|target:any",true,0.1).press_id
	out.append(check(received.fields.force==120 and received.fields.harm==0 and first==again and next!=first and punctuation_a!=punctuation_b and Contact.closest(Vector2(3,1),Vector2.ZERO,Vector2(5,0))==Vector2(3,0),"normal discovery adds one contact file; opaque pair identity survives punctuation"))
	var v=Fixture.fixture()
	var old=VillageSession.village
	var was_active: bool=VillageSession.active
	var was_save_paused: bool=SaveGame.paused
	var was_background: bool=VillageSession.background
	var was_locked: bool=Controls.locked
	VillageSession.village=v
	VillageSession.active=true
	SaveGame.paused=false
	VillageSession.background=false
	Controls.locked=false
	var bridge := RetryBridge.new()
	tree.root.add_child(bridge)
	Contact.pending["same"]={"bridge":bridge,"village_id":str(v.runtime.village),"actor":"actor:any","targets":[{"id":3}],"verb":"strike",
		"fields":{"press_id":"same","force":400,"damage":0},"geometry":{},"retry_tick":People.tick(v)}
	# A separate checked publication clones the same village before input delivery resumes.
	VillageSession.village=Codec.from_data(Codec.to_data(v,false))
	Contact.retry()
	var survived: bool=VillageSession.village!=v and bridge.calls.size()==1 and not Contact.pending.has("same")
	Contact.pending["other"]={"bridge":bridge,"village_id":"other:village","retry_tick":People.tick(VillageSession.village)}
	Contact.retry()
	out.append(check(survived and not Contact.pending.has("other") and bridge.calls.size()==1 and bridge.calls[0].fields.press_id=="same" and bridge.calls[0].targets==[{"id":3}],"failed contact survives checked village cloning, retains intent and refuses another village"))
	VillageSession.village=old
	VillageSession.active=was_active
	SaveGame.paused=was_save_paused
	VillageSession.background=was_background
	Controls.locked=was_locked
	r.stop()
	crowd.free()
	body.free()
	other.free()
	bridge.free()
	return out

