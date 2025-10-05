class_name CoinType
extends Resource

@export var id: CoinTypes.Type
@export var display_name: String = ""

# Visual (mesh) size
@export var visual_diameter_m: float = 0.026
@export var visual_thickness_m: float = 0.003

# Physics (collider) thickness (keep 0.006–0.008 for stability with Jolt)
@export var collider_thickness_m: float = 0.006

# Gameplay value
@export var value_points: int = 1

# Year range for this type
@export var year_min: int = 1990
@export var year_max: int = 2025

# Material defaults
@export var rim_color: Color = Color(0.82, 0.84, 0.86)
@export var metallic: float = 0.9
@export var roughness: float = 0.38
@export var wear_default: float = 0.35  # 0..1, you can randomize around this

# Fallback faces (used if a variant/year doesn’t provide)
@export var default_top: Texture2D
@export var default_bottom: Texture2D

# Authoring weights (for now simple/even; kept for future tuning)
@export var type_weight: float = 1.0

@export var variants: Array[CoinVariant] = []
