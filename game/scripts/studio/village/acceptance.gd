extends RefCounted
## E/S checked acceptance: root actions, ready memories, costs and semantic phases share ONE checked batch and save.
## transact(prepare(village)->receipt, writer?)->receipt; only OK publishes accepted=true.
## prepare must not publish, animate, signal or save. A replay returns its saved receipt without a write.
## Resource notifications are withheld until the write succeeds; recursive acceptance is refused.
## Failure restores village/bag/purse without publishing notifications. Stable caller keys survive retry.
## Step 4 (5 Oct): prepare runs on the live village. VillageImage (village/sim/image.gd) holds what disk holds: a
## refused, replayed or unwritten batch is put back from it exactly, and a written one is one small journal line
## (only what changed), flushed before anything is published. No whole-village copy or encode on this path.
const Codec := preload("res://scripts/studio/village/sim/save.gd")
const People := preload("res://scripts/studio/village/sim/people.gd")
const VillageImage := preload("res://scripts/studio/village/sim/image.gd")
const S := preload("res://scripts/studio/village/sim/state.gd")
static var writes := 0
static var failures := 0
## Batches refused because prepare left people state its consumers cannot read; each defect reports once.
static var rejected := 0
static var _reported := {}
static var measures: Array[Dictionary] = []
static var _accepting := false
static var _guard_arg := -1
static func transact(prepare: Callable, writer := Callable()) -> Dictionary:
	if _accepting:
		return {"accepted":false,"reason":"recursive acceptance"}
	_accepting=true
	var result := _execute(prepare,writer)
	_accepting=false
	return result
static func _execute(prepare: Callable, writer: Callable) -> Dictionary:
	var started := Time.get_ticks_usec()
	var v = VillageSession.village
	if v==null:
		return {"accepted":false,"reason":"no village"}
	VillageImage.begin(v)
	var begun := Time.get_ticks_usec()
	var result: Dictionary=prepare.call(v)
	var prepared := Time.get_ticks_usec()
	var diff := VillageImage.batch_changes(v)
	VillageImage.hints=null
	if not result.get("accepted",false) or result.get("duplicate",false):
		VillageImage.restore(v,diff)
		_guard(v,"refused or replayed batch")
		return result
	var defect := People.invalid(_touched(v,diff))
	if not defect.is_empty():
		VillageImage.restore(v,diff)
		rejected+=1
		if not _reported.has(defect):
			_reported[defect]=true
			push_error("PEOPLE ACCEPTANCE REFUSED invalid "+defect)
		_guard(v,"invalid batch")
		return {"accepted":false,"reason":"invalid people state","defect":defect}
	var bag := Inventory.to_data().duplicate(true)
	var coins := Money.coins
	var totals := {}
	for cost: Dictionary in result.get("costs",[]):
		totals[str(cost.item)]=int(totals.get(str(cost.item),0))+int(cost.count)
	for item: String in totals:
		if int(totals[item])<0 or int(totals[item])>(coins if item=="coins" else Inventory.count(item)):
			VillageImage.restore(v,diff)
			_guard(v,"unaffordable batch")
			return {"accepted":false,"reason":"insufficient batch resources"}
	var checked := Time.get_ticks_usec()
	VillageImage.stage(v,diff)
	var inventory_blocked := Inventory.is_blocking_signals()
	var money_blocked := Money.is_blocking_signals()
	Inventory.set_block_signals(true)
	Money.set_block_signals(true)
	for item: String in totals:
		if item=="coins":
			Money.spend(int(totals[item]))
		else:
			Inventory.remove(item,int(totals[item]))
	var saving := Time.get_ticks_usec()
	var error: int=int(writer.call()) if writer.is_valid() else SaveGame.save_game(false)
	writes+=1
	if error!=OK:
		VillageImage.unstage()
		VillageImage.restore(v,diff)
		Inventory.load_data(bag)
		Money.coins=coins
		failures+=1
	else:
		VillageImage.commit(v)
	var done := Time.get_ticks_usec()
	if not writer.is_valid():
		# clone_us is the batch-start image check (named for the 4 Oct comparison); save_us is the line and its write.
		measures.append({"clone_us":begun-started,"prepare_us":prepared-begun,"check_us":checked-prepared,"stage_us":saving-checked,
			"save_us":done-checked,"accept_us":done-started})
		if measures.size()>128:
			measures.pop_front()
	Inventory.set_block_signals(inventory_blocked)
	Money.set_block_signals(money_blocked)
	VillageImage.hints=null
	_guard(v,"written batch" if error==OK else "failed write")
	if error!=OK:
		return {"accepted":false,"reason":"save failed","error":error}
	# Publication only. Notification listeners cannot reenter a candidate transaction.
	for item: String in totals:
		if item=="coins":
			Money.changed.emit(Money.coins)
		else:
			Inventory.changed.emit(item,Inventory.count(item))
	return result
## The minds a batch changed, as a village People.invalid can read: the others were accepted (or loaded) unchanged.
## People.invalid checks each mind's receipts and stances alone (2 ms for all 34 on the real save, every batch).
static func _touched(v,diff: Dictionary):
	if diff.m.is_empty() and not diff.f.has("actor_minds") and not diff.has("n"):
		return _empty
	var probe := S.Village.new()
	probe.seed=v.seed
	for i: int in diff.m:
		var d: Dictionary=diff.m[i]
		if not (d.has(&"appraised") or d.has(&"stances")): # what People.invalid reads
			continue
		var changed: Variant=d.get(&"appraised")
		if changed is Dictionary and i<VillageImage.disk_n:
			# Only this batch's receipts: every other one was checked when it was written.
			var live=v.people[i]
			var shown=S.Person.new()
			shown.id=live.id
			shown.mind.stances=live.mind.stances
			shown.mind.appraised={}
			for fact: Variant in changed.set:
				if live.mind.appraised.has(fact):shown.mind.appraised[fact]=live.mind.appraised[fact]
			probe.people.append(shown)
		else:
			probe.people.append(v.people[i])
	for i in range(VillageImage.disk_n,v.people.size()):
		if not diff.m.has(i):probe.people.append(v.people[i])
	if diff.f.has("actor_minds"):
		probe.actor_minds=v.actor_minds
	return probe
static var _empty = S.Village.new()
## Tests (--save-guard, or VillageImage.guard set): the image equals the live village after every batch, or the run fails.
static func _guard(v,what: String) -> void:
	if _guard_arg<0:
		_guard_arg=1 if OS.get_cmdline_user_args().has("--save-guard") else 0
	if not (VillageImage.guard or _guard_arg==1):
		return
	var differs := VillageImage.verify(v)
	if not differs.is_empty():
		print("FAIL save-image guard after %s: %s" % [what,", ".join(PackedStringArray(differs.map(func(x)->String:return str(x))))])
