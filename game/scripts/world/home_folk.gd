extends RefCounted
## Who is inside a village house when you walk in (world/visit_interior.gd), from Hilmi's living village: the
## family that lives there (and anyone visiting them), each doing what their day says. Asleep in bed at night
## (more sleepers than beds lie on the floor by the wall), round the table at noon, otherwise about the room.
## Each gets a body in the room and a Talk spot; they answer with the village's own lines (resident_lines.gd).
## Nothing here changes the village: it only shows it.

const Body := preload("res://scripts/studio/village/villager_body.gd")
const Talk := preload("res://scripts/studio/village/resident_talk.gd")
const Lines := preload("res://scripts/studio/village/resident_lines.gd")
const View := preload("res://scripts/studio/village/sim/view.gd")
const Rules := preload("res://scripts/studio/village/sim/village.gd")
const Houses := preload("res://scripts/world/village.gd")
const UseSpot := preload("res://scripts/world/use_spot.gd")
const Ported := preload("res://scripts/studio/village/sim/ported.gd") # studio: port

const CHILD_SCALE := 0.68
## Free places to stand about the room (room metres, x and z), and to lie when the beds are full.
const STANDS := [Vector2(1.6, 1.2), Vector2(-1.0, 1.4), Vector2(-2.6, 0.4), Vector2(2.6, -0.6), Vector2(-0.4, 2.4), Vector2(0.9, -1.9)]
const FLOOR_BEDS := [Vector2(-3.6, -2.8), Vector2(-1.6, -3.0), Vector2(1.4, 3.0), Vector2(-3.6, 2.8)]
const FLOOR_LAP := 1.0      # metres along x for each further lap of FLOOR_BEDS (a bedroll is 0.9 wide) # studio: port
const SEATS := ["chair", "stool", "armchair", "bench_seat"]
static var dev_verb := ""     # dev (--homeverb=sleeping): everyone at home does this, for checking the room


## The home's name in the village (its model: house_cottage.glb -> "cottage"); "" for the mill.
static func home_of(index: int) -> String:
	var model := String(Houses.HOUSES[index]["model"]).get_file()
	return model.get_basename().trim_prefix("house_") if model.begins_with("house_") else ""


## The family name of the household living in house `index` ("" if nobody, or no village).
static func family_of(index: int) -> String:
	var v = VillageSession.village
	var home := home_of(index)
	if v == null or home == "":
		return ""
	for h in v.households:
		if h.members.is_empty() or Ported.keeps_house(v, int(h.members[0])): # studio: port - his seven's own households ("of cottage") are not the house's family
			continue # studio: port
		if h.home == home:
			return str(v.lineages[h.lineage].name) if h.lineage >= 0 else ""
	return ""


## The people inside house `index` now: [{id, verb}] (verb: sleeping, eating, at_home, visiting).
static func inside(tree: SceneTree, index: int) -> Array:
	var v = VillageSession.village
	var home := home_of(index)
	var out: Array = []
	if v == null or home == "" or v.runtime.is_empty():
		return out
	for p in v.people:
		if not p.alive or not p.present or p.locked or p.authored != "":
			continue
		var his := _his_id(v, int(p.id)) # studio: port - one of his residents is at home only when his day says so (the port walks his body otherwise)
		if his != "" and not (Residents.ids().has(his) and Residents.activity(his) == "home"): # studio: port
			continue # studio: port
		var act: Dictionary = View.activity(v, p.id)
		if act.place != home or act.moving:
			continue
		# (by day the village may have them out in the yard: home is home, and they come in when you do)
		out.append({"id": int(p.id), "verb": dev_verb if dev_verb != "" else str(act.verb)})
	return out


## His id for one of his seven in the village ("" for anyone else). # studio: port
static func _his_id(v, pid: int) -> String: # studio: port
	for entry: Dictionary in v.runtime.get("ported", []): # studio: port
		if int(entry.person) == pid: # studio: port
			return str(entry.id) # studio: port
	return "" # studio: port


## Puts a body for each person in `people` into the room at `origin`, among `furniture` ([{id, x, z, turn}]).
## Returns the nodes made (bodies and their talk spots), for the room to free on the way out.
static func place(room: Node3D, origin: Vector3, furniture: Array, people: Array) -> Array[Node]:
	var made: Array[Node] = []
	var beds: Array = furniture.filter(func(f: Dictionary) -> bool: return f.id == "bed")
	var seats: Array = furniture.filter(func(f: Dictionary) -> bool: return f.id in SEATS)
	var tables: Array = furniture.filter(func(f: Dictionary) -> bool: return f.id == "table")
	var table := Vector2(tables[0].x, tables[0].z) if not tables.is_empty() else Vector2(0.3, 0.2)
	var v = VillageSession.village
	var stand := 0
	var floor_bed := 0
	for who: Dictionary in people:
		var id: int = who.id
		var body := Body.new()
		body.hero_look = Talk.look_of(v, id)
		body.is_player_look = false
		room.add_child(body)
		made.append(body)
		var age: int = Rules.age_of(v, v.people[id])
		var size := CHILD_SCALE if age < 14 else 1.0
		body.scale = Vector3.ONE * size
		Body.dress_his(body, v, id) # studio: port - one of his seven wears his own look indoors too (parts and their sizes), as outside
		var at := Vector2.ZERO
		var face := 0.0
		var lift := 0.0
		match who.verb:
			"sleeping":                    # on their back, head on the pillow (the bed's head is at its -z end)
				var length := 1.7 * size
				if not beds.is_empty():
					var bed: Dictionary = beds.pop_front()
					face = float(bed.turn)
					at = Vector2(bed.x, bed.z) + Vector2(0, length * 0.5).rotated(-face)
					lift = 0.5
				else:
					at = FLOOR_BEDS[floor_bed % FLOOR_BEDS.size()] + Vector2(FLOOR_LAP * (floor_bed / FLOOR_BEDS.size()), 0) # studio: port - more sleepers than floor places: the next lap a bedroll's width over, never on another
					floor_bed += 1
					lift = 0.08
					made.append(_bedroll(room, origin + Vector3(at.x, 0.03, at.y - length * 0.5)))
				body.play_loop("Idle", 0.0)
			"eating":
				var seated := not seats.is_empty()
				if seated:
					var seat: Dictionary = seats.pop_front()
					at = Vector2(seat.x, seat.z)
				else:                         # no seat left: standing at the table with their bowl
					at = table + Vector2(1.1, 0.0).rotated(stand * 1.7)
					stand += 1
				face = atan2(table.x - at.x, table.y - at.y)
				body.play_loop("Sitting_Idle" if seated else "Idle", 0.0)
			_:
				at = STANDS[stand % STANDS.size()]
				stand += 1
				face = atan2(-at.x, -at.y) + randf_range(-0.6, 0.6)   # turned roughly to the middle of the room
				body.play_loop("Idle" if randf() < 0.6 else "Idle_FoldArms", 0.0)
		body.global_position = origin + Vector3(at.x, lift, at.y)
		body.rotation = Vector3(-PI / 2.0, face, 0.0) if who.verb == "sleeping" else Vector3(0.0, face, 0.0)
		var spot := Node3D.new()
		spot.set_script(UseSpot)
		room.add_child(spot)
		var asleep: bool = who.verb == "sleeping"
		spot.setup(body.global_position + Vector3(0, 0.1, 0), "Wake" if asleep else "Talk", func() -> void: _speak(room, body, id, asleep), 1.6)
		made.append(spot)
	return made


## A blanket on the floor for whoever has no bed.
static func _bedroll(room: Node3D, at: Vector3) -> Node3D:
	var roll := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.9, 0.06, 2.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.42, 0.62)     # a blue blanket, clear against the boards
	box.material = mat
	roll.mesh = box
	room.add_child(roll)
	roll.global_position = at
	return roll


## What someone at home says when you talk to them (or wake them).
static func _speak(room: Node3D, body: Node3D, id: int, asleep: bool) -> void:
	var v = VillageSession.village
	if v == null or not is_instance_valid(body):
		return
	var d := View.describe(v, id)
	var now := int(v.runtime.now)
	var words: String = "Mm...? What are you doing in my house? Get out!" if asleep else Lines.line(d, now / 1440, now % 1440)
	var live := room.get_tree().current_scene.get_node_or_null("VillageLive")
	if live != null and live.registry.get("speech") != null and live.registry.speech.say(body, words, 1, id + 20000, Talk.voice_of(d)):
		return
	room.get_tree().call_group("hud", "hint", "%s: %s" % [d.name, words])
