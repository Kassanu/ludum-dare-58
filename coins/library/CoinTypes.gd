class_name CoinTypes

enum Type { PENNY, NICKEL, DIME, QUARTER, HALFDOLLAR, DOLLAR }

static func from_id(id: StringName) -> Type:
	match String(id).to_lower():
		"penny":        return Type.PENNY
		"nickel":       return Type.NICKEL
		"dime":         return Type.DIME
		"quarter":      return Type.QUARTER
		"half_dollar",\
		"halfdollar",\
		"half-dollar":  return Type.HALFDOLLAR
		"dollar":       return Type.DOLLAR
		_:              return Type.PENNY  # safe default

static func to_id(t: Type) -> StringName:
	match t:
		Type.PENNY:      return &"penny"
		Type.NICKEL:     return &"nickel"
		Type.DIME:       return &"dime"
		Type.QUARTER:    return &"quarter"
		Type.HALFDOLLAR: return &"half_dollar"
		Type.DOLLAR:     return &"dollar"
		_:               return &"penny"