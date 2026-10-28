class_name TrackInfo
extends RefCounted
## Runtime description of a track centreline (closed loop, evenly spaced points).

var points: PackedVector3Array = PackedVector3Array()
var tangents: PackedVector3Array = PackedVector3Array()
var width: float = 14.0
var length: float = 0.0


func setup(pts: PackedVector3Array, w: float) -> void:
    points = pts
    width = w
    var n := points.size()
    tangents = PackedVector3Array()
    tangents.resize(n)
    length = 0.0
    for i in n:
        var t := points[(i + 1) % n] - points[(i - 1 + n) % n]
        t.y = 0.0
        tangents[i] = t.normalized()
        length += points[i].distance_to(points[(i + 1) % n])


func count() -> int:
    return points.size()


func point(i: int) -> Vector3:
    return points[posmod(i, points.size())]


func tangent(i: int) -> Vector3:
    return tangents[posmod(i, points.size())]


## Right-hand side of the driving direction.
func right(i: int) -> Vector3:
    return tangent(i).cross(Vector3.UP)


func _d2(a: Vector3, b: Vector3) -> float:
    var dx := a.x - b.x
    var dz := a.z - b.z
    return dx * dx + dz * dz


## Nearest centreline index. With a hint only a small window around it is searched.
func nearest_index(pos: Vector3, hint: int = -1, window: int = 14) -> int:
    var n := points.size()
    var best := 0
    var best_d := INF
    if hint < 0:
        for i in n:
            var d := _d2(pos, points[i])
            if d < best_d:
                best_d = d
                best = i
        return best
    for k in range(-window, window + 1):
        var j := posmod(hint + k, n)
        var d2 := _d2(pos, points[j])
        if d2 < best_d:
            best_d = d2
            best = j
    return best


func lateral_offset(pos: Vector3, idx: int) -> float:
    return (pos - point(idx)).dot(right(idx))


## Starting grid index for a slot (two cars per row, 12 m between rows, behind the line at index 0).
func grid_index(slot: int) -> int:
    return posmod(count() - 3 - (slot / 2) * 3, count())


func grid_transform(slot: int) -> Transform3D:
    var idx := grid_index(slot)
    var side := -1.0 if slot % 2 == 0 else 1.0
    var pos := point(idx) + right(idx) * side * 3.0
    return Transform3D(Basis.looking_at(tangent(idx), Vector3.UP), pos)
