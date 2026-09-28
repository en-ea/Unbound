extends RefCounted
## The world kernel: the world as a pure function of (seed, years, action log).
##
## Integer maths only, keyed randomness, one packed array per field (structure of arrays).
## No nodes and no engine calls, so it can run on a worker thread and gives the same world on
## every phone. The spec is tools-src/studio/kernel-reference/kernel.mjs; golden.gd holds the
## hashes this file must reproduce (run.gd --conform).
##
## Integer rules: chances in parts per million (ppm), multipliers per mille (pm), map positions in
## tenths (0..1000); every division has non-negative operands; hashes are kept inside 32 bits.

# ---------- content (mirrors kernel.mjs) ----------
const PEOPLE_LAND: Array[int] = [0, 1, 2]
const PEOPLE_FERTILE: Array[int] = [1150, 900, 1000]
const PEOPLE_ORE: Array[int] = [200, 1000, 500]
const PEOPLE_FOREST: Array[int] = [1000, 600, 800]

# random draw purposes
const P_CLIMATE := 1
const P_FLOOD := 2
const P_GROW := 3
const P_DISCOVER := 4
const P_LOSE := 5
const P_FOUND := 6
const P_RAID := 7
const P_TRADE := 8
const P_NAME := 9
const P_PLACE := 10
const P_SPREAD := 11

# trades (bits)
const TR_FARMER := 1
const TR_WOODCUTTER := 2
const TR_MINER := 4
const TR_CARPENTER := 8
const TR_SMITH := 16
const TR_HERBALIST := 32

# knowledge
const T_FIRE := 0
const T_FARMING := 1
const T_POTTERY := 2
const T_CHARCOAL := 3
const T_COPPER := 4
const T_MILL := 5
const T_BREAD := 6
const T_IRON := 7
const T_WRITING := 8
const T_BOATS := 9
const T_MEDICINE := 10
const NT := 11
const ALL_TECH := (1 << NT) - 1
const TECH_NEEDS: Array[int] = [0, 1, 1, 1, 8, 2, 36, 24, 4, 16, 256]
const TECH_TRADE: Array[int] = [0, 0, 0, TR_WOODCUTTER, TR_MINER, TR_CARPENTER, 0, TR_SMITH, 0, TR_CARPENTER, TR_HERBALIST]
const TECH_MIN_POP: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 90, 0, 0]

# chronicle events
const E_FOUNDED := 0
const E_DROUGHT := 1
const E_FLOOD_HELD := 2
const E_FLOOD := 3
const E_HUNGER := 4
const E_DISCOVERY := 5
const E_REDISCOVERY := 6
const E_FORGOT := 7
const E_AID := 8
const E_RAID := 9
const E_LEARNED := 10
const E_RUIN := 11
const E_WARNED := 12
const E_TAUGHT := 13
const E_GIFT := 14
const E_FELLED := 15
const E_BRIDGE := 16
const E_STORM := 17

# player actions: PackedInt32Array [year, player, seq, kind, target, a, b]
const A_WARN := 1     # a = years of dykes
const A_TEACH := 2    # a = tech
const A_GIFT := 3     # a = grain
const A_FELL := 4     # a = grain lost
const A_BRIDGE := 5
const A_STORM := 6    # a = share folded (per mille), b = the year it is folded into

const SYL: Array[String] = ["ar", "bel", "cor", "dun", "el", "fen", "gar", "hol", "is", "kel", "lor", "mor", "nor", "or", "pel", "ran", "sil", "tor", "ul", "ven", "wen", "yr", "ash", "brin"]

const M32 := 0xFFFFFFFF
const REL_STRIDE := 4096      # relation key = from * 4096 + to
const NEAR2 := 200 * 200      # 20 map units: shares land
const REACH2 := 450 * 450     # 45 map units: can trade or raid overland
const START_FOOD := 20
const FNV := 2166136261

# ---------- state ----------
var seed_value := 0
var base := 0
var year := 0
var n := 0
var people := PackedInt32Array()
var x := PackedInt32Array()
var y := PackedInt32Array()
var pop := PackedInt32Array()
var food := PackedInt32Array()
var tech := PackedInt32Array()
var lost := PackedInt32Array()
var river := PackedInt32Array()
var ore := PackedInt32Array()
var founded := PackedInt32Array()
var parent := PackedInt32Array()
var ruined := PackedInt32Array()
var had_mill := PackedInt32Array()
var flood_proof := PackedInt32Array()
var era := PackedInt32Array()
var enclave_of := PackedInt32Array()
var names := PackedStringArray()
var rel := {}   # int key (from * REL_STRIDE + to) -> int

# the chronicle: one row per event, and a running hash over every event
var ev_year := PackedInt32Array()
var ev_type := PackedInt32Array()
var ev_sub := PackedInt32Array()
var ev_other := PackedInt32Array()
var ev_a := PackedInt32Array()
var ev_b := PackedInt32Array()
var ev_c := PackedInt32Array()
var ev_hash := FNV

# Derived, not state: pairwise geometry, cached because settlements never move. One byte per pair,
# grown as settlements are founded and rebuilt after a snapshot. Not hashed, not saved.
const GEO_REACH := 1   # same land, close enough to trade or raid overland
const GEO_NEAR := 2    # same land, close enough to share fields
const GEO_SEA := 4     # different lands: reachable only with boats on both shores
var _geo := PackedByteArray()
var _geo_stride := 0
var _geo_n := 0
var _near: Array[PackedInt32Array] = []   # per settlement: same-land settlements sharing its fields (itself included)



# ---------- randomness ----------
## One step of the keyed hash chain: mix(h ^ k), lowbias32, all mod 2^32. The multiply by
## 0x846ca68b is split so no product leaves 63 bits (GDScript ints are signed 64-bit).
static func key(h: int, k: int) -> int:
	h ^= k & M32
	h = ((h ^ (h >> 16)) * 0x7feb352d) & M32
	h ^= h >> 15
	h = (h * 0x046ca68b + ((h & 1) << 31)) & M32
	return h ^ (h >> 16)


static func ppm(d: int) -> int:
	return (d * 1000000) >> 32


static func pick(d: int, count: int) -> int:
	return (d * count) >> 32


static func has(mask: int, t: int) -> bool:
	return ((mask >> t) & 1) == 1


## 1000 * sqrt(v), floored: a table for the usual crowd sizes, integer Newton iteration beyond it.
## (A table, not a cache, so worker threads share nothing mutable.)
const SQRT1000: Array[int] = [0, 1000, 1414, 1732, 2000, 2236, 2449, 2645, 2828, 3000, 3162, 3316, 3464, 3605, 3741, 3872, 4000, 4123, 4242, 4358, 4472, 4582, 4690, 4795, 4898, 5000, 5099, 5196, 5291, 5385, 5477, 5567, 5656, 5744, 5830, 5916, 6000, 6082, 6164, 6244, 6324, 6403, 6480, 6557, 6633, 6708, 6782, 6855, 6928, 7000, 7071, 7141, 7211, 7280, 7348, 7416, 7483, 7549, 7615, 7681, 7745, 7810, 7874, 7937]

@warning_ignore("integer_division")
static func sqrt1000(v: int) -> int:
	if v < SQRT1000.size():
		return SQRT1000[v]
	var m := v * 1000000
	var a := m
	var b := (a + 1) / 2
	while b < a:
		a = b
		b = (a + m / a) / 2
	return a


# ---------- creation ----------
## World.new(seed) makes year 0; World.new() makes an empty shell (used by snapshot()).
func _init(p_seed: int = -1) -> void:
	if p_seed < 0:
		return
	seed_value = p_seed & M32
	base = key(seed_value, 0x9e3779b9)   # mix(seed ^ 0x9e3779b9)
	var h0 := key(base, 0)
	for p in 3:
		for i in 4:
			var h_k := key(h0, p * 10 + i)
			var h_p := key(h_k, P_PLACE)
			_add_settlement(p, pick(key(h_p, 0), 1000), pick(key(h_p, 1), 1000), 18 + pick(key(h_k, P_GROW), 12), -1, false)


func _add_settlement(p_people: int, px: int, py: int, p_pop: int, p_parent: int, quiet: bool) -> int:
	var id := n
	n += 1
	var h_i := key(key(base, 0), id)
	var h_p := key(h_i, P_PLACE)
	people.append(p_people)
	x.append(px)
	y.append(py)
	pop.append(p_pop)
	food.append(START_FOOD)
	tech.append(1 << T_FIRE)
	lost.append(0)
	river.append(1 if ppm(key(h_p, 2)) < 450000 else 0)
	ore.append(1 if ppm(key(h_p, 3)) < 300000 else 0)
	founded.append(year)
	parent.append(p_parent)
	ruined.append(-1)
	had_mill.append(0)
	flood_proof.append(0)
	era.append(-1)
	enclave_of.append(-1)
	var h_n := key(h_i, P_NAME)
	var syl := 2 + pick(key(h_n, 0), 2)
	var s := ""
	for i in syl:
		s += SYL[pick(key(h_n, i + 1), SYL.size())]
	names.append(s.substr(0, 1).to_upper() + s.substr(1))
	if not quiet:
		_event(E_FOUNDED, id, p_parent, 0, 0, 0)
	return id


func _event(type: int, sub: int, other: int, a: int, b: int, c: int) -> void:
	ev_year.append(year)
	ev_type.append(type)
	ev_sub.append(sub)
	ev_other.append(other)
	ev_a.append(a)
	ev_b.append(b)
	ev_c.append(c)
	var h := ev_hash
	h = key(h, year)
	h = key(h, type)
	h = key(h, sub)
	h = key(h, other)
	h = key(h, a)
	h = key(h, b)
	ev_hash = key(h, c)


func rel_get(a: int, b: int) -> int:
	return rel.get(a * REL_STRIDE + b, 0)


func _trades_of(s: int) -> int:
	var pp := people[s]
	var p_pop := pop[s]
	var t := TR_FARMER
	if PEOPLE_FOREST[pp] > 500:
		t |= TR_WOODCUTTER
	if PEOPLE_ORE[pp] > 400 or ore[s] == 1:
		t |= TR_MINER
	if p_pop >= 30:
		t |= TR_CARPENTER
	if has(tech[s], T_COPPER) and p_pop >= 45:
		t |= TR_SMITH
	if p_pop >= 60:
		t |= TR_HERBALIST
	return t


## Extends the geometry cache to every settlement (positions and peoples never change).
func _ensure_geo() -> void:
	if _geo_n == n:
		return
	if n > _geo_stride:
		var stride := maxi(64, _geo_stride * 2)
		while stride < n:
			stride *= 2
		_geo_stride = stride
		_geo = PackedByteArray()
		_geo.resize(stride * stride)
		_geo_n = 0
		_near.clear()
	for i in range(_geo_n, n):
		_near.append(PackedInt32Array())
		for j in i + 1:
			var v := GEO_SEA
			if PEOPLE_LAND[people[i]] == PEOPLE_LAND[people[j]]:
				var dx := x[i] - x[j]
				var dy := y[i] - y[j]
				var d := dx * dx + dy * dy
				v = (GEO_REACH if d < REACH2 else 0) | (GEO_NEAR if d < NEAR2 else 0)
			_geo[i * _geo_stride + j] = v
			_geo[j * _geo_stride + i] = v
			if (v & GEO_NEAR) != 0:
				var li := _near[i]
				li.append(j)
				_near[i] = li
				if j != i:
					var lj := _near[j]
					lj.append(i)
					_near[j] = lj
	_geo_n = n


func _can_reach(a: int, b: int) -> bool:
	var g := _geo[a * _geo_stride + b]
	if (g & GEO_REACH) != 0:
		return true
	# across the sea only with boats on both shores
	return (g & GEO_SEA) != 0 and ((tech[a] >> T_BOATS) & 1) == 1 and ((tech[b] >> T_BOATS) & 1) == 1


## Land is shared with close neighbours, so crowding caps growth. Counts the settlements that were
## alive at the start of the year (id below n_start, never revived within a year) and still are.
@warning_ignore("integer_division")
func _capacity(s: int, n_start: int) -> int:
	var crowd := 0
	for o: int in _near[s]:
		if o < n_start and pop[o] > 0:
			crowd += 1
	var t := tech[s]
	var b := 110 + (50 if has(t, T_FARMING) else 0) + (50 if has(t, T_BREAD) else 0) + (25 if has(t, T_IRON) else 0)
	return (b * PEOPLE_FERTILE[people[s]]) / sqrt1000(crowd)


static func _clamp_pos(v: int) -> int:
	return 0 if v < 0 else (1000 if v > 1000 else v)


# ---------- one year ----------
@warning_ignore("integer_division")
func step(acts: Array, hist: Object) -> void:
	var yr := year
	for act: PackedInt32Array in acts:
		_apply(act, hist)
	var alive := PackedInt32Array()
	for i in n:
		if pop[i] > 0:
			alive.append(i)
	_ensure_geo()
	var n_start := n
	var h_y := key(base, yr)
	for s: int in alive:
		if pop[s] <= 0:
			continue   # killed earlier this year (a raid); ruined below
		var pp := people[s]
		var h_s := key(h_y, s)
		var tr := _trades_of(s)
		# climate
		var climate := 1000
		if ppm(key(h_s, P_CLIMATE)) < 60000:
			climate = 550
			_event(E_DROUGHT, s, -1, 0, 0, 0)
		if river[s] == 1 and ppm(key(h_s, P_FLOOD)) < 25000:
			if flood_proof[s] > yr:
				_event(E_FLOOD_HELD, s, -1, 0, 0, 0)
			else:
				var gone := (pop[s] + 3) / 4   # a quarter, rounded up
				pop[s] -= gone
				var mill := 1 if has(tech[s], T_MILL) else 0
				_event(E_FLOOD, s, -1, gone, mill, 0)
				if mill == 1:
					tech[s] &= ~((1 << T_MILL) | (1 << T_BREAD))
					lost[s] |= 1 << T_MILL
				if pop[s] <= 0:
					continue
		# food
		var t := tech[s]
		var prod := PEOPLE_FERTILE[pp] + (220 if has(t, T_FARMING) else 0) + (180 if has(t, T_BREAD) else 0) + (80 if has(t, T_IRON) else 0) + (40 if has(t, T_MEDICINE) else 0)
		var cap := _capacity(s, n_start)
		var p0 := pop[s]
		var worked := mini(p0, cap)
		var made := ((worked * prod + (p0 - worked) * 700) * climate) / 1000000
		food[s] += made - p0
		if food[s] > p0 * 2:
			food[s] = p0 * 2
		var h_g := key(h_s, P_GROW)
		if food[s] >= 0:
			var g := 20000 + pick(h_g, 30000)   # 2-5% a year
			pop[s] += maxi(1, (p0 * g) / 1000000)
		else:
			var loss_ppm := 60000 + pick(h_g, 100000)   # 6-16%
			var loss := maxi(1, (p0 * loss_ppm) / 1000000)
			pop[s] -= loss
			food[s] = 0
			_event(E_HUNGER, s, -1, loss, 0, 0)
			_raid_or_plead(s, alive, h_s)
		# knowledge: discover, then lose
		var missing := ALL_TECH & ~tech[s]   # knowledge found in this loop is always its own bit
		var h_d := key(h_s, P_DISCOVER) if missing != 0 else 0
		for k in range(1, NT if missing != 0 else 1):
			if ((missing >> k) & 1) == 0:
				continue
			var have := tech[s]
			var needs := TECH_NEEDS[k]
			if (have & needs) != needs:
				continue
			if TECH_TRADE[k] != 0 and (tr & TECH_TRADE[k]) == 0:
				continue
			if TECH_MIN_POP[k] != 0 and pop[s] < TECH_MIN_POP[k]:
				continue
			var again := ((lost[s] >> k) & 1) == 1   # rediscovery is easier: the ruins remember
			var chance := ((60000 if again else 18000) * mini(pop[s], 120)) / 40
			if ppm(key(h_d, k)) < chance:
				tech[s] |= 1 << k
				if k == T_MILL:
					had_mill[s] = 1
				_event(E_REDISCOVERY if again else E_DISCOVERY, s, -1, k, 0, 0)
		if pop[s] < 15 and tech[s] > 3:
			var top := _top_bit(tech[s])
			if top > 0 and ppm(key(h_s, P_LOSE)) < 200000:
				tech[s] &= ~(1 << top)
				lost[s] |= 1 << top
				_event(E_FORGOT, s, -1, top, 0, 0)
		# a daughter village, while the land has room
		if pop[s] > 90 and pop[s] * 5 > cap * 4:
			var h_f := key(h_s, P_FOUND)
			if ppm(h_f) < 80000 and _count_on_land(alive, PEOPLE_LAND[pp]) < 12:
				pop[s] -= 40
				var d := _add_settlement(pp, _clamp_pos(x[s] + pick(key(h_f, 1), 301) - 150), _clamp_pos(y[s] + pick(key(h_f, 2), 301) - 150), 40, s, false)
				tech[d] = tech[s] & ~(1 << T_WRITING)   # settlers carry skills, not the scribes
				had_mill[d] = 1 if has(tech[d], T_MILL) else 0
	_trade(alive, h_y)
	for s: int in alive:
		if pop[s] <= 0:
			pop[s] = 0
			ruined[s] = yr
			_event(E_RUIN, s, -1, had_mill[s], 0, 0)
	year += 1


static func _top_bit(mask: int) -> int:
	for t in range(NT - 1, -1, -1):
		if ((mask >> t) & 1) == 1:
			return t
	return -1


func _count_on_land(alive: PackedInt32Array, land: int) -> int:
	var c := 0
	for o: int in alive:
		if pop[o] > 0 and PEOPLE_LAND[people[o]] == land:
			c += 1
	return c


@warning_ignore("integer_division")
func _raid_or_plead(s: int, alive: PackedInt32Array, h_s: int) -> void:
	var rich := -1
	for o: int in alive:
		if o == s or pop[o] <= 0 or food[o] <= 30 or not _can_reach(s, o):
			continue
		if rich < 0 or food[o] > food[rich]:
			rich = o   # ties keep the lower id
	if rich < 0:
		return
	var r := rel_get(s, rich)
	if r > 20:
		var gift := food[rich] / 3
		food[rich] -= gift
		food[s] += gift
		_event(E_AID, s, rich, gift, 0, 0)
	elif ppm(key(h_s, P_RAID)) < 350000:
		var take := food[rich] / 2
		food[rich] -= take
		food[s] += take
		var dead := mini(pop[rich], 1 + (pop[rich] * 5) / 100)
		pop[rich] -= dead
		rel[s * REL_STRIDE + rich] = r - 40
		rel[rich * REL_STRIDE + s] = rel_get(rich, s) - 60
		_event(E_RAID, s, rich, dead, take, 0)


func _trade(alive: PackedInt32Array, h_y: int) -> void:
	var count := alive.size()
	for i in count:
		var a := alive[i]
		if pop[a] <= 0:
			continue   # trading never changes population, so this holds for the whole row
		var row := a * _geo_stride
		for j in range(i + 1, count):
			var b := alive[j]
			if pop[b] <= 0:
				continue
			var g := _geo[row + b]
			if (g & GEO_REACH) == 0:
				# across the sea only with boats on both shores (a may learn boats earlier in this row)
				if (g & GEO_SEA) == 0 or ((tech[a] >> T_BOATS) & 1) == 0 or ((tech[b] >> T_BOATS) & 1) == 0:
					continue
			var ab := a * REL_STRIDE + b
			var r_ab: int = rel.get(ab, 0)
			if r_ab < -30:
				continue
			# key(h_y, a * 1000 + b) and key(h_pair, P_TRADE), inlined: the hottest line in the kernel
			var h := h_y ^ (a * 1000 + b)
			h = ((h ^ (h >> 16)) * 0x7feb352d) & M32
			h ^= h >> 15
			h = (h * 0x046ca68b + ((h & 1) << 31)) & M32
			var h_pair := h ^ (h >> 16)
			h = h_pair ^ P_TRADE
			h = ((h ^ (h >> 16)) * 0x7feb352d) & M32
			h ^= h >> 15
			h = (h * 0x046ca68b + ((h & 1) << 31)) & M32
			if (((h ^ (h >> 16)) * 1000000) >> 32) >= 250000:
				continue
			var ba := b * REL_STRIDE + a
			rel[ab] = mini(100, r_ab + 3)
			rel[ba] = mini(100, rel.get(ba, 0) + 3)
			# knowledge travels with traders
			var h_sp := key(h_pair, P_SPREAD)
			for k in range(1, NT):
				var ha := ((tech[a] >> k) & 1) == 1
				if ha == (((tech[b] >> k) & 1) == 1):
					continue
				var from := a if ha else b
				var to := b if ha else a
				if (tech[to] & TECH_NEEDS[k]) != TECH_NEEDS[k]:
					continue
				if ppm(key(h_sp, k)) < 50000:
					tech[to] |= 1 << k
					if k == T_MILL:
						had_mill[to] = 1
					_event(E_LEARNED, to, from, k, 0, 0)


# ---------- actions: what players (and storms) do, in any era ----------
@warning_ignore("integer_division")
func _apply(act: PackedInt32Array, hist: Object) -> void:
	var s := act[4]
	if s < 0 or s >= n or pop[s] <= 0:
		return
	var a := act[5]
	match act[3]:
		A_WARN:
			flood_proof[s] = year + a
			_event(E_WARNED, s, -1, a, 0, 0)
		A_TEACH:
			if a < 1 or a >= NT:
				return
			tech[s] |= 1 << a
			if a == T_MILL:
				had_mill[s] = 1
			_event(E_TAUGHT, s, -1, a, 0, 0)
		A_GIFT:
			food[s] += a
			_event(E_GIFT, s, -1, a, 0, 0)
		A_FELL:
			food[s] -= a
			_event(E_FELLED, s, -1, a, act[1], 0)
		A_BRIDGE:
			for k: int in rel.keys():
				if k / REL_STRIDE == s:
					rel[k] = rel[k] + 10
			_event(E_BRIDGE, s, -1, 0, act[1], 0)
		A_STORM:
			_storm_enclave(s, a, act[6], hist)


## A time storm turns part of a village into its own past. The district's present residents are
## displaced; the people of `past_year` stand in their place with that year's knowledge, food and
## grudges. Both claim the same fields and the same name. Nothing scripts a fight: any conflict
## comes from the ordinary rules. The kernel computes the past itself, so the logged action is
## only (target, share, year).
@warning_ignore("integer_division")
func _storm_enclave(origin: int, share_pm: int, past_year: int, hist: Object) -> void:
	if hist == null or past_year < 0 or past_year >= year or share_pm <= 0 or share_pm > 1000:
		return
	var then: RefCounted = hist.state_at(past_year)
	if origin >= then.n or then.pop[origin] <= 0:
		return   # the village did not exist yet
	var gone := (pop[origin] * share_pm) / 1000
	pop[origin] -= gone
	var e := _add_settlement(people[origin], _clamp_pos(x[origin] + 20), _clamp_pos(y[origin] + 10), maxi(8, (then.pop[origin] * share_pm) / 1000), origin, true)
	names[e] = "Old " + names[origin]
	var past_tech: int = then.tech[origin]
	tech[e] = past_tech
	had_mill[e] = 1 if has(past_tech, T_MILL) else 0
	era[e] = past_year
	enclave_of[e] = origin
	food[e] = (then.food[origin] * share_pm) / 1000
	for k: int in then.rel.keys():
		if k / REL_STRIDE == origin:
			rel[e * REL_STRIDE + k % REL_STRIDE] = then.rel[k]
	var gap := year - past_year
	var pride := 10 if (past_tech & ~tech[origin]) != 0 else 0   # "you let the mill fall"
	rel[e * REL_STRIDE + origin] = -10 - gap / 10 - pride
	rel[origin * REL_STRIDE + e] = -10 - gap / 20
	_event(E_STORM, e, origin, gone, past_year, pop[e])


# ---------- snapshots and hashing ----------
## A copy of the state without the chronicle rows (events stay with the run that made them); the
## running event hash is kept, so a resumed world hashes the same as one run from year 0.
func snapshot() -> RefCounted:
	var c: RefCounted = get_script().new()
	c.seed_value = seed_value
	c.base = base
	c.year = year
	c.n = n
	c.people = people.duplicate()
	c.x = x.duplicate()
	c.y = y.duplicate()
	c.pop = pop.duplicate()
	c.food = food.duplicate()
	c.tech = tech.duplicate()
	c.lost = lost.duplicate()
	c.river = river.duplicate()
	c.ore = ore.duplicate()
	c.founded = founded.duplicate()
	c.parent = parent.duplicate()
	c.ruined = ruined.duplicate()
	c.had_mill = had_mill.duplicate()
	c.flood_proof = flood_proof.duplicate()
	c.era = era.duplicate()
	c.enclave_of = enclave_of.duplicate()
	c.names = names.duplicate()
	c.rel = rel.duplicate()
	c.ev_hash = ev_hash
	return c


## Hash of the whole state plus every event so far, as 8 hex digits (same as kernel.mjs hashWorld).
func hash_hex() -> String:
	var h := key(FNV, year)
	h = key(h, n)
	for i in n:
		h = key(h, people[i])
		h = key(h, x[i])
		h = key(h, y[i])
		h = key(h, pop[i])
		h = key(h, food[i])
		h = key(h, tech[i])
		h = key(h, lost[i])
		h = key(h, river[i])
		h = key(h, ore[i])
		h = key(h, founded[i])
		h = key(h, parent[i])
		h = key(h, ruined[i])
		h = key(h, had_mill[i])
		h = key(h, flood_proof[i])
		h = key(h, era[i])
		h = key(h, enclave_of[i])
	var keys := rel.keys()
	keys.sort()
	for k: int in keys:
		h = key(h, k)
		h = key(h, rel[k])
	h = key(h, ev_hash)
	return "%08x" % h
