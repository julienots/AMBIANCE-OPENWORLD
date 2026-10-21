// Toon shading for heroes and props: banded light, crisp specular, rim light,
// emissive pulse, hit flash and organic dissolve.
shader_type spatial;
render_mode cull_back;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float bands = 2.0;
uniform float emission_energy = 0.0;
uniform float pulse_speed = 0.0;
uniform float specular_amount = 0.12;
uniform float specular_threshold = 0.93;
uniform float rim_amount = 0.35;
uniform vec4 rim_color : source_color = vec4(0.75, 0.85, 1.0, 1.0);
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float dissolve = 0.0;
uniform vec4 dissolve_color : source_color = vec4(0.65, 0.15, 1.0, 1.0);
uniform float power_glow = 0.0;          // set while an ability is active
uniform vec4 power_color : source_color = vec4(0.3, 0.9, 1.0, 1.0);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float n = 1.0;
	if (dissolve > 0.0) {
		n = texture(noise_tex, local_pos.xz * 1.3 + vec2(local_pos.y * 0.7)).r;
		if (n < dissolve) {
			discard;
		}
	}
	ALBEDO = albedo.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float pulse = pulse_speed > 0.0 ? 0.7 + 0.3 * sin(TIME * pulse_speed) : 1.0;
	vec3 em = albedo.rgb * emission_energy * pulse;
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	em += rim_color.rgb * smoothstep(0.55, 0.75, fres) * rim_amount * 0.3;
	em += power_color.rgb * pow(fres, 2.0) * power_glow * 1.5;
	em += flash_color.rgb * flash;
	if (dissolve > 0.0) {
		em += dissolve_color.rgb * 5.0 * smoothstep(dissolve + 0.07, dissolve, n);
	}
	EMISSION = em;
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float i = ndl * ATTENUATION;
	float x = i * bands;
	float q = (floor(x) + smoothstep(0.35, 0.65, fract(x))) / bands;
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * q * 1.25;
	vec3 h = normalize(VIEW + LIGHT);
	float s = smoothstep(specular_threshold, specular_threshold + 0.02, dot(NORMAL, h));
	SPECULAR_LIGHT += LIGHT_COLOR / PI * s * specular_amount * step(0.05, i);
}
