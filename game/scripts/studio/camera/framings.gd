extends RefCounted
## The living camera's framings (docs/studio/CAMERA-AND-FORMAT.md section 4), as presets for look
## boards and, later, the camera prototype. BUILD is exactly the camera the game has today.
## Numbers are first guesses from geometry; the look board and play decide them.

const FRAMES := {
	"explore": {"distance": 8.0, "pitch": -10.0, "fov": 50.0, "lift": 0.0},    # walking: the horizon carries the world
	"fight": {"distance": 12.0, "pitch": -32.0, "fov": 45.0, "lift": 0.0},     # close to the tuned view, tells still read
	"build": {"distance": 18.0, "pitch": -45.0, "fov": 32.0, "lift": 0.0},     # today's camera, unchanged
	"vantage": {"distance": 6.0, "pitch": -5.0, "fov": 40.0, "lift": 14.0},    # as if from a tower or hilltop
}


## rig: the CameraRig (follow_camera.gd). Instant, so a screenshot can follow straight away.
static func apply(rig: Node3D, frame_name: String) -> void:
	var f: Dictionary = FRAMES.get(frame_name, FRAMES["build"])
	rig.set_view(f["distance"], f["pitch"], Vector3(0.0, f["lift"], 0.0), 0.01)
	rig.camera.fov = f["fov"]
