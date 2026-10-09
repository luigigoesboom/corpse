// Editor preview of world.png: rock in a solid color, open space transparent.
// Same rule as WorldMap.is_rock_color(); keep them in sync.
shader_type canvas_item;

uniform vec4 rock_color : source_color = vec4(0.25, 0.3, 0.45, 1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	bool rock = c.a >= 0.5 && c.r + c.g + c.b < 1.5;
	COLOR = rock ? rock_color : vec4(0.0);
}
