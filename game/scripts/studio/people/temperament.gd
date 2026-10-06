extends RefCounted
## S1/S2/S5 discovered temperament: ID + tune(own profile)->bounded gain/rate/attention/style patch.
## Same Modules discovery as sources/modifiers. One file, no chooser/appraisal plug-in registry.
const Modules := preload("res://scripts/studio/people/modules.gd")
static func resolve(me: Dictionary, id := "common", folders: Array = ["res://scripts/studio/people/temperaments/"], modifier_folders: Array = ["res://scripts/studio/people/modifiers/"]) -> Dictionary:
	var tuning := {"anger_gain":1000,"fear_gain":1000,"pain_gain":1000,"interest_gain":1000,"alertness_gain":1000,
		"anger_rate":24,"fear_rate":20,"pain_rate":8,"interest_rate":35,"alertness_rate":30,
		"anger_build_rate":1000,"fear_build_rate":1000,"pain_build_rate":1000,"interest_build_rate":1000,"alertness_build_rate":1200,
		"anger_pulse":500,"fear_pulse":400,
		"wary_rate":33,"trust_rate":3,"resentment_rate":4,"obligation_rate":3,
		"attention_ms":650,"distraction_ms":0,"show":700,"steady":500,"pace":0,"lean":0,"space_mm":1400}
	var modules: Dictionary=Modules.discover(folders[0]) if folders.size()==1 else {}
	if folders.size()!=1:
		for folder: String in folders:modules.merge(Modules.discover(folder),false)
	if modules.has(id):tuning.merge(modules[id].new().tune(me),true)
	var rows: Array=me.get("modifiers",[])
	if not rows.is_empty():
		var modifiers := {}
		for folder: String in modifier_folders:modifiers.merge(Modules.discover(folder),false)
		for row: Dictionary in rows:
			if modifiers.has(str(row.id)):tuning.merge(modifiers[str(row.id)].new().tune(me,row),true)
	for field: String in tuning:
		var bounds: Vector2i=_bounds.get(field,Vector2i.ZERO)
		if bounds==Vector2i.ZERO:bounds=limits(field);_bounds[field]=bounds
		tuning[field]=clampi(int(tuning[field]),bounds.x,bounds.y)
	return tuning
## Each field's clamp range depends only on its name; cached per name.
static var _bounds := {}
static func limits(field: String) -> Vector2i:
	var limit := 3000 if field.ends_with("_gain") else 100 if field.ends_with("_rate") else 1000
	if field=="attention_ms":limit=3000
	if field.ends_with("_build_rate"):limit=3000
	if field=="distraction_ms":limit=30000
	if field=="space_mm":limit=4000
	return Vector2i(-1000 if field in ["pace","lean"] else 0,limit)
func tune(_me: Dictionary) -> Dictionary:
	return {}
