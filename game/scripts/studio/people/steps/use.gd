extends "res://scripts/studio/people/step.gd"
## C4 physical use: bridge checks real contact and saves before true. Timeout cannot invent success.
const ID := "use"
func update(port: Dictionary,step: Dictionary,_state: Dictionary,_dt: float) -> bool:
	return bool(port.use.call(step))
