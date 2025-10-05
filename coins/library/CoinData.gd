class_name CoinData
extends Resource

@export var type_id: CoinTypes.Type
@export var type_name: String = ""
@export var variant_id: StringName
@export var variant_name: String = ""
@export var year: int = 2000
@export var value_points: int = 1
@export var is_special: bool = false

@export var visual_diameter_m: float = 0.026
@export var visual_thickness_m: float = 0.003
@export var collider_thickness_m: float = 0.006
@export var mass: float = 0.02

# Material resolved
@export var rim_color: Color = Color(0.82, 0.84, 0.86)
@export var face_color: Color = Color(0.82, 0.84, 0.86)
@export var metallic: float = 0.9
@export var roughness: float = 0.35
@export var wear: float = 0.35

# Faces resolved
@export var top_tex: Texture2D
@export var bottom_tex: Texture2D

func get_label() -> String:
	var vname := variant_name.strip_edges()
	var vtxt := " — %s" % vname if (vname != "" and vname != "regular") else ""
	return "%s%s (%d)" % [type_name, vtxt, year]
