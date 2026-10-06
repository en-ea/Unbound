extends RefCounted
## Who talks with whom (Pass 3, L5: "who chats with whom comes from who gets on, not id order"). Pure: people and how
## well each pair gets on in, conversations out. Generic: the affinity is the caller's (the village asks its rules'
## opinions, its households and ages).
##
##   Groups.form(people, affinity, most := 5) -> [[id, ...], ...]
##       people:   ids standing about together (at one place)
##       affinity: (a, b) -> float, about -100..100: how well a and b get on (they need not agree with each other)
##
## Greedy and stable: the most sociable start a conversation and draw in whoever gets on best with all of it; nobody
## joins a group they would rather not be in (below WELCOME with anyone already there), and nobody is left alone
## while a group would take them. Keyed by the ids only, so the same people at the same place make the same groups.
## n is a place's crowd (a few dozen at most): O(n^2) affinity calls.

const WELCOME := -15.0        # nobody joins a group with someone they get on with worse than this
const DRAW := 5.0             # mean affinity to the group needed to be drawn in (else they start their own)


static func form(people: Array, affinity: Callable, most := 5) -> Array:
	var left: Array = people.duplicate()
	left.sort()
	var table := {}           # [a, b] -> how a feels about b (each pair asked once each way)
	var feel := func(a: int, b: int) -> float:
		var key := a * 100003 + b
		if not table.has(key):
			table[key] = float(affinity.call(a, b))
		return table[key]
	var groups: Array = []
	while not left.is_empty():
		# the one who gets on best with everyone left starts the next conversation
		var seed: int = left[0]
		var seed_score := -INF
		for a: int in left:
			var s := 0.0
			for b: int in left:
				if a != b:
					s += feel.call(a, b) + feel.call(b, a)
			if s > seed_score:
				seed_score = s
				seed = a
		var group: Array = [seed]
		left.erase(seed)
		while group.size() < most:
			var best := -1
			var best_score := -INF
			for c: int in left:
				var worst := INF
				var mean := 0.0
				for g: int in group:
					var both := minf(feel.call(c, g), feel.call(g, c))
					worst = minf(worst, both)
					mean += (feel.call(c, g) + feel.call(g, c)) * 0.5
				mean /= group.size()
				if worst >= WELCOME and mean >= DRAW and mean > best_score:
					best_score = mean
					best = c
			if best < 0:
				break
			group.append(best)
			left.erase(best)
		groups.append(group)
	# nobody alone if a group would have them (a lone one joins the warmest group with room)
	var alone: Array = groups.filter(func(g: Array) -> bool: return g.size() == 1)
	for lone: Array in alone:
		var who: int = lone[0]
		var home: Array = []
		var warmest := -INF
		for g: Array in groups:
			if g.size() == 1 or g.size() >= most:
				continue
			var worst := INF
			var mean := 0.0
			for m: int in g:
				worst = minf(worst, minf(feel.call(who, m), feel.call(m, who)))
				mean += feel.call(who, m)
			if worst >= WELCOME and mean / g.size() > warmest:
				warmest = mean / g.size()
				home = g
		if not home.is_empty():
			home.append(who)
			groups.erase(lone)
	return groups
