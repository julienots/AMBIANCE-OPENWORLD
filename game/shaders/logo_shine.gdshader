// Light sweep across the studio logo.
shader_type canvas_item;
uniform float progress = -0.3;
uniform float width = 0.12;
uniform float strength = 0.9;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float d = abs((UV.x + UV.y * 0.35) - progress * 1.35);
	float s = smoothstep(width, 0.0, d) * strength;
	COLOR = vec4(c.rgb + vec3(s) * c.a, c.a);
}
