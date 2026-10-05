extends Node3D
## Builds the current region (Region.current: the meadow, the forest...) and places the player.

@onready var terrain: Node = $Terrain
@onready var scatter: Node = $Scatter
@onready var player: CharacterBody3D = $Player
@onready var camera_rig: Node3D = $CameraRig


func _ready() -> void:
	var first_load := Region.arrive == Vector2.INF
	if first_load:
		Region.current = SaveGame.saved_region()
	var meadow := Region.current == "meadow"
	var shape := WorldShape.new()
	terrain.build(shape)
	scatter.build(shape)
	terrain.bake_shade(scatter.shade_spots)
	$Landmark.place(shape)
	$ResourceVisuals.setup(scatter.gatherables)
	$OcclusionFader.setup(scatter.trees)
	$Enemies.spawn(shape)
	if meadow:
		$Village.build(shape)
	$HUD.setup_map(shape, scatter.tree_points(), $Landmark)
	var treasure := Node3D.new()
	treasure.set_script(preload("res://scripts/world/treasure.gd"))
	treasure.player = player
	add_child(treasure)
	treasure.build(shape)
	if meadow:
		var workbench := Node3D.new()
		workbench.set_script(preload("res://scripts/world/workbench.gd"))
		add_child(workbench)
		workbench.build(shape, Vector2(-15.5, 3.0))
	var fire := Node3D.new()
	fire.set_script(preload("res://scripts/world/campfire.gd"))
	add_child(fire)
	fire.build(shape, Vector2(-4.5, 17.0) if meadow else Vector2(4.0, -81.5))
	for id: String in Projects.DEFS:
		if Projects.DEFS[id]["region"] == Region.current:
			var site := Node3D.new()
			site.set_script(preload("res://scripts/world/project_site.gd"))
			add_child(site)
			site.build(shape, id)
	if meadow:
		var plot := Node3D.new()
		plot.set_script(preload("res://scripts/world/home_plot.gd"))
		plot.player = player
		plot.day_night = $WorldEnvironment
		add_child(plot)
		plot.build(shape)
	var bounty_board := Node3D.new()
	bounty_board.set_script(preload("res://scripts/world/bounty_board.gd"))
	add_child(bounty_board)
	bounty_board.build(shape)
	var waystone := Node3D.new()                   # fast travel (Waystones)
	waystone.set_script(preload("res://scripts/world/waystone.gd"))
	waystone.player = player
	add_child(waystone)
	waystone.build(shape)
	var places := Node3D.new()
	places.set_script(preload("res://scripts/world/places.gd"))
	places.player = player
	add_child(places)
	places.build(shape)
	if meadow:
		var shrine := Node3D.new()
		shrine.set_script(preload("res://scripts/world/shrine.gd"))
		shrine.player = player
		add_child(shrine)
		shrine.build(shape)
	var camp := BanditCamp.new()
	camp.player = player
	camp.day_night = $WorldEnvironment
	add_child(camp)
	camp.build(shape)
	# Hunting: bodies need the ground height; the butcher's rack in the village; the ox cart wherever
	# it was left; the Duskmaw watch; a body you dragged through the gate comes with you.
	Carcass.shape = shape
	if meadow:
		var butcher := Node3D.new()
		butcher.set_script(preload("res://scripts/world/butcher.gd"))
		butcher.player = player
		add_child(butcher)
		butcher.build(shape)
	var director := Node3D.new()
	director.set_script(preload("res://scripts/world/hunt_director.gd"))
	director.player = player
	director.day_night = $WorldEnvironment
	add_child(director)
	var warm := Node3D.new()                       # class ability effects, shown once behind the loading cover
	warm.set_script(preload("res://scripts/world/ability_warmup.gd"))
	add_child(warm)
	var gates := Node3D.new()
	gates.set_script(preload("res://scripts/world/region_gates.gd"))
	gates.player = player
	add_child(gates)
	gates.build(shape)
	var guide := Node3D.new()
	guide.name = "QuestGuide"
	guide.set_script(preload("res://scripts/world/quest_guide.gd"))
	guide.player = player
	add_child(guide)
	guide.build(shape)
	var lab := Node3D.new()
	lab.set_script(preload("res://scripts/dev/build_lab.gd"))
	lab.player = player
	lab.scatter = scatter
	lab.visuals = $ResourceVisuals
	lab.treasure = treasure
	add_child(lab)
	var fishing := Node3D.new()                    # fish anywhere along the pond's edge
	fishing.set_script(preload("res://scripts/world/fishing_spots.gd"))
	fishing.player = player
	add_child(fishing)
	fishing.build(shape)
	if Region.current == "forest":                 # Glimmerdeep, under the Cave Mouth
		var cave := Node3D.new()
		cave.set_script(preload("res://scripts/world/cave.gd"))
		cave.player = player
		cave.day_night = $WorldEnvironment
		cave.scatter = scatter
		cave.visuals = $ResourceVisuals
		cave.treasure = treasure
		cave.door_out = Vector3(-62, shape.height_at(-62, 76.5) + 0.3, 76.5)
		add_child(cave)
	var critters := Node3D.new()
	critters.set_script(preload("res://scripts/world/critters.gd"))
	critters.player = player
	critters.day_night = $WorldEnvironment
	add_child(critters)
	critters.build(shape)
	$Player/Sounds.shape = shape
	var spawn := WorldShape.SPAWN
	player.global_position = Vector3(spawn.x, shape.height_at(spawn.x, spawn.y) + 0.3, spawn.y)
	player.spawn_point = player.global_position
	_hunting_arrival.call_deferred()
	var arrive := Region.arrive
	SaveGame.attach(player, $WorldEnvironment)
	if arrive != Vector2.INF:          # came through a gate: stand just inside it, facing in
		player.global_position = Vector3(arrive.x, shape.height_at(arrive.x, arrive.y) + 0.3, arrive.y)
		player.visual.rotation.y = atan2(-arrive.x, -arrive.y)
	camera_rig.snap()
	Region.arrived(not first_load)


## The ox cart (if it's in this region) and a body you dragged through the gate, placed once you're in.
func _hunting_arrival() -> void:
	if Hunting.cart["region"] == Region.current:
		if Hunting.riding:                     # came through on the cart: it arrives beside you
			var p := player.global_position
			Hunting.cart["at"] = Vector2(p.x, p.z)
		var cart := Node3D.new()
		cart.set_script(preload("res://scripts/world/ox_cart.gd"))
		cart.player = player
		add_child(cart)
		cart.build(Carcass.shape)
	Hunting.riding = false
	if not Hunting.elk.is_empty():               # your elk: wherever you are, it's near (or under you)
		if Hunting.elk["region"] != Region.current or Hunting.elk_riding:
			var p := player.global_position + Vector3(2.5, 0, 1.5)
			Hunting.elk = {"region": Region.current, "at": Vector2(p.x, p.z), "yaw": 0.0}
		var elk := CharacterBody3D.new()
		elk.set_script(preload("res://scripts/world/elk_mount.gd"))
		elk.player = player
		add_child(elk)
		elk.build(Carcass.shape, Hunting.elk["at"], Hunting.elk["yaw"])
		if Hunting.elk_riding:
			(func() -> void: player.hauling.mount(elk)).call_deferred()
	Hunting.elk_riding = false
	if not Hunting.carried.is_empty():
		var c: Dictionary = Hunting.carried
		Hunting.carried = {}
		var body := Carcass.spawn(self, c["kind"], player.global_position - Vector3(0, 0, 1.5), 0.0, player, c["age"])
		player.hauling.start_carry(body)
