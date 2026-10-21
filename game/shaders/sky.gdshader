// Stylised night sky: gradient, moon with halo, drifting clouds, faint stars, polluted glow.
shader_type sky;

uniform vec4 top_color : source_color = vec4(0.02, 0.025, 0.06, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.16, 0.1, 0.18, 1.0);
uniform vec4 glow_color : source_color = vec4(0.45, 0.12, 0.18, 1.0);
uniform vec3 moon_dir = vec3(0.3, 0.45, -0.85);
uniform vec4 moon_color : source_color = vec4(0.95, 0.9, 0.8, 1.0);
uniform float cloudiness = 0.6;
uniform float stars = 0.6;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

void sky() {
	vec3 d = EYEDIR;
	float h = clamp(d.y, -1.0, 1.0);
	vec3 col = mix(horizon_color.rgb, top_color.rgb, smoothstep(0.0, 0.55, h));
	col += glow_color.rgb * pow(1.0 - abs(h), 6.0) * 0.6;
	vec3 md = normalize(moon_dir);
	float m = dot(d, md);
	col += moon_color.rgb * smoothstep(0.9985, 0.9992, m) * 1.5;
	col += moon_color.rgb * pow(max(m, 0.0), 80.0) * 0.25;
	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.25);
		float s = texture(noise_tex, uv * 3.0).a;
		col += vec3(step(0.985, s) * stars * smoothstep(0.1, 0.4, h));
		float c = texture(noise_tex, uv * 0.18 + TIME * 0.003).r * 0.6 + texture(noise_tex, uv * 0.4 - TIME * 0.002).g * 0.4;
		float cl = smoothstep(1.0 - cloudiness, 1.0, c) * smoothstep(0.0, 0.25, h);
		vec3 cc = mix(vec3(0.05, 0.045, 0.07), moon_color.rgb * 0.35, pow(max(m, 0.0), 6.0));
		col = mix(col, cc, cl * 0.85);
	}
	COLOR = col;
}
