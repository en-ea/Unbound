extends Node
## Village houses you can buy and let out (game state, no visuals). Each one you own has a tenant who pays
## rent every in-game day; it waits for you (up to Balance.LETTINGS "days" of it) until you collect it at
## the house's sign or your mailbox. Doing a house up (levels 1..3) furnishes it better and raises its rent.
## The houses stand in the meadow village (world/village.gd HOUSES, by index); you can look inside any time
## (world/visit_interior.gd). Numbers: Balance.LETTINGS.
## Each house has its tenant (TENANTS, villagers in state/npcs.gd), at home inside. Their mood (0..100) sets
## the rent (Balance.LETTINGS "mood_rent": from the low to the high end); now and then they ask for something
## (bring it and talk to them: happier, and a tip). An ask left waiting sours them a little each day; doing
## the house up cheers them.

signal changed

## Village house index -> its name and the feel of its room.
const HOUSES := {3: {"name": "Hill House", "feel": "hill"}, 4: {"name": "Green Lodge", "feel": "swoop"},
	6: {"name": "Loaf Cottage", "feel": "lantern"}}
const LEVELS := ["For sale", "Plain", "Cosy", "Fine"]
const TENANTS := {3: "tenant_odo", 4: "tenant_mira", 6: "tenant_fen"}
## 6 Oct (owner): Hilmi's villagers live in the houses now and Enea's tenants have left; the family in a house you
## buy pays the rent. Asks came from the old tenants (talked to inside): off until the families can ask.
const ASKING := false
## What tenants ask for: [item, how many].
const ASKS := [["wood", 8], ["stone", 6], ["apple", 4], ["flower", 5], ["roast_meat", 2], ["hide", 2], ["resin", 2],
	["stew", 1], ["pinewood", 4], ["bluegill", 2]]

var owned := {}           # house index -> level (1..3)
var waiting := 0          # rent to collect
var mood := {}            # house index -> 0..100
var asks := {}            # house index -> [item, count]
var _day_secs := 0.0


func level(i: int) -> int:
	return owned.get(i, 0)


func price(i: int) -> int:
	return Balance.LETTINGS["price"][i]


## Rent a day at a level (the house's own level, with the tenant's mood, if not given).
func rent(i: int, at := -1) -> int:
	var lv := level(i) if at < 0 else at
	if lv <= 0:
		return 0
	var base: int = Balance.LETTINGS["rent"][i][lv - 1]
	var span: Vector2 = Balance.LETTINGS["mood_rent"]
	return roundi(base * lerpf(span.x, span.y, mood.get(i, 70) / 100.0)) if at < 0 else base


## The house a tenant lives in (-1 if they aren't one).
func house_of(npc: String) -> int:
	for i: int in TENANTS:
		if TENANTS[i] == npc and owned.has(i):
			return i
	return -1


## How the tenant feels, in a word.
func mood_word(i: int) -> String:
	var m: int = mood.get(i, 70)
	return "delighted" if m >= 85 else ("happy" if m >= 65 else ("so-so" if m >= 40 else "unhappy"))


## The action: hand over what a tenant asked for. Returns the tip.
func give(i: int) -> int:
	if not asks.has(i) or not Inventory.remove(asks[i][0], asks[i][1]):
		return 0
	var tip: int = maxi(Items.value_of(asks[i][0]) * asks[i][1] * 2, 15)
	asks.erase(i)
	mood[i] = mini(mood.get(i, 70) + Balance.LETTINGS["mood_ask"], 100)
	Money.earn(tip)
	changed.emit()
	return tip


## What a tenant says when you talk to them: their mood, and what they'd like.
func talk(npc: String) -> Dictionary:
	var i := house_of(npc)
	var def := Npcs.get_def(npc)
	var bye := [{"label": "Bye", "do": func() -> Dictionary: return {}}]
	var feel: String = {"delighted": "I love this place. Best house in the village!", "happy": "It's a good little home. Thank you.",
		"so-so": "It's... fine. Could be better.", "unhappy": "I'm not happy here, landlord. Not happy at all."}[mood_word(i)]
	if asks.has(i):
		var ask: Array = asks[i]
		var line := "%s Could you bring me %d %s? I'd be grateful." % [feel, ask[1], Items.name_of(ask[0])]
		if Inventory.count(ask[0]) >= ask[1]:
			return {"text": line, "options": [{"label": "Here you go", "do": func() -> Dictionary:
				var tip := give(i)
				return {"text": "Oh, wonderful! Here, take %d coins for your trouble." % tip, "options": bye, "emote": "Yes"}},
				{"label": "Later", "do": func() -> Dictionary: return {}}]}
		return {"text": line, "options": [{"label": "I'll find some", "do": func() -> Dictionary: return {}}]}
	return {"text": "%s %s" % [def["chatter"].pick_random(), feel], "options": bye}


func daily() -> int:
	var total := 0
	for i: int in owned:
		total += rent(i)
	return total


## What doing it up to the next level costs ({} at the top).
func do_up_cost(i: int) -> Dictionary:
	var lv := level(i)
	var ups: Array = Balance.LETTINGS["do_up"]
	return ups[lv - 1] if lv >= 1 and lv - 1 < ups.size() else {}


## The action: buy a house (a tenant moves in the next day).
func buy(i: int) -> bool:
	if not HOUSES.has(i) or owned.has(i) or not Money.spend(price(i)):
		return false
	owned[i] = 1
	mood[i] = Balance.LETTINGS["mood_start"]
	changed.emit()
	return true


## The action: do it up a level (better furniture, more rent).
func do_up(i: int) -> bool:
	var c := do_up_cost(i)
	if c.is_empty() or Money.coins < c["coins"] or not Gear.can_afford(c["cost"]):
		return false
	Money.spend(c["coins"])
	for item: String in c["cost"]:
		Inventory.remove(item, c["cost"][item])
	owned[i] += 1
	mood[i] = mini(mood.get(i, 70) + Balance.LETTINGS["mood_do_up"], 100)
	changed.emit()
	return true


## The action: take the rent that's waiting.
func collect() -> int:
	var got := waiting
	if got > 0:
		Money.earn(got)
		waiting = 0
		changed.emit()
	return got


func _process(delta: float) -> void:
	if owned.is_empty():
		return
	_day_secs += delta
	if _day_secs >= Bounties.DAY_SECS:
		new_day()


## A new day (time went by, or you slept through the night): the tenants pay.
func new_day() -> void:
	_day_secs = 0.0
	if owned.is_empty():
		return
	waiting = mini(waiting + daily(), daily() * Balance.LETTINGS["days"])
	var l: Dictionary = Balance.LETTINGS
	for i: int in owned:                    # an ask left waiting sours them; otherwise they settle in, and may ask
		if asks.has(i):
			mood[i] = maxi(mood.get(i, 70) - l["mood_wait"], 0)
		else:
			mood[i] = mini(mood.get(i, 70) + l["mood_day"], 100)
			if ASKING and randf() < l["ask_chance"]:
				asks[i] = ASKS.pick_random()
	changed.emit()


func to_data() -> Dictionary:
	var list := {}
	for i: int in owned:
		list[str(i)] = owned[i]
	var moods := {}
	var wants := {}
	for i: int in owned:
		moods[str(i)] = mood.get(i, 70)
		if asks.has(i):
			wants[str(i)] = asks[i]
	return {"owned": list, "waiting": waiting, "day_secs": _day_secs, "mood": moods, "asks": wants}


func load_data(data: Variant) -> void:
	owned = {}
	waiting = 0
	mood = {}
	asks = {}
	_day_secs = 0.0
	if data is Dictionary:
		var moods: Variant = data.get("mood", {})
		var wants: Variant = data.get("asks", {})
		if moods is Dictionary:
			for key: String in moods:
				mood[int(key)] = clampi(int(moods[key]), 0, 100)
		if wants is Dictionary:
			for key: String in wants:
				var a: Variant = wants[key]
				if a is Array and a.size() == 2 and Items.DEFS.has(str(a[0])):
					if ASKING:
						asks[int(key)] = [str(a[0]), int(a[1])]
		var list: Variant = data.get("owned", {})
		if list is Dictionary:
			for key: String in list:
				if HOUSES.has(int(key)):
					owned[int(key)] = clampi(int(list[key]), 1, LEVELS.size() - 1)
		waiting = int(data.get("waiting", 0))
		_day_secs = float(data.get("day_secs", 0.0))
	changed.emit()
