// Full-screen horror post-process: vignette, threat desaturation, chromatic aberration,
// damage pulse, hiding tunnel vision and film grain. Strength follows player settings.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D grain_tex : repeat_enable;
uniform float threat = 0.0;
uniform float damage = 0.0;
uniform float hidden = 0.0;
uniform float strength = 1.0;
uniform float low_hp = 0.0;
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float r = length(c);
	float ca = (threat * 0.004 + damage * 0.01) * strength;
	vec3 col;
	col.r = texture(screen_tex, uv + c * ca).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - c * ca).b;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum), clamp(threat * 0.45 + hidden * 0.5, 0.0, 0.8) * strength);
	col *= tint.rgb;
	float vig = smoothstep(0.85, 0.25 - hidden * 0.15, r * (1.0 + threat * 0.35 + hidden * 0.6));
	col *= mix(1.0, vig, 0.25 + 0.3 * strength + threat * 0.3);
	float pulse = 0.5 + 0.5 * sin(TIME * (3.0 + threat * 5.0));
	col += vec3(0.6, 0.0, 0.05) * smoothstep(0.35, 0.8, r) * (damage + low_hp * pulse * 0.6) * strength;
	float g = texture(grain_tex, uv * vec2(4.0, 2.4) + vec2(fract(TIME * 13.7), fract(TIME * 7.3))).r - 0.5;
	col += g * (0.035 + threat * 0.05) * strength;
	COLOR = vec4(col, 1.0);
}
