class_name WolfVisual
extends BoarVisual
## The wolf's look: the boar's animation (trot, eye glow, flash, health bar, fall) plus a wagging
## tail and a jaw that snarls while it stalks and snaps when it lunges. Model: make_wolf.py.

var crouch := false        # set by Wolf just before it lunges (the tell)


func _init() -> void:
	model_scene = preload("res://assets/creatures/wolf.glb")
	paws = false
	mark_height = 1.55
	bar_height = 1.35


func _pose(swing: float, bob: float, head_pitch: float, stride: float) -> void:
	var tail_lift := 0.0
	var tail_wag := sin(_time * 3.0) * 0.15
	var jaw_open := 0.0
	match mode:
		"alert":           # head low, snarling, tail stiff and low
			head_pitch = 0.22 + sin(_time * 18.0) * 0.015
			jaw_open = 0.18 + sin(_time * 22.0) * 0.04
			tail_lift = -0.25
			tail_wag = 0.0
		"charge":          # stretched out, jaws wide
			head_pitch = 0.1
			jaw_open = 0.55
			tail_lift = 0.25
			tail_wag = 0.0
		"hurt":
			jaw_open = 0.35
			tail_lift = -0.5
		"dead":
			tail_wag = 0.0
	if crouch:             # low and coiled, jaws open
		head_pitch = 0.35
		jaw_open = 0.4
	super(swing, bob, head_pitch, stride)
	if crouch:
		_parts["Body"].position.y -= 0.08
		_parts["Head"].position.y -= 0.1
	_parts["Tail"].transform = _rest["Tail"] * Transform3D(Basis(Vector3.UP, tail_wag) * Basis(Vector3.RIGHT, tail_lift + swing * 0.2), Vector3.ZERO)
	_parts["Jaw"].transform = _rest["Jaw"] * Transform3D(Basis(Vector3.RIGHT, jaw_open), Vector3.ZERO)
