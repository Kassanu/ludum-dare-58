extends CharacterBody3D

@export var speed := 5.0
@export var mouse_sens := 0.12
@onready var cam: Camera3D = $Camera3D

var _yaw := 0.0
var _pitch := 0.0
var gravity : float = ProjectSettings.get_setting("physics/3d/default_gravity")
var look_locked: bool = false

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func set_look_locked(flag: bool) -> void:
	look_locked = flag

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not look_locked:
		_yaw -= event.relative.x * mouse_sens * 0.01
		_pitch -= event.relative.y * mouse_sens * 0.01
		_pitch = clamp(_pitch, deg_to_rad(-85), deg_to_rad(85))
		rotation.y = _yaw
		cam.rotation.x = _pitch
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta: float) -> void:
	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)
	var wish := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	velocity.x = wish.x * speed
	velocity.z = wish.z * speed
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()
