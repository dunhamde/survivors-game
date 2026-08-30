shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform float wave_progress : hint_range(0.0, 1.0) = 1.0;
uniform float wave_active : hint_range(0.0, 1.0) = 0.0;
uniform float radius_uv : hint_range(0.2, 0.5) = 0.42;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float r = length(p);
	vec4 pack = texture(TEXTURE, UV);
	float cover = pack.a;
	float seam = pack.r;
	float ash = pack.g;
	float pool = pack.b;

	float flicker = 0.82 + 0.18 * step(0.5, fract(TIME * 3.4 + ash * 3.0));
	float heat = max(seam, pool * 0.8);

	float wave_r = radius_uv * (1.0 - (1.0 - wave_progress) * (1.0 - wave_progress));
	float passed = step(r, wave_r + 0.02);
	float ignite = mix(1.0, 0.7 + 0.45 * passed, wave_active);

	float pulse_boost = pulse * 0.5;
	float lava_amt = step(0.28, heat) * flicker * ignite * (0.85 + pulse_boost);

	vec3 earth = mix(vec3(0.14, 0.08, 0.04), vec3(0.22, 0.12, 0.05), step(0.5, ash));
	vec3 magma = vec3(0.82, 0.26, 0.05);
	vec3 gold = vec3(0.95, 0.58, 0.12);
	vec3 lava = mix(magma, gold, step(0.62, heat * flicker));
	vec3 col = mix(earth, lava, clamp(lava_amt, 0.0, 1.0));

	float edge_fade = 1.0 - smoothstep(radius_uv * 0.42, radius_uv * 0.96, r);
	float alpha = cover * edge_fade * (0.7 + pulse * 0.22);
	COLOR = vec4(col, clamp(alpha, 0.0, 1.0));
}
