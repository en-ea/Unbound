extends RefCounted
## B6-B8 normal-discovery element: ID, HOLDS, GIVES; optional FROM channel or {channel: threshold}.
## begin(port,strength 0..1,fact)->state; step(port,state,dt active seconds)->done; end(port,state).
## port {body,mover,source,tick,age_ms,rehydrating,present,visible,hints,current(fact),live(fact),
## emit(kind,fields),announce(kind,fact,transition=false),pose(key,fields),drop_pose(key),vocal(kind,strength)}.
## Fact strength adapted ONCE from 0..1000. current returns actual matching saved revision or {}.
## Removed facts finish through step (down may get up); end cleans only its layers/constraints.
## age_ms reconstructs condition. rehydrating forbids replayed impulses, transitions and cries.
## Named pose fields are visual-owner data; runtime stores them, body.apply_elements(layers) consumes them.
## No appraisal, injury, save, travel owner or choice. Hints contain no destinations/clip names.
func begin(_port: Dictionary, _strength: float, _fact: Dictionary) -> Dictionary:
	return {}
func step(_port: Dictionary, _state: Dictionary, _dt: float) -> bool:
	return true
func end(_port: Dictionary, _state: Dictionary) -> void:
	pass
