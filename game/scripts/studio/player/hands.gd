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
const ARC_FROM := -150.0
const ARC_TO := -30.0
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
		var area := hand+Vector2(-55,25)*unit()
		var arc := arcs()
		for role: String in arc:
			out[role]=area+Vector2.from_angle((arc[role].x+arc[role].y)*0.5)*(ACT_RADIUS+ARC_GAP+ARC_BAND*0.5)*unit()
		out.act=area # Last, so the powers win where the thumb area meets them.
		return out
	for i in list.size():
		out["power:"+str(list[i])]=hand+Vector2(-77+(i-(list.size()-1)/2.0)*92,-145)*unit()
	return out
## Slice 4: each power's sector of the band above the thumb area, as Vector2(from, to) in radians.
func arcs() -> Dictionary:
	var list := Classes.abilities()
	var out := {}
	if list.is_empty():
		return out
	var width := (ARC_TO-ARC_FROM-ARC_SPLIT*(list.size()-1))/list.size()
	for i in list.size():
		var start := ARC_FROM+i*(width+ARC_SPLIT)
		out["power:"+str(list[i])]=Vector2(deg_to_rad(start),deg_to_rad(start+width))
	return out
func radius_of(role: String) -> float:
	return ACT_RADIUS if role=="act" else 68.0 if role=="hand" else 36.0
func role_at(at: Vector2) -> String:
	if scheme=="act":
		var area: Vector2=surfaces().act
		var reach := at.distance_to(area)/unit()
		if reach>=ACT_RADIUS+ARC_GAP*0.5 and reach<=ACT_RADIUS+ARC_GAP+ARC_BAND+6:
			var angle := (at-area).angle()
			var arc := arcs()
			for role: String in arc:
				if angle>=arc[role].x-0.03 and angle<=arc[role].y+0.03:
					return role
		return "act" if reach<=ACT_RADIUS else ""
	for role: String in surfaces():
		if at.distance_to(surfaces()[role])<=radius_of(role)*unit():
			return role
	return ""
func covers(at: Vector2) -> bool:
	return is_visible_in_tree() and role_at(at)!=""
func _input(event: InputEvent) -> void:
	if Controls.locked or VillageSession.background or not is_visible_in_tree():
		cancel() # A queued release cannot commit before the next inactive process frame.
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed and pointers.has(touch.index):
			var gesture= pointers[touch.index]
			var intent: String=gesture.release(touch.index)
			if gesture.role=="act" and intent=="use":
				intent=str(gesture.target.get("tap","use"))
			_live_end(touch.index)
			if intent!="cancel":
				var strength := clampf(gesture.offset.length()/(80*unit()),0,1)
				if gesture.role=="act" and intent in ["strike","heavy"]:
					gesture.target.force=gesture.flick_force() # Slice 2: the flick's speed is the blow's force.
					strength=gesture.flick_force()/1000.0
				var released: Dictionary=gesture.target.duplicate()
				released.merge({"verb":intent,"phase":"released","strength":strength},true)
				intent_changed.emit(released) # Physical release cue, not an accepted fact/assault.
				driver.commit(intent,gesture.target,strength,gesture.offset)
				_feel_for(intent,gesture.target)
			pointers.erase(touch.index)
			get_viewport().set_input_as_handled()
			queue_redraw()
		elif touch.pressed and not Controls.locked and is_visible_in_tree():
			var role := role_at(touch.position)
			if role=="" or pointers.values().any(func(g) -> bool: return g.role==role):
				return
			var gesture := Gesture.new()
			gesture.begin(touch.index,role,touch.position,get_viewport().get_visible_rect().size,driver.capture(role))
			gesture.target.scale=unit()
			pointers[touch.index]=gesture
			get_viewport().set_input_as_handled()
			queue_redraw()
	elif event is InputEventScreenDrag and pointers.has(event.index):
		var gesture=pointers[event.index]
		if gesture.drag(event.index,event.position,event.relative):
			if gesture.armed and not gesture.cancelled and gesture.intent in ["strike","heavy","shove"]:
				driver.aim_target(gesture.target,driver.direction(gesture.offset,gesture.target.yaw))
			elif gesture.role.begins_with("power:") and not gesture.cancelled and gesture.armed:
				gesture.target.forward=driver.direction(gesture.offset,gesture.target.yaw)
			get_viewport().set_input_as_handled()
			queue_redraw()
func _process(dt: float) -> void:
	var stick: Dictionary=Controls.stick_act # Read once; an inactive frame drops it.
	Controls.stick_act={}
	if Controls.locked or not is_visible_in_tree() or VillageSession.background:
		cancel()
		return
	if scheme=="act" and not stick.is_empty():
		feet(stick)
	driver.pushing=pointers.values().any(func(g) -> bool: return g.role=="act" and g.intent=="shove" and not g.cancelled)
	driver.step(dt)
	if VillageSession.village!=null:
		feel.step(VillageSession.village,People.tick(VillageSession.village))
	intent_changed.emit(preview())
	for finger: int in pointers:
		var gesture=pointers[finger]
		gesture.tick(dt)
		if gesture.intent in ["guard","crouch"] and not gesture.cancelled and not _live.has(finger):
			_live[finger]=gesture.intent
			driver.live(gesture.intent,true)
		if gesture.cancelled:
			_live_end(finger)
	queue_redraw()
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
		if gesture.role=="act" and gesture.armed and gesture.intent in ["strike","heavy"]:
			strength=gesture.flick_force()/1000.0 # Slice 5: the lean shows the blow's force while it is aimed.
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
	if ringed!=null and view_camera!=null: # Slice 5: on the ground under the person the act will reach.
		_ring(view_camera,ringed.global_position,0.6,Color(0.05,0.04,0.03,0.7))
		_ring(view_camera,ringed.global_position,0.55,Color(1,0.62,0.42) if pointers.values().any(func(g) -> bool: return g.intent in ["strike","heavy","shove"]) else INK)
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
		elif intent in ["strike","heavy","shove"]:
			tint=Color(1,0.62,0.42) # Slice 4: light enough to keep 4.5 contrast on the backing.
			preview+=" "+str(gesture.target.get("label","air"))
			var res := preload("res://scripts/studio/village/contact.gd").registry(get_tree())
			var body: Node3D=gesture.target.get("native")
			if res!=null and int(gesture.target.target)>=0:
				body=res.bodies.get(int(gesture.target.target))
			preview+=_target_feedback(body,2.8 if intent=="heavy" else 2.2,tint)
		if gesture.role.begins_with("power:") and gesture.armed:
			var camera := get_viewport().get_camera_3d()
			var ability: String=gesture.role.trim_prefix("power:")
			var point: Vector3=driver.aim_point(gesture.target,gesture.offset)
			preview=str(Classes.ABILITIES[ability]["short"])+" / release"
			if camera!=null:
				if ability=="meteor":
					_ring(camera,point,player.abilities._meteor_radius(),Classes.color())
				elif ability=="cinderburst":
					_ring(camera,player.global_position,6.0*(1.4 if Classes.has_talent("wide_ring") else 1.0),Classes.color())
				elif ability=="flame_dash":
					var forward: Vector3=gesture.target.get("forward",Vector3.FORWARD)
					_ring(camera,player.global_position+forward*7.5,1.7,Classes.color())
		draw_line(gesture.origin,gesture.origin+gesture.offset,tint,4*u,true)
		draw_circle(gesture.origin+gesture.offset,9*u,tint,true,-1,true)
		if gesture.armed:
			if scheme=="act":
				if words:
					_pill(gesture.origin+Vector2(0,-95)*u,"Return to cancel",tint,14)
			else:
				_text(gesture.origin+Vector2(0,-95)*u,"Return to cancel",tint,14)
		break
	if preview=="" and scheme=="act":
		preview=TapRule.hint(str(driver.tap_context().context.get("verb","Use")),driver.load_kind())
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
	if scheme=="act":
		return surfaces().act-Vector2(110,ACT_RADIUS+ARC_GAP+ARC_BAND+30)*unit() # merge-fix: left, clear of the Bow button
	return centres().hand+Vector2(-77,-200)*unit()
func stick_hint_at() -> Vector2:
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
## Slice 4 (act): the thumb area and the power arcs above it. merge-fix: drawn in the buttons' look (button_look.gd):
## a glass body with a gold metal rim and a hand symbol; each power a glassy band in the class colour with its
## symbol, a dark shade over the cooldown still to wait (and the seconds), and a soft glow once it's ready.
func _draw_act(u: float) -> void:
	var area: Vector2=surfaces().act
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
	if words:
		_pill(area+Vector2(0,44)*u,"Hand",INK,14)
	var arc := arcs()
	var r0 := (ACT_RADIUS+ARC_GAP)*u
	var r1 := r0+ARC_BAND*u
	var font := get_theme_default_font()
	for role: String in arc:
		var a0: float=arc[role].x
		var a1: float=arc[role].y
		var color := Classes.color()
		var ability := role.trim_prefix("power:")
		var dragging: bool=ability=="burrow" and player.burrowed()
		var left := 0.0 if dragging else Classes.cooldown_left(ability)
		var mid := area+Vector2.from_angle((a0+a1)*0.5)*(r0+r1)*0.5
		if left<=0.0:   # ready: a soft glow in the class colour, beating
			var beat := 0.5+0.5*sin(Time.get_ticks_msec()*0.004)
			Look.blob(self,mid,Vector2.ONE*ARC_BAND*u*(0.95+0.08*beat),Color(color,0.22+0.14*beat))
		var points := PackedVector2Array()
		var tints := PackedColorArray()
		for i in 17:   # the outer edge lit, the inner one deep
			points.append(area+Vector2.from_angle(lerpf(a0,a1,i/16.0))*r1)
			tints.append(Color(color.darkened(0.35),0.85))
		for i in range(16,-1,-1):
			points.append(area+Vector2.from_angle(lerpf(a0,a1,i/16.0))*r0)
			tints.append(Color(0.05,0.05,0.08,0.88))
		draw_polygon(points,tints)
		if left>0.0:   # the part still cooling, shaded from the end back
			var shade := PackedVector2Array()
			var from := a0+(a1-a0)*(1.0-left)
			for i in 9:
				shade.append(area+Vector2.from_angle(lerpf(from,a1,i/8.0))*r1)
			for i in range(8,-1,-1):
				shade.append(area+Vector2.from_angle(lerpf(from,a1,i/8.0))*r0)
			draw_colored_polygon(shade,Color(0.01,0.02,0.04,0.6))
		points.append(points[0])
		draw_polyline(points,Color(0,0,0,0.5),3.5*u,true)
		draw_polyline(points,Color(color.lightened(0.4),0.9 if left<=0.0 else 0.5),1.6*u,true)
		var ink := Color(INK,1.0 if left<=0.0 else 0.4)
		if dragging:
			_text(mid+Vector2(0,6)*u,"Drag" if not player.abilities.delver.dragged_this_dive else "Used",INK,16)
		else:
			AbilityIcons.draw(self,ability,mid+Vector2(0,2)*u,17*u,Color(0,0,0,0.45*ink.a),Color(0.05,0.06,0.09))
			AbilityIcons.draw(self,ability,mid,17*u,ink,Color(0.05,0.06,0.09))
		if left>0.0:
			var secs := str(ceili(left*Classes.cooldown_of(ability)))
			var size := roundi(20*u)
			var w := font.get_string_size(secs,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
			draw_string_outline(font,mid+Vector2(-w*0.5,size*0.36),secs,HORIZONTAL_ALIGNMENT_LEFT,-1,size,maxi(roundi(4*u),3),Color(0,0,0,0.7))
			draw_string(font,mid+Vector2(-w*0.5,size*0.36),secs,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color(1,1,1,0.97))
		draw_arc(area,r1+4*u,a0,a0+(a1-a0)*(1.0-left),24,Color(color.lightened(0.2),0.95),3*u,true)
## Slice 4's board check: for each control's words, screen points that show only its backing (the pill's inner
## edge, or the arc band away from its name), and the ink drawn on it. The probe samples the rendered pixels there.
## The screen space the controls and their words take, for speech.gd's bubbles to keep clear of.
func occupied_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if not is_visible_in_tree():
		return out
	var u := unit()
	if scheme=="act":
		var area: Vector2=surfaces().act
		var reach := (ACT_RADIUS+ARC_GAP+ARC_BAND)*u
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
	var pills := {"hand":[surfaces().act+Vector2(0,6)*u,"Hand",16],"hint":[hint_at(),_hint_words,19],
		"stick":[stick_hint_at(),STICK_WORDS,15]}
	for name: String in pills:
		var rect := _pill_rect(pills[name][0],pills[name][1],pills[name][2]).grow(-1.5)
		var samples := PackedVector2Array()
		var x := rect.position.x
		while x<=rect.end.x:
			samples.append_array([Vector2(x,rect.position.y),Vector2(x,rect.end.y)])
			x+=3
		out.append({"name":name,"ink":INK,"samples":samples})
	var area: Vector2=surfaces().act
	var arc := arcs()
	for role: String in arc:
		var samples := PackedVector2Array()
		for i in 13:
			var angle: float=lerpf(arc[role].x+0.04,arc[role].y-0.04,i/12.0)
			for radius: float in [ACT_RADIUS+ARC_GAP+5,ACT_RADIUS+ARC_GAP+ARC_BAND-5]:
				samples.append(area+Vector2.from_angle(angle)*radius*u)
		out.append({"name":role,"ink":INK,"samples":samples})
	return out
