extends RefCounted
## The action log, checkpoints and the past on demand. The world at any year is computed, never
## stored: from year 0, or from the nearest checkpoint. Mirrors History in kernel.mjs.

const World := preload("res://scripts/studio/kernel/world.gd")

var seed_value := 0
var every := 25
var by_year := {}        # year -> Array of actions, in canonical order
var checkpoints := {}    # year -> World snapshot


## actions: PackedInt32Array rows [year, player, seq, kind, target, a, b], in any arrival order.
func _init(p_seed: int, actions: Array = [], p_every: int = 25) -> void:
	seed_value = p_seed
	every = p_every
	by_year = canonical(actions)


## Sorts by every field, so two phones that received the same actions in different orders
## compute the same world.
static func canonical(actions: Array) -> Dictionary:
	var sorted := actions.duplicate()
	sorted.sort_custom(func(p: PackedInt32Array, q: PackedInt32Array) -> bool:
		for i in 7:
			if p[i] != q[i]:
				return p[i] < q[i]
		return false)
	var out := {}
	for act: PackedInt32Array in sorted:
		if not out.has(act[0]):
			out[act[0]] = []
		out[act[0]].append(act)
	return out


## Runs from year 0 to `to_year`, keeping a checkpoint every `every` years.
func run(to_year: int) -> World:
	var w := World.new(seed_value)
	while w.year < to_year:
		if w.year % every == 0:
			checkpoints[w.year] = w.snapshot()
		w.step(by_year.get(w.year, []), self)
	return w


## The world as it stood at `year`, from the nearest checkpoint (never from year 0).
@warning_ignore("integer_division")
func state_at(p_year: int) -> World:
	return resume(checkpoints[(p_year / every) * every], p_year)


func resume(cp: World, to_year: int) -> World:
	var w: World = cp.snapshot()
	while w.year < to_year:
		w.step(by_year.get(w.year, []), self)
	return w
