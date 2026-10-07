extends Node
## Permanent connected encounter fixture: cast/positions/traits only. Real Heavy, ordinary action/save doors,
## sensors, appraisal, offers and travel run unchanged. No scripted victim/helper reactions.
const VillageImage := preload("res://scripts/studio/village/sim/image.gd")
const People := preload("res://scripts/studio/village/sim/people.gd")
const Rules := preload("res://scripts/studio/village/sim/village.gd")
const Codec := preload("res://scripts/studio/village/sim/save.gd")
const Contact := preload("res://scripts/studio/village/contact.gd")
const Accept := preload("res://scripts/studio/village/acceptance.gd")
const Water := preload("res://scripts/studio/village/water.gd")
var live: Node
var res: Node
var player: Node3D
var cast: Array[int] = []
var mode := "check"
var failed := 0
var shot_path := ""
var camera: Camera3D
static func on_device(tree: SceneTree) -> void:
	if DisplayServer.get_name()=="headless":
		tree.root.get_node("ItemIcons").set_process(false)
	var node: Node=load("res://scripts/studio/village/encounter_probe.gd").new()
	tree.root.add_child.call_deferred(node)
func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--village-encounter="):mode=arg.trim_prefix("--village-encounter=")
		if arg.begins_with("--shot="):shot_path=arg.trim_prefix("--shot=")
	run.call_deferred()
func frames(n: int) -> void:
	for _i in n:await get_tree().process_frame
func seconds(s: float) -> void:
	var start := People.tick(VillageSession.village)
	while People.tick(VillageSession.village)-start<roundi(s*1000):
		await get_tree().process_frame
func check(ok: bool,text: String) -> void:
	print(("PASS encounter " if ok else "FAIL encounter ")+text)
	if not ok:failed+=1
func run() -> void:
	await frames(180)
	live=get_tree().current_scene.get_node_or_null("VillageLive")
	player=get_tree().get_first_node_in_group("player")
	if live==null:
		check(false,"live missing")
		get_tree().quit(1)
		return
	res=live.registry
	while not res.all_built():await get_tree().process_frame
	var v=VillageSession.village
	for p in v.people:
		if p.alive and p.present and p.authored=="" and Rules.age_of(v,p)>=18 and not p.locked:
			cast.append(p.id)
			if cast.size()==5:break
	if cast.size()!=5:
		check(false,"cast missing")
		get_tree().quit(1)
		return
	v.runtime.events.clear()
	v.people_facts.clear()
	v.authority=cast[4]
	for id in cast:
		v.people[id].mind=preload("res://scripts/studio/village/sim/state.gd").Mind.new()
		v.people[id].traits[Rules.C.BOLD]=45
		v.people[id].traits[Rules.C.ALERT]=65
		v.people[id].hurt=0
		v.people[id].down_until=-1
		v.people[id].plan=PackedInt32Array([0,1440,v.pl_well])
		res._leave_situation(id)
		res._drop_stay(id)
		res.owners.claim(id,"cast",2)
		res.destinations.erase(id)
	var victim:=cast[0]
	var friend:=cast[1]
	var timid:=cast[2]
	var distracted:=cast[3]
	var helper:=cast[4]
	v.people[friend].traits[Rules.C.BOLD]=80
	var rel: int=v.people[friend].rel_k.find(victim)
	if rel>=0:v.people[friend].rel_v[rel]=70
	else:
		v.people[friend].rel_k.append(victim)
		v.people[friend].rel_v.append(70)
		v.people[friend].rel_abs.append(70)
	v.people[timid].traits[Rules.C.BOLD]=15
	v.people[helper].traits[Rules.C.BOLD]=85
	v.people[helper].values[Rules.C.V_LAW]=80
	v.people[distracted].mind.modifiers.append({"id":"distracted","delay_ms":2400})
	VillageImage.drifted(distracted) # a fixture write outside acceptance: the next batch takes it in
	# The cast's fresh minds, traits and plans above are fixture writes outside acceptance too (on a reused save they
	# replace remembered minds): the next frame writes a full save from live, as after a load.
	VillageImage.stale = true
	# merge-enea (6 Oct): his layout wins, and his villagers and campfire now stand on the green at (0, 20). The cast
	# is arranged on the first centre where every spot is standable, none of his villagers is within 2.5 m, and the
	# witnesses, the victim and the player see each other (so the timid witness sees the blow, as the fixture means).
	var offsets:=[Vector2.ZERO,Vector2(3,1),Vector2(-4,2),Vector2(5,5),Vector2(-24,0)]
	var centre:=pick_centre(offsets)
	print("ENCOUNTER centre=",centre)
	var positions:=offsets.map(func(o:Vector2)->Vector2:return centre+o)
	for i in cast.size():
		var id:=cast[i]
		var pos:Vector2=positions[i]
		res._movers[id].indoors=false
		res._movers[id].active=true
		res._movers[id].place(pos,PI)
		res._movers[id].hold(pos,centre)
		res.bodies[id].show()
	player.global_position=Vector3(centre.x,WorldShape.new().height_at(centre.x,centre.y),centre.y-1.8)
	player.visual.rotation.y=0
	player.fighter.target=null
	Inventory.add("apple",5)
	camera=Camera3D.new()
	camera.fov=50
	add_child(camera)
	camera.global_position=player.global_position+Vector3(8,6,10)
	camera.look_at(Vector3(centre.x,player.global_position.y+0.8,centre.y))
	camera.make_current()
	await frames(15)
	if mode=="sequence":await shot("01-before",false)
	if mode=="before":
		await shot()
		return
	if mode in ["water","water_check"]:
		await water_route(victim)
		return
	if mode in ["fire","fire_check"]:
		player.abilities._drop_star(null,res.bodies[victim].global_position,1.0)
		await seconds(2.0)
		var m=VillageSession.village.people[victim].mind
		check(m.plan.get("offer","")=="escape_fire" and m.known.size()>0,"real Meteor accepted through second P1 source and own chooser")
		check(res._elements[victim].playing.has("burning") and res._movers[victim].can_move(),"flames overlay permits chosen escape")
		var restored=Codec.from_data(Codec.to_data(VillageSession.village,false))
		check(restored.people[victim].body_facts.has("burning") and restored.people[victim].mind.known.size()>0,"accepted fire fact and memory persist")
		if mode=="fire":
			await shot()
			return
		await seconds(5.0)
		check(not res._elements[victim].playing.has("burning") and VillageSession.village.people[victim].mind.known.size()>0,"timed flames end without erasing deed")
		print("FIRE complete failures=%d" % failed)
		get_tree().quit(0 if failed==0 else 1)
		return
	var eligible:=Contact.candidates(get_tree(),player,2.8,Vector3.BACK)
	check(eligible.any(func(c:Dictionary)->bool:return int(c.id)==victim),"unsquared adult eligible through contact geometry")
	check(not live.get_node("Provoke").is_squared_up(victim),"no fight mode required")
	var writes:=Accept.writes
	player.heavy()
	await seconds(1.0)
	v=VillageSession.village
	check(v.people[victim].mind.known.size()>0,"real Heavy accepted and remembered")
	check(Accept.writes>writes,"normal checked save written")
	for who: int in [friend,timid]:
		var m=v.people[who].mind
		var b=res.people_bridge
		print("ENCOUNTER diag id=%d offer=%s known=%d pending_due=%s now=%d wake=%d batch_at=%d retry_at=%d phases=%d reports=%d uses=%d notices=%d captures=%d" % [who,str(m.plan.get("offer","")),m.known.size(),
			str(m.pending.map(func(a)->int:return int(a.due))),People.tick(v),b._wake_tick,b._batch_at,b._retry_at,b.phase_requests.size(),b.reports.size(),b.uses.size(),b.notices.size(),b._contact_captures.size()])
	check(v.people[friend].mind.plan.get("offer","")=="intervene","friend chooses intervention")
	check(v.people[timid].mind.plan.get("offer","")=="fetch_help","timid witness chooses journey")
	check(v.people[distracted].mind.known.is_empty() and not v.people[distracted].mind.pending.is_empty(),"distracted witness waits")
	var first_deed:=str(v.people[victim].body_facts.get("hurt",{}).get("deed",""))
	if mode=="sequence":await shot("02-impact",false)
	if mode=="impact":
		await shot()
		return
	if mode=="route_check":
		var generations := {}
		var begin := People.tick(VillageSession.village)
		while People.tick(VillageSession.village)-begin<8000:
			for id in cast:
				var mind=VillageSession.village.people[id].mind
				if generations.get(id,-1)!=mind.generation:
					generations[id]=mind.generation
					print("ROUTE changed actor=",id," tick=",People.tick(VillageSession.village)," generation=",mind.generation," plan=",mind.plan," known=",mind.known.keys())
			await get_tree().process_frame
		for id in cast:
			var person=VillageSession.village.people[id]
			if res.people_bridge.runners.has(id):
				var runner=res.people_bridge.runners[id].runner
				print("ROUTE runner actor=",id," started=",runner._semantic_started," done=",runner._semantic_done," state=",runner._primitive_state," requested=",res.people_bridge.phase_requests.get(id,{}))
			print("ROUTE actor=",id," tick=",People.tick(VillageSession.village)," available=",res.people_bridge.available()," owner=",res.owners.owner(id)," at=",res._movers[id].pos," move=",res._movers[id].can_move()," constraints=",res._movers[id].constraints," plan=",person.mind.plan.get("offer","")," phase=",person.mind.plan.get("phase",-1)," pending=",person.mind.pending.map(func(a: Dictionary)->Array:return [a.due,a.kind])," deadline=",res.people_bridge._wake_tick," log=",res.people_bridge.log)
		print("ROUTE complete failures=",failed)
		get_tree().quit(0 if failed==0 else 1)
		return
	# Actual captured attention includes temperament and distraction, plus the Heavy windup.
	var notice_start:=People.tick(VillageSession.village)
	while VillageSession.village.people[distracted].mind.known.is_empty() and People.tick(VillageSession.village)-notice_start<7000:
		await get_tree().process_frame
	check(not VillageSession.village.people[distracted].mind.known.is_empty(),"delayed account accepted and saved")
	if mode=="sequence":await shot("03-notice",false)
	if mode=="notice":
		var waited:=People.tick(VillageSession.village)
		while People.tick(VillageSession.village)-waited<18000 and not res.people_bridge.log.any(func(row:Array)->bool:return row[0]=="say" and str(row[2]).contains("dead flies")):
			await get_tree().process_frame
		await shot()
		return
	var started:=People.tick(VillageSession.village)
	var traveled:=false
	var reported:=false
	var report_memory: Dictionary={}
	var witness_key:=People.key(VillageSession.village,timid)
	var incident:=first_deed
	var report_key:="report:"+(incident+"|"+witness_key+"|"+People.key(VillageSession.village,helper)).sha256_text().substr(0,32)
	while People.tick(VillageSession.village)-started<55000:
		if res._movers[timid].pos.distance_to(positions[2])>5:traveled=true
		for account: Dictionary in VillageSession.village.people[helper].mind.known.values():
			var act: Dictionary=account.get("facets",{}).get("act",{})
			# The accepted receipt and canonical facet prove this witness's actual report. A prior cry
			# can already occupy the merged account; its optional top-level transmission list is not authority.
			if str(account.deed)==incident and str(act.get("via",""))=="told" and str(act.get("speaker",""))==witness_key and VillageSession.village.people_facts.has(report_key):
				reported=true;report_memory=account
		if reported:break # A cry or visible condition is not the witness's saved report.
		await get_tree().process_frame
	if not reported: # the help chain in full, so a missed report is diagnosable from the log
		var vv=VillageSession.village
		for id in [timid,helper,victim]:
			var person=vv.people[id]
			print("HELPCHAIN actor=",id," tick=",People.tick(vv)," at=",res._movers[id].pos," owner=",res.owners.owner(id)," move=",res._movers[id].can_move()," plan=",person.mind.plan.get("offer","")," phase=",person.mind.plan.get("phase",-1)," steps=",person.mind.plan.get("steps",[]).size()," pending=",person.mind.pending.map(func(a: Dictionary)->Array:return [a.due,a.kind])," known=",person.mind.known.keys().size())
		print("HELPCHAIN bridge reports=",res.people_bridge.reports.keys()," uses=",res.people_bridge.uses.keys()," notices=",res.people_bridge.notices.size()," witnesses=",res.people_bridge.witnesses.size()," report_key_saved=",vv.people_facts.has(report_key)," log_tail=",res.people_bridge.log.slice(-8))
	check(traveled,"witness physically leaves to fetch help")
	if reported and not (report_memory.get("facets",{}).get("act",{}).get("via","")=="told" and report_memory.identity.learned=="told"):
		print("HELPCHAIN report_memory identity=",report_memory.get("identity",{})," act=",report_memory.get("facets",{}).get("act",{})," helper_at=",res._movers[helper].pos," victim_at=",res._movers[victim].pos)
	check(reported and report_memory.get("facets",{}).get("act",{}).get("via","")=="told" and report_memory.identity.learned=="told","helper receives saved told account at real proximity")
	check(VillageSession.village.people[helper].mind.plan.get("offer","")=="intervene","helper independently chooses to help")
	if mode=="sequence":
		camera.global_position=res.bodies[timid].global_position+Vector3(7,5,8)
		camera.look_at(res.bodies[timid].global_position+Vector3(0,0.8,0))
		await shot("04-report",false)
		camera.global_position=player.global_position+Vector3(8,6,10)
		camera.look_at(res.bodies[victim].global_position+Vector3(0,0.8,0))
	if mode=="report":
		camera.global_position=res.bodies[timid].global_position+Vector3(7,5,8)
		camera.look_at(res.bodies[timid].global_position+Vector3(0,0.8,0))
		await shot()
		return
	started=People.tick(VillageSession.village)
	while People.tick(VillageSession.village)-started<25000 and res._movers[helper].pos.distance_to(res._movers[victim].pos)>3.5:
		await get_tree().process_frame
	check(reported and res._movers[helper].pos.distance_to(res._movers[victim].pos)<=3.5,"help actually travels and arrives")
	if mode=="sequence":await shot("05-help",false)
	if mode=="help":
		await shot()
		return
	if mode=="report_check":
		print("REPORT complete failures=%d" % failed)
		get_tree().quit(0 if failed==0 else 1)
		return
	player.global_position=res.bodies[victim].global_position+Vector3(0,0,-1.8)
	player.visual.rotation.y=0
	player.fighter.target=null
	player.heavy()
	await seconds(1.2)
	print("ENCOUNTER second visible=%s inside=%s hurt=%d down=%s candidates=%s playerdown=%s busy=%s" % [res.bodies[victim].is_visible_in_tree(),res._movers[victim].indoors,VillageSession.village.people[victim].hurt,VillageSession.village.people[victim].down_until,Contact.candidates(get_tree(),player,2.8,Vector3.BACK),player._down,player.fighter.is_busy()])
	check(int(VillageSession.village.people[victim].mind.stances.get("player:local",{}).get("hits",0))>=2,"repeated aggression retained")
	check(VillageSession.village.people[victim].mind.plan.get("offer","")=="retreat","repeated aggression changes victim choice")
	if VillageSession.village.people[victim].mind.plan.get("offer","")!="retreat":
		var history=VillageSession.village.people[victim].mind
		var account: Dictionary=People.episode_account(history,history.episodes[-1]) if not history.episodes.is_empty() else {}
		var profile:=People.profile(VillageSession.village,People.key(VillageSession.village,victim),account)
		print("ENCOUNTER repeat profile=",{"courage":profile.courage,"hits":profile.hits,"pain":profile.pain,"target":account.get("target",""),"identity":account.get("identity",{}),"plan":history.plan.get("offer","")})
	if mode=="down":
		await seconds(2.0)
		print("ENCOUNTER down element=",res._elements[victim].playing," clip=",res.bodies[victim]._anim.current_animation," time=",res.bodies[victim]._anim.current_animation_position," length=",res.bodies[victim].animation_length("Hit_Knockback"))
		await shot()
		return
	var down_at:Vector2=res._movers[victim].pos
	await seconds(1)
	check(res._movers[victim].vel.length()<0.01,"down body planted")
	await seconds(1.0)
	check(res._elements[victim].playing.has("down") and res._elements[victim].playing.down.state.get("phase","")=="lie","down element reaches held ground pose")
	if mode=="sequence":await shot("06-down",false)
	await seconds(7)
	check(res._movers[victim].can_move(),"visible recovery releases physical constraint")
	check(res._movers[victim].pos.distance_to(down_at)<8.0,"recovery resumes from actual position")
	if mode=="sequence":await shot("07-recovery",false)
	if mode=="risen":
		await shot()
		return
	player.global_position=res.bodies[victim].global_position+Vector3(0,0,-1.5)
	var m=VillageSession.village.people[victim].mind
	var anger:=int(m.affect.anger)
	var known: int=m.known.size()
	var result:Dictionary=res.people_bridge.action("give",victim,{"item":"apple","count":1,"press_id":"fixture:gift"})
	print("ENCOUNTER gift ",result)
	check(result.accepted and int(VillageSession.village.people[victim].mind.affect.anger)<anger,"gift softens anger")
	check(VillageSession.village.people[victim].mind.known.size()>=known,"gift keeps deed")
	await seconds(4)
	if mode=="sequence":await shot("08-gift",false)
	if mode=="gift":
		await shot()
		return
	if mode=="slice_check":
		print("SLICE complete failures=%d writes=%d facts=%d" % [failed,Accept.writes,VillageSession.village.people_facts.size()])
		get_tree().quit(0 if failed==0 else 1)
		return
	var save_result:=SaveGame.save_game()
	var snapshot:=Codec.to_data(VillageSession.village,false)
	SaveGame.load_game()
	check(save_result==OK and VillageSession.village.people[victim].mind.known.size()>=known,"normal save/load retains accepted episodes")
	var roundtrip=Codec.from_data(snapshot)
	check(roundtrip.people[victim].mind.known.size()>=known,"region-independent saved episode")
	check(not VillageSession.village.runtime.get("reactions",{}).has(str(victim)),"no migrated legacy decision")
	var before=VillageSession.village
	var failed_save:=Accept.transact(func(candidate)->Dictionary:
		candidate.people[victim].mind.known["rollback"]={}
		return {"accepted":true},func()->int:return ERR_CANT_CREATE)
	check(not failed_save.accepted and VillageSession.village==before and not before.people[victim].mind.known.has("rollback"),"failed save publishes no facts")
	var overdraw:=Accept.transact(func(candidate)->Dictionary:
		candidate.people[victim].mind.known["unpaid"]={}
		return {"accepted":true,"costs":[{"item":"apple","count":Inventory.count("apple")},{"item":"apple","count":1}]})
	check(not overdraw.accepted and VillageSession.village==before and not before.people[victim].mind.known.has("unpaid"),"batch costs checked together before publishing")
	var request := {"action_id":"fixture:retry","actor":"actor:other","target":People.key(before,victim),"verb":"square_up",
		"village_id":before.runtime.village,"logical_time":before.runtime.now,"parameters":{}}
	var prepare:=func(candidate)->Dictionary:return preload("res://scripts/studio/village/sim/people_actions.gd").prepare(candidate,request,{"authorized":true,"distance_dm":10})
	var refused:=Accept.transact(prepare,func()->int:return ERR_CANT_CREATE)
	var retried:=Accept.transact(prepare)
	var replay:=Accept.transact(prepare)
	check(not refused.accepted and retried.accepted and replay.get("duplicate",false),"failed action retries once; accepted replay idempotent")
	var memory_count: int=VillageSession.village.people[victim].mind.known.size()
	var measured_senses: Array=res.people_bridge.sense_usec.duplicate()
	Region.travel("forest",Vector2.ZERO)
	while Region.current!="forest" or Region._busy:await get_tree().process_frame
	await frames(30)
	check(VillageSession.village.people[victim].mind.known.size()==memory_count,"leaving region retains episode")
	Region.travel("meadow",Vector2(0,18))
	while Region.current!="meadow" or Region._busy:await get_tree().process_frame
	await frames(45)
	check(VillageSession.village.people[victim].mind.known.size()==memory_count,"returning region retains episode")
	print("MEASURE desktop sense_us ",measured_senses)
	print("MEASURE desktop accept ",Accept.measures)
	if mode=="sequence":
		camera.make_current()
		await shot("09-return",false)
		await shot("",false) # The common capture runner also requires its named final image.
	if mode=="return":
		camera.make_current()
		await shot()
		return
	print("ENCOUNTER complete failures=%d writes=%d facts=%d" % [failed,Accept.writes,VillageSession.village.people_facts.size()])
	get_tree().quit(0 if failed==0 else 1)
func shot(label := "",finish := true) -> void:
	await frames(3)
	await RenderingServer.frame_post_draw
	var path := shot_path if label.is_empty() else shot_path.get_base_dir().path_join(label+".png")
	var error:=get_viewport().get_texture().get_image().save_png(path)
	print("ENCOUNTER shot %s %s error=%d" % [mode,path,error])
	if error!=OK:failed+=1
	if finish:get_tree().quit(0 if error==OK else 1)

## Permanent C4 arrival proof: existing layout water, native Burst and actual chosen travel/use.
## The first open centre for the cast (see run): standable spots, his villagers clear, plain sight among the near cast.
func pick_centre(offsets: Array) -> Vector2:
	var npcs:=get_tree().current_scene.find_children("*","Node3D",true,false).filter(func(n:Node)->bool:return n.get_script()==preload("res://scripts/world/npc.gd"))
	var space:PhysicsDirectSpaceState3D=(get_tree().current_scene as Node3D).get_world_3d().direct_space_state
	var shape:=WorldShape.new()
	for c:Vector2 in [Vector2(0,20),Vector2(0,30),Vector2(-2,34),Vector2(6,32),Vector2(-4,12),Vector2(0,10),Vector2(20,20),Vector2(-20,30)]:
		var ok:=true
		var spots:Array=offsets.map(func(o:Vector2)->Vector2:return c+o)
		spots.append(c+Vector2(0,-1.8)) # where the player stands
		for p:Vector2 in spots:
			if not res._world.standable.call(p):ok=false
			for n:Node3D in npcs:
				if Vector2(n.global_position.x,n.global_position.z).distance_to(p)<2.5:ok=false
		for i in [0,1,2,3]:
			for j in [0,1,2,3,5]:
				if i!=j and ok:
					var a:Vector2=spots[i];var b:Vector2=spots[j]
					var q:=PhysicsRayQueryParameters3D.create(Vector3(a.x,shape.height_at(a.x,a.y)+1.5,a.y),Vector3(b.x,shape.height_at(b.x,b.y)+1.5,b.y))
					if not space.intersect_ray(q).is_empty():ok=false
		if ok:return c
	return Vector2(0,20)


## Only cast positions are arranged; no injected plan, arrival, extinguish or guessed 'water' destination.
func water_route(victim: int) -> void:
	var water := Water.resolve(res,res._movers[victim].pos,victim)
	check(not water.is_empty(),"concrete layout water has a completely reachable stand point")
	if water.is_empty():
		print("WATER complete failures=%d" % failed)
		get_tree().quit(1)
		return
	var stand := Vector2(float(water.at[0]),float(water.at[1]))
	var start := Vector2.INF
	for offset: Vector2 in [Vector2(6,0),Vector2(-6,0),Vector2(0,6),Vector2(0,-6)]:
		var point := stand+offset
		var reachable := Water.resolve(res,point,victim)
		if res._world.standable.call(point) and not reachable.is_empty() and str(reachable.key)==str(water.key):
			start=point;break
	if start==Vector2.INF:
		check(false,"water cast has no clear start")
		print("WATER complete failures=%d" % failed)
		get_tree().quit(1)
		return
	for id: int in cast:
		var point := start if id==victim else start+Vector2(-45-id*3,0)
		res._movers[id].place(point,PI)
		res._movers[id].hold(point,stand)
	await frames(3) # Actual body adapters consume placement before the native ability measures its contact.
	player.global_position=res.bodies[victim].global_position+Vector3(0,0,-1.5)
	camera.global_position=res.bodies[victim].global_position+Vector3(9,6,10)
	camera.look_at(Vector3(stand.x,player.global_position.y+0.8,stand.y))
	await frames(3)
	player.abilities._cinderburst({"press_id":"fixture:water-burst"})
	await seconds(0.5)
	var v=VillageSession.village
	var fire: Dictionary=v.people[victim].body_facts.get("burning",{})
	var cause := str(fire.get("deed",""))
	check(not cause.is_empty() and v.people[victim].mind.plan.get("offer","")=="escape_fire","native Burst admits own fire and chooses concrete water")
	var began := People.tick(v)
	var uses := []
	while People.tick(VillageSession.village)-began<14000:
		uses=[]
		for fact: Dictionary in VillageSession.village.people_facts.values():
			var receipt: Dictionary=fact.get("receipt",{})
			if str(fact.get("verb",""))=="extinguish" and str(receipt.get("fire_cause",""))==cause and str(receipt.get("method",""))=="water":uses.append(fact)
		if not uses.is_empty() or not VillageSession.village.people[victim].alive:break
		await get_tree().process_frame
	v=VillageSession.village
	var at: Vector2=res._movers[victim].pos
	check(uses.size()==1 and at.distance_to(start)>2 and Water.contact(res,at,at,str(water.key)),"real travel reaches water and one checked contact extinguishes its own fire")
	var restored=Codec.from_data(Codec.to_data(v,false))
	check(v.people[victim].alive and not v.people[victim].body_facts.has("burning") and restored.people[victim].mind.known.size()>0 and restored.people_facts.size()==v.people_facts.size(),"saved rescue retains the fire deed and checked use")
	print("WATER route key=%s start=%s actual=%s checked_uses=%d" % [water.key,start,at,uses.size()])
	if mode=="water":
		await shot()
		return
	print("WATER complete failures=%d" % failed)
	get_tree().quit(0 if failed==0 else 1)
