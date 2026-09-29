extends RefCounted
## A compact transition from the existing world kernel into an ordinary village storm.
const History := preload("res://scripts/studio/kernel/history.gd")
const World := preload("res://scripts/studio/kernel/world.gd")

static func transition(seed: int, cycle: int) -> Dictionary:
	var epoch := 20 + cycle
	var action := PackedInt32Array([epoch, 0, cycle, World.A_STORM, 0, 333, 0])
	var world: World = History.new(seed, [action]).run(epoch + 1)
	var i := world.ev_type.rfind(World.E_STORM)
	if i < 0:
		return {}
	return {"epoch": epoch, "source": world.ev_other[i], "enclave": world.ev_sub[i],
		"displaced": world.ev_a[i], "past": world.ev_b[i], "hash": world.hash_hex()}
