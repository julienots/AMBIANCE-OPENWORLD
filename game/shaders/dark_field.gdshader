// Swirling darkness for Noctis' domain and the Devourer's presence.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(0.5, 0.2, 0.9, 1.0);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float density = 0.75;

void fragment() {
	vec2 uv = UV * vec2(3.0, 1.5) + vec2(TIME * 0.05, TIME * 0.08);
	float n = texture(noise_tex, uv).r * 0.6 + texture(noise_tex, uv * 2.3 - TIME * 0.03).g * 0.4;
	float fres = pow(1.0 - abs(dot(NORMAL, VIEW)), 1.5);
	ALBEDO = mix(vec3(0.01, 0.0, 0.02), color.rgb * 0.6, smoothstep(0.6, 0.9, n) * fres);
	ALPHA = clamp((0.35 + n * 0.5) * density * (0.4 + fres), 0.0, 0.92);
}
