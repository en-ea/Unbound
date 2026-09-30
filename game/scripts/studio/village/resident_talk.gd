extends RefCounted
## Talking to a simulated resident, through Enea's own talk screen (ui/dialogue_panel.gd). A resident is
## addressed as "resident:<id>", and three marked hooks send that name here:
##   Npcs.get_def("resident:12")      -> def(): who they are for the screen (look, plain village theme, voice)
##   Quests.talk("resident:12")       -> screen(): what they say and what can be said back
##   hud.open_dialogue("resident:12") -> opened(): the village records the meeting (PlayerActs, "talk")
## Enea's own characters (Wren, Brakk, Morrow, the Seeker) never come through here.
##
##   Spot     a node in group "interactable" on every resident: verb "Talk", reach REACH; the player's action
##            button (player.gd) finds it like any other interactable and calls interact()
##   look_of  the same look the resident's body wears (residents.gd) and the portrait shows
const View := preload("res://scripts/studio/village/sim/view.gd")
const Lines := preload("res://scripts/studio/village/resident_lines.gd")
const PlayerActs := preload("res://scripts/studio/village/player_acts.gd")

const PREFIX := "resident:"
const REACH := 2.2
## One plain village theme for everyone: dark wood, lamplight, Enea's Almendra lettering. The voice is by age
## and sex (make_voices.py: man, woman, elder, child).
const BG := Color(0.11, 0.09, 0.07, 0.95)
const ACCENT := Color(0.88, 0.72, 0.47)
const TEXT := Color(1.0, 0.96, 0.86)

## The view of the resident just before the meeting was recorded, so a stranger is met as a stranger.
static var _before := {}


## The talk spot on a resident's body.
class Spot extends Node3D:
	var verb := "Talk"
	var reach := REACH
	var resident := -1
	var offered := false          # whether it is in the player's reach group now (residents.gd keeps this)

	func interact() -> void:
		get_tree().call_group("hud", "open_dialogue", PREFIX + str(resident))


static func is_resident(npc: String) -> bool:
	return npc.begins_with(PREFIX)


static func id_of(npc: String) -> int:
	return int(npc.trim_prefix(PREFIX))


## Outfits that suit a trade (CharacterLook.OUTFITS names; never the knight's, guardian's or mage's armour and
## robes, and never the northlander's, which is the old ones'). Which of them: by the resident's id.
const OUTFITS_BY_ROLE := {
	"farmer": ["Fisher", "Wanderer", "Explorer"], "herder": ["Ranger", "Wanderer", "Explorer"],
	"woodcutter": ["Explorer", "Ranger", "Wanderer"], "hunter": ["Ranger", "Explorer"],
	"gatherer": ["Druid", "Fisher", "Ranger"], "miller": ["Wanderer", "Merchant", "Fisher"], "smith": ["Smith"],
	"merchant": ["Merchant", "Bard"], "priest": ["Druid", "Alchemist"], "elder": ["Alchemist", "Merchant", "Bard"],
	"midwife": ["Alchemist", "Druid", "Bard"], "beggar": ["Wanderer", "Fisher"],
	"child": ["Wanderer", "Fisher", "Explorer", "Bard"],
}


## What a resident looks like: an outfit that suits their trade and their colours, as residents.gd dresses the body.
static func look_of(v: Object, id: int) -> CharacterLook:
	var d := View.describe(v, id)
	var look := CharacterLook.new()
	var choices: Array = OUTFITS_BY_ROLE.get(str(d.role), CharacterLook.OUTFITS.keys())
	look.set_outfit(choices[posmod(int(d.look.outfit) + id, choices.size())])
	if d.forebear:
		look.set_outfit("Northlander")   # the existing fur and paint outfit makes the old ones readable
	look.set_color("Hair", (id * 3) % CharacterLook.PALETTES.Hair.size())
	look.set_color("Skin", (id * 2 + 1) % CharacterLook.PALETTES.Skin.size())
	return look


static func voice_of(d: Dictionary) -> String:
	if d.age_group == "child":
		return "child"
	if d.age_group == "elder":
		return "elder"
	return "woman" if int(d.sex) == 1 else "man"


static func title_of(d: Dictionary) -> String:
	if d.forebear:
		return "Forebear of the %s line" % d.lineage if d.lineage != "" else "Forebear"
	if d.priest:
		return "Keeper of the shrine"
	if d.authority:
		return "Village elder"
	var title: String = str(d.role).capitalize()
	if d.epithet != "":
		title += ", " + str(d.epithet)
	return title


## Enea's NPC def shape (state/npcs.gd), made from the resident.
static func def(npc: String) -> Dictionary:
	var v = VillageSession.village
	var id := id_of(npc)
	var d := View.describe(v, id)
	var look := look_of(v, id)
	var height := 0.68 if d.age_group == "child" else 1.0
	return {
		"name": str(d.name), "title": title_of(d), "at": Vector2.ZERO, "scale": Vector3.ONE * height,
		"look": {"parts": look.parts.duplicate(), "colors": look.colors.duplicate()},
		"theme": {"bg": BG, "accent": ACCENT, "text": TEXT, "voice": voice_of(d),
			"font": "res://assets/fonts/Almendra-Regular.ttf", "name_font": "res://assets/fonts/Almendra-Bold.ttf"},
		# the chest and face, framed as Wren's is, scaled to the body (a child is smaller)
		"portrait": {"look_at": Vector3(0.04, 1.52 * height, 0.0), "cam": Vector3(0.2 * height, 1.68 * height, 1.85 * height),
			"fov": 34.0, "turn": -10.0},
		"greetings": [], "chatter": [Lines.line(d, int(v.runtime.now) / 1440, int(v.runtime.now) % 1440)],
	}


## The village records the meeting, then the screen opens. False (nothing opens) when the village is not
## running, the resident is not in reach, or the game is paused.
static func opened(npc: String) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var live := tree.current_scene.get_node_or_null("VillageLive") if tree.current_scene != null else null
	var v = VillageSession.village
	if v == null or live == null or not VillageSession.active:
		return false
	var id := id_of(npc)
	var player := tree.get_first_node_in_group("player") as Node3D
	_before = View.describe(v, id)
	var result := PlayerActs.request(player, live.registry, "talk", id)
	if not result.accepted:
		return false
	live.registry.begin_talk(id, player)
	return true


## What the player asked for on this screen, done once it has closed (the controls are then free again; a world
## action refuses while a screen holds them): {"verb": "fight" | "give", "id", "item", "count"}.
static var pending := {}
const GIFT_COINS := 5
const MAX_GIFTS := 3


## Their words, and what the player can say back. During an open event the people who have a part in it (the
## judge, a witness, the leader of a rite) also offer what the event allows (live.gd talk_context). Otherwise, to
## a grown person: "Give..." (what the player carries that makes sense) and "Pick a fight" (never to a child).
static func screen(npc: String) -> Dictionary:
	var v = VillageSession.village
	var id := id_of(npc)
	var d: Dictionary = _before if int(_before.get("id", -1)) == id else View.describe(v, id)
	_before = {}
	var day := int(v.runtime.now) / 1440
	var minute := int(v.runtime.now) % 1440
	var tree := Engine.get_main_loop() as SceneTree
	var live := tree.current_scene.get_node_or_null("VillageLive") if tree.current_scene != null else null
	var context: Dictionary = live.talk_context(id) if live != null and live.has_method("talk_context") else {}
	var words := Lines.event_line(d, context.part, day) if not context.is_empty() and d.age_group != "child" else Lines.line(d, day, minute)
	var options: Array = []
	options.append_array(context.get("options", []))
	if context.is_empty() and not d.held and not d.protected:
		var gifts := giftable()
		if not gifts.is_empty():
			options.append({"label": "Give...", "do": func() -> Dictionary: return _give_screen(id, d, gifts, day)})
		if d.age_group != "child":
			options.append({"label": "Pick a fight", "do": func() -> Dictionary:
				pending = {"verb": "fight", "id": id}
				return {}})
	options.append({"label": "Bye", "do": func() -> Dictionary: return {}})
	return {"text": words, "options": options}


## What the player carries that is worth handing over: five coins, and food (Food.FOODS), at most MAX_GIFTS.
static func giftable() -> Array:
	var out := []
	if Money.coins >= GIFT_COINS:
		out.append({"item": "coins", "count": GIFT_COINS, "label": "Give: %d coins" % GIFT_COINS})
	var foods: Array = []
	for item: String in Food.FOODS:
		if Inventory.count(item) > 0:
			foods.append(item)
	foods.sort_custom(func(a: String, b: String) -> bool: return Inventory.count(a) > Inventory.count(b))
	for item: String in foods:
		if out.size() >= MAX_GIFTS:
			break
		out.append({"item": item, "count": 1, "label": "Give: %s" % Items.name_of(item)})
	return out


static func _give_screen(id: int, d: Dictionary, gifts: Array, day: int) -> Dictionary:
	var options: Array = []
	for gift: Dictionary in gifts:
		options.append({"label": gift.label, "do": func() -> Dictionary:
			pending = {"verb": "give", "id": id, "item": gift.item, "count": gift.count}
			return answer(Lines.thanks(d, str(gift.item), day), "Bye", "Yes")})
	options.append({"label": "Never mind", "do": func() -> Dictionary: return screen(PREFIX + str(id))})
	return {"text": "Oh? What have you got there?" if d.age_group != "child" else "Is that for me?", "options": options}


## Does what the screen asked, now that it has closed. (residents.gd calls this the frame the controls are free.)
static func run_pending(registry: Node, player: Node3D) -> void:
	if pending.is_empty():
		return
	var job := pending
	pending = {}
	var tree := Engine.get_main_loop() as SceneTree
	var live := tree.current_scene.get_node_or_null("VillageLive") if tree.current_scene != null else null
	if live == null or not VillageSession.active:
		return
	var id := int(job.id)
	if job.verb == "fight":
		var provoke := live.get_node_or_null("Provoke")
		var result: Dictionary = provoke.square_up(id) if provoke != null else {"accepted": false, "reason": "not now"}
		if not result.get("accepted", false):
			tree.call_group("hud", "hint", "Too far." if str(result.get("reason", "")) == "out of reach" else "Not now.")
	elif job.verb == "give":
		var result := PlayerActs.request(player, registry, "give", id, {"item": job.item, "count": job.count})
		if not result.accepted:
			tree.call_group("hud", "hint", "They won't take it.")


## A one-button screen: the answer, and a way to close it.
static func answer(text: String, label := "Thank you", emote := "") -> Dictionary:
	var next := {"text": text, "options": [{"label": label, "do": func() -> Dictionary: return {}}]}
	if emote != "":
		next["emote"] = emote
	return next
