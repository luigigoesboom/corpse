// Cave back wall: two repeating textures that scroll slower than the world
// (parallax). Drawn full-screen on a CanvasLayer behind everything, so it
// always covers the whole screen. Colors are final: no lights or darkness.
shader_type canvas_item;

uniform sampler2D far_texture : repeat_enable, filter_nearest;
uniform sampler2D mid_texture : repeat_enable, filter_nearest;
uniform vec2 camera_position;  // Screen center in world pixels, set by backdrop.gd.
uniform vec2 screen_size = vec2(1280.0, 720.0);
uniform float far_scroll = 0.15;
uniform float mid_scroll = 0.4;
uniform float pixel_scale = 2.0;  // Texture pixels are drawn this big.

vec4 layer(sampler2D tex, float scroll, vec2 uv) {
	vec2 world = camera_position * scroll + (uv - 0.5) * screen_size;
	vec2 texel = floor(world / pixel_scale);
	return texture(tex, texel / vec2(textureSize(tex, 0)));
}

void fragment() {
	vec4 far = layer(far_texture, far_scroll, UV);
	vec4 mid = layer(mid_texture, mid_scroll, UV);
	COLOR = vec4(mix(far.rgb, mid.rgb, mid.a), 1.0);
}
