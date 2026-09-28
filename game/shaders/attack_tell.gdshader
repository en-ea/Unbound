shader_type spatial;
// An enemy's attack warning on the ground: a red-orange lane with an arrow tip that fills from the
// enemy outward as the attack gets closer, with a bright rim and faint chevrons running along it.
// UV.y is 0 at the enemy and 1 at the tip.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.04, 0.02, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.38, 0.12, 1.0);
uniform float progress = 0.0;
uniform float alpha = 0.0;
uniform float length = 6.0;

void fragment() {
	float v = UV.y;
	float u = abs(UV.x * 2.0 - 1.0);
	float half_w = v < 0.8 ? 1.0 : 1.0 - (v - 0.8) / 0.2;      // an arrow tip at the far end
	float inside = smoothstep(half_w, half_w - 0.08, u) * smoothstep(0.0, 0.06, v);
	float rim = inside * smoothstep(half_w - 0.22, half_w - 0.1, u);
	float fill = inside * smoothstep(progress + 0.015, progress - 0.015, v);
	float front = inside * (1.0 - smoothstep(0.0, 0.03, abs(v - progress))) * step(progress, 0.99);
	float chevron = step(fract(v * length / 1.1 + u * 0.35 - TIME * 1.6), 0.28) * inside;
	float ready = smoothstep(0.85, 1.0, progress);              // the whole lane brightens just before
	float a = rim * 0.9 + inside * 0.06 + fill * (0.2 + 0.2 * ready) + chevron * 0.14 + front * 0.7;
	ALBEDO = mix(color.rgb, rim_color.rgb, rim * 0.7 + front * 0.9 + ready * 0.2) * 1.3;
	ALPHA = clamp(a, 0.0, 1.0) * alpha;
}
