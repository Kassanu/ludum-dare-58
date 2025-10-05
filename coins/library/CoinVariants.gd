class_name CoinVariants

enum Type { REGULAR, REVERSE, OFFSET, WRONG_RIM, SHINY}

static func from_id(id: StringName) -> Type:
	match String(id).to_lower():
		"regular":       return Type.REGULAR
		"reverse":       return Type.REVERSE
		"offset":        return Type.OFFSET
		"wrong_rim":    return Type.WRONG_RIM
		"shiny":    return Type.SHINY
		_:              return Type.REGULAR  # safe default

static func to_id(t: Type) -> StringName:
	match t:
		Type.REGULAR:      return &"regular"
		Type.REVERSE:     return &"reverse"
		Type.OFFSET:       return &"offset"
		Type.WRONG_RIM:       return &"wrong_rim"
		Type.SHINY:       return &"shiny"
		_:               return &"penny"

static func to_name(t: Type) -> String:
	match t:
		Type.REGULAR:      return "Regular"
		Type.REVERSE:     return "Reverse Face"
		Type.OFFSET:       return "Offset Face"
		Type.WRONG_RIM:    return "Wrong Rim"
		Type.SHINY:    return "Shiny"
		_:               return "Regular"