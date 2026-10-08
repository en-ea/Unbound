extends Node
## Waystones (game state): one old standing stone in each region. Walk up to one and it wakes (attuned);
## at any waystone you've woken, Travel opens the map and takes you to any other one you've woken, in a
## flash of light (the same region, or another: Region.travel). World: world/waystone.gd; the map:
## ui/world_map.gd.

signal changed

## Region -> the stone's name and where it stands (x, z). Their ground is a clearing in WorldShape.REGIONS.
const STONES := {
	"meadow": {"name": "Village Waystone", "at": Vector2(-6.0, 44.0)},
	"forest": {"name": "Fernhollow Waystone", "at": Vector2(-11.0, 9.0)},
	"highlands": {"name": "Shepherd's Waystone", "at": Vector2(-7.5, -46.0)},
	"sands": {"name": "Saffra Waystone", "at": Vector2(-2.0, 54.0)},
}
const ARRIVE := Vector2(0.0, 2.6)            # where you step out, from the stone (towards its front)

var found: Array[String] = []


func is_found(region: String) -> bool:
	return region in found


## The action: a waystone wakes for you. Returns true the first time.
func attune(region: String) -> bool:
	if not STONES.has(region) or region in found:
		return false
	found.append(region)
	changed.emit()
	return true


## Whether you can travel right now (not dragging a body or riding the cart; not mid-trip).
func can_travel(player: Node) -> String:
	if player.hauling.carrying:
		return "Put the body down first"
	if player.hauling.riding and player.hauling.riding.is_in_group("ox_cart"):
		return "Get off the cart first"
	return ""


## The action: go to a woken waystone. In this region: a flash and you're there. Elsewhere: through the
## region change (saves, fades, rebuilds).
func travel(to: String, player: Node3D) -> void:
	if not is_found(to) or can_travel(player) != "":
		return
	if player.hauling.riding:
		player.hauling.get_off()
	var at: Vector2 = STONES[to]["at"] + ARRIVE
	if to == Region.current:
		Region.fade_through(func() -> void:
			var shape := Carcass.shape
			player.global_position = Vector3(at.x, (shape.height_at(at.x, at.y) if shape else 0.0) + 0.3, at.y)
			player.velocity = Vector3.ZERO
			player.get_tree().call_group("camera_rig", "snap")
			player.get_tree().call_group("companion", "come_to", player.global_position))
	else:
		Region.travel(to, at)


func to_data() -> Array:
	return found


func load_data(data: Variant) -> void:
	found = []
	if data is Array:
		for r: Variant in data:
			if STONES.has(str(r)) and str(r) not in found:
				found.append(str(r))
	changed.emit()
