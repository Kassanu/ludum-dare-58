class_name CoinVariant
extends Resource

@export var id: StringName
@export var display_name: String = ""

@export var spawn_weight: float = 1.0

# Year constraints (any of these may be used)
@export var years_exact: PackedInt32Array = PackedInt32Array()
@export var years_ranges: Array[Vector2i] = []  # inclusive ranges (x=min, y=max)

# Faces
@export var faces_by_year: Dictionary = {}      # key:int year -> CoinFaces
@export var faces_default: CoinFaces            # used if no per-year faces

# Optional material overrides
@export var override_rim_color: bool = false
@export var rim_color_override: Color = Color.WHITE
@export var override_face_color: bool = false
@export var face_color_override: Color = Color.WHITE
@export var override_metallic: bool = false
@export var metallic_override: float = 0.9
@export var override_roughness: bool = false
@export var roughness_override: float = 0.35
@export var override_wear: bool = false
@export var wear_override: float = 0.35

func supports_year(y: int) -> bool:
	if years_exact.size() > 0:
		return years_exact.has(y)
	if years_ranges.size() > 0:
		for r in years_ranges:
			if y >= r.x and y <= r.y:
				return true
		return false
	return true
