extends Node
## Saves the game on the device: your items, the state of trees/rocks/plants, where you stand and
## the time of day, and your tools. It saves by itself every few seconds and whenever the app goes to the
## background, so you can stop anywhere. (Your look is saved by CharacterLook; settings by Settings.)

const SafeFile := preload("res://scripts/core/safe_file.gd")
const PeopleAcceptance := preload("res://scripts/studio/village/acceptance.gd") # studio: checked live memories at the existing save owner
const SaveJournal := preload("res://scripts/studio/village/journal.gd") # studio: step 4 full checkpoint + journal lines
const VillageImage := preload("res://scripts/studio/village/sim/image.gd") # studio: what the journal last wrote, natively
const MAIN := "user://save.json"
const STORY := "user://save_story.json"      # the Story start (title screen) plays in its own save
const PATH := MAIN # studio: merge - the real save; test saves and the Story start move _path

var path: String: # studio: merge - his Story start switches saves by setting path: one path, one journal
	get: # studio:
		return _path # studio:
	set(value): # studio:
		if _journal != null: # studio:
			_journal.wait() # studio: never leave a checkpoint writing the old file
		_path = value # studio:
		_journal = SaveJournal.new(_path) # studio:
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
var _path := PATH # studio: isolated test files use the real save path
var _journal = null # studio: SaveJournal for _path


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test-save="):
			_path = "user://studio-test-" + arg.trim_prefix("--test-save=").validate_filename() + ".json"
	_journal = SaveJournal.new(_path) # studio:


## Called by main once the world is built: remembers what to save and loads the last save.
func attach(player: Node3D, day_night: Node) -> void:
	_player = player
	_day_night = day_night
	# Dev test runs start fresh and don't overwrite the real save.
	_enabled = OS.get_cmdline_user_args().is_empty() or _path != PATH
	if _enabled:
		load_game()


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = AUTOSAVE_EVERY
		save_game(Time.get_ticks_msec() / 1000.0 - _last_full >= FULL_EVERY) # studio: autosave appends a line; every FULL_EVERY it also starts a checkpoint
	_journal.poll() # studio: a finished checkpoint drops the lines it holds
	if VillageSession.village != null: # studio:
		VillageImage.sweep(VillageSession.village) # studio: one part checked exactly per frame
		_bind_now(VillageSession.village) # studio:


func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and VillageSession._probe_run():return # studio: inherited off-screen probes keep their active clock
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		VillageSession.quiesce_background() # studio: one checked save before suspension, shared with session notification
	elif what==NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		_journal.wait() # studio: the checkpoint finishes before the app closes


# studio: step 4 (5 Oct, plan/STEP4-SAVE-STALL-2026-10-05.md) - a save is a journal line: the game's state whole
# studio: and the village as what changed since disk (VillageImage), flushed before a checked acceptance publishes.
# studio: The current region's world follows in its own line after the acceptance, on saves the game asks for. A full
# studio: save from live state starts a chain (load, new game, a broken journal); every FULL_EVERY seconds, on
# studio: background and on exit a checkpoint is built from data on a worker thread (SaveJournal). Loading replays
# studio: the journal on top.
const JOURNAL_LIMIT := 4194304 # studio:
const FULL_EVERY := 120.0 # studio:
var _last_full := 0.0 # studio:
func save_game(full := true) -> Error: # studio: accepted village batches must observe the actual write result
	if not _enabled or paused or not is_instance_valid(_player):
		return ERR_UNAVAILABLE # studio: refusing a write is not durable acceptance
	if not PeopleAcceptance._accepting: # studio: one checked batch, its line written inside it
		var checked := VillageSession.checked_save()
		if checked.get("handled",false):
			if not checked.get("accepted",false): # studio:
				return int(checked.get("error",ERR_BUSY)) # studio:
			return _world_line(full) # studio: the world follows the checked village line, outside the acceptance
	var outer := not PeopleAcceptance._accepting # studio: no acceptance around this save (no people bridge here)
	var v = VillageSession.village # studio:
	if _journal.chain.is_empty() or (v != null and (not VillageImage.bound(v) or VillageImage.stale)): # studio:
		return _full_save() # studio: no chain on disk for this village yet
	var own := v != null and VillageImage.staged == null # studio: outside an acceptance: what changed since disk
	if own: # studio:
		VillageImage.stage(v, VillageImage.changes(v)) # studio:
	var data := _state(false) # studio:
	if outer: # studio:
		data["region_world"] = {Region.current: _region_now()} # studio:
	data["village"] = VillageImage.staged.line if v != null else {} # studio:
	var error: Error = _journal.append(data) # studio:
	if own: # studio:
		if error == OK: # studio:
			VillageImage.commit(v) # studio:
		else: # studio:
			VillageImage.unstage() # studio:
	if error == OK and ((outer and full) or _journal.bytes >= JOURNAL_LIMIT): # studio:
		_checkpoint() # studio:
	return error # studio:


# studio: the current region's world as its own line (a checked save carries only the village and belongings).
# studio: a village disk does not describe yet (a new game, a rebuilt village) is written whole in an ordinary frame,
# studio: so the first reaction never pays for the full save and the image's first binding (39 ms measured, 5 Oct).
var _bind_retry := 0 # studio:
func _bind_now(v) -> void: # studio:
	if not _enabled or paused or not is_instance_valid(_player) or PeopleAcceptance._accepting or Time.get_ticks_msec() < _bind_retry: # studio:
		return # studio:
	if _journal.chain.is_empty() or not VillageImage.bound(v) or VillageImage.stale: # studio:
		if _full_save() != OK: # studio:
			_bind_retry = Time.get_ticks_msec() + 1000 # studio: a failed write is retried, not every frame
func _world_line(full: bool) -> Error: # studio:
	var error: Error = _journal.append({"region_world": {Region.current: _region_now()}}) # studio:
	if error == OK and (full or _journal.bytes >= JOURNAL_LIMIT): # studio:
		_checkpoint() # studio:
	return error # studio:


func _region_now() -> Dictionary: # studio:
	_regions[Region.current] = {"world": WorldResources.to_data(), "layout": str(WorldResources.layout_id()), "saved_at": Time.get_unix_time_from_system()} # studio:
	return _regions[Region.current] # studio:


func _checkpoint() -> void: # studio:
	_journal.checkpoint() # studio:
	_last_full = Time.get_ticks_msec() / 1000.0 # studio:


# studio: everything a save holds except the village; the world regions only in a full save.
func _state(with_regions: bool) -> Dictionary: # studio:
	var p := _player.global_position # studio:
	var data := {"version": VERSION, "inventory": Inventory.to_data(), "gear": Gear.to_data(), "armor": Armor.to_data(), # studio:
		"skills": Skills.to_data(), "coins": Money.coins, "projects": Projects.to_data(), "home": Home.to_data(), # studio:
		"quests": Quests.to_data(), "classes": Classes.to_data(), "hunting": Hunting.to_data(), "region": Region.current, # studio:
		"bounties": Bounties.to_data(), "residents": Residents.to_data(), "lettings": Lettings.to_data(), # studio: merge - his six saved kinds
		"waystones": Waystones.to_data(), "companions": Companions.to_data(), "fishing": FishData.to_data(), # studio:
		"player": {"pos": [p.x, p.y, p.z], "facing": _player.visual.rotation.y, "indoors": _indoors()}, # studio:
		"clock": WorldClock.to_data()} # studio: merge - the one world clock, saved once (its time of day is derived)
	if with_regions: # studio:
		_region_now() # studio:
		data["regions"] = _regions # studio:
	return data # studio:


# studio: a full save from live state starts a new chain; the image then describes exactly what is on disk.
func _full_save() -> Error: # studio:
	_journal.wait() # studio: never two writers of the save file
	var data := _state(true) # studio:
	data["village"] = VillageSession.to_data() # studio: accepted state precedes animation
	var id := "%d-%d" % [int(Time.get_unix_time_from_system()), randi()] # studio:
	data["save_id"] = id # studio:
	var text := JSON.stringify(data) # studio:
	var error := SafeFile.write_text(_path, text) # studio: checked normal save; callers publish consequences after OK
	if error == OK: # studio:
		_journal.rebase(id, text) # studio:
		if VillageSession.village != null: # studio:
			VillageImage.rebase(VillageSession.village, true) # studio:
		_last_full = Time.get_ticks_msec() / 1000.0 # studio:
	return error # studio:


func _read() -> Dictionary:
	var fallback := {}
	for path in SafeFile.candidates(_path):      # the save, or what a crash mid-save left behind
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path)) != OK:
			continue
		var data: Variant = parser.data
		if data is Dictionary and data.get("version", 0) == VERSION:
			data = SaveJournal.replay(data, _path + ".journal") # studio: step 4 journal lines on top of the full save
			var village: Variant = data.get("village", {})
			if not village is Dictionary or (not village.is_empty() and not VillageSession.Save.valid(village)):
				if fallback.is_empty():
					_keep_rejected(path) # studio: the rejected village is kept byte-for-byte before any rebuild can overwrite it
					fallback = data.duplicate(true)
					fallback.erase("village")
					fallback["village_recovery"] = true
				continue
			return data
	return fallback


# studio: proposal (people rule 7, 4 Oct) - a village the codec refuses is preserved once per run, never silently lost.
static var _kept_rejected := false # studio:
func _keep_rejected(path: String) -> void: # studio:
	if _kept_rejected: # studio:
		return # studio:
	_kept_rejected = true # studio:
	var keep := "user://village-rejected-%d.json" % int(Time.get_unix_time_from_system()) # studio:
	var error := DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(keep)) # studio:
	push_error("VILLAGE REJECTED save kept at %s (copy error %d); belongings restored, village rebuilt" % [keep, error]) # studio:


## The region the save was made in, so main can build it before loading (real runs only).
func saved_region() -> String:
	if not OS.get_cmdline_user_args().is_empty() and _path == PATH:
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
	Residents.load_data(data.get("residents", {})) # studio: merge - before the village: Mind's port reads his liking and lettings when his seven join
	Lettings.load_data(data.get("lettings", {})) # studio: merge - (moved up from below)
	VillageSession.load_data(data.get("village", {}))
	WorldClock.load_data(data) # studio: merge - "clock", or a save from before it: its time of day on day 0
	VillageSession.initial_minute = WorldClock.minute % 1440 # studio:
	if data.get("village_recovery", false):
		VillageSession.recovery_notice = "Village record damaged; your belongings were restored."
	Quests.load_data(data.get("quests", {}))
	Classes.load_data(data.get("classes", {}))
	Hunting.load_data(data.get("hunting", {}))
	Bounties.load_data(data.get("bounties", {}))
	Waystones.load_data(data.get("waystones", []))
	Companions.load_data(data.get("companions", {}))
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
	_day_night.time_of_day = WorldClock.time_of_day() # studio: merge - the sky shows the one world clock
	if VillageSession.village != null: # studio: the loaded village starts this session's journal chain (one full save at load)
		_full_save() # studio:


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
	Lettings.load_data(data.get("lettings", {}))
	Waystones.load_data(data.get("waystones", []))
	Companions.load_data(data.get("companions", {}))
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
	SafeFile.remove(_path)   # and its backup, or the next launch would bring the old world back
	_journal.reset() # studio:
	if FileAccess.file_exists(_path + ".journal"): # studio:
		DirAccess.remove_absolute(_path + ".journal") # studio:
	_enabled = false        # don't save the old world on the way out
	_regions = {}
	VillageSession.reset()
	WorldClock.reset() # studio: merge - a new world starts at its first morning
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
	Lettings.load_data({})
	Waystones.load_data([])
	Companions.load_data({})
	FishData.load_data({})
	WorldResources.reset()
	get_tree().reload_current_scene()
