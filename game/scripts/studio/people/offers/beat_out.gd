extends "res://scripts/studio/people/offer.gd"
## Your own flames first (desk 6 Oct: "helping a burning friend is brave and risky ... death comes only if you stay in
## it"). Someone burning beats the flames out on their own body. It answers their own burning, outranks helping anyone
## else (help_fire, intervene: up to 900) and yields to running for water only when the water is near (escape_fire 1200
## within its NEAR_WATER, else 1100), so a helper who catches fire stops helping. Found by the port probe: Tomas, alight
## beside his burning friend, kept choosing help_fire, or ran for a far well, and burned to death (6 Oct).
const ID := "beat_out"
const ANSWERS := ["fire","burning"]
const ROLES := ["burning victim"]
const PRIORITY := 5
const BEATING_S := 1.0          # (1.5 s left a helper downed at hurt 70 in his own flames: down while alight is death)
func can(me: Dictionary,a: Dictionary) -> bool:
	return own_fire(me,a)
func score(_me: Dictionary,_a: Dictionary) -> int:
	return 1150
func steps(me: Dictionary,a: Dictionary) -> Array:
	# The words come after: a say step waits for its line to be spoken (about 1.5 s in the probe), time a man alight
	# does not have (6 Oct probe: flames out at 9.3 s against the hurt-70 down at 10.5 s; the beating starts at once now).
	return [{"op":"wait","seconds":BEATING_S},     # slapping at your own flames takes a while: they burn meanwhile
		{"op":"use","verb":"extinguish","target":me.key,"method":"beat","cause_id":a.deed},
		{"op":"say","text":"Off! Get off me!"},
		{"op":"wait","seconds":1.0}]
func lasts(_me: Dictionary,_a: Dictionary) -> float:
	return 12.0

## Is it my own burning? The account is about me, or I felt it: a fire that spread to me from someone I saw catch it
## carries that first ignition's deed, so it joins my account of their fire (target them) as a felt facet (6 Oct probe:
## Tomas, alight from his friend's flames, never answered his own).
static func own_fire(me: Dictionary,a: Dictionary) -> bool:
	if a.target==me.key and a.evidence.get("act","") in ["burn","burning"]:
		return true
	for f: Dictionary in a.get("facets",{}).values():
		var e: Dictionary=f.get("evidence",{})
		if str(f.get("via",""))=="felt" and (str(e.get("act","")) in ["burn","burning"] or str(e.get("condition",""))=="burning"):
			return true
	return false
