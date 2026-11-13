// Francisco Cidade  |  https://fcidade.com  |  https://fcidade.itch.io
// GENERATED from psx.gdshader by produtos/psx/gerar-variantes.py. Variant of psx.gdshader that adds its light to what is behind it (light beams, fire, glows).
shader_type spatial;
#define PSX_ADDITIVE
render_mode vertex_lighting, diffuse_lambert, specular_disabled, shadows_disabled, fog_disabled, cull_disabled, depth_draw_never, blend_add;
// PSX: a PlayStation 1 look for any 3D mesh. Vertex snapping and jitter, affine texture warping, per-vertex
// lighting and fog, 15-bit color with dithering, sphere-mapped metal, emission, billboards and alpha cutout in one material.
// Godot 4.x, Spatial, works in Forward+, Mobile and Compatibility. CC0: use it, change it, sell it with your game.
// For the final-pixel dither and chunky pixels of the whole screen add psx_screen.gdshader (see the README).

group_uniforms texture;
// The picture on the surface. Drawn with nearest filtering and repeating, like a console texture.
uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
// Tint multiplied with the texture. White leaves the texture as it is.
uniform vec4 albedo_color : source_color = vec4(1.0);
// How much the mesh vertex colors darken or tint the surface (0 = ignore them, 1 = full). PS1 levels were lit by painting these.
uniform float vertex_color_mix : hint_range(0.0, 1.0, 0.01) = 1.0;
// How the texture is smoothed. Nearest = hard square texels (PS1). N64 3-point = the soft, triangular blur of the
// Nintendo 64, which mixes only three texels instead of four.
uniform int texture_filter : hint_enum("Nearest", "N64 3-point") = 0;
// Repeats the texture. 2 = twice across each face.
uniform vec2 uv_scale = vec2(1.0, 1.0);
// Moves the texture, in texture widths.
uniform vec2 uv_offset = vec2(0.0, 0.0);
// Slides the texture, in texture widths per second (water, conveyor belts, flames).
uniform vec2 uv_scroll = vec2(0.0, 0.0);
// Texture swimming. 1 = affine mapping like the real PS1, where the texture bends across big polygons
// that are close to the camera. 0 = a modern, perspective-correct texture.
uniform float affine : hint_range(0.0, 1.0, 0.01) = 1.0;
// The most the texture may slide because of affine mapping, in texture repeats. Big polygons at the edge of a wide
// view would otherwise smear the whole texture; a lower value keeps the swimming but caps it. 8 = no cap.
uniform float affine_limit : hint_range(0.05, 8.0, 0.05) = 0.35;

group_uniforms snapping;
// Size of one console pixel in screen pixels. The vertices snap to this grid, and the dither cells use it too.
// 3 on a 960 x 720 view = the classic 320 x 240. Use the same value in psx_screen.gdshader.
uniform float pixel_size : hint_range(1.0, 16.0, 0.5) = 3.0;
// How strongly the vertices snap to the pixel grid. 1 = every vertex jumps to a whole pixel, which makes
// the edges shimmer when the camera or the object moves. 0 = off.
uniform float snap_strength : hint_range(0.0, 1.0, 0.01) = 1.0;
// Random shaking of every vertex, in console pixels (the unstable geometry of the early 3D games). 0 = off.
uniform float jitter : hint_range(0.0, 2.0, 0.01) = 0.0;
// How many times per second the jitter changes.
uniform float jitter_rate : hint_range(1.0, 30.0, 1.0) = 12.0;

group_uniforms lighting;
// 1 = lit by the lights in the scene, computed at the vertices (smooth Gouraud shading, no per-pixel light).
// 0 = flat, the texture color as it is.
uniform float lit : hint_range(0.0, 1.0, 0.01) = 1.0;
// Self illumination of the whole surface. It keeps this much of its color even in the dark.
uniform float glow : hint_range(0.0, 1.0, 0.01) = 0.0;
// Picture of what glows (windows, runes, lava). Only its bright parts light up, in the dark too.
uniform sampler2D emission_tex : source_color, hint_default_black, filter_nearest, repeat_enable;
// How strongly the emission picture glows.
uniform float emission_strength : hint_range(0.0, 4.0, 0.01) = 1.0;

group_uniforms metal;
// Picture of a sphere that is wrapped around the surface by its normal (a matcap): chrome, gold, a wet floor.
// It already contains its own light, so the lit part is replaced by it.
uniform sampler2D matcap_tex : source_color, hint_default_white, filter_nearest, repeat_disable;
// How much of the surface becomes the metal picture. 0 = off.
uniform float matcap_amount : hint_range(0.0, 1.0, 0.01) = 0.0;

group_uniforms sprite;
// Turns the surface toward the camera: a flat picture that always faces you (trees, enemies, items).
// Full follows the camera in every direction, Upright only turns around the vertical axis (a tree does not lean).
uniform int billboard : hint_enum("Off", "Full", "Upright") = 0;

group_uniforms fog;
// How much of the distance fog is used. 0 = no fog. The fog is worked out at the vertices, as on the console.
uniform float fog_amount : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform vec4 fog_color : source_color = vec4(0.05, 0.06, 0.08, 1.0);
// Distance from the camera where the fog starts, in meters.
uniform float fog_start : hint_range(0.0, 200.0, 0.5) = 8.0;
// Distance where the fog is complete. Close to fog_start makes a hard wall of fog.
uniform float fog_end : hint_range(0.5, 400.0, 0.5) = 30.0;

group_uniforms color;
// Bits per color channel. 5 = the PS1 15-bit color (32 shades per channel). 8 = off, 1 = very few colors.
uniform int color_bits : hint_range(1, 8, 1) = 5;
// Strength of the 4x4 ordered dither that hides the banding of the reduced colors. 0 = no dither.
uniform float dither_amount : hint_range(0.0, 1.0, 0.01) = 1.0;

group_uniforms alpha;
// Pixels with an alpha below this are cut out (leaves, fences, sprites). 0 = off, the surface is solid.
// The transparent and additive variants blend instead (see the README).
uniform float cutout : hint_range(0.0, 1.0, 0.01) = 0.0;

varying vec3 v_affine;  // texture coordinate times w, and w: divided in fragment() they give screen-linear UVs
varying float v_fog;

const int BAYER4[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	// Billboards: rebuild the position from the object center and the camera axes instead of the model's own axes.
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (billboard > 0) {
		vec3 center = MODEL_MATRIX[3].xyz;
		vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
		vec3 right = INV_VIEW_MATRIX[0].xyz;
		vec3 up = INV_VIEW_MATRIX[1].xyz;
		if (billboard == 2) {
			up = normalize(MODEL_MATRIX[1].xyz);  // stays upright: only turns around its own up axis
			right = normalize(cross(up, INV_VIEW_MATRIX[2].xyz));
		}
		vec3 world = center + right * VERTEX.x * scale.x + up * VERTEX.y * scale.y;
		view_pos = VIEW_MATRIX * vec4(world, 1.0);
	}
	vec4 clip = PROJECTION_MATRIX * view_pos;
	float w = max(clip.w, 0.0001);

	// Vertex snapping and jitter: round the screen position to the console pixel grid, then go back to clip space.
	if (clip.w > 0.0001 && (snap_strength > 0.0 || jitter > 0.0)) {
		vec2 grid = VIEWPORT_SIZE * 0.5 / max(pixel_size, 1.0);
		vec2 ndc = clip.xy / clip.w;
		if (jitter > 0.0) {
			float step_id = floor(TIME * jitter_rate);
			vec2 shake = vec2(hash13(vec3(VERTEX * 7.0 + step_id)), hash13(vec3(VERTEX * 7.0 - step_id + 3.1))) - 0.5;
			ndc += shake * jitter / grid;
		}
		vec2 snapped = floor(ndc * grid + 0.5) / grid;
		clip.xy = mix(ndc, snapped, snap_strength) * clip.w;
	}
	POSITION = clip;

	// Affine texturing: the GPU divides every varying by w. Passing uv * w and w lets fragment() undo that.
	vec2 uv = UV * uv_scale + uv_offset + uv_scroll * TIME;
	UV = uv;
	v_affine = vec3(uv * w, w);

	// Distance fog at the vertex.
	v_fog = fog_amount * clamp((length(view_pos.xyz) - fog_start) / max(fog_end - fog_start, 0.001), 0.0, 1.0);
}

// Nintendo 64 texture filter: the three nearest texels of the triangle that contains the point.
vec4 sample_3point(sampler2D tex, vec2 uv) {
	vec2 size = vec2(textureSize(tex, 0));
	vec2 p = uv * size - 0.5;
	vec2 f = fract(p);
	vec2 b = floor(p) + 0.5;
	vec4 c00 = texture(tex, b / size);
	vec4 c10 = texture(tex, (b + vec2(1.0, 0.0)) / size);
	vec4 c01 = texture(tex, (b + vec2(0.0, 1.0)) / size);
	if (f.x + f.y > 1.0) {
		vec4 c11 = texture(tex, (b + vec2(1.0, 1.0)) / size);
		return c11 + (1.0 - f.x) * (c01 - c11) + (1.0 - f.y) * (c10 - c11);
	}
	return c00 + f.x * (c10 - c00) + f.y * (c01 - c00);
}

// Reduces the color to `bits` per channel with the dither added before rounding.
vec3 retro_color(vec3 c, vec2 frag) {
	float levels = exp2(float(color_bits)) - 1.0;
	ivec2 cell = ivec2(floor(frag / max(pixel_size, 1.0)));
	float t = (float(BAYER4[(cell.y & 3) * 4 + (cell.x & 3)]) + 0.5) / 16.0 - 0.5;
	return clamp(floor(c * levels + t * dither_amount + 0.5) / levels, 0.0, 1.0);
}

void fragment() {
	vec2 affine_uv = v_affine.xy / max(v_affine.z, 0.0001);
	vec2 shift = affine_uv - UV;
	shift *= affine_limit / (affine_limit + length(shift));  // soft cap: small shifts stay, huge ones saturate
	vec2 uv = UV + shift * affine;
	vec4 tex = (texture_filter == 1 ? sample_3point(albedo_tex, uv) : texture(albedo_tex, uv)) * albedo_color;
	vec3 base = tex.rgb * mix(vec3(1.0), COLOR.rgb, vertex_color_mix);

#ifdef PSX_BLEND
	ALPHA = tex.a;
#else
	if (cutout > 0.0) {
		ALPHA = tex.a;
		ALPHA_SCISSOR_THRESHOLD = cutout;
	}
#endif

	// Reduced color and dither on the surface color (before the light, which is added per vertex by the engine).
	base = retro_color(base, FRAGCOORD.xy);

	// Metal: the surface takes its color from a picture of a sphere, looked up by the normal. It replaces the lit part.
	vec2 mc = vec2(NORMAL.x * 0.5 + 0.5, -NORMAL.y * 0.5 + 0.5);
	vec3 metal = retro_color(texture(matcap_tex, mc).rgb * albedo_color.rgb, FRAGCOORD.xy);

	// The part of the color that is lit goes to ALBEDO (multiplied by the vertex light), the part that is not
	// (lit < 1, glow, emission, metal) goes to EMISSION. The fog replaces both, so it is not dimmed by the light.
	float unlit = clamp(1.0 - lit + glow, 0.0, 1.0);
	vec3 glowing = texture(emission_tex, uv).rgb * emission_strength;
	ALBEDO = base * lit * (1.0 - matcap_amount) * (1.0 - v_fog);
	EMISSION = (base * unlit * (1.0 - matcap_amount) + metal * matcap_amount + glowing) * (1.0 - v_fog) + fog_color.rgb * v_fog;
#ifdef PSX_ADDITIVE
	ALPHA = tex.a;
#endif
}
