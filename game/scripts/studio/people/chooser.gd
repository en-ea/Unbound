extends RefCounted
## C2 one arbitration per appraisal. Discovered offers compete on can/score; modifier score/instruction
## alters this actor's choice. Deterministic priority/id ties. Helper uses this same chooser with its own profile.
## pick/pick_many return the already-evaluated instruction with the chosen offer; consumers never evaluate it again.
const Modules := preload("res://scripts/studio/people/modules.gd")
var offers: Dictionary
var modifiers: Dictionary
func _init(offer_folder := "res://scripts/studio/people/offers/", modifier_folder := "res://scripts/studio/people/modifiers/") -> void:
	offers = Modules.discover(offer_folder)
	modifiers = Modules.discover(modifier_folder)
func pick(me: Dictionary, account: Dictionary) -> Dictionary:
	var instruction := {}
	for row: Dictionary in me.get("modifiers",[]):
		if modifiers.has(str(row.id)):
			instruction.merge(modifiers[str(row.id)].new().choose(me,account,row),true)
	var best := {}
	for key: String in offers:
		var module = offers[key].new()
		if not module.ANSWERS.has(str(account.kind)) or not module.can(me,account):
			continue
		var value := int(module.score(me,account))
		for row: Dictionary in me.get("modifiers",[]):
			if modifiers.has(str(row.id)):
				value += int(modifiers[str(row.id)].new().score(key,me,row))
		if not instruction.is_empty() and key == str(instruction.get("offer","")):
			value += 10000
		if best.is_empty() or value > int(best.value) or (value == int(best.value) and int(module.PRIORITY)>int(best.priority)):
			best = {"offer":key,"value":value,"priority":module.PRIORITY,"effects":module.effects(me,account),
				"steps":module.steps(me,account),"lasts":module.lasts(me,account),"instruction":instruction.duplicate(true)}
	return best

## One actor chooses once for the accounts admitted together. All appraisals precede this arbitration;
## self-preservation can beat an account of another victim in the same physical sweep.
func pick_many(accounts: Array, profile: Callable) -> Dictionary:
	var best := {}
	for a: Dictionary in accounts:
		var candidate := pick(profile.call(a),a)
		if candidate.is_empty():
			continue
		if best.is_empty() or int(candidate.value)>int(best.value) or (int(candidate.value)==int(best.value) and int(candidate.priority)>int(best.priority)):
			best=candidate
			best.account=a
	return best
