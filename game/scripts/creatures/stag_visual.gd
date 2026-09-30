class_name StagVisual
extends BoarVisual
## The stag's look: the boar's animation (legs, flash, health bar, fall) with a long neck that dips to
## graze, snaps up when it hears you (ears and tail up), and stretches out in a gallop. Model: make_stag.py.


func _init() -> void:
	model_scene = preload("res://assets/creatures/stag.glb")
	paws = true
	mark_height = 3.3
	bar_height = 2.4


func _pose(swing: float, bob: float, head_pitch: float, stride: float) -> void:
	var tail_lift := 0.0
	match mode:
		"graze":        # head right down in the grass, a slow chew
			head_pitch = 0.95 + sin(_time * 2.2) * 0.05
			swing = 0.0
		"listen", "alert":        # head high and still, listening (alert: angry, with the red "!")
			head_pitch = -0.18
			tail_lift = 0.6
		"flee":         # stretched out, head forward, tail up
			head_pitch = 0.2
			tail_lift = 0.9
			swing *= 1.3
		"windup":       # antlers lowered at you
			head_pitch = 0.55 + sin(_time * 18.0) * 0.03
		"charge":
			head_pitch = 0.6
	super(swing, bob, head_pitch, stride)
	if _parts.has("Tail"):
		_parts["Tail"].transform = _rest["Tail"] * Transform3D(Basis(Vector3.RIGHT, -tail_lift), Vector3.ZERO)
