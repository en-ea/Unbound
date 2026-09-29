extends Node
## Your coins (game state). Change them only through earn() and spend().

signal changed(coins: int)

var coins := 0


func earn(amount: int) -> void:
	coins += amount
	changed.emit(coins)


func spend(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	changed.emit(coins)
	return true


func load_data(value: Variant) -> void:
	coins = maxi(int(value), 0)
	changed.emit(coins)


# --- the trader ---------------------------------------------------------------------------------
const STOCK_POOL := Balance.STOCK_POOL
const STOCK_SIZE := Balance.STOCK_SIZE
const RESTOCK_EVERY := Balance.RESTOCK_EVERY

var _stock: Array = []            # [{item, amount, price, tool: [slot, record], sold}]
var _stock_block := -1


## The action: sell some of an item to the trader.
func sell(item: String, amount := 1) -> bool:
	if not Inventory.remove(item, amount):
		return false
	earn(Items.value_of(item) * amount)
	return true


## Today's stock (it changes every RESTOCK_EVERY seconds).
func stock() -> Array:
	var block := int(Time.get_unix_time_from_system()) / RESTOCK_EVERY
	if block != _stock_block:
		_stock_block = block
		_stock.clear()
		var rng := RandomNumberGenerator.new()
		rng.seed = block
		var pool := STOCK_POOL.duplicate()
		for i in STOCK_SIZE:
			var pick: Array = pool.pop_at(rng.randi() % pool.size())
			var offer := {"item": pick[0], "amount": pick[1], "price": pick[2], "sold": false}
			if pick[0] == "tool":
				offer["tool"] = Gear.roll_found("trader")
			_stock.append(offer)
	return _stock


## Seconds until the stock changes.
func restock_in() -> int:
	return RESTOCK_EVERY - int(Time.get_unix_time_from_system()) % RESTOCK_EVERY


## The action: buy an offer from the stock.
func buy(offer: Dictionary) -> bool:
	if offer["sold"] or coins < offer["price"]:
		return false
	if offer["item"] != "tool" and not Inventory.has_room(offer["item"]):
		return false
	spend(offer["price"])
	offer["sold"] = true
	if offer["item"] == "tool":
		Gear.take(offer["tool"][0], offer["tool"][1])
	else:
		Inventory.add(offer["item"], offer["amount"])
	return true
