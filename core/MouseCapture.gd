# res://core/MouseCapture.gd
extends Node

signal capture_state_changed(captured: bool)

var _want_capture := true
var _last_mode := Input.MOUSE_MODE_VISIBLE
var _just_captured := false
var _grace_time := 0.0
const _GRACE_DURATION := 0.06  # ~60 ms; tweak if needed

func _ready() -> void:
    release()
    _last_mode = Input.get_mouse_mode()

func is_captured() -> bool:
    return Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED

func is_in_post_capture_grace() -> bool:
    return _just_captured

func capture() -> void:
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    _want_capture = false
    _just_captured = true
    _grace_time = 0.0
    emit_signal("capture_state_changed", true)

func release() -> void:
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    _want_capture = true
    _just_captured = false
    _grace_time = 0.0
    emit_signal("capture_state_changed", false)

func _process(_dt: float) -> void:
    # Detect pointer-lock changes that happened *outside* our code (e.g., browser Esc).
    var cur := Input.get_mouse_mode()
    if cur != _last_mode:
        if cur != Input.MOUSE_MODE_CAPTURED:
            # We lost capture externally → arm for recapture and show overlay.
            _want_capture = true
            emit_signal("capture_state_changed", false)
        _last_mode = cur

    if _just_captured:
        _grace_time += _dt
        if _grace_time >= _GRACE_DURATION:
            _just_captured = false

func _input(event: InputEvent) -> void:
    # Release if we *do* see Esc/F1 (desktop/editor; sometimes web).
    if event.is_action_pressed(&"mouse_capture_toggle"):
        release()
        return

    # Recapture on any mouse click when armed (user gesture → required on Web).
    if _want_capture and event is InputEventMouseButton and event.pressed:
        capture()
        return
