extends Bank
class_name VariantShelf

@export var coin_type: CoinTypes.Type = CoinTypes.Type.PENNY

@export var variant_types: Array[CoinVariants.Type] = [
	CoinVariants.Type.REGULAR,
	CoinVariants.Type.REVERSE,
	CoinVariants.Type.OFFSET,
	CoinVariants.Type.WRONG_RIM,
	CoinVariants.Type.SHINY,
]

@export var slots_root_path: NodePath = ^"Slots"
@export var label_scene: PackedScene
@export var columns: int = 1
@export var row_gap: float = 0.12
@export var col_gap: float = 0.40

@export var collected_prefix: String = "✓ "
@export var pending_prefix: String = "• "
@export var collected_tint: Color = Color(0.6, 1.0, 0.6, 1.0)
@export var pending_tint: Color = Color(1, 1, 1, 1)
@export var dim_alpha_when_collected: float = 0.55

# Header
@export var show_header: bool = true
@export var header_offset_y: float = 0.25
@export var header_color: Color = Color(1, 0.9, 0.6, 1.0)
@export var header_pixel_size: float = 0.004

signal updated_progress(collected_count: int, total: int)

const SND_SHELF := preload("res://sounds/shelf_deposit.wav")

var _slots_root: Node3D
var _slot_nodes: Array[Label3D] = []
var _collected_by_type: Dictionary = {} # CoinVariants.Type -> bool
var _header_label: Label3D = null

func _ready() -> void:
	_slots_root = get_node_or_null(slots_root_path)
	if _slots_root == null:
		_slots_root = Node3D.new()
		_slots_root.name = "Slots"
		add_child(_slots_root)

	# normalize state
	_slot_nodes.clear()
	_collected_by_type.clear()
	for t in variant_types:
		_collected_by_type[t] = false

	_build_labels()
	if show_header:
		_add_header_label()
	_emit_progress()

func _build_labels() -> void:
	for c in _slots_root.get_children():
		c.queue_free()
	_slot_nodes.clear()

	var i := 0
	for t in variant_types:
		var l: Label3D = _make_label()
		l.text = _format_text(t, false)
		l.modulate = pending_tint
		var r : float = i / max(columns, 1)
		var c : float = i % max(columns, 1)
		l.transform.origin = Vector3(c * col_gap, -r * row_gap, 0.0)
		_slots_root.add_child(l)
		_slot_nodes.append(l)
		i += 1

func _add_header_label() -> void:
	var label := Label3D.new()
	label.text = CoinTypes.to_name(coin_type)
	label.pixel_size = header_pixel_size
	label.double_sided = true
	label.modulate = header_color
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	var total_width : float = (max(columns, 1) - 1) * col_gap
	label.transform.origin = Vector3(total_width * 0.5, header_offset_y, 0.0)
	_slots_root.add_child(label)
	_header_label = label

func _make_label() -> Label3D:
	if label_scene:
		var inst = label_scene.instantiate()
		if inst is Label3D:
			return inst
		var lbl := inst.get_node_or_null("Label3D")
		if lbl and lbl is Label3D:
			return lbl
	var l := Label3D.new()
	l.double_sided = true
	l.pixel_size = 0.003
	return l

func _format_text(t: CoinVariants.Type, collected: bool) -> String:
	var prefix := collected_prefix if collected else pending_prefix
	return prefix + CoinVariants.to_name(t)

# ------------ DEPOSIT CONTRACT ------------
func try_deposit(coin: Coin) -> bool:
	if coin == null:
		emit_signal("rejected", coin, "No coin"); return false

	# Type gate
	var ctype := coin.coin_type_id()
	var type_ok := (ctype == coin_type) or (accepts_any or accepted_types.has(ctype))
	if not type_ok:
		emit_signal("rejected", coin, "Wrong type"); return false

	# Variant gate (map string id -> enum)
	var vid := _get_variant_id(coin)         # StringName like "regular"
	var vt  := CoinVariants.from_id(vid)     # enum
	if not variant_types.has(vt):
		emit_signal("rejected", coin, "Variant not tracked"); return false
	if _collected_by_type.get(vt, false):
		emit_signal("rejected", coin, "Already collected"); return false

	_mark_collected(vt)
	emit_signal("deposited", coin)
	_on_accept(coin) # Bank default: queue_free
	return true

func _on_accept(coin: Coin) -> void:
	# play a quick one-shot at the shelf's position
	var s := AudioStreamPlayer3D.new()
	s.stream = SND_SHELF
	# Optional tiny variation so repeated deposits don't sound identical:
	s.pitch_scale = randf_range(0.97, 1.03)
	add_child(s)
	s.play()
	s.connect("finished", Callable(s, "queue_free"))

	# keep the original behavior (remove the coin)
	coin.queue_free()

# ---- Variant extraction (works with your Coin/CoinData) ----
func _get_variant_id(coin: Coin) -> StringName:
	# Prefer a method on Coin if present
	if coin and coin.has_method("variant_id"):
		var v = coin.variant_id()
		if v != null and String(v) != "":
			return StringName(v)
	# Property on Coin
	var v_coin = coin.get("variant_id") if coin else null
	if v_coin != null and String(v_coin) != "":
		return StringName(v_coin)
	# Property on CoinData (Resource) — safe via get()
	if coin and coin.data:
		var v_data = coin.data.get("variant_id")
		if v_data != null and String(v_data) != "":
			return StringName(v_data)
	# default
	return &"regular"

func _mark_collected(vt: CoinVariants.Type) -> void:
	_collected_by_type[vt] = true
	# Update label
	for i in variant_types.size():
		if variant_types[i] == vt:
			var l := _slot_nodes[i]
			l.text = _format_text(vt, true)
			var c := collected_tint
			c.a = clamp(dim_alpha_when_collected, 0.0, 1.0)
			l.modulate = c
			break
	_emit_progress()

func _emit_progress() -> void:
	var total := variant_types.size()
	var got := 0
	for t in _collected_by_type.keys():
		if _collected_by_type[t]:
			got += 1
	updated_progress.emit(got, total)
