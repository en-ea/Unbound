extends Control
## E/B6 continuous phone surfaces. A finger's origin role is fixed until release; camera owns other space.
## Intent/target captured at preparation; one preview, actual geometry at delivery. No fight mode.
const Gesture := preload("res://scripts/studio/player/gesture.gd")
const Driver := preload("res://scripts/studio/player/physical_input.gd")
const Feel := preload("res://scripts/studio/player/contact_feel.gd")
const TapRule := preload("res://scripts/studio/player/tap_rule.gd")
const People := preload("res://scripts/studio/village/sim/people.gd")
const FONT := preload("res://assets/fonts/Almendra-Regular.ttf")
const Look := preload("res://scripts/ui/button_look.gd") # merge-fix: the buttons' look
const AbilityIcons := preload("res://scripts/ui/ability_icons.gd") # merge-fix: the powers' symbols
var player
var driver
## C1 unit 1 (desk, 6 Oct): his buttons are the frame again. hud.gd hands them here by name (attack, heavy, parry,
## sneak, roll, swap); Attack and Heavy run their strokes through this surface's gestures, so the target ring, the lean,
## the hint and the buzz are the same ones the thumb area had. The thumb area itself is unrouted (its drawing and touch).
var buttons := {}
var _parry_finger := -1 # his Parry's finger while it holds the guard (a key in _live)
var _was_cooling := {} # C1 unit 3: ability -> it was cooling last drawn frame
var _ready_ring := {} # ability -> 1..0, his ready ring flying out as a cooldown ends
var pointers := {}
var _live := {}
signal intent_changed(intent: Dictionary) # Claude owns the player pose adapter consuming this stable intent.
var _teaching := {}
## B3: "act" is one thumb area where the motion picks the act; "discs" keeps Hand/Palm/Grip for comparison (dev arg).
var scheme := "act"
## Slice 5: the act is shown in the world (target ring, the player's lean, a buzz on contact). The words stay on in his
## build behind this switch until Hilmi has played; --words=off shows the scheme without them, for boards only.
var words := true
var feel := Feel.new()
const ACT_RADIUS := 115.0
## Slice 4: in "act" the powers are arcs just above the thumb area, reached by the thumb (a flick up is a strike, so
## a stroke never slides from the area into an arc). Angles in screen space, -90 straight up.
const ARC_GAP := 10.0
const ARC_BAND := 52.0
const ARC_FROM := -172.0 # C1: from his left (where his first power stood) ...
const ARC_TO := -84.0 # ... to just short of his Swap (-70 deg from Attack at his default spots)
const ARC_SPLIT := 4.0
## Every control's words sit on this, dark enough that cream ink reads over a white world (contrast >= 4.5).
const BACKING := Color(0.05,0.04,0.03,0.8)
const INK := Color(1,0.94,0.8)
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group("speech_occupied") # B7: speech keeps its bubbles off the controls and their words (occupied_rects)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	driver=Driver.new(player)
	process_priority=30
	if "--controls=discs" in OS.get_cmdline_user_args():
		scheme="discs"
	if "--words=off" in OS.get_cmdline_user_args():
		words=false
	add_to_group("studio_hands")
	# Permanent Body-owned normal-game proof; no new production action or shared dispatcher.
	if OS.is_debug_build():
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--body-play="):
				load("res://scripts/studio/player/body_play_probe.gd").on_device(get_tree())
				break
func unit() -> float:
	var viewport := get_viewport().get_visible_rect().size
	return clampf(minf(viewport.x,viewport.y)/720.0,0.65,2.0)
func centres() -> Dictionary:
	var viewport := get_viewport().get_visible_rect().size
	var u := unit()
	var hand := viewport-Vector2(135,165)*u
	return {"hand":hand,"shove":hand+Vector2(-115,0)*u,"grip":hand+Vector2(-60,95)*u,
		"feet":hand+Vector2(-195,95)*u}
func surfaces() -> Dictionary:
	var centre := centres()
	var out := centre.duplicate() if scheme=="discs" else {} # Slice 3: in "act" the left stick owns the feet; no Feet disc.
	var list := Classes.abilities()
	var hand: Vector2=centre.hand
	# studio 4 Oct: 92 apart so neighbouring cooldown rings (radius 40) no longer touch; row stays centred where it was.
	if scheme=="act":
		var area := arc_centre()
		var arc := arcs()
		for role: String in arc:
			out[role]=area+Vector2.from_angle((arc[role].x+arc[role].y)*0.5)*(arc_inner()+ARC_BAND*0.5*unit())
		# C1: the act is his Attack button now (and Heavy beside it); their centres, for the probes' real touches.
		out.act=hand if thumb() else _button_centre("attack",hand)
		out.heavy=_button_centre("heavy",hand+Vector2(-112,-72))
		out.parry=_button_centre("parry",hand+Vector2(-40,-132))
		return out
	for i in list.size():
		out["power:"+str(list[i])]=hand+Vector2(-77+(i-(list.size()-1)/2.0)*92,-145)*unit()
	return out
## C1: the arcs ring his Attack button, outside his inner buttons (Heavy, Parry, Sneak), from his left to just short of
## his Swap (ARC_FROM..ARC_TO, screen angles, -90 straight up). Measured from his buttons where they stand, so the
## band follows his editor's spots and his button size.
func _button_centre(id: String,fallback: Vector2) -> Vector2:
	var b: Control=buttons.get(id)
	return b.center() if is_instance_valid(b) else fallback
## C1 unit 5: the arc row is a movable item of his editor ("arcs"; its proxy while editing, then his saved spot).
func arc_centre() -> Vector2:
	if thumb(): # merge-fix: his thumb area, the arcs ring it
		return centres().hand
	var item: Control=buttons.get("arcs")
	if is_instance_valid(item):
		return item.center()
	if Settings.button_spots.has("arcs"):
		return get_viewport().get_visible_rect().size-Vector2(Settings.button_spots["arcs"])
	return _button_centre("attack",centres().hand)
func arc_inner() -> float:
	var centre := arc_centre()
	var inner: float=(ACT_RADIUS+ARC_GAP)*unit()
	if thumb():
		return inner
	for id: String in ["heavy","parry","sneak"]:
		var b: Control=buttons.get(id)
		if is_instance_valid(b) and b.is_visible_in_tree():
			var to: Vector2=b.center()-centre
			var half := asin(clampf(b.radius/maxf(to.length(),b.radius),0,1))
			if to.angle()+half>=deg_to_rad(ARC_FROM) and to.angle()-half<=deg_to_rad(ARC_TO):
				inner=maxf(inner,to.length()+b.radius+ARC_GAP*unit())
	return inner
func arc_outer() -> float:
	return arc_inner()+ARC_BAND*unit()
## Slice 4: each power's sector of the band above the thumb area, as Vector2(from, to) in radians.
func arcs() -> Dictionary:
	var list := Classes.abilities()
	var out := {}
	if list.is_empty():
		return out
	var span := arc_span()
	var width := (span.y-span.x-ARC_SPLIT*(list.size()-1))/list.size()
	for i in list.size():
		var start := span.x+i*(width+ARC_SPLIT)
		out["power:"+str(list[i])]=Vector2(deg_to_rad(start),deg_to_rad(start+width))
	return out
## The arcs' span in degrees: round his cluster (C1), or above his thumb area as the thumb area first had them.
func arc_span() -> Vector2:
	return Vector2(-150.0,-30.0) if thumb() else Vector2(ARC_FROM,ARC_TO)
func radius_of(role: String) -> float:
	return ACT_RADIUS if role=="act" else 68.0 if role=="hand" else 36.0
func role_at(at: Vector2) -> String:
	if scheme=="act": # C1: only the arcs; his buttons take their own touches (the thumb area is unrouted)
		var area := arc_centre()
		var reach := at.distance_to(area)
		if thumb() and reach<=ACT_RADIUS*unit(): # merge-fix: his thumb area (Settings: thumb_controls) takes the act's touches
			return "act"
		if reach>=arc_inner()-ARC_GAP*0.5*unit() and reach<=arc_outer()+6*unit():
			var angle := (at-area).angle()
			var arc := arcs()
			for role: String in arc:
				if angle>=arc[role].x-0.03 and angle<=arc[role].y+0.03:
					return role
		return ""
	for role: String in surfaces():
		if at.distance_to(surfaces()[role])<=radius_of(role)*unit():
			return role
	return ""
## merge-fix: Hilmi's thumb area is his Settings option (thumb_controls); off, C1's buttons are the act (the default).
func thumb() -> bool:
	return scheme=="act" and Settings.thumb_controls and not bow_out() # (the bow out: his Attack draws it, as his own hud had)
func covers(at: Vector2) -> bool:
	return is_visible_in_tree() and role_at(at)!=""
func _input(event: InputEvent) -> void:
	if Controls.locked or VillageSession.background or not is_visible_in_tree():
		cancel() # A queued release cannot commit before the next inactive process frame.
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed and pointers.has(touch.index) and pointers[touch.index].role in BUTTON_ROLES:
			return # His button owns this finger's release and hands it here (release_button).
		if not touch.pressed and pointers.has(touch.index):
			_release(touch.index)
			get_viewport().set_input_as_handled()
		elif touch.pressed and not Controls.locked and is_visible_in_tree():
			var role := role_at(touch.position)
			if role=="" or pointers.values().any(func(g) -> bool: return g.role==role):
				return
			var gesture := Gesture.new()
			gesture.begin(touch.index,role,touch.position,get_viewport().get_visible_rect().size,driver.capture(role))
			gesture.target.scale=unit()
			if role.begins_with("power:"):
				gesture.target.power=role.trim_prefix("power:")
			pointers[touch.index]=gesture
			get_viewport().set_input_as_handled()
			queue_redraw()
	elif event is InputEventScreenDrag and not pointers.has(event.index) and Settings.slide_buttons and scheme=="act":
		_slide_into_arc(event)
	elif event is InputEventScreenDrag and pointers.has(event.index):
		var gesture=pointers[event.index]
		if gesture.drag(event.index,event.position,event.relative):
			if gesture.armed and gesture.role in BUTTON_ROLES:
				buttons[gesture.role].studio_keep=true # Unit 5: armed here, it stays here (before his button sees the next move)
			if gesture.armed and not gesture.cancelled and gesture.intent in ["strike","heavy","shove"] and gesture.role!="heavy":
				var aim: Vector2=Vector2(0,-1) if Gesture.by_direction and gesture.role=="act" else gesture.offset # merge-fix: by direction, blows go ahead
				driver.aim_target(gesture.target,driver.direction(aim,gesture.target.yaw))
			elif gesture.role.begins_with("power:") and not gesture.cancelled and gesture.armed:
				gesture.target.forward=driver.direction(gesture.offset,gesture.target.yaw)
			get_viewport().set_input_as_handled()
			queue_redraw()
## C1 unit 5: a finger sliding off one of his buttons into a power's arc lets the button go quietly and arms that arc's
## aim from where it came in (its lift then fires it, aimed). A finger that armed an act on the button stays there.
func _slide_into_arc(event: InputEventScreenDrag) -> void:
	for id: String in buttons:
		var b: ActionButton=buttons[id]
		if b!=null and b._held==event.index and not b.studio_keep:
			# The same 8 px samples his button takes: whichever the move reaches first, another button or an arc, has it.
			var from: Vector2=b._studio_last if b._studio_last!=Vector2.INF else event.position
			var steps := maxi(1,ceili(from.distance_to(event.position)/b.STUDIO_STEP))
			var role := ""
			var at := event.position
			for k in range(1,steps+1):
				var q := from.lerp(event.position,float(k)/steps)
				if q.distance_to(b.center())<b.radius*b.STUDIO_HYSTERESIS:
					continue
				if buttons.values().any(func(o) -> bool: return o!=null and o!=b and o.is_visible_in_tree() and q.distance_to(o.center())<o.radius):
					return # another button comes first: his slide hands it there
				if role_at(q).begins_with("power:"):
					role=role_at(q)
					at=q
					break
			if role=="" or pointers.values().any(func(g) -> bool: return g.role==role):
				return
			b._held=-1 # (his own slide lets go the same way: quietly, no release)
			b.queue_redraw()
			var gesture := Gesture.new()
			gesture.begin(event.index,role,at,get_viewport().get_visible_rect().size,driver.capture(role))
			gesture.target.scale=unit()
			gesture.target.power=role.trim_prefix("power:")
			pointers[event.index]=gesture
			get_viewport().set_input_as_handled()
			queue_redraw()
			return
## One finger's lift: its act commits through the driver, with the release cue and the buzz.
func _release(index: int) -> void:
	var gesture=pointers[index]
	var intent: String=gesture.release(index)
	if intent=="severe": # Unit 2: the held Heavy has already done its act; the lift adds nothing.
		pointers.erase(index)
		queue_redraw()
		return
	if gesture.role in ["act","attack"] and intent=="use":
		intent=str(gesture.target.get("tap","use"))
	_live_end(index)
	if intent!="cancel":
		var strength := clampf(gesture.offset.length()/(80*unit()),0,1)
		if gesture.role in ["act","attack"] and intent in ["strike","heavy"]:
			gesture.target.force=gesture.force() # Slice 2: the flick's speed is the blow's force (merge-fix: by direction, its act's).
			strength=gesture.force()/1000.0
		var released: Dictionary=gesture.target.duplicate()
		released.merge({"verb":intent,"phase":"released","strength":strength},true)
		intent_changed.emit(released) # Physical release cue, not an accepted fact/assault.
		driver.commit(intent,gesture.target,strength,gesture.offset)
		_feel_for(intent,gesture.target)
	pointers.erase(index)
	queue_redraw()
## C1: his buttons' presses and lifts (hud.gd connects their signals here). With the bow out, Attack and Heavy keep
## his own acts (draw and loose, Triple Shot); with the sword they are strokes on this surface.
const BUTTON_ROLES := ["attack","heavy"]
func bow_out() -> bool:
	return Gear.has_bow and Gear.weapon=="bow"
func press_button(id: String) -> void:
	var b: ActionButton=buttons.get(id)
	if b==null or Controls.locked or VillageSession.background or not is_visible_in_tree():
		return
	match id:
		"attack":
			if bow_out():
				player.act()
				return
			_begin_button(b,"attack")
		"heavy":
			if bow_out():
				player.heavy()
				return
			_begin_button(b,"heavy")
		"parry": # His tap; a hold keeps it up (_buttons_step).
			_parry_finger=b._held
			player.guard()
		"sneak": player.sneak()
func release_button(id: String) -> void:
	var b: ActionButton=buttons.get(id)
	if b==null:
		return
	var finger: int=b._held
	if Controls.locked or VillageSession.background or not is_visible_in_tree():
		cancel() # A queued lift cannot commit while play is not live.
		return
	if id=="parry" and _live.has(finger):
		_live_end(finger)
		intent_changed.emit({"verb":"guard","phase":"released","strength":0.0,"target":-2}) # The held guard's release cue.
	if pointers.has(finger) and pointers[finger].role==id:
		_release(finger)
func _begin_button(b: ActionButton,role: String) -> void:
	var finger: int=b._held
	if pointers.has(finger) and pointers[finger].role in BUTTON_ROLES and buttons[pointers[finger].role]._held!=finger:
		pointers[finger].cancel() # Unit 5: this finger slid here from another button: that stroke lets go quietly
		pointers.erase(finger)
	if finger<0 or pointers.has(finger) or pointers.values().any(func(g) -> bool: return g.role==role):
		return
	var gesture := Gesture.new()
	gesture.begin(finger,role,b._start,get_viewport().get_visible_rect().size,driver.capture(role))
	gesture.target.scale=unit()
	if role=="heavy": # Decided at the press: a villager captured is the checked shove, anyone or anything else the swing.
		gesture.intent="shove" if int(gesture.target.get("target",-2))>=0 else "heavy"
		gesture.target.severe=driver.severe(gesture.target) # Unit 2: what holding on would do, captured here with the rest.
	pointers[finger]=gesture
	queue_redraw()
## His Compact setting: a flick up on Attack is the Heavy tap, at once.
func compact_heavy() -> void:
	var b: ActionButton=buttons.get("attack")
	if b==null or bow_out():
		player.heavy()
		return
	var intent: Dictionary=driver.capture("heavy")
	var verb := "shove" if int(intent.get("target",-2))>=0 else "heavy"
	driver.commit(verb,intent,1.0)
	_feel_for(verb,intent)
func _process(dt: float) -> void:
	var stick: Dictionary=Controls.stick_act # Read once; an inactive frame drops it.
	Controls.stick_act={}
	if Controls.locked or not is_visible_in_tree() or VillageSession.background:
		cancel()
		return
	if scheme=="act" and not stick.is_empty():
		feet(stick)
	driver.pushing=pointers.values().any(func(g) -> bool: return g.role in ["act","attack"] and g.intent=="shove" and not g.cancelled)
	driver.step(dt)
	if VillageSession.village!=null:
		feel.step(VillageSession.village,People.tick(VillageSession.village))
	intent_changed.emit(preview())
	_buttons_step()
	_severe_step()
	for ability: String in _ready_ring.keys():
		_ready_ring[ability]=maxf(0.0,float(_ready_ring[ability])-dt*2.5)
	for finger: int in pointers:
		var gesture=pointers[finger]
		gesture.tick(dt)
		if gesture.intent in ["guard","crouch"] and not gesture.cancelled and not _live.has(finger):
			_live[finger]=gesture.intent
			driver.live(gesture.intent,true)
		if gesture.cancelled:
			_live_end(finger)
	queue_redraw()
## C1 unit 2: holding Heavy. At SEVERE_HOLD with a severe target captured at the press, the severe act happens then,
## while still held (the ring has filled); the lift after it does nothing more. With none, holding is just a slower tap.
## DISMEMBER_HOLD is reserved for the next stage on the same hold and target (not built).
const SEVERE_HOLD := 0.35
const DISMEMBER_HOLD := 0.9
func _severe_step() -> void:
	for gesture in pointers.values():
		if gesture.role!="heavy" or gesture.cancelled or gesture.intent=="severe":
			continue
		var severe: Dictionary=gesture.target.get("severe",{})
		if not severe.is_empty() and gesture.age>=SEVERE_HOLD:
			gesture.intent="severe"
			var released: Dictionary=gesture.target.duplicate()
			released.merge({"verb":"severe","phase":"released","strength":1.0,"severe":str(severe.kind)},true)
			intent_changed.emit(released)
			driver.commit("severe",gesture.target)
## C1: his Parry held past the hold time keeps the guard up (the studio's held guard); his Attack and Heavy read what
## a tap would do now.
func _buttons_step() -> void:
	# Unit 5: a finger that armed an act on his button never slides away from it (a flick, a held draw, a held Heavy);
	# a stroke whose finger has slid on to another button lets go quietly (no act).
	for finger: int in pointers.keys():
		var g=pointers[finger]
		if g.role in BUTTON_ROLES:
			var owner: ActionButton=buttons[g.role]
			if owner._held!=finger:
				g.cancel()
				pointers.erase(finger)
			else:
				owner.studio_keep=g.armed or (g.role=="heavy" and (not g.target.get("severe",{}).is_empty() or g.age>=SEVERE_HOLD))
	var bow_button: ActionButton=buttons.get("attack")
	if bow_button!=null and bow_out() and bow_button.is_held():
		bow_button.studio_keep=player.fighter.aiming()
	var parry: ActionButton=buttons.get("parry")
	if parry!=null and parry.is_held() and parry._held==_parry_finger and parry.held_for()>=Gesture.HOLD and not _live.has(parry._held):
		_live[parry._held]="guard"
		driver.live("guard",true)
	var attack: ActionButton=buttons.get("attack")
	if attack!=null:
		var words: String=str(player.verb) if bow_out() else attack_verb()
		if attack.verb!=words:
			attack.set_verb(words)
	var heavy: ActionButton=buttons.get("heavy")
	if heavy!=null:
		var words2 := "Heavy" if bow_out() else str(_severe_ahead().get("verb","Heavy"))
		if heavy.verb!=words2:
			heavy.set_verb(words2)
## What his Attack's tap does now, in his words (nothing in reach: his "Attack", a swing at the air).
func attack_verb() -> String:
	var c: Dictionary=driver.tap_context().context
	return "Attack" if str(c.get("kind","empty")) in ["empty","fight"] else str(c.get("verb","Attack"))
func _villager_ahead() -> bool:
	var probe: Dictionary=driver.capture("heavy")
	return int(probe.get("target",-2))>=0
## What holding Heavy would do on what a press would capture now (the label shows the hold's act; the tap is the shove).
func _severe_ahead() -> Dictionary:
	return driver.severe(driver.capture("heavy"))
## B3 slice 3: the stick's lift. A flick dodges its way through the same commit the Feet disc used; a tap is the
## native crouch toggle (stand again with a tap, or by sprinting). The release cue matches the disc's.
func feet(stick: Dictionary) -> void:
	var intent: Dictionary=driver.capture("feet")
	var verb := str(stick.get("verb",""))
	var offset: Vector2=stick.get("offset",Vector2.ZERO)
	if verb=="dodge":
		intent.forward=driver.direction(offset,intent.yaw)
	var released := intent.duplicate()
	released.merge({"verb":verb,"phase":"released","strength":clampf(offset.length()/(80*unit()),0,1)},true)
	intent_changed.emit(released)
	if verb=="dodge":
		driver.commit("dodge",intent,0.0,offset)
	elif verb=="crouch" and not player.is_down():
		player.sneak()
## Slice 5: watch the checked receipt of the act just released; contact_feel buzzes once if it lands.
func _feel_for(intent: String,target: Dictionary) -> void:
	if VillageSession.village==null:
		return
	feel.actor=driver.actor()
	var context: Dictionary=target.get("context",{})
	var verb := "strike" if intent in ["strike","heavy"] else "shove" if intent=="shove" else ""
	var id := int(target.get("target",-2))
	if intent=="grip" and str(context.get("kind","")) in ["person","person_down"]:
		verb="carry" if context.kind=="person" else "set_down"
		id=int(context.get("id",-2))
	if verb!="":
		feel.watch(VillageSession.village,str(target.get("press_id","")),verb,id,People.tick(VillageSession.village))
## Slice 5: the body a prepared act points at, for its ring on the ground (null when none).
func ring_target() -> Node3D:
	for gesture in pointers.values():
		if gesture.cancelled:
			return null
		if gesture.intent in ["strike","heavy"] and not TapRule.strikes_while(driver.load_kind()):
			return null # Carrying: the flick strikes nobody, so nobody is ringed.
		if gesture.intent in ["strike","heavy","shove"]:
			var res := preload("res://scripts/studio/village/contact.gd").registry(get_tree())
			var body: Node3D=gesture.target.get("native")
			if res!=null and int(gesture.target.get("target",-2))>=0:
				body=res.bodies.get(int(gesture.target.target))
			return body if is_instance_valid(body) else null
		if gesture.intent in ["use","grip"]:
			var node=gesture.target.get("context_view",{}).get("node")
			return node if node is Node3D and is_instance_valid(node) else null
	return null
## Real E3 consumption port: no animation implementation here.
## verb/phase/strength/forward/target are prepared intent, not permission, identity truth or accepted facts.
func preview() -> Dictionary:
	for gesture in pointers.values():
		if gesture.intent in ["strike","heavy"] and not TapRule.strikes_while(driver.load_kind()):
			break # Carrying: the flick strikes nobody, so the body does not lean into a blow.
		var strength := clampf(gesture.offset.length()/(80*unit()),0,1)
		if gesture.role in ["act","attack"] and gesture.armed and gesture.intent in ["strike","heavy"]:
			strength=gesture.force()/1000.0 # Slice 5: the lean shows the blow's force while it is aimed.
		return {"verb":gesture.intent,"phase":"cancelled" if gesture.cancelled else "prepared",
			"strength":strength,"forward":gesture.target.get("forward",Vector3.ZERO),
			"target":gesture.target.get("target",-2)}
	return {"verb":"","phase":"idle","strength":0.0,
		"load":"person" if player.has_meta("studio_people_load") else "carcass" if player.hauling.carrying else "",
		"guard":player._studio_guard,"crouch":player.sneaking}
func _ring(camera: Camera3D,at: Vector3,radius: float,color: Color) -> void:
	var points := PackedVector2Array()
	for i in 33:
		var point := at+Vector3(cos(TAU*i/32.0),0.05,sin(TAU*i/32.0))*radius
		if camera.is_position_behind(point):
			return
		points.append(camera.unproject_position(point))
	draw_polyline(points,color,2*unit(),true)
func _live_end(finger: int) -> void:
	if _live.has(finger):
		driver.live(str(_live[finger]),false)
		_live.erase(finger)
func cancel() -> void:
	_parry_finger=-1 # A held guard cut short by a menu or the background does not come back on its own.
	for finger: int in _live.keys():
		_live_end(finger)
	for gesture in pointers.values():
		gesture.cancel()
	pointers.clear()
	queue_redraw()
func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT or what==NOTIFICATION_VISIBILITY_CHANGED:
		if driver!=null:
			cancel()
func _text(at: Vector2,words: String,color := Color(1,0.94,0.8),font_size := 16) -> void:
	var font := FONT
	var size := roundi(font_size*unit())
	var width := font.get_string_size(words,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	draw_string(font,at-Vector2(width*0.5,0),words,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
func _target_feedback(body: Node3D,reach: float,tint: Color) -> String:
	if not is_instance_valid(body):
		return ""
	var gap: float=player.global_position.distance_to(body.global_position)
	var camera := get_viewport().get_camera_3d()
	if camera!=null and not camera.is_position_behind(body.global_position):
		draw_arc(camera.unproject_position(body.global_position+Vector3(0,1,0)),25*unit(),0,TAU,32,tint,2*unit(),true)
	return " %.1f / %.1f m" % [gap,reach]
func _draw() -> void:
	if player==null or driver==null:
		return
	var u := unit()
	if scheme=="act":
		_draw_act(u)
		_draw_hold(u)
		_draw_bow(u)
	for role: String in ([] if scheme=="act" else surfaces().keys()):
		var at: Vector2=surfaces()[role]
		var radius := radius_of(role)
		var color := Color(0.92,0.75,0.45,0.65)
		if role.begins_with("power:"):
			color=Classes.color()
		draw_circle(at,radius*u,Color(0.06,0.04,0.03,0.18 if role=="act" else 0.30),true,-1,true)
		draw_arc(at,radius*u,0,TAU,64 if role=="act" else 48,color,2*u,true)
		var label := "Hand" if role in ["hand","act"] else "Palm" if role=="shove" else "Grip" if role=="grip" else "Feet" if role=="feet" else str(Classes.ABILITIES[role.trim_prefix("power:")]["short"])
		var dragging: bool=role=="power:burrow" and player.burrowed()
		if dragging:
			label="Drag" if not player.abilities.delver.dragged_this_dive else "Used"
		_text(at+Vector2(0,6)*u,label,color,16)
		if role.begins_with("power:"):
			draw_arc(at,(radius+4)*u,-PI/2,-PI/2+TAU*(1.0-(0.0 if dragging else Classes.cooldown_left(role.trim_prefix("power:")))),48,color,3*u,true)
	var ringed := ring_target()
	var view_camera := get_viewport().get_camera_3d()
	if ringed!=null and view_camera!=null: # Slice 5: who the act will reach (merge-fix: an arrow over their head, not rings)
		_marker(view_camera,ringed,Color(1,0.5,0.3) if pointers.values().any(func(g) -> bool: return g.intent in ["strike","heavy","shove"]) else Color(1.0,0.82,0.42))
	var preview := ""
	var tint := Color(1,0.94,0.8)
	for gesture in pointers.values():
		var intent: String=gesture.intent
		preview="Cancel" if gesture.cancelled else intent.capitalize()
		if gesture.cancelled:
			continue
		if intent=="use" or intent=="grip":
			preview=str(gesture.target.get("context",{}).get("verb",preview))
			var focus: Dictionary=gesture.target.get("context_view",{})
			preview+=" "+str(focus.get("label",""))
			preview+=_target_feedback(focus.get("node"),float(focus.get("reach",1.8)),tint)
		elif gesture.role=="heavy" and not gesture.target.get("severe",{}).is_empty():
			tint=Color(1,0.62,0.42)
			preview=("" if intent=="severe" else "Hold: ")+str(gesture.target.severe.verb)
		elif intent in ["strike","heavy","shove"]:
			tint=Color(1,0.62,0.42) # Slice 4: light enough to keep 4.5 contrast on the backing.
			preview+=" "+str(gesture.target.get("label","air"))
			var res := preload("res://scripts/studio/village/contact.gd").registry(get_tree())
			var body: Node3D=gesture.target.get("native")
			if res!=null and int(gesture.target.target)>=0:
				body=res.bodies.get(int(gesture.target.target))
			preview+=_target_feedback(body,2.8 if intent=="heavy" else 2.2,tint)
		if gesture.role.begins_with("power:") and gesture.armed:
			preview=_power_preview(gesture)
		draw_line(gesture.origin,gesture.origin+gesture.offset,tint,4*u,true)
		draw_circle(gesture.origin+gesture.offset,9*u,tint,true,-1,true)
		if gesture.armed:
			if scheme=="act":
				if words:
					_pill(gesture.origin+Vector2(0,-95)*u,"Return to cancel",tint,14)
			else:
				_text(gesture.origin+Vector2(0,-95)*u,"Return to cancel",tint,14)
		break
	if preview=="" and scheme=="act": # C1: his Attack's motions (with the bow, his own draw and Triple Shot)
		var held: Dictionary=_severe_ahead() if not bow_out() else {}
		preview="Hold Attack: draw / Heavy: Triple Shot" if bow_out() else attack_verb()+" / hold Heavy: "+str(held.verb) if not held.is_empty() else TapRule.hint(attack_verb(),driver.load_kind())
	if preview=="":
		preview=str(driver.context().get("verb","Use"))+" / stroke strike"
	if scheme=="act": # Slice 3's words for the stick and the hint, each on its backing; text stays until Hilmi has played.
		if words:
			_pill(stick_hint_at(),STICK_WORDS,INK,15)
			_pill(hint_at(),preview,tint,19)
		_hint_words=preview
	else:
		# Above the power row, not squeezed between it and Palm/Hand (owner screenshot 161221: label overlapped the rings).
		_text(hint_at(),preview,tint,19)
const STICK_WORDS := "flick dodge / tap crouch"
var _hint_words := "Use / flick strike / push shove" # As last drawn, so the board samples the drawn pill.
## Where the hint's baseline is centred: above the arcs (act) or above the power row (discs).
func hint_at() -> Vector2:
	if scheme=="act": # C1: above the arcs' highest point, over the middle of the band
		var mid := deg_to_rad((arc_span().x+arc_span().y)*0.5)
		return Vector2(arc_centre().x+cos(mid)*arc_outer(),arc_centre().y-arc_outer()-30*unit())
	return centres().hand+Vector2(-77,-200)*unit()
func stick_hint_at() -> Vector2:
	if Settings.button_spots.has("stick"): # C1 unit 5: under the stick's rest spot, where his editor put it
		return get_viewport().get_visible_rect().size-Vector2(Settings.button_spots["stick"])+Vector2(0,95)
	return Vector2(220,get_viewport().get_visible_rect().size.y-95)
func _pill_rect(at: Vector2,words: String,font_size: int) -> Rect2:
	var size := roundi(font_size*unit())
	var width := FONT.get_string_size(words,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	var pad := 6*unit()
	return Rect2(at.x-width*0.5-pad,at.y-FONT.get_ascent(size)-pad*0.5,width+pad*2,FONT.get_ascent(size)+FONT.get_descent(size)+pad)
func _pill(at: Vector2,words: String,color: Color,font_size: int) -> void:
	var box := StyleBoxFlat.new() # merge-fix: rounded, with a faint gold edge
	box.bg_color=BACKING
	box.set_corner_radius_all(roundi(10*unit()))
	box.border_color=Color(1.0,0.82,0.42,0.35)
	box.set_border_width_all(1)
	box.anti_aliasing=true
	draw_style_box(box,_pill_rect(at,words,font_size).grow_individual(4*unit(),0,4*unit(),0))
	_text(at,words,color,font_size)
## merge-fix (owner, 6 Oct: the two rings on the ground looked odd): who the act will reach, as one small arrow
## floating over their head, pointing down at them, gently bobbing; gold to use or talk, orange to strike.
func _marker(camera: Camera3D,body: Node3D,color: Color) -> void:
	var head := body.global_position+Vector3(0,2.2*body.scale.y+0.08*sin(Time.get_ticks_msec()*0.006),0)
	if camera.is_position_behind(head):
		return
	var tip := camera.unproject_position(head)
	var u := unit()
	var w := 11.0*u
	var h := 13.0*u
	var arrow := PackedVector2Array([tip,tip+Vector2(-w,-h),tip+Vector2(0,-h*0.6),tip+Vector2(w,-h)])
	Look.blob(self,tip+Vector2(0,-h*0.5),Vector2.ONE*w*2.2,Color(color,0.35))
	var outline := arrow.duplicate()
	outline.append(arrow[0])
	draw_polyline(outline,Color(0.05,0.03,0.02,0.85),4*u,true)
	draw_colored_polygon(arrow,color)
	draw_polyline(PackedVector2Array([tip+Vector2(-w,-h),tip+Vector2(0,-h*0.6)]),Color(1,1,1,0.55),1.2*u,true)
## C1 unit 3: what an aimed power will do, drawn on the ground before release (design section 4), and its words.
## Only while a power is aimed: rings, strips and lines (a draw each), no cost otherwise.
func _power_preview(gesture) -> String:
	var ability: String=gesture.role.trim_prefix("power:")
	var words := str(Classes.ABILITIES[ability]["short"])+" / release"
	var camera := get_viewport().get_camera_3d()
	if camera==null:
		return words
	var tint: Color=Classes.color()
	var here: Vector3=player.global_position
	var forward: Vector3=gesture.target.get("forward",Vector3.FORWARD)
	var point: Vector3=driver.aim_point(gesture.target,gesture.offset)
	var delver=player.abilities.delver
	var shade=player.abilities.shade
	# Any power whose code describes its own reach (preview(ability, aim_point) -> {shape "ring"|"cone", at, radius,
	# angle_deg, forward[, reach]}) is drawn from that: one branch, no class named here (the Tidecaller's first).
	for source in player.abilities.get_children():
		if source.has_method("preview"):
			var reach_aim: Vector3=point
			var shape: Dictionary=source.preview(ability,reach_aim)
			if shape.has("reach") and Vector2(point.x-here.x,point.z-here.z).length()>float(shape.reach):
				var off := Vector3(point.x-here.x,0,point.z-here.z).limit_length(float(shape.reach))
				reach_aim=here+off
				shape=source.preview(ability,reach_aim)
			if not shape.is_empty():
				_shape(camera,shape,tint)
				return words
	match ability:
		"meteor":
			_ring(camera,point,player.abilities._meteor_radius(),tint)
		"cinderburst":
			_ring(camera,here,6.0*(1.4 if Classes.has_talent("wide_ring") else 1.0),tint)
		"flame_dash":
			_strip(camera,here,forward,7.5,1.7,tint)
			_ring(camera,here+forward*7.5,1.7,tint)
		"fault_line": # along the aim, snapped to the foe his fault would turn to (within 12 m that way)
			var foe: Node3D=delver._nearest(12.0,forward)
			var way: Vector3=forward
			if foe!=null:
				way=Vector3(foe.global_position.x-here.x,0,foe.global_position.z-here.z).normalized()
				_ring(camera,foe.global_position,0.7,INK)
			_strip(camera,here,way,delver.FAULT_LENGTH*(1.5 if Classes.has_talent("long_fault") else 1.0),delver.FAULT_WIDTH,tint)
		"sinkhole":
			var off := Vector3(point.x-here.x,0,point.z-here.z).limit_length(delver.PIT_REACH)
			_ring(camera,here+off,delver.PIT_RADIUS*(1.33 if Classes.has_talent("wide_pit") else 1.0),tint)
		"burrow":
			if player.burrowed(): # the Drag: its reach, and the foe it would take
				_ring(camera,here,delver.DRAG_REACH,tint)
				var foe: Node3D=delver._nearest(delver.DRAG_REACH)
				if foe!=null:
					_ring(camera,foe.global_position,0.7,INK)
				else:
					words="Nobody close enough to drag under"
				if delver.dragged_this_dive:
					words="Used this dive"
		"shadow_dance":
			_ring(camera,here,shade.DANCE_REACH*(1.5 if Classes.has_talent("deep_step") else 1.0),tint)
			var foes: Array=shade.dance_targets()
			for foe: Node3D in foes.slice(0,shade.DANCE_CUTS):
				_ring(camera,foe.global_position,0.7,INK)
			if foes.is_empty():
				words="No one close enough to dance with"
		"mirage": # the double stands where he is, facing the aim; he slips back out of it
			_ring(camera,here,0.6,INK)
			_line(camera,here,here-forward*2.0,tint)
			_ring(camera,here-forward*2.0,0.35,tint)
		"switch": # the nearest double he would swap with, or the burst round him
			var double: Node3D=null
			for d in shade._pool:
				if d.active and (double==null or d.global_position.distance_to(here)<double.global_position.distance_to(here)):
					double=d
			if double!=null:
				_line(camera,here,double.global_position,tint)
				_ring(camera,double.global_position,shade.SWITCH_RADIUS*(1.35 if Classes.has_talent("wide_burst") else 1.0),tint)
			else:
				_ring(camera,here,shade.SWITCH_RADIUS*(1.35 if Classes.has_talent("wide_burst") else 1.0),tint)
				words="No double: burst and vanish / release"
	return words
## A described reach (a power's own preview()): a ring, or a cone of angle_deg about forward, on the ground.
func _shape(camera: Camera3D,shape: Dictionary,color: Color) -> void:
	var at: Vector3=shape.get("at",player.global_position)
	var radius := float(shape.get("radius",1.0))
	if str(shape.get("shape","ring"))!="cone" or float(shape.get("angle_deg",360.0))>=359.0:
		_ring(camera,at,radius,color)
		return
	var forward: Vector3=shape.get("forward",Vector3.FORWARD)
	var half := deg_to_rad(float(shape.get("angle_deg",60.0))*0.5)
	var points := PackedVector2Array()
	var corners: Array[Vector3]=[at]
	for i in 13:
		corners.append(at+forward.rotated(Vector3.UP,lerpf(-half,half,i/12.0))*radius)
	corners.append(at)
	for c: Vector3 in corners:
		var q := c+Vector3(0,0.05,0)
		if camera.is_position_behind(q):
			return
		points.append(camera.unproject_position(q))
	draw_polyline(points,color,2*unit(),true)
## A strip on the ground from `from` along `dir`, `length` x `width` metres (Flame Dash's path, the Fault Line).
func _strip(camera: Camera3D,from: Vector3,dir: Vector3,length: float,width: float,color: Color) -> void:
	var d := Vector3(dir.x,0,dir.z).normalized()
	var side := d.cross(Vector3.UP)*width*0.5
	var corners: Array[Vector3]=[from+side,from+d*length+side,from+d*length-side,from-side,from+side]
	var points := PackedVector2Array()
	for c: Vector3 in corners:
		var p := c+Vector3(0,0.05,0)
		p.y=WorldShape.new().height_at(p.x,p.z)+0.05 if absf(p.y-from.y)<3.0 else p.y
		if camera.is_position_behind(p):
			return
		points.append(camera.unproject_position(p))
	draw_polyline(points,color,2*unit(),true)
## A line on the ground between two points (Switch to its double, Mirage's step back, the bow's aim).
func _line(camera: Camera3D,a: Vector3,b: Vector3,color: Color) -> void:
	if camera.is_position_behind(a) or camera.is_position_behind(b):
		return
	draw_line(camera.unproject_position(a+Vector3(0,0.05,0)),camera.unproject_position(b+Vector3(0,0.05,0)),color,2*unit(),true)
## C1 unit 3: while his bow draws: a line to the target it will loose at, and a draw arc round his Attack that fills
## with the draw and turns gold in the Perfect window (his PERFECT after full).
func _draw_bow(u: float) -> void:
	var fighter=player.fighter
	var attack: ActionButton=buttons.get("attack")
	if attack==null or not fighter.aiming():
		return
	var full: float=fighter.DRAW_TIME*(fighter.TRIPLE["draw"]/fighter.DRAW_TIME if fighter._triple else 1.0)
	var k := clampf(float(fighter._draw)/maxf(full,0.01),0,1)
	var perfect: bool=float(fighter._full_at)>=0.0 and float(fighter._draw)-float(fighter._full_at)<=fighter.PERFECT and not fighter._triple
	var r: float=attack.radius+7*u
	draw_arc(attack.center(),r,0,TAU,48,Color(0.05,0.04,0.03,0.7),6*u,true)
	draw_arc(attack.center(),r,-PI/2,-PI/2+TAU*k,48,Color(1,0.82,0.42) if perfect else INK,4*u,true)
	var camera := get_viewport().get_camera_3d()
	var target: Node3D=fighter._bow_target if is_instance_valid(fighter._bow_target) else fighter.target
	if camera!=null and is_instance_valid(target):
		_line(camera,player.global_position,target.global_position,Color(1,0.82,0.42) if perfect else INK)
## C1 unit 2: the hold's fill round his Heavy while a severe act is captured: a dark track, then the fill in the
## blow's colour, full (gold) once the act is done. Drawn only while held (two arcs).
func _draw_hold(u: float) -> void:
	var heavy: ActionButton=buttons.get("heavy")
	if heavy==null:
		return
	for gesture in pointers.values():
		if gesture.role!="heavy" or gesture.cancelled or gesture.target.get("severe",{}).is_empty():
			continue
		var r: float=heavy.radius+7*u
		var k := clampf(gesture.age/SEVERE_HOLD,0,1)
		draw_arc(heavy.center(),r,0,TAU,40,Color(0.05,0.04,0.03,0.7),6*u,true)
		draw_arc(heavy.center(),r,-PI/2,-PI/2+TAU*k,40,Color(1,0.82,0.42) if gesture.intent=="severe" else Color(1,0.62,0.42),4*u,true)
## Slice 4 (act): the power arcs round his cluster (C1: the thumb area is unrouted, his Attack button is the act).
## merge-fix: drawn in the buttons' look (button_look.gd): each power a glassy band in the class colour with its symbol,
## a dark shade over the cooldown still to wait (and the seconds), and a soft glow once it's ready.
func _draw_act(u: float) -> void:
	if thumb():
		_draw_thumb_area(u)
	var area := arc_centre()
	var arc := arcs()
	var r0 := arc_inner()
	var r1 := arc_outer()
	var font := get_theme_default_font()
	for role: String in arc:
		var a0: float=arc[role].x
		var a1: float=arc[role].y
		var color := Classes.color()
		var ability := role.trim_prefix("power:")
		var dragging: bool=ability=="burrow" and player.burrowed()
		var left := 0.0 if dragging else Classes.cooldown_left(ability)
		var mid := area+Vector2.from_angle((a0+a1)*0.5)*(r0+r1)*0.5
		if left<=0.0: # ready: a soft glow in the class colour, beating
			var beat := 0.5+0.5*sin(Time.get_ticks_msec()*0.004)
			Look.blob(self,mid,Vector2.ONE*ARC_BAND*u*(0.95+0.08*beat),Color(color,0.22+0.14*beat))
		var points := PackedVector2Array()
		var tints := PackedColorArray()
		for i in 17: # the outer edge lit, the inner one deep
			points.append(area+Vector2.from_angle(lerpf(a0,a1,i/16.0))*r1)
			tints.append(Color(color.darkened(0.35),0.85))
		for i in range(16,-1,-1):
			points.append(area+Vector2.from_angle(lerpf(a0,a1,i/16.0))*r0)
			tints.append(Color(0.05,0.05,0.08,0.88))
		draw_polygon(points,tints)
		if left>0.0: # C1 unit 3: his cooldown wedge over what is still to wait
			var from := a0+(a1-a0)*(1.0-left)
			var wedge := PackedVector2Array()
			for i in 9:
				wedge.append(area+Vector2.from_angle(lerpf(from,a1,i/8.0))*(r1-1*u))
			for i in range(8,-1,-1):
				wedge.append(area+Vector2.from_angle(lerpf(from,a1,i/8.0))*(r0+1*u))
			draw_colored_polygon(wedge,Color(0.01,0.02,0.04,0.6))
		points.append(points[0])
		draw_polyline(points,Color(0,0,0,0.5),3.5*u,true)
		draw_polyline(points,Color(color.lightened(0.4),0.9 if left<=0.0 else 0.5),1.6*u,true)
		var ink := Color(INK,1.0 if left<=0.0 else 0.4)
		if dragging:
			_text(mid+Vector2(0,6)*u,"Drag" if not player.abilities.delver.dragged_this_dive else "Used",INK,16)
		elif AbilityIcons.draw(self,ability,mid+Vector2(0,2)*u,17*u,Color(0,0,0,0.45*ink.a),Color(0.05,0.06,0.09)):
			AbilityIcons.draw(self,ability,mid,17*u,ink,Color(0.05,0.06,0.09))
		elif left<=0.0: # a power with no symbol yet: its name
			_text(mid+Vector2(0,6)*u,str(Classes.ABILITIES[ability]["short"]),INK,16)
		if left>0.0: # the seconds left, and his cooldown filling along the outer edge
			var secs := str(ceili(left*Classes.cooldown_of(ability)))
			var size := roundi(20*u)
			var w := font.get_string_size(secs,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
			draw_string_outline(font,mid+Vector2(-w*0.5,size*0.36),secs,HORIZONTAL_ALIGNMENT_LEFT,-1,size,maxi(roundi(4*u),3),Color(0,0,0,0.7))
			draw_string(font,mid+Vector2(-w*0.5,size*0.36),secs,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color(1,1,1,0.97))
			draw_arc(area,r1+4*u,a0,a0+(a1-a0)*(1.0-left),24,color,3*u,true)
		if _was_cooling.get(ability,false) and left<=0.0:
			_ready_ring[ability]=1.0 # his ready ring: cooled down, it flies out
		_was_cooling[ability]=left>0.0
		var ready: float=float(_ready_ring.get(ability,0.0))
		if ready>0.0:
			var grow := (1.0-ready)*10*u
			draw_arc(area,r1+4*u+grow,a0,a1,24,Color(color.lightened(0.4),ready),2*u+3*u*ready,true)
## merge-fix: his thumb area in the buttons' look (button_look.gd): a glass body with a gold metal rim and a hand symbol;
## by direction, each flick's act at its edge with a small arrow pointing out. Drawn only with Settings.thumb_controls.
func _draw_thumb_area(u: float) -> void:
	var area: Vector2=centres().hand
	var r := ACT_RADIUS*u
	var held := pointers.values().any(func(g) -> bool: return g.role=="act")
	Look.blob(self,area+Vector2(0,r*0.08),Vector2.ONE*r*1.22,Color(0,0,0,0.32))
	draw_circle(area,r,Color(0.05,0.06,0.09,0.42),true,-1,true)
	Look.blob(self,area+Vector2(0,r*0.1),Vector2.ONE*r*0.95,Color(1.0,0.78,0.42,0.2+(0.18 if held else 0.0)))
	Look.blob(self,area-Vector2(0,r*0.52),Vector2(r*0.66,r*0.32),Color(1,1,1,0.12))
	draw_arc(area,r+4*u,0,TAU,96,Color(0,0,0,0.5),2*u,true)
	Look.metal_ring(self,area,r,6*u,Color(1.0,0.93,0.66),Color(0.5,0.31,0.1))
	draw_arc(area,r-3.5*u,0,TAU,96,Color(0.15,0.08,0.02,0.55),1.5*u,true)
	draw_arc(area,r+2.4*u,PI*1.08,PI*1.62,24,Color(1,1,1,0.45),1.2*u,true)
	var icon_at := area+Vector2(0,-6)*u
	Look.hand(self,icon_at+Vector2(0,3)*u,24*u,Color(0,0,0,0.45))
	Look.hand(self,icon_at,24*u,Color(INK,0.92))
	if Gesture.by_direction:
		var striking := TapRule.strikes_while(driver.load_kind())
		var font_dir := get_theme_default_font()
		for mark: Array in [[Vector2(0,-1),"Hit",striking],[Vector2(1,0),"Heavy",striking],[Vector2(-1,0),"Parry",true],[Vector2(0,1),"Shove",true]]:
			var dir: Vector2=mark[0]
			var on: bool=mark[2]
			var at := area+dir*(r-30*u)
			var side := Vector2(-dir.y,dir.x)
			var tip := area+dir*(r-10*u)
			draw_colored_polygon(PackedVector2Array([tip,tip-dir*8*u+side*7*u,tip-dir*8*u-side*7*u]),Color(1.0,0.82,0.42,0.9 if on else 0.3))
			var size := roundi(15*u)
			var w := font_dir.get_string_size(mark[1],HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
			var p := at+Vector2(-w*0.5,size*0.36)-dir*Vector2(w*0.35,0).abs()*absf(dir.x)
			draw_string_outline(font_dir,p,mark[1],HORIZONTAL_ALIGNMENT_LEFT,-1,size,maxi(roundi(4*u),3),Color(0,0,0,0.6))
			draw_string(font_dir,p,mark[1],HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color(INK,0.95 if on else 0.35))
	elif words:
		_pill(area+Vector2(0,44)*u,"Hand",INK,14)
## Slice 4's board check: for each control's words, screen points that show only its backing (the pill's inner
## edge, or the arc band away from its name), and the ink drawn on it. The probe samples the rendered pixels there.
## The screen space the controls and their words take, for speech.gd's bubbles to keep clear of.
func occupied_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if not is_visible_in_tree():
		return out
	var u := unit()
	if scheme=="act":
		var area := arc_centre()
		var reach := arc_outer()+4*u
		out.append(Rect2(area-Vector2(reach,reach),Vector2(reach,reach)*2.0))
	else:
		var places := surfaces()
		for role: String in places:
			var radius: float=radius_of(role)*u
			out.append(Rect2(places[role]-Vector2(radius,radius),Vector2(radius,radius)*2.0))
	if words and scheme=="act":
		out.append(_pill_rect(hint_at(),_hint_words,19))
		out.append(_pill_rect(stick_hint_at(),STICK_WORDS,15))
	return out
func label_boxes() -> Array:
	var out := []
	if scheme!="act" or not words:
		return out
	var u := unit()
	var pills := {"hint":[hint_at(),_hint_words,19],"stick":[stick_hint_at(),STICK_WORDS,15]}
	for name: String in pills:
		var rect := _pill_rect(pills[name][0],pills[name][1],pills[name][2]).grow(-1.5)
		var samples := PackedVector2Array()
		var x := rect.position.x
		while x<=rect.end.x:
			samples.append_array([Vector2(x,rect.position.y),Vector2(x,rect.end.y)])
			x+=3
		out.append({"name":name,"ink":INK,"samples":samples})
	var area := arc_centre()
	var arc := arcs()
	for role: String in arc:
		var samples := PackedVector2Array()
		for i in 13:
			var angle: float=lerpf(arc[role].x+0.04,arc[role].y-0.04,i/12.0)
			for radius: float in [arc_inner()+5*u,arc_outer()-5*u]:
				samples.append(area+Vector2.from_angle(angle)*radius)
		out.append({"name":role,"ink":INK,"samples":samples})
	return out
