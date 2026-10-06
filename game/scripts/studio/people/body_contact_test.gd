extends Node
## Real P4 broad phase plus physics walls/actual bodies; no injury, Mind, save or animation substitutes.
const Contact := preload("res://scripts/studio/village/contact.gd")
const Nearby := preload("res://scripts/studio/people/nearby.gd")
const Fixture := preload("res://scripts/studio/people/foundation_state_test.gd")
const People := preload("res://scripts/studio/village/sim/people.gd")
const Residents := preload("res://scripts/studio/village/residents.gd")
const Body := preload("res://scripts/studio/village/villager_body.gd")
const Mover := preload("res://scripts/studio/people/mover.gd")
const Persona := preload("res://scripts/studio/people/persona.gd")
const Runner := preload("res://scripts/studio/people/body_elements.gd")
const Crowd := preload("res://scripts/studio/people/crowd.gd")
const Bridge := preload("res://scripts/studio/village/people_bridge.gd")
class Grid extends RefCounted:
	var nearby=Nearby.new()
class Registry extends Node:
	var bodies := {}
	var _movers := {}
	var _crowd=Grid.new()
class Live extends Node:
	var registry: Node
class ActorBridge extends Node:
	var carrier: Node3D
	func actor_node(_actor: String) -> Node3D:
		return carrier
var checks := 0
var failed := 0
func _ready() -> void:
	_run.call_deferred()
func check(ok: bool,words: String) -> void:
	checks+=1
	if not ok: failed+=1
	print(("PASS " if ok else "FAIL ")+words)
func _run() -> void:
	var tree := get_tree()
	var v=Fixture.fixture()
	var id := Fixture.adult(v)
	v.people[id].present=true
	v.people[id].locked=true
	VillageSession.village=v
	VillageSession.active=true
	VillageSession.background=false
	Controls.locked=false
	var scene := Node3D.new()
	tree.root.add_child(scene)
	tree.current_scene=scene
	var live := Live.new()
	live.name="VillageLive"
	scene.add_child(live)
	var res := Registry.new()
	live.registry=res
	scene.add_child(res)
	var source := Node3D.new()
	source.set_meta("people_actor","actor:cart")
	scene.add_child(source)
	var body := Node3D.new()
	body.position=Vector3(2,0,0)
	scene.add_child(body)
	res.bodies[id]=body
	res._movers[id]={"indoors":false,"pos":Vector2(2,0)}
	res._crowd.nearby.snapshot(PackedVector2Array([Vector2(2,0),Vector2(2,0)]),[
		{"key":People.key(v,id),"body":body},{"key":People.key(v,id),"body":body,"sensing_only":true}])
	await tree.physics_frame
	check(Contact.actor_of(source)=="actor:cart" and Contact.measure(tree,source,source.global_position,2.2,Vector3.RIGHT,id).size()==1,
		"generic actor measures a restrained body once despite physical/sensing grid rows")
	check(Contact.measure(tree,source,Vector3.ZERO,2.2,Vector3.RIGHT,-2).is_empty(),"captured air cannot become a later assault")
	var wall := StaticBody3D.new()
	wall.collision_layer=1
	wall.position=Vector3(1,0.8,0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=Vector3(0.2,3,5)
	collision.shape=shape
	wall.add_child(collision)
	scene.add_child(wall)
	await tree.physics_frame
	await tree.physics_frame
	check(Contact.measure(tree,source,Vector3.ZERO,2.2,Vector3.RIGHT,id).is_empty(),"actual wall ray blocks contact admitted by P4 broad phase")
	wall.position=Vector3(10,0.8,0)
	await tree.physics_frame
	await tree.physics_frame
	body.position=Vector3(5,0,0)
	check(Contact.measure(tree,source,Vector3.ZERO,2.2,Vector3.RIGHT,id).is_empty(),"actual body movement invalidates stale grid reach")
	body.position=Vector3(3,0,0.5)
	res._crowd.nearby.snapshot(PackedVector2Array([Vector2(3,0.5)]),[{"key":People.key(v,id),"body":body}])
	check(Contact.measure(tree,source,Vector3.ZERO,0.7,Vector3.ZERO,id,Vector3(4,0,0)).size()==1,
		"actual travelled capsule reaches contact along its sweep")
	res._movers[id].indoors=true
	check(Contact.measure(tree,source,Vector3.ZERO,0.7,Vector3.ZERO,id,Vector3(4,0,0)).is_empty(),
		"indoor body remains unavailable to outdoor physical contact")
	# Exercise the real residents carry port and Claude body, without creating a second movement owner.
	var mechanical := Residents.new()
	var carried_body := Body.new()
	scene.add_child(carried_body)
	var carry_mover := Mover.new(carried_body,Persona.motion({"key":id,"age":30}))
	carry_mover.actor_key=People.key(v,id)
	mechanical.bodies[id]=carried_body
	mechanical._movers[id]=carry_mover
	mechanical._elements[id]=Runner.new()
	mechanical._crowd=Crowd.new()
	var adapter := ActorBridge.new()
	adapter.carrier=source
	mechanical.people_bridge=adapter
	source.position=Vector3(6,2,0)
	v.people[id].body_facts={"carried":{"kind":"carried","id":"carried","deed":"lift","revision":1,
		"since_tick":People.tick(v),"strength":1000,"carrier":"actor:cart"},"location":{"at":[100.0,100.0]}}
	mechanical._physical(id,0.05)
	var anchored := carried_body.global_position.is_equal_approx(source.global_position+Vector3(0,0.8,-0.8))
	var held: bool=mechanical.owners.held(id,"carry") and not carry_mover.can_move()
	var actual := Vector2(carried_body.global_position.x,carried_body.global_position.z)
	v.people[id].body_facts.erase("carried")
	mechanical._physical(id,0.05)
	check(anchored and held and carry_mover.pos.is_equal_approx(actual) and carry_mover.can_move() and mechanical.owners.is_free(id) and not source.has_meta("studio_people_load"),
		"rehydrated carry uses the actual carrier, then releases one owner from actual position")
	# Drive current apparent matching through the REAL source bridge, including its normal mask discovery.
	carried_body.position=Vector3.ZERO
	carry_mover.pos=Vector2.ZERO
	source.position=Vector3(1.5,0,0)
	mechanical._crowd.nearby.snapshot(PackedVector2Array([Vector2(1.5,0)]),[{"key":"actor:cart","body":source}])
	var sensing := Bridge.new(mechanical)
	mechanical.people_bridge=sensing
	var hints := {"attention":{"identity":"actor:cart","at":[100,100],"watch":0.8},"regard":[{"identity":"actor:cart","keep_m":3.0,"watch":0.8}]}
	var unknown: Dictionary=mechanical._regard(id,hints)
	check(unknown.space.is_empty() and unknown.look==Vector3.INF,"an unfamiliar generic body cannot supply a civil-identity tracking match")
	source.set_meta("people_recognized_by",[carry_mover.actor_key])
	mechanical.express_body(id,hints)
	check(carry_mover.regard.has(source.get_instance_id()) and mechanical._expression_look[id]==source.global_position+Vector3(0,1.4,0),
		"regard and named attention bind current visible geometry, not the old saved position")
	People.mind(v,"actor:cart").modifiers=[{"id":"masked","look":"look:masked:red"}]
	sensing.modifier_folders.append("res://scripts/studio/people/proofs/forward/")
	var civil: Dictionary=mechanical._regard(id,hints)
	hints.attention.identity="look:masked:red"
	hints.regard[0].identity="look:masked:red"
	var apparent: Dictionary=mechanical._regard(id,hints)
	check(civil.space.is_empty() and civil.look==Vector3.INF and apparent.space.has(source.get_instance_id()),
		"changing appearance breaks civil tracking and only the matching visible mask keeps room")
	wall.position=Vector3(0.75,0.8,0)
	await tree.physics_frame
	await tree.physics_frame
	var blocked: Dictionary=mechanical._regard(id,hints)
	wall.position=Vector3(10,0.8,0)
	source.hide()
	var hidden: Dictionary=mechanical._regard(id,hints)
	source.show()
	source.position=Vector3(20,0,0) # deliberately leave the old P4 row behind
	var departed: Dictionary=mechanical._regard(id,hints)
	check(blocked.space.is_empty() and blocked.look==Vector3.INF and hidden.space.is_empty() and departed.space.is_empty() and departed.look==Vector3.INF,
		"walls, hidden bodies and actual departure break regard despite a stale nearby row")
	sensing.free()
	mechanical._elements[id].stop()
	mechanical._crowd.free()
	adapter.free()
	mechanical.free()
	print("BODY CONTACT complete: %d checks, %d failed" % [checks,failed])
	tree.quit(1 if failed>0 else 0)

