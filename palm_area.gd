# PalmArea.gd
extends Area3D

@export var hand_follow_time: float = 0.12   # seconds to "catch up" to hand speed
@export var max_speed: float = 0.25          # strict planar speed cap (m/s)
@export var max_accel: float = 2.0           # planar accel cap (m/s^2)
@export var y_lock_when_push: bool = true    # force Y velocity to 0 while pushing
@export var up_axis: Vector3 = Vector3.UP

var _inside: Array[RigidBody3D] = []
var _last_pos: Vector3 = Vector3.ZERO
var _palm_vel: Vector3 = Vector3.ZERO

func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_last_pos = global_transform.origin

func _physics_process(delta: float) -> void:
	var pos: Vector3 = global_transform.origin
	_palm_vel = (pos - _last_pos) / max(delta, 0.0001)
	_last_pos = pos

	if Input.is_action_pressed("palm_push"):
		_apply_push(delta)

func _on_body_entered(body: Node) -> void:
	var rb: RigidBody3D = body as RigidBody3D
	if rb and _inside.find(rb) == -1:
		_inside.append(rb)

func _on_body_exited(body: Node) -> void:
	var rb: RigidBody3D = body as RigidBody3D
	if rb:
		_inside.erase(rb)

func _apply_push(delta: float) -> void:
	# Hand velocity flattened to table plane (XZ if up_axis is Y)
	var flat_hand_v: Vector3 = _palm_vel - _palm_vel.project(up_axis)
	if flat_hand_v.length() < 0.01:
		return

	# Desired planar speed, capped
	var v_des: Vector3 = flat_hand_v
	if v_des.length() > max_speed:
		v_des = v_des.normalized() * max_speed

	# Smooth catch-up factor (stable vs delta): alpha = 1 - e^(-dt/tau)
	var alpha: float = 1.0 - exp(-delta / max(hand_follow_time, 0.001))
	var max_dv: float = max_accel * delta

	for body in _inside:
		if not is_instance_valid(body):
			continue
		body.sleeping = false

		# Current planar velocity
		var v_planar: Vector3 = body.linear_velocity - body.linear_velocity.project(up_axis)

		# Move toward v_des with smoothing
		var dv: Vector3 = (v_des - v_planar) * alpha

		# Acceleration cap
		if dv.length() > max_dv:
			dv = dv.normalized() * max_dv

		var v_new: Vector3 = v_planar + dv

		# Speed cap (planar)
		if v_new.length() > max_speed:
			v_new = v_new.normalized() * max_speed

		# Compose final velocity with vertical component
		var vy: float = body.linear_velocity.y
		if y_lock_when_push:
			vy = 0.0  # enforce no vertical influence while pushing

		body.linear_velocity = v_new + up_axis * vy
