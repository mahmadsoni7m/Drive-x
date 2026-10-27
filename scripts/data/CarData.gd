class_name CarData
extends RefCounted
## Static car catalogue + upgrade math. Add a car by appending one dictionary to _build().
## Keep ids in sync with tools/blender/generate_cars.py if you provide .glb models.

const MAX_UPGRADE := 5
const UPGRADE_KEYS: Array = ["engine", "tires", "nitro"]
const UPGRADE_NAMES: Dictionary = {"engine": "ENGINE", "tires": "TIRES", "nitro": "NITRO"}

static var _cache: Array = []


static func cars() -> Array:
    if _cache.is_empty():
        _cache = _build()
    return _cache


static func _build() -> Array:
    return [
        {"id": "gt_rookie", "name": "GT ROOKIE", "price": 0, "color": "e63946", "top": 46.0, "accel": 15.0,
         "handling": 1.00, "nitro": 1.00, "len": 4.3, "wid": 1.80, "hei": 0.50, "cabin": 0.50, "spoiler": false, "stripe": false},
        {"id": "street_fox", "name": "STREET FOX", "price": 2500, "color": "ff9f1c", "top": 52.0, "accel": 17.0,
         "handling": 1.05, "nitro": 1.05, "len": 4.1, "wid": 1.80, "hei": 0.52, "cabin": 0.52, "spoiler": true, "stripe": true},
        {"id": "apex_r", "name": "APEX R", "price": 7000, "color": "2ec4b6", "top": 58.0, "accel": 19.0,
         "handling": 1.12, "nitro": 1.10, "len": 4.4, "wid": 1.90, "hei": 0.46, "cabin": 0.46, "spoiler": true, "stripe": false},
        {"id": "viper_s", "name": "VIPER S", "price": 16000, "color": "7b2cbf", "top": 66.0, "accel": 21.5,
         "handling": 1.15, "nitro": 1.20, "len": 4.5, "wid": 1.95, "hei": 0.44, "cabin": 0.44, "spoiler": true, "stripe": true},
        {"id": "phantom_x", "name": "PHANTOM X", "price": 35000, "color": "e8ecf4", "top": 76.0, "accel": 24.0,
         "handling": 1.20, "nitro": 1.35, "len": 4.6, "wid": 2.00, "hei": 0.42, "cabin": 0.42, "spoiler": true, "stripe": true},
    ]


static func has_car(id: String) -> bool:
    for c in cars():
        if c["id"] == id:
            return true
    return false


static func by_id(id: String) -> Dictionary:
    for c in cars():
        if c["id"] == id:
            return c
    return cars()[0]


static func index_of(id: String) -> int:
    var all := cars()
    for i in all.size():
        if all[i]["id"] == id:
            return i
    return 0


static func upgrade_cost(current_level: int) -> int:
    return 300 * (current_level + 1) * (current_level + 1)


## Final driving stats for a car with the given upgrade levels {"engine":n,"tires":n,"nitro":n}.
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
