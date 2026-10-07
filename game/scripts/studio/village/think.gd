class_name Think
extends Node
## One think budget per frame (Hilmi, 6 Oct: "think far less frequently but more impactful", "with semi async
## processing for them to even out the cost"; plan/SMOOTHNESS-TUNING-2026-10-06.md). Villagers' periodic work -
## re-plans, steering, regard, noticing - is registered here and run round-robin within a per-frame time budget,
## interrupts first. Cooperative time-slicing on the main thread, not threads: every change to the village still goes
## through acceptance and the journal, in order.
##
##   Think.every(owner, kind, period, work)   work.call(elapsed: float) every `period` seconds, staggered by owner
##   Think.now(owner, kind := "", reason)     due at once, ahead of the queue (an event: hit, harm seen, spoken to)
##   Think.once(owner, kind, work, delay)     one call, `delay` seconds from now (0: the next frame with room)
##   Think.forget(owner, kind := "")          stop one kind, or everything for that owner
##   Think.budget_ms                          the per-frame budget (default 4 ms; --think-budget=N for measurement)
##
## `owner` is any int or String (a villager's id, "wolf:12"); `kind` names the work ("plan", "steer", "notice").
## Each run is passed the seconds since its last run, so a body can integrate over a longer step.
##
## Order each frame: interrupts (Think.now) first, all of them, whatever the budget - an event is never left
## waiting; then the due periodic work, most overdue first, until the budget is spent. At least one due item runs
## each frame, so nothing starves; what does not fit waits for the next frame and is the most overdue there.
## First runs are staggered across the period by the owner's hash, so twenty villagers registered in one frame do
## not all think in the same frame.
##
## The driver node is added to the tree's root on first use, with an early process priority (thinking before the
## frame's movement and presentation). Stats for probes: Think.stats (ran, interrupts, deferred, late_max_ms,
## spent_ms_last, spent_ms_max, per-kind ms).

const DEFAULT_BUDGET_MS := 4.0

static var budget_ms := _budget_arg()
static var paused := false                 # (a probe or a frozen clock may hold all thinking)
static var manual := false                 # a headless test drives tick() itself: no driver node
static var stats := {"ran": 0, "interrupts": 0, "deferred": 0, "late_max_ms": 0.0, "spent_ms_last": 0.0, "spent_ms_max": 0.0, "kinds": {}}
static var _entries := {}                  # key "owner|kind" -> {owner, kind, period, work, next, last, urgent, once}
static var _clock := 0.0                   # seconds, advanced by the driver (or by a test's tick)
static var _driver: Node = null


static func _budget_arg() -> float:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--think-budget="):
			return float(arg.trim_prefix("--think-budget="))
	return DEFAULT_BUDGET_MS


static func every(owner: Variant, kind: String, period: float, work: Callable) -> void:
	_ensure_driver()
	var key := _key(owner, kind)
	var old: Dictionary = _entries.get(key, {})
	var first := _clock + period * _phase(owner, kind) if old.is_empty() else float(old.next)
	_entries[key] = {"owner": owner, "kind": kind, "period": maxf(period, 0.0), "work": work, "next": first,
		"last": float(old.get("last", _clock)), "urgent": bool(old.get("urgent", false)), "once": false, "reason": str(old.get("reason", ""))}


static func once(owner: Variant, kind: String, work: Callable, delay := 0.0) -> void:
	_ensure_driver()
	_entries[_key(owner, kind)] = {"owner": owner, "kind": kind, "period": 0.0, "work": work, "next": _clock + delay,
		"last": _clock, "urgent": false, "once": true, "reason": ""}


## Due at once, ahead of the queue. With no kind, every kind the owner has.
static func now(owner: Variant, kind := "", reason := "") -> void:
	for key: String in _entries:
		var e: Dictionary = _entries[key]
		if str(e.owner) == str(owner) and (kind == "" or e.kind == kind):
			e.urgent = true
			e.reason = reason


static func forget(owner: Variant, kind := "") -> void:
	for key: String in _entries.keys():
		var e: Dictionary = _entries[key]
		if str(e.owner) == str(owner) and (kind == "" or e.kind == kind):
			_entries.erase(key)


static func has(owner: Variant, kind: String) -> bool:
	return _entries.has(_key(owner, kind))


## The seconds until this work next runs (0: due now; -1: not registered).
static func due_in(owner: Variant, kind: String) -> float:
	var e: Dictionary = _entries.get(_key(owner, kind), {})
	return -1.0 if e.is_empty() else maxf(0.0, float(e.next) - _clock)


static func clear() -> void:
	_entries.clear()
	stats = {"ran": 0, "interrupts": 0, "deferred": 0, "late_max_ms": 0.0, "spent_ms_last": 0.0, "spent_ms_max": 0.0, "kinds": {}}


## One frame of thinking: the clock moves by dt, interrupts run, then due work until the budget is spent.
static func tick(dt: float) -> void:
	_clock += dt
	if paused:
		return
	var start := Time.get_ticks_usec()
	var limit := int(budget_ms * 1000.0)
	var urgent: Array = []
	var due: Array = []
	for key: String in _entries:
		var e: Dictionary = _entries[key]
		if e.urgent:
			urgent.append(key)
		elif float(e.next) <= _clock:
			due.append(key)
	due.sort_custom(func(a: String, b: String) -> bool: return float(_entries[a].next) < float(_entries[b].next))
	for key: String in urgent:
		if _entries.has(key):
			stats.interrupts = int(stats.interrupts) + 1
			_run(key)
	var ran := 0
	for key: String in due:
		if ran > 0 and Time.get_ticks_usec() - start >= limit:
			stats.deferred = int(stats.deferred) + 1
			continue
		if _entries.has(key):
			stats.late_max_ms = maxf(float(stats.late_max_ms), (_clock - float(_entries[key].next)) * 1000.0)
			_run(key)
			ran += 1
	var spent := float(Time.get_ticks_usec() - start) / 1000.0
	stats.spent_ms_last = spent
	stats.spent_ms_max = maxf(float(stats.spent_ms_max), spent)


static func _run(key: String) -> void:
	var e: Dictionary = _entries[key]
	var elapsed := _clock - float(e.last)
	e.last = _clock
	if e.once:
		_entries.erase(key)
	elif e.urgent or float(e.next) > _clock:
		e.next = _clock + float(e.period)   # an interrupt: a full period before the next ordinary run
	else:
		# The next run keeps the cadence (a late run does not push every later one back), never in the past.
		e.next = maxf(float(e.next) + float(e.period), _clock + float(e.period) * 0.5)
	e.urgent = false
	var t := Time.get_ticks_usec()
	if (e.work as Callable).is_valid():
		(e.work as Callable).call(elapsed)
	else:
		_entries.erase(key)                # its object is gone (a body freed)
	var kinds: Dictionary = stats.kinds
	kinds[e.kind] = float(kinds.get(e.kind, 0.0)) + float(Time.get_ticks_usec() - t) / 1000.0
	stats.ran = int(stats.ran) + 1


static func _key(owner: Variant, kind: String) -> String:
	return "%s|%s" % [str(owner), kind]


## Where in its period an owner's work first falls (0..1): a hash, so the same village staggers the same way.
static func _phase(owner: Variant, kind: String) -> float:
	return float(hash(_key(owner, kind)) & 0xffff) / 65536.0


static func _ensure_driver() -> void:
	if manual or is_instance_valid(_driver):
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return                             # a headless test drives tick() itself
	_driver = (load("res://scripts/studio/village/think.gd") as GDScript).new()
	_driver.name = "Think"
	_driver.process_priority = -100
	tree.root.add_child.call_deferred(_driver)


func _process(dt: float) -> void:
	if self == _driver:
		tick(dt)


## The tree is going (the game quits, or a test tears down): the statics let go of every callable and of this node
## now, while the objects they point at still exist. Left to the engine's own shutdown, statics outlive the scene
## and freeing them after it crashed the quit ("double free or corruption", 2 of 13 tuned runs, 6 Oct).
func _exit_tree() -> void:
	if self == _driver:
		_entries.clear()
		_driver = null
