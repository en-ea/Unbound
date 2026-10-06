extends "res://scripts/studio/people/step.gd"
## A report waits for real proximity AND a checked save. Timeout never reports an arrival.
const ID := "report"
func update(port: Dictionary, step: Dictionary, _st: Dictionary, _dt: float) -> bool:
	return bool(port.report.call(str(step.target),step.account))
