extends CanvasLayer

@export var telemetry_label: Label
@export var prompt_label: Label
@export var alert_label: Label

func _ready() -> void:
	GameState.status_message_updated.connect(_on_status_updated)
	GameState.mission_ended.connect(_on_mission_ended)
	
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_signal("prompt_changed"):
		player.prompt_changed.connect(func(text): if prompt_label: prompt_label.text = text)

func _process(_delta: float) -> void:
	if telemetry_label:
		telemetry_label.text = "O2: %.1f%% | ppCO2: %.1f mmHg | LEO: %.2f km/s | T-%.0fs" % [
			GameState.o2_remaining,
			GameState.pp_co2,
			GameState.orbital_velocity,
			GameState.time_left
		]

func _on_status_updated(msg: String) -> void:
	if alert_label:
		alert_label.text = msg

func _on_mission_ended(success: bool, reason: String) -> void:
	if alert_label:
		alert_label.text = ("MISSION SUCCESS: " if success else "MISSION FAILED: ") + reason
