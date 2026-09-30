extends Node
## Look check for the daily-life loops (resident_anims.gd): a row of villagers, each looping one animation,
## its name floating above. Sets: --anim-set=work | rest | social | all (default all, in rows of eight).
## Run (open ground, the camera at the game's angle): --studio=village/anim_lineup --anim-set=work --at=2,24
##   --shot=C:/path/work.png [--shotframe=240]   (the game's own --shot saves the screenshot and quits)

const VillagerBody := preload("res://scripts/studio/village/villager_body.gd")
const SETS := {
	"work": ["Farm_Harvest", "Farm_PlantSeed", "Farm_Watering", "TreeChopping:axe", "TreeChopping:pickaxe", "Push", "Fixing_Kneeling", "PickUp_Table"],
	"rest": ["Idle", "Idle_FoldArms", "Consume", "Sitting_Idle", "Crouch_Idle", "Idle_Lantern", "Interact", "Spell_Simple_Idle"],
	"social": ["Idle_Talking", "Sitting_Talking", "Yes", "Idle_No", "Idle_Rail_Call", "Idle_TalkingPhone", "Dance", "Chest_Open"],
}
const GAP := 1.35

var _frame := 0
var _set := "all"


static func on_device(tree: SceneTree) -> void:
	var probe: Node = (load("res://scripts/studio/village/anim_lineup.gd") as GDScript).new()
	tree.root.add_child.call_deferred(probe)


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--anim-set="):
			_set = arg.trim_prefix("--anim-set=")


func _process(_delta: float) -> void:
	_frame += 1
	if _frame == 8:
		_build()


func _build() -> void:
	var player := get_tree().current_scene.get_node("Player") as Node3D
	player.visible = false
	var shape := WorldShape.new()
	var names: Array = []
	if _set == "all":
		for key: String in SETS:
			names.append_array(SETS[key])
	else:
		names = SETS.get(_set, SETS.work)
	var x := -(names.size() - 1) * GAP / 2.0
	for entry: String in names:
		var bits := entry.split(":")
		var at := player.global_position + Vector3(x, 0.0, 0.0)
		at.y = shape.height_at(at.x, at.z)
		var body := VillagerBody.new()
		var look := CharacterLook.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(entry)
		look.randomize_look(rng)
		body.hero_look = look
		body.is_player_look = false
		add_child(body)
		body.global_position = at
		body.rotation.y = 0.0
		body.play_loop(bits[0], 0.0, 1.0, 0.7)
		if bits.size() > 1:
			body.show_tool(bits[1])
		var label := Label3D.new()
		label.text = entry.replace(":", "\n+ ")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.font_size = 30
		label.pixel_size = 0.005
		label.outline_size = 10
		label.position = at + Vector3(0.0, 2.05, 0.0)
		add_child(label)
		x += GAP
		print("STUDIO anim %s: %.2f s" % [entry, body.animation_length(bits[0])])
	var rig := get_tree().current_scene.get_node("CameraRig")
	rig.set_view(maxf(names.size() * GAP * 1.05, 8.0), -10.0, Vector3(0.0, 1.0, 0.0), 0.01)
