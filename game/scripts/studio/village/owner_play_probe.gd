extends Node
## Release gate (PHONE-DELIVERY-RULES rule 7): the normal live village booted from Hilmi's actual save
## (--test-save copy, never his real file). Nothing in his village is reset: a real Heavy lands on a resident whose
## memories came from the earlier release, witnesses process through the ordinary doors, then a checked save
## reloads. Any script error fails the job runner; this prints acceptance cost for the step-4 comparison.
const People := preload("res://scripts/studio/village/sim/people.gd")
const Codec := preload("res://scripts/studio/village/sim/save.gd")
const Accept := preload("res://scripts/studio/village/acceptance.gd")
const Journal := preload("res://scripts/studio/village/journal.gd")
const VillageImage := preload("res://scripts/studio/village/sim/image.gd")
var failed := 0
static func on_device(tree: SceneTree) -> void:
	if DisplayServer.get_name()=="headless":
		tree.root.get_node("ItemIcons").set_process(false)
	tree.root.add_child.call_deferred(load("res://scripts/studio/village/owner_play_probe.gd").new())
func _ready() -> void:
	run.call_deferred()
func frames(n: int) -> void:
	for _i in n:await get_tree().process_frame
func seconds(s: float) -> void:
	var start := People.tick(VillageSession.village)
	while People.tick(VillageSession.village)-start<roundi(s*1000):
		await get_tree().process_frame
func check(ok: bool, text: String) -> void:
	print(("PASS owner-play " if ok else "FAIL owner-play ")+text)
	if not ok:failed+=1
func run() -> void:
	await frames(180)
	var live: Node=null
	for _i in 1200:
		live=get_tree().current_scene.get_node_or_null("VillageLive") if get_tree().current_scene!=null else null
		if live!=null:break
		await get_tree().process_frame
	print("OWNER PLAY scene=%s region=%s living=%s active=%s village=%s" % [get_tree().current_scene.name if get_tree().current_scene!=null else "none",
		Region.current,str(Settings.living_village),str(VillageSession.active),str(VillageSession.village!=null)])
	var player: Node3D=get_tree().get_first_node_in_group("player")
	var v=VillageSession.village
	check(live!=null and v!=null and player!=null,"owner save boots the live village")
	if live==null or v==null or player==null:
		print("OWNER PLAY complete failures=%d" % failed);get_tree().quit(1);return
	var res=live.registry
	while not res.all_built():await get_tree().process_frame
	check(People.invalid(v)=="","loaded people state is readable by every consumer")
	# The resident with the most upgraded receipts, alive and present, stands in front of the player.
	var target := -1;var most := 0
	for p in v.people:
		var n := 0
		for r: Dictionary in p.mind.appraised.values():if r.has("upgraded"):n+=1
		if p.alive and p.present and not p.locked and n>most and res._movers.has(p.id):target=p.id;most=n
	check(target>=0,"no recovery fallback: a present resident carries earlier-release memories (%d receipts)" % most)
	if target<0:
		print("OWNER PLAY complete failures=%d" % failed);get_tree().quit(1);return
	var known := int(v.people[target].mind.known.size())
	var front := Vector2(player.global_position.x,player.global_position.z+1.6)
	# Same placement door as the encounter fixture: the daily routine must not walk the target off before the blow.
	res._leave_situation(target)
	res._drop_stay(target)
	res.owners.claim(target,"cast",2)
	res.destinations.erase(target)
	res._movers[target].indoors=false
	res._movers[target].active=true
	res._movers[target].place(front,PI)
	res._movers[target].hold(front,front)
	res.bodies[target].show()
	player.visual.rotation.y=0
	player.fighter.target=null
	await frames(15)
	var eligible: Array=preload("res://scripts/studio/village/contact.gd").candidates(get_tree(),player,2.8,Vector3.BACK)
	check(eligible.any(func(c: Dictionary)->bool:return int(c.id)==target),"target stands within real Heavy contact")
	check(SaveGame.save_game()==OK,"full save before the encounter")
	var writes := Accept.writes
	Accept.measures.clear()
	player.heavy()
	await seconds(20.0)
	v=VillageSession.village
	check(Accept.writes>writes and Accept.rejected==0,"real Heavy and witness memories accepted through checked saves (%d writes, %d refused)" % [Accept.writes-writes,Accept.rejected])
	check(int(v.people[target].mind.known.size())>known,"struck resident remembers the new deed beside its earlier history")
	check(People.invalid(v)=="","people state remains readable after live processing")
	# Step 4 journal: what a restart would read (full save + journal lines) is exactly the live village.
	SaveGame.save_game(false)
	var journal := FileAccess.open(SaveGame._path+".journal",FileAccess.READ)
	var bytes := journal.get_length() if journal!=null else 0
	var lines := Journal.records(journal).size() if journal!=null else 0
	var replayed=Codec.from_data(SaveGame._read().get("village",{}))
	print("OWNER PLAY journal lines=%d bytes=%d" % [lines,bytes])
	if replayed!=null:
		var a: Dictionary=Codec.to_data(replayed,false).state.fields;var b: Dictionary=Codec.to_data(VillageSession.village,false).state.fields
		for field: String in b:
			if JSON.stringify(a.get(field))!=JSON.stringify(b[field]):
				var detail := ""
				if field=="people":
					for i in b.people.size():
						if i>=a.people.size() or JSON.stringify(a.people[i])!=JSON.stringify(b.people[i]):
							detail="first row %d sizes %d/%d" % [i,a.people.size(),b.people.size()]
							if i<a.people.size():
								for j in maxi(a.people[i].size(),b.people[i].size()):
									if j>=a.people[i].size() or j>=b.people[i].size() or JSON.stringify(a.people[i][j])!=JSON.stringify(b.people[i][j]):
										var x := JSON.stringify(a.people[i][j] if j<a.people[i].size() else null);var y := JSON.stringify(b.people[i][j] if j<b.people[i].size() else null)
										var at := 0
										while at<mini(x.length(),y.length()) and x[at]==y[at]:at+=1
										detail+=" slot %d at %d/%d/%d replay=%s live=%s" % [j,at,x.length(),y.length(),x.substr(maxi(0,at-120),240),y.substr(maxi(0,at-120),240)];break
							break
				print("OWNER PLAY journal differs field=%s %s" % [field,detail])
	check(lines>0 and replayed!=null and JSON.stringify(Codec.to_data(replayed,false))==JSON.stringify(Codec.to_data(VillageSession.village,false)),
		"full save plus journal replays to exactly the live village (%d lines)" % lines)
	var back=Codec.from_data(Codec.to_data(v,false))
	check(back!=null and back.people[target].mind.known.size()==v.people[target].mind.known.size() and People.invalid(back)=="","checked state reloads with the new and earlier memories")
	# Step 4 checkpoint: built on a worker thread from the full save and the journal only, it holds the live village.
	SaveGame._journal.checkpoint()
	SaveGame._journal.wait()
	var held: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SaveGame._path))
	var built=Codec.from_data(held.get("village",{})) if held.get("village") is Dictionary else null
	check(SaveGame._journal.checkpoints>0 and int(held.get("journal_seq",0))==SaveGame._journal.seq and not FileAccess.file_exists(SaveGame._path+".journal") and built!=null
		and JSON.stringify(Codec.to_data(built,false))==JSON.stringify(Codec.to_data(VillageSession.village,false)),
		"checkpoint built from data alone holds exactly the live village (journal_seq %d, swept %d)" % [int(held.get("journal_seq",0)),VillageImage.swept])
	for field: String in ["accept_us","clone_us","save_us"]:
		var costs: Array=Accept.measures.map(func(row: Dictionary)->int:return int(row.get(field,0)))
		costs.sort()
		if not costs.is_empty():
			print("OWNER PLAY %s samples=%d median_ms=%.3f max_ms=%.3f" % [field,costs.size(),costs[costs.size()/2]/1000.0,costs[-1]/1000.0])
	print("OWNER PLAY complete failures=%d" % failed)
	get_tree().quit(0 if failed==0 else 1)
