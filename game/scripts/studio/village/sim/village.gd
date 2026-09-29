extends RefCounted
## Port of tools-src/studio/village-reference/village.mjs.
## The living village (tier V): about 30 named people in households and lineages, living a day at a time.
## Each day: food and life, the director, dawn plans (who is where, when), today's scheduled events
## (trials, public acts, funerals, festivals), crimes, discoveries, gossip, cases, and minds (stress,
## guilt, confessions). Integers only; every random draw is keyed.
##
## Entry points: create_village(seed, opts), step_day(V), run(V, days), hash_village(V); the stagings made
## are V.stagings (staging.gd contract Dictionaries), V.staging_count in all.

const R := preload("res://scripts/studio/village/sim/rng.gd")
const C := preload("res://scripts/studio/village/sim/content.gd")
const S := preload("res://scripts/studio/village/sim/state.gd")
const E := preload("res://scripts/studio/village/sim/events.gd")
const Crime := preload("res://scripts/studio/village/sim/crime.gd")
const Justice := preload("res://scripts/studio/village/sim/justice.gd")
const Director := preload("res://scripts/studio/village/sim/director.gd")
const Storm := preload("res://scripts/studio/village/sim/storm.gd")

const YEAR := 60  # days in a village year: four seasons of 15
const DAY := 1440  # minutes
const P_TRAIT := 1
const P_NAME := 2
const P_ROLE := 3
const P_BIRTH := 4
const P_DEATH := 5
const P_MARRY := 6
const P_PLAN := 7
const P_CRIME := 8
const P_SIGHT := 9
const P_GOSSIP := 10
const P_TRIAL := 11
const P_CROWD := 12
const P_HARVEST := 13
const P_OMEN := 14
const P_CYCLE := 15
const P_OPINION := 16
const P_SEX := 17
const P_AGE := 18
const P_VALUE := 19
const P_FOOD := 20
const P_CONFESS := 21
const P_FESTIVAL := 22
const P_STORM := 23
const P_ARRIVAL := 24
const P_STAGE := 25
const P_EXILE := 26
const P_RETURN := 27
const P_MOTIVE := 28

# The meadow village as a layout of the reusable type (content.gd PLACE_KINDS); decimetres. Homes follow
# Enea's houses (sites.gd); pens sit beside them; public places match sites.gd.
const MEADOW := {
	"homes": ["cottage", "cabin", "round", "hill", "lodge", "loaf"],
	"pos": {
		"cottage": [-32, 126], "cabin": [80, 140], "round": [-64, 234], "hill": [58, 224], "lodge": [-32, 300], "loaf": [-102, 36],
		"pen_cottage": [-70, 100], "pen_cabin": [120, 150], "pen_round": [-100, 250], "pen_hill": [100, 250], "pen_lodge": [-70, 320], "pen_loaf": [-140, 50],
		"square": [15, 180], "pillory": [-5, 170], "gallows": [10, 70], "stake": [40, -50], "shrine": [-110, 140], "well": [40, 250],
		"mill": [120, 60], "field": [-140, 200], "pasture": [60, 330], "forge": [-170, 120], "woods": [-220, -60], "gate_south": [20, 400],
		# beyond the village: where errands go, and where no one sees (the road south, the far woods)
		"road": [40, 1100], "far_woods": [-700, -400],
	},
}


## opts: {"pace": int, "age": int, "tier": String, "layout": Dictionary, "name": String, "anchored": bool, "live": bool, "focus": bool,
##   "stormPlan": [{"day": int, "household": int, "days": int}]}
static func create_village(seed: int, opts: Dictionary = {}) -> S.Village:
	var V := S.Village.new()
	V.seed = seed & R.M32
	V.base = R.key(V.seed, 0x5eed)
	V.day = 0
	V.age = opts.get("age", C.VILLAGE)
	# pace: how dense life is. 1 = the chronicle (history at a believable per-head rate); the live game runs
	# faster (C.LIVE_PACE), as a named cast standing for a larger settlement. It scales how often people
	# act on a motive, never whether they have one.
	V.pace = opts.get("pace", 1)
	V.tier = opts.get("tier", "private")
	V.name = opts.get("name", "Wenbrook")
	# time storms (storm.gd): an anchored story village is exempt; stormPlan is the kernel's stand-in for tests
	for sp: Dictionary in opts.get("stormPlan", []):
		V.storm_plan.append_array([sp["day"], sp["household"], sp["days"]])
	V.anchored = opts.get("anchored", false)
	# the live game (live.gd): public acts wait on the stage for the player (justice.gd resolve_public)
	V.live = opts.get("live", false)
	# focus: this is the village the player is in (the live game's director paces it by play time, director.gd)
	V.focus = opts.get("focus", false)
	make_places(V, opts.get("layout", MEADOW))
	V.culture = (C.CULTURE[V.age] as Dictionary).duplicate()
	# six founding lineages, one household each
	var names: Array = C.LINEAGE_NAMES[V.age]
	var used := {}
	for h in V.homes.size():
		var n := R.pick(R.key(V.base, 100 + h), names.size())
		while used.has(n):
			n = (n + 1) % names.size()
		used[n] = true
		var lin := S.Lineage.new()
		lin.id = h; lin.name = names[n]; lin.age = V.age
		V.lineages.append(lin)
		var hh := S.Household.new()
		hh.id = h; hh.lineage = h; hh.home = V.homes[h]; hh.home_place = place_id(V, hh.home); hh.food = 40
		hh.geese = R.pick(R.key(V.base, 200 + h), 5)
		V.households.append(hh)
	# people: a couple, children, sometimes a grandparent, per household
	for h in V.households.size():
		var hk := R.key(V.base, 300 + h)
		var father := add_person(V, h, 0, 25 + R.pick(R.key(hk, 1), 20), -1, -1)
		var mother := add_person(V, h, 1, 22 + R.pick(R.key(hk, 2), 18), -1, -1)
		V.people[father].spouse = mother; V.people[mother].spouse = father
		var kids := 1 + R.pick(R.key(hk, 3), 4)
		for k in kids:
			add_person(V, h, R.pick(R.key(hk, 10 + k), 2), 1 + R.pick(R.key(hk, 20 + k), 17), father, mother)
		if R.chance(R.key(hk, 4), 400000):
			add_person(V, h, R.pick(R.key(hk, 5), 2), 58 + R.pick(R.key(hk, 6), 12), -1, -1)
	# the elder: the oldest adult; the priest: the most pious other adult (a shaman in the tribal age)
	elect_authorities(V)
	# a few friendships and rivalries between households
	var n := V.people.size()
	for i in n * 2:
		var k := R.key(V.base, 5000 + i)
		var a := R.pick(k, n)
		var b := R.pick(R.key(k, 1), n)
		if a == b or V.people[a].household == V.people[b].household:
			continue
		var v := R.pick(R.key(k, 2), 120) - 60
		set_opinion(V, a, b, v); set_opinion(V, b, a, clampi(v + R.pick(R.key(k, 3), 40) - 20, -100, 100))
	return V


## (port) Interns the layout's places: ids in the order of layout.pos, positions, and the squared distances
## between every pair (witnesses_at reads them).
static func make_places(V: S.Village, layout: Dictionary) -> void:
	V.homes = PackedStringArray(layout["homes"])
	var pos: Dictionary = layout["pos"]
	for nm: String in pos:
		var xz: Array = pos[nm]
		_add_place(V, nm, xz[0], xz[1], true)
	V.pl_square = place_id(V, "square")
	V.pl_shrine = place_id(V, "shrine")
	V.pl_pillory = place_id(V, "pillory")
	V.pl_far_woods = place_id(V, "far_woods")
	V.pl_road = place_id(V, "road")
	V.pl_woods = place_id(V, "woods")
	V.pl_home_word = V.place_ids.get("home", -2)   # the reference compares places with "home": never a place here
	for h in V.homes:
		place_id(V, h)
		place_id(V, "pen_" + h)


static func _add_place(V: S.Village, nm: String, x: int, z: int, has_pos: bool) -> int:
	var id := V.place_names.size()
	V.place_names.append(nm)
	V.place_ids[nm] = id
	V.place_x.append(x)
	V.place_z.append(z)
	V.place_has_pos.append(1 if has_pos else 0)
	V.place_pen.append(1 if nm.begins_with("pen") else 0)
	V.n_places = V.place_names.size()
	# ranks (string order, as the reference's sort of place names) and distances, rebuilt on each addition
	var sorted := Array(V.place_names)
	sorted.sort()
	V.place_rank.resize(V.n_places)
	for i in V.n_places:
		V.place_rank[V.place_names.find(sorted[i])] = i
	V.dist2.resize(V.n_places * V.n_places)
	for i in V.n_places:
		for j in V.n_places:
			var dx := V.place_x[i] - V.place_x[j]
			var dz := V.place_z[i] - V.place_z[j]
			V.dist2[i * V.n_places + j] = dx * dx + dz * dz
	return id


## A place's id; a name the layout does not know is added at [0, 0] (the reference's `pos[place] ?? [0, 0]`).
static func place_id(V: S.Village, nm: String) -> int:
	var id: int = V.place_ids.get(nm, -1)
	if id < 0:
		id = _add_place(V, nm, 0, 0, false)
	return id


# A child is named for a dead forebear of the lineage when one is free (the old custom), else a name no one
# living in the village holds; two living people never share a given name, so the tales can tell them apart.
static func name_child(V: S.Village, hh: S.Household, given: Array, _sex: int, k: int) -> String:
	var held := {}
	for q in V.people:
		if q.alive:
			held[q.name] = true
	var lin: S.Lineage = V.lineages[hh.lineage] if hh != null else null
	var forebears := PackedStringArray()
	if lin != null:
		for nm in lin.past_names:
			if given.has(nm) and not held.has(nm):
				forebears.append(nm)
	if forebears.size() > 0 and R.chance(R.key(k, 1), 600000):
		return forebears[R.pick(R.key(k, 2), forebears.size())]
	var free := []
	for nm: String in given:
		if not held.has(nm):
			free.append(nm)
	var pool: Array = free if free.size() > 0 else given
	return pool[R.pick(k, pool.size())]


## opts: {"era": int, "quiet": bool}
static func add_person(V: S.Village, household: int, sex: int, age_years: int, father: int, mother: int, opts: Dictionary = {}) -> int:
	var id := V.people.size()
	var k := R.key(R.key(V.base, 1000), id)
	var age: int = opts.get("era", V.age)
	var traits := PackedInt32Array()
	for t in C.TRAITS.size():
		# inherited from a parent when there is one (with drift), else drawn; two draws averaged
		var inherit := -1
		if father >= 0:
			var from := father if R.chance(R.key(k, 30 + t), 500000) else mother
			if from >= 0 and from < V.people.size():   # the reference's `V.people[...]?.traits[t]`
				inherit = V.people[from].traits[t]
		var drawn := R.idiv(R.pick(R.key(k, t), 101) + R.pick(R.key(k, 10 + t), 101), 2)
		traits.append(clampi(R.idiv(inherit * 2 + drawn, 3), 0, 100) if inherit >= 0 else drawn)
	var cul: Dictionary = C.CULTURE[age]
	var given: Array = C.GIVEN[age][sex]
	var hh: S.Household = V.households[household] if household >= 0 and household < V.households.size() else null
	var p := S.Person.new()
	p.id = id
	p.name = opts["name"] if opts.has("name") else name_child(V, hh, given, sex, R.key(k, P_NAME))
	p.lineage = hh.lineage if hh != null else -1
	p.household = household
	p.sex = sex
	p.born = V.day - age_years * YEAR - R.pick(R.key(k, P_AGE), YEAR)
	p.era = age
	p.traits = traits
	var values := PackedInt32Array()
	for i in 4:
		values.append(clampi(int(cul[C.VALUE_NAMES[i]]) + R.pick(R.key(k, 40 + i), 51) - 25, 0, 100))
	p.values = values
	p.father = father
	p.mother = mother
	V.people.append(p)
	if hh != null:
		hh.members.append(id)
	p.role = role_for(V, p)
	if hh != null and V.day > 0 and not opts.get("quiet", false):
		E.log_event(V, "birth", id, mother, {"lineage": p.lineage}, PackedInt32Array(), "a newborn's cry")
	return id


## A person's age in years. (V.day - born is never negative, so int division is floor division here.)
@warning_ignore("integer_division")
static func age_of(V: S.Village, p: S.Person) -> int:
	return (V.day - p.born) / YEAR


static func role_for(V: S.Village, p: S.Person) -> String:
	var a := age_of(V, p)
	if a < 14:
		return "child"
	var roles: Array = C.ADULT_ROLES[p.era]
	return roles[R.pick(R.key(R.key(V.base, 2000), p.id), roles.size())]


static func elect_authorities(V: S.Village) -> void:
	var elder := -1
	var priest := -1
	for p in V.people:
		if not p.alive or not p.present or p.era != V.age or age_of(V, p) < 30:
			continue
		if elder < 0 or p.born < V.people[elder].born or (p.born == V.people[elder].born and p.id < elder):
			elder = p.id
	for p in V.people:
		if not p.alive or not p.present or p.id == elder or p.era != V.age or age_of(V, p) < 20:
			continue
		if priest < 0 or p.traits[C.PIETY] > V.people[priest].traits[C.PIETY]:
			priest = p.id
	if V.authority != elder and elder >= 0:
		V.people[elder].role = "elder"
	if V.priest != priest and priest >= 0:
		V.people[priest].role = "priest"
	V.authority = elder
	V.priest = priest


# Opinions: sparse, -100..100; kin are fond of each other by default.
static func opinion(V: S.Village, a: int, b: int) -> int:
	var pa := V.people[a]
	var i := pa.rel_k.find(b)
	if i >= 0:
		return pa.rel_v[i]
	return 50 if is_kin(V, a, b) else 0


static func set_opinion(V: S.Village, a: int, b: int, v: int) -> void:
	var pa := V.people[a]
	v = clampi(v, -100, 100)
	var i := pa.rel_k.find(b)
	if i >= 0:
		pa.rel_v[i] = v
	else:
		pa.rel_k.append(b)
		pa.rel_v.append(v)
	if pa.rel_k.size() > 16:  # keep the strongest feelings (Bannerlord: grudges are personal and few)
		var weakest := -1
		var w := 1000
		var wi := -1
		for j in pa.rel_k.size():
			var val := absi(pa.rel_v[j])
			var o := pa.rel_k[j]
			if val < w or (val == w and o < weakest):
				w = val; weakest = o; wi = j
		pa.rel_k.remove_at(wi)
		pa.rel_v.remove_at(wi)


static func is_kin(V: S.Village, a: int, b: int) -> bool:
	var pa := V.people[a]
	var pb := V.people[b]
	return pa.household == pb.household or pa.lineage == pb.lineage or pa.spouse == b or pa.father == b or pa.mother == b or pb.father == a or pb.mother == a


static func living(V: S.Village) -> Array[S.Person]:
	var out: Array[S.Person] = []
	for p in V.people:
		if p.alive and p.present:
			out.append(p)
	return out


# ---------- one day ----------
static func step_day(V: S.Village) -> void:
	# anything the stage did not finish yesterday resolves as it was going to
	while V.pending.size() > 0:
		Justice.resolve_public(V, V.pending[0].staging, "")
	var doy := V.day % YEAR
	if doy == 0:
		year_start(V)
	food(V)
	life(V)
	Director.director_day(V)
	plan_day(V)
	Justice.run_scheduled(V)
	Crime.crimes_today(V)
	if V.storms.size() > 0 or V.storm_plan.size() > 0:
		Storm.storm_day(V)
	Crime.discover_crimes(V)
	Crime.gossip(V)
	Crime.check_cases(V)
	minds(V)
	V.day += 1


static func run(V: S.Village, days: int) -> S.Village:
	for i in days:
		step_day(V)
	return V


static func year_start(V: S.Village) -> void:
	var y := R.idiv(V.day, YEAR)
	# harvest quality: most years fair, some poor, a few ruinous (droughts); keyed per year
	var r := R.ppm(R.key(R.key(V.base, P_HARVEST), y))
	V.harvest = 45 if r < 70000 else (70 if r < 220000 else (100 if r < 850000 else 125))
	if V.harvest <= 45:
		V.stats["famines"] += 1
		E.log_event(V, "famine", -1, -1, {"year": y}, PackedInt32Array(), "the grain rots in the ear")
		V.hardship = clampi(V.hardship + 500, 0, 1000)
		V.fear = clampi(V.fear + 250, 0, 1000)
	# children come of age; the elder and priest are re-chosen if gone
	for p in V.people:
		if p.alive and p.role == "child" and age_of(V, p) >= 14:
			p.role = role_for(V, p)
	if V.authority < 0 or not V.people[V.authority].alive or not V.people[V.authority].present:
		elect_authorities(V)
	elif V.priest < 0 or not V.people[V.priest].alive or not V.people[V.priest].present:
		elect_authorities(V)
	marriages(V)
	arrivals(V)


const SEASON := [80, 120, 150, 40]  # spring, summer, autumn, winter: percent of a role's yield


static func food(V: S.Village) -> void:
	var season: int = SEASON[R.idiv(V.day % YEAR, 15)]
	for h in V.households:
		var made := 0
		var eaters := 0
		for id in h.members:
			var p := V.people[id]
			if not p.alive or not p.present:
				continue
			eaters += 1
			if p.locked:
				continue
			made += int(C.ROLES[p.role]["yield"]) if C.ROLES.has(p.role) else 0
		if eaters == 0:
			continue
		h.food += R.idiv(made * season * V.harvest, 10000) - eaters
		if h.food > eaters * 25:
			h.food = eaters * 25
		var hungry := h.food < 0
		if hungry:
			h.food = maxi(h.food, -eaters * 20)
		for id in h.members:
			var p := V.people[id]
			if not p.alive:
				continue
			p.hunger = clampi(p.hunger + (60 if hungry else -80), 0, 1000)
	V.hardship = clampi(V.hardship - 5, 0, 1000)
	V.fear = clampi(V.fear - 8, 0, 1000)


static func life(V: S.Village) -> void:
	for p in V.people:
		if not p.alive or not p.present:
			continue
		var a := age_of(V, p)
		var k := R.key(R.key(R.key(V.base, P_DEATH), V.day), p.id)
		# natural death: rises after 50; hunger raises it (famine); store-tier children never die of hunger
		var risk := 30 if a < 50 else (250 if a < 60 else (900 if a < 70 else 2500))
		if p.hunger >= 900 and not (V.tier == "store" and a < 14):
			risk += 1500
		if R.chance(k, risk):
			die(V, p.id, "hunger" if p.hunger >= 900 else "age", PackedInt32Array(), "the empty bowl by the bed" if p.hunger >= 900 else "the bell for the dead")
	# births: married women 18-40 with a living husband, not in famine, small household
	# (people born in this loop are visited too, as in the reference; they are never mothers)
	var i := 0
	while i < V.people.size():
		var p := V.people[i]
		i += 1
		if not p.alive or not p.present or p.sex != 1 or p.spouse < 0 or not V.people[p.spouse].alive:
			continue
		var a := age_of(V, p)
		if a < 18 or a > 40:
			continue
		var hh := V.households[p.household]
		var alive_members := 0
		for m in hh.members:
			if V.people[m].alive:
				alive_members += 1
		if alive_members >= 8 or hh.food < 0:
			continue
		if R.chance(R.key(R.key(R.key(V.base, P_BIRTH), V.day), p.id), 9000):
			var k := R.key(R.key(V.base, P_SEX), V.people.size())
			var baby := add_person(V, p.household, R.pick(k, 2), 0, p.spouse, p.id, {"era": p.era} if p.ancestor >= 0 else {})
			if p.ancestor >= 0:  # born in the storm, goes with it
				V.people[baby].ancestor = p.ancestor
				V.storms[p.ancestor].ancestors.append(baby)
			V.stats["births"] += 1


static func die(V: S.Village, id: int, cause: String, causes: PackedInt32Array, cue: String) -> int:
	var p := V.people[id]
	if not p.alive:
		return -1
	# a deathbed confession: the dying who let another pay may tell the priest at the last
	if p.guilt > 0 and (cause == "age" or cause == "hunger") and p.traits[C.PIETY] >= 35:
		Justice.confess_guilt(V, id, true)
	p.alive = false; p.died = V.day; p.death_cause = cause; p.locked = false
	if p.lineage >= 0 and p.lineage < V.lineages.size():
		V.lineages[p.lineage].past_names.append(p.name)
	V.stats["deaths"] += 1
	var violent := not (cause == "age" or cause == "hunger")
	if violent:
		V.stats["violentDeaths"] += 1
	var ev := E.log_event(V, "violent_death" if violent else "death", id, -1, {"cause": cause}, causes, cue)
	# grief: kin and friends take it hard; a funeral tomorrow is the damper (Dwarf Fortress's lesson)
	for q in V.people:
		if not q.alive or q.id == id:
			continue
		var o := opinion(V, q.id, id)
		if o > 30:
			q.stress = clampi(q.stress + (90 if is_kin(V, q.id, id) else 40), 0, 400)
	var s := S.Sched.new()
	s.day = V.day + 1; s.kind = "funeral"; s.who = id; s.causes = PackedInt32Array([ev])
	V.schedule.append(s)
	if V.authority == id or V.priest == id:
		elect_authorities(V)
	return ev


static func marriages(V: S.Village) -> void:
	var single: Array[S.Person] = []
	for p in V.people:
		if p.alive and p.present and p.spouse < 0 and age_of(V, p) >= 18 and age_of(V, p) <= 45 and p.era == V.age:
			single.append(p)
	for m in single:
		if m.sex != 0 or m.spouse >= 0:
			continue
		var best := -1
		var best_score := -20
		for w in single:
			if w.sex != 1 or w.spouse >= 0 or is_kin(V, m.id, w.id):
				continue
			var s := opinion(V, m.id, w.id) + opinion(V, w.id, m.id) + R.pick(R.key(R.key(V.base, P_MARRY), m.id * 997 + w.id + V.day), 60)
			if s > best_score:
				best_score = s; best = w.id
		if best < 0:
			continue
		var w := V.people[best]
		m.spouse = best; w.spouse = m.id
		# the bride joins the groom's household (patrilocal, as the villages of the age did)
		var old := V.households[w.household]
		var kept := PackedInt32Array()
		for x in old.members:
			if x != best:
				kept.append(x)
		old.members = kept
		w.household = m.household; w.lineage = m.lineage
		V.households[m.household].members.append(best)
		set_opinion(V, m.id, best, 70); set_opinion(V, best, m.id, 70)
		# the one who wanted her too: a rival's grudge against the groom, remembered (and sometimes repaid)
		var rival := -1
		var rs := 25
		for r in single:
			if r.sex != 0 or r.id == m.id or r.spouse >= 0 or is_kin(V, r.id, best):
				continue
			var s := opinion(V, r.id, best) + R.pick(R.key(R.key(V.base, P_MARRY), r.id * 131 + best + V.day), 50)
			if s > rs:
				rs = s; rival = r.id
		if rival >= 0:
			var rv := V.people[rival]
			var ev := E.log_event(V, "rivalry", rival, m.id, {"bride": best, "motive": "love"}, PackedInt32Array(), "%s walking away from the wedding feast before the dancing" % rv.name)
			set_opinion(V, rival, m.id, opinion(V, rival, m.id) - 30 - R.idiv(rv.traits[C.TEMPER], 2))
			Justice.remember(rv, m.id, ev)
		var sc := S.Sched.new()
		sc.day = V.day + 3; sc.kind = "wedding"; sc.who = m.id; sc.other = best
		V.schedule.append(sc)


# When the village shrinks, newcomers arrive: a new lineage takes an empty home (outsiders: suspicion's
# first targets, as in the witch-trial record).
static func arrivals(V: S.Village) -> void:
	var alive := living(V).size()
	if alive >= 22:
		return
	var empty: S.Household = null
	for h in V.households:
		var every := true
		for m in h.members:
			if V.people[m].alive and V.people[m].present:
				every = false
				break
		if every:
			empty = h
			break
	if empty == null:
		return
	var k := R.key(R.key(V.base, P_ARRIVAL), V.day)
	var names: Array = C.LINEAGE_NAMES[V.age]
	# a name no living lineage holds; if all are held, the newcomers are named for where they came from
	var held := {}
	for h in V.households:
		for m in h.members:
			if V.people[m].alive and V.people[m].present:
				held[V.lineages[h.lineage].name] = true
				break
	var free := []
	for nm: String in names:
		if not held.has(nm):
			free.append(nm)
	var lname: String = free[R.pick(k, free.size())] if free.size() > 0 else names[R.pick(k, names.size())] + " " + C.FROM[R.pick(R.key(k, 4), C.FROM.size())]
	var lin := S.Lineage.new()
	lin.id = V.lineages.size(); lin.name = lname; lin.age = V.age; lin.outsider = true
	V.lineages.append(lin)
	empty.lineage = lin.id; empty.members = PackedInt32Array(); empty.food = 30
	var a := add_person(V, empty.id, 0, 24 + R.pick(R.key(k, 1), 15), -1, -1, {"quiet": true})
	var b := add_person(V, empty.id, 1, 22 + R.pick(R.key(k, 2), 15), -1, -1, {"quiet": true})
	V.people[a].spouse = b; V.people[b].spouse = a; V.people[a].outsider = true; V.people[b].outsider = true
	var c := 0
	while c < 1 + R.pick(R.key(k, 3), 3):
		add_person(V, empty.id, R.pick(R.key(k, 10 + c), 2), 2 + R.pick(R.key(k, 20 + c), 10), a, b, {"quiet": true})
		c += 1
	E.log_event(V, "arrival", a, b, {"lineage": lin.id}, PackedInt32Array(), "a cart with strangers at the gate")


# ---------- dawn plans: who is where, and when ----------
# A plan is a list of [from, to, place] in minutes. Night 21:00-06:00 at home; work 06:00-12:00 and
# 13:00-18:00 at the role's place; a meal at noon; the evening is a choice among places that offer something
# (the well and the square offer company, the shrine comfort, home family), weighted by needs and traits,
# picked at random among the top three (never always the best: crowds must not move in lockstep).
static func plan_day(V: S.Village) -> void:
	var dk := R.key(R.key(V.base, P_PLAN), V.day)
	var holy := V.day % 7 == 0
	var market := V.day % 7 == 3
	for p in V.people:
		p.plan = PackedInt32Array()
		if not p.alive or not p.present:
			continue
		var home := V.households[p.household].home_place
		if p.locked:
			p.plan = PackedInt32Array([0, DAY, p.locked_at if p.locked_at >= 0 else V.pl_pillory])
			continue
		var k := R.key(dk, p.id)
		var work := work_place(V, p)
		var plan := PackedInt32Array([0, 360, home])
		if holy and p.traits[C.PIETY] >= 35:
			plan.append_array([360, 540, home, 540, 660, V.pl_shrine, 660, 1080, V.pl_square if market else home])
		elif market and (p.role == "merchant" or R.chance(R.key(k, 1), 350000)):
			plan.append_array([360, 600, work, 600, 780, V.pl_square, 780, 1080, work])
		else:
			plan.append_array([360, 720, work, 720, 780, work if (p.role == "farmer" or p.role == "herder") else home])
			plan.append_array(afternoon(V, p, work, k))
		plan.append_array([1080, 1260, evening_choice(V, p, k), 1260, DAY, home])
		p.plan = plan


# Most afternoons are work; now and then an errand takes a person out alone (to the next village's market,
# to the far woods for timber or game): the lonely hours where no one sees.
static func afternoon(V: S.Village, p: S.Person, work: int, k: int) -> PackedInt32Array:
	if p.role == "child" or p.role == "elder" or p.role == "priest" or p.role == "beggar" or not R.chance(R.key(k, 2), 60000):
		return PackedInt32Array([780, 1080, work])
	var far := V.pl_far_woods if (p.role == "woodcutter" or p.role == "hunter" or p.role == "gatherer") else V.pl_road
	return PackedInt32Array([780, 840, work, 840, 1000, far, 1000, 1080, work])


static func work_place(V: S.Village, p: S.Person) -> int:
	var w: String = C.ROLES[p.role]["work"] if C.ROLES.has(p.role) else "home"
	if w == "home":
		return V.households[p.household].home_place
	if p.role == "child":
		return V.households[p.household].home_place
	return place_id(V, w)


static func evening_choice(V: S.Village, p: S.Person, k: int) -> int:
	var t := p.traits
	var home := V.households[p.household].home_place
	var o_place: Array[int] = [place_id(V, "well"), V.pl_square, V.pl_shrine, home]
	var o_weight: Array[int] = [
		t[C.SOCIABLE] * 2 + 20,
		t[C.SOCIABLE] + (100 - t[C.PIETY]) + R.idiv(p.stress, 4),
		t[C.PIETY] * 2 + R.idiv(V.fear, 10) + R.idiv(p.stress, 4) + (60 if p.guilt > 0 else 0),
		(100 - t[C.SOCIABLE]) + 60,
	]
	# a friend's home: the best-liked person outside one's household
	var friend := -1
	var fo := 40
	for i in p.rel_k.size():
		var o := p.rel_k[i]
		var v := p.rel_v[i]
		if v > fo and V.people[o].alive and V.people[o].present and V.people[o].household != p.household:
			fo = v; friend = o
	if friend >= 0:
		o_place.append(V.households[V.people[friend].household].home_place)
		o_weight.append(fo + t[C.SOCIABLE])
	# sort: weight descending, then place name ascending (the names differ, so the order is total);
	# an insertion sort over at most five offers
	var n := o_place.size()
	for i in range(1, n):
		var pl := o_place[i]
		var wt := o_weight[i]
		var j := i - 1
		while j >= 0 and (o_weight[j] < wt or (o_weight[j] == wt and V.place_rank[o_place[j]] > V.place_rank[pl])):
			o_place[j + 1] = o_place[j]
			o_weight[j + 1] = o_weight[j]
			j -= 1
		o_place[j + 1] = pl
		o_weight[j + 1] = wt
	var top := mini(3, n)
	var total := 0
	for i in top:
		total += maxi(1, o_weight[i])
	var r := R.pick(R.key(k, 99), total)
	for i in top:
		r -= maxi(1, o_weight[i])
		if r < 0:
			return o_place[i]
	return o_place[0]


# Where a person is at a minute (from today's plan); -1 (the reference's "") if absent.
static func place_at(p: S.Person, minute: int) -> int:
	var pl := p.plan
	var i := 0
	var n := pl.size()
	while i < n:
		if minute >= pl[i] and minute < pl[i + 1]:
			return pl[i + 2]
		i += 3
	return -1


# People who can see a place at a minute: anyone whose own place is within sight of it.
static func witnesses_at(V: S.Village, place: int, minute: int, exclude: int) -> Array[int]:
	var night := minute < 360 or minute >= 1260
	var r := C.SEE_NIGHT if night else C.SEE_DAY
	var r2 := r * r
	var row := place * V.n_places
	var out: Array[int] = []
	for q in V.people:
		if not q.alive or not q.present or q.id == exclude:
			continue
		var at := place_at(q, minute)
		if at < 0:
			continue
		if V.dist2[row + at] <= r2:
			out.append(q.id)
	return out


# ---------- minds: stress, guilt, coping, belief fading, feelings drifting ----------
static func minds(V: S.Village) -> void:
	for p in V.people:
		if not p.alive or not p.present:
			continue
		# stress eases a little each day; hunger and fear feed it
		p.stress = clampi(p.stress - 6 + R.idiv(p.hunger, 200) + R.idiv(V.fear, 250), 0, 400)
		# guilt for a crime someone else paid for grows with piety and compassion (it can break a person)
		# (a hard heart feels none: they carry it to the grave, unless the deathbed breaks them)
		if p.guilt > 0 and p.traits[C.PIETY] + p.traits[C.COMPASSION] >= 100:
			p.guilt = clampi(p.guilt + R.idiv(p.traits[C.PIETY] + p.traits[C.COMPASSION] - 60, 40) * V.pace, 0, 400)
			if p.guilt >= 300:
				Justice.confess_guilt(V, p.id)
		# beliefs fade; the weakest are forgotten
		if p.beliefs.size() > 0:
			var kept: Array[S.Belief] = []
			for b in p.beliefs:
				b.strength -= 4
				if b.strength > 60:
					kept.append(b)
			p.beliefs = kept
		# feelings drift back towards neutral, slowly; deep hatreds hardly at all (grudges are few and kept)
		if V.day % 10 == p.id % 10:
			for i in p.rel_k.size():
				var v := p.rel_v[i]
				if v < -50 and V.day % 60 != p.id % 60:
					continue
				p.rel_v[i] = v - 1 if v > 0 else (v + 1 if v < 0 else 0)


static func hash_village(V: S.Village) -> String:
	var h := R.key(R.FNV, V.day)
	for p in V.people:
		h = R.key(h, p.id); h = R.key(h, 1 if p.alive else 0); h = R.key(h, 1 if p.present else 0); h = R.key(h, p.household); h = R.key(h, p.stress); h = R.key(h, p.hunger)
		h = R.key(h, p.offences); h = R.key(h, p.beliefs.size()); h = R.key(h, p.spouse)
		var order: Array[int] = p.rel_k.duplicate()
		order.sort()
		for o in order:
			h = R.key(h, o); h = R.key(h, p.rel_v[p.rel_k.find(o)])
		for b in p.beliefs:
			h = R.key(h, b.crime); h = R.key(h, b.culprit); h = R.key(h, b.strength); h = R.key(h, b.origin)
	for hh in V.households:
		h = R.key(h, hh.food); h = R.key(h, hh.members.size()); h = R.key(h, hh.geese)
	h = R.key(h, V.ev_hash)
	return "%08x" % h
