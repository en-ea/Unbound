extends RefCounted
## B3 slice 1: the one thumb area's classifier, as a table of finger paths (pure, headless).
## B3 slice 3: the left stick's flick (dodge), tap (crouch) and the sharp turn, as the same kind of table.
## B3 slice 5: the contact buzz grows with the accepted force; the lean reads the blow's force while it is aimed.
## Combined motions: what one tap is where several acts are in reach (TapRule), and the flick while carrying.
##   godot --headless --path game --script res://scripts/studio/run.gd -- player/act_gesture_test
const Gesture := preload("res://scripts/studio/player/gesture.gd")
const Stick := preload("res://scripts/studio/player/stick_gesture.gd")
const Feel := preload("res://scripts/studio/player/contact_feel.gd")
const TapRule := preload("res://scripts/studio/player/tap_rule.gd")
const Brush := preload("res://scripts/studio/people/contacts/brush.gd")
const FRAME := 1.0/60.0
static func check(ok: bool,words: String) -> String:
	return ("PASS " if ok else "FAIL ")+words
## path: [[seconds to wait, dx, dy], ...] in viewport px (each row ticks, then moves by dx,dy unless both are 0).
static func play(path: Array,viewport := Vector2(1560,720)) -> RefCounted:
	var g := Gesture.new()
	g.begin(4,"act",Vector2(1300,500),viewport,{"target":-2,"press_id":"table"})
	var at := Vector2(1300,500)
	for row: Array in path:
		g.tick(float(row[0]))
		var step := Vector2(float(row[1]),float(row[2]))
		if step!=Vector2.ZERO:
			g.drag(4,at+step,step)
			at+=step
	return g
## The same path rows for the stick finger, landing at (220,540); returns what its lift asks for.
static func stick(path: Array,viewport := Vector2(1560,720)) -> Dictionary:
	var g := Stick.new()
	g.begin(4,Vector2(220,540),viewport)
	var at := Vector2(220,540)
	for row: Array in path:
		g.tick(float(row[0]))
		var step := Vector2(float(row[1]),float(row[2]))
		if step!=Vector2.ZERO:
			at+=step
			g.drag(4,at)
	return g.release(4)
static func steady(frames: int,dx: float,dy: float) -> Array:
	var rows := []
	for _i in frames:
		rows.append([FRAME,dx,dy])
	return rows
static func report() -> PackedStringArray:
	var out := PackedStringArray()
	var g := play([[0.1,0,0]])
	out.append(check(g.release(4)=="use","still tap uses what is in front"))
	g=play([[0.3,0,0]])
	out.append(check(g.intent=="guard" and g.release(4)=="guard","still hold guards"))
	g=play([[0.02,60,0]])
	out.append(check(g.intent=="heavy" and g.flick_force()==1000 and g.release(4)=="heavy","sharp one-frame flick is the heavy blow at full force"))
	g=play(steady(3,0,-15))
	out.append(check(g.intent=="strike" and g.flick_force()>300 and g.flick_force()<500,"three-frame flick (900 px/s) strikes lightly: %.0f px/s force %d" % [g.speed,g.flick_force()]))
	g=play(steady(10,4,0))
	out.append(check(g.intent=="shove" and g.release(4)=="shove","slow push (240 px/s) shoves: %.0f" % g.speed))
	g=play(steady(10,0,4))
	out.append(check(g.release(4)=="shove","a slow push toward the camera is still a shove, never a grab"))
	g=play([[0.2,0,0],[FRAME,40,0]])
	out.append(check(g.intent=="strike","rest under the hold time, then a flick, still strikes"))
	g=play(steady(3,0,-15)+[[0.5,0,0]])
	out.append(check(g.release(4)=="strike","a light flick held on stays light: force is speed, not waiting"))
	var forces := []
	for px: float in [10.0,20.0,30.0,40.0,80.0]: # Three frames at 1/60 s: 600, 1200, 1800, 2400, 4800 px/s.
		forces.append(play(steady(3,0,-px)).flick_force())
	out.append(check(forces[0]<forces[1] and forces[1]<forces[2] and forces[2]<forces[3] and forces[3]==1000 and forces[4]==1000,"force rises with flick speed and caps: %s" % str(forces)))
	g=play(steady(3,0,-30))
	out.append(check(g.intent=="heavy" and g.flick_force()>=Gesture.HEAVY_FORCE,"a 1800 px/s flick crosses the knock-down force: %d" % g.flick_force()))
	g=play(steady(10,4,0)+[[0.5,0,0]])
	out.append(check(g.release(4)=="shove","a held push stays a shove, never heavy"))
	g=play([[0.02,60,0],[FRAME,-55,0]])
	out.append(check(g.cancelled and g.release(4)=="cancel","flick returned to the start cancels"))
	g=play([[0.1,10,0]])
	out.append(check(g.release(4)=="use","small drift on a tap still uses"))
	g=play(steady(10,6,0),Vector2(2340,1080))
	out.append(check(g.intent=="shove","phone-size slow push (unit 1.5) shoves: %.0f" % g.speed))
	g=play([[0.02,90,0]],Vector2(2340,1080))
	out.append(check(g.intent in ["strike","heavy"],"phone-size flick strikes"))
	g=play(steady(3,0,-22.5),Vector2(2340,1080))
	out.append(check(g.flick_force()==play(steady(3,0,-15)).flick_force(),"the same thumb motion has the same force at phone size (unit 1.5)"))
	g=play([[0.3,0,0],[0.02,60,0]])
	out.append(check(g.release(4)=="guard","a guard already held does not turn into a strike"))
	g=play([])
	out.append(check(not g.drag(5,Vector2(1360,500),Vector2(60,0)),"another finger cannot move this stroke"))
	out.append_array(stick_report())
	out.append_array(tap_report())
	out.append_array(brush_report())
	var light := Feel.buzz(300)
	var heavy := Feel.buzz(1000)
	out.append(check(light.x<heavy.x and light.y<heavy.y and heavy.x<=90 and light.x>=25,"feel: a light blow buzzes shorter and softer than a heavy one (%s / %s)" % [str(light),str(heavy)]))
	out.append(check(Feel.buzz(-50)==Feel.buzz(0) and Feel.buzz(5000)==heavy,"feel: force outside 0..1000 is clamped"))
	return out
static func stick_report() -> PackedStringArray:
	var out := PackedStringArray()
	out.append(check(stick([[0.1,0,0]]).get("verb","")=="crouch","stick: a still tap on its base crouches or stands"))
	out.append(check(stick([[0.05,4,0],[0.05,4,0]]).get("verb","")=="crouch","stick: a tap with 8 px drift still crouches"))
	var a := stick(steady(3,25,0))
	out.append(check(a.get("verb","")=="dodge" and a.offset.x>70,"stick: a quick flick right (1500 px/s) dodges right"))
	a=stick(steady(3,0,-25))
	out.append(check(a.get("verb","")=="dodge" and a.offset.y<-70,"stick: a quick flick up dodges away from the camera"))
	out.append(check(stick([[1.0/30,25,0],[1.0/30,25,0],[1.0/30,25,0]]).get("verb","")=="dodge","stick: the same flick at 30 fps (750 px/s) dodges"))
	out.append(check(stick(steady(9,6,0)).is_empty(),"stick: a slow short walk lifted at once (360 px/s) is not a dodge"))
	out.append(check(stick([[0.3,0,0]]).is_empty(),"stick: a still rest longer than a tap does nothing"))
	out.append(check(stick(steady(3,25,0)+[[0.4,0,0]]).is_empty(),"stick: a fast start held on is a run, not a dodge"))
	out.append(check(stick(steady(6,12,0)+[[0.5,0,0]]+steady(4,-36,0)).is_empty(),"stick: SHARP TURN - walking right, a quick reversal left turns, never dodges"))
	out.append(check(stick(steady(20,4,0)+[[0.3,0,0]]+steady(3,-50,0)).is_empty(),"stick: SHARP TURN - a slow walk then a fast reversal lifted at once still only turns"))
	out.append(check(stick(steady(3,37.5,0),Vector2(2340,1080)).get("verb","")=="dodge","stick: phone-size quick flick (unit 1.5) dodges"))
	out.append(check(stick([[0.1,12,0]],Vector2(2340,1080)).get("verb","")=="crouch","stick: phone-size tap with 12 px drift (8 unit px) crouches"))
	var g := Stick.new()
	g.begin(4,Vector2(220,540),Vector2(1560,720))
	g.drag(5,Vector2(300,540))
	out.append(check(g.release(4).get("verb","")=="crouch","stick: another finger cannot move this stroke"))
	return out
## What one tap does where several acts are in reach: urgent (put out, emerge, get off, takedown) first, then picking
## up or setting down, then a village action, then talk and stations, then gathering.
static func tap_report() -> PackedStringArray:
	var out := PackedStringArray()
	var burning := {"kind":"extinguish","id":3,"verb":"Put out"}
	var talk := {"kind":"station","verb":"Talk"}
	var free := {"kind":"station","verb":"Free"}
	var lift := {"kind":"person","id":5,"verb":"Lift"}
	var lower := {"kind":"lower","verb":"Lower"}
	var none := {"kind":"empty","verb":"Grip"}
	var rows := [
		[{"extinguish":burning,"station":talk},none,"use","Put out","a burning one beside someone to talk to: the tap puts out"],
		[{"extinguish":burning},lift,"use","Put out","a burning one beside a downed one: the tap puts out, not lifts"],
		[{"extinguish":burning,"village_station":free},none,"use","Put out","a burning one beside the pillory: put out before Free"],
		[{"erupt":{"kind":"erupt","verb":"Emerge"},"station":talk},lift,"use","Emerge","burrowed: the tap comes up, whatever is near"],
		[{"get_off":{"kind":"get_off","verb":"Get off"},"station":talk},none,"use","Get off","riding past someone to talk to: the tap gets off"],
		[{"takedown":{"kind":"takedown","verb":"Takedown"},"station":talk},none,"use","Takedown","a downed foe beside a talk spot: the tap finishes"],
		[{"takedown":{"kind":"takedown","verb":"Takedown"}},lift,"use","Takedown","a downed foe beside a downed villager: takedown first"],
		[{"village_station":free},lift,"grip","Lift","the pillory beside a downed one: the tap lifts"],
		[{"station":talk},lift,"grip","Lift","someone to talk to beside a downed one: the tap lifts"],
		[{"station":talk,"lower":lower},lower,"grip","Lower","carrying, beside someone to talk to: the tap sets the load down"],
		[{"station":talk,"gather":{"kind":"gather","verb":"Chop"}},none,"use","Talk","someone to talk to beside a tree: the tap talks"],
		[{"gather":{"kind":"gather","verb":"Chop"}},none,"use","Chop","only a tree: the tap gathers"],
		[{},none,"use","Use","nothing in reach: the tap is a plain Use"],
	]
	for row: Array in rows:
		var t := TapRule.tap(row[0],row[1])
		out.append(check(str(t.tap)==str(row[2]) and str(t.context.verb)==str(row[3]),"tap: %s (%s %s)" % [row[4],t.tap,t.context.verb]))
	out.append(check(str(TapRule.use_of({"get_off":{"kind":"get_off","verb":"Get off"},"station":talk}).verb)=="Get off","tap: the discs' Hand keeps the same order (riding beside a talk spot gets off)"))
	out.append(check(TapRule.strikes_while("") and not TapRule.strikes_while("carcass") and not TapRule.strikes_while("person"),"carrying a carcass or a person, a flick does not strike; empty-handed it does"))
	out.append(check(TapRule.hint("Lower","carcass")=="Lower / push shove" and TapRule.hint("Use","")=="Use / flick strike / push shove","the hint offers only what the stroke can do with the load"))
	out.append(check(play(steady(3,0,-15)).release(4)=="strike" and play([[0.1,0,0]]).release(4)=="use","the stroke, not what is in reach, chooses strike or tap: a flick beside a burning one still strikes"))
	return out
## Walking contact (people/contacts/brush.gd): a touch, a stumble, a barge, a held push.
static func brush_report() -> PackedStringArray:
	var out := PackedStringArray()
	var b := Brush.new()
	var touch := func(closing: float,how := "walk",age := 0.0) -> Dictionary: return b.measure({"closing":closing,"how":how},{"age":age},FRAME)
	var slow: Dictionary=touch.call(0.5)
	out.append(check(not slow.has("stumble") and not slow.has("verb") and int(slow.cue_force)<300,"brush: drifting into someone (0.5 m/s) only rocks their shoulders"))
	var walk: Dictionary=touch.call(1.6)
	out.append(check(absf(float(walk.get("stumble",0))-0.32)<0.01 and not walk.has("verb"),"brush: walking into someone (1.6 m/s) makes them stumble %.2f m, no checked shove" % float(walk.get("stumble",0))))
	var run: Dictionary=touch.call(5.4)
	out.append(check(float(run.get("stumble",0))==0.6 and str(run.get("verb",""))=="shove","brush: running into someone (5.4 m/s) knocks them 0.6 m and asks for the checked shove"))
	var push: Dictionary=touch.call(0.5,"push")
	out.append(check(str(push.get("verb",""))=="shove","brush: a held push into someone asks for the checked shove at once"))
	var pressed: Dictionary=touch.call(0.0,"push",0.7)
	out.append(check(float(pressed.get("stumble",0))==0.4,"brush: pressed against someone with the push held, they give ground (0.4 m)"))
	out.append(check(not touch.call(0.0,"walk",0.7).has("stumble"),"brush: standing against someone without pushing moves nobody"))
	return out
