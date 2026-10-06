extends RefCounted
## Who fights you in a dungeon, by the theme's "foes":
##   "clan"    a cannibal clan: people on the bandit body (creatures/bandit.gd) in war paint, furs and bone,
##             their chief at the goal. The dungeon runs their fight like the Red Hand's camp (turns, alarms).
##   "beasts"  wolves, with a shadow wolf guarding the goal.
## spawn(dungeon, kind, room, count, boss, rng) puts them in a room (local metres; `dungeon` places and owns them).

const WOLF := preload("res://scenes/wolf.tscn")

## The clan's looks: our character parts, bare-armed in furs and kilts, painted faces, bone-white masks.
const CLAN_LOOKS := [
	{"parts": {"head": "none", "top": "jerkin", "chest": "bandolier", "shoulders": "fur", "waist": "kilt", "feet": "wraps",
		"hair": "mohawk", "beard": "stubble", "marks": "mask", "back": "none"},
		"colors": {"Main": 4, "Second": 3, "Cloth": 3, "Leather": 3, "Hair": 1, "Marks": 0}},
	{"parts": {"head": "none", "mask": "hollow", "top": "tunic", "chest": "strap", "shoulders": "fur", "waist": "kilt", "feet": "wraps",
		"hair": "messy", "back": "none"},
		"colors": {"Main": 3, "Second": 4, "Cloth": 3, "Leather": 3, "Hair": 2}},
	{"parts": {"head": "bandana", "top": "jerkin", "chest": "none", "shoulders": "pads", "waist": "kilt", "feet": "wraps",
		"hair": "long", "beard": "full", "marks": "warpaint", "back": "quiver"},
		"colors": {"Main": 4, "Second": 3, "Cloth": 3, "Leather": 3, "Hair": 1, "Marks": 2}},
]
## The chief: a big man in a bone mask with a fur mantle and a cape.
const CHIEF_LOOK := {"parts": {"head": "none", "mask": "oni", "top": "coat", "chest": "bandolier", "shoulders": "fur", "waist": "kilt",
	"feet": "boots", "hair": "long", "beard": "braided", "back": "cape"},
	"colors": {"Main": 3, "Second": 4, "Cloth": 3, "Leather": 3, "Hair": 1, "Accent": 11}}
const CHIEF_NAMES := ["Gorm the Gnawer", "Old Marrow", "Skarra Bone-Wife", "Hask the Hungry"]


static func spawn(dungeon: Node3D, kind: String, room: Dictionary, count: int, boss: bool, rng: RandomNumberGenerator) -> Array[Node3D]:
	var made: Array[Node3D] = []
	var centre: Vector2 = room.at
	var r: float = room.r
	for k in count:
		var at: Vector2 = dungeon.rock.by_wall(centre, r * 0.55, rng.randf() * 360.0, 1.4)
		if kind == "clan":
			made.append(_clansman(dungeon, at, centre, ["cutthroat", "cutthroat", "shield", "archer"][rng.randi() % 4], k, rng))
		else:
			made.append(_wolf(dungeon, at, centre, false))
	if boss:
		if kind == "clan":
			var chief := _clansman(dungeon, centre + Vector2(0, -r * 0.35), centre, "leader", 9, rng)
			chief.title = CHIEF_NAMES[rng.randi() % CHIEF_NAMES.size()]
			made.append(chief)
		else:
			made.append(_wolf(dungeon, centre + Vector2(0, -r * 0.35), centre, true))
	return made


static func _clansman(dungeon: Node3D, at: Vector2, centre: Vector2, kind: String, n: int, rng: RandomNumberGenerator) -> Node3D:
	var b := Bandit.new()
	b.kind = kind
	b.camp = dungeon
	b.player = dungeon.player
	b.day_night = dungeon.day_night
	b.trophy = "fang" if rng.randf() < 0.5 else ""
	var post: Vector3 = dungeon.world(at)
	b.post = post
	b.post_turn = (centre - at).angle_to(Vector2(0, 1)) if at != centre else 0.0
	b.idle_pose = "Idle_FoldArms" if kind == "leader" else ""
	var def: Dictionary = CHIEF_LOOK if kind == "leader" else CLAN_LOOKS[n % CLAN_LOOKS.size()]
	var look := CharacterLook.new()
	look.parts["brows"] = "stern"
	look.parts["mouth"] = "flat"
	look.parts["eyes"] = "narrow"
	look.parts["mask"] = "none"
	for slot: String in def.parts:
		look.parts[slot] = def.parts[slot]
	look.colors["Skin"] = rng.randi_range(1, 6)
	for slot: String in def.colors:
		look.colors[slot] = def.colors[slot]
	b.look = look
	b.body_scale = 1.15 if kind == "leader" else rng.randf_range(0.95, 1.06)
	dungeon.built.add_child(b)
	b.global_position = post + Vector3(0, 0.2, 0)
	return b


static func _wolf(dungeon: Node3D, at: Vector2, centre: Vector2, shadow: bool) -> Node3D:
	var wolf := WOLF.instantiate()
	wolf.player = dungeon.player
	wolf.shadow = shadow
	wolf.home = dungeon.world(centre)
	dungeon.built.add_child(wolf)
	wolf.global_position = dungeon.world(at) + Vector3(0, 0.5, 0)
	return wolf
