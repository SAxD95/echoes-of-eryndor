# PSX - Godot Shader

A PlayStation 1 look for 3D in Godot: a material for your meshes and a screen effect for the whole view. Vertex snapping and jitter, affine texture warping, per-vertex lighting and fog, 15-bit color with dithering, sphere-mapped metal, emission, billboards, alpha cutout and an optional Nintendo 64 texture filter.

- Godot 4.x. Works in GL Compatibility, Mobile and Forward+. No plugin, no autoload and no global setup.
- Try it in your browser, with sliders, ready-made looks and your own texture, before you download: see the itch.io page.

Installed at `res://addons/psx_shader/` (no plugin to enable: it is only shader files, textures and an example).

## What is in the folder

| File | What it is |
|---|---|
| `shaders/psx.gdshader` | The material (opaque, one side). The main file: copy it into your project |
| `shaders/psx_double_sided.gdshader` | The same material drawing both faces (cloth, leaves, thin walls) |
| `shaders/psx_transparent.gdshader` | The same material blended by the alpha of the texture (windows, ghosts) |
| `shaders/psx_additive.gdshader` | The same material adding its light to what is behind (beams, fire) |
| `shaders/psx_screen.gdshader` | The screen effect: chunky pixels, 15-bit color and dither on the final image |
| `psx_material.tres` | A ready material with the brick texture |
| `example/demo.gd`, `example/example.tscn` | The example: a torch-lit hall that cycles through six looks (`scene_kind` in `demo.gd` also builds a graveyard from the models in `example/kenney/`) |
| `example/kenney/` | A few models of Kenney's Graveyard Kit (CC0, see `example/kenney/LICENSE.txt`) used by the example scenes |

The three variants are copies of `psx.gdshader` with another `render_mode`; the blend and the culling cannot change from a parameter in Godot. Their parameters are the same.

## Use it in your project

1. Copy `shaders/psx.gdshader` into your project (and `psx_screen.gdshader` for the screen effect).
2. On a `MeshInstance3D`, create a `ShaderMaterial` and assign the shader (or load `psx_material.tres`).
3. Put your picture in `albedo_tex` and tweak the parameters in the Inspector.
4. For the screen effect: add a `CanvasLayer`, put a full-rect `ColorRect` in it and give it a `ShaderMaterial` with `psx_screen.gdshader`. Keep `screen_pixel_size` equal to `pixel_size` of the material. `demo.gd` shows it in `_build_screen`.

`pixel_size` is the size of one console pixel in screen pixels: 3 on a 960 x 720 view is the classic 320 x 240. The vertices snap to that grid and the dither cells use it. Nothing needs to render at a low resolution; if you want the speed of a real 320 x 240 render, put the camera in a `SubViewport` of that size, show it with a `SubViewportContainer` (stretch on, Nearest filter) and set `pixel_size` to 1.

## The material

**Texture**: `albedo_tex` is drawn with nearest filtering and repeating. `affine` is the texture swimming of the PS1: the texture bends across big polygons close to the camera (1 = console, 0 = modern). `texture_filter` switches between hard texels and the soft three-texel blur of the Nintendo 64. `vertex_color_mix` is how much the vertex colors tint the surface: PS1 levels were lit by painting the vertices, and this is how to use that.

**Snapping**: every vertex jumps to a whole console pixel, so edges shimmer when the camera or an object moves. `jitter` adds a random shake on top, changing `jitter_rate` times a second. The effect shows most on big polygons: cut meshes into pieces of a few meters.

**Lighting**: the light of the scene is worked out at the vertices (Gouraud, no per-pixel light, no shadows). `lit` 0 is flat, `glow` makes the whole surface light itself, `emission_tex` and `emission_strength` make only the bright parts of a picture glow (windows, runes, lava).

**Metal**: `matcap_tex` is a picture of a sphere that is wrapped around the surface by its normal; it already contains its own light. `matcap_amount` says how much of the surface becomes that picture. Chrome, gold and ember pictures are in `assets/`.

**Sprite**: `billboard` turns the surface toward the camera. Full follows the camera in every direction, Upright only turns around the vertical axis (a tree does not lean).

**Fog**: distance fog, also worked out at the vertices, with its own color, start and end.

**Color**: `color_bits` reduces each channel (5 = PS1 15-bit color) and `dither_amount` hides the banding with a 4x4 ordered pattern. In the material this is applied to the surface color before the vertex light is added; the screen shader does the same on the final image, which covers light and fog too.

**Alpha**: `cutout` removes pixels below an alpha value (fences, leaves). For real blending use the transparent or additive variant.

## Parameters of the material

| Name | What it does |
|---|---|
| `albedo_tex` | The picture on the surface (nearest filter, repeats) |
| `albedo_color` | Tint multiplied with the texture; white leaves it as it is |
| `vertex_color_mix` | How much the mesh vertex colors tint the surface (0 ignores them) |
| `texture_filter` | Nearest (hard texels) or N64 3-point (soft, triangular blur) |
| `uv_scale` | Repeats the texture; 2 = twice across each face |
| `uv_offset` | Moves the texture, in texture widths |
| `uv_scroll` | Slides the texture, in texture widths per second |
| `affine` | 1 = PS1 texture swimming, 0 = perspective-correct |
| `affine_limit` | Caps how far affine mapping may slide the texture (in repeats); 8 = no cap |
| `pixel_size` | Size of one console pixel in screen pixels (snap grid and dither cells) |
| `snap_strength` | How strongly vertices snap to the pixel grid (0 = off) |
| `jitter` | Random shaking of every vertex, in console pixels (0 = off) |
| `jitter_rate` | How many times per second the jitter changes |
| `lit` | 1 = lit by the scene lights at the vertices, 0 = flat color |
| `glow` | The whole surface keeps this much of its color in the dark |
| `emission_tex` | Picture of what glows; only its bright parts light up |
| `emission_strength` | How strongly the emission picture glows |
| `matcap_tex` | Picture of a sphere wrapped by the normal (chrome, gold) |
| `matcap_amount` | How much of the surface becomes the metal picture (0 = off) |
| `billboard` | Off, Full or Upright: the surface faces the camera |
| `fog_amount` | How much of the distance fog is used (0 = none) |
| `fog_color` | Color of the fog |
| `fog_start` | Distance where the fog starts, in meters |
| `fog_end` | Distance where the fog is complete |
| `color_bits` | Bits per color channel; 5 = PS1, 8 = off |
| `dither_amount` | Strength of the 4x4 dither (0 = none) |
| `cutout` | Pixels with alpha below this are cut out (0 = solid) |

## Parameters of the screen effect

| Name | What it does |
|---|---|
| `screen_amount` | How much of the effect is used (0 = the picture as it is) |
| `screen_pixel_size` | Size of one console pixel in screen pixels; same value as `pixel_size` |
| `screen_color_bits` | Bits per color channel; 5 = PS1, 8 = off |
| `screen_dither` | Strength of the 4x4 ordered dither |
| `grain` | Brightness noise that changes every frame |
| `vignette` | Darkens the corners of the screen |

## Example project

Open this folder in Godot 4.x and run it: `main.tscn` walks down a torch-lit hall and cycles through six looks (PS1, horror fog, modern, N64 filter, crunchy 3-bit, shaky). The walls are lit only by light painted into their vertices, the pillars and crates by the lights of the scene. The textures in `assets/` are made for this project and are CC0 too. The models in `example/kenney/` are from Kenney's Graveyard Kit (www.kenney.nl, CC0).

## Prior art and credits

The code of this pack is mine. The techniques are shared knowledge of the PS1 and N64 look, and these people wrote about them or showed them before: the vertex snapping idea of dsoft20's `psx_retroshader` (Unity), the way `uv * w` and `w` are passed to undo the perspective division (described in heyheythere's devlog on PS1 wobble in Godot), the matcap lookup for metal and the billboard sprites (seen in MenacingMecha's godot-psx-style-demo, MIT) and the three-texel N64 filter (documented by many emulator and shader authors). If you want other approaches, those and the Ultimate Retro Shader Collection by Zorochase are worth a look.

## License

CC0 (public domain): see `LICENSE.txt`. Credit is appreciated, not required.
