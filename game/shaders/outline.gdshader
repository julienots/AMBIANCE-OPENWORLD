// Inverted-hull outline drawn as a next pass. Width stays readable at distance.
shader_type spatial;
render_mode cull_front, unshaded, shadows_disabled;

uniform vec4 outline_color : source_color = vec4(0.03, 0.02, 0.06, 1.0);
uniform float thickness = 0.012;

void vertex() {
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float dist_scale = clamp(-view.z * 0.12, 1.0, 3.5);
	VERTEX += NORMAL * thickness * dist_scale;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
