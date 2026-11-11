extends Control
## The kit in use: a ship's HUD, a systems window, a cargo hold and a comms line over a starfield,
## all plain Controls styled by one Theme. The buttons along the bottom swap the theme.

const KIT := "res://addons/pixel_ui_scifi/"
const ALL_THEMES: Array[String] = ["cyan", "amber", "green", "magenta", "red", "steel"]
const ART_HEIGHT := 240.0

## Store capture only: switch to the next theme every this many frames.
@export var cycle_frames := 0

var frame := 0
var theme_buttons := {}


## Draws the UI at a whole-number scale so the art pixels stay square: the largest that still
## fits `art_height` pixels of art on screen.
static func pixel_scale(node: Node, art_height: float) -> void:
	var window := node.get_tree().root
	window.content_scale_factor = 1.0
	window.content_scale_factor = maxf(1.0, floorf(window.get_visible_rect().size.y / art_height))


static func themes() -> Array[String]:
	var installed: Array[String] = []
	for n in ALL_THEMES:
		if ResourceLoader.exists(KIT + "themes/%s.tres" % n):
			installed.append(n)
	return installed


## The named theme, or the first one installed.
static func kit_theme(name: String) -> Theme:
	return load(KIT + "themes/%s.tres" % (name if name in themes() else themes()[0]))


## Null when the icon isn't installed.
static func icon_texture(name: String) -> Texture2D:
	var path := KIT + "icons/%s.png" % name
	return load(path) if ResourceLoader.exists(path) else null


## The icons are white: a TextureRect takes the theme's colour through `self_modulate`, which
## `tint` sets from the Button icon colour of the theme in effect.
static func icon(name: String) -> TextureRect:
	var t := TextureRect.new()
	t.texture = icon_texture(name)
	t.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	t.add_to_group(&"tinted")
	return t


static func tint(root: Node) -> void:
	for node in root.get_tree().get_nodes_in_group(&"tinted"):
		if root.is_ancestor_of(node) or node == root:
			var c := node as Control
			c.self_modulate = c.get_theme_color(&"icon_normal_color", &"Button")


## A titled window; add its content to the returned VBox.
static func window(parent: Control, title: String, at: Vector2, width: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"WindowPanel"
	panel.position = at
	panel.custom_minimum_size.x = width
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	var label := Label.new()
	label.text = title
	label.theme_type_variation = &"Title"
	box.add_child(label)
	return box


static func row(parent: Control, separation := 3) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	parent.add_child(h)
	return h


static func bar(parent: Control, colour: String, value: float, width: float) -> ProgressBar:
	var b := ProgressBar.new()
	if colour != "":
		b.theme_type_variation = StringName(colour + "Bar")
	b.show_percentage = false
	b.value = value
	b.custom_minimum_size = Vector2(width, 8)
	parent.add_child(b)
	return b


static func slider(parent: Control, label: String, value: float) -> void:
	var r := row(parent)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = 36
	r.add_child(l)
	var s := HSlider.new()
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(s)


static func label(parent: Control, text: String) -> Label:
	var l := Label.new()
	l.text = text
	parent.add_child(l)
	return l


func _ready() -> void:
	get_viewport().canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST  # project.godot's, for a project without it
	pixel_scale(self, ART_HEIGHT)
	add_child(Starfield.new())
	theme = kit_theme("cyan")
	_hud()
	_systems()
	_cargo()
	_target()
	_comms()
	var switcher := row(self, 2)
	switcher.position = Vector2(6, 222)
	var group := ButtonGroup.new()
	for name in themes():
		var b := Button.new()
		b.text = name.capitalize()
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = name == "cyan"
		b.toggled.connect(func(on: bool) -> void:
			if on:
				theme = kit_theme(name)
				tint(self))
		switcher.add_child(b)
		theme_buttons[name] = b
	tint(self)


func _process(_delta: float) -> void:
	if cycle_frames <= 0:
		return
	frame += 1
	if frame % cycle_frames == 0:
		var names := themes()
		var next: String = names[(names.find("cyan") + frame / cycle_frames) % names.size()]
		theme_buttons[next].button_pressed = true


func _hud() -> void:
	var rows := VBoxContainer.new()
	rows.position = Vector2(6, 5)
	rows.add_theme_constant_override("separation", 1)
	add_child(rows)
	for pair in [["heart", "Red", 72], ["shield", "Blue", 48], ["energy", "Gold", 90]]:
		var r := row(rows, 2)
		r.add_child(icon(pair[0]))
		var b := bar(r, pair[1], pair[2], 70)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var money := row(self, 1)
	money.position = Vector2(290, 5)
	for pair in [["credit", "4096"], ["crystal", "12"], ["fuel", "68%"]]:
		money.add_child(icon(pair[0]))
		label(money, pair[1])
		var gap := Control.new()
		gap.custom_minimum_size.x = 4
		money.add_child(gap)


func _systems() -> void:
	var box := window(self, "SHIP SYSTEMS", Vector2(6, 62), 150)
	slider(box, "Thrust", 70)
	slider(box, "Shields", 40)
	var auto := CheckBox.new()
	auto.text = "Autopilot"
	auto.button_pressed = true
	box.add_child(auto)
	var cloak := CheckBox.new()
	cloak.text = "Cloak"
	box.add_child(cloak)
	var mode := OptionButton.new()
	for m in ["Cruise", "Combat", "Stealth"]:
		mode.add_item(m)
	box.add_child(mode)
	var callsign := LineEdit.new()
	callsign.placeholder_text = "Callsign"
	box.add_child(callsign)
	var buttons := row(box)
	for t in ["Abort", "Engage"]:
		var b := Button.new()
		b.text = t
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(b)


func _cargo() -> void:
	var box := window(self, "CARGO HOLD", Vector2(164, 28), 258)
	var tabs := TabContainer.new()
	box.add_child(tabs)
	var items := GridContainer.new()
	items.name = "Items"
	items.columns = 9
	items.add_theme_constant_override("h_separation", 2)
	items.add_theme_constant_override("v_separation", 2)
	tabs.add_child(items)
	var stock := [["fuel", 3], ["battery", 2], ["crystal", 12], ["chip", 4], ["keycard", 1], ["health", 5],
		["laser", 1], ["rocket", 2], ["cargo", 6], ["wrench", 1], ["satellite", 0], ["asteroid", 9], ["radar", 0],
		["robot", 0], ["alien", 0], ["star", 0], ["energy", 0], ["planet", 0]]
	stock = stock.filter(func(pair: Array) -> bool: return icon_texture(pair[0]) != null).slice(0, 16)
	for i in 18:
		var slot := PanelContainer.new()
		slot.theme_type_variation = &"InsetPanel"
		slot.custom_minimum_size = Vector2(24, 24)
		items.add_child(slot)
		if i >= stock.size():
			continue
		var pair: Array = stock[i]
		var art := icon(pair[0])
		art.tooltip_text = String(pair[0]).capitalize()
		slot.add_child(art)
		if pair[1] > 1:
			var count := Label.new()
			count.text = str(pair[1])
			count.add_theme_color_override("font_shadow_color", Color.BLACK)
			art.add_child(count)
			count.position = Vector2(19, 10) - Vector2(count.get_minimum_size().x, 0)
	var crew := VBoxContainer.new()
	crew.name = "Crew"
	tabs.add_child(crew)
	for pair in [["astronaut", "Cmdr. Vega"], ["robot", "Unit K-9"]]:
		var r := row(crew)
		r.add_child(icon(pair[0]))
		var l := label(r, pair[1])
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b := Button.new()
		b.text = "Assign"
		r.add_child(b)
	var hold := row(box)
	hold.add_child(icon("cargo"))
	label(hold, "Hold 60%")
	var fill := bar(hold, "", 60, 0)
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var actions := row(box)
	for pair in [["check", "Use"], ["trash", "Jettison"], ["info", "Scan"]]:
		var b := Button.new()
		b.text = pair[1]
		b.icon = icon_texture(pair[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(b)


func _target() -> void:
	var frame_panel := PanelContainer.new()
	frame_panel.theme_type_variation = &"BracketPanel"
	frame_panel.position = Vector2(100, 4)
	frame_panel.custom_minimum_size = Vector2(56, 52)
	add_child(frame_panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	frame_panel.add_child(box)
	var reticle := TextureRect.new()
	reticle.texture = load(KIT + "hud/reticle_lock.png")
	reticle.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	reticle.add_to_group(&"tinted")
	box.add_child(reticle)
	label(box, "LOCKED").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _comms() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(6, 187)
	panel.custom_minimum_size.x = 416
	add_child(panel)
	var r := row(panel, 6)
	var face := PanelContainer.new()
	face.theme_type_variation = &"InsetPanel"
	face.add_child(icon("astronaut"))
	r.add_child(face)
	var text := label(r, "Incoming transmission from Outpost 7.\nDock at bay 3 and mind the asteroids.")
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var next := Button.new()
	next.icon = icon_texture("arrow_right")
	next.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(next)


## Stars and a planet behind the UI, so the panels show they let a little through.
class Starfield extends Control:
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		show_behind_parent = true

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 140:
			var p := Vector2(rng.randi_range(0, 427), rng.randi_range(0, 240))
			var v := rng.randf_range(0.25, 1.0)
			draw_rect(Rect2(p, Vector2.ONE), Color(v, v, v * 1.1))
		draw_circle(Vector2(330, 180), 70, Color(0.09, 0.1, 0.2))
		draw_circle(Vector2(318, 170), 58, Color(0.12, 0.14, 0.27))
