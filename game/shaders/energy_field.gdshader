// Translucent energy field for shields, domes, storms and dark domains.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(0.3, 0.9, 1.0, 1.0);
uniform float intensity = 1.0;
uniform float darkness = 0.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

void fragment() {
	float fres = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.2);
	vec2 uv = UV * vec2(4.0, 2.0) + vec2(TIME * 0.12, -TIME * 0.2);
	float n = texture(noise_tex, uv).r;
	float hex = smoothstep(0.55, 0.75, texture(noise_tex, UV * 6.0 + vec2(0.0, TIME * 0.05)).b);
	float a = (fres * 0.9 + n * 0.15 + hex * 0.3) * intensity;
	ALBEDO = mix(color.rgb * a * 1.6, vec3(0.0), darkness);
	ALPHA = clamp(a, 0.0, 1.0);
}
