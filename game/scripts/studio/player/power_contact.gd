extends Node
## B6/P1 actual dash segments after native movement. Generic actor ref/cast key; no injury/choice/visual author.
const Contact := preload("res://scripts/studio/village/contact.gd")
var actor_body: Node3D
var _casts := {}
func _init(body: Node3D) -> void:
	actor_body=body
func _ready() -> void:
	process_physics_priority=20
func begin(key: String,seconds: float,radius: float,force: int,heat: int) -> void:
	_casts[key]={"at":actor_body.global_position,"left":seconds,"radius":radius,"force":force,"heat":heat}
func _physics_process(dt: float) -> void:
	if Controls.locked or VillageSession.background or dt<=0 or not is_instance_valid(actor_body):
		return
	var actor := Contact.actor_of(actor_body)
	for key: String in _casts.keys():
		var cast: Dictionary=_casts[key]
		var at := actor_body.global_position
		Contact.sweep(get_tree(),actor,actor_body,cast.at,at,float(cast.radius),key,"burn",{"force":cast.force,"heat":cast.heat})
		cast.at=at
		cast.left-=dt
		if float(cast.left)<=0:
			Contact.end_sweep(actor,key)
			_casts.erase(key)
func _exit_tree() -> void:
	if is_instance_valid(actor_body):
		for key: String in _casts:
			Contact.end_sweep(Contact.actor_of(actor_body),key)
	_casts.clear()

