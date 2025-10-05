extends Node3D
class_name JarBank

@export var jar_type: CoinTypes.Type = CoinTypes.Type.PENNY
@export var hover_point_path: NodePath = ^"HoverPoint"
@export var body_path: NodePath = ^"Body"   # StaticBody3D, used only for layer reference
@export var label_path: NodePath = ^"Visual/Label3D"
@export var count_label_path: NodePath = ^"Visual/CountLabel"

# Animation feel
@export var fly_time: float = 0.18          # seconds to move to hover point
@export var fall_timeout: float = 1.5       # safety: finalize if no collision
@export var collide_jar_layer: int = 1      # (1–20) layer index the jar Body is on

signal deposited(coin: Coin)
signal rejected(coin, reason: String)

var count := 0

@onready var _hover_pt: Node3D = get_node_or_null(hover_point_path)
@onready var _body: StaticBody3D = get_node_or_null(body_path)
@onready var _label: Label3D = get_node_or_null(label_path)
@onready var _count_label: Label3D = get_node_or_null(count_label_path)

func _ready() -> void:
	_update_label()

func try_deposit(coin) -> bool:
	if coin == null:
		emit_signal("rejected", coin, "null")
		return false

	var t := _extract_enum(coin)
	if t != jar_type:
		emit_signal("rejected", coin, "wrong_type")
		return false

	_start_animated_deposit(coin)
	return true


func _extract_enum(coin) -> CoinTypes.Type:
	if coin is Coin:
		return coin.coin_type_id()
	if "data" in coin and coin.data and ("type_id" in coin.data):
		return CoinTypes.from_id(coin.data.type_id)
	return CoinTypes.Type.PENNY


func _start_animated_deposit(coin: Coin) -> void:
	coin.set_meta("pending_deposit", true)

	# store original physics data
	coin.set_meta("orig_layers", coin.collision_layer)
	coin.set_meta("orig_mask", coin.collision_mask)

	# freeze and disable collisions during the fly-up
	coin.linear_velocity = Vector3.ZERO
	coin.angular_velocity = Vector3.ZERO
	coin.freeze = true
	coin.collision_layer = 0
	coin.collision_mask = 0

	# keep scene tidy
	var gt := coin.global_transform
	if coin.get_parent() != self:
		coin.get_parent().remove_child(coin)
		add_child(coin)
	coin.global_transform = gt

	var target := _hover_pt.global_position if _hover_pt else global_position + Vector3(0, 0.12, 0)

	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(coin, "global_position", target, fly_time)
	tw.finished.connect(func():
		# nudge up slightly to guarantee a new collision contact
		coin.global_position.y += 0.01
		_release_for_fall(coin)
	)


func _release_for_fall(coin: Coin) -> void:
	# restore physics and make the coin only collide with the jar
	coin.freeze = false
	coin.sleeping = false
	coin.linear_velocity = Vector3.ZERO
	coin.angular_velocity = Vector3.ZERO

	coin.collision_mask = 0
	if collide_jar_layer >= 1 and collide_jar_layer <= 20:
		coin.set_collision_mask_value(collide_jar_layer, true)

	var orig_layers := int(coin.get_meta("orig_layers", coin.collision_layer))
	coin.collision_layer = orig_layers

	# enable contact monitoring on the coin itself
	coin.contact_monitor = true
	coin.max_contacts_reported = max(coin.max_contacts_reported, 4)

	if not coin.is_connected("body_entered", Callable(self, "_on_coin_body_entered")):
		coin.body_entered.connect(Callable(self, "_on_coin_body_entered").bind(coin))

	# fallback timer if somehow no collision is seen
	var timer := get_tree().create_timer(fall_timeout)
	timer.timeout.connect(func():
		if coin and coin.has_meta("pending_deposit"):
			_finalize_deposit(coin)
	)


func _on_coin_body_entered(other: Node, coin: Coin) -> void:
	if not coin or not coin.has_meta("pending_deposit"):
		return

	# optional check—ignore collisions not involving this jar
	if _body and other != _body:
		return

	_finalize_deposit(coin)


func _finalize_deposit(coin: Coin) -> void:
	if coin.is_connected("body_entered", Callable(self, "_on_coin_body_entered")):
		coin.body_entered.disconnect(Callable(self, "_on_coin_body_entered"))

	coin.set_meta("pending_deposit", null)
	count += 1
	_update_count_label()
	emit_signal("deposited", coin)
	coin.queue_free()

	# --- QUICK SOUND ---
	var snd := AudioStreamPlayer3D.new()
	snd.stream = load("res://sounds/jar_deposit.wav")
	add_child(snd)
	snd.play()
	snd.connect("finished", Callable(snd, "queue_free"))

func _update_label() -> void:
	if _label:
		_label.text = _coin_type_to_text(jar_type)

func _update_count_label() -> void:
	if _count_label:
		_count_label.text = str(count)

func _coin_type_to_text(t: CoinTypes.Type) -> String:
	match t:
		CoinTypes.Type.PENNY:      return "Penny"
		CoinTypes.Type.NICKEL:     return "Nickel"
		CoinTypes.Type.DIME:       return "Dime"
		CoinTypes.Type.QUARTER:    return "Quarter"
		CoinTypes.Type.HALFDOLLAR: return "Half Dollar"
		CoinTypes.Type.DOLLAR:     return "Dollar"
		_:                         return "Coins"
