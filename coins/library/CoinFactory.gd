extends Node
class_name CoinFactory

@export var library: CoinLibrary
@export var coin_scene: PackedScene

@export var base_mass: float = 0.02
@export var base_diameter_m: float = 0.026
@export var base_thickness_m: float = 0.003

const SND_RARE := preload("res://sounds/rare_spawn.wav")

var _rng := RandomNumberGenerator.new()
var _rare_sfx_cooldown := false

func set_seed(seed: int) -> void:
	_rng.seed = seed

func sample_data() -> CoinData:
	assert(library and library.types.size() > 0)
	var t: CoinType = _pick_type()
	var v: CoinVariant = _pick_variant(t)
	var year: int = _pick_year(t, v)

	var faces := _resolve_faces(t, v, year)

	var data := CoinData.new()
	data.type_id = t.id
	data.type_name = t.display_name
	data.variant_id = v.id if v else StringName("regular")
	data.variant_name = v.display_name if v else "regular"
	data.year = year
	data.value_points = t.value_points
	data.is_special = v != null and v.id != StringName("regular")

	data.visual_diameter_m = t.visual_diameter_m
	data.visual_thickness_m = t.visual_thickness_m
	data.collider_thickness_m = t.collider_thickness_m

	data.rim_color = v.rim_color_override if (v and v.override_rim_color) else t.rim_color
	data.face_color = v.face_color_override if (v and v.override_face_color) else t.face_color
	data.metallic = v.metallic_override if (v and v.override_metallic) else t.metallic
	data.roughness = v.roughness_override if (v and v.override_roughness) else t.roughness
	var base_wear := t.wear_default
	if v and v.override_wear:
		base_wear = v.wear_override
	data.wear = clamp(base_wear + (_rng.randf() - 0.5) * 0.2, 0.0, 1.0)

	data.top_tex = faces.top
	data.bottom_tex = faces.bottom

	var vol_scale : float = (t.visual_diameter_m * t.visual_diameter_m * t.visual_thickness_m) / max(1e-6, base_diameter_m * base_diameter_m * base_thickness_m)
	data.mass = clamp(base_mass * vol_scale, 0.0015, 0.0200)

	return data

func instance_from_data(data: CoinData) -> RigidBody3D:
	assert(coin_scene)
	var node := coin_scene.instantiate() as RigidBody3D
	var body := node as Coin
	if body == null:
		if node.has_method("configure_from_data"):
			node.call("configure_from_data", data)
		else:
			push_error("coin_scene root must have configure_from_data(data: CoinData)")
	else:
		body.configure_from_data(data)

	# --- play subtle rare spawn sfx if variant isn't regular ---
	if data.is_special:
		_play_rare_spawn_sfx()

	return node

# --- Internals ---

func _play_rare_spawn_sfx() -> void:
	# Avoid spam when dumping many coins at once.
	if _rare_sfx_cooldown:
		return
	_rare_sfx_cooldown = true
	get_tree().create_timer(0.08).timeout.connect(func(): _rare_sfx_cooldown = false)

	var s := AudioStreamPlayer3D.new()
	s.stream = SND_RARE
	s.volume_db = -46.0
	s.pitch_scale = randf_range(0.98, 1.02)
	add_child(s)  # attach to factory so it plays immediately (even before coin is added to tree)
	s.play()
	s.connect("finished", Callable(s, "queue_free"))

func _pick_type() -> CoinType:
	var total := 0.0
	for t in library.types: total += max(t.type_weight, 0.0)
	var r := _rng.randf() * total
	for t in library.types:
		r -= max(t.type_weight, 0.0)
		if r <= 0.0: return t
	return library.types[0]

func _pick_variant(t: CoinType) -> CoinVariant:
	if t.variants.is_empty(): return null
	var total := 0.0
	for v in t.variants: total += max(v.spawn_weight, 0.0)
	var r := _rng.randf() * total
	for v in t.variants:
		r -= max(v.spawn_weight, 0.0)
		if r <= 0.0: return v
	return t.variants[0]

func _pick_year(t: CoinType, v: CoinVariant) -> int:
	var y0 := t.year_min
	var y1 := t.year_max
	if v:
		if v.years_exact.size() > 0:
			return v.years_exact[_rng.randi() % v.years_exact.size()]
		if v.years_ranges.size() > 0:
			var range := v.years_ranges[_rng.randi() % v.years_ranges.size()]
			return _rng.randi_range(range.x, range.y)
	return _rng.randi_range(y0, y1)

func _resolve_faces(t: CoinType, v: CoinVariant, year: int) -> CoinFaces:
	if v:
		if v.faces_by_year.has(year):
			return v.faces_by_year[year]
		if v.faces_default:
			return v.faces_default
	var f := CoinFaces.new()
	f.top = t.default_top
	f.bottom = t.default_bottom
	return f
