extends SceneTree
## Body-owned bootstrap: load the physics fixture after project autoloads are registered.
## engine_batch -> job.sh -> --headless --script this file. The fixture prints the completion marker.
var _ran := false
func _process(_delta: float) -> bool:
	if not _ran:
		_ran=true
		var script := load("res://scripts/studio/people/body_contact_test.gd") as Script
		if script==null or not script.can_instantiate():
			quit(1)
		else:
			root.add_child(script.new())
	return false
