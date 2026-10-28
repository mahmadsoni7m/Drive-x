class_name WorldData
extends RefCounted
## The open world layout: 2.4 km x 2.4 km map with THREE road types:
##   HIGHWAY  - wide fast asphalt ring road + connectors
##   CITY     - grid of city streets with buildings
##   DIRT     - mountain dirt roads (slower, less grip)

const HALF := 1200.0
const K_GRASS := 0
const K_HIGHWAY := 1
const K_CITY := 2
const K_DIRT := 3
const SPEED_MULT: Array = [0.62, 1.0, 1.0, 0.88]
const GRIP_MULT: Array = [0.75, 1.0, 1.0, 0.78]
const STREETS: Array = [-300.0, -150.0, 0.0, 150.0, 300.0]

const PLAYER_CAR := Vector3(-24.0, 0.0, 3.0)
const PLAYER_START := Vector3(-24.0, 0.0, 7.5)
const HOSPITAL := Vector3(-60.0, 0.0, 8.0)
const FIGHTER_SPOTS: Array = [
    Vector3(150, 0, 150), Vector3(-150, 0, 150), Vector3(150, 0, -150),
    Vector3(-150, 0, -150), Vector3(-300, 0, 0), Vector3(300, 0, 0),
]

static var _roads: Array = []


static func dirt_loop(cx: float, cz: float, base_r: float, wob: float, freq: int, n: int, start: float) -> PackedVector2Array:
    var pts := PackedVector2Array()
    for i in n:
        var a := start + TAU * float(i) / float(n)
        var r := base_r + wob * sin(float(freq) * a)
        pts.append(Vector2(cx + r * cos(a), cz + r * sin(a)))
    return pts


static func _road(kind: int, width: float, closed: bool, smooth: bool, pts: PackedVector2Array) -> Dictionary:
    return {"kind": kind, "width": width, "closed": closed, "smooth": smooth, "pts": pts}


static func roads() -> Array:
    if not _roads.is_empty():
        return _roads
    var r: Array = []
    for s: float in STREETS:
        r.append(_road(K_CITY, 10.0, false, false, PackedVector2Array([Vector2(s, -300.0), Vector2(s, 300.0)])))
        r.append(_road(K_CITY, 10.0, false, false, PackedVector2Array([Vector2(-300.0, s), Vector2(300.0, s)])))
    var ring := PackedVector2Array()
    for i in 48:
        var a := TAU * float(i) / 48.0
        ring.append(Vector2(cos(a), sin(a)) * 800.0)
    r.append(_road(K_HIGHWAY, 18.0, true, true, ring))
    for d: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
        r.append(_road(K_HIGHWAY, 14.0, false, false, PackedVector2Array([d * 300.0, d * 800.0])))
    var south := dirt_loop(0.0, 1000.0, 120.0, 25.0, 3, 12, -PI / 2.0)
    var east := dirt_loop(1000.0, 0.0, 110.0, 20.0, 4, 12, PI)
    r.append(_road(K_DIRT, 9.0, true, true, south))
    r.append(_road(K_DIRT, 9.0, true, true, east))
    r.append(_road(K_DIRT, 9.0, false, false, PackedVector2Array([Vector2(0.0, 800.0), south[0]])))
    r.append(_road(K_DIRT, 9.0, false, false, PackedVector2Array([Vector2(800.0, 0.0), east[0]])))
    _roads = r
    return _roads
