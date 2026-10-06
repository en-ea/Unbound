extends RefCounted
## Release gate (PHONE-DELIVERY-RULES rule 7): Hilmi's actual phone saves, never generated ones, must load,
## upgrade, take a new action, decay, accept a gift and reload with accepted history intact.
## Fixtures are the preserved owner saves under the studio evidence folder, passed as --owner-saves=a.json;b.json
## so the owner's data never enters the game repository.
const People := preload("res://scripts/studio/village/sim/people.gd")
const Codec := preload("res://scripts/studio/village/sim/save.gd")
const P := preload("res://scripts/studio/people/perception.gd")
const Accept := preload("res://scripts/studio/village/acceptance.gd")
const Actions := preload("res://scripts/studio/village/sim/people_actions.gd")
const Journal := preload("res://scripts/studio/village/journal.gd")
const VillageImage := preload("res://scripts/studio/village/sim/image.gd")
const SafeFile := preload("res://scripts/core/safe_file.gd")
static func check(out: PackedStringArray, ok: bool, description: String) -> void:
	out.append(("PASS" if ok else "FAIL")+" owner-save "+description)
static func report() -> PackedStringArray:
	var out := PackedStringArray()
	var paths := []
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--owner-saves="):paths=Array(arg.trim_prefix("--owner-saves=").split(";",false))
	check(out,paths.size()>=1,"fixtures supplied (%d)" % paths.size())
	for path: String in paths:_one(out,path)
	return out
static func _legacy(v) -> int:
	var n := 0
	for p in v.people:
		for r: Variant in p.mind.appraised.values():
			if not (r is Dictionary and r.get("stance",{}) is Dictionary and r.has("revision")):n+=1
	return n
static func _one(out: PackedStringArray, path: String) -> void:
	var name := path.get_base_dir().get_file()+"/"+path.get_file()
	var text := FileAccess.get_file_as_string(path)
	var data: Variant=JSON.parse_string(text) if not text.is_empty() else null
	if not data is Dictionary or not data.get("village") is Dictionary:
		check(out,false,name+" readable");return
	var payload: Dictionary=data.village
	# Raw decode without the semantic upgrade, to measure what the upgrade must preserve.
	var raw = Codec._decode(payload)
	var before := _legacy(raw)
	var stances := [];var known := [];var episodes := [];var affect := []
	for p in raw.people:
		stances.append(p.mind.stances.duplicate(true));known.append(_gist(p.mind.known))
		episodes.append(p.mind.episodes.map(func(e)->String:return e.key+"@"+str(e.tick)));affect.append(p.mind.affect.duplicate(true))
	var upgraded := People.upgrade(raw)
	var kept := true
	for i in raw.people.size():
		var m=raw.people[i].mind
		kept=kept and m.stances==stances[i] and _gist(m.known)==known[i] and m.affect==affect[i] and m.episodes.map(func(e)->String:return e.key+"@"+str(e.tick))==episodes[i]
	check(out,before>0 and upgraded>=before and _legacy(raw)==0 and People.invalid(raw)=="" and People.upgrade(raw)==0,
		"%s upgrades %d earlier receipts (%d records with accounts) once, leaving none unreadable" % [name,before,upgraded])
	check(out,kept,name+" keeps every stance total, hit count, account, episode and feeling unchanged")
	# The normal load door applies the same upgrade.
	var v = Codec.from_data(payload)
	check(out,v!=null and _legacy(v)==0 and People.invalid(v)=="",name+" loads through the normal codec already upgraded")
	if v==null:return
	# Every affected mind decays, settles and counts prior hits without touching a malformed record.
	var now := People.tick(v)+600000
	var affected := []
	for p in raw.people:
		for r: Dictionary in p.mind.appraised.values():
			if r.has("upgraded") and not affected.has(p.id):affected.append(p.id)
	for id: int in affected:
		var m=v.people[id].mind
		People.settle_stances(m,now)
		for who: String in m.stances:People.prior_hits(m,who,m.known.size())
	check(out,affected.size()>0 and People.invalid(v)=="","%s decays and settles all %d affected minds" % [name,affected.size()])
	# Re-learning an upgraded deed adds no hit; a new strike adds one; a gift softens without erasing.
	var id: int=affected[0]
	var old_fact := ""
	for candidate: int in affected:
		for fact: String in v.people[candidate].mind.appraised:
			var r: Dictionary=v.people[candidate].mind.appraised[fact]
			if old_fact.is_empty() and r.has("upgraded") and r.counted and str(r.stance.get("identity",""))=="player:local":id=candidate;old_fact=fact
	check(out,not old_fact.is_empty(),"%s has an upgraded strike by the player to re-learn (%s)" % [name,old_fact])
	if old_fact.is_empty():return
	var own := People.key(v,id)
	var m=v.people[id].mind
	var hits_before := _hits(m)
	var deed := old_fact.trim_suffix(":"+own)
	People.learn(v,_strike(own,own,deed,v),null,false)
	check(out,_hits(m)==hits_before and People.invalid(v)=="",name+" new evidence for an old deed charges no second hit")
	var strike := _strike(own,own,"owner-save:new-strike",v)
	People.learn(v,strike,null,false)
	var hit_once := _hits(m)==hits_before+1
	var angry := int(m.affect.anger)
	var gift := P.account(own,{"kind":"gift","source":"player:local","actor":"player:local","target":own,"at":[2.0,3.0],"strength":400,
		"evidence":{"act":"gift"},"features":{"assistance":220,"novelty":100},"deed":"owner-save:gift"},
		{"seen":true,"due":People.tick(v),"tick":People.tick(v),"gain":1.0},{"key":"player:local","name":"you"},"owner-save:gift:"+own)
	People.learn(v,gift,null,false)
	check(out,hit_once and int(m.affect.anger)<=angry and m.known.has("owner-save:new-strike:"+own) and m.known.has(old_fact),
		name+" a new strike counts once and a gift softens without erasing either deed")
	# Step 4: the v1 people rows ({"p","m"} per person) carry everything the readable form does.
	var packed := Codec.to_data(v,true)
	var unpacked = Codec.from_data(packed)
	check(out,packed.state.fields.people.get("v")==1 and unpacked!=null and JSON.stringify(Codec.to_data(unpacked,false))==JSON.stringify(Codec.to_data(v,false)),
		name+" v1 people rows reload to exactly the same village")
	_interrupt(out,name,v,id)
	# Reload keeps all of it, and the reloaded state is still valid for acceptance.
	var back = Codec.from_data(Codec.to_data(v,false))
	var bm=back.people[id].mind if back!=null else null
	check(out,bm!=null and bm.known.has("owner-save:new-strike:"+own) and bm.known.has(old_fact) and _hits(bm)==_hits(m) and bm.appraised==m.appraised and People.invalid(back)=="",
		name+" reload keeps old and new deeds, hits and receipts")
## What an account means to its owner: deed, how learned, who it names, what act. Shape may change, this may not.
static func _gist(known: Dictionary) -> Dictionary:
	var out := {}
	for fact: String in known:
		var a: Dictionary=known[fact]
		out[fact]=[str(a.get("deed","")),str(a.get("via","")),str(a.get("identity",{}).get("key","")),str(a.get("target","")),str(a.get("evidence",{}).get("act",""))]
	return out
static func _hits(m) -> int:
	return int(m.stances.get("player:local",{}).get("hits",0))
static func _strike(target: String, observer: String, deed: String, v) -> Dictionary:
	var record := {"kind":"contact","source":"player:local","actor":"player:local","target":target,"at":[2.0,3.0],"strength":480,"evidence":{"act":"strike"},
		"features":{"harm":480,"threat":480,"novelty":200},"deed":deed,"event_ref":"incident:opaque"}
	var measured := {"seen_event":true,"seen_actor":true,"seen_subject":true,"felt":true,"tick":People.tick(v),"captured_tick":People.tick(v),
		"occurred_tick":People.tick(v),"due":People.tick(v),"gain":1.0,"subject_identity":{"key":target,"name":"them"}}
	return P.account(observer,record,measured,{"key":"player:local","name":"you"},deed+":"+observer)
## Step 4 interruption (plan STEP4 section 3): on the real save, a strike and a later gift are accepted through the
## journal, the app "stops" with no checkpoint, the full save plus journal reload to exactly the live village, the same
## strike and gift sent again harm nobody twice, and a checkpoint built from data alone holds the same village.
static func _interrupt(out: PackedStringArray, name: String, v, id: int) -> void:
	var path := "user://studio-test-owner-save-interrupt.json"
	SafeFile.remove(path)
	if FileAccess.file_exists(path+".journal"):DirAccess.remove_absolute(path+".journal")
	var journal = Journal.new(path)
	var previous=VillageSession.village
	VillageSession.village=v
	VillageImage.guard=true
	var save_id := "owner-save-%d" % randi()
	var text := JSON.stringify({"version":1,"save_id":save_id,"village":Codec.to_data(v,true)})
	var written := SafeFile.write_text(path,text)
	journal.rebase(save_id,text)
	VillageImage.rebase(v,true)
	var writer := func()->int:return journal.append({"village":VillageImage.staged.line})
	var own := People.key(v,id)
	var request := {"action_id":"owner-save:interrupt-strike","actor":"player:local","target":own,"verb":"strike",
		"village_id":v.runtime.village,"logical_time":v.runtime.now,"parameters":{"damage":1}}
	var account := _strike(own,own,"owner-save:interrupt-strike",v)
	var strike := func(live)->Dictionary:
		var answer := Actions.prepare(live,request,{"authorized":true,"distance_dm":10})
		if answer.get("accepted",false) and not answer.get("duplicate",false):People.flush(live,[account.duplicate(true)])
		return answer
	var first: Dictionary=Accept.transact(strike,writer)
	var m=v.people[id].mind
	var hurt: int=v.people[id].hurt
	var hits := _hits(m)
	v.runtime.now=int(v.runtime.now)+120 # a minute of active time later: decay, then a gift
	var gift := P.account(own,{"kind":"gift","source":"player:local","actor":"player:local","target":own,"at":[2.0,3.0],"strength":400,
		"evidence":{"act":"gift"},"features":{"assistance":220,"novelty":100},"deed":"owner-save:interrupt-gift"},
		{"seen":true,"due":People.tick(v),"tick":People.tick(v),"gain":1.0},{"key":"player:local","name":"you"},"owner-save:interrupt-gift:"+own)
	var given: Dictionary=Accept.transact(func(live)->Dictionary:
		People.settle_stances(live.people[id].mind,People.tick(live))
		return {"accepted":People.learn(live,gift.duplicate(true),null,false)},writer)
	check(out,written==OK and first.get("accepted",false) and not first.get("duplicate",false) and given.get("accepted",false) and journal.seq==2 and hurt>0,
		"%s strike and later gift accepted as two journal lines (%d bytes)" % [name,journal.bytes])
	# The app stops here: no checkpoint. A restart reads the full save and the journal.
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var back=Codec.from_data(Journal.replay(data,path+".journal").village)
	var live_text := JSON.stringify(Codec.to_data(v,false))
	check(out,back!=null and JSON.stringify(Codec.to_data(back,false))==live_text,name+" full save plus journal reload to exactly the live village")
	if back==null:
		VillageSession.village=previous;VillageImage.guard=false;return
	VillageSession.village=back
	VillageImage.rebase(back,true)
	journal.rebase(save_id,text) # (the test's reload keeps the same disk files; nothing more is written below)
	var again: Dictionary=Accept.transact(strike,func()->int:return OK)
	var regift: Dictionary=Accept.transact(func(live)->Dictionary:return {"accepted":People.learn(live,gift.duplicate(true),null,false)},func()->int:return OK)
	var bm=back.people[id].mind
	check(out,again.get("duplicate",false) and not regift.get("accepted",false) and back.people[id].hurt==hurt and _hits(bm)==hits and bm.known.has("owner-save:interrupt-gift:"+own),
		"%s the same strike and gift sent again after the restart harm nobody twice (hurt %d, hits %d)" % [name,hurt,hits])
	# A checkpoint is built on a worker thread from the full save text and the journal lines only.
	VillageSession.village=v
	save_id += "-2"
	text=JSON.stringify({"version":1,"save_id":save_id,"village":Codec.to_data(v,true)})
	SafeFile.write_text(path,text)
	journal.rebase(save_id,text)
	VillageImage.rebase(v,true)
	v.runtime.now=int(v.runtime.now)+1
	var noted: Dictionary=Accept.transact(func(live)->Dictionary:
		live.people_facts["owner-save:checkpoint"]={"receipt":{"accepted":true}}
		return {"accepted":true},writer)
	journal.checkpoint()
	journal.wait()
	var held: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var built=Codec.from_data(held.village)
	check(out,noted.get("accepted",false) and journal.checkpoints==1 and int(held.get("journal_seq",0))==1 and not FileAccess.file_exists(path+".journal") and built!=null
		and JSON.stringify(Codec.to_data(built,false))==JSON.stringify(Codec.to_data(v,false)),name+" checkpoint built from data alone holds exactly the live village")
	VillageImage.guard=false
	VillageSession.village=previous
