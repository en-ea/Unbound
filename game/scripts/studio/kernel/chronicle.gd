extends RefCounted
## Reading the kernel's chronicle: its structured events rendered as text. Presentation only; the
## kernel stores codes and numbers. Mirrors line() and describe() in kernel.mjs.

const World := preload("res://scripts/studio/kernel/world.gd")

const PEOPLE_NAME: Array[String] = ["Mainlanders", "Ashfolk", "Tethered"]
const TECH_NAME: Array[String] = ["fire", "farming", "pottery", "charcoal", "copper", "the mill", "bread", "iron", "writing", "boats", "medicine"]
const STAGES: Array[String] = ["hut", "homestead", "hamlet", "village", "town"]
const PLAYER_NAMES: Array[String] = ["someone", "Hilmi", "Enea"]


static func stage_of(p: int) -> int:
	if p <= 0:
		return -1
	if p < 20:
		return 0
	if p < 50:
		return 1
	if p < 120:
		return 2
	if p < 250:
		return 3
	return 4


static func _name(w: World, i: int) -> String:
	return w.names[i] if i >= 0 and i < w.n else "?"


static func _who(p: int) -> String:
	return PLAYER_NAMES[p] if p >= 0 and p < PLAYER_NAMES.size() else "player %d" % p


static func line(w: World, i: int) -> String:
	var who := _name(w, w.ev_sub[i])
	var other := _name(w, w.ev_other[i])
	var a := w.ev_a[i]
	var b := w.ev_b[i]
	var c := w.ev_c[i]
	match w.ev_type[i]:
		World.E_FOUNDED:
			if w.ev_other[i] < 0:
				return "%s is founded by the %s" % [who, PEOPLE_NAME[w.people[w.ev_sub[i]]]]
			return "settlers from %s found %s" % [other, who]
		World.E_DROUGHT:
			return "drought in %s" % who
		World.E_FLOOD_HELD:
			return "the river rises at %s, but the dykes hold" % who
		World.E_FLOOD:
			return "a flood takes %d lives in %s" % [a, who] + (" and destroys the mill" if b != 0 else "")
		World.E_HUNGER:
			return "hunger in %s: %d die or leave" % [who, a]
		World.E_DISCOVERY:
			return "%s discovers %s" % [who, TECH_NAME[a]]
		World.E_REDISCOVERY:
			return "%s rediscovers %s" % [who, TECH_NAME[a]]
		World.E_FORGOT:
			return "%s forgets %s" % [who, TECH_NAME[a]]
		World.E_AID:
			return "%s sends %d grain to %s" % [other, a, who]
		World.E_RAID:
			return "%s raids %s for %d grain; %d fall" % [who, other, b, a]
		World.E_LEARNED:
			return "%s learns %s from %s" % [who, TECH_NAME[a], other]
		World.E_RUIN:
			return "%s is abandoned" % who + ("; its mill stands empty" if a != 0 else "")
		World.E_WARNED:
			return "a stranger from another age warns %s of the flood; they raise dykes" % who
		World.E_TAUGHT:
			return "a stranger teaches %s %s" % [who, TECH_NAME[a]]
		World.E_GIFT:
			return "a traveller leaves %d grain at %s" % [a, who]
		World.E_FELLED:
			return "%s clears the woods by %s" % [_who(b), who]
		World.E_BRIDGE:
			return "%s funds a bridge at %s" % [_who(b), who]
		World.E_STORM:
			return "a time storm folds %d of %s's people into year %d; %d people of that age stand in their place and call themselves %s" % [a, other, b, c, who]
	return "? event %d" % w.ev_type[i]


## The whole chronicle, one "yyy  text" line per event (the format golden.mjs hashes).
static func text(w: World) -> String:
	var lines := PackedStringArray()
	for i in w.ev_year.size():
		lines.append(str(w.ev_year[i]).lpad(3) + "  " + line(w, i))
	return "\n".join(lines) + "\n"


static func describe(w: World, s: int) -> String:
	if w.pop[s] <= 0:
		return "%s: ruin since year %d" % [w.names[s], w.ruined[s]]
	var known := PackedStringArray()
	for k in World.NT:
		if World.has(w.tech[s], k):
			known.append(TECH_NAME[k])
	return "%s: %s of %d, knows %s" % [w.names[s], STAGES[stage_of(w.pop[s])], w.pop[s], ", ".join(known)]
