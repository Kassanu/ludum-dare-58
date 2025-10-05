# res://interact/VariantShelf.gd
extends Bank
class_name VariantShelf

# --------- CONFIG ---------
@export var coin_type: CoinTypes.Type = CoinTypes.Type.PENNY

# Each entry: { "id": "reverse", "name": "Reverse Face" }
# Keep this short for the jam—hand fill in the inspector.
@export var variants: Array[Dictionary] = [
	{"id":"regular", "name":"Regular"},
	{"id":"reverse", "name":"Reverse Face"},
]

# Layout on the wall “board”
@export var slots_root_path: NodePath = ^"Slots"  # a plain Node3D under your shelf
@export var label_scene: PackedScene              # optional: custom Label3D scene; if null, we create basic Label3D
@export var columns: int = 1                      # 1 column makes a vertical list
@export var row_gap: float = 0.12                 # world units between rows
@export var col_gap: float = 0.40

# Visual tweaks
@export var collected_prefix: String = "✓ "
@export var pending_prefix: String = "• "
@export var collected_tint: Color = Color(0.6, 1.0, 0.6, 1.0)
@export var pending_tint: Color = Color(1, 1, 1, 1)
@export var dim_alpha_when_collected: float = 0.55

# If true, the shelf will also check the type list from Bank.accepted_types
# (handy if you duplicated from a generic shelf that accepts multiple)
@export var also_respect_bank_type_list: bool = false

# --- optional header ---
@export var show_header: bool = true
@export var header_offset_y: float = 0.25   # vertical distance above the first slot
@export var header_color: Color = Color(1, 0.9, 0.6, 1.0)
@export var header_pixel_size: float = 0.004
var _header_label: Label3D = null

signal updated_progress(collected_count: int, total: int)

var _slots_root: Node3D
var _slot_nodes: Array[Label3D] = []
var _collected: Dictionary = {} # id -> bool

func _ready() -> void:
	_slots_root = get_node_or_null(slots_root_path)
	if _slots_root == null:
		_slots_root = Node3D.new()
		_slots_root.name = "Slots"
		add_child(_slots_root)

	# normalize input + clear old state
	_slot_nodes.clear()
	_collected.clear()
	for v in variants:
		if not v.has("id"):
			v["id"] = StringName("unknown")
		if not v.has("name"):
			v["name"] = String(v["id"])
		_collected[v["id"]] = false

	_build_labels()
	if show_header:
		_add_header_label()
	_emit_progress()

func _build_labels() -> void:
	# destroy old children (in case you hot-reload)
	for c in _slots_root.get_children():
		c.queue_free()

	# make labels
	var i := 0
	for v in variants:
		var l: Label3D = _make_label()
		l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		l.text = _format_text(v, false)
		l.modulate = pending_tint
		# grid-ish layout
		var r : int = i / max(columns, 1)
		var c :int = i % max(columns, 1)
		l.transform.origin = Vector3(float(c) * col_gap, -float(r) * row_gap, 0.0)
		_slots_root.add_child(l)
		_slot_nodes.append(l)
		i += 1

func _make_label() -> Label3D:
	if label_scene:
		var inst = label_scene.instantiate()
		# If they gave us a small prefab that isn’t a Label3D root, try to find one:
		if inst is Label3D:
			return inst
		var label := inst.get_node_or_null("Label3D")
		if label and label is Label3D:
			return label
		# fallback to a plain label
	var l := Label3D.new()
	l.double_sided = true
	l.text = "Slot"
	l.pixel_size = 0.003 # small-ish; tune in editor
	l.outline_size = 0
	return l

func _format_text(v: Dictionary, collected: bool) -> String:
	var prefix := collected_prefix if collected else pending_prefix
	return prefix + String(v.get("name", v.get("id", "Variant")))

# ------------ DEPOSIT CONTRACT ------------
func try_deposit(coin: Coin) -> bool:
	if coin == null:
		emit_signal("rejected", coin, "No coin")
		return false

	# Type gate: either strict coin_type, or also accept Bank.accepted_types if you want a multi-type board
	var ctype := coin.coin_type_id()
	var type_ok := (ctype == coin_type) or (also_respect_bank_type_list and (accepts_any or accepted_types.has(ctype)))
	if not type_ok:
		emit_signal("rejected", coin, "Wrong type")
		return false

	# Variant gate:
	var vid := _get_variant_id(coin)
	if vid == "":
		emit_signal("rejected", coin, "No variant id")
		return false
	if not _collected.has(vid):
		emit_signal("rejected", coin, "Variant not tracked")
		return false
	if _collected[vid] == true:
		emit_signal("rejected", coin, "Already collected")
		return false

	# Accept and mark collected
	_mark_collected(vid)
	emit_signal("deposited", coin)
	_on_accept(coin) # from Bank: default queue_free
	return true

# Replace the old _get_variant_id with this version
func _get_variant_id(coin: Coin) -> StringName:
	# 1) If Coin implements a method, prefer it
	if coin and coin.has_method("variant_id"):
		var v = coin.variant_id()
		if v != null and String(v) != "":
			return StringName(v)

	# 2) If Coin has a property "variant_id" (not exported doesn’t matter), use it
	var v_coin = coin.get("variant_id") if coin else null
	if v_coin != null and String(v_coin) != "":
		return StringName(v_coin)

	# 3) Look on the CoinData resource safely via get()
	if coin and coin.data:
		var v_data = coin.data.get("variant_id")   # safe even if the property doesn't exist
		if v_data != null and String(v_data) != "":
			return StringName(v_data)

	return StringName("regular")


func _mark_collected(vid: StringName) -> void:
	_collected[vid] = true

	# Update one label
	for i in variants.size():
		if StringName(variants[i]["id"]) == vid:
			var l := _slot_nodes[i]
			l.text = _format_text(variants[i], true)
			# “cross out” vibe: dim + tint greenish
			var c := collected_tint
			c.a = clamp(dim_alpha_when_collected, 0.0, 1.0)
			l.modulate = c
			break

	_emit_progress()

func _emit_progress() -> void:
	var total := variants.size()
	var got := 0
	for k in _collected.keys():
		if _collected[k]:
			got += 1
	updated_progress.emit(got, total)

func _add_header_label() -> void:
	if _slots_root == null:
		return

	var label := Label3D.new()
	label.text = CoinTypes.to_name(coin_type)
	label.pixel_size = header_pixel_size
	label.double_sided = true
	label.modulate = header_color
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED

	# Position centered horizontally and above the first slot
	var total_width : float = (max(columns, 1) - 1) * col_gap
	label.transform.origin = Vector3(total_width * 0.5, header_offset_y, 0.0)

	_slots_root.add_child(label)
	_header_label = label
