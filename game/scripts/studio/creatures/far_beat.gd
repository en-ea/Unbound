extends RefCounted
## Animals far from the player think a few times a second (Hilmi, 6 Oct smoothness tuning: "think far less frequently";
## the desk's design: "animals far from the player at a low physics or update rate"). One marked line at the top of a
## creature's _physics_process:
##
##   delta = FarBeat.owed(self, player, delta, calm)      then   if delta <= 0.0: return
##
## calm: wandering or grazing (anything else - alert, a fight, fleeing, hurt - runs every frame wherever it is).
## Calm and beyond FAR_M it runs every FAR_S with the time owed, beyond VERY_FAR_M every VERY_FAR_S; in between it glides
## on at its last velocity along the ground (no rays, no collision step), so nothing visibly steps. Its own visual
## animates in its own _process every frame as before. Its memory rides on the body (metadata "far_beat").
const FAR_M := 25.0          # metres from the player (well past a wolf's or a boar's SIGHT 10)
const FAR_S := 0.2
const VERY_FAR_M := 60.0
const VERY_FAR_S := 1.0
const META := "far_beat"


static func owed(body: CharacterBody3D, player: Node3D, delta: float, calm: bool) -> float:
	var left: float = body.get_meta(META, 0.0)
	var d2 := body.global_position.distance_squared_to(player.global_position) if is_instance_valid(player) else 0.0
	if not calm or d2 < FAR_M * FAR_M:
		if left > 0.0:
			body.set_meta(META, 0.0)
		return delta + left
	var period := FAR_S if d2 < VERY_FAR_M * VERY_FAR_M else VERY_FAR_S
	left += delta
	if left < period * (0.75 + 0.5 * float(body.get_instance_id() % 97) / 97.0):   # (each on its own beat)
		body.set_meta(META, left)
		body.global_position += Vector3(body.velocity.x, 0.0, body.velocity.z) * delta
		return 0.0
	body.set_meta(META, 0.0)
	return left
