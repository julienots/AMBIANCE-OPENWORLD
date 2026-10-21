// Symbiote flesh: oily black surface with iridescent sheen, pulsing veins,
// breathing deformation, hit flash and dissolve on death.
shader_type spatial;
render_mode cull_back;

uniform vec4 base_color : source_color = vec4(0.04, 0.03, 0.06, 1.0);
uniform vec4 vein_color : source_color = vec4(0.9, 0.1, 0.25, 1.0);
uniform vec4 sheen_color : source_color = vec4(0.35, 0.2, 0.9, 1.0);
uniform float vein_strength = 1.0;
uniform float vein_scale = 1.4;
uniform float pulse_speed = 2.2;
uniform float breathe = 0.012;
uniform float emission_energy = 0.0;      // for eyes / glands using this shader
uniform float flash = 0.0;
uniform float dissolve = 0.0;
uniform float alert = 0.0;                 // veins brighten while hunting
uniform float bands = 2.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
	float w = texture(noise_tex, VERTEX.xz * 0.6 + vec2(TIME * 0.05)).g;
	VERTEX += NORMAL * breathe * sin(TIME * 2.0 + w * 6.2831 + VERTEX.y * 3.0);
}

vec3 triplanar(vec3 p, vec3 n) {
	vec3 b = pow(abs(n), vec3(4.0));
	b /= (b.x + b.y + b.z);
	float x = texture(noise_tex, p.yz * vein_scale).b;
	float y = texture(noise_tex, p.xz * vein_scale).b;
	float z = texture(noise_tex, p.xy * vein_scale).b;
	return vec3(x * b.x + y * b.y + z * b.z);
}

void fragment() {
	float d = texture(noise_tex, local_pos.xz * 1.1 + vec2(local_pos.y * 0.8)).r;
	if (dissolve > 0.0 && d < dissolve) {
		discard;
	}
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float veins = triplanar(local_pos, wn).r;
	float pulse = 0.55 + 0.45 * sin(TIME * pulse_speed * (1.0 + alert) + local_pos.y * 4.0);
	ALBEDO = base_color.rgb;
	ROUGHNESS = 0.3;
	SPECULAR = 0.0;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	vec3 em = sheen_color.rgb * fres * 0.6;
	em += vein_color.rgb * smoothstep(0.55, 0.9, veins) * vein_strength * pulse * (1.0 + alert * 1.5);
	em += base_color.rgb * emission_energy;
	em += vec3(1.0, 0.95, 0.95) * flash;
	if (dissolve > 0.0) {
		em += vein_color.rgb * 6.0 * smoothstep(dissolve + 0.08, dissolve, d);
	}
	EMISSION = em;
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float x = ndl * bands;
	float q = (floor(x) + smoothstep(0.4, 0.6, fract(x))) / bands;
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * q;
	vec3 h = normalize(VIEW + LIGHT);
	float s = smoothstep(0.9, 0.93, dot(NORMAL, h));
	SPECULAR_LIGHT += LIGHT_COLOR / PI * s * 0.6 * step(0.02, ndl);
}
