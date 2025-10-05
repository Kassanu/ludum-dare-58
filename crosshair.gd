extends Control

@export var crosshair_size: int = 8      # arm length (px)
@export var gap: int = 4                 # gap at center (px)
@export var thickness: int = 2           # line thickness (px)
@export var color_default: Color = Color(1, 1, 1, 0.85)
@export var color_hover: Color = Color(1.0, 0.8, 0.2, 1.0)

# Nudge the crosshair on screen to line up with your raycast (pixels).
# Positive X → right, Positive Y → down (screen coords)
@export var offset_px: Vector2 = Vector2.ZERO

var _hovering := false

func _ready() -> void:
	# Make this control a centered square just big enough to draw in
	mouse_filter = MOUSE_FILTER_IGNORE

	# Center anchors
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5

	# Calculate an integer box size to avoid half-pixel blurring
	var box := int(crosshair_size + gap + thickness)
	# Size the control around the center
	offset_left = -box * 0.5
	offset_top = -box * 0.5
	offset_right = box * 0.5
	offset_bottom = box * 0.5

	# Ensure our pivot is the visual center
	pivot_offset = size * 0.5

	queue_redraw()

func set_hovering(flag: bool) -> void:
	if _hovering == flag:
		return
	_hovering = flag
	queue_redraw()

func _draw() -> void:
	var c := color_hover if _hovering else color_default
	var s := float(crosshair_size)
	var g := float(gap)
	var t := float(thickness)

	# Apply the editor-tunable screen offset for alignment
	# (This translates the local draw space by offset_px.)
	draw_set_transform(offset_px, 0.0, Vector2.ONE)

	# Use integer-ish coordinates to keep lines crisp
	var half_t : float = floor(t * 0.5)

	# left arm
	draw_rect(Rect2(Vector2(-(g + s), -half_t), Vector2(s, t)), c)
	# right arm
	draw_rect(Rect2(Vector2(g, -half_t), Vector2(s, t)), c)
	# top arm
	draw_rect(Rect2(Vector2(-half_t, -(g + s)), Vector2(t, s)), c)
	# bottom arm
	draw_rect(Rect2(Vector2(-half_t, g), Vector2(t, s)), c)
