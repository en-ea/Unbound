extends RefCounted
## B3 slice 5 (B6/E): a short vibration when a released act actually lands. Hands hands over each released act;
## this watches the checked receipt for that same press and cause (the deed key Contact writes), and buzzes once,
## longer and stronger with the accepted force. Nothing is felt for a miss, a refusal or a cancelled stroke.
## The phone decides whether it can vibrate (Input.vibrate_handheld is a no-op where it is not allowed).
const WATCH_MS := 1500 # Active ms to wait for the receipt: a heavy swing commits its contact about 0.5 s in.
var actor := ""
var watching: Array[Dictionary] = [] # {deed, verb, until}
var felt: Array[Dictionary] = [] # What was buzzed, newest last: {verb, force, ms, amplitude}. Read by the probe.
var enabled := true
## Duration (ms) and amplitude (0..1) for an accepted force 0..1000. Pure, so the table test can read it.
static func buzz(force: int) -> Vector2:
	var f := clampf(force/1000.0,0,1)
	return Vector2(roundi(lerpf(25,90,f)),lerpf(0.35,1.0,f))
## The deed key Contact gives an accepted act of this actor, press and verb on a person (people_facts key).
static func deed(actor_ref: String,press_id: String,verb: String,target_key: String) -> String:
	var key := JSON.stringify([actor_ref,press_id,verb])
	return "deed:"+JSON.stringify([key,target_key]).sha256_text().substr(0,32)
func watch(village,press_id: String,verb: String,target: int,now: int) -> void:
	if village==null or target<0 or target>=village.people.size() or press_id=="":
		return
	var key: String=preload("res://scripts/studio/village/sim/people.gd").key(village,target)
	watching.append({"deed":deed(actor,press_id,verb,key),"verb":verb,"until":now+WATCH_MS})
func step(village,now: int) -> void:
	if village==null:
		watching.clear()
		return
	for i in range(watching.size()-1,-1,-1):
		var w: Dictionary=watching[i]
		var receipt: Dictionary=village.people_facts.get(w.deed,{}).get("receipt",{})
		if receipt.get("accepted",false):
			var force := int(receipt.get("force",500))
			var feel := buzz(force)
			felt.append({"verb":w.verb,"force":force,"ms":int(feel.x),"amplitude":feel.y})
			if enabled:
				Input.vibrate_handheld(int(feel.x),feel.y)
			watching.remove_at(i)
		elif now>int(w.until):
			watching.remove_at(i)
