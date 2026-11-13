extends Node3D

@onready var screen_mesh: MeshInstance3D = $MeshInstance3D
var screen_mat: StandardMaterial3D
var pulse_tween: Tween

func _ready() -> void:
	# Duplicate the material so only this tablet changes color
	screen_mat = screen_mesh.get_active_material(0).duplicate()
	screen_mesh.set_surface_override_material(0, screen_mat)
	set_valve_error()

func set_valve_error() -> void:
	screen_mat.albedo_color = Color(0.2, 0.0, 0.0)
	screen_mat.emission = Color(1.0, 0.08, 0.08)
	
	if pulse_tween:
		pulse_tween.kill()
	pulse_tween = create_tween().set_loops()
	pulse_tween.tween_property(screen_mat, "emission_energy_multiplier", 0.8, 0.6)
	pulse_tween.tween_property(screen_mat, "emission_energy_multiplier", 3.0, 0.6)

func set_valve_fixed() -> void:
	if pulse_tween:
		pulse_tween.kill()
	
	var tween := create_tween().set_parallel(true)
	tween.tween_property(screen_mat, "albedo_color", Color(0.0, 0.15, 0.3), 0.5)
	tween.tween_property(screen_mat, "emission", Color(0.1, 0.6, 1.0), 0.5)
	tween.tween_property(screen_mat, "emission_energy_multiplier", 2.2, 0.5)
