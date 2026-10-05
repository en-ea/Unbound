extends Node
## Village houses you can buy and let out (game state, no visuals). Each one you own has a tenant who pays
## rent every in-game day; it waits for you (up to Balance.LETTINGS "days" of it) until you collect it at
## the house's sign or your mailbox. Doing a house up (levels 1..3) furnishes it better and raises its rent.
## The houses stand in the meadow village (world/village.gd HOUSES, by index); you can look inside any time
## (world/visit_interior.gd). Numbers: Balance.LETTINGS.

signal changed

## Village house index -> its name and the feel of its room.
const HOUSES := {3: {"name": "Hill House", "feel": "hill"}, 4: {"name": "Green Lodge", "feel": "swoop"},
	6: {"name": "Loaf Cottage", "feel": "lantern"}}
const LEVELS := ["For sale", "Plain", "Cosy", "Fine"]

var owned := {}           # house index -> level (1..3)
var waiting := 0          # rent to collect
var _day_secs := 0.0


func level(i: int) -> int:
	return owned.get(i, 0)


func price(i: int) -> int:
	return Balance.LETTINGS["price"][i]


## Rent a day at a level (the house's own level if not given).
func rent(i: int, at := -1) -> int:
	var lv := level(i) if at < 0 else at
	return Balance.LETTINGS["rent"][i][lv - 1] if lv > 0 else 0


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
	changed.emit()


func to_data() -> Dictionary:
	var list := {}
	for i: int in owned:
		list[str(i)] = owned[i]
	return {"owned": list, "waiting": waiting, "day_secs": _day_secs}


func load_data(data: Variant) -> void:
	owned = {}
	waiting = 0
	_day_secs = 0.0
	if data is Dictionary:
		var list: Variant = data.get("owned", {})
		if list is Dictionary:
			for key: String in list:
				if HOUSES.has(int(key)):
					owned[int(key)] = clampi(int(list[key]), 1, LEVELS.size() - 1)
		waiting = int(data.get("waiting", 0))
		_day_secs = float(data.get("day_secs", 0.0))
	changed.emit()
