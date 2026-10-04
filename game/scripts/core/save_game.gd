extends Node
## Saves the game on the device: your items, the state of trees/rocks/plants, where you stand and
## the time of day, and your tools. It saves by itself every few seconds and whenever the app goes to the
## background, so you can stop anywhere. (Your look is saved by CharacterLook; settings by Settings.)

const MAIN := "user://save.json"
const STORY := "user://save_story.json"      # the Story start (title screen) plays in its own save

var path := MAIN
var skip_title := false   # the scene reloaded into a game that starts straight away (Story start)
var intro_pending := false  # play the story's opening (story/intro.gd) once the world is up
const VERSION := 1
const AUTOSAVE_EVERY := 15.0

var _player: Node3D
var _day_night: Node
var _timer := AUTOSAVE_EVERY
var _enabled := true
var paused := false     # the build lab turns saving off while you are in it
var _regions := {}      # region -> {"layout", "world", "saved_at"}: every region's trees, rocks and chests


## Called by main once the world is built: remembers what to save and loads the last save.
func attach(player: Node3D, day_night: Node) -> void:
	_player = player
	_day_night = day_night
	# Dev test runs start fresh and don't overwrite the real save.
	_enabled = OS.get_cmdline_user_args().is_empty()
	if _enabled:
		load_game()


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = AUTOSAVE_EVERY
		save_game()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST]:
		save_game()


func save_game() -> void:
	if not _enabled or paused or not is_instance_valid(_player):
		return
	var p := _player.global_position
	_regions[Region.current] = {
		"world": WorldResources.to_data(),
		"layout": str(WorldResources.layout_id()),     # as text: JSON would round a big number
		"saved_at": Time.get_unix_time_from_system(),
	}
	var data := {
		"version": VERSION,
		"inventory": Inventory.to_data(),
		"gear": Gear.to_data(),
		"armor": Armor.to_data(),
		"skills": Skills.to_data(),
		"coins": Money.coins,
		"projects": Projects.to_data(),
		"home": Home.to_data(),
		"quests": Quests.to_data(),
		"classes": Classes.to_data(),
		"hunting": Hunting.to_data(),
		"bounties": Bounties.to_data(),
		"residents": Residents.to_data(),
		"fishing": FishData.to_data(),
		"region": Region.current,
		"regions": _regions,
		"player": {"pos": [p.x, p.y, p.z], "facing": _player.visual.rotation.y, "indoors": _indoors()},
		"time_of_day": _day_night.time_of_day,
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))


func _read() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("version", 0) != VERSION:
		return {}
	return data


## The region the save was made in, so main can build it before loading (real runs only).
func saved_region() -> String:
	if not OS.get_cmdline_user_args().is_empty():
		return Region.current
	return _read().get("region", "meadow")


func load_game() -> void:
	var data := _read()
	if data.is_empty():
		return
	Inventory.load_data(data.get("inventory", {}))
	Gear.load_data(data.get("gear", {}))
	Armor.load_data(data.get("armor", {}))
	Skills.load_data(data.get("skills", {}))
	Money.load_data(data.get("coins", 0))
	Projects.load_data(data.get("projects", []))
	Home.load_data(data.get("home", {}))
	Quests.load_data(data.get("quests", {}))
	Classes.load_data(data.get("classes", {}))
	Hunting.load_data(data.get("hunting", {}))
	Bounties.load_data(data.get("bounties", {}))
	Residents.load_data(data.get("residents", {}))
	FishData.load_data(data.get("fishing", {}))
	_regions = data.get("regions", {})
	if not data.has("regions") and data.has("world"):       # a save from before regions: the meadow
		_regions = {"meadow": {"world": data["world"], "layout": data.get("layout", ""), "saved_at": Time.get_unix_time_from_system()}}
	var here: Dictionary = _regions.get(Region.current, {})
	if here.get("layout", "") == str(WorldResources.layout_id()):
		WorldResources.load_data(here.get("world", []), Time.get_unix_time_from_system() - float(here.get("saved_at", 0.0)))
	var pl: Dictionary = data.get("player", {})
	var pos: Array = pl.get("pos", [])
	if Region.arrive != Vector2.INF or data.get("region", "meadow") != Region.current:
		pass                     # just came through a gate: main places the player there
	elif pos.size() == 3 and pl.get("indoors", false) and Home.owned():
		get_tree().call_group("home_interior", "resume", Vector3(pos[0], pos[1] + 0.1, pos[2]), float(pl.get("facing", 0.0)))
	elif pos.size() == 3 and pos[1] > -100.0:
		_player.global_position = Vector3(pos[0], pos[1] + 0.1, pos[2])
		_player.visual.rotation.y = pl.get("facing", 0.0)
	_day_night.time_of_day = data.get("time_of_day", _day_night.time_of_day)


## Puts back everything you own and have learned from the last save (leaving the Build lab), but not
## where you stand or the world.
func restore_belongings() -> void:
	var data := _read()
	if data.is_empty():
		return
	Inventory.load_data(data.get("inventory", {}))
	Gear.load_data(data.get("gear", {}))
	Armor.load_data(data.get("armor", {}))
	Skills.load_data(data.get("skills", {}))
	Money.load_data(data.get("coins", 0))
	Quests.load_data(data.get("quests", {}))
	Classes.load_data(data.get("classes", {}))
	Hunting.load_data(data.get("hunting", {}))
	Bounties.load_data(data.get("bounties", {}))
	Residents.load_data(data.get("residents", {}))
	FishData.load_data(data.get("fishing", {}))


func _indoors() -> bool:
	var room := get_tree().get_first_node_in_group("home_interior")
	return room != null and room.active


## Story start (fresh = from the very beginning, with the opening) or carry on with the story's own save.
func begin_story(fresh: bool) -> void:
	save_game()
	path = STORY
	skip_title = true
	if fresh:
		intro_pending = true
		start_over()
		return
	_enabled = false
	get_tree().reload_current_scene()


func has_story() -> bool:
	return FileAccess.file_exists(STORY)


## Wipes the save and restarts the world from scratch.
func start_over() -> void:
	DirAccess.remove_absolute(path)
	_enabled = false        # don't save the old world on the way out
	_regions = {}
	Region.current = "meadow"
	Inventory.load_data({})
	Gear.load_data({})
	Armor.load_data({})
	Skills.load_data({})
	Money.load_data(0)
	Projects.load_data([])
	Home.load_data({})
	Quests.load_data({})
	Classes.reset()
	Hunting.load_data({})
	Bounties.load_data({})
	Residents.load_data({})
	FishData.load_data({})
	WorldResources.reset()
	get_tree().reload_current_scene()
