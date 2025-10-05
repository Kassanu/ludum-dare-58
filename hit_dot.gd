extends MeshInstance3D

@onready var ray: RayCast3D = $"../TableRay"
@onready var dot: MeshInstance3D = $"../HitDot"

func _physics_process(_dt: float) -> void:
	ray.force_raycast_update()
	if ray.is_colliding():
		var p: Vector3 = ray.get_collision_point()
		var n: Vector3 = ray.get_collision_normal()
		# orient the dot to the surface
		var x := n.cross(Vector3.FORWARD).normalized()
		if x.length() < 0.001:
			x = n.cross(Vector3.RIGHT).normalized()
		var z := x.cross(n).normalized()
		dot.global_transform = Transform3D(Basis(x, n, z), p + n * 0.001)
		dot.visible = true
	else:
		dot.visible = false
