extends Node3D
## Demo: a torch-lit hall walked at console resolution, cycling through looks so you can see what the parameters do.
## Everything is built here in code. To use the shader in your own scene, give any MeshInstance3D a ShaderMaterial
## that uses shaders/psx.gdshader (or psx_material.tres) and set its parameters. For the screen effect, put a
## ColorRect with shaders/psx_screen.gdshader inside a CanvasLayer (see _build_screen below).

const LOOK_TIME := 3.5

## -1 cycles through the looks; 0 or more stays on one look (an index of LOOKS).
@export var fixed_look := -1
@export var show_info := true
## > 0 replaces the pixel_size of every look (for covers rendered at another size).
@export var pixel_override := 0.0
## > 0: the camera goes forward and back in a loop of this many seconds (for GIFs); 0 = walks on and on.
@export var loop_seconds := 0.0
## "hall" = the torch-lit brick hall made of primitives; "graveyard" = an outdoor scene made only of the kit.
@export_enum("hall", "graveyard") var scene_kind := "hall"

# Each look sets only what it names; every other parameter goes back to the default (DEFAULTS).
const LOOKS := [
	{"name": "PS1", "fog_amount": 0.55},
	{"name": "Horror fog", "fog_amount": 1.0, "fog_start": 2.0, "fog_end": 15.0, "color_bits": 4, "screen_color_bits": 4, "grain": 0.04, "vignette": 0.5},
	{"name": "Modern (all off)", "snap_strength": 0.0, "affine": 0.0, "color_bits": 8, "dither_amount": 0.0, "screen_amount": 0.0},
	{"name": "N64 filter", "texture_filter": 1, "snap_strength": 0.0, "affine": 0.0, "fog_amount": 0.3, "pixel_size": 2.0, "screen_pixel_size": 2.0},
	{"name": "Crunchy 3-bit", "color_bits": 3, "screen_color_bits": 3, "fog_amount": 0.4, "pixel_size": 4.0, "screen_pixel_size": 4.0},
	{"name": "Shaky", "jitter": 1.0, "fog_amount": 0.3},
]
const DEFAULTS := {"snap_strength": 1.0, "affine": 1.0, "color_bits": 5, "dither_amount": 1.0, "pixel_size": 3.0, "jitter": 0.0,
		"fog_amount": 0.0, "texture_filter": 0, "fog_start": 8.0, "fog_end": 30.0, "screen_amount": 1.0, "screen_pixel_size": 3.0,
		"screen_color_bits": 5, "screen_dither": 1.0, "grain": 0.0, "vignette": 0.0}
const SCREEN_KEYS := ["screen_amount", "screen_pixel_size", "screen_color_bits", "screen_dither", "grain", "vignette"]
const TORCHES := [Vector3(-2.2, 2.0, -5), Vector3(2.2, 2.0, -11), Vector3(-2.2, 2.0, -17), Vector3(2.2, 2.0, -23)]

var _materials: Array[ShaderMaterial] = []
var _screen: ShaderMaterial
var _camera: Camera3D
var _info: Label
var _t := 0.0
var _flames: Array[OmniLight3D] = []
var _env: Environment
var _defaults := DEFAULTS.duplicate()
var _bake_lights: Array = TORCHES  # points of the painted light (positions of torches or lamps)
var _bake_ambient := Color(0.32, 0.34, 0.46)


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.04, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.76)
	_env = env
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	if scene_kind == "graveyard":
		_build_graveyard()
	else:
		_build_hall()

	_camera = Camera3D.new()
	_camera.fov = 70
	_camera.far = 80.0
	add_child(_camera)

	_build_screen()


## The screen effect: a full-screen ColorRect with the psx_screen shader, in a CanvasLayer above the 3D view.
func _build_screen() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen = ShaderMaterial.new()
	_screen.shader = load("res://addons/psx_shader/shaders/psx_screen.gdshader")
	rect.material = _screen
	layer.add_child(rect)
	_info = Label.new()
	_info.position = Vector2(10, 8)
	_info.visible = show_info
	layer.add_child(_info)


func _material(tex: String, uv: Vector2, extra := {}) -> ShaderMaterial:
	var m := (load("res://addons/psx_shader/psx_material.tres") as ShaderMaterial).duplicate() as ShaderMaterial
	m.set_shader_parameter("albedo_tex", load("res://addons/psx_shader/assets/%s.png" % tex))
	m.set_shader_parameter("uv_scale", uv)
	for k in extra:
		m.set_shader_parameter(k, extra[k])
	_materials.append(m)
	return m


## Light painted into the vertices, like a PS1 level: dim blue ambient and a warm pool around each torch.
func _baked(p: Vector3) -> Color:
	var c := _bake_ambient
	for t in _bake_lights:
		var k := clampf(1.0 - p.distance_to(t) / 8.0, 0.0, 1.0)
		c += Color(1.0, 0.62, 0.3) * k * k * 1.5
	return Color(minf(c.r, 1.0), minf(c.g, 1.0), minf(c.b, 1.0))


## A wall, floor or ceiling cut into 2 m cells, with the baked light in the vertex colors. The texture repeats every 2 m.
func _plane(size: Vector2, pos: Vector3, normal: Vector3, mat: Material) -> void:
	var basis := Basis(Quaternion(Vector3.UP, normal))
	var nx := maxi(1, int(size.x / 2.0))
	var nz := maxi(1, int(size.y / 2.0))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i in nx:
		for j in nz:
			var x0 := -size.x / 2.0 + size.x * i / nx
			var x1 := -size.x / 2.0 + size.x * (i + 1) / nx
			var z0 := -size.y / 2.0 + size.y * j / nz
			var z1 := -size.y / 2.0 + size.y * (j + 1) / nz
			for c in [[x0, z0], [x1, z0], [x0, z1], [x1, z0], [x1, z1], [x0, z1]]:
				st.set_uv(Vector2(c[0], c[1]) * 0.5)
				st.set_color(_baked(pos + basis * Vector3(c[0], 0.0, c[1])))
				st.add_vertex(Vector3(c[0], 0.0, c[1]))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.position = pos
	mi.transform.basis = basis
	add_child(mi)


func _box(size: Vector3, pos: Vector3, mat: Material, yaw := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees.y = yaw
	add_child(mi)
	return mi


func _build_hall() -> void:
	var wall := _material("brick", Vector2(1, 1), {"lit": 0.0})  # lit by the painted vertex colors only
	var floor_m := _material("stone", Vector2(1, 1), {"lit": 0.0})
	var ceil_m := _material("metal", Vector2(1, 1), {"lit": 0.0})
	_plane(Vector2(3.6, 44), Vector3(-2.5, 1.8, -20), Vector3.RIGHT, wall)
	_plane(Vector2(3.6, 44), Vector3(2.5, 1.8, -20), Vector3.LEFT, wall)
	_plane(Vector2(5, 44), Vector3(0, 0, -20), Vector3.UP, floor_m)
	_plane(Vector2(5, 44), Vector3(0, 3.6, -20), Vector3.DOWN, ceil_m)
	_plane(Vector2(5, 3.6), Vector3(0, 1.8, -42), Vector3.BACK, wall)

	# stone pillars lit by the lights of the scene (per vertex)
	for z in [-8.0, -14.0, -20.0]:
		for x in [-2.0, 2.0]:
			_box(Vector3(0.7, 3.6, 0.7), Vector3(x, 1.8, z), _material("stone", Vector2(1, 3)))
	# crates
	for spec in [[-1.5, -4.0, 20.0], [1.4, -9.5, -15.0], [-1.2, -12.0, 40.0], [0.4, -12.0, 5.0]]:
		_box(Vector3(0.9, 0.9, 0.9), Vector3(spec[0], 0.45, spec[1]), _material("crate", Vector2(1, 1)), spec[2])
	# torches: a glowing block and a flickering light
	for t in TORCHES:
		var wall_side := signf(t.x)
		var flame := _box(Vector3(0.18, 0.4, 0.18), Vector3(t.x - wall_side * 0.1, t.y, t.z), _material("stone", Vector2(1, 1), {"glow": 1.0, "lit": 0.0, "albedo_color": Color(1.0, 0.62, 0.2)}))
		flame.rotation_degrees.y = 45.0
		_torch_light(t)
	# a chrome ball on a pedestal, runes in the floor and a wire gate
	_box(Vector3(0.8, 0.5, 0.8), Vector3(0, 0.25, -16.0), _material("stone", Vector2(1, 1)))
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.8
	sphere.radial_segments = 12
	sphere.rings = 6
	ball.mesh = sphere
	ball.material_override = _material("checker", Vector2(1, 1), {"matcap_amount": 1.0, "matcap_tex": load("res://addons/psx_shader/assets/chrome.png")})
	ball.position = Vector3(0, 0.9, -16.0)
	add_child(ball)
	_build_gate()


func _torch_light(t: Vector3) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.66, 0.35)
	light.omni_range = 9.0
	light.light_energy = 2.0
	light.position = t - Vector3(signf(t.x) * 0.5, 0, 0)
	add_child(light)
	_flames.append(light)


## Runes in the floor and a wire gate at the end of the hall (both scenes).
func _build_gate() -> void:
	_box(Vector3(2.6, 0.02, 2.6), Vector3(0, 0.011, -26.0), _material("stone", Vector2(1, 1),
			{"emission_tex": load("res://addons/psx_shader/assets/runes.png"), "emission_strength": 1.2, "lit": 0.0}))
	var gate := _material("fence", Vector2(4, 3), {"cutout": 0.5, "lit": 0.0})
	var gate_mesh := QuadMesh.new()
	gate_mesh.size = Vector2(5, 3.6)
	var gate_node := MeshInstance3D.new()
	gate_node.mesh = gate_mesh
	gate_node.material_override = gate
	gate_node.position = Vector3(0, 1.8, -31.0)
	add_child(gate_node)


## One piece of the Kenney Graveyard Kit with the PSX material. The kit is about 1 m per tile, so `s` scales it up.
func _kit(model: String, pos: Vector3, yaw := 0.0, s := 3.0, extra := {}) -> Node3D:
	var node := (load("res://addons/psx_shader/example/kenney/%s.glb" % model) as PackedScene).instantiate() as Node3D
	var m := (load("res://addons/psx_shader/psx_material.tres") as ShaderMaterial).duplicate() as ShaderMaterial
	m.set_shader_parameter("albedo_tex", load("res://addons/psx_shader/example/kenney/Textures/colormap.png"))
	m.set_shader_parameter("albedo_color", Color(0.78, 0.82, 1.0))  # the kit palette is pastel; a cold tint sets the night
	m.set_shader_parameter("fog_color", Color(0.05, 0.07, 0.12))
	for k in extra:
		m.set_shader_parameter(k, extra[k])
	_materials.append(m)
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = m
	node.position = pos
	node.rotation_degrees.y = yaw
	node.scale = Vector3.ONE * s
	add_child(node)
	return node


func _lamp(p: Vector3, color: Color, energy := 3.6) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.omni_range = 9.0
	light.light_energy = energy
	light.position = p
	add_child(light)
	_flames.append(light)


## A night graveyard: a road between iron fences, graves, pines, lamp posts and a crypt at the end.
func _build_graveyard() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var lamps := [Vector3(-2.4, 3.3, -3), Vector3(2.4, 3.3, -12), Vector3(-2.4, 3.3, -21)]
	_bake_lights = lamps
	_bake_ambient = Color(0.22, 0.27, 0.46)
	_env.background_color = Color(0.05, 0.07, 0.12)
	_env.ambient_light_color = Color(0.34, 0.40, 0.62)
	_defaults["fog_start"] = 3.0
	_defaults["fog_end"] = 28.0
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.62, 0.9)
	moon.light_energy = 0.4
	moon.rotation_degrees = Vector3(-50, 30, 0)
	moon.shadow_enabled = false
	add_child(moon)
	var grass := _material("grass", Vector2(1, 1), {"lit": 0.0, "fog_color": Color(0.05, 0.07, 0.12)})
	_plane(Vector2(40, 64), Vector3(0, 0, -22), Vector3.UP, grass)
	for i in 14:
		_kit("road", Vector3(0, 0.01, 4.0 - i * 2.4), 0.0, 3.0)
	for side in [-1.0, 1.0]:
		for i in 12:
			_kit("iron-fence", Vector3(side * 7.0, 0, 3.0 - i * 3.0), 90.0, 3.0)
		for i in 7:
			var z := 2.0 - i * 5.0 + rng.randf_range(-1, 1)
			var kind: String = ["gravestone-cross", "gravestone-round", "gravestone-bevel", "gravestone-wide", "grave", "gravestone-broken", "gravestone-decorative"][rng.randi() % 7]
			_kit(kind, Vector3(side * rng.randf_range(3.4, 5.4), 0, z), rng.randf_range(-12, 12) + (180 if side > 0 else 0), 2.6)
		for i in 5:
			var pine: String = ["pine", "pine-crooked", "pine-fall"][rng.randi() % 3]
			_kit(pine, Vector3(side * rng.randf_range(9.0, 14.0), 0, 6.0 - i * 8.0 + rng.randf_range(-2, 2)), rng.randf_range(0, 360), rng.randf_range(3.6, 5.0))
	for l in lamps:
		_kit("lightpost-single", Vector3(l.x, 0, l.z), 0.0 if l.x < 0 else 180.0, 3.0, {"glow": 0.0})
		_lamp(l - Vector3(signf(l.x) * 0.3, 0.4, 0), Color(1.0, 0.72, 0.4))
		_kit("pumpkin-carved", Vector3(l.x * 1.6, 0, l.z + 1.2), rng.randf_range(0, 360), 2.4, {"glow": 0.7})
	_kit("crypt-large", Vector3(0, 0, -29), 0.0, 4.0)
	_kit("fire-basket", Vector3(-2.2, 0, -25), 0.0, 3.0, {"glow": 1.0, "lit": 0.0, "albedo_color": Color(1.0, 0.6, 0.2)})
	_kit("fire-basket", Vector3(2.2, 0, -25), 0.0, 3.0, {"glow": 1.0, "lit": 0.0, "albedo_color": Color(1.0, 0.6, 0.2)})
	_lamp(Vector3(0, 1.4, -24), Color(1.0, 0.55, 0.25), 2.6)
	_kit("character-ghost", Vector3(3.0, 0.2, -9), -30.0, 3.0, {"glow": 0.6, "albedo_color": Color(0.8, 0.95, 1.0)})
	_kit("character-skeleton", Vector3(-3.4, 0, -17), 40.0, 3.0)


func _process(delta: float) -> void:
	_t += delta
	var look: Dictionary = LOOKS[(int(_t / LOOK_TIME) if fixed_look < 0 else fixed_look) % LOOKS.size()]
	for k in _defaults:
		var v: Variant = look.get(k, _defaults[k])
		if pixel_override > 0.0 and (k == "pixel_size" or k == "screen_pixel_size"):
			v = pixel_override
		if k in SCREEN_KEYS:
			_screen.set_shader_parameter(k, v)
		else:
			for m in _materials:
				m.set_shader_parameter(k, v)
	for i in _flames.size():
		_flames[i].light_energy = 2.0 + sin(_t * 9.0 + i * 2.0) * 0.25 + sin(_t * 23.0 + i) * 0.15
	# The camera walks down the hall and sways, so the snapping and the texture swimming show.
	if loop_seconds > 0.0:
		var p := _t / loop_seconds * TAU
		_camera.position = Vector3(sin(p) * 0.6, 1.55 + sin(p * 4.0) * 0.04, 2.0 - 7.0 * (0.5 - 0.5 * cos(p)))
		_camera.rotation = Vector3(sin(p * 2.0) * 0.03, sin(p) * 0.14, sin(p) * 0.02)
	else:
		var u := _t * 0.35
		_camera.position = Vector3(sin(u * 1.7) * 0.6, 1.55 + sin(u * 6.0) * 0.04, -fposmod(u * 4.0, 30.0) + 2.0)
		_camera.rotation = Vector3(sin(u * 2.3) * 0.03, sin(u * 1.1) * 0.14, sin(u * 1.7) * 0.02)
	_info.text = "%s  |  snap %.1f  |  affine %.1f  |  color_bits %d  |  fog %.2f  |  pixel_size %.0f" % [
		look["name"], look.get("snap_strength", 1.0), look.get("affine", 1.0), look.get("color_bits", 5), look.get("fog_amount", 0.0), look.get("pixel_size", 3.0)]
