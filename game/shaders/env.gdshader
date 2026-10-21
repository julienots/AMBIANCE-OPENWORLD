// World geometry: toon banding, triplanar grit, vertex-colour AO, optional lit windows,
// contamination veins and wetness. Used for buildings, ground, rocks, interiors.
shader_type spatial;
render_mode cull_back;

uniform vec4 albedo : source_color = vec4(0.5, 0.5, 0.55, 1.0);
uniform vec4 albedo2 : source_color = vec4(0.4, 0.4, 0.45, 1.0);
uniform float noise_scale = 0.15;
uniform float grit = 0.5;
uniform float bands = 2.0;
uniform float windows = 0.0;
uniform vec4 window_color : source_color = vec4(1.0, 0.75, 0.4, 1.0);
uniform float window_lit = 0.18;
uniform vec2 window_size = vec2(2.2, 3.2);
uniform float corruption = 0.0;
uniform vec4 corruption_color : source_color = vec4(0.8, 0.05, 0.2, 1.0);
uniform float emission_energy = 0.0;
uniform float specular_amount = 0.0;
uniform float rim = 0.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

varying vec3 wpos;
varying vec3 wnorm;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float tri(vec3 p, vec3 n, int ch) {
	vec3 b = pow(abs(n), vec3(4.0));
	b /= (b.x + b.y + b.z);
	vec4 x = texture(noise_tex, p.yz);
	vec4 y = texture(noise_tex, p.xz);
	vec4 z = texture(noise_tex, p.xy);
	vec4 r = x * b.x + y * b.y + z * b.z;
	return ch == 0 ? r.r : (ch == 1 ? r.g : (ch == 2 ? r.b : r.a));
}

void fragment() {
	float n = tri(wpos * noise_scale, wnorm, 0);
	float fine = tri(wpos * noise_scale * 6.0, wnorm, 3);
	vec3 col = mix(albedo.rgb, albedo2.rgb, smoothstep(0.35, 0.75, n));
	col *= 1.0 - grit * 0.25 * (1.0 - fine);
	col *= COLOR.rgb;
	vec3 em = col * emission_energy;
	if (windows > 0.5 && abs(wnorm.y) < 0.3) {
		vec2 face = abs(wnorm.x) > abs(wnorm.z) ? vec2(wpos.z, wpos.y) : vec2(wpos.x, wpos.y);
		vec2 cell = floor(face / window_size);
		vec2 f = fract(face / window_size);
		float win = step(0.18, f.x) * step(f.x, 0.82) * step(0.22, f.y) * step(f.y, 0.78);
		float h = hash(cell + floor(wpos.xz / 40.0) * 7.13);
		col = mix(col, vec3(0.05, 0.06, 0.09), win * 0.85);
		float lit = step(1.0 - window_lit, h) * win;
		float flick = 0.85 + 0.15 * sin(TIME * (2.0 + h * 6.0) + h * 30.0);
		em += window_color.rgb * lit * 0.55 * flick;
	}
	if (corruption > 0.0) {
		float v = tri(wpos * 0.35, wnorm, 2);
		float m = smoothstep(0.55, 0.85, v) * corruption;
		col = mix(col, vec3(0.03, 0.02, 0.04), smoothstep(0.3, 0.6, tri(wpos * 0.12, wnorm, 1)) * corruption);
		em += corruption_color.rgb * m * (0.6 + 0.4 * sin(TIME * 2.0 + wpos.x));
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	EMISSION = em + vec3(0.5, 0.6, 0.9) * smoothstep(0.6, 0.85, fres) * rim * 0.2;
}

void light() {
	float i = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float x = i * bands;
	float q = (floor(x) + smoothstep(0.3, 0.7, fract(x))) / bands;
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * q * 1.2;
	if (specular_amount > 0.0) {
		vec3 h = normalize(VIEW + LIGHT);
		SPECULAR_LIGHT += LIGHT_COLOR / PI * smoothstep(0.92, 0.95, dot(NORMAL, h)) * specular_amount * step(0.05, i);
	}
}
