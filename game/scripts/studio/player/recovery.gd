extends RefCounted
## C1 unit 4 (design section 3): stamina is retired (player/stamina.gd stays in the tree, unrouted), and recovery does
## its limiting. Numbers in Balance.RECOVERY. Pure: the callers (player.gd, fighter.gd, marked lines) pass the facts.
##   roll      after a roll, ROLL rest (his 0.25 s became 0.45 s). Rolls chain while each starts within ROLL_WINDOW of
##             the last one ending; the third in a chain waits ROLL_WAIT (a roll lasts 0.7 s and rests 0.45 s, so three
##             roll starts can never fall inside 2 s: the window is counted from the last landing)
##   heavy     the heavy swing is a commitment (no roll, no guard) for its swing and HEAVY after it
##   guard     a blocked blow of force >= GUARD_BREAK (push x 100: a bandit's lunge, a charge) breaks the guard: a
##             BREAK_STUN stagger and the blow lands at BREAK_TAKE
##   Well Rested (his sleep buff) makes the roll and heavy recoveries x RESTED
static func pace(rested: bool) -> float:
	return float(Balance.RECOVERY["rested"]) if rested else 1.0


## The chain a roll starting now joins: `chain` rolls so far, the last landing at `last_end` (s).
static func chain_after(chain: int, last_end: float, now: float) -> int:
	return chain + 1 if now - last_end <= float(Balance.RECOVERY["roll_window"]) else 1


## The rest after the roll that is `chain`-th in its chain.
static func roll_rest(chain: int, rested: bool) -> float:
	var wait := float(Balance.RECOVERY["roll_wait"]) if chain >= int(Balance.RECOVERY["roll_burst"]) else float(Balance.RECOVERY["roll"])
	return wait * pace(rested)


## How long the heavy swing holds him (its swing, then the recovery).
static func heavy_commit(swing: float, rested: bool) -> float:
	return swing + float(Balance.RECOVERY["heavy"]) * pace(rested)


## A blocked blow's force from his push (enemies push 3 .. 9 m/s; x 100 is the people's force scale).
static func force_of(push: Vector3) -> int:
	return roundi(Vector2(push.x, push.z).length() * 100.0)


static func breaks_guard(push: Vector3) -> bool:
	return force_of(push) >= int(Balance.RECOVERY["guard_break"])


## What a blow that breaks the guard still does (at least 1).
static func broken_damage(damage: int) -> int:
	return maxi(1, roundi(damage * float(Balance.RECOVERY["break_take"])))
