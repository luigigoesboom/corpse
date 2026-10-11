// The look of the whole picture (atmosphere pass, after week 52): drawn over
// the world and under the UI, it reads what is on screen and
//   grades it per region (the Gut warm and sick, the Lungs pale and cold),
//   closes a deep, uneven vignette around it that beats with the god's heart
//     (and swells with the breath in the Lungs), in steps, pixel-art style,
//   adds grain on the game's own pixel grid,
//   and pulls the dark in, red, when the host is close to death.
// src/world/atmosphere.gd sets the uniforms every frame; `amount` is the
// Atmosphere setting (0 = the plain picture).
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float amount = 1.0;
uniform float time_s = 0.0;
uniform float heartbeat = 0.0;  // 0..1, a double thump
uniform float breath = 0.0;     // -1..1
uniform float hurt = 0.0;       // 0 = fine .. 1 = a heart left
uniform vec3 lift = vec3(0.05, 0.0, 0.02);   // added in the shadows
uniform vec3 gain = vec3(1.06, 0.96, 0.92);  // multiplied in
uniform float saturation = 0.88;
uniform vec4 vignette_tint : source_color = vec4(0.04, 0.0, 0.02, 1.0);
uniform float vignette = 0.95;
uniform float fringe = 1.0;  // Colour fringe toward the edges, in game pixels.
uniform float grain = 0.045;
uniform vec2 pixels = vec2(640.0, 360.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	// Whole game pixels: everything this shader adds stays on the pixel grid.
	vec2 px = floor(SCREEN_UV * pixels) + 0.5;
	vec2 uv = px / pixels;
	vec3 plain = texture(screen, SCREEN_UV).rgb;
	vec3 col = plain;
	// A fringe of colour toward the edges, as through wet glass: red and blue
	// pulled a whole pixel apart.
	vec2 away = normalize(uv - 0.5 + 0.0001) / pixels * fringe * smoothstep(0.3, 0.75, length((uv - 0.5) * 2.0));
	col.r = texture(screen, SCREEN_UV + away).r;
	col.b = texture(screen, SCREEN_UV - away).b;

	// Grading.
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 graded = mix(vec3(luma), col, saturation) * gain + lift * (1.0 - luma);

	// The vignette: an ellipse whose edge wanders with slow noise, beating.
	vec2 c = (uv - 0.5) * vec2(pixels.x / pixels.y, 1.0);
	float d = length(c);
	float wander = (noise(c * 2.5 + vec2(time_s * 0.04, time_s * 0.02)) - 0.5) * 0.16;
	float edge = 0.3 - heartbeat * 0.03 - breath * 0.03 - hurt * 0.16;
	float v = smoothstep(edge + wander, edge + 0.62 + wander, d);
	v = pow(v, 0.85);
	v = floor(v * 7.0) / 7.0;
	vec3 shade = mix(vignette_tint.rgb, vec3(0.42, 0.02, 0.04), hurt * (0.55 + 0.45 * heartbeat));
	graded = mix(graded, shade, clamp(v * vignette, 0.0, 1.0));

	// Grain: a new speckle a dozen times a second, per game pixel.
	graded += (hash(px + floor(time_s * 12.0) * 7.0) - 0.5) * grain;

	COLOR = vec4(mix(plain, graded, amount), 1.0);
}
