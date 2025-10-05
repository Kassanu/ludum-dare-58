extends Node3D

@export var factory: CoinFactory                # NEW: drag your CoinFactory node here
@export var table_body: StaticBody3D
@export var count: int = 30
@export var tries_per_coin: int = 40
@export var edge_margin_m: float = 0.05
@export var lift_above_table_m: float = 0.003

# Overlap mask: World (1) + Coins (4)
@export_flags_3d_physics var overlap_mask: int = (1 | 4)

func _ready() -> void:
	if not factory or not table_body:
		push_warning("Assign factory and table_body."); return

	var col := table_body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not col or not (col.shape is BoxShape3D):
		push_warning("Table needs a BoxShape3D CollisionShape3D."); return

	var half: Vector3 = (col.shape as BoxShape3D).size * 0.5
	var table_top_y: float = table_body.global_transform.origin.y + half.y

	var space := get_world_3d().direct_space_state
	var placed: Array[RigidBody3D] = []

	for i in count:
		# 1) Randomize a coin (type/variant/year + sizes/material already resolved)
		var data := factory.sample_data()

		# 2) Build a per-coin query shape (tiny safety pad)
		var qshape := CylinderShape3D.new()
		qshape.radius = data.visual_diameter_m * 0.5 * 1.02
		qshape.height = data.collider_thickness_m * 1.02

		# 3) Find a free spot on the table
		var ok := false
		var pos_world := Vector3.ZERO

		for t in tries_per_coin:
			var x := randf_range(-half.x + edge_margin_m, half.x - edge_margin_m)
			var z := randf_range(-half.z + edge_margin_m, half.z - edge_margin_m)

			var local := Vector3(x, lift_above_table_m + data.collider_thickness_m * 0.5, z)
			var candidate := table_body.global_transform * local
			candidate.y = table_top_y + lift_above_table_m + data.collider_thickness_m * 0.5

			var qp := PhysicsShapeQueryParameters3D.new()
			qp.shape = qshape
			qp.transform = Transform3D(Basis(), candidate)
			qp.collision_mask = overlap_mask
			qp.collide_with_bodies = true
			qp.collide_with_areas = false

			var hits := space.intersect_shape(qp, 16)
			if hits.is_empty():
				pos_world = candidate
				ok = true
				break
		if not ok:
			# last resort: place slightly higher in the middle
			pos_world = Vector3(
				table_body.global_transform.origin.x,
				table_top_y + lift_above_table_m + data.collider_thickness_m * 0.5 + 0.01,
				table_body.global_transform.origin.z
			)

		# 4) Instance the configured coin and place it
		var coin := factory.instance_from_data(data)
		add_child(coin)
		coin.global_transform.origin = pos_world
		coin.linear_velocity = Vector3.ZERO
		coin.angular_velocity = Vector3.ZERO
		coin.sleeping = true
		placed.append(coin)

	# 5) Gentle wake so rims tip instead of exploding
	for c in placed:
		if not is_instance_valid(c): continue
		c.sleeping = false
		c.apply_impulse(Vector3(randf_range(-0.01, 0.01), 0.0, randf_range(-0.01, 0.01)))
		c.apply_torque_impulse(Vector3(
			randf_range(-0.002, 0.002),
			randf_range(-0.001, 0.001),
			randf_range(-0.002, 0.002)
		))
