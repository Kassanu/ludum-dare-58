class_name CoinLibrary
extends Resource

@export var types: Array[CoinType] = []

func get_type_by_id(wanted: CoinTypes.Type) -> CoinType:
	for t in types:
		if t.id == wanted:
			return t
	return null
