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

const _AUTHORED_DIAMETER_M  := 0.026
const _AUTHORED_THICKNESS_M := 0.003

func _ready() -> void:
	continuous_cd = true
	collision_layer = 4
	collision_mask  = 1 | 4

	# Ensure no inherited scaling is flattening differences
	self.scale = Vector3.ONE
	mesh_inst.scale = Vector3.ONE

	# Make sure this coin has its own unique mesh/shape so per-coin sizing sticks
	_ensure_unique_resources()

	if data:
		_apply_data(data)

func configure_from_data(d: CoinData) -> void:
	data = d
	if is_inside_tree():
		_apply_data(d)

func _ensure_unique_resources() -> void:
	# Mesh
	if mesh_inst.mesh:
		var m := mesh_inst.mesh.duplicate()
		m.resource_local_to_scene = true
		mesh_inst.mesh = m
	else:
		# If nothing assigned, create a cylinder so we can size it
		var cyl := CylinderMesh.new()
		cyl.sides = 64
		mesh_inst.mesh = cyl

	# Shape
	if col.shape:
		var s := col.shape.duplicate()
		s.resource_local_to_scene = true
		col.shape = s
	else:
		var sh := CylinderShape3D.new()
		col.shape = sh

func _apply_data(d: CoinData) -> void:
	# ---------- Physics material ----------
	if physics_material_override == null:
		physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.85
	physics_material_override.bounce = 0.0

	# ---------- Mass / damping ----------
	mass = d.mass
	linear_damp = 0.35  # was 0.25
	angular_damp = 0.45 # was 0.30

	# ---------- Visual mesh sizing ----------
	var vis_mesh := mesh_inst.mesh
	if vis_mesh is CylinderMesh:
		var cyl := vis_mesh as CylinderMesh
		cyl.top_radius = d.visual_diameter_m * 0.5
		cyl.bottom_radius = d.visual_diameter_m * 0.5
		cyl.height = d.visual_thickness_m
		mesh_inst.mesh = cyl
		mesh_inst.scale = Vector3.ONE
	else:
		# Fallback scale if not a CylinderMesh
		var sx := d.visual_diameter_m  / _AUTHORED_DIAMETER_M
		var sz := d.visual_diameter_m  / _AUTHORED_DIAMETER_M
		var sy := d.visual_thickness_m / _AUTHORED_THICKNESS_M
		mesh_inst.scale = Vector3(sx, sy, sz)

	# ---------- Collider sizing ----------
	if col.shape is CylinderShape3D:
		var c := col.shape as CylinderShape3D
		var vis_radius := d.visual_diameter_m * 0.5
		var vis_height := d.visual_thickness_m

		# Minimum collision thickness (in meters) to keep the solver stable
		const MIN_COLLIDER_HEIGHT := 0.0025  # 2.5 mm feels good
		var target_height := d.collider_thickness_m if d.collider_thickness_m > 0.0 else vis_height
		c.radius = vis_radius
		c.height = max(target_height, MIN_COLLIDER_HEIGHT)
		col.shape = c
	else:
		push_warning("Coin collider is not CylinderShape3D; physics size may not match visuals.")

	# ---------- Material hookup ----------
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://coins/shaders/coin_faces_sdf.gdshader")
	mesh_inst.material_override = _mat

	# ---------- Face textures / material params ----------
	_mat.set_shader_parameter("top_tex", d.top_tex)
	_mat.set_shader_parameter("top_tex_enabled", d.top_tex != null)
	_mat.set_shader_parameter("bottom_tex", d.bottom_tex)
	_mat.set_shader_parameter("bottom_tex_enabled", d.bottom_tex != null)
	_mat.set_shader_parameter("rim_color", d.rim_color)
	_mat.set_shader_parameter("face_color", d.face_color)
	_mat.set_shader_parameter("metallic", d.metallic)
	_mat.set_shader_parameter("roughness", d.roughness)
	_mat.set_shader_parameter("wear", d.wear)

	var r: float = d.visual_diameter_m * 0.5
	_mat.set_shader_parameter("cap_center_top_os", Vector2(0.0, 0.0))
	_mat.set_shader_parameter("cap_center_bot_os", Vector2(0.0, 0.0))
	_mat.set_shader_parameter("cap_radius_top_os", r)
	_mat.set_shader_parameter("cap_radius_bot_os", r)

	_mat.set_shader_parameter("bottom_flip_u", false)
	_mat.set_shader_parameter("bottom_flip_v", false)

	# ---------- Year overlay (SDF) ----------
	var have_sdf := digits_sdf != null
	_mat.set_shader_parameter("overlay_enabled", have_sdf)
	if have_sdf:
		_mat.set_shader_parameter("digits_sdf", digits_sdf)
		_mat.set_shader_parameter("year_digits", _digits_of_year(d.year))

		_mat.set_shader_parameter("overlay_on_top", true)
		_mat.set_shader_parameter("overlay_on_bottom", false)
		_mat.set_shader_parameter("overlay_align_tangent", true)
		_mat.set_shader_parameter("overlay_follows_face_rotation", false)

		_mat.set_shader_parameter("overlay_radial_margin", 0.06)
		_mat.set_shader_parameter("overlay_color", Color(0.12, 0.12, 0.12))
		_mat.set_shader_parameter("digit_spacing", 0.08)
		_mat.set_shader_parameter("digits_softness", 0.10)

		_mat.set_shader_parameter("overlay_use_cap_space", true)
		_mat.set_shader_parameter("overlay_angle", deg_to_rad(270.0))
		_mat.set_shader_parameter("overlay_inset_norm", 0.10)

		_apply_overlay_by_type(d.type_id, _mat)

		_mat.set_shader_parameter("debug_face_circle", false)
		_mat.set_shader_parameter("debug_overlay_box", false)
		_mat.set_shader_parameter("debug_overlay_fill", false)

	#print("Coin ", d.type_name, " -> diameter=", d.visual_diameter_m, "m thickness=", d.visual_thickness_m, "m")

func _apply_overlay_by_type(type_id: CoinTypes.Type, mat: ShaderMaterial) -> void:
	var size := Vector2(0.34, 0.12)
	match type_id:
		CoinTypes.Type.DIME:        size = Vector2(0.22, 0.09)
		CoinTypes.Type.PENNY:       size = Vector2(0.24, 0.10)
		CoinTypes.Type.NICKEL:      size = Vector2(0.26, 0.10)
		CoinTypes.Type.QUARTER:     size = Vector2(0.28, 0.11)
		CoinTypes.Type.HALFDOLLAR:  size = Vector2(0.32, 0.12)
		CoinTypes.Type.DOLLAR:      size = Vector2(0.34, 0.12)
		_:                          size = Vector2(0.26, 0.10)
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

func on_dropped():
	is_held = false
	freeze = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	# Small upward nudge to avoid immediate deep intersections
	global_position.y += 0.002
	apply_central_impulse(Vector3.ZERO)

func coin_type_id() -> CoinTypes.Type:
	return self.data.type_id
