// Ground telegraph for heavy enemy attacks: outline ring + filling disc.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.15, 0.1, 1.0);
uniform float fill = 0.0;

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float ring = smoothstep(0.9, 0.95, r) * smoothstep(1.0, 0.96, r);
	float disc = step(r, fill) * 0.35 * smoothstep(1.0, 0.0, r * 0.3);
	float edge = smoothstep(fill - 0.06, fill, r) * step(r, fill) * 0.8;
	float a = (ring + disc + edge) * step(r, 1.0);
	ALBEDO = color.rgb * a * 1.5;
	ALPHA = a;
}
