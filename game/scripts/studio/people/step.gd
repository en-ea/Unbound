extends RefCounted
## C4 primitive: ID; begin(port,step)->transient; update(port,step,state,dt seconds)->done.
## port {actor,mover,body,at(ref),route,say,report}; no saved paths/frames or global choice authority.
func begin(_port: Dictionary, _step: Dictionary) -> Dictionary:
	return {}
func update(_port: Dictionary, _step: Dictionary, _state: Dictionary, _dt: float) -> bool:
	return true
