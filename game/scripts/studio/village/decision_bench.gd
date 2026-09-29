extends RefCounted
## Spike S3 (village costs): what one villager decision costs in typed GDScript, to size the village
## plan's budgets. A synthetic stand-in for the planned decision layer, not the real rules:
## 30 villagers; each decision scores 16 actions with 4 considerations each (response curves as
## lookup tables, integer maths), 4 of the actions choose a target among all villagers, then the
## villager passes a belief to someone (a rumour step), and schedules its next decision in a heap.
## Run: godot --headless --path game --script res://scripts/studio/run.gd -- village/decision_bench
##      or on a phone: dev argument --studio=village/decision_bench (debug builds).

const N := 30            # villagers
const NEEDS := 8
const VALUES := 4
const ACTIONS := 16
const CONS := 4          # considerations per action
const TARGETED := 4      # actions that pick a target among the villagers
const BELIEFS := 32      # belief slots per villager
const CURVES := 8
const CURVE_LEN := 64
const M32 := 0xFFFFFFFF

var needs := PackedInt32Array()      # N * NEEDS, 0..1023
var values := PackedInt32Array()     # N * VALUES, 0..1023
var opinion := PackedInt32Array()    # N * N, -512..511
var belief_fact := PackedInt32Array()     # N * BELIEFS
var belief_strength := PackedInt32Array() # N * BELIEFS
var curves := PackedInt32Array()     # CURVES * CURVE_LEN, per mille
var cons_input := PackedInt32Array() # ACTIONS * CONS: which input feeds each consideration
var cons_curve := PackedInt32Array() # ACTIONS * CONS: which curve shapes it
var heap_time := PackedInt32Array()  # next-decision queue (binary heap by time, then id)
var heap_id := PackedInt32Array()
var seed_value := 12345
var chosen := PackedInt32Array()     # how often each action won (sanity: not one action always)


static func key(h: int, k: int) -> int:
	h ^= k & M32
	h = ((h ^ (h >> 16)) * 0x7feb352d) & M32
	h ^= h >> 15
	h = (h * 0x046ca68b + ((h & 1) << 31)) & M32
	return h ^ (h >> 16)


func _init() -> void:
	var h := key(seed_value, 1)
	needs.resize(N * NEEDS)
	values.resize(N * VALUES)
	opinion.resize(N * N)
	belief_fact.resize(N * BELIEFS)
	belief_strength.resize(N * BELIEFS)
	for i in needs.size():
		h = key(h, i)
		needs[i] = h & 1023
	for i in values.size():
		h = key(h, i + 7)
		values[i] = h & 1023
	for i in opinion.size():
		h = key(h, i + 13)
		opinion[i] = (h & 1023) - 512
	for i in belief_fact.size():
		h = key(h, i + 17)
		belief_fact[i] = h & 255
		belief_strength[i] = (h >> 8) & 1023
	curves.resize(CURVES * CURVE_LEN)
	for c in CURVES:          # a spread of shapes: rising, falling, S-like, thresholds
		for x in CURVE_LEN:
			var v := 0
			match c % 4:
				0: v = x * 1000 / (CURVE_LEN - 1)
				1: v = 1000 - x * 1000 / (CURVE_LEN - 1)
				2: v = (x * x * 1000) / ((CURVE_LEN - 1) * (CURVE_LEN - 1))
				3: v = 1000 if x > CURVE_LEN / 2 else 100
			curves[c * CURVE_LEN + x] = v
	cons_input.resize(ACTIONS * CONS)
	cons_curve.resize(ACTIONS * CONS)
	for i in cons_input.size():
		h = key(h, i + 23)
		cons_input[i] = h % (NEEDS + VALUES + 2)
		cons_curve[i] = (h >> 8) % CURVES
	chosen.resize(ACTIONS)
	for i in N:
		_heap_push(i, i)


## One decision for villager `a` at time `t`: score every action, pick the best (keyed tie-break),
## apply a small effect, pass on a belief, schedule the next decision.
@warning_ignore("integer_division")
func decide(a: int, t: int) -> void:
	var best := -1
	var best_score := -1
	var best_target := -1
	var h_a := key(key(seed_value, t), a)
	var nb := a * NEEDS
	var vb := a * VALUES
	for act in ACTIONS:
		var score := 1000
		var cb := act * CONS
		for c in CONS:
			var src := cons_input[cb + c]
			var x := 0
			if src < NEEDS:
				x = needs[nb + src]
			elif src < NEEDS + VALUES:
				x = values[vb + src - NEEDS]
			else:
				x = (t * 37 + a * 11) & 1023      # time of day, mood: stand-ins
			score = (score * curves[cons_curve[cb + c] * CURVE_LEN + (x >> 4)]) / 1000
			if score == 0:
				break                              # early out, as a real utility system does
		var target := -1
		if act < TARGETED and score > 0:          # pick who to steal from, accuse, befriend...
			var ob := a * N
			var tbest := -1000000
			for o in N:
				if o == a:
					continue
				var ts := -opinion[ob + o] + ((key(h_a, o) & 255) >> 2)
				if ts > tbest:
					tbest = ts
					target = o
			score = score * (tbest + 600) / 1000
		var tie := key(h_a, act) & 63
		if score * 64 + tie > best_score:
			best_score = score * 64 + tie
			best = act
			best_target = target
	chosen[best] += 1
	needs[nb + (best & 7)] = maxi(0, needs[nb + (best & 7)] - 200)   # acting eases a need
	for k in NEEDS:
		needs[nb + k] = mini(1023, needs[nb + k] + 9)
	if best_target >= 0:
		opinion[best_target * N + a] = clampi(opinion[best_target * N + a] - 8, -512, 511)
	# rumour step: tell your closest friend your strongest belief, sometimes garbled
	var ob2 := a * N
	var friend := -1
	var fo := -1000000
	for o in N:
		if o != a and opinion[ob2 + o] > fo:
			fo = opinion[ob2 + o]
			friend = o
	var bb := a * BELIEFS
	var strongest := bb
	for s in range(bb + 1, bb + BELIEFS):
		if belief_strength[s] > belief_strength[strongest]:
			strongest = s
	var slot := friend * BELIEFS + (key(h_a, 999) % BELIEFS)
	belief_fact[slot] = belief_fact[strongest] if (key(h_a, 1001) & 15) != 0 else (key(h_a, 1002) & 255)
	belief_strength[slot] = belief_strength[strongest] * 3 / 4
	_heap_push(t + 1 + (key(h_a, 77) & 3), a)


func _heap_push(t: int, id: int) -> void:
	heap_time.append(t)
	heap_id.append(id)
	var i := heap_time.size() - 1
	while i > 0:
		var p := (i - 1) >> 1
		if heap_time[p] < heap_time[i] or (heap_time[p] == heap_time[i] and heap_id[p] < heap_id[i]):
			break
		var tt := heap_time[p]
		heap_time[p] = heap_time[i]
		heap_time[i] = tt
		var ti := heap_id[p]
		heap_id[p] = heap_id[i]
		heap_id[i] = ti
		i = p


## Pops the earliest (time, id); returns [time, id].
func _heap_pop() -> PackedInt32Array:
	var out := PackedInt32Array([heap_time[0], heap_id[0]])
	var last := heap_time.size() - 1
	heap_time[0] = heap_time[last]
	heap_id[0] = heap_id[last]
	heap_time.resize(last)
	heap_id.resize(last)
	var i := 0
	var n := last
	while true:
		var l := i * 2 + 1
		var r := l + 1
		var m := i
		if l < n and (heap_time[l] < heap_time[m] or (heap_time[l] == heap_time[m] and heap_id[l] < heap_id[m])):
			m = l
		if r < n and (heap_time[r] < heap_time[m] or (heap_time[r] == heap_time[m] and heap_id[r] < heap_id[m])):
			m = r
		if m == i:
			break
		var tt := heap_time[m]
		heap_time[m] = heap_time[i]
		heap_time[i] = tt
		var ti := heap_id[m]
		heap_id[m] = heap_id[i]
		heap_id[i] = ti
		i = m
	return out


## Runs `count` decisions through the queue; returns microseconds taken.
func run(count: int) -> int:
	var t0 := Time.get_ticks_usec()
	for i in count:
		var e := _heap_pop()
		decide(e[1], e[0])
	return Time.get_ticks_usec() - t0


static func report() -> PackedStringArray:
	var lines := PackedStringArray()
	var b = (load("res://scripts/studio/village/decision_bench.gd") as GDScript).new()
	b.run(3000)   # warm up
	var counts: Array[int] = [30000, 30000, 30000]
	var times: Array[int] = []
	for c: int in counts:
		times.append(b.run(c))
	times.sort()
	var us_per: float = float(times[1]) / counts[1]
	lines.append("device: %s, %s; Godot %s" % [OS.get_model_name(), OS.get_processor_name(), Engine.get_version_info()["string"]])
	lines.append("one decision (16 actions x 4 considerations, 4 targeted over 30 villagers, a rumour step, a heap reschedule): %.2f us (median of 3 runs of 30,000)" % us_per)
	lines.append("  -> %d decisions per millisecond" % int(1000.0 / us_per))
	for per_day: int in [24, 96]:
		var day_us: float = us_per * N * per_day
		lines.append("  a village day, 30 villagers deciding %d times each: %.1f ms; a village year: %.2f s; 30 days away (catch-up): %.2f s" % [per_day, day_us / 1000.0, day_us * 365.0 / 1e6, day_us * 30.0 / 1e6])
	var spread := PackedStringArray()
	for a in b.chosen.size():
		spread.append(str(b.chosen[a]))
	lines.append("actions chosen (sanity - not one action always): " + " ".join(spread))
	return lines


## Phone entry (dev argument --studio=village/decision_bench): log lines and user://studio-village-decision_bench.txt.
static func on_device(tree: SceneTree) -> void:
	var lines := report()
	for s in lines:
		print("STUDIO ", s)
	var f := FileAccess.open("user://studio-village-decision_bench.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")
		f.close()
	tree.quit()
