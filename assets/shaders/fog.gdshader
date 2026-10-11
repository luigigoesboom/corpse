// Fog (atmosphere pass): drifting banks of haze anchored in the world, drawn
// behind the playfield (in front of the back wall) or as a thin mist in
// front of it. Two layers of slow noise, thicker low on the screen and
// deeper in the body, in the region's colour, on the game's pixel grid.
// src/world/atmosphere.gd sets camera_position, tint, density and time.
shader_type canvas_item;

uniform vec2 camera_position;
uniform vec2 screen_size = vec2(640.0, 360.0);
uniform float scroll = 0.6;       // How much it moves with the camera (parallax).
uniform vec4 tint : source_color = vec4(0.42, 0.16, 0.2, 1.0);
uniform float density = 0.3;     // Strongest alpha.
uniform float low = 0.6;         // How much more of it near the bottom of the screen (0..1).
uniform float time_s = 0.0;
uniform float drift = 6.0;       // px per second, sideways.
uniform float scale = 0.006;     // Size of the banks (smaller = bigger banks).

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += noise(p) * a;
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 px = floor(UV * screen_size);
	vec2 world = camera_position * scroll + px - screen_size * 0.5 + vec2(time_s * drift, 0.0);
	float n = fbm(world * scale) * 0.65 + fbm(world * scale * 2.7 + vec2(time_s * 0.03, 0.0)) * 0.35;
	float bank = smoothstep(0.34, 0.78, n);
	float height = mix(1.0, UV.y, low);  // Thicker toward the floor.
	float a = bank * density * height;
	a = floor(a * 10.0) / 10.0;  // In steps.
	COLOR = vec4(tint.rgb, a);
}
