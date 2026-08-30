shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform float wave_progress : hint_range(0.0, 1.0) = 1.0;
uniform float wave_active : hint_range(0.0, 1.0) = 0.0;
uniform float radius_uv : hint_range(0.2, 0.5) = 0.42;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	v += noise(p) * a;
	p = p * 2.03 + 13.1;
	a *= 0.5;
	v += noise(p) * a;
	p = p * 2.01 + 7.7;
	a *= 0.5;
	v += noise(p) * a;
	p = p * 2.07 + 3.3;
	a *= 0.5;
	v += noise(p) * a;
	p = p * 2.02 + 1.9;
	a *= 0.5;
	v += noise(p) * a;
	return v;
}

void fragment() {
	vec2 p = UV - vec2(0.5);
	float r = length(p);
	vec4 pack = texture(TEXTURE, UV);
	float cover = pack.a;
	float seam = pack.r;
	float ash = pack.g;
	float pool = pack.b;

	vec2 warp = vec2(fbm(UV * 8.0 + TIME * 0.11), fbm(UV * 8.0 + 17.0 - TIME * 0.09));
	float micro = 1.0 - abs(fbm(UV * 16.0 + warp * 1.6) * 2.0 - 1.0);
	micro = pow(micro, 9.0) * cover;

	float heat = max(seam, max(pool * 0.85, micro * 0.42));
	float flicker = 0.78 + 0.22 * sin(TIME * 11.0 + r * 28.0 + ash * 9.0);
	flicker *= 0.88 + 0.12 * noise(UV * 22.0 + TIME * 3.4);

	float wave_r = radius_uv * (1.0 - (1.0 - wave_progress) * (1.0 - wave_progress));
	float passed = smoothstep(wave_r + 0.03, wave_r - 0.02, r);
	float front = exp(-abs(r - wave_r) * 22.0) * wave_active;
	float ignite = mix(1.0, 0.72 + 0.55 * passed, wave_active);

	float pulse_boost = pulse * 0.7;
	float lava_amt = smoothstep(0.12, 0.62, heat) * flicker * ignite;
	lava_amt = lava_amt * (0.82 + pulse_boost) + front * 0.35 * heat;

	vec3 charcoal = vec3(0.10, 0.055, 0.03);
	vec3 scorched = vec3(0.22, 0.10, 0.045);
	vec3 ash_col = vec3(0.16, 0.09, 0.05);
	vec3 earth = mix(charcoal, scorched, ash);
	earth = mix(earth, ash_col, clamp(heat * 0.45, 0.0, 1.0));

	vec3 magma = vec3(0.95, 0.28, 0.04);
	vec3 gold = vec3(1.0, 0.62, 0.14);
	vec3 hot = vec3(1.0, 0.90, 0.45);
	vec3 core = vec3(1.0, 0.97, 0.88);
	float temp = clamp(heat * flicker * (0.85 + pulse_boost), 0.0, 1.0);
	vec3 lava = mix(magma, gold, smoothstep(0.2, 0.55, temp));
	lava = mix(lava, hot, smoothstep(0.5, 0.82, temp));
	lava = mix(lava, core, smoothstep(0.78, 1.0, temp));

	vec3 col = mix(earth, lava, clamp(lava_amt, 0.0, 1.0));

	float rim = smoothstep(0.18, 0.62, cover) * smoothstep(1.0, 0.55, cover);
	rim *= 0.75 + 0.25 * flicker + pulse * 0.35;
	vec3 rim_fire = mix(vec3(1.0, 0.45, 0.08), vec3(1.0, 0.88, 0.4), flicker);
	col = mix(col, rim_fire, clamp(rim * 0.85, 0.0, 1.0));

	float glow = cover * 0.22 + heat * 0.55 + rim * 0.65 + front * 0.4;
	float halo = smoothstep(radius_uv + 0.085, radius_uv - 0.01, r) * (1.0 - cover);
	halo *= 0.22 + pulse * 0.18 + wave_active * front * 0.25;
	col += vec3(1.0, 0.5, 0.12) * halo;
	glow = max(glow, halo);

	float spark = 0.0;
	for (int i = 0; i < 7; i++) {
		float fi = float(i);
		vec2 seed = vec2(fi * 1.7 + 0.3, fi * 4.1 + 2.2);
		vec2 ep = vec2(hash12(seed), hash12(seed + 8.1)) - vec2(0.5);
		ep *= radius_uv * 1.55;
		float life = fract(TIME * 0.35 + hash12(seed + 3.4));
		vec2 rise = ep + vec2(0.0, -life * 0.06);
		float sd = length(p - rise);
		spark += exp(-sd * sd * 1400.0) * (1.0 - life) * cover;
	}
	col += vec3(1.0, 0.85, 0.4) * spark * (0.7 + pulse);
	glow += spark * 0.8;

	float alpha = max(cover * 0.78, glow);
	alpha *= 0.72 + pulse * 0.22;
	COLOR = vec4(col, clamp(alpha, 0.0, 1.0));
}
