// Diggable rock: vertex colour = mineral type, alpha = emission (crystals / alloy veins),
// triplanar grit and strata, toon banding. Double sided (faces are seen from the cave).
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float bands = 2.0;
uniform vec4 glow_color : source_color = vec4(0.3, 0.9, 1.0, 1.0);

varying vec3 wpos;
varying vec3 wn;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 b = pow(abs(wn), vec3(4.0));
	b /= (b.x + b.y + b.z);
	vec4 nx = texture(noise_tex, wpos.yz * 0.35);
	vec4 ny = texture(noise_tex, wpos.xz * 0.35);
	vec4 nz = texture(noise_tex, wpos.xy * 0.35);
	vec4 n = nx * b.x + ny * b.y + nz * b.z;
	float strata = 0.85 + 0.15 * sin(wpos.y * 3.0 + n.r * 4.0);
	vec3 col = COLOR.rgb * (0.75 + 0.5 * n.r) * strata;
	col *= 0.85 + 0.3 * n.a;
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float glow = COLOR.a * smoothstep(0.45, 0.8, n.b + 0.2);
	vec3 gcol = COLOR.a > 0.5 ? glow_color.rgb : vec3(1.0, 0.7, 0.3);
	EMISSION = gcol * glow * (1.6 + 0.4 * sin(TIME * 2.0 + wpos.x));
}

void light() {
	float i = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float x = i * bands;
	float q = (floor(x) + smoothstep(0.3, 0.7, fract(x))) / bands;
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * q * 1.3;
}
