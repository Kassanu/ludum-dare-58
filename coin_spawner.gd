class_name CoinSpawner
extends Node3D

signal spawn_started(count: int)
signal finished()

@export var factory: CoinFactory           # drag your CoinFactory here
@export var coins_total: int = 60          # total coins to release this run
@export var coins_per_burst: int = 6       # how many come out at once
@export var burst_interval_s: float = 0.25 # time between bursts

# Where coins emerge relative to this node (think "bag mouth" position)
@export var local_spawn_offset: Vector3 = Vector3(0, 0.35, 0)

# Mouth radius controls how spread out the drops are around the mouth
@export var bag_mouth_radius_m: float = 0.08

# Try multiple random points per coin to avoid immediate overlaps at spawn
@export var tries_per_coin: int = 24

# Random orientation on spawn
@export_range(0.0, 90.0, 0.5) var tilt_max_degrees: float = 15.0  # random tip in X/Z
@export var randomize_yaw: bool = true

# Small “dumping” motion so coins don’t spawn perfectly still
@export var add_initial_motion: bool = true
@export var initial_down_speed_mps: Vector2 = Vector2(0.0, 0.7)  # min..max downward
@export var sideways_speed_mps: Vector2   = Vector2(0.0, 0.4)    # min..max sideways
@export var random_spin_radps: Vector3    = Vector3(6.0, 4.0, 6.0)

# Collisions to consider when checking the spawn mouth for overlaps.
# Example: World(1) | Coins(4) — adjust to your layers.
@export_flags_3d_physics var overlap_mask: int = (1 | 4)

# Auto-start in _ready()
@export var autostart: bool = true

var _active := false
var _remaining := 0

func _ready() -> void:
	if not factory:
		push_warning("Assign 'factory' on coin_spawner.gd")
		return
	if autostart:
		start()

# Public: start a dump with optional override
func start(total: int = -1) -> void:
	if total > 0:
		_remaining = total
	else:
		_remaining = coins_total
	_active = true
	emit_signal("spawn_started", _remaining)
	_spawn_loop()

# Public: cancel an in-progress dump
func cancel() -> void:
	_active = false

# ---------------- Internal ----------------

func _spawn_loop() -> void:
	# run as a coroutine
	await get_tree().process_frame
	while _active and _remaining > 0:
		var n : int = min(coins_per_burst, _remaining)
		_spawn_burst(n)
		_remaining -= n
		if _remaining <= 0:
			break
		if burst_interval_s > 0.0:
			await get_tree().create_timer(burst_interval_s).timeout
	# done
	_active = false
	emit_signal("finished")

func _spawn_burst(n: int) -> void:
	var space := get_world_3d().direct_space_state
	for i in n:
		var data := factory.sample_data()

		# build a per-coin query cylinder roughly matching its collider
		var qshape := CylinderShape3D.new()
		qshape.radius = data.visual_diameter_m * 0.5 * 1.02
		qshape.height = data.collider_thickness_m * 1.05

		var ok := false
		var chosen := Transform3D()
		for t in tries_per_coin:
			var xz := _rand_in_disc(bag_mouth_radius_m)
			var spawn_origin := (global_transform * Transform3D(Basis(), local_spawn_offset)).origin
			var pos := spawn_origin + Vector3(xz.x, 0.0, xz.y)

			# random orientation (tip a bit so they don't all fall flat)
			var basis := Basis()
			if randomize_yaw:
				basis = basis.rotated(Vector3.UP, randf() * TAU)
			var tilt_x := deg_to_rad(randf_range(-tilt_max_degrees, tilt_max_degrees))
			var tilt_z := deg_to_rad(randf_range(-tilt_max_degrees, tilt_max_degrees))
			basis = basis.rotated(Vector3.RIGHT, tilt_x)
			basis = basis.rotated(Vector3.FORWARD, tilt_z)

			var xf := Transform3D(basis, pos)

			var qp := PhysicsShapeQueryParameters3D.new()
			qp.shape = qshape
			qp.transform = xf
			qp.collision_mask = overlap_mask
			qp.collide_with_bodies = true
			qp.collide_with_areas = false

			var hits := space.intersect_shape(qp, 16)
			if hits.is_empty():
				chosen = xf
				ok = true
				break
		if not ok:
			# last resort: still spawn, but slightly above mouth to avoid tunneling
			var up := Vector3.UP * (data.collider_thickness_m * 0.5 + 0.01)
			chosen.origin = (global_transform * Transform3D(Basis(), local_spawn_offset)).origin + up

		var coin := factory.instance_from_data(data)
		add_child(coin)

		# place and wake
		coin.global_transform = chosen
		coin.sleeping = false

		# small initial push (down + a little sideways) to sell the "dump"
		if add_initial_motion:
			var down_speed := randf_range(initial_down_speed_mps.x, initial_down_speed_mps.y)
			var side_speed := randf_range(sideways_speed_mps.x, sideways_speed_mps.y)
			# sideways direction = from center toward chosen point (or random if identical)
			var mouth_center := (global_transform * Transform3D(Basis(), local_spawn_offset)).origin
			var dir := (chosen.origin - mouth_center).normalized()
			if dir.length() < 0.2:
				# if nearly centered, pick a random lateral direction
				var v := _rand_in_disc(1.0)
				dir = Vector3(v.x, 0.0, v.y).normalized()
			coin.linear_velocity = dir * side_speed + Vector3.DOWN * down_speed
			coin.angular_velocity = Vector3(
				randf_range(-random_spin_radps.x, random_spin_radps.x),
				randf_range(-random_spin_radps.y, random_spin_radps.y),
				randf_range(-random_spin_radps.z, random_spin_radps.z)
			)

func _rand_in_disc(r: float) -> Vector2:
	# uniform disc sampling
	var a := randf() * TAU
	var s := sqrt(randf()) * r
	return Vector2(cos(a), sin(a)) * s
