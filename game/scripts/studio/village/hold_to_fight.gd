extends Node
## Tap to talk, hold to fight (Pass 3; Hilmi, 1 Oct 2026: "holding the action button will initiate the targeting and
## enable hitting rather than talking"). The action button on a villager:
##
##   press ──> still held at HOLD ──> square up (provoke.gd: the village's rules decide) ──> the button attacks
##         └─> let go sooner ──────> the talk, as before
##
## While it is held the button's rim fills, so the hold is seen. Someone the rules will not let the player fight (a
## child, someone held) gets the button's "not now" shake and a hint, and nothing opens. A press nobody is holding (a
## probe calling player.act()) is a tap at once. While a grown villager is the button's target it reads "hold: fight".
## Lives under VillageLive (live.gd adds it); the talk spot (resident_talk.gd) hands it each press.
const Talk := preload("res://scripts/studio/village/resident_talk.gd")
const View := preload("res://scripts/studio/village/sim/view.gd")

const HOLD := 0.4             # seconds held to square up (a tap is well under; a deliberate hold is not much more)
const KEYS := [KEY_E, KEY_SPACE]   # the action button's keys (Enea's player.gd _unhandled_input)

var provoke: Node
var _resident := -1           # the villager the press began on
var _held := 0.0
var _button: Control
var _player: Node3D
var _sub := false             # "hold: fight" is showing
var _fightable := {}          # id -> [minute, whether the talk screen would offer a fight]


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")


## The action button went down on a villager's talk spot.
func press(resident: int) -> void:
	if not _holding():
		_talk(resident)          # nobody is holding it (a probe's act()): a tap
		return
	_resident = resident
	_held = 0.0


func _process(delta: float) -> void:
	_show_sub()
	if _resident < 0:
		return
	if Controls.locked:
		_end()
		return
	if not _holding():
		var id := _resident
		_end()
		_talk(id)
		return
	_held += delta
	var button := _action_button()
	if button != null:
		button.set_meter(clampf(_held / HOLD, 0.0, 1.0))
	if _held < HOLD:
		return
	var id := _resident
	_end()
	var result: Dictionary = provoke.square_up(id)
	if not result.get("accepted", false):
		if button != null:
			button.refuse()
		get_tree().call_group("hud", "hint", "Too far." if str(result.get("reason", "")) == "out of reach" else "Not now.")


func _end() -> void:
	_resident = -1
	var button := _action_button()
	if button != null:
		button.set_meter(1.0)


func _talk(id: int) -> void:
	get_tree().call_group("hud", "open_dialogue", Talk.PREFIX + str(id))


func _holding() -> bool:
	for key: int in KEYS:
		if Input.is_physical_key_pressed(key):
			return true
	var button := _action_button()
	return button != null and button.is_held()


func _action_button() -> Control:
	if not is_instance_valid(_button):
		_button = get_tree().get_first_node_in_group("action_button") as Control   # Enea's hud.gd marks it (studio hook)
	return _button


## "hold: fight" under the verb while the button's target is a villager the talk screen would offer a fight with.
func _show_sub() -> void:
	var button := _action_button()
	if button == null or _player == null:
		return
	var station: Variant = _player.get("_station")   # (a freed one is not an Object to assign)
	var on := false
	if is_instance_valid(station) and station is Talk.Spot:
		var id: int = (station as Talk.Spot).resident
		on = not provoke.is_squared_up(id) and _offers_fight(id)
	if on != _sub:
		_sub = on
		button.sub = "hold: fight" if on else ""
		button.queue_redraw()


## Whether the talk screen would offer "Pick a fight" (resident_talk.gd screen): a grown person, not held, not one
## of Enea's own. Asked once a game minute per villager.
func _offers_fight(id: int) -> bool:
	var v = VillageSession.village
	if v == null:
		return false
	var now := int(v.runtime.now)
	var known: Array = _fightable.get(id, [-1, false])
	if int(known[0]) != now:
		var d: Dictionary = View.describe(v, id)
		known = [now, d.age_group != "child" and not d.held and not d.protected]
		_fightable[id] = known
	return bool(known[1])
