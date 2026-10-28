class_name CarData
extends RefCounted
## Car stats + upgrade math. The catalogue itself lives in content/cars/*.json (see Content).

const MAX_UPGRADE := 5
const UPGRADE_KEYS: Array = ["engine", "tires", "nitro"]


static func cars() -> Array:
    return Content.cars()


static func has_car(id: String) -> bool:
    return not Content.car(id).is_empty()


static func by_id(id: String) -> Dictionary:
    var c := Content.car(id)
    if c.is_empty():
        return Content.cars()[0]
    return c


static func index_of(id: String) -> int:
    var all := Content.cars()
    for i in all.size():
        if all[i]["id"] == id:
            return i
    return 0


static func upgrade_cost(current_level: int) -> int:
    return 300 * (current_level + 1) * (current_level + 1)


static func stats_for(car: Dictionary, levels: Dictionary) -> Dictionary:
    var eng := int(levels.get("engine", 0))
    var tir := int(levels.get("tires", 0))
    var nit := int(levels.get("nitro", 0))
    return {
        "top": float(car["top"]) * (1.0 + 0.035 * eng),
        "accel": float(car["accel"]) * (1.0 + 0.06 * eng),
        "handling": float(car["handling"]) * (1.0 + 0.03 * tir),
        "grip": 1.0 + 0.07 * tir,
        "nitro": float(car["nitro"]) * (1.0 + 0.15 * nit),
    }
