// Darkens the screen edges in a few hard steps (pixel-art friendly).
shader_type canvas_item;

uniform float strength = 0.6;
uniform vec4 tint : source_color = vec4(0.06, 0.0, 0.02, 1.0);

void fragment() {
	vec2 uv = (UV - 0.5) * vec2(1.6, 1.0);
	float v = smoothstep(0.45, 1.0, length(uv));
	v = floor(v * 5.0) / 5.0;  // Bands instead of a smooth fade.
	COLOR = vec4(tint.rgb, v * strength);
}
