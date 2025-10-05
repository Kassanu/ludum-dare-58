extends CharacterBody3D

@export var speed := 5.0
@export var mouse_sens := 0.12
@onready var cam: Camera3D = $Camera3D

var _yaw := 0.0
var _pitch := 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var look_locked: bool = false

func _ready() -> void:
    pass

func set_look_locked(flag: bool) -> void:
    look_locked = flag

func _input(event: InputEvent) -> void:
    # Only process mouse look when pointer is captured and not explicitly locked.
    if not MouseCapture.is_captured() or look_locked:
        return

    if event is InputEventMouseMotion:
        _yaw -= event.relative.x * mouse_sens * 0.01
        _pitch -= event.relative.y * mouse_sens * 0.01
        _pitch = clamp(_pitch, deg_to_rad(-85), deg_to_rad(85))
        rotation.y = _yaw
        cam.rotation.x = _pitch

func _physics_process(delta: float) -> void:
    # If mouse isn't captured, ignore WASD (freeze horizontal movement).
    if not MouseCapture.is_captured() or look_locked:
        velocity.x = 0.0
        velocity.z = 0.0
        # Still apply gravity so you fall naturally if needed:
        if not is_on_floor():
            velocity.y -= gravity * delta
        else:
            velocity.y = 0.0
        move_and_slide()
        return

    # --- Normal movement when captured ---
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
