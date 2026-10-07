extends Node
## The one world clock (merge-enea, Hilmi's revision 6): the game's time, owned by the core game (an autoload,
## WorldClock) and saved once (SaveGame's "clock"). Everything else reads it or catches up to it:
## - the sky (world/day_night.gd) shows its time of day; caves and beds act on it (set_time / skip move it forward);
## - a village keeps its own minute count (it starts after its generated history), so the clock holds each village's
##   offset (whole days, so the sky and the village agree on the time of day): the village is advanced to the clock's
##   minute plus its offset every frame, and catches up after a load or a return; a village a probe moved ahead pulls
##   the clock with it, so the clock never runs behind a village. Offsets live here, saved with the clock, not in
##   the village (nothing outside acceptance writes the village);
## - Enea's day timers (bounties, lettings, home, residents' work) count `step`, the world seconds this frame.
## One day is twelve real minutes (day_night.gd cycle_minutes, Bounties.DAY_SECS): 2 game minutes a second.
## It stands still while controls are locked (menus, shops), in the background and while saving is paused,
## as the village clock did.
const MINUTES_PER_SECOND := 2.0
const START := 432                  # 07:12, his time_of_day 0.3
var minute := START                 # whole game minutes since the world began
var fraction := 0.0                 # 0..1 of the next minute
var step := 0.0                     # world seconds this frame (0 while it stands still)
var _moved := 0.0                   # world seconds set_time/skip added since the last frame
var offsets := {}                   # village id (runtime.village) -> its minute when the clock reads 0


func _ready() -> void:
	process_priority = -60          # before the village (VillageSession -50) and the sky


func time_of_day() -> float:
	return fposmod(float(minute) + fraction, 1440.0) / 1440.0


func running() -> bool:
	return not Controls.locked and not SaveGame.paused and not VillageSession.background and not get_tree().paused


func _process(delta: float) -> void:
	step = _moved
	_moved = 0.0
	if not running():
		return
	step += delta
	fraction += delta * MINUTES_PER_SECOND
	var whole := int(fraction)
	if whole > 0:
		fraction -= whole
		minute += whole


## Forward by game minutes (a nap, a night's sleep, the dev button). Never backwards.
func advance(minutes: float) -> void:
	if minutes <= 0.0:
		return
	var total := fraction + minutes
	var whole := int(total)
	minute += whole
	fraction = total - whole
	_moved += minutes / MINUTES_PER_SECOND


## Forward to the next time this time of day (0..1) comes round.
func advance_to_time(t: float) -> void:
	advance(fposmod(fposmod(t, 1.0) * 1440.0 - (fposmod(float(minute), 1440.0) + fraction), 1440.0))


## A village ahead of the clock (a probe advanced it) pulls the clock up to it.
func not_behind(village_minute: int, village_fraction: float) -> void:
	if village_minute > minute or (village_minute == minute and village_fraction > fraction):
		minute = village_minute
		fraction = village_fraction


## The minute a village should be at now; a village the clock has not met yet is joined at its own minute, its
## offset rounded down to whole days so its time of day stays the clock's.
func village_minute(village_id: String, village_now: int) -> int:
	if not offsets.has(village_id):
		offsets[village_id] = village_now - minute - posmod(village_now - minute, 1440)
	return minute + int(offsets[village_id])


func to_data() -> Dictionary:
	return {"minute": minute, "fraction": fraction, "villages": offsets.duplicate()}


## From a save: its "clock". A save from before it (his, or an earlier studio one) starts from its time of day on day 0;
## a village it holds is then joined at its own minute (village_minute), its time of day becoming the clock's.
func load_data(data: Dictionary) -> void:
	var clock: Variant = data.get("clock")
	offsets = {}
	if clock is Dictionary:
		minute = int(clock.get("minute", START))
		fraction = clampf(float(clock.get("fraction", 0.0)), 0.0, 0.999999)
		var saved: Variant = clock.get("villages", {})
		if saved is Dictionary:
			for k: Variant in saved:
				offsets[str(k)] = int(saved[k])
	else:
		var t := float(data.get("time_of_day", 0.3)) * 1440.0
		minute = int(t)
		fraction = t - minute


func reset() -> void:
	offsets = {}
	minute = START
	fraction = 0.0
	step = 0.0
	_moved = 0.0
