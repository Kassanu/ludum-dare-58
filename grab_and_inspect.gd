extends Camera3D

@export var camera: Camera3D
@export var ray: RayCast3D
@export var crosshair: Control             # optional
@export var player_node: Node              # drag your Player node here

@export var deposit_ray: RayCast3D
@export var deposit_debug: bool = false

@export var hold_distance: float = 0.45
@export var min_hold_distance: float = 0.15
@export var max_hold_distance: float = 0.90

@export var pos_lerp: float = 0.35
@export var rotate_sens: float = 0.0018
@export var rotate_smooth_time: float = 0.08
@export var only_group: StringName = &"coin"

var grabbed: RigidBody3D = null
var _prev_freeze_mode: int = 0
var _prev_frozen: bool = false
var _rotating: bool = false

var hovered: RigidBody3D = null
var _hover_mat: StandardMaterial3D = null

var _desired_basis: Basis = Basis.IDENTITY

func _ready() -> void:
	if camera:
		camera.near = 0.02
	if ray:
		ray.enabled = true
	if deposit_ray:
		deposit_ray.enabled = true

	_hover_mat = StandardMaterial3D.new()
	_hover_mat.emission_enabled = true
	_hover_mat.emission = Color(1.0, 0.8, 0.2, 1.0)
	_hover_mat.emission_energy_multiplier = 1.0

func _unhandled_input(event: InputEvent) -> void:
	# LMB: grab OR (when holding) deposit-or-drop
	if event.is_action_pressed("grab"):
		if grabbed == null:
			_try_grab()
		else:
			# first: try to deposit into a bank we're aiming at
			if not _try_deposit_held():
				# if no bank / rejected, fall back to dropping
				_drop()

	# explicit drop key (if you have one)
	if event.is_action_pressed("drop"):
		_drop()

	# Wheel distance while holding
	if event is InputEventMouseButton and event.pressed and grabbed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			hold_distance = clamp(hold_distance - 0.05, min_hold_distance, max_hold_distance)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			hold_distance = clamp(hold_distance + 0.05, min_hold_distance, max_hold_distance)

	# RMB rotate on/off
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed and grabbed:
			_rotating = true
			_set_look_lock(true)
		else:
			_rotating = false
			_set_look_lock(false)

	# Named rotate action (optional)
	if event.is_action_pressed("inspect_rotate") and grabbed:
		_rotating = true
		_set_look_lock(true)
	if event.is_action_released("inspect_rotate"):
		_rotating = false
		_set_look_lock(false)

	# Accumulate desired rotation (apply smoothly later)
	if event is InputEventMouseMotion and grabbed and _rotating:
		var yaw: float = -event.relative.x * rotate_sens
		var pitch: float = -event.relative.y * rotate_sens
		var up_axis: Vector3 = camera.global_transform.basis.y
		var right_axis: Vector3 = camera.global_transform.basis.x
		_desired_basis = (Basis(up_axis, yaw) * Basis(right_axis, pitch) * _desired_basis).orthonormalized()

func _physics_process(dt: float) -> void:
	_update_hover()

	if grabbed:
		# Smooth position
		var target_pos: Vector3 = camera.global_transform.origin - camera.global_transform.basis.z * hold_distance
		var gt: Transform3D = grabbed.global_transform
		gt.origin = gt.origin.lerp(target_pos, pos_lerp)
		# Smooth rotation
		var q_from: Quaternion = gt.basis.get_rotation_quaternion()
		var q_to:   Quaternion = _desired_basis.get_rotation_quaternion()
		var t: float = 1.0 - exp(-dt / max(rotate_smooth_time, 0.001))
		var q_smooth: Quaternion = q_from.slerp(q_to, t)
		gt.basis = Basis(q_smooth).orthonormalized()
		grabbed.global_transform = gt

func _update_hover() -> void:
	if grabbed or not ray:
		_set_hover(null); return

	ray.force_raycast_update()
	if not ray.is_colliding():
		_set_hover(null); return

	var rb := ray.get_collider() as RigidBody3D
	if rb == null or (String(only_group) != "" and not rb.is_in_group(only_group)):
		_set_hover(null); return

	_set_hover(rb)

func _set_hover(rb: RigidBody3D) -> void:
	if hovered == rb: return

	if hovered and is_instance_valid(hovered):
		var m := _get_mesh(hovered); if m: m.material_overlay = null
	hovered = rb
	if hovered:
		var m2 := _get_mesh(hovered); if m2: m2.material_overlay = _hover_mat
	if crosshair and crosshair.has_method("set_hovering"):
		crosshair.call("set_hovering", hovered != null)

func _try_grab() -> void:
	if not ray: return
	ray.force_raycast_update()
	if not ray.is_colliding(): return
	var body := ray.get_collider() as RigidBody3D
	if body == null: return
	if String(only_group) != "" and not body.is_in_group(only_group): return

	_set_hover(null)
	grabbed = body

	_prev_freeze_mode = grabbed.freeze_mode
	_prev_frozen = grabbed.freeze

	# Freeze as kinematic and zero velocities
	grabbed.linear_velocity = Vector3.ZERO
	grabbed.angular_velocity = Vector3.ZERO
	grabbed.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	grabbed.freeze = true

	# Initialize rotation smoothing target to current orientation
	_desired_basis = grabbed.global_transform.basis.orthonormalized()

func _drop() -> void:
	if grabbed == null: return

	grabbed.freeze_mode = _prev_freeze_mode
	grabbed.freeze = _prev_frozen
	grabbed.sleeping = false
	grabbed.linear_velocity = Vector3.ZERO
	grabbed.angular_velocity = Vector3.ZERO

	_rotating = false
	_set_look_lock(false)
	grabbed = null
	hold_distance = 0.45

# ---------- Deposit support ----------

# Tries to deposit the held coin into a bank under deposit_ray.
# Returns true if deposited (coin consumed / mounted), false otherwise.
func _try_deposit_held() -> bool:
	if grabbed == null or not deposit_ray:
		if deposit_debug: print("[Deposit] No grabbed or deposit_ray missing")
		return false

	deposit_ray.force_raycast_update()
	if not deposit_ray.is_colliding():
		if deposit_debug: print("[Deposit] Ray not colliding")
		return false

	var hit := deposit_ray.get_collider()
	if deposit_debug:
		print("[Deposit] Hit: ", hit, " path=", (hit as Node).get_path() if hit is Node else "<no node>")

	if not is_instance_valid(hit):
		return false

	var bank := _find_bank_on_node_or_parents(hit)
	if deposit_debug:
		print("[Deposit] Bank found? ", bank, " has try_deposit? ", bank and bank.has_method("try_deposit"))

	if bank == null or not bank.has_method("try_deposit"):
		return false

	# If your bank expects `Coin` as a typed parameter, this cast matters.
	var coin := grabbed as Node # narrow first to Node
	if coin and not (coin is Coin):
		coin = grabbed as Coin
	if coin == null:
		# fallback: pass grabbed, but warn
		if deposit_debug: print("[Deposit] WARNING: grabbed is not Coin (", grabbed, ")")
		coin = grabbed

	var ok := bank.try_deposit(coin)
	if deposit_debug:
		print("[Deposit] try_deposit -> ", ok)

	if ok:
		# Bank owns/consumes/mounts coin; release our handle
		grabbed = null
		_rotating = false
		_set_look_lock(false)
		return true

	return false


func _find_bank_on_node_or_parents(n: Object) -> Bank:
	var cur := n as Node
	while cur:
		if cur.has_method("try_deposit") or cur.is_in_group("bank"):
			return cur
		cur = cur.get_parent()
	return null

func _get_mesh(rb: RigidBody3D) -> MeshInstance3D:
	return rb.get_node_or_null("MeshInstance3D") as MeshInstance3D

func _set_look_lock(flag: bool) -> void:
	if player_node and player_node.has_method("set_look_locked"):
		player_node.call("set_look_locked", flag)
