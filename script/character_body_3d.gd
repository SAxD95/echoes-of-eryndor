extends CharacterBody3D

const WALK_SPEED: float = 4.5
const SPRINT_SPEED: float = 7.5
const ACCELERATION: float = 20.0
const FRICTION: float = 25.0
const JUMP_VELOCITY: float = 4.5
const MOUSE_SENSITIVITY: float = 0.0025

# Maximum height of stairs/debris to glide over in meters
const MAX_STEP_HEIGHT: float = 0.45

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# References
@onready var camera: Camera3D = find_child("Camera3D", true, false)
@onready var anim_player: AnimationPlayer = find_child("AnimationPlayer", true, false)

var is_interacting: bool = false

func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Floor settings for smooth stair transitions
	floor_snap_length = 0.4
	floor_constant_speed = true
	floor_stop_on_slope = true
	floor_max_angle = deg_to_rad(55.0)

	# Hide torso/head meshes from first-person view while keeping arms/hands visible
	for mesh in find_children("*", "MeshInstance3D", true, false):
		var mesh_name: String = mesh.name.to_lower()
		if "head" in mesh_name or "body" in mesh_name or "torso" in mesh_name or "chest" in mesh_name:
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY

	if anim_player:
		anim_player.animation_finished.connect(_on_animation_finished)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Horizontal rotation (yaw)
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		
		# Vertical tilt (pitch) - Inverted look (+ instead of -)
		if camera:
			camera.rotate_x(event.relative.y * MOUSE_SENSITIVITY)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-45.0), deg_to_rad(65.0))

	# Trigger interact animation via "interact" action or standard 'E' key
	if (event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and event.keycode == KEY_E)) and not is_interacting:
		trigger_interact()

	# Toggle mouse lock with Escape
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move_dir: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var is_sprinting: bool = (Input.is_key_pressed(KEY_SHIFT) or Input.is_action_pressed("sprint")) and move_dir != Vector3.ZERO
	var target_speed: float = SPRINT_SPEED if is_sprinting else WALK_SPEED

	var accel: float = ACCELERATION if is_on_floor() else ACCELERATION * 0.25
	var fric: float = FRICTION if is_on_floor() else 1.0

	if move_dir != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, move_dir.x * target_speed, accel * delta)
		velocity.z = move_toward(velocity.z, move_dir.z * target_speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, fric * delta)
		velocity.z = move_toward(velocity.z, 0, fric * delta)

	# Execute step-up test over stairs and debris before physics movement
	if is_on_floor() and move_dir != Vector3.ZERO:
		handle_step_climb(move_dir, delta)

	move_and_slide()
	update_animation(move_dir, is_sprinting)

func handle_step_climb(dir: Vector3, delta: float) -> void:
	var h_vel: Vector3 = Vector3(velocity.x, 0, velocity.z)
	var forward_motion: Vector3 = dir * max(h_vel.length() * delta, 0.08)

	# 1. Check if an obstacle or stair riser is blocking the feet
	if test_move(global_transform, forward_motion):
		# 2. Check upward headroom so we don't phase into ceilings
		var up_transform: Transform3D = global_transform.translated(Vector3(0, MAX_STEP_HEIGHT, 0))
		if not test_move(up_transform, Vector3.ZERO):
			# 3. Check horizontal clearance on top of the step
			if not test_move(up_transform, forward_motion):
				global_position.y += MAX_STEP_HEIGHT
				apply_floor_snap()

func trigger_interact() -> void:
	if not anim_player or is_interacting:
		return
	
	if anim_player.has_animation("interact-right"):
		is_interacting = true
		anim_player.play("interact-right")

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "interact-right":
		is_interacting = false

func update_animation(dir: Vector3, is_sprinting: bool) -> void:
	if not anim_player or is_interacting:
		return

	if dir != Vector3.ZERO:
		if is_sprinting and anim_player.has_animation("sprint"):
			if anim_player.current_animation != "sprint":
				anim_player.play("sprint")
		elif anim_player.has_animation("walk"):
			if anim_player.current_animation != "walk":
				anim_player.play("walk")
	else:
		if anim_player.has_animation("idle") and anim_player.current_animation != "idle":
			anim_player.play("idle")
