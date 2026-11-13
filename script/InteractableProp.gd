extends Node3D

enum PropType {
	CASSETTE_PHOTO,
	HOLO_TABLE,
	WALL_TERMINAL,
	LOCKED_DOOR,
	PRESSURE_VALVE,
	REACTOR_CORE
}

@export var prop_type: PropType
@export var target_door: Node3D
@export var audio_player: AudioStreamPlayer3D
@export var core_light: OmniLight3D

const AMBER_COLOR := Vector3(2.2, 1.15, 0.2)
const GREEN_COLOR := Vector3(0.2, 2.4, 0.5)

var _highlight_mat: ShaderMaterial
var _meshes: Array[MeshInstance3D] = []
@onready var anim_player: AnimationPlayer = find_child("AnimationPlayer", true, false)


func _ready() -> void:
	var shader := Shader.new()
	shader.code = """
	shader_type spatial;
	render_mode unshaded, cull_front, depth_draw_never;

	uniform float outline_width = 0.012;
	uniform vec3 outline_color : source_color = vec3(2.2, 1.15, 0.2);

	void vertex() {
		vec3 smooth_dir = normalize(mix(NORMAL, normalize(VERTEX + vec3(0.0001)), 0.5));
		VERTEX += smooth_dir * outline_width;
	}

	void fragment() {
		float view_dot = abs(dot(NORMAL, VIEW));
		if (view_dot > 0.35) {
			discard;
		}
		ALBEDO = outline_color;
	}
	"""
	_highlight_mat = ShaderMaterial.new()
	_highlight_mat.shader = shader

	for child in find_children("*", "MeshInstance3D", true, false):
		_meshes.append(child)


func set_highlighted(active: bool) -> void:
	if not active and _highlight_mat:
		_highlight_mat.set_shader_parameter("outline_color", AMBER_COLOR)
	for mesh in _meshes:
		mesh.material_overlay = _highlight_mat if active else null


func mark_activated() -> void:
	if _highlight_mat:
		_highlight_mat.set_shader_parameter("outline_color", GREEN_COLOR)
	set_highlighted(true)


func get_prompt() -> String:
	match prop_type:
		PropType.CASSETTE_PHOTO:
			return "[E] Play Family Cassette"
		PropType.HOLO_TABLE:
			return "[E] Inspect Orbital Trajectory (LEO: %.2f km/s)" % GameState.orbital_velocity
		PropType.WALL_TERMINAL:
			return "[E] Reroute 100 MW Grid (Toggle ECLSS / Propulsion)"
		PropType.LOCKED_DOOR:
			return "[E] Override Bulkhead Lock"
		PropType.PRESSURE_VALVE:
			return "[E] Vent Air Terminal Pressure"
		PropType.REACTOR_CORE:
			return "[E] Ignite Primary Reactor Core"
	return "[E] Interact"


func interact() -> void:
	if audio_player and prop_type != PropType.REACTOR_CORE:
		audio_player.play()

	match prop_type:
		PropType.CASSETTE_PHOTO:
			mark_activated()
			_unlock_door(target_door)
			GameState.status_message_updated.emit("CASSETTE LOG PLAYED: Bulkhead unsealed.")

		PropType.HOLO_TABLE:
			mark_activated()
			GameState.status_message_updated.emit("ORBITAL TELEMETRY: Trajectory verified.")

		PropType.WALL_TERMINAL:
			mark_activated()
			GameState.comms_active = true
			GameState.propulsion_active = true
			_unlock_door(target_door)
			GameState.status_message_updated.emit("POWER REROUTED: Comms & Propulsion online. Bulkhead unsealed.")

		PropType.LOCKED_DOOR:
			mark_activated()
			_unlock_door(target_door)
			GameState.status_message_updated.emit("BULKHEAD OVERRIDE: Door unlocked.")

		PropType.PRESSURE_VALVE:
			mark_activated()
			_play_prop_animation()
			GameState.valve_vented = true
			_unlock_door(target_door)
			GameState.status_message_updated.emit("PRESSURE EQUALIZED: Reactor Bay Airlock unsealed.")

		PropType.REACTOR_CORE:
			if not GameState.comms_active or not GameState.propulsion_active:
				GameState.status_message_updated.emit("IGNITION LOCKED: Enable Comms & Propulsion first.")
				return
			if not GameState.valve_vented:
				GameState.status_message_updated.emit("IGNITION LOCKED: Vent Air Terminal Pressure first.")
				return
			mark_activated()
			_play_prop_animation()
			GameState.reactor_ignited = true
			if core_light:
				core_light.light_energy = 4.5
			if audio_player:
				audio_player.play()
			GameState.end_mission(true, "NOMINAL ORBIT ACHIEVED (7.89 km/s) - CREW SURVIVED")


func _play_prop_animation() -> void:
	if not anim_player:
		return
	if anim_player.has_animation("EXPORT_layout_a_valve_handwheelAction"):
		anim_player.play("EXPORT_layout_a_valve_handwheelAction")
	elif anim_player.get_animation_list().size() > 0:
		anim_player.play(anim_player.get_animation_list()[0])


func _unlock_door(door: Node3D) -> void:
	if not door:
		return
	if door.has_method("open"):
		door.open()
	elif door.has_method("unlock"):
		door.unlock()
	else:
		door.visible = false
		door.process_mode = Node.PROCESS_MODE_DISABLED
