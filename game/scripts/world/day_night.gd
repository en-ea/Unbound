extends WorldEnvironment
## Day/night cycle: moves the sun and moon and blends sky, fog, light and ambient colours.
## time_of_day: 0 = midnight, 0.25 = sunrise, 0.5 = noon, 0.75 = sunset.

@export var sun: DirectionalLight3D
@export var moon: DirectionalLight3D
@export var terrain: Node          # has a `material` with a cloud_strength parameter
@export var cycle_minutes := 12.0
@export_range(0.0, 1.0) var time_of_day := 0.3

## 0 in daylight, 1 at full night. Read by the fireflies.
var night := 0.0
## Inside a house: softer sunlight and a warmer, dimmer ambient (the room's own lights do the rest).
var indoors := false
var village_clock := false # studio: one logical clock for light and consequences
var cave := false                  # down in a cave (world/cave.gd): no sun or moon, cold dim light, close dark fog

const UPDATE_EVERY := 0.2

# Key times, and the look at each (sRGB colours, blended in between).
const KEYS := [0.0, 0.2, 0.26, 0.34, 0.5, 0.66, 0.74, 0.8, 1.0]
const SKY_TOP := [Color(0.03, 0.05, 0.14), Color(0.10, 0.12, 0.28), Color(0.34, 0.42, 0.68), Color(0.36, 0.58, 0.88),
	Color(0.32, 0.58, 0.92), Color(0.36, 0.56, 0.86), Color(0.34, 0.34, 0.62), Color(0.10, 0.10, 0.26), Color(0.03, 0.05, 0.14)]
const HORIZON := [Color(0.08, 0.11, 0.24), Color(0.30, 0.26, 0.42), Color(1.00, 0.68, 0.50), Color(0.88, 0.86, 0.80),
	Color(0.78, 0.88, 0.96), Color(0.92, 0.86, 0.74), Color(1.00, 0.56, 0.40), Color(0.34, 0.22, 0.38), Color(0.08, 0.11, 0.24)]
const SUN_COLOR := [Color(1, 0.8, 0.6), Color(1.0, 0.62, 0.40), Color(1.0, 0.72, 0.48), Color(1.0, 0.88, 0.7),
	Color(1.0, 0.93, 0.8), Color(1.0, 0.86, 0.66), Color(1.0, 0.62, 0.38), Color(1.0, 0.5, 0.35), Color(1, 0.8, 0.6)]
const SUN_ENERGY := [0.0, 0.0, 1.05, 1.5, 1.6, 1.55, 1.3, 0.0, 0.0]
const AMBIENT := [Color(0.36, 0.45, 0.72), Color(0.42, 0.40, 0.58), Color(0.62, 0.6, 0.72), Color(0.56, 0.66, 0.86),
	Color(0.56, 0.68, 0.9), Color(0.6, 0.66, 0.84), Color(0.66, 0.54, 0.62), Color(0.42, 0.40, 0.62), Color(0.36, 0.45, 0.72)]
const AMBIENT_ENERGY := [0.85, 0.85, 0.95, 0.92, 0.9, 0.92, 0.98, 0.85, 0.85]

var _sky_mat := ProceduralSkyMaterial.new()
var _timer := 0.0


func _ready() -> void:
	add_to_group("day_night")
	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 22.0
	env.fog_depth_end = 95.0
	env.fog_depth_curve = 1.3
	env.fog_density = 0.7
	env.fog_sky_affect = 0.6
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.0
	env.adjustment_contrast = 0.98
	environment = env
	_sky_mat.sun_angle_max = 20.0
	_sky_mat.sun_curve = 0.08
	_apply()


func _process(delta: float) -> void:
	if WorldClock != null: # studio: merge - the one world clock (studio/world/world_clock.gd) owns time
		time_of_day = WorldClock.time_of_day() # studio:
	else:
		time_of_day = fposmod(time_of_day + delta / (cycle_minutes * 60.0), 1.0)
	_timer -= delta
	if _timer <= 0.0:
		_timer = UPDATE_EVERY
		_apply()


func set_cave(on: bool) -> void:
	cave = on
	environment.fog_depth_begin = 9.0 if on else 22.0
	environment.fog_depth_end = 34.0 if on else 95.0
	_apply()


func set_indoors(on: bool) -> void:
	indoors = on
	_apply()


## Sets the clock (test menu: Make it night / day).
func set_time(t: float) -> void:
	WorldClock.advance_to_time(t) # studio: merge - forward on the one world clock (beds, the test menu)
	time_of_day = fposmod(t, 1.0)
	_apply()


## Jumps the clock forward (dev button).
func skip(fraction: float) -> void:
	WorldClock.advance(fraction * 1440.0) # studio: merge - the village catches up to the one world clock
	time_of_day = WorldClock.time_of_day() # studio:
	_apply()


func _apply() -> void:
	var t := time_of_day
	var a := (t - 0.25) * TAU
	# The sun rises in the east, peaks high in the north (so shadows fall towards the camera)
	# and sets in the west.
	var sun_dir := Vector3(cos(a), sin(a) * 0.9, -0.5).normalized()
	var moon_dir := Vector3(-cos(a), -sin(a) * 0.9, -0.5).normalized()
	sun.global_basis = Basis.looking_at(-sun_dir, Vector3.UP)
	moon.global_basis = Basis.looking_at(-moon_dir, Vector3.UP)

	var sun_e := _sample_f(SUN_ENERGY, t)
	sun.light_energy = sun_e
	sun.light_color = _sample_c(SUN_COLOR, t)
	# Lights stay visible (energy 0 when off): toggling them would make the phone rebuild shaders.
	sun.shadow_enabled = sun_dir.y > 0.2   # no shadows when the sun is low
	night = clampf(0.2 - sun_dir.y * 3.0, 0.0, 1.0)
	moon.light_energy = 0.5 * night

	var env := environment
	var horizon := _sample_c(HORIZON, t)
	_sky_mat.sky_top_color = _sample_c(SKY_TOP, t)
	_sky_mat.sky_horizon_color = horizon
	_sky_mat.ground_horizon_color = horizon
	_sky_mat.ground_bottom_color = horizon.darkened(0.5)
	env.ambient_light_color = _sample_c(AMBIENT, t)
	env.ambient_light_energy = _sample_f(AMBIENT_ENERGY, t)
	if indoors:
		sun.light_energy = sun_e * 0.45
		moon.light_energy = 0.15 * night
		env.ambient_light_color = env.ambient_light_color.lerp(Color(0.92, 0.84, 0.74), lerpf(0.5, 0.35, night))
		env.ambient_light_energy *= lerpf(1.15, 0.9, night)
	env.fog_light_color = horizon.lerp(env.ambient_light_color, 0.35)
	if cave:
		sun.light_energy = 0.0
		moon.light_energy = 0.0
		env.ambient_light_color = Color(0.5, 0.58, 0.75)
		env.ambient_light_energy = 0.9
		env.fog_light_color = Color(0.0, 0.004, 0.012)
	if terrain and terrain.get("material"):
		terrain.material.set_shader_parameter("cloud_strength", 0.12 * clampf(sun_e, 0.0, 1.0))


func _segment(t: float) -> Vector2:
	for i in KEYS.size() - 1:
		if t <= KEYS[i + 1]:
			return Vector2(i, (t - KEYS[i]) / (KEYS[i + 1] - KEYS[i]))
	return Vector2(KEYS.size() - 2, 1.0)


func _sample_c(list: Array, t: float) -> Color:
	var s := _segment(t)
	var c: Color = list[int(s.x)]
	return c.lerp(list[int(s.x) + 1], smoothstep(0.0, 1.0, s.y))


func _sample_f(list: Array, t: float) -> float:
	var s := _segment(t)
	return lerpf(list[int(s.x)], list[int(s.x) + 1], smoothstep(0.0, 1.0, s.y))
