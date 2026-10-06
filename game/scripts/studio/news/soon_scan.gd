extends RefCounted
## Which villages stage which public act soon (plan LIVELY-VILLAGE: the ends are watched on real acts, and the rules'
## history moves whenever the rules change, so the village to watch one in is looked up, not remembered). Pure rules:
## each seed advanced dawn by dawn as session.gd's --village-soon does, up to DAYS.
##   godot --headless --path game --script res://scripts/studio/run.gd -- news/soon_scan
## Prints SOON <seed> <kind> day <n> for the first of each kind in each village, then PASS.
const Runtime := preload("res://scripts/studio/village/sim/runtime.gd")
const Save := preload("res://scripts/studio/village/sim/save.gd")
const SEEDS := [-1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
const KINDS := ["pillory", "stocks", "hanging", "bonfire"]
const DAYS := 60


static func report() -> PackedStringArray:
	var out := PackedStringArray()
	for seed: int in SEEDS:
		var v = Runtime.create(Save.HOME_SEED if seed < 0 else seed)
		var seen := {}
		for day in DAYS:
			Runtime.advance(v, Runtime.next_dawn(v))
			for pending in v.pending:
				if pending.kind in KINDS and not seen.has(pending.kind):
					seen[pending.kind] = day + 1
		var line := "SOON %s" % ("home" if seed < 0 else str(seed))
		for k: String in KINDS:
			line += " %s:%s" % [k, str(seen.get(k, "-"))]
		out.append(line)
	out.append("PASS soon scanned (%d villages, %d days)" % [SEEDS.size(), DAYS])
	return out
