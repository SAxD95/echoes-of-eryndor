// Francisco Cidade  |  https://fcidade.com  |  https://fcidade.itch.io
shader_type canvas_item;
// PSX screen: chunky console pixels, 15-bit color and a dither on the final image of the whole 3D view.
// Put it on a full-screen ColorRect inside a CanvasLayer above the 3D view. CC0.
// It works on what was drawn before it, so the dither also covers the lighting and the fog, which a material cannot do.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

// How much of the effect is used. 0 = the picture as it is.
uniform float screen_amount : hint_range(0.0, 1.0, 0.01) = 1.0;
// Size of one console pixel in screen pixels. Use the same value as pixel_size in psx.gdshader (the viewer keeps the two together).
uniform float screen_pixel_size : hint_range(1.0, 16.0, 0.5) = 3.0;
// Bits per color channel. 5 = the PS1 15-bit color. 8 = off.
uniform int screen_color_bits : hint_range(1, 8, 1) = 5;
// Strength of the 4x4 ordered dither (0 = none).
uniform float screen_dither : hint_range(0.0, 1.0, 0.01) = 1.0;
// Slight brightness noise that changes every frame, like a worn picture.
uniform float grain : hint_range(0.0, 0.2, 0.005) = 0.0;
// Darkens the corners of the screen.
uniform float vignette : hint_range(0.0, 1.0, 0.01) = 0.0;

const int BAYER4[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 cell = floor(FRAGCOORD.xy / screen_pixel_size);
	// the middle of the big pixel: every screen pixel inside it reads the same color
	vec2 uv = (cell + 0.5) * screen_pixel_size / size;
	vec3 c = texture(screen_texture, uv).rgb;
	vec3 original = texture(screen_texture, SCREEN_UV).rgb;

	ivec2 ic = ivec2(cell);
	float t = (float(BAYER4[(ic.y & 3) * 4 + (ic.x & 3)]) + 0.5) / 16.0 - 0.5;
	float levels = exp2(float(screen_color_bits)) - 1.0;
	c = clamp(floor(c * levels + t * screen_dither + 0.5) / levels, 0.0, 1.0);
	c += (hash12(cell + floor(TIME * 24.0) * 17.0) - 0.5) * grain;
	vec2 d = SCREEN_UV - 0.5;
	c *= 1.0 - vignette * smoothstep(0.25, 0.8, length(d * vec2(1.0, 0.8)) * 1.4);
	COLOR = vec4(mix(original, c, screen_amount), 1.0);
}
