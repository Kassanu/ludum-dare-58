extends Control

@onready var dim: ColorRect = $Dim if has_node("Dim") else null
@onready var message: Label = $Message

var _tween: Tween

func _ready() -> void:
    # Make sure clicks pass through (for safety if edited later)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    if dim:
        dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if message:
        message.mouse_filter = Control.MOUSE_FILTER_IGNORE

    # React to capture state
    MouseCapture.capture_state_changed.connect(_on_capture_changed)
    _on_capture_changed(MouseCapture.is_captured())

func _on_capture_changed(captured: bool) -> void:
    var target_visible := not captured
    if target_visible and not visible:
        visible = true
        modulate.a = 0.0
    if _tween and _tween.is_running():
        _tween.kill()

    _tween = create_tween()
    _tween.tween_property(self, "modulate:a", 1.0 if target_visible else 0.0, 0.18)
    _tween.finished.connect(func():
        if not target_visible:
            visible = false)
