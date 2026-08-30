shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float radius_uv : hint_range(0.2, 0.5) = 0.42;
uniform float intensity : hint_range(0.0, 2.0) = 1.0;

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
	p = p * 2.07 + 4.2;
	a *= 0.5;
	v += noise(p) * a;
	p = p * 2.03 + 9.1;
	a *= 0.5;
	v += noise(p) * a;
	return v;
}

void fragment() {
	vec2 p = UV - vec2(0.5);
	float r = length(p);
	float ang = atan(p.y, p.x);

	float u = progress;
	float eased = 1.0 - (1.0 - u) * (1.0 - u);
	float n = fbm(vec2(ang * 2.4, u * 6.0 + TIME * 2.5));
	float jag = (n - 0.5) * 0.034;
	float wave_r = eased * radius_uv + jag;

	float d = r - wave_r;
	float front = exp(-d * d * 720.0);
	float trail = exp(-max(d, 0.0) * 38.0) * smoothstep(-0.09, 0.0, d);
	float core = exp(-d * d * 2400.0);
	float sheet = exp(-abs(d) * 16.0) * (0.55 + 0.45 * n);

	float tongues = pow(max(0.0, 1.0 - abs(sin(ang * 9.0 + n * 6.0 + TIME * 8.0))), 4.0);
	tongues *= smoothstep(0.05, 0.0, d) * smoothstep(-0.07, -0.01, d);

	float appear = smoothstep(0.0, 0.06, u);
	float fade = 1.0 - smoothstep(0.62, 1.0, u);
	float energy = (front * 0.95 + trail * 0.55 + core * 1.15 + sheet * 0.22 + tongues * 0.65);
	energy *= appear * fade * intensity;

	vec3 magma = vec3(1.0, 0.32, 0.05);
	vec3 gold = vec3(1.0, 0.62, 0.12);
	vec3 hot = vec3(1.0, 0.88, 0.42);
	vec3 white = vec3(1.0, 0.97, 0.86);
	vec3 col = magma * trail + gold * front + hot * sheet + white * core;
	col += hot * tongues;
	COLOR = vec4(col * energy, energy);
}
