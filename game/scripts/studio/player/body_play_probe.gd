extends Node
## B6/P1 normal HUD/physical proof. Uses actual scene, pointers, measured contact, checked rules and Claude bodies.
## --studio=village/live --body-play=flow|inactive|labels|feet|contact|actor|sequence|talk|crowd|things|buttons --test-save=<fresh-name> [--shot=<png> --shotframe=999999]
## Cast positioning/traits are fixtures; expressions, consequences, choices and locomotion remain their owners'.
const People := preload("res://scripts/studio/village/sim/people.gd")
const Rules := preload("res://scripts/studio/village/sim/village.gd")
const Contact := preload("res://scripts/studio/village/contact.gd")
const Speech := preload("res://scripts/studio/people/speech.gd")
const View := preload("res://scripts/studio/village/sim/view.gd")
const Feel := preload("res://scripts/studio/player/contact_feel.gd")
var failed := 0
var hud: Node
var player: Node3D
var res: Node
var mode := "flow"
var shot_path := ""
var cast: Array[int] = []
var camera: Camera3D
var subject := -1 # The person the board frames beside the player; -1 frames the player alone.
var _frame_on: Node3D # Talk mode: one of Enea's characters framed beside the player (not a resident).
var caption: Label
var releases := 0
static func report() -> PackedStringArray:
	var ready := true
	for path: String in ["res://scripts/ui/hud.gd","res://scripts/studio/player/hands.gd","res://scripts/studio/player/body_play_probe.gd"]:
		var script := load(path) as Script
		ready=ready and script!=null and script.can_instantiate()
	return PackedStringArray([("PASS BODY LOAD " if ready else "FAIL BODY LOAD ")+"actual HUD, Hands and normal-play fixture compile"])
static func on_device(tree: SceneTree) -> void:
	if tree.root.has_node("BodyPlayProbe"):
		return
	var probe: Node=load("res://scripts/studio/player/body_play_probe.gd").new()
	probe.name="BodyPlayProbe"
	tree.root.add_child.call_deferred(probe)
func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--body-play="):mode=arg.trim_prefix("--body-play=")
		if arg.begins_with("--shot="):shot_path=arg.trim_prefix("--shot=")
	if DisplayServer.get_name()=="headless":get_tree().root.get_node("ItemIcons").set_process(false)
	run.call_deferred()
func frames(n: int) -> void:
	for _i in n:await get_tree().process_frame
func active(seconds: float) -> void:
	var start := People.tick(VillageSession.village)
	var wall_start := Time.get_ticks_msec()
	var seen := start
	while People.tick(VillageSession.village)-start<roundi(seconds*1000):
		if People.tick(VillageSession.village)!=seen: # A slow renderer still advances; only a stopped clock stalls.
			seen=People.tick(VillageSession.village)
			wall_start=Time.get_ticks_msec()
		if Time.get_ticks_msec()-wall_start>45000:
			check(false,"active clock stalled: tick=%d locked=%s background=%s paused=%s tree=%s scale=%s" % [People.tick(VillageSession.village),Controls.locked,VillageSession.background,SaveGame.paused,get_tree().paused,Engine.time_scale])
			get_tree().quit(2)
			return
		await get_tree().process_frame
func check(ok: bool,words: String) -> void:
	print(("PASS BODY PLAY " if ok else "FAIL BODY PLAY ")+words)
	if not ok:failed+=1
func touch(id: int,at: Vector2,pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index=id
	event.position=at
	event.pressed=pressed
	get_viewport().push_input(event,true) # Centres are viewport coordinates; window stretch must not map them twice.
func drag(id: int,from: Vector2,to: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index=id
	event.position=to
	event.relative=to-from
	get_viewport().push_input(event,true)
func one_hands() -> bool:
	var hands: Array=get_tree().get_nodes_in_group("studio_hands")
	return hands.size()==1 and hands[0]==hud._hands and hands[0].get_child_count()==1
func run() -> void:
	await frames(40)
	hud=get_tree().get_first_node_in_group("hud")
	player=get_tree().get_first_node_in_group("player")
	if hud==null or player==null or VillageSession.village==null:
		check(false,"normal boot missing")
		finish()
		return
	if mode=="flow":
		await flow()
	elif mode=="inactive":
		await inactive()
	elif mode=="labels":
		await labels()
	elif mode=="feet":
		await feet()
	elif mode=="talk":
		await talk()
	elif mode=="crowd":
		await crowd()
	elif mode=="buttons":
		await preload("res://scripts/studio/player/buttons_play.gd").run(self)
	elif mode=="still":
		await still()
	elif mode=="things":
		await preload("res://scripts/studio/player/things_play.gd").run(self)
	else:
		await sequence()
	finish()
func finish() -> void:
	SaveGame.paused=true
	print("BODY PLAY complete mode=%s failures=%d" % [mode,failed])
	get_tree().quit(0 if failed==0 else 1)
func flow() -> void:
	check(one_hands() and hud._hands.is_visible_in_tree(),"normal boot has one live Hands and actual pose adapter")
	hud.show_title()
	hud.start_game(true)
	hud.show_title()
	hud.start_game(true)
	await frames(2)
	check(one_hands(),"return to title reuses the input and pose owners")
	var camera_at := Vector2(get_viewport().get_visible_rect().size.x*0.7,90)
	var hand_at: Vector2=hud._hands.centres().hand
	touch(41,camera_at,true)
	var previous := camera_at
	for i in 6:
		var next := camera_at.lerp(hand_at,float(i+1)/6.0)
		drag(41,previous,next)
		previous=next
	await frames(2)
	check(hud._camera_drag._finger==41 and hud._hands.pointers.is_empty(),"camera-origin finger stays camera across the hand surface")
	touch(41,hand_at,false)
	var guard_at: Vector2=hud._hands.surfaces().get("parry",hand_at) # C1: his Parry holds the guard
	touch(42,guard_at,true)
	await active(0.4)
	print("BODY GUARD viewport=",get_viewport().get_visible_rect().size," at=",hand_at," pointers=",hud._hands.pointers.keys()," preview=",hud._hands.preview()," held=",hud._hands._live," camera=",hud._camera_drag._finger," locked=",Controls.locked," background=",VillageSession.background," guard=",player._guard," rest=",player._guard_rest," stamina=",player.stamina.value," down=",player._down," stun=",player._stun)
	check(player._studio_guard and (hud._hands.pointers.has(42) or hud._hands._live.has(42)),"still Hand holds actual guard without a fight mode")
	hud.open_bag()
	await frames(2)
	check(not player._studio_guard and hud._hands.pointers.is_empty() and not hud._hands.visible,"modal hiding cancels the held intent")
	var panel: Node=hud.get_children().filter(func(n: Node) -> bool: return n.get_script()==load("res://scripts/ui/inventory_panel.gd"))[0]
	panel._close()
	await frames(2)
	hud.set_indoors(true)
	var indoor_ok: bool=not hud._map.visible and hud._hands.is_visible_in_tree()
	hud.set_indoors(false)
	hud._on_settings_changed()
	check(indoor_ok and hud._map.visible==Settings.show_map,"indoor and settings map follow the actual play surface")
	var error := SaveGame.save_game()
	SaveGame.load_game()
	Region.travel("forest",Vector2.ZERO)
	while Region.current!="forest" or Region._busy:await get_tree().process_frame
	await frames(10)
	hud=get_tree().get_first_node_in_group("hud")
	check(error==OK and one_hands() and hud._hands.is_visible_in_tree(),"normal save/load and forest arrival build one live input owner")
	Region.travel("meadow",Vector2(0,18))
	while Region.current!="meadow" or Region._busy:await get_tree().process_frame
	await frames(10)
	hud=get_tree().get_first_node_in_group("hud")
	check(one_hands() and hud._hands.is_visible_in_tree(),"meadow return preserves one input and actual pose owner")
func inactive() -> void:
	var hand_at: Vector2=hud._hands.surfaces().get("act",hud._hands.centres().hand)
	var guard_at: Vector2=hud._hands.surfaces().get("parry",hud._hands.centres().hand) # C1: his Parry holds the guard
	var move_at := Vector2(200,get_viewport().get_visible_rect().size.y-180)
	var camera_at := Vector2(get_viewport().get_visible_rect().size.x*0.7,90)
	hud._hands.intent_changed.connect(func(intent: Dictionary) -> void:
		if str(intent.get("phase",""))=="released":releases+=1)
	var to: Vector2=hand_at+Vector2(0,58)*hud._hands.unit()
	touch(61,hand_at,true)
	drag(61,hand_at,to)
	var roots_before: int=VillageSession.village.people_facts.size()
	VillageSession.background=true
	touch(61,to,false) # No inactive process frame has run yet.
	check(releases==0 and hud._hands.pointers.is_empty() and VillageSession.village.people_facts.size()==roots_before,"background queued release cancels before commitment")
	touch(62,guard_at,true)
	touch(63,move_at,true)
	drag(63,move_at,move_at+Vector2(0,75))
	touch(64,camera_at,true)
	drag(64,camera_at,camera_at+Vector2(50,0))
	await frames(3)
	check(hud._hands.pointers.is_empty() and hud._joystick._finger==-1 and hud._camera_drag._finger==-1 and Controls.joystick==Vector2.ZERO and not Controls.stick_sprint,"background fresh pointers cannot acquire hand movement or camera")
	VillageSession.background=false
	touch(65,guard_at,true)
	touch(66,move_at,true)
	drag(66,move_at,move_at+Vector2(0,75))
	touch(67,camera_at,true)
	await active(0.5)
	var held_ok: bool=player._studio_guard and hud._joystick._finger==66 and hud._camera_drag._finger==67 and Controls.stick_sprint
	VillageSession.background=true
	await frames(3)
	check(held_ok and not player._studio_guard and hud._hands.pointers.is_empty() and hud._joystick._finger==-1 and hud._camera_drag._finger==-1 and not hud._camera_drag.camera_rig.held and not Controls.stick_sprint,"background clears actual guard sprint and camera holds")
	VillageSession.background=false
	await active(1.4) # Native guard cooldown remains native; background does not consume it.
	touch(68,guard_at,true)
	await active(0.4)
	var resumed: bool=player._studio_guard and (hud._hands.pointers.has(68) or hud._hands._live.has(68))
	touch(68,guard_at,false)
	check(resumed and not player._studio_guard and releases==1,"resume accepts fresh guard without replaying released strike")
func position_player(at: Vector3) -> void:
	player.global_position=at
	player.velocity=Vector3.ZERO
	player.visual.rotation.y=0
	player.fighter.target=null
## kind: hand (flick strike), shove (slow push), grip (pick up / set down). In the act scheme they are motions in
## the one thumb area: a one-frame flick, a push of 6 px a frame, a still tap; with --controls=discs, disc strokes.
## C1: the thumb area is his Attack button (a flick, a still tap), and the shove is his Heavy's tap on the villager.
func stroke(kind: String,heavy := false,target := -1) -> Dictionary:
	var act: bool=hud._hands.scheme=="act"
	var at: Vector2=hud._hands.surfaces()[("heavy" if kind=="shove" else "act") if act else kind]
	var offset: Vector2=Vector2(0,58)*hud._hands.unit()
	if target>=0:
		var direction: Vector3=res.bodies[target].global_position-player.global_position
		offset=Vector2(direction.x,direction.z).normalized().rotated(Controls.cam_yaw)*58*hud._hands.unit()
	var to: Vector2=at+offset
	touch(51,at,true)
	if act and kind=="grip":
		to=at
		await frames(2) # A still tap: the driver's own rule picks lift or set down.
	elif act and kind=="hand" and not heavy:
		var from := at
		for i in 3: # A lazy flick: 20 px a frame at 30 fps, 600 px/s, a light blow (slice 2).
			var next: Vector2=at+offset*float(i+1)/3.0
			drag(51,from,next)
			from=next
			await get_tree().process_frame
	elif act and kind=="shove":
		to=at
		await frames(2) # His Heavy's tap: the villager it shoves is captured at the press.
	else:
		drag(51,at,to)
	await active(0.55 if heavy else 0.07)
	if not hud._hands.pointers.has(51):
		print("BODY STROKE cancelled kind=",kind," locked=",Controls.locked," background=",VillageSession.background)
		return {}
	var gesture=hud._hands.pointers[51]
	var captured: Dictionary=gesture.target.duplicate()
	captured.verb=gesture.intent
	print("BODY STROKE prepared kind=",kind," role=",gesture.role," verb=",gesture.intent," press=",captured.press_id," target=",captured.target," context=",captured.get("context",{}).get("kind","")," forward=",captured.forward," age=",gesture.age," busy=",player.fighter._busy," playerdown=",player._down," stun=",player._stun," stamina=",player.stamina.value)
	var carrying: bool=hud._hands.driver.load_kind()!=""
	if target>=0 and kind in ["hand","shove"] and not (carrying and kind=="hand"):
		check(hud._hands.ring_target()==res.bodies[target],"prepared %s rings its captured target on the ground" % gesture.intent)
	if act and kind=="hand" and not carrying:
		var lean: float=hud._hands.preview().strength
		check(absf(lean-gesture.flick_force()/1000.0)<0.001,"the player's lean reads the aimed blow's force (%.2f)" % lean)
	if act and kind=="hand" and carrying:
		check(hud._hands.ring_target()==null and str(hud._hands.preview().verb)=="","carrying: an aimed flick rings nobody and the body does not lean into a blow")
	if kind=="shove" and shot_path!="" and DisplayServer.get_name()!="headless":
		await capture("02a-intent") # Actual prepared target/reach/cancel surface before this same commitment.
	touch(51,to,false)
	print("BODY STROKE released verb=",captured.verb," native_heavy=",player.fighter._heavy," native_key=",player.fighter._contact_key," impact=",player.fighter._impact," busy=",player.fighter._busy)
	return captured
## Talk happens in the world (brief section 3): people speak as he comes near, and his act is the answer, with no
## panel or button. Enea's character greets him as he comes up; a conversation's words reach him close by; a tap on
## someone in reach is answered aloud in the world (no talk screen, the controls stay live); a shove is answered by
## the one shoved. Frames talk-01 .. talk-05.
func talk() -> void:
	var live := get_tree().current_scene.get_node("VillageLive")
	res=live.registry
	while not res.all_built():await get_tree().process_frame
	var v=VillageSession.village
	var speech: Node=res.speech
	camera=Camera3D.new()
	add_child(camera)
	camera.fov=50
	camera.make_current()
	speech.camera=camera
	var overlay := CanvasLayer.new()
	add_child(overlay)
	caption=Label.new()
	caption.position=Vector2(get_viewport().get_visible_rect().size.x*0.36,14)
	caption.add_theme_font_size_override("font_size",26)
	overlay.add_child(caption)
	# 1. Enea's character: nothing said from 9 m; his greeting as he comes within reach.
	var npc: Node3D=null
	for n: Node3D in res._npcs:
		if is_instance_valid(n) and n.is_visible_in_tree():
			npc=n
			break
	check(npc!=null,"one of Enea's characters is in the village")
	if npc!=null:
		subject=-1
		_frame_on=npc
		# studio: Foundations, desk grant 6 Oct - a village alarm (a wolf) outranks his greeting and can crowd it out, which is
		# correct play: let it pass and come again (stepping back past 6 m lets him greet anew), up to four approaches.
		var far_quiet := true
		var greeted := false
		for _approach in 4:
			for _wait in 24:
				if speech._shown.is_empty() and speech._waiting.is_empty():break
				await active(0.25)
			position_player(npc.global_position+Vector3(0,0,-9))
			await active(1.2)
			far_quiet=far_quiet and not speech.saying(npc)
			if _approach==0:await capture("talk-01-far")
			position_player(npc.global_position+Vector3(0,0,-2.5))
			await active(1.2)
			greeted=speech.saying(npc)
			if greeted:break
		await capture("talk-02-he-comes-near")
		check(far_quiet and greeted,"Enea's %s says nothing to him 9 m off and greets him as he comes near (through speech.gd)" % str(npc.get("_id")))
		_frame_on=null
	# 2. A conversation: from close by, its words reach him.
	var sit=null
	var waited := 0.0 # (game seconds: a software render runs at a few frames a second)
	while sit==null and waited<90.0:
		for s in res.society.situations:
			if s.phase=="beats" and s.bodies.size()>=2 and s.shape() in ["circle","pair","crouch","beside"]: # (the shapes whose talk is voiced: residents._voices)
				sit=s
				break
		if sit==null:
			await active(0.5)
			waited+=0.5
	check(sit!=null,"a conversation is going on in the village")
	if sit!=null:
		var first: int=int(sit.who[0])
		subject=first
		position_player(res.bodies[first].global_position+Vector3(0,0,-2.2))
		var heard := false
		var t := 0.0
		while not heard and t<14.0:
			await active(0.5)
			t+=0.5
			for b in sit.bodies:
				heard=heard or speech.saying(b)
		await capture("talk-03-overheard")
		check(heard,"close to a conversation he catches its words in the world (%.1f s)" % t)
	# 3. His act is the answer: a tap on someone in reach is answered aloud, no talk screen; a shove, by the shoved.
	var who := -1
	var arguing := {} # (a tap on one of two arguing steps between them: residents.step_in, not this proof)
	for hid in res.runs:
		arguing[int(res.runs[hid].record.get("a",-1))]=true
		arguing[int(res.runs[hid].record.get("b",-1))]=true
	var second := -1 # (someone else, for the person-beside-the-board case at the end)
	for p in v.people:
		if not arguing.has(p.id) and p.alive and p.present and p.authored=="" and not p.locked and res.bodies.has(p.id) and res.bodies[p.id].is_visible_in_tree() and Rules.age_of(v,p)>=18 and (sit==null or not sit.who.has(p.id)) and res._movers[p.id].can_move():
			if who<0:
				who=p.id
			elif second<0:
				second=p.id
				break
	check(who>=0,"someone to go up to")
	if who<0:
		return
	subject=who
	res.owners.claim(who,"body_fixture",2)
	# C1 (desk, 6 Oct): an open centre clear of his things - standable, his villagers 2.5 m away, nothing of his in reach
	# of where he stands, plain sight - as Foundations did for the encounter. (Near the square: out at 50 m a wild
	# creature knocked the player down mid-proof; in a crowd the stroke's aim, nearest ahead, may pick another.)
	var room := _talk_centre(who)
	if room!=Vector2.INF:
		res._movers[who].place(room,PI)
		res._movers[who].hold(room,room+Vector2(0,-1))
		await frames(4)
	await approach(who,1.4)
	await active(0.3)
	var tap: Dictionary=hud._hands.driver.tap_context()
	var at: Vector2=hud._hands.surfaces()["act" if hud._hands.scheme=="act" else "hand"]
	touch(52,at,true)
	await frames(2)
	touch(52,at,false)
	await active(0.8)
	var panel := false
	for n in get_tree().root.find_children("*","Control",true,false):
		if n.get_script()!=null and str((n.get_script() as Script).resource_path).ends_with("ui/dialogue_panel.gd") and n.is_visible_in_tree():
			panel=true
	await capture("talk-04-tap-answered")
	check(str(tap.context.get("verb",""))=="Talk" and speech.saying(res.bodies[who]) and not panel and not Controls.locked,"a tap on %s is answered aloud in the world: no talk screen, the controls stay live (tap %s, panel %s)" % [str(View.describe(v,who).get("name",who)),str(tap.context.get("verb","")),str(panel)])
	await active(3.0)
	await approach(who,1.2)
	var shove := await stroke("shove",false,who)
	var shoved := await landed(shove,"shove",who)
	var settle := 0.0
	while shoved.is_empty() and settle<10.0: # (the checked acceptance can outlast landed()'s wall limit when rendered)
		await active(0.5)
		settle+=0.5
		shoved=receipt(shove,"shove",who)
	var answered := false
	var t2 := 0.0
	while not answered and t2<6.0:
		await active(0.25)
		t2+=0.25
		answered=speech.saying(res.bodies[who])
	await capture("talk-05-shove-answered")
	check(shoved.get("accepted",false) and answered,"a shove is answered by the one shoved, aloud in the world (%.2f s)" % t2)
	await beside_board(second)
	if shot_path!="" and DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(shot_path)==OK,"final talk image")
## The crowd (brief section 3: "he pushes through it. People stumble ..."): he runs through five people standing
## in his way, then through five more with a push held. Those he touches stumble a step (presentation only, Body's
## mover, no fact, no speech, no choice); a barge or the held push sends the checked shove, once a person. Frames
## crowd-01 .. crowd-04.
func crowd() -> void:
	var live := get_tree().current_scene.get_node("VillageLive")
	res=live.registry
	while not res.all_built():await get_tree().process_frame
	var v=VillageSession.village
	camera=Camera3D.new()
	add_child(camera)
	camera.fov=50
	camera.make_current()
	res.speech.camera=camera
	var arguing := {}
	for hid in res.runs:
		arguing[int(res.runs[hid].record.get("a",-1))]=true
		arguing[int(res.runs[hid].record.get("b",-1))]=true
	for p in v.people:
		if not arguing.has(p.id) and p.alive and p.present and p.authored=="" and not p.locked and res.bodies.has(p.id) and Rules.age_of(v,p)>=18 and res._movers[p.id].can_move():
			cast.append(p.id)
			if cast.size()==5:break
	check(cast.size()==5,"five people for the crowd")
	if cast.size()<5:
		return
	var start := _clear_spot(-1,9.0,[12.0,16.0,20.0,24.0,28.0,34.0,40.0],9.0) # (and 9 m of open ground every way: the
	# follow camera decides which way he runs, and a fence or a wall would stop him where no crowd does)
	check(start!=Vector2.INF,"open ground for the crowd (%s)" % str(start))
	if start==Vector2.INF:
		return
	var ground := func(p: Vector2) -> Vector3: return Vector3(p.x,WorldShape.new().height_at(p.x,p.y)+0.05,p.y)
	position_player(ground.call(start))
	await frames(4)
	# Which way a stick push up runs him (it follows the camera): measured, then the crowd stands across that way.
	var stick_at := Vector2(200,get_viewport().get_visible_rect().size.y-180)
	touch(54,stick_at,true)
	drag(54,stick_at,stick_at+Vector2(0,-120))
	await active(0.6)
	touch(54,stick_at+Vector2(0,-120),false)
	var ran_way := Vector2(player.global_position.x,player.global_position.z)-start
	var yaw_way := Vector2(0,-1).rotated(-Controls.cam_yaw)
	print("BODY CROWD calibrate ran=",ran_way.normalized()," from_yaw=",yaw_way," yaw=",Controls.cam_yaw)
	check(ran_way.length()>1.0 and ran_way.normalized().dot(yaw_way)>0.9,"a stick push up runs him the camera's way (%.1f m)" % ran_way.length())
	var actor := Contact.actor_of(player)
	for pass_i in 2:
		position_player(ground.call(start))
		await frames(4)
		var holding := pass_i==1
		var act_at: Vector2=hud._hands.surfaces()["act" if hud._hands.scheme=="act" else "shove"]
		if holding: # A push held on the thumb area: a slow push, then pressed on.
			touch(55,act_at,true)
			var from := act_at
			for i in 5: # 8 px a frame: 240 px/s at the probe's 30 fps, a push (slower would be a guard)
				drag(55,from,act_at+Vector2(0,-8.0*(i+1)))
				from=act_at+Vector2(0,-8.0*(i+1))
				await get_tree().process_frame
		# He sets off; the way he actually runs (the follow camera turns) is read, then the five stand across it ahead.
		var set_off := Vector2(player.global_position.x,player.global_position.z)
		touch(54,stick_at,true)
		drag(54,stick_at,stick_at+Vector2(0,-120))
		var push_at := act_at+Vector2(0,-40)
		var set_t := 0.0
		while set_t<0.25:
			if holding: # A held push keeps pressing on (a still finger would be a guard).
				drag(55,push_at,push_at+Vector2(0,-3))
				push_at+=Vector2(0,-3)
			await get_tree().process_frame
			set_t+=get_process_delta_time()
		var here := Vector2(player.global_position.x,player.global_position.z)
		var way := (here-set_off).normalized() if here.distance_to(set_off)>0.2 else ran_way.normalized()
		var side := Vector2(-way.y,way.x)
		var spots := [here+way*2.6,here+way*3.5+side*-0.35,here+way*3.5+side*0.35,here+way*4.4,here+way*5.3]
		for i in cast.size():
			var id: int=cast[i]
			res._leave_situation(id);res._drop_stay(id);res.owners.claim(id,"body_fixture",2);res.destinations.erase(id)
			res._movers[id].indoors=false;res._movers[id].active=true
			res._movers[id].place(spots[i],PI);res._movers[id].hold(spots[i],here)
			res.bodies[id].show()
		subject=cast[2]
		await frames(4) # (mover.place is drawn by the crowd's next steps: the board shows them where they stand)
		await capture("crowd-01-before" if pass_i==0 else "crowd-03-push-before")
		var shoves_before := _shoves_by(actor)
		var roots_before: Array=VillageSession.village.people_facts.keys()
		var Accept: GDScript=load("res://scripts/studio/village/acceptance.gd")
		Accept.measures.clear()
		var stumbled := {}
		var closest := {}
		var moved := {}
		start=here
		var t := 0.0
		var through := false
		while t<(4.0 if holding else 2.6): # (pushing through is slower than running round)
			if holding: # A held push keeps pressing on (a still finger would be a guard).
				drag(55,push_at,push_at+Vector2(0,-3))
				push_at+=Vector2(0,-3)
			await get_tree().process_frame
			t+=get_process_delta_time()
			for i in cast.size():
				var id: int=cast[i]
				if not res._movers[id]._stagger.is_empty():
					stumbled[id]=true
				var pp := Vector2(player.global_position.x,player.global_position.z)
				closest[id]=minf(float(closest.get(id,INF)),res._movers[id].pos.distance_to(pp))
				moved[id]=maxf(float(moved.get(id,0.0)),res._movers[id].pos.distance_to(spots[i]))
			if not through and t>=1.0:
				through=true
				await capture("crowd-02-through" if pass_i==0 else "crowd-04-push-through")
		var pp := Vector2(player.global_position.x,player.global_position.z)
		var stepped_in := -1 # someone in his way answering what he did (they protest, step in): the encounter, not a body fault
		for id: int in res._movers: # (who is up against him at the end: diagnosis when he is held up)
			var m=res._movers[id]
			if m.pos.distance_to(pp)<1.0 and str(VillageSession.village.people[id].mind.plan.get("offer","")) in ["intervene","protest"]:
				stepped_in=id
			if m.pos.distance_to(pp)<1.3:
				print("BODY CROWD near pass=",pass_i," id=",id," d=%.2f" % m.pos.distance_to(pp)," owner=",res.owners.owner(id)," can_move=",m.can_move()," exact=",m.exact," staggering=",not m._stagger.is_empty()," offer=",VillageSession.village.people[id].mind.plan.get("offer","")," cast=",cast.has(id))
		touch(54,stick_at+Vector2(0,-120),false)
		if holding:
			print("BODY CROWD push intent=",hud._hands.pointers[55].intent if hud._hands.pointers.has(55) else "gone")
			touch(55,push_at,false)
		var ran: float=Vector2(player.global_position.x,player.global_position.z).distance_to(start)
		var shoves: int=_shoves_by(actor)-shoves_before
		var people: int=_shove_targets(actor,roots_before).size() # (distinct people among this pass's shoves)
		var costs: Array=Accept.measures.map(func(r: Dictionary) -> float: return int(r.get("accept_us",0))/1000.0)
		costs.sort()
		var total := 0.0
		for c: float in costs:
			total+=c
		print("BODY CROWD cost pass=%d seq_ms=%s" % [pass_i,str(Accept.measures.map(func(r: Dictionary) -> float: return snappedf(int(r.get("accept_us",0))/1000.0,0.1)))])
		print("BODY CROWD cost pass=%d acceptances=%d median_ms=%.1f max_ms=%.1f total_ms=%.1f (in %.1f s)" % [pass_i,costs.size(),costs[costs.size()/2] if not costs.is_empty() else 0.0,costs[-1] if not costs.is_empty() else 0.0,total,4.0 if holding else 2.6])
		print("BODY CROWD pass=",pass_i," held_push=",holding," ran=",ran," stumbled=",stumbled.keys()," shoves=",shoves," closest=",closest," moved=",moved)
		var in_way := 0 # (those he came within 1 m of; the others were never in his way)
		var gave_way := 0
		var run_into := 0
		for id: int in cast:
			if float(closest.get(id,INF))>=1.0:
				continue
			in_way+=1
			if stumbled.has(id) or float(moved.get(id,0.0))>=0.3:
				gave_way+=1
			if float(closest.get(id,INF))<0.35:
				run_into+=1
		if holding:
			check((ran>5.3 or stepped_in>=0) and stumbled.size()>=2,"pushing through: %d of the 5 stumble aside, and he gets as far as the last of them stood (%.1f m, 5.3 m ahead)%s" % [stumbled.size(),ran,"" if ran>5.3 else (" - or one he shoved answers him and stops him (%d)" % stepped_in)])
		else:
			check((ran>5.0 or stepped_in>=0) and in_way>=2 and gave_way==in_way and run_into==0,"running through: all %d in his way give way, stepping aside or stumbling (%d stumble), nobody is run through, and he gets through (%.1f m)%s" % [in_way,stumbled.size(),ran,"" if ran>5.0 else (" - or one he barged answers him and stops him (%d)" % stepped_in)])
		if holding:
			check(shoves>=1 and shoves==people,"pushing through, the held push lands its checked shove at once, once a person, never repeated (%d shoves on %d people)" % [shoves,people])
		else:
			check(shoves==people,"running through, a barge is one checked shove a person, never repeated (%d shoves on %d people)" % [shoves,people])
		await active(5.5) # (the people settle before the next pass)
	if shot_path!="" and DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(shot_path)==OK,"final crowd image")
## The people this actor's checked shoves were on (roots in people_facts).
func _shove_targets(actor: String,except: Array=[]) -> Dictionary:
	var out := {}
	for key: String in VillageSession.village.people_facts:
		if except.has(key):
			continue
		var root=VillageSession.village.people_facts[key]
		if root is Dictionary and str(root.get("verb",""))=="shove" and str(root.get("actor",""))==actor:
			out[str(root.get("target",""))]=true
	return out
## Checked shoves this actor has had accepted so far (roots in people_facts).
## Standing still beside someone is no act (desk, 6 Oct: 3 blows landed on Tomas from bumping alone, with the player
## stood 1.2 m off as port_gift_check stands him). Walking contact is presentation only unless he himself moves into
## them. Two people: one held where they stand, one left to their own plan (placed only, as port_gift_check does), the
## player set down 1.2 m from each and left still for 6 s. Zero acts by him, no hits on their stance of him.
func still() -> void:
	var live := get_tree().current_scene.get_node("VillageLive")
	res=live.registry
	while not res.all_built():await get_tree().process_frame
	var v=VillageSession.village
	var actor := Contact.actor_of(player)
	var picked: Array[int] = []
	var ported := preload("res://scripts/studio/village/sim/ported.gd")
	var tomas: int=ported.person_of(v,"tomas")
	if tomas>=0 and res.bodies.has(tomas):
		picked.append(tomas)
	for p in v.people:
		if picked.size()>=2:break
		if not picked.has(p.id) and p.alive and p.present and not p.locked and res.bodies.has(p.id) and res.bodies[p.id].is_visible_in_tree() and Rules.age_of(v,p)>=18 and res._movers[p.id].can_move():
			picked.append(p.id)
	check(picked.size()==2,"two people to stand beside (%s)" % str(picked))
	for i in picked.size():
		var id: int=picked[i]
		var held := i==1
		var body: Node3D=res.bodies[id]
		if held:
			res.owners.claim(id,"body_fixture",2)
			var at := Vector2(body.global_position.x,body.global_position.z)
			res._movers[id].place(at,PI)
			res._movers[id].hold(at,at+Vector2(0,-1))
		else:
			res._movers[id].place(Vector2(body.global_position.x,body.global_position.z),PI)
		await frames(2)
		var facts_before: Array=v.people_facts.keys()
		var hits_before := int(v.people[id].mind.stances.get("player:local",{}).get("hits",0))
		player.global_position=body.global_position+Vector3(0,0.1,-1.2)
		player.velocity=Vector3.ZERO
		var closest := INF
		var t := 0.0
		while t<6.0:
			await active(0.25)
			t+=0.25
			closest=minf(closest,Vector2(player.global_position.x-body.global_position.x,player.global_position.z-body.global_position.z).length())
		var acts := []
		for key: String in v.people_facts:
			var root=v.people_facts[key]
			if not facts_before.has(key) and root is Dictionary and str(root.get("actor",""))==actor:
				acts.append(str(root.get("verb","")))
		var hits := int(v.people[id].mind.stances.get("player:local",{}).get("hits",0))-hits_before
		print("BODY STILL id=",id," held=",held," closest=%.2f" % closest," acts=",acts," hits=",hits," pairs=",hud._hands.driver.touch.pairs.size())
		check(acts.is_empty() and hits==0,"standing still 1.2 m from %s (%s, closest %.2f m) for 6 s is no act: %d acts %s, %d hits" % [str(View.describe(v,id).get("name",id)),"held" if held else "on their own plan",closest,acts.size(),str(acts),hits])
		player.global_position=body.global_position+Vector3(12,0.1,0)
		await active(1.0)
func _shoves_by(actor: String) -> int:
	var n := 0
	for key: String in VillageSession.village.people_facts:
		var root=VillageSession.village.people_facts[key]
		if root is Dictionary and str(root.get("verb",""))=="shove" and str(root.get("actor",""))==actor:
			n+=1
	return n
## B7 on the board: no bubble fully up sits on space already in use (the HUD's panels, the controls and their words,
## the name tag), read the way speech.gd reads it, in this frame's view.
func bubbles_clear(where: String) -> void:
	var speech: Node=Contact.registry(get_tree()).speech
	var view := get_viewport().get_camera_3d()
	var taken: Array=speech._occupied(view,0.0) # (the same rule, so a faint tag counts here as it does there)
	var bad := []
	for l in speech._shown:
		if not is_instance_valid(l.label) or l.label.modulate.a<0.99:
			continue
		var r: Rect2=speech._rect(view,l)
		for t: Rect2 in taken:
			if r.size!=Vector2.ZERO and r.grow(2.0).intersects(t):
				bad.append("'%s' on %s" % [l.text,str(t)])
				break
	check(bad.is_empty(),"%s: no bubble sits on the HUD, the controls or a name tag (%d bubbles, %d spaces in use) %s" % [where,speech._shown.size(),taken.size(),str(bad)])
## Whether the ground is standable every 0.5 m out to `reach` in eight directions from `p`.
func _open_round(p: Vector2,reach: float) -> bool:
	for k in 8:
		var d := Vector2.from_angle(TAU*k/8.0)
		var r := 0.5
		while r<=reach:
			if not res._standable(p+d*r):
				return false
			r+=0.5
	return true
## How far a resident's body (not its mover) moves over `seconds`, at most, from where it was; `until_up`: stop early
## once they can move again.
func body_drift(id: int,seconds: float,until_up := false) -> float:
	var body: Node3D=res.bodies[id]
	var from := body.global_position
	var most := 0.0
	var t := 0.0
	while t<seconds:
		await get_tree().process_frame
		t+=get_process_delta_time()
		if until_up and (res._movers[id].can_move() or not VillageSession.village.people[id].body_facts.has("down")):
			break
		most=maxf(most,Vector2(body.global_position.x-from.x,body.global_position.z-from.z).length())
	return most
## The path a resident's hand travels relative to its body over `seconds` (arms swatting read as a long path).
func hand_travel(id: int,seconds: float) -> float:
	var body: Node3D=res.bodies[id]
	var hand: Node3D=body.hand_attachment()
	if hand==null:
		return 0.0
	var last := hand.global_position-body.global_position
	var path := 0.0
	var t := 0.0
	while t<seconds:
		await get_tree().process_frame
		t+=get_process_delta_time()
		var now := hand.global_position-body.global_position
		path+=now.distance_to(last)
		last=now
	return path
## C1: where the talk proof stands (talk part 3): the first centre round the square where the person's spot and his,
## 1.4 m short of it, are standable, none of Enea's villagers is within 2.5 m, no one else within 4 m, nothing of his
## (a station, a sign, a board) is in reach of his spot, and they see each other.
func _talk_centre(me: int) -> Vector2:
	var npcs := get_tree().current_scene.find_children("*","Node3D",true,false).filter(func(n: Node) -> bool: return n.get_script()==preload("res://scripts/world/npc.gd"))
	var space: PhysicsDirectSpaceState3D=(get_tree().current_scene as Node3D).get_world_3d().direct_space_state
	var shape := WorldShape.new()
	for radius: float in [6.0,10.0,14.0,18.0,22.0,26.0]:
		for k in 24:
			var c := Vector2(0,20)+Vector2.from_angle(TAU*k/24.0)*radius
			var stand := c+Vector2(0,-1.4)
			var ok: bool=res._world.standable.call(c) and res._world.standable.call(stand)
			for n: Node3D in npcs:
				var at := Vector2(n.global_position.x,n.global_position.z)
				ok=ok and at.distance_to(c)>=2.5 and at.distance_to(stand)>=2.5
			for id: int in res._movers:
				ok=ok and (id==me or res._movers[id].pos.distance_to(c)>=4.0)
			for n in get_tree().get_nodes_in_group("interactable"):
				if ok and n is Node3D and not (n.get("resident")!=null and int(n.get("resident"))==me):
					var at := Vector2((n as Node3D).global_position.x,(n as Node3D).global_position.z)
					var reach: float=float(n.get("reach")) if n.get("reach")!=null else 2.0
					ok=at.distance_to(stand)>reach+0.6
			if ok:
				var q := PhysicsRayQueryParameters3D.create(Vector3(stand.x,shape.height_at(stand.x,stand.y)+1.5,stand.y),Vector3(c.x,shape.height_at(c.x,c.y)+1.5,c.y))
				ok=space.intersect_ray(q).is_empty()
			if ok:
				print("BODY TALK centre=",c)
				return c
	return Vector2.INF
## C1 (desk, 6 Oct): a person and his bounty board both in reach. The tap takes the one he faces: facing the person it
## talks, facing the board it opens the board (TapRule's facing cone), and a real tap on his Attack does that.
func beside_board(id: int) -> void:
	var board: Node3D=null
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is Node3D and str(n.get("verb"))=="Bounties":
			board=n
	check(board!=null and id>=0,"his bounty board and someone to stand beside it")
	if board==null or id<0:
		return
	res.owners.claim(id,"body_fixture",2)
	var b := Vector2(board.global_position.x,board.global_position.z)
	var stand := Vector2.INF
	var other := Vector2.INF
	for k in 16: # him 1.1 m from the board, the person 1.2 m beside him, across the line to the board
		var d := Vector2.from_angle(TAU*k/16.0)
		var s2: Vector2=b+d*1.1
		var o: Vector2=s2+d.orthogonal()*1.2
		if res._world.standable.call(s2) and res._world.standable.call(o):
			stand=s2
			other=o
			break
	check(stand!=Vector2.INF,"standable ground beside his board for him and the person")
	if stand==Vector2.INF:
		return
	res._movers[id].place(other,PI)
	res._movers[id].hold(other,stand)
	position_player(Vector3(stand.x,WorldShape.new().height_at(stand.x,stand.y)+0.05,stand.y))
	await frames(4)
	var face := func(at: Vector2) -> void: player.visual.rotation.y=atan2(at.x-stand.x,at.y-stand.y)
	face.call(Vector2(res.bodies[id].global_position.x,res.bodies[id].global_position.z))
	await frames(2)
	var to_person: Dictionary=hud._hands.driver.tap_context()
	face.call(b)
	await frames(2)
	var to_board: Dictionary=hud._hands.driver.tap_context()
	var at: Vector2=hud._hands.surfaces().act
	touch(56,at,true)
	await frames(2)
	touch(56,at,false)
	await frames(6)
	var opened: Control=null
	for n in hud.get_children():
		if n is Control and n.get_script()!=null and str((n.get_script() as Script).resource_path).ends_with("ui/bounty_panel.gd"):
			opened=n
	print("BODY TALK board person=",to_person.get("slot",""),"/",to_person.context.get("verb","")," board=",to_board.get("slot",""),"/",to_board.context.get("verb","")," gap=",stand.distance_to(other))
	check(str(to_person.context.get("verb",""))=="Talk" and str(to_board.context.get("verb",""))=="Bounties" and opened!=null,
		"with someone and his bounty board both in reach the tap takes the one he faces: Talk facing them, Bounties facing the board, and his Attack opens it (%s / %s)" % [str(to_person.context.get("verb","")),str(to_board.context.get("verb",""))])
	if opened!=null:
		opened.closed.emit()
		opened.queue_free()
		await frames(6)
## A standable point at least `clear` metres from every other resident and the player, on rings round the square.
func _clear_spot(me: int,clear: float,radii: Array=[50.0,60.0,70.0,85.0],lane := 0.0) -> Vector2:
	for radius: float in radii:
		for k in 24:
			var p := Vector2(0,20)+Vector2.from_angle(TAU*k/24.0)*radius
			if not res._standable(p) or (lane>0.0 and not _open_round(p,lane)):
				continue
			var ok := Vector2(player.global_position.x,player.global_position.z).distance_to(p)>=clear
			for id: int in res._movers:
				if id!=me and res._movers[id].pos.distance_to(p)<clear:
					ok=false
					break
			if ok:
				return p
	return Vector2.INF
## Slice 5: the newest buzz Hands asked for after a landed act of this verb.
func felt(verb: String) -> Dictionary:
	for i in range(hud._hands.feel.felt.size()-1,-1,-1):
		if hud._hands.feel.felt[i].verb==verb:
			return hud._hands.feel.felt[i]
	return {}
func deed(intent: Dictionary,verb: String,target: int) -> String:
	var key := JSON.stringify([Contact.actor_of(player),str(intent.get("press_id","")),verb])
	return "deed:"+JSON.stringify([key,People.key(VillageSession.village,target)]).sha256_text().substr(0,32)
func receipt(intent: Dictionary,verb: String,target: int) -> Dictionary:
	if intent.is_empty():return {}
	return VillageSession.village.people_facts.get(deed(intent,verb,target),{}).get("receipt",{})
func landed(intent: Dictionary,verb: String,target: int) -> Dictionary:
	var started := People.tick(VillageSession.village)
	var wall := Time.get_ticks_msec()
	while receipt(intent,verb,target).is_empty() and People.tick(VillageSession.village)-started<3000 and Time.get_ticks_msec()-wall<20000:
		await get_tree().process_frame
	var result := receipt(intent,verb,target)
	print("BODY RECEIPT verb=",verb," captured=",intent.get("target",-2)," deed=",deed(intent,verb,target)," result=",result," actual=",res.bodies[target].global_position," mover=",res._movers[target].pos," facts=",VillageSession.village.people[target].body_facts," busy=",player.fighter._busy," impact=",player.fighter._impact," locked=",Controls.locked," paused=",SaveGame.paused," background=",VillageSession.background," scale=",Engine.time_scale)
	return result
func approach(target: int,distance: float) -> void:
	var started := People.tick(VillageSession.village)
	while player.fighter.is_busy() and People.tick(VillageSession.village)-started<4000:
		await get_tree().process_frame
	position_player(res.bodies[target].global_position+Vector3(0,0,-distance))
	await frames(2) # Body adapters and P4 consume actual placement before target preparation.
func capture(label: String) -> void:
	print("BODY FRAME ",label," tick=",People.tick(VillageSession.village)," player=",player.global_position)
	for id in cast:
		var p=VillageSession.village.people[id]
		print("BODY ACTOR ",id," at=",res.bodies[id].global_position," mover=",res._movers[id].pos," owner=",res.owners.owner(id)," hurt=",p.hurt," facts=",p.body_facts.keys()," offer=",p.mind.plan.get("offer",""))
	var reg: Node=Contact.registry(get_tree())
	if reg!=null and reg.get("speech")!=null:
		for l in reg.speech._shown:
			print("BODY SPEECH UP '",l.text,"' age=%.2f/%.2f prio=%d rise=%.2f rect=%s at=%s" % [l.age,l.seconds,l.priority,l.rise,str(reg.speech._rect(get_viewport().get_camera_3d(),l)),str(l.body.global_position)])
	if shot_path=="" or DisplayServer.get_name()=="headless":return
	if caption!=null:caption.text=label
	if camera!=null:
		frame()
		await frames(2) # Speech lays its bubbles out for the camera each frame: after the board's camera jumps, let it.
	await RenderingServer.frame_post_draw
	if mode=="talk":
		bubbles_clear(label)
	var path := shot_path.get_base_dir().path_join(label.validate_filename()+".png")
	check(get_viewport().get_texture().get_image().save_png(path)==OK,"capture "+label)
## Board framing (Body 2, 5 Oct): a side view across the player and the subject, so neither stands in front of
## the other, from the first angle whose line of sight no collider (a wall, a stall) blocks. Touch aim reads
## Controls.cam_yaw, never this camera, so framing changes no act.
func frame() -> void:
	var a: Vector3=player.global_position
	var b: Vector3=res.bodies[subject].global_position if subject>=0 else (_frame_on.global_position if is_instance_valid(_frame_on) else a)
	var centre: Vector3=(a+b)*0.5+Vector3(0,0.9,0)
	var axis := Vector3(b.x-a.x,0,b.z-a.z)
	axis=axis.normalized() if axis.length()>0.2 else Vector3(0,0,1)
	var space := get_viewport().get_world_3d().direct_space_state
	var chosen := Vector3.INF
	for side: float in [1.0,-1.0]:
		for turn: float in [0.0,25.0,-25.0,50.0,-50.0]:
			var from: Vector3=centre+axis.rotated(Vector3.UP,deg_to_rad(90*side+turn))*5.2+Vector3(0,1.6,0)
			var ray := PhysicsRayQueryParameters3D.create(centre,from)
			ray.exclude=[player.get_rid()]
			if space.intersect_ray(ray).is_empty() and not blocked_by_person(from,centre):
				chosen=from
				break
		if chosen!=Vector3.INF:break
	if chosen==Vector3.INF:chosen=centre+axis.rotated(Vector3.UP,PI*0.5)*5.2+Vector3(0,1.6,0)
	camera.global_position=chosen
	camera.look_at(centre)
	print("BODY CAMERA subject=",subject," at=",chosen," look=",centre)
## Bodies have no colliders the ray could hit, so a bystander nearer than 0.7 m to the sight line, or 1.8 m to
## the camera, blocks the angle.
func blocked_by_person(from: Vector3,to: Vector3) -> bool:
	for id in res.bodies:
		var body: Node3D=res.bodies[id]
		if id==subject or not body.is_visible_in_tree():
			continue
		var at: Vector3=body.global_position+Vector3(0,0.9,0)
		if Vector2(at.x-from.x,at.z-from.z).length()<1.8:
			return true # Someone beside the camera fills the foreground.
		var along := clampf((at-from).dot(to-from)/(to-from).length_squared(),0,1)
		if along<0.92 and at.distance_to(from.lerp(to,along))<0.7:
			return true
	return false
func sequence() -> void:
	var live := get_tree().current_scene.get_node("VillageLive")
	res=live.registry
	while not res.all_built():await get_tree().process_frame
	if mode=="actor":player.set_meta("people_actor","body-proof:controller") # Durable actor opt-in, no recognition/name supplied.
	var v=VillageSession.village
	v.runtime.events.clear() # Fresh proof cast; no authored stage borrows these fixture bodies.
	for p in v.people:
		if p.alive and p.present and p.authored=="" and Rules.age_of(v,p)>=18 and not p.locked:
			cast.append(p.id)
			if cast.size()==5:break
	if cast.size()!=5:
		check(false,"physical cast missing")
		return
	var centre := Vector2(0,20)
	var positions := [centre,centre+Vector2(3,1),centre+Vector2(-4,2),centre+Vector2(6,4),centre+Vector2(-24,0)]
	for i in cast.size():
		var id := cast[i]
		v.people[id].plan=PackedInt32Array([0,1440,v.pl_well])
		res._leave_situation(id)
		res._drop_stay(id)
		res.owners.claim(id,"body_fixture",2)
		res.destinations.erase(id)
		res._movers[id].indoors=false
		res._movers[id].active=true
		res._movers[id].place(positions[i],PI)
		res._movers[id].hold(positions[i],centre)
		res.bodies[id].show()
	v.people[cast[1]].traits[Rules.C.BOLD]=85
	v.people[cast[2]].traits[Rules.C.BOLD]=15
	v.people[cast[3]].mind.modifiers.append({"id":"distracted","delay_ms":2400})
	preload("res://scripts/studio/village/sim/image.gd").drifted(cast[3]) # a fixture write outside acceptance: the next batch takes it in (as encounter_probe)
	var victim := cast[0]
	await frames(4) # mover.place is consumed by Crowd; reading the body earlier gives its old world position.
	check(res._movers[victim].pos.distance_to(centre)<0.6 and Vector2(res.bodies[victim].global_position.x,res.bodies[victim].global_position.z).distance_to(centre)<0.6 and res.owners.held(victim,"body_fixture"),"generic claimed owner retains arranged actual body through day update")
	position_player(res.bodies[victim].global_position+Vector3(0,0,-1.7))
	player.health_changed.connect(func(health: int,_most: int) -> void: print("BODY PLAYER HURT health=",health," tick=",People.tick(VillageSession.village)," from=",get_stack().slice(1,4)))
	camera=Camera3D.new()
	add_child(camera)
	camera.fov=50
	subject=victim
	frame()
	camera.make_current()
	var overlay := CanvasLayer.new()
	add_child(overlay)
	caption=Label.new()
	caption.position=Vector2(get_viewport().get_visible_rect().size.x*0.36,14) # Top centre: clear of hearts, quest card and minimap.
	caption.add_theme_font_size_override("font_size",26)
	overlay.add_child(caption)
	await active(0.3)
	await capture("01-before")
	subject=-1
	var wolf := Carcass.spawn(get_tree().current_scene,"wolf",player.global_position,0,player)
	player.hauling.start_carry(wolf)
	var walk_at := Vector2(200,get_viewport().get_visible_rect().size.y-180)
	touch(53,walk_at,true)
	drag(53,walk_at,walk_at+Vector2(0,70))
	await active(1.0)
	touch(53,walk_at+Vector2(0,70),false)
	await capture("01b-load-brush")
	subject=victim
	check(player.hauling.carrying==wolf and hud._hands.driver.touch.pairs.values().any(func(pair: Dictionary) -> bool: return str(pair.how)=="load"),"carried native wolf measures load contact through P4")
	# Combined motions: carrying, the tap sets the load down, the hint offers no strike, and a flick strikes nobody.
	var carry_tap: Dictionary=hud._hands.driver.tap_context()
	check(str(carry_tap.tap)=="grip" and str(carry_tap.context.get("verb",""))=="Lower" and (hud._hands.scheme!="act" or not "flick strike" in hud._hands._hint_words),"carrying: the tap is Lower and the hint offers no strike (%s)" % hud._hands._hint_words)
	var hurt_before: int=VillageSession.village.people[victim].hurt
	var hurt_deed := str(VillageSession.village.people[victim].body_facts.get("hurt",{}).get("deed",""))
	await stroke("hand",false,victim)
	await active(0.4)
	check(player.hauling.carrying==wolf and VillageSession.village.people[victim].hurt==hurt_before and str(VillageSession.village.people[victim].body_facts.get("hurt",{}).get("deed",""))==hurt_deed,"carrying: a flick at someone 1.7 m away strikes nobody, and the load stays")
	await stroke("grip")
	await active(0.1)
	await approach(victim,1.4)
	var palm := await stroke("shove",false,victim)
	var palm_result := await landed(palm,"shove",victim)
	await frames(2)
	await capture("02-impact")
	check(not felt("shove").is_empty(),"the accepted shove is felt: %s" % str(felt("shove")))
	check(palm.get("verb","")=="shove" and int(palm.get("target",-2))==victim and palm_result.get("accepted",false) and str(VillageSession.village.people[victim].body_facts.get("hurt",{}).get("deed",""))==deed(palm,"shove",victim),"deliberate Palm has its own accepted cause and Claude impact")
	await active(1)
	await approach(victim,1.4)
	var voiced := []
	res.bodies[victim].vocalized.connect(func(kind: String,k: float) -> void: voiced.append([kind,k]))
	var light_from: Vector2=res._movers[victim].pos
	var light := await stroke("hand",false,victim)
	var light_result := await landed(light,"strike",victim)
	await frames(2)
	await capture("02b-light") # Slice 2: a lazy flick's light blow, for the board beside 03-down's sharp one.
	var light_force := int(light_result.get("force",0))
	var light_ok: bool=light_force==450 if hud._hands.scheme=="discs" else light_force>=300 and light_force<750
	check(light.get("verb","")=="strike" and int(light.get("target",-2))==victim and light_result.get("accepted",false) and light_ok,"ordinary Hand strike keeps captured target through native impact (force %d)" % light_force)
	await active(0.8)
	var light_voice: Array=voiced.filter(func(v: Array) -> bool: return v[0]=="grunt")
	var staggered: float=res._movers[victim].pos.distance_to(light_from)
	check(not light_voice.is_empty() and absf(float(light_voice[-1][1])-light_force/1000.0)<0.01 and staggered>0.1 and not VillageSession.village.people[victim].body_facts.has("down"),"the light blow shows on the body at its force: a grunt at %.2f, a stagger of %.2f m, still standing" % [float(light_voice[-1][1]) if not light_voice.is_empty() else -1.0,staggered])
	voiced.clear()
	await approach(victim,1.4)
	var heavy := await stroke("hand",true,victim)
	var heavy_result := await landed(heavy,"strike",victim)
	await frames(2)
	var heavy_force := int(heavy_result.get("force",0))
	check(heavy.get("verb","")=="heavy" and int(heavy.get("target",-2))==victim and heavy_result.get("accepted",false) and (heavy_force==850 if hud._hands.scheme=="discs" else heavy_force>=750) and str(VillageSession.village.people[victim].body_facts.get("down",{}).get("deed",""))==deed(heavy,"strike",victim),"prepared Heavy reaches native commitment and same-cause down (force %d)" % heavy_force)
	await capture("03-down")
	var hard_voice: Array=voiced.filter(func(v: Array) -> bool: return v[0]=="grunt")
	check(not hard_voice.is_empty() and float(hard_voice[-1][1])>=0.99 and VillageSession.village.people[victim].body_facts.has("down"),"the heavy blow shows harder: a grunt at %.2f (light %.2f), and it fells" % [float(hard_voice[-1][1]) if not hard_voice.is_empty() else -1.0,light_force/1000.0])
	var hard := felt("strike")
	check(int(hard.get("force",0))==heavy_force and int(hard.get("ms",0))>=int(Feel.buzz(light_force).x),"the heavy blow buzzes at its force (%s), no shorter than the light one" % str(hard))
	if mode=="actor":
		var root: Dictionary=VillageSession.village.people_facts.get(deed(heavy,"strike",victim),{})
		check(str(root.get("actor",""))=="body-proof:controller" and str(root.get("target",""))==People.key(VillageSession.village,victim),"native contacts retain general controller ref without claiming recognition")
		return
	var down_at: Vector2=res._movers[victim].pos
	var lying_drift: float=await body_drift(victim,1.2)
	check(VillageSession.village.people[victim].body_facts.has("down") and not res._movers[victim].can_move() and res._movers[victim].pos.distance_to(down_at)<0.05,"down stays planted under integration and separation")
	check(lying_drift<0.05 and str(res.bodies[victim].posture()) in ["down","dead"],"lying, the body itself never slides (drift %.3f m, posture %s)" % [lying_drift,res.bodies[victim].posture()])
	await capture("04-lying")
	await approach(victim,0.9)
	var lift := await stroke("grip")
	var lifted := await landed(lift,"carry",victim)
	await frames(2)
	check(lifted.get("accepted",false) and player.has_meta("studio_people_load") and player.hauling.carrying==null and str(VillageSession.village.people[victim].body_facts.get("carried",{}).get("carrier",""))==Contact.actor_of(player),"Grip lifts accepted human through its own carry fact")
	await capture("04b-carried-person")
	var lower := await stroke("grip")
	var lowered := await landed(lower,"set_down",victim)
	await frames(2)
	check(lifted.get("accepted",false) and lowered.get("accepted",false) and not VillageSession.village.people[victim].body_facts.has("carried") and not player.has_meta("studio_people_load"),"Grip lowers previously accepted human at actual position")
	var set_down_drift: float=await body_drift(victim,6.0,true)
	check(set_down_drift<0.05,"set down, the body lies where it was put until it rises (drift %.3f m)" % set_down_drift)
	var recovery_limit := People.tick(VillageSession.village)+8000
	while not res._movers[victim].can_move() and People.tick(VillageSession.village)<recovery_limit:
		await get_tree().process_frame # Accepted down has ended; Claude owns the actual pain-slowed get-up duration.
	await capture("05-recovery")
	check(heavy_result.get("accepted",false) and not VillageSession.village.people[victim].body_facts.has("down") and res._movers[victim].can_move(),"fact removal releases actual locomotion")
	check(not str(res.bodies[victim].posture()) in ["down","dead"],"they get up before they walk: posture '%s' once they can move" % res.bodies[victim].posture())
	if mode=="contact":return
	# Fire uses a different, unstruck person: the first victim may already have terminal injury.
	var rescued := cast[1]
	subject=rescued
	position_player(res.bodies[rescued].global_position+Vector3(0,0,-1.5))
	var cries := []
	res.bodies[rescued].vocalized.connect(func(kind: String,k: float) -> void: cries.append([kind,k]))
	var calm_hand: float=await hand_travel(rescued,0.6)
	player.abilities._cinderburst({"press_id":"body-sequence:burst"})
	await active(0.5)
	await capture("06-fire")
	check(VillageSession.village.people[rescued].body_facts.has("burning"),"native Burst reaches moving body through checked heat and force")
	var flail_hand: float=await hand_travel(rescued,0.6)
	check(cries.any(func(v: Array) -> bool: return v[0]=="scream") and flail_hand>2.0*calm_hand and flail_hand>0.3,"on fire they scream (PLACEHOLDER: voice blips; %s) and the arms flail (hand travels %.2f m in 0.6 s, calm %.2f m)" % [str(cries.map(func(v: Array) -> String: return v[0])),flail_hand,calm_hand])
	var run_from: Vector2=res._movers[rescued].pos
	await active(1.0)
	await capture("06b-fire-running")
	var plan_offer := str(VillageSession.village.people[rescued].mind.plan.get("offer",""))
	print("BODY FIRE rescued=",rescued," offer=",plan_offer," ran=",res._movers[rescued].pos.distance_to(run_from)," burning=",VillageSession.village.people[rescued].body_facts.has("burning"))
	check(plan_offer=="escape_fire" and res._movers[rescued].pos.distance_to(run_from)>1.0,"the burning one runs for water (offer %s, %.1f m in 1 s)" % [plan_offer,res._movers[rescued].pos.distance_to(run_from)])
	position_player(res.bodies[rescued].global_position+Vector3(0,0,-0.8))
	await frames(2)
	var fire_tap: Dictionary=hud._hands.driver.tap_context()
	check(str(fire_tap.slot)=="extinguish" and str(fire_tap.context.get("verb",""))=="Put out","beside the burning one the tap is Put out, before any pick-up, talk or station (%s)" % str(fire_tap.slot))
	var at: Vector2=hud._hands.surfaces().get("act",hud._hands.centres().hand) # C1: his Attack button
	print("BODY FIRE before tap pointers=",hud._hands.pointers.keys()," attack_held=",hud._action._held," visible=",hud._action.is_visible_in_tree()," locked=",Controls.locked," at=",at," centre=",hud._action.center())
	touch(52,at,true)
	# The rule: the tap puts out the burning person it targets (the nearest, captured at the press). Who that is can be
	# someone other than `rescued`: they run on for water, and a burning bystander may be nearer by then.
	var pressed=hud._hands.pointers.get(52)
	var put_out := int(pressed.target.get("context",{}).get("id",-1)) if pressed!=null else -1
	var was_burning: bool=put_out>=0 and VillageSession.village.people[put_out].body_facts.has("burning")
	touch(52,at,false)
	await active(0.3)
	var doused_by_tap := false
	for key: String in VillageSession.village.people_facts:
		var root=VillageSession.village.people_facts[key]
		if root is Dictionary and str(root.get("verb",""))=="extinguish" and str(root.get("actor",""))==Contact.actor_of(player) and str(root.get("target",""))==People.key(VillageSession.village,put_out):
			doused_by_tap=true
	print("BODY FIRE TAP target=",put_out," rescued=",rescued," was_burning=",was_burning," burning_after=",VillageSession.village.people[put_out].body_facts.has("burning") if put_out>=0 else "-"," by_tap=",doused_by_tap)
	check(put_out>=0 and was_burning and not VillageSession.village.people[put_out].body_facts.has("burning") and doused_by_tap,"contextual tap physically beats out actual fire on the burning person it targets (%d; the one set alight was %d)" % [put_out,rescued])
	await capture("07-extinguished")
	var held := cast[4]
	# The death rule is proved alone: nobody may sense the flames (burning carries 26 m, a scream 40 m) and choose to
	# beat them out. On step 4's live phases a neighbour's help_fire reached a held one 24 m out and saved them (a
	# real rescue, covered by the water check and the fire log), so the held one stands 45 m clear of everyone.
	var lonely := _clear_spot(held,45.0)
	check(lonely!=Vector2.INF,"a standable spot 45 m clear of every other resident for the restrained-fire death (%s)" % str(lonely))
	if lonely!=Vector2.INF:
		res._movers[held].place(lonely,PI)
		res._movers[held].hold(lonely,lonely+Vector2(0,-1))
		await frames(4)
	subject=held
	var held_body: Node3D=res.bodies[held]
	var held_at := held_body.global_position
	held_body.hold_hands(held_body.to_global(Vector3(0.16,1.32,0.42)),held_body.to_global(Vector3(-0.16,1.32,0.42)))
	position_player(held_at+Vector3(0,0,-0.8))
	var burnt := Contact.perform(get_tree(),Contact.actor_of(player),player,"burn",{"press_id":"body-sequence:restrained-flame","heat":1000,"duration_ms":20000,"force":900},player.global_position,1.2,Vector3.ZERO,held)
	await active(0.7)
	check(burnt.get("accepted",false) and res._movers[held].pos.distance_to(Vector2(held_at.x,held_at.z))<0.05 and not res._movers[held].can_posture("down"),"measured restrained fire flails within planted wrist constraints")
	await capture("08-restrained-fire")
	# The wait happens back in the square: at the meadow edge a wild boar knocked the player out (s3-r1 09, Body 2).
	position_player(res.bodies[victim].global_position+Vector3(0,0,-3))
	var helpers := {}
	for i in 20:
		await active(0.5)
		for p in VillageSession.village.people:
			if p.id!=held and str(p.mind.plan.get("offer","")) in ["help_fire"] and str(p.mind.known.get(str(p.mind.plan.get("account","")),{}).get("target",""))==People.key(VillageSession.village,held):
				helpers[p.id]=true
	check(helpers.is_empty(),"nobody chose to help the restrained one: the death below is the rule's alone (helpers %s)" % str(helpers.keys()))
	check(not VillageSession.village.people[held].alive and VillageSession.village.people[held].body_facts.has("dead"),"continued accepted heat reaches rule-owned terminal death")
	for key: String in VillageSession.village.people_facts:
		var root: Dictionary=VillageSession.village.people_facts[key]
		if str(root.get("verb",""))=="extinguish":
			print("BODY EXTINGUISH ",key," actor=",root.get("actor","")," target=",root.get("target","")," at=",root.get("tick",root.get("since_tick","")))
	print("BODY HELD facts=",VillageSession.village.people[held].body_facts.keys()," hurt=",VillageSession.village.people[held].hurt," key=",People.key(VillageSession.village,held))
	print("BODY TERMINAL tick=",People.tick(VillageSession.village)," locked=",Controls.locked," background=",VillageSession.background," paused=",SaveGame.paused," scale=",Engine.time_scale," playerdown=",player._down)
	held_body.release_hands() # Actual restraint prevented reaching water; release the accepted corpse, never script its death.
	position_player(held_at+Vector3(0,0,-2.5))
	await active(1)
	await capture("09-terminal-death")
	if shot_path!="" and DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(shot_path)==OK,"final physical sequence image")
## B3 slice 3: the left stick owns the feet, through Enea's joystick and its marked lines, in the normal camera.
## A tap crouches and a second stands; a quick flick dodges its way; a quick reversal while walking only turns;
## the rim dwell still sprints. With --controls=discs the Feet disc stays and a stick flick dodges nothing.
func feet() -> void:
	var view := get_viewport().get_visible_rect().size
	var overlay := CanvasLayer.new()
	add_child(overlay)
	caption=Label.new()
	caption.position=Vector2(view.x*0.36,14)
	caption.add_theme_font_size_override("font_size",26)
	overlay.add_child(caption)
	var at := Vector3(0,0,24)
	at.y=WorldShape.new().height_at(at.x,at.z)
	position_player(at)
	await active(0.6)
	var base := Vector2(220,view.y-190)
	var u: float=hud._hands.unit() # Stick strokes are thumb motions in unit px, as the classifier reads them.
	var flick: Array=[Vector2(32,0)*u,Vector2(32,0)*u,Vector2(32,0)*u] # (960 px/s at 30 fps: over Enea's retuned flick line, 800)
	await capture("feet-01-idle")
	if hud._hands.scheme=="discs":
		check(hud._hands.surfaces().has("feet"),"discs keep the Feet disc")
		await stick_path(82,base,flick)
		await frames(6)
		check(not player.is_rolling(),"with the discs a stick flick dodges nothing")
		return
	check(not hud._hands.surfaces().has("feet"),"the thumb area has no Feet disc: the stick owns the feet")
	await stick_path(81,base,[])
	await frames(3)
	check(player.sneaking,"a still tap on the stick's base crouches")
	await active(0.6)
	await capture("feet-02-crouch")
	await stick_path(81,base,[])
	await frames(3)
	check(not player.sneaking,"a second tap stands")
	await active(0.4)
	var stamina_before: float=player.stamina.value
	await stick_path(82,base,flick)
	var stick=hud._joystick._studio_feet
	print("BODY FEET flick asks=",Controls.stick_act," age=",stick.age," speed=",stick.speed," travel=",stick.travel," stamina=",player.stamina.value," roll_rest=",player._roll_rest)
	var waited := 0
	while not player.is_rolling() and waited<10:
		await frames(1)
		waited+=1
	var expected: Vector3=hud._hands.driver.direction(Vector2(1,0),Controls.cam_yaw)
	check(player.is_rolling() and player._roll_dir.dot(expected)>0.9 and player.stamina.value==stamina_before,"a quick stick flick right dodges right, camera-relative, spending nothing (C1 unit 4: stamina retired) (dir %s)" % str(player._roll_dir))
	await frames(4)
	await capture("feet-03-dodge")
	await active(1.2)
	position_player(at) # Back to open ground: the dodge may have ended against a fence.
	await frames(2)
	touch(83,base,true)
	var knob := base
	for i in 6:
		drag(83,knob,knob+Vector2(12,0)*u)
		knob+=Vector2(12,0)*u
		await frames(1)
	await active(0.4) # Under the rim dwell, and short of the fence 6 m east.
	var heading: Vector3=player.velocity
	print("BODY FEET walk joystick=",Controls.joystick," finger=",hud._joystick._finger," at=",player.global_position," rolling=",player.is_rolling()," sneaking=",player.sneaking," busy=",player.fighter.is_busy())
	await capture("feet-04-walk-right")
	var rolled := false
	for i in 4:
		drag(83,knob,knob+Vector2(-36,0)*u)
		knob+=Vector2(-36,0)*u
		await frames(1)
		rolled=rolled or player.is_rolling()
	var turn_start := People.tick(VillageSession.village)
	while People.tick(VillageSession.village)-turn_start<600:
		rolled=rolled or player.is_rolling()
		await frames(1)
	print("BODY FEET turn before=",heading," after=",player.velocity," rolled=",rolled)
	check(not rolled and heading.length()>0.5 and player.velocity.dot(heading)<0,"SHARP TURN: a quick reversal while walking turns, never dodges")
	await capture("feet-05-sharp-turn")
	await active(0.8)
	check(Controls.stick_sprint,"the rim dwell still sprints")
	touch(83,knob,false)
	await frames(3)
	check(not player.is_rolling() and not player.sneaking,"lifting after a long walk asks for nothing")
	if shot_path!="" and DisplayServer.get_name()!="headless": # look.sh's own frame (s3-r1 lacked it).
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(shot_path)==OK,"final feet image")
## One stick finger: lands at base, moves by each step a frame, lifts.
func stick_path(finger: int,base: Vector2,steps: Array) -> void:
	touch(finger,base,true)
	await frames(1)
	var knob := base
	for step: Vector2 in steps:
		drag(finger,knob,knob+step)
		knob+=step
		await frames(1)
	touch(finger,knob,false)
## Slice 4 geometry: the thumb area and every arc (with its cooldown edge) inside the screen, the arcs in order
## with gaps, a fresh touch on each arc's middle picks that power, and the hint's widest common pill above them all.
## C1: the arcs ring his Attack button; none of them may cover one of his buttons.
func arcs_clear(hands: Control,u: float,view: Vector2) -> bool:
	var area: Vector2=hands.arc_centre()
	var outer: float=hands.arc_outer()+5.5*u
	var ok := true
	var arc: Dictionary=hands.arcs()
	for id: String in hands.buttons:
		var b: Control=hands.buttons[id]
		if b.is_visible_in_tree() and id!="attack":
			for k in 16:
				var edge: Vector2=b.center()+Vector2.from_angle(TAU*k/16.0)*b.radius
				if hands.role_at(edge)!="":
					print("BODY LABELS arc over his ",id," at ",edge)
					ok=false
					break
	var last := -INF
	for role: String in arc:
		for angle: float in [arc[role].x,arc[role].y]:
			var edge: Vector2=area+Vector2.from_angle(angle)*outer
			ok=ok and edge.x>=0 and edge.x<=view.x and edge.y>=0
		ok=ok and arc[role].x>last and hands.role_at(hands.surfaces()[role])==role
		last=arc[role].y
	var top: float=area.y-outer
	var bottom := -INF
	var left := INF
	var right := -INF
	for words: String in ["Shove Someone Longname 2.2 / 2.2 m","Put out / flick strike / push shove"]:
		var rect: Rect2=hands._pill_rect(hands.hint_at(),words,19)
		bottom=maxf(bottom,rect.end.y)
		left=minf(left,rect.position.x)
		right=maxf(right,rect.end.x)
	print("BODY LABELS arcs view=",view," unit=",u," arc_top=",top," hint_bottom=",bottom," hint_x=",left,"..",right)
	return ok and bottom<top-2*u and left>=0 and right<=view.x
## Slice 4's pixel check: the rendered pixels behind each control's words (the drawn backing over whatever world is
## there) against its ink. Relative luminance; WCAG's 4.5 for normal text. Only where frames are drawn.
func readable(where: String) -> void:
	if shot_path=="" or DisplayServer.get_name()=="headless" or hud._hands.scheme!="act":
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var worst := INF
	var ok := true
	for box: Dictionary in hud._hands.label_boxes():
		var behind := []
		for at: Vector2 in box.samples:
			var pixel := Vector2i(clampi(roundi(at.x),0,image.get_width()-1),clampi(roundi(at.y),0,image.get_height()-1))
			behind.append(luminance(image.get_pixelv(pixel)))
		behind.sort()
		var bright: float=behind[int(behind.size()*0.9)]
		var ratio: float=(luminance(box.ink)+0.05)/(bright+0.05)
		print("BODY CONTRAST ",where," ",box.name," behind=%.3f ratio=%.1f" % [bright,ratio])
		worst=minf(worst,ratio)
		ok=ok and ratio>=4.5
	check(ok,"every control's words read on their backing over %s (worst contrast %.1f)" % [where,worst])
## B7's pixel check: a bubble's rendered words against what is behind them on its backing, over the world and over a
## white wall in the 3D view (a bubble is 3D, so a 2D sheet would cover it). Only where frames are drawn.
func speech_readable() -> void:
	if shot_path=="" or DisplayServer.get_name()=="headless":
		return
	var reg: Node=Contact.registry(get_tree())
	check(reg!=null and reg.get("speech")!=null,"the village's speech manager is up for the bubble check")
	if reg==null or reg.get("speech")==null:
		return
	var speech: Node=reg.speech
	var camera := get_viewport().get_camera_3d()
	speech.say(player,"Find a tree. It has no friends.",Speech.STRUCK,990001)
	await active(0.5)
	await capture("speech-over-world")
	var world_ok: float=await _speech_contrast("the world")
	var wall := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size=Vector2(60,40)
	wall.mesh=quad
	var white := StandardMaterial3D.new()
	white.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	white.albedo_color=Color.WHITE
	wall.material_override=white
	add_child(wall)
	var at: Vector3=player.global_position
	wall.global_position=camera.global_position+(at-camera.global_position).normalized()*(camera.global_position.distance_to(at)+1.5)
	wall.look_at(camera.global_position,Vector3.UP,true)
	speech.say(player,"Find a tree. It has no friends.",Speech.STRUCK,990002)
	await active(0.5)
	await capture("speech-over-white")
	var white_ok: float=await _speech_contrast("a white wall")
	wall.queue_free()
	check(world_ok>=4.5 and white_ok>=4.5,"every speech bubble's words read on their backing over the world and over white (contrast %.1f / %.1f)" % [world_ok,white_ok])
func _speech_contrast(where: String) -> float:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var worst := INF
	var boxes: Array=Contact.registry(get_tree()).speech.label_boxes(get_viewport().get_camera_3d())
	var measured := 0
	for box: Dictionary in boxes:
		if float(box.alpha)<0.99:
			print("BODY SPEECH CONTRAST ",where," '",box.name,"' fading (alpha %.2f): not measured" % float(box.alpha))
			continue
		measured+=1
		var behind := []
		for p: Vector2 in box.samples:
			behind.append(luminance(image.get_pixelv(Vector2i(clampi(roundi(p.x),0,image.get_width()-1),clampi(roundi(p.y),0,image.get_height()-1)))))
		var ink := []
		var words: Rect2=box.words
		for y in range(int(words.position.y),int(words.end.y)):
			for x in range(int(words.position.x),int(words.end.x),2):
				ink.append(luminance(image.get_pixel(clampi(x,0,image.get_width()-1),clampi(y,0,image.get_height()-1))))
		behind.sort()
		ink.sort()
		var bright: float=behind[int(behind.size()*0.9)]
		var letters: float=ink[int(ink.size()*0.98)]
		var ratio: float=(letters+0.05)/(bright+0.05)
		print("BODY SPEECH CONTRAST ",where," '",box.name,"' rect=",box.rect," behind=%.3f ink=%.3f ratio=%.1f" % [bright,letters,ratio])
		worst=minf(worst,ratio)
	if measured==0:
		print("BODY SPEECH CONTRAST ",where," no bubble fully up")
		return 0.0
	return worst
static func luminance(c: Color) -> float:
	var lin := func(v: float) -> float: return v/12.92 if v<=0.04045 else pow((v+0.055)/1.055,2.4)
	return 0.2126*lin.call(c.r)+0.7152*lin.call(c.g)+0.0722*lin.call(c.b)
## B1 power-row readability (4 Oct ring spacing, now Body's): measured geometry for each open class, then an
## armed Meteor held and returned, in the normal camera. Cancel casts nothing.
func labels() -> void:
	var hands: Control=hud._hands
	for id: String in ["pyromancer","delver"]:
		Classes.choose(id)
		await frames(2)
		check(layout_clear(hands),"%s power rings, hint and discs keep apart inside the screen" % id)
		await capture("labels-"+id)
		await readable("the world (%s)" % id)
	Classes.choose("pyromancer")
	await frames(2)
	var at: Vector2=hands.surfaces()["power:meteor"]
	var to: Vector2=at+Vector2(-40,-60)*hands.unit()
	touch(71,at,true)
	drag(71,at,to)
	await active(0.2)
	var armed: bool=hands.pointers.has(71) and hands.pointers[71].armed and str(hands.preview().verb)=="power:meteor"
	check(armed,"held Meteor arms its ground ring")
	await capture("labels-meteor-held")
	drag(71,to,at)
	touch(71,at,false)
	await frames(2)
	check(hands.pointers.is_empty() and Classes.cooldown_left("meteor")==0.0,"returning the finger cancels without a cast")
	await speech_readable()
	if shot_path!="" and DisplayServer.get_name()!="headless" and hands.scheme=="act":
		# The worst world: a white sheet over the 3D view, under the HUD (CanvasLayer 1).
		var sheet := CanvasLayer.new()
		sheet.layer=0
		var white := ColorRect.new()
		white.color=Color.WHITE
		white.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sheet.add_child(white)
		add_child(sheet)
		await frames(2)
		await capture("labels-over-white")
		await readable("a white world")
		sheet.queue_free()
		await frames(2)
	if shot_path!="" and DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(shot_path)==OK,"final labels image")
func layout_clear(hands: Control) -> bool:
	var u: float=hands.unit()
	var view: Vector2=hands.get_viewport().get_visible_rect().size
	if hands.scheme=="act":
		return arcs_clear(hands,u,view)
	var discs := {}
	for role: String in hands.surfaces():
		discs[role]=(hands.radius_of(role)+(4.0 if role.begins_with("power:") else 0.0))*u # Power rings draw a cooldown arc at +4.
	var ok := true
	var top := INF
	for role: String in discs:
		var at: Vector2=hands.surfaces()[role]
		var r: float=discs[role]
		ok=ok and at.x-r>=0 and at.y-r>=0 and at.x+r<=view.x and at.y+r<=view.y
		if role.begins_with("power:"):top=minf(top,at.y-r)
		for other: String in discs:
			if other>role and at.distance_to(hands.surfaces()[other])<r+discs[other]+4*u:
				print("BODY LABELS touching ",role," ",other)
				ok=false
	# The hint's longest common line, at its drawn size, must sit above the row and inside the screen.
	var size := roundi(19*u)
	var width := 0.0
	for words: String in ["Shove Someone Longname 2.2 / 2.2 m","Put out / flick strike / push shove"]:
		width=maxf(width,hands.FONT.get_string_size(words,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x)
	var base: Vector2=hands.hint_at()
	var bottom: float=base.y+hands.FONT.get_descent(size)
	print("BODY LABELS view=",view," unit=",u," ring_top=",top," hint_bottom=",bottom," hint_x=",base.x-width*0.5,"..",base.x+width*0.5)
	return ok and bottom<top-2*u and base.x-width*0.5>=0 and base.x+width*0.5<=view.x
