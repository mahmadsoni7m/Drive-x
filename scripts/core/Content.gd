class_name Content
extends RefCounted
## Data-driven content loader. Everything under res://content/<kind>/<id>.json is listed in
## res://content/index.json. To add a car / outfit / character / race: drop a JSON file in the right
## folder and add its id to index.json - no code changes needed (see docs/ADDING_CONTENT.md).

const ROOT := "res://content/"
const SLOTS: Array = ["top", "bottom", "shoes", "hat"]

static var _cache: Dictionary = {}
static var _errors: Array = []


static func read_json(path: String) -> Variant:
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null:
        _errors.append("cannot open %s" % path)
        return null
    var parsed: Variant = JSON.parse_string(f.get_as_text())
    if parsed == null:
        _errors.append("invalid JSON: %s" % path)
    return parsed


static func _list(kind: String) -> Array:
    if _cache.has(kind):
        return _cache[kind]
    var out: Array = []
    var idx: Variant = read_json(ROOT + "index.json")
    if idx is Dictionary and (idx as Dictionary).get(kind) is Array:
        for id in idx[kind]:
            var d: Variant = read_json("%s%s/%s.json" % [ROOT, kind, str(id)])
            if d is Dictionary:
                if str(d.get("id", "")) != str(id):
                    _errors.append("%s/%s.json: id mismatch" % [kind, str(id)])
                out.append(d)
    _cache[kind] = out
    return out


static func cars() -> Array:
    return _list("cars")


static func outfits() -> Array:
    return _list("outfits")


static func characters() -> Array:
    return _list("characters")


static func races() -> Array:
    return _list("races")


static func _find(list: Array, id: String) -> Dictionary:
    for d in list:
        if d["id"] == id:
            return d
    return {}


static func car(id: String) -> Dictionary:
    return _find(cars(), id)


static func outfit(id: String) -> Dictionary:
    return _find(outfits(), id)


static func character(id: String) -> Dictionary:
    return _find(characters(), id)


static func race(id: String) -> Dictionary:
    return _find(races(), id)


static func outfits_in(slot: String, shop_only: bool = true) -> Array:
    var out: Array = []
    for o in outfits():
        if o["slot"] == slot and (not shop_only or bool(o.get("shop", true))):
            out.append(o)
    return out


static func characters_with_role(role: String) -> Array:
    var out: Array = []
    for c in characters():
        if c.get("role", "") == role:
            out.append(c)
    return out


## Returns a list of human-readable problems (empty list = content is valid).
static func validate() -> Array:
    _cache.clear()
    _errors.clear()
    var p: Array = _errors
    if cars().is_empty():
        p.append("no cars")
    for c in cars():
        for k in ["name", "price", "color", "top", "accel", "handling", "nitro", "len", "wid", "hei", "cabin"]:
            if not c.has(k):
                p.append("car %s missing '%s'" % [c["id"], k])
        if float(c.get("top", 0)) < 20.0 or float(c.get("accel", 0)) < 5.0:
            p.append("car %s has unrealistic stats" % c["id"])
    for o in outfits():
        if not SLOTS.has(str(o.get("slot", ""))):
            p.append("outfit %s has bad slot" % o["id"])
        for k in ["name", "price", "color", "style"]:
            if not o.has(k):
                p.append("outfit %s missing '%s'" % [o["id"], k])
    for c in characters():
        var oc: Dictionary = c.get("outfit", {})
        for slot in oc:
            var oid := str(oc[slot])
            if oid != "" and outfit(oid).is_empty():
                p.append("character %s uses unknown outfit %s" % [c["id"], oid])
    if characters_with_role("npc").is_empty() or characters_with_role("fighter").is_empty():
        p.append("need at least one npc and one fighter character")
    for r in races():
        if (r.get("waypoints", []) as Array).size() < 6:
            p.append("race %s needs >= 6 waypoints" % r["id"])
    for e in _errors:
        if not p.has(e):
            p.append(e)
    return p
