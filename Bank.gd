extends Node3D
class_name Bank

signal deposited(coin: Coin)
signal rejected(coin: Coin, reason: String)

@export var accepts_any: bool = false
@export var accepted_types: Array[CoinTypes.Type] = []

# optional helpful UI name
@export var bank_name: String = "Bank"

func try_deposit(coin: Coin) -> bool:
	# default: check type list / any
	if not coin:
		emit_signal("rejected", coin, "No coin")
		return false
	if accepts_any or accepted_types.has(coin.coin_type_id()):
		_on_accept(coin)
		emit_signal("deposited", coin)
		return true
	emit_signal("rejected", coin, "Wrong type")
	return false

func _on_accept(coin: Coin) -> void:
	# Overridden by subclasses (jar removes, slotbank mounts, etc.)
	coin.queue_free()
