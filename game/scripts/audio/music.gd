class_name Music
extends Node
## Background music (CC0 tracks in assets/music, see LICENSE.txt there). One track plays at a time and
## crossfades to the next: the village tune near the houses, the meadow tune out in the fields, the forest
## tune in the Whispering Wood, the fight tune while an enemy is after you, and the boss tune while a boss
## (group "boss") is awake. Quieter at night and indoors. Settings.music_on turns it off.

const DIR := "res://assets/music/"
const VILLAGE_AT := Vector2(0.0, 17.0)     # the middle of the village (village.gd houses)
const VILLAGE_R := 26.0
const FIGHT_R := 26.0                      # an enemy after you this close counts as a fight
const CALM_AFTER := 5.0                    # seconds without a fight before the calm tune returns
const FADE := 2.5                          # seconds to crossfade
const LEVEL := {"village": 0.5, "meadow": 0.55, "forest": 0.6, "fight": 0.55, "boss": 0.65}

var day_night: Node
var listener: Node3D

var _players := {}                         # track -> AudioStreamPlayer
var _want := ""
var _fight_left := 0.0
static var _stinger: AudioStreamPlayer
## The story takes the music over for a set-piece (story/awakening.gd): a track name, "none" for a hard
## silence, or "" to give it back. Changes fade fast, so a cut lands with the moment.
static var story := ""


func _ready() -> void:
	for track: String in LEVEL:
		var p := AudioStreamPlayer.new()
		var s: AudioStream = load(DIR + track + ".ogg")
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		p.stream = s
		p.volume_db = -80.0
		add_child(p)
		_players[track] = p
	_stinger = AudioStreamPlayer.new()
	add_child(_stinger)


## A short one-off sound over the music (story moments, a boss waking), with the music ducked under it.
static func sting(stream: AudioStream, volume_db := -2.0) -> void:
	if _stinger and stream:
		_stinger.stream = stream
		_stinger.volume_db = volume_db
		_stinger.play()


func _process(delta: float) -> void:
	_want = _pick(delta) if Settings.music_on else ""
	if story != "":
		_want = "" if story == "none" or not Settings.music_on else story
	var fade := 0.7 if story != "" else FADE
	var night: float = day_night.night if day_night else 0.0
	var indoors: bool = day_night.indoors if day_night else false
	var scale := lerpf(1.0, 0.6, night) * (0.45 if indoors else 1.0)
	if _stinger.playing and story == "":
		scale *= 0.35
	for track: String in _players:
		var p: AudioStreamPlayer = _players[track]
		var now := db_to_linear(p.volume_db)
		var goal: float = LEVEL[track] * scale if track == _want else 0.0
		now = move_toward(now, goal, delta / fade)
		p.volume_db = linear_to_db(maxf(now, 0.0001))
		if now > 0.001 and not p.playing:
			p.play()
		elif now <= 0.001 and p.playing and track != _want:
			p.stop()


func _pick(delta: float) -> String:
	if not get_tree().get_nodes_in_group("boss").filter(func(b: Node) -> bool: return b.has_method("is_awake") and b.is_awake()).is_empty():
		return "boss"
	if _enemy_after_you():
		_fight_left = CALM_AFTER
	else:
		_fight_left -= delta
	if _fight_left > 0.0:
		return "fight"
	if Region.current == "forest":
		return "forest"
	if listener and Vector2(listener.global_position.x, listener.global_position.z).distance_to(VILLAGE_AT) < VILLAGE_R:
		return "village"
	return "meadow"


func _enemy_after_you() -> bool:
	if not listener:
		return false
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.has_method("is_engaged") and e.is_engaged() and (e as Node3D).global_position.distance_to(listener.global_position) < FIGHT_R:
			return true
	return false
