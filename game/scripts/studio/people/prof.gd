extends RefCounted
## Per-owner script time for the storm crowd check (merge/storm_crowd_check.gd reads Engine meta "prof", microseconds
## per owner, and clears it each frame). Off unless the run has --studio-prof: then a part costs one ticks call.
##   var t := Prof.now()  ...  Prof.add("crowd.step", t)

static var on := "--studio-prof" in OS.get_cmdline_user_args()


static func now() -> int:
	return Time.get_ticks_usec() if on else 0


## Adds the time since `since` to `owner`; returns now (for the next part).
static func add(owner: String, since: int) -> int:
	if not on:
		return 0
	var t := Time.get_ticks_usec()
	var prof: Dictionary = Engine.get_meta("prof", {})
	prof[owner] = float(prof.get(owner, 0.0)) + float(t - since)
	Engine.set_meta("prof", prof)
	return t
