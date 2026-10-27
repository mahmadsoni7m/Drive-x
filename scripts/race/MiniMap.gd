class_name MiniMap
extends Control
## Cheap custom-drawn minimap (track polyline + racer dots).

var info: TrackInfo
var racers: Array = []
var player: Vehicle
var _min := Vector2.ZERO
var _extent := Vector2.ONE


func setup(track: TrackInfo, all_racers: Array, p: Vehicle) -> void:
    info = track
    racers = all_racers
    player = p
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    var lo := Vector2(INF, INF)
    var hi := Vector2(-INF, -INF)
    for pt in info.points:
        lo = Vector2(minf(lo.x, pt.x), minf(lo.y, pt.z))
        hi = Vector2(maxf(hi.x, pt.x), maxf(hi.y, pt.z))
    _min = lo
    _extent = Vector2(maxf(hi.x - lo.x, 1.0), maxf(hi.y - lo.y, 1.0))


func _map(p: Vector3) -> Vector2:
    var pad := 14.0
    var sc := minf((size.x - pad * 2.0) / _extent.x, (size.y - pad * 2.0) / _extent.y)
    var off := (size - _extent * sc) * 0.5
    return Vector2((p.x - _min.x) * sc, (p.z - _min.y) * sc) + off


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.4), true)
    if info == null:
        return
    var poly := PackedVector2Array()
    for i in range(0, info.count(), 2):
        poly.append(_map(info.points[i]))
    poly.append(poly[0])
    draw_polyline(poly, Color(1, 1, 1, 0.8), 4.0)
    for r in racers:
        var v := r as Vehicle
        if v == null or v == player:
            continue
        draw_circle(_map(v.global_position), 5.0, Color(0.9, 0.9, 0.9))
    if player != null:
        draw_circle(_map(player.global_position), 8.0, UIKit.ACCENT)
