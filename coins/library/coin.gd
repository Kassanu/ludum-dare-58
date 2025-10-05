class_name Coin
extends RigidBody3D

@export var data: CoinData
@export var digits_sdf: Texture2D
@export var coin_type: CoinTypes.Type = CoinTypes.Type.PENNY
@export var unique_id: StringName = &"" # for rare/specific coins (e.g., "CA-2001-broadstrike")

@onready var mesh_inst: MeshInstance3D = $MeshInstance3D
@onready var col: CollisionShape3D = $CollisionShape3D

var _mat: ShaderMaterial
var is_held := false

func _ready() -> void:
	continuous_cd = true
	collision_layer = 4                    # Layer 3 (value 4) = Coins
	collision_mask  = 1 | 4               # World + Coins

	if data:
		_apply_data(data)

func configure_from_data(d: CoinData) -> void:
	data = d
	if is_inside_tree():
		_apply_data(d)

func _apply_data(d: CoinData) -> void:
	# Physics material
	if physics_material_override == null:
		physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.85
	physics_material_override.bounce = 0.0

	# Mass / damping
	mass = d.mass
	linear_damp = 0.25
	angular_damp = 0.30

	# Build mesh and collider
	var r: float = d.visual_diameter_m * 0.5
	# (cyl, shape, etc.) unchanged…

	# Material hookup
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://coins/shaders/coin_faces_sdf.gdshader")
	mesh_inst.material_override = _mat

	# Face textures / material params
	_mat.set_shader_parameter("top_tex", d.top_tex)
	_mat.set_shader_parameter("top_tex_enabled", d.top_tex != null)
	_mat.set_shader_parameter("bottom_tex", d.bottom_tex)
	_mat.set_shader_parameter("bottom_tex_enabled", d.bottom_tex != null)
	_mat.set_shader_parameter("rim_color", d.rim_color)
	_mat.set_shader_parameter("face_color", d.face_color)
	_mat.set_shader_parameter("metallic", d.metallic)
	_mat.set_shader_parameter("roughness", d.roughness)
	_mat.set_shader_parameter("wear", d.wear)

	_mat.set_shader_parameter("cap_center_top_os", Vector2(0.0, 0.0))
	_mat.set_shader_parameter("cap_center_bot_os", Vector2(0.0, 0.0))
	_mat.set_shader_parameter("cap_radius_top_os", r)
	_mat.set_shader_parameter("cap_radius_bot_os", r)

	# Optional: if bottom art is mirrored, toggle these:
	_mat.set_shader_parameter("bottom_flip_u", false)
	_mat.set_shader_parameter("bottom_flip_v", false)

	# Year overlay (SDF)
	var have_sdf := digits_sdf != null
	_mat.set_shader_parameter("overlay_enabled", have_sdf)
	if have_sdf:
		_mat.set_shader_parameter("digits_sdf", digits_sdf)
		_mat.set_shader_parameter("year_digits", _digits_of_year(d.year))

		_mat.set_shader_parameter("overlay_on_top", true)
		_mat.set_shader_parameter("overlay_on_bottom", false)
		_mat.set_shader_parameter("overlay_align_tangent", true)

		# Keep upright (since we spin the rigidbody, not the face)
		_mat.set_shader_parameter("overlay_follows_face_rotation", false)

		_mat.set_shader_parameter("overlay_radial_margin", 0.06)
		_mat.set_shader_parameter("overlay_color", Color(0.12, 0.12, 0.12))
		_mat.set_shader_parameter("digit_spacing", 0.08)
		_mat.set_shader_parameter("digits_softness", 0.10)

		# --- NEW geometry-driven overlay controls ---
		_mat.set_shader_parameter("overlay_use_cap_space", true)

		# Angle around the rim (0° = +X, 90° = +Z, 180° = −X, 270° = −Z)
		# For “bottom” placement like a date on a coin, 270° is typical.
		_mat.set_shader_parameter("overlay_angle", deg_to_rad(270.0))

		# How far inward from the rim (0.0 = edge, 1.0 = center)
		_mat.set_shader_parameter("overlay_inset_norm", 0.10)

		_apply_overlay_by_type(d.type_id, _mat)

		# DEBUG (optional, only while tuning overlay)
		_mat.set_shader_parameter("debug_face_circle", false)
		_mat.set_shader_parameter("debug_overlay_box", false)
		_mat.set_shader_parameter("debug_overlay_fill", false)

func _apply_overlay_by_type(type_id: CoinTypes.Type, mat: ShaderMaterial) -> void:
	var size := Vector2(0.34, 0.12)
	match type_id:
		CoinTypes.Type.DIME:    size = Vector2(0.22, 0.09)
		CoinTypes.Type.PENNY:   size = Vector2(0.24, 0.10)
		CoinTypes.Type.NICKEL:  size = Vector2(0.26, 0.10)
		CoinTypes.Type.QUARTER: size = Vector2(0.28, 0.11)
		CoinTypes.Type.HALFDOLLAR:    size = Vector2(0.32, 0.12)
		CoinTypes.Type.DOLLAR:  size = Vector2(0.34, 0.12)
		_:         size = Vector2(0.26, 0.10)

	mat.set_shader_parameter("overlay_size_uv", size)

func _digits_of_year(y: int) -> Vector4:
	var a := (y / 1000) % 10
	var b := (y / 100)  % 10
	var c := (y / 10)   % 10
	var d := y % 10
	return Vector4(a, b, c, d)

func on_picked_up():
	is_held = true
	freeze = true
	sleeping = true
	# mode = RigidBody3D.MODE_STATIC

func on_dropped():
	is_held = false
	freeze = false
	# mode = RigidBody3D.MODE_RIGID
	apply_central_impulse(Vector3.ZERO)

func coin_type_id() -> CoinTypes.Type:
	return self.data.type_id
