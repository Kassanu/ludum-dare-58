# PalmPushController.gd
extends Camera3D

@export var table_ray: RayCast3D
@export_flags_3d_physics var props_mask: int = 1

# Palm shape & response
@export var radius: float = 0.24           # palm footprint (m)
@export var sigma_forward: float = 0.12    # falloff along push
@export var sigma_side: float = 0.20       # falloff sideways
@export var follow_time: float = 0.09      # seconds to approach target speed
@export var max_speed: float = 0.35        # cap (m/s), per coin
@export var up_axis: Vector3 = Vector3.UP

# Perception / gain (scales world delta so it feels responsive)
@export var hand_speed_gain: float = 4.0   # multiply computed hand speed
@export var smooth_time: float = 0.06      # smoothing for hand velocity (s)

var _last_hit_ok: bool = false
var _last_hit: Vector3 = Vector3.ZERO
var _hand_v: Vector3 = Vector3.ZERO  # planar, smoothed

func _physics_process(delta: float) -> void:
	if not table_ray:
		return

	table_ray.force_raycast_update()
	if not table_ray.is_colliding():
		_last_hit_ok = false
		return

	var hit: Vector3 = table_ray.get_collision_point()
	var raw_v: Vector3 = (hit - (_last_hit if _last_hit_ok else hit)) / max(delta, 0.0001)
	var flat_raw: Vector3 = raw_v - raw_v.project(up_axis)

	# Gain + smoothing
	var target_v: Vector3 = flat_raw * hand_speed_gain
	var alpha: float = 1.0 - exp(-delta / max(smooth_time, 0.001))
	_hand_v = _hand_v.lerp(target_v, alpha)

	_last_hit = hit
	_last_hit_ok = true

	if Input.is_action_pressed("palm_push"):
		_apply_push(hit, delta)

func _apply_push(hit: Vector3, delta: float) -> void:
	# Desired planar hand velocity (capped)
	var v_des: Vector3 = _hand_v
	if v_des.is_zero_approx():
		return
	var v_mag: float = v_des.length()
	if v_mag > max_speed:
		v_des = v_des * (max_speed / v_mag)

	# Build a small overlap query around the hit point
	var space := get_world_3d().direct_space_state
	var shp := SphereShape3D.new()
	shp.radius = radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shp
	q.transform = Transform3D(Basis(), hit + up_axis * 0.01)
	q.collision_mask = props_mask
	q.collide_with_bodies = true
	q.collide_with_areas = false

	var results := space.intersect_shape(q, 64)
	if results.is_empty():
		return

	# Orthonormal planar frame (u = push dir, v = sideways)
	var u: Vector3 = (v_des - v_des.project(up_axis)).normalized()
	var v: Vector3 = up_axis.cross(u).normalized()

	# Time-invariant blend toward target speed
	var blend: float = 1.0 - exp(-delta / max(follow_time, 0.001))

	for item in results:
		var body := item.get("collider") as RigidBody3D
		if body == null or not is_instance_valid(body):
			continue
		body.sleeping = false

		# Planar displacement from hit to coin
		var cpos: Vector3 = body.global_transform.origin
		var r_vec: Vector3 = cpos - hit
		var r_planar: Vector3 = r_vec - r_vec.project(up_axis)

		# Decompose into forward/side components
		var along: float = r_planar.dot(u)   # >0 = in front of push
		var side:  float = r_planar.dot(v)

		# Only push coins ahead of the motion; behind gets near-zero influence
		if along <= 0.0:
			continue

		# Anisotropic Gaussian: tighter along push, wider sideways
		var w_forward: float = exp(-0.5 * (along * along) / max(sigma_forward * sigma_forward, 1e-6))
		var w_side:    float = exp(-0.5 * (side  * side)  / max(sigma_side    * sigma_side,    1e-6))
		var w: float = w_forward * w_side     # 1 at palm center, decays ahead/side

		if w < 0.02:
			continue  # negligible

		# Current planar velocity and incremental Δv toward v_des
		var v_planar: Vector3 = body.linear_velocity - body.linear_velocity.project(up_axis)
		var dv: Vector3 = (v_des - v_planar) * (blend * w)

		# Apply as impulse so it wakes and feels responsive
		var J: Vector3 = dv * body.mass
		body.apply_impulse(J)

		# Strict planar speed cap (belt-and-suspenders)
		var p: Vector3 = body.linear_velocity - body.linear_velocity.project(up_axis)
		var vy: float = body.linear_velocity.dot(up_axis)
		var p_len: float = p.length()
		if p_len > max_speed:
			p = p * (max_speed / p_len)
		body.linear_velocity = p + up_axis * vy
