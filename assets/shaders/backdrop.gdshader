// The cave's back wall (D-028): three seamless layers drawn by the art
// program (tools/pixel/recipes/backdrop.gd), each scrolling slower than the
// world (parallax): far muscle walls, mid shapes (ribs, pillars, membranes),
// near silhouettes. Drawn full-screen on a CanvasLayer behind everything.
// `tint` follows the kind of rock around the camera (backdrop.gd).
shader_type canvas_item;

uniform sampler2D far_texture : repeat_enable, filter_nearest;
uniform sampler2D mid_texture : repeat_enable, filter_nearest;
uniform sampler2D near_texture : repeat_enable, filter_nearest;
uniform vec2 camera_position;  // Screen centre in world pixels, set by backdrop.gd.
uniform vec2 screen_size = vec2(640.0, 360.0);  // Viewport size in game pixels.
uniform float far_scroll = 0.12;
uniform float mid_scroll = 0.3;
uniform float near_scroll = 0.55;
uniform float brightness = 0.5;
uniform vec3 tint = vec3(1.0);

vec4 layer(sampler2D tex, float scroll, vec2 uv) {
	vec2 world = camera_position * scroll + (uv - 0.5) * screen_size;
	return texture(tex, floor(world) / vec2(textureSize(tex, 0)));
}

void fragment() {
	vec3 col = layer(far_texture, far_scroll, UV).rgb;
	vec4 mid = layer(mid_texture, mid_scroll, UV);
	col = mix(col, mid.rgb, mid.a);
	vec4 near = layer(near_texture, near_scroll, UV);
	col = mix(col, near.rgb, near.a);
	COLOR = vec4(col * tint * brightness, 1.0);
}
