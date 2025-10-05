extends Control

@export var crosshair_size: int = 8          # arm length (px)
@export var gap: int = 4           # gap at center (px)
@export var thickness: int = 2     # line thickness (px)

@export var color_default: Color = Color(1, 1, 1, 0.85)
@export var color_hover: Color = Color(1.0, 0.8, 0.2, 1.0)

var _hovering: bool = false

func _ready() -> void:
	# Center the control and make it just big enough for drawing
	mouse_filter = MOUSE_FILTER_IGNORE
	anchor_left = 0.5; anchor_top = 0.5; anchor_right = 0.5; anchor_bottom = 0.5
	offset_left = - (crosshair_size + gap + thickness) / 2.0
	offset_right =  (crosshair_size + gap + thickness) / 2.0
	offset_top =   - (crosshair_size + gap + thickness) / 2.0
	offset_bottom =  (crosshair_size + gap + thickness) / 2.0

func set_hovering(flag: bool) -> void:
	if _hovering == flag: return
	_hovering = flag
	queue_redraw()

func _draw() -> void:
	var c := color_hover if _hovering else color_default
	var s := float(crosshair_size)
	var g := float(gap)
	var t := float(thickness)

	# left arm
	draw_rect(Rect2(Vector2(-(g+s), -t*0.5), Vector2(s, t)), c)
	# right arm
	draw_rect(Rect2(Vector2(g, -t*0.5), Vector2(s, t)), c)
	# top arm
	draw_rect(Rect2(Vector2(-t*0.5, -(g+s)), Vector2(t, s)), c)
	# bottom arm
	draw_rect(Rect2(Vector2(-t*0.5, g), Vector2(t, s)), c)
