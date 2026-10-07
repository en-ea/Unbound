extends "res://scripts/studio/people/offer.gd"
const ID := "settle"
const ANSWERS := ["contact","threat","gift","fire"]
const ROLES := ["observer","recipient"]
const PRIORITY := 0
func can(_me: Dictionary, _a: Dictionary) -> bool:
	return true
func score(_me: Dictionary, a: Dictionary) -> int:
	return 800 if a.kind == "gift" else 100
func steps(me: Dictionary, a: Dictionary) -> Array:
	var line := "A fine day for keeping one's head down."
	if a.kind == "gift":
		line = "I will take the food. My memory is not for sale." if me.hits > 0 else "Thank you. That almost resembles kindness."
	elif a.kind=="fire" and a.via!="heard":
		line="That is an ambitious way to ask for warmth."
	elif a.via == "heard":
		# What was heard, in its own words: only blows are a scuffle.
		line = {"scream": "That scream... something terrible has happened.", "splash": "What was that splashing?",
			"crack": "Was that ice cracking? In this weather?", "thunder": "Thunder. That was close."}.get(str(a.evidence.get("act", "")), "Someone is arguing with their fists.")
	elif int(me.get("distraction",0)) > 0:
		line = "What happened? I was counting the dead flies."
	return [{"op":"face","target":a.target},{"op":"say","text":line},{"op":"wait","seconds":2.0}]
