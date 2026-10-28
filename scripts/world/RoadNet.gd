class_name RoadNet
extends RefCounted
## Spatial index over all road segments: fast "what surface am I on?" queries
## (grass / highway / city / dirt) used for grip, speed and scenery placement.

const CELL := 64.0

var polylines: Array = []   # [{kind, width, closed, pts: PackedVector3Array}] for mesh building
var _a := PackedVector2Array()
var _b := PackedVector2Array()
var _kind := PackedInt32Array()
var _hw := PackedFloat32Array()
var _grid: Dictionary = {}


func build() -> void:
    polylines.clear()
    for road: Dictionary in WorldData.roads():
        var closed := bool(road["closed"])
        var pts := PathUtil.resample(road["pts"], closed, bool(road["smooth"]), 8.0)
        polylines.append({"kind": int(road["kind"]), "width": float(road["width"]), "closed": closed, "pts": pts})
        var n := pts.size()
        var segs := n if closed else n - 1
        for i in segs:
            var p := pts[i]
            var q := pts[(i + 1) % n]
            _add(Vector2(p.x, p.z), Vector2(q.x, q.z), int(road["kind"]), float(road["width"]) * 0.5)


func _add(a: Vector2, b: Vector2, kind: int, hw: float) -> void:
    var idx := _a.size()
    _a.append(a)
    _b.append(b)
    _kind.append(kind)
    _hw.append(hw)
    var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(hw + 2.0, hw + 2.0)
    var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(hw + 2.0, hw + 2.0)
    for cx in range(floori(lo.x / CELL), floori(hi.x / CELL) + 1):
        for cz in range(floori(lo.y / CELL), floori(hi.y / CELL) + 1):
            var key := Vector2i(cx, cz)
            var arr: PackedInt32Array = _grid.get(key, PackedInt32Array())
            arr.append(idx)
            _grid[key] = arr


func _dist(p: Vector2, idx: int) -> float:
    var a := _a[idx]
    var ab := _b[idx] - a
    var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
    return p.distance_to(a + ab * t)


## Surface kind under a world position: WorldData.K_GRASS / K_HIGHWAY / K_CITY / K_DIRT.
func surface_at(pos: Vector3) -> int:
    var p := Vector2(pos.x, pos.z)
    var key := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
    if not _grid.has(key):
        return WorldData.K_GRASS
    var best := WorldData.K_GRASS
    for idx in (_grid[key] as PackedInt32Array):
        if _dist(p, idx) <= _hw[idx]:
            var k := _kind[idx]
            if best == WorldData.K_GRASS or k != WorldData.K_DIRT:
                best = k
    return best


## True if any road lies within (half-width + margin) of the position.
func near_road(pos: Vector3, margin: float) -> bool:
    var p := Vector2(pos.x, pos.z)
    var cx := floori(p.x / CELL)
    var cz := floori(p.y / CELL)
    for dx in range(-1, 2):
        for dz in range(-1, 2):
            var key := Vector2i(cx + dx, cz + dz)
            if not _grid.has(key):
                continue
            for idx in (_grid[key] as PackedInt32Array):
                if _dist(p, idx) <= _hw[idx] + margin:
                    return true
    return false
