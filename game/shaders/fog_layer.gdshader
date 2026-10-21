// Animated ground fog sheet (stack several at different heights for volume).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(0.6, 0.62, 0.7, 1.0);
uniform float density = 0.35;
uniform float scale = 0.035;
uniform vec2 wind = vec2(0.012, 0.006);
uniform float fade_near = 2.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	float a = texture(noise_tex, wpos.xz * scale + TIME * wind).r;
	float b = texture(noise_tex, wpos.xz * scale * 2.3 - TIME * wind * 1.7).g;
	float n = smoothstep(0.25, 0.85, a * 0.65 + b * 0.35);
	float dist = length(wpos - CAMERA_POSITION_WORLD);
	float near = smoothstep(0.5, fade_near, dist);
	ALBEDO = color.rgb;
	ALPHA = clamp(n * density * near, 0.0, 1.0);
}
