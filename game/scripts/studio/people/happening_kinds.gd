extends RefCounted
## How each kind of happening is played on the bodies (plan VILLAGE-LIFE-AND-NEWS section 6). The rules decide which
## phases happen, between whom and when (village/sim/happenings.gd: the record's path and phases); an entry here says
## what the bodies do in each phase. One entry a kind, one part a phase: a new kind is an entry here and one in the
## rules. Generic: roles, shapes, clips, loudness and rings, not villages.
##
## A phase:
##   shape   "pair"     the two face each other, a step apart (situation.gd's pair), the beats played in turn
##           "between"  the peacemaker steps into the middle, the two step back from each other (GAP_BETWEEN)
##           "apart"    each steps back and turns half away; then they go (the phase's end)
##           "address"  the speakers stand in a row at the middle, facing the crowd; on their beat one steps forward
##                      (STEP_FORWARD) and speaks, the others and the crowd turn to them
##           "disperse" it is over: everyone goes back to their day
##   beats   [[role, clip, seconds], ...]  played in order, then from the start again: "a", "b", "both", "peacemaker",
##           "elder", "all" (every speaker) (a clip "@nod" / "@wave" is the body's own gesture over whatever it plays)
##   lines   {role: line kind}  said aloud as the phase begins (the director's words for the kind; one voice at a time);
##           "{outcome}" in a line kind is the record's outcome (the rules' decision)
##   loud    metres the phase's voices carry (a stimulus while it lasts, its sound "raised_voices" or the phase's
##           own): who hears it may come to watch (draw_from: metres they come from, if not the voices: the bell)
##   draw    how many at most come to watch in this phase (0: none come; those there stay)
##   come    who comes: "bold" (the bold and curious; timid children stay away) or "all" (the bell calls everyone grown)
##   ring    [inner, outer] metres from the middle that those watching stand on
##   watch   the clips those watching take turns at, each on their own beat; watch_by {outcome: clips} instead, once
##           the rules have decided
##
## A kind's META: run_near (metres from the player within which it is played on the bodies), needs (the roles without
## which it is not played), late (it may be joined after it began: those coming walk in), lead (game minutes before its
## first phase that its cast set off), keep (someone taken by something higher - a word with the player, an answer to
## a blow - comes back to it when that is over, rather than being out of it), waits (its first phase waits, up to the
## runner's LATE, for the cast to arrive: two who argue must be face to face; a meeting gathers as they come)

const KINDS := {
	"argument": {
		"words": {"shape": "pair", "loud": 12.0, "draw": 2, "ring": [3.5, 6.0], "lines": {"a": "argue_words"},
			"beats": [["a", "Idle_Talking", 1.8], ["b", "Idle_No", 1.4], ["b", "Idle_Talking", 1.6], ["a", "Idle_No", 1.2]],
			"watch": ["Idle", "Idle_FoldArms"]},
		"heated": {"shape": "pair", "loud": 28.0, "draw": 7, "ring": [3.5, 6.5], "lines": {"a": "argue_heated", "b": "argue_heated"},
			"beats": [["a", "Spell_Simple_Shoot", 1.0], ["b", "Idle_No", 1.2], ["b", "Spell_Simple_Shoot", 1.0], ["a", "Idle_No", 1.0],
				["both", "Idle_FoldArms", 0.9], ["a", "Idle_Talking", 1.4]],
			"watch": ["Idle_FoldArms", "Idle_No", "Idle", "Yes"]},
		"blows": {"shape": "pair", "loud": 36.0, "draw": 9, "ring": [4.5, 7.5], "lines": {"a": "argue_blows"},
			"beats": [["a", "Push", 0.8], ["b", "Hit_Chest", 0.9], ["b", "Push", 0.8], ["a", "Hit_Chest", 0.9]],
			"watch": ["Idle_No", "Idle_FoldArms", "Idle"]},
		"parted": {"shape": "between", "loud": 10.0, "draw": 0, "ring": [4.0, 7.0], "lines": {"peacemaker": "part_them"},
			"beats": [["peacemaker", "Idle_No", 1.3], ["a", "Idle_FoldArms", 1.2], ["peacemaker", "Idle_Talking", 1.6], ["b", "Idle_No", 1.0]],
			"watch": ["Yes", "Idle", "Idle_FoldArms"]},
		"cooled": {"shape": "apart", "loud": 6.0, "draw": 0, "ring": [4.0, 7.0], "lines": {"b": "argue_last_word"},
			"beats": [["a", "Idle_No", 1.2], ["b", "Idle_FoldArms", 1.2]],
			"watch": ["Idle", "Yes"]},
	},
	"meeting": {
		"gather": {"shape": "address", "loud": 16.0, "sound": "crowd", "draw_from": 110.0, "draw": 14, "come": "all", "ring": [5.0, 9.5],
			"lines": {"elder": "meeting_call"},
			"beats": [["elder", "Idle_Talking", 2.2], ["all", "Idle", 2.6]],
			"watch": ["Idle", "Idle_FoldArms", "Idle_Talking", "Idle"]},
		"speak": {"shape": "address", "loud": 22.0, "draw_from": 40.0, "draw": 4, "come": "all", "ring": [5.0, 9.5],
			"lines": {"a": "meeting_plea", "b": "meeting_answer"},
			"beats": [["a", "Idle_Talking", 2.6], ["a", "Spell_Simple_Shoot", 1.0], ["b", "Idle_No", 1.2], ["b", "Idle_Talking", 2.4],
				["elder", "@nod", 0.9], ["a", "Idle_No", 1.2], ["b", "Idle_Talking", 1.8], ["elder", "Idle_Talking", 2.2]],
			"watch": ["Idle_FoldArms", "Yes", "Idle_No", "Idle"]},
		"decide": {"shape": "address", "loud": 22.0, "draw": 0, "ring": [5.0, 9.5], "lines": {"elder": "meeting_{outcome}"},
			"beats": [["elder", "Idle_Talking", 3.0], ["elder", "@nod", 1.0], ["all", "Idle", 1.6]],
			"watch": ["Idle"],
			"watch_by": {"share": ["Yes", "Idle", "Yes", "Idle_FoldArms"], "watch": ["Yes", "Idle_FoldArms", "Idle"],
				"nothing": ["Idle_No", "Idle_FoldArms", "Idle_No", "Spell_Simple_Shoot"]}},
		"disperse": {"shape": "disperse"},
	},
}
const META := {
	"argument": {"run_near": 45.0, "needs": ["a", "b"], "late": false, "lead": 0, "keep": false, "waits": true},
	"meeting": {"run_near": 90.0, "needs": ["elder"], "late": true, "lead": 14, "keep": true, "waits": false},
}
const GAP_BETWEEN := 1.4       # metres each of the two stands from the middle when someone steps between them
const GAP_APART := 2.2         # metres each steps back to when it cools
const ROW_GAP := 1.7           # metres between speakers standing in a row
const STEP_FORWARD := 0.9      # metres a speaker steps out of the row to speak


static func phase(kind: String, name: String) -> Dictionary:
	return KINDS.get(kind, {}).get(name, {})


static func meta(kind: String) -> Dictionary:
	return META.get(kind, META.argument)
