class_name Hauling
extends Node
## Dragging a body (world/carcass.gd) or riding the ox cart (world/ox_cart.gd). While dragging you're slow
## and can't roll, fight or sprint: the action button says Drop (a hit makes you drop it too). While riding,
## the stick drives the ox and the action button says Get off. Both carry on through region gates.

var carrying: Node3D = null
var riding: Node3D = null

@onready var player: CharacterBody3D = get_parent()


func _ready() -> void:
	Region.leaving.connect(leaving)


func busy() -> bool:
	return carrying != null or riding != null


func start_carry(body: Node3D) -> void:
	if busy():
		return
	carrying = body
	body.start_drag()
	player.set_sneaking(false)
	player.visual.walk_anim = "Push"         # bent over, hands on it, stepping backwards
	player.visual.walk_backward = true
	get_tree().call_group("hud", "hint", "Dragging it. Slow going, and no fighting: Drop to let go.")
	preload("res://scripts/studio/player/haul.gd").start(player, body)   # studio: a wolf or stag on the shoulders, the rest dragged forward (note 230032)


func drop() -> void:
	if is_instance_valid(carrying):
		carrying.release()
	carrying = null
	_walk_normally()


## Handed over (the cart or the butcher took it).
func let_go_of(body: Node3D) -> void:
	if carrying == body:
		carrying = null
		_walk_normally()


func _walk_normally() -> void:
	player.visual.walk_anim = ""
	player.visual.walk_backward = false
	preload("res://scripts/studio/player/haul.gd").stop(player)   # studio: (note 230032)


func mount(cart: Node3D) -> void:
	if busy():
		return
	riding = cart
	player.set_sneaking(false)
	player.collision_layer = 0
	player.collision_mask = 0
	player.visual.loop_animation("Sitting_Idle")
	player.visual.idle_anim = "Sitting_Idle"
	player.visual.play_motion(0.0)


func get_off() -> void:
	if riding == null:
		return
	var side: Vector3 = riding.side_spot()
	riding.rider_left()
	riding = null
	player.global_position = side
	player.collision_layer = 1
	player.collision_mask = 1
	player.visual.idle_anim = ""
	player.velocity = Vector3.ZERO


## Before a region gate reloads the world: remember what comes along.
func leaving(to: String, arrive: Vector2) -> void:
	if is_instance_valid(carrying):
		Hunting.carried = {"kind": carrying.kind, "age": carrying.age}
	if riding and riding.is_in_group("elk"):
		Hunting.elk_riding = true
	elif riding:
		Hunting.riding = true
		Hunting.cart["region"] = to
		Hunting.cart["at"] = arrive
