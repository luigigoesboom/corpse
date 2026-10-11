// The cave's back wall (D-028): three seamless layers drawn by the art
// program (tools/pixel/recipes/backdrop.gd), each scrolling slower than the
// world (parallax): far muscle walls, mid shapes (ribs, pillars, membranes),
// near silhouettes. Drawn full-screen on a CanvasLayer behind everything.
// `tint` follows the kind of rock around the camera (backdrop.gd).
shader_type canvas_item;

uniform sampler2D far_texture : repeat_enable, filter_nearest;
uniform sampler2D mid_texture : repeat_enable, filter_nearest;
uniform sampler2D near_texture : repeat_enable, filter_nearest;
// The Lungs' set (week 47), blended in by `lungs` (0 = the Gut, 1 = the Lungs).
uniform sampler2D lungs_far_texture : repeat_enable, filter_nearest;
uniform sampler2D lungs_mid_texture : repeat_enable, filter_nearest;
uniform sampler2D lungs_near_texture : repeat_enable, filter_nearest;
uniform float lungs = 0.0;
// The god's breath (week 52), -1..1: the Lungs' walls brighten as they fill.
uniform float breath = 0.0;
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

vec3 stack(sampler2D far_t, sampler2D mid_t, sampler2D near_t, vec2 uv) {
	vec3 col = layer(far_t, far_scroll, uv).rgb;
	vec4 mid = layer(mid_t, mid_scroll, uv);
	col = mix(col, mid.rgb, mid.a);
	vec4 near = layer(near_t, near_scroll, uv);
	return mix(col, near.rgb, near.a);
}

void fragment() {
	vec3 col = lungs < 0.999 ? stack(far_texture, mid_texture, near_texture, UV) : vec3(0.0);
	if (lungs > 0.001) {
		col = mix(col, stack(lungs_far_texture, lungs_mid_texture, lungs_near_texture, UV), lungs);
	}
	COLOR = vec4(col * tint * brightness * (1.0 + breath * 0.12), 1.0);
}
