extends StaticBody3D
class_name CoinBag

@export var spawner_path: NodePath
@export var coins_to_dump: int = -1        # -1 = let spawner use its default
@export var cooldown_sec: float = 2.0
@export var group_name: StringName = &"coin_bag"

var _spawner: CoinSpawner
var _cooling_down := false
var _cooldown_timer: Timer

func _ready() -> void:
	if not is_in_group(group_name):
		add_to_group(group_name)

	if spawner_path != NodePath():
		_spawner = get_node_or_null(spawner_path) as CoinSpawner

	# Optional: this lets the bag auto-reset after the spawner finishes (even if cooldown is 0)
	if _spawner and not _spawner.is_connected("finished", Callable(self, "_on_spawn_finished")):
		_spawner.finished.connect(_on_spawn_finished)

	_cooldown_timer = Timer.new()
	_cooldown_timer.one_shot = true
	add_child(_cooldown_timer)
	_cooldown_timer.timeout.connect(func():
		_cooling_down = false
		_set_bag_visual_ready(true))

	_set_bag_visual_ready(true)

func try_dump() -> bool:
	# Returns true if we actually triggered a dump
	if _cooling_down:
		return false
	if not _spawner:
		push_warning("CoinBag: spawner_path is not set or not found.")
		return false

	_spawner.start(coins_to_dump)
	_begin_cooldown()
	return true

func _begin_cooldown() -> void:
	_cooling_down = true
	_set_bag_visual_ready(false)
	if cooldown_sec > 0.0:
		_cooldown_timer.start(cooldown_sec)
	else:
		# immediate ready if no cooldown desired
		_cooling_down = false
		_set_bag_visual_ready(true)

func _on_spawn_finished() -> void:
	# Optional: hook if you’d like to react when spawner is done
	pass

# --- Simple visual feedback helpers (optional) ---
func _set_bag_visual_ready(ready: bool) -> void:
	var mesh := _get_mesh_node()
	if not (mesh and mesh is MeshInstance3D):
		return

	var target_alpha := 1.0 if ready else 0.6
	var brightness   := 1.0 if ready else 0.75  # slight dim to make it obvious

	# If there's a material_override, prefer that single override.
	if mesh.material_override:
		var mat : Material = mesh.material_override
		mesh.material_override = _tint_std_material(mat, target_alpha, brightness)
		return

	# Otherwise, override each surface so ALL parts change.
	if not mesh.mesh:
		return
	var sc : int = mesh.mesh.get_surface_count()
	for i in sc:
		var surf_mat : Material = mesh.mesh.surface_get_material(i)
		var tinted := _tint_std_material(surf_mat, target_alpha, brightness)
		# Assign as a per-surface override on the instance:
		mesh.set_surface_override_material(i, tinted)

func _tint_std_material(mat: Material, alpha: float, brightness: float) -> Material:
	var out_mat: Material
	if mat is StandardMaterial3D:
		out_mat = (mat as StandardMaterial3D).duplicate()
		var m := out_mat as StandardMaterial3D
		# Ensure transparency is actually used
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		# Optional: keep depth sorting sane for transparent objects
		# m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALPHA_PREPASS

		# Tweak color & alpha
		var c := m.albedo_color
		c = Color(c.r * brightness, c.g * brightness, c.b * brightness, alpha)
		m.albedo_color = c

		# (Optional) gentle emission ping so it reads clearly
		# m.emission_enabled = alpha < 1.0
		# m.emission = Color(0.8, 0.8, 0.8)
		# m.emission_energy = alpha < 1.0 ? 0.2 : 0.0

		return m
	elif mat is ShaderMaterial:
		out_mat = (mat as ShaderMaterial).duplicate()
		var sm := out_mat as ShaderMaterial
		# Expect a 'tint_a' uniform in your shader if you want alpha control
		if sm.shader and sm.shader.has_param("tint_a"):
			sm.set_shader_parameter("tint_a", alpha)
		return sm
	else:
		# Fallback: create a simple StandardMaterial3D from scratch
		var m2 := StandardMaterial3D.new()
		m2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m2.albedo_color = Color(brightness, brightness, brightness, alpha)
		return m2

func _get_mesh_node() -> Node:
	# Return first MeshInstance3D child (adjust if your hierarchy differs)
	for c in get_children():
		if c is MeshInstance3D:
			return c
	return null
