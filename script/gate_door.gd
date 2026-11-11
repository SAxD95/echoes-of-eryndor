extends Node3D

@onready var anim_player: AnimationPlayer = find_child("AnimationPlayer", true, false)
@onready var trigger_zone: Area3D = $TriggerZone

var bodies_in_zone: int = 0

func _ready() -> void:
	trigger_zone.body_entered.connect(_on_body_entered)
	trigger_zone.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D or body.is_in_group("player"):
		bodies_in_zone += 1
		open_door()

func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D or body.is_in_group("player"):
		bodies_in_zone = max(0, bodies_in_zone - 1)
		if bodies_in_zone == 0:
			close_door()

func open_door() -> void:
	# Plays the built-in opening animation
	# (If the animation name is different, check AnimationPlayer in the bottom panel)
	if anim_player.has_animation("open"):
		anim_player.play("open")
	elif anim_player.has_animation("Open"):
		anim_player.play("Open")
	else:
		# If it only has one animation (e.g., standard action), play it forward
		anim_player.play(anim_player.get_animation_list()[0])

func close_door() -> void:
	# Plays the animation in reverse to close
	if anim_player.has_animation("close"):
		anim_player.play("close")
	elif anim_player.has_animation("Close"):
		anim_player.play("Close")
	else:
		# Play the default animation backwards
		anim_player.play_backwards(anim_player.get_animation_list()[0])
