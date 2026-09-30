class_name EnemyOverlay
extends Node3D
## What floats over a human enemy: the attack glint at the eyes (with its "ting"), a health bar after a
## hit, and the awareness marker: a "?" that fills from yellow to red while they notice you, then a
## red "!" when they've spotted you. Put it on the enemy at head height.

const GLINT_SHADER := preload("res://shaders/glint.gdshader")
const GLINT_SOUND := preload("res://assets/sounds/tell_glint.wav")
const BAR_SHADER := preload("res://shaders/health_bar.gdshader")

var _glint: MeshInstance3D
var _glint_mat: ShaderMaterial
var _glint_t := 1.0
var _glint_audio: AudioStreamPlayer3D
var _bar: MeshInstance3D
var _bar_mat: ShaderMaterial
var _bar_alpha := 0.0
var _bar_time := 0.0
var _fill := 1.0
var _trail := 1.0
var _trail_wait := 0.0
var _mark: Label3D
var _time := 0.0
var _alert_pop := 0.0


func _ready() -> void:
	_glint = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 1.2
	_glint.mesh = quad
	_glint_mat = ShaderMaterial.new()
	_glint_mat.shader = GLINT_SHADER
	_glint.material_override = _glint_mat
	_glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glint.visible = false
	_glint.position = Vector3(0, -0.1, 0.12)
	add_child(_glint)
	_glint_audio = AudioStreamPlayer3D.new()
	_glint_audio.stream = GLINT_SOUND
	_glint_audio.unit_size = 10.0
	_glint_audio.volume_db = -4.0
	add_child(_glint_audio)
	_bar = MeshInstance3D.new()
	var bq := QuadMesh.new()
	bq.size = Vector2(0.95, 0.13)
	_bar.mesh = bq
	_bar_mat = ShaderMaterial.new()
	_bar_mat.shader = BAR_SHADER
	_bar_mat.set_shader_parameter("aspect", 7.0)
	_bar_mat.render_priority = 2
	_bar.material_override = _bar_mat
	_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar.position = Vector3(0, 0.45, 0)
	add_child(_bar)
	_mark = Label3D.new()
	_mark.font_size = 96
	_mark.outline_size = 18
	_mark.pixel_size = 0.006
	_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_mark.no_depth_test = true
	_mark.position = Vector3(0, 0.75, 0)
	_mark.visible = false
	add_child(_mark)


func glint() -> void:
	_glint_t = 0.0
	_glint.visible = true
	_glint_audio.play()


func show_health(fraction: float, hit_points := 5) -> void:
	_bar_mat.set_shader_parameter("segments", float(clampi(hit_points, 1, 12)))
	_bar_time = 3.5 if fraction > 0.0 else 0.6
	_fill = fraction
	_bar_mat.set_shader_parameter("fill", fraction)
	_trail_wait = 0.35


## 0 = unaware (hidden), up to 1 = about to spot you ("?" going yellow to red); `alert` shows "!".
func set_awareness(amount: float, alert: bool) -> void:
	if alert:
		if _mark.text != "!":
			_alert_pop = 1.0
		_mark.text = "!"
		_mark.modulate = Color(1.0, 0.25, 0.15)
		_mark.visible = _alert_pop > 0.0
		return
	_mark.visible = amount > 0.05
	_mark.text = "?"
	_mark.modulate = Color(1.0, 0.9, 0.3).lerp(Color(1.0, 0.35, 0.15), amount)
	_mark.scale = Vector3.ONE * (0.6 + 0.5 * amount)


func _process(delta: float) -> void:
	_time += delta
	if _glint.visible:
		_glint_t += delta / 0.4
		_glint.visible = _glint_t < 1.0
		_glint_mat.set_shader_parameter("t", _glint_t)
	if _alert_pop > 0.0:
		_alert_pop -= delta / 1.6            # the "!" pops, hangs a moment, then goes
		_mark.scale = Vector3.ONE * (1.0 + 0.6 * clampf((_alert_pop - 0.8) * 5.0, 0.0, 1.0))
		_mark.visible = _alert_pop > 0.0
	_bar_time -= delta
	_bar_alpha = move_toward(_bar_alpha, 1.0 if _bar_time > 0.0 else 0.0, delta * 5.0)
	_trail_wait -= delta
	if _trail_wait <= 0.0:
		_trail = move_toward(_trail, _fill, delta * 1.2)
	_bar.visible = _bar_alpha > 0.001 or _time < 1.0
	if _bar.visible:
		_bar_mat.set_shader_parameter("trail", _trail)
		_bar_mat.set_shader_parameter("alpha", _bar_alpha)
