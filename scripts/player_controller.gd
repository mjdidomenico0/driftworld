extends CharacterBody3D
## Player controller for Driftworld
## Handles: walk, run, sprint, crouch, jump, climb, glide

# Movement parameters
@export var walk_speed: float = 5.0
@export var run_speed: float = 8.0
@export var sprint_speed: float = 12.0
@export var crouch_speed: float = 2.5
@export var glide_speed: float = 3.0
@export var climb_speed: float = 4.0

# Stamina parameters
@export var max_stamina: float = 100.0
@export var stamina_drain_run: float = 5.0
@export var stamina_drain_jump: float = 10.0
@export var stamina_drain_climb: float = 8.0
@export var stamina_drain_glide: float = 2.0
@export var stamina_regen: float = 10.0

# Jump and physics
@export var jump_force: float = 8.0
@export var gravity: float = 20.0
@export var crouch_collision_height: float = 1.0
@export var normal_collision_height: float = 1.8

# Glide parameters
@export var glide_min_height: float = 3.0
@export var glide_stamina_threshold: float = 10.0

# climb
@export var climb_detection_range: float = 1.5
@export var wall_angle_threshold: float = 0.7

var stamina: float = max_stamina
var is_sprinting: bool = false
var is_crouching: bool = false
var is_climbing: bool = false
var is_gliding: bool = false
var is_on_wall: bool = false

# climb state
var climb_normal: Vector3 = Vector3.UP

# References
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh: Node3D = $Mesh

var mouse_sensitivity: float = 0.002

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	# Mouse look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_camera(-event.relative.x * mouse_sensitivity, -event.relative.y * mouse_sensitivity)

func rotate_camera(yaw: float, pitch: float) -> void:
	camera_pivot.rotate_y(yaw)
	camera_pivot.rotate_x(pitch)
	camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -PI/3, PI/3)

func _physics_process(delta: float) -> void:
	var input_dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_forward", "move_backward")
	)
	
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Crouch toggle
	if Input.is_action_just_pressed("crouch"):
		is_crouching = !is_crouching
		collision_shape.shape.size.y = crouch_collision_height if is_crouching else normal_collision_height
		collision_shape.position.y = crouch_collision_height / 2.0 if is_crouching else normal_collision_height / 2.0
	
	# Sprint hold
	is_sprinting = Input.is_action_pressed("sprint") and not is_crouching and stamina > 0.0
	
	# Determine current speed
	var current_speed := walk_speed
	if is_crouching:
		current_speed = crouch_speed
	elif is_sprinting and direction.length() > 0:
		current_speed = sprint_speed
	elif is_climbing:
		current_speed = climb_speed
	elif is_gliding:
		current_speed = glide_speed
	
	# Gliding check
	var should_glide := Input.is_action_pressed("glide") and not is_on_floor and not is_climbing
	var glider_has_stamina := stamina >= glide_stamina_threshold
	var above_min_height := global_position.y >= glide_min_height
	
	if should_glide and above_min_height and glider_has_stamina:
		if not is_gliding:
			is_gliding = true
			stamina -= stamina_drain_glide * delta
	else:
		is_gliding = false
	
	# climb detection
	is_on_wall = _check_wall_climb()
	if is_on_wall and Input.is_action_pressed("move_forward"):
		is_climbing = true
		direction = Vector3(0, 1, 0)  # Move up while climbing
		stamina -= stamina_drain_climb * delta
	
	if not is_on_wall or not Input.is_action_pressed("move_forward"):
		is_climbing = false
	
	# Apply gravity
	if not is_climbing:
		velocity.y -= gravity * delta
	
	# Movement
	if is_climbing:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		velocity.y = direction.y * current_speed if is_on_wall else 0.0
	elif is_gliding:
		# Slow horizontal + controlled fall
		var glide_dir := direction
		if glide_dir.length() == 0:
			glide_dir = Vector3.FORWARD
		velocity.x = glide_dir.x * current_speed
		velocity.z = glide_dir.z * current_speed
		velocity.y = -2.0  # Slow fall when gliding
	else:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	
	# Jumping
	if Input.is_action_just_pressed("jump") and is_on_floor and stamina >= stamina_drain_jump and not is_climbing:
		velocity.y = jump_force
		stamina -= stamina_drain_jump
	
	# Stamina regeneration
	if not is_sprinting and not is_climbing and not is_gliding:
		stamina = min(max_stamina, stamina + stamina_regen * delta)
	
	# Run stamina drain
	if is_sprinting:
		stamina -= stamina_drain_run * delta
		if stamina <= 0:
			stamina = 0
			is_sprinting = false
	
	move_and_slide()

func _check_wall_climb() -> bool:
	# Cast rays in cardinal directions to check for walls
	var directions := [
		transform.basis * Vector3.FORWARD,
		transform.basis * Vector3.BACK,
		transform.basis * Vector3.LEFT,
		transform.basis * Vector3.RIGHT
	]
	
	for dir in directions:
		var space_state := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(
			global_position,
			global_position + dir * climb_detection_range,
			0xFFFFFFFF
		)
		var result := space_state.intersect_ray(query)
		if result:
			var normal: Vector3 = result["normal"]
			# Check if wall is steep enough to climb
			if normal.y < wall_angle_threshold and normal.y >= 0:
				climb_normal = normal
				return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	# ESC to release mouse
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED