class_name MiniMap
extends Control
## Shows a window of the pre-rendered world map around the player (north-up).

const WINDOW_M := 700.0

var tex: Texture2D
var player_pos := Vector3.ZERO
var markers: Array = []            # [{pos: Vector3, color: Color}]
var path: PackedVector3Array = PackedVector3Array()


func _init() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE


func _w2p(p: Vector3) -> Vector2:
    var sc := float(WorldBuilder.MAP_PX) / (WorldData.HALF * 2.0)
    return Vector2((p.x + WorldData.HALF) * sc, (p.z + WorldData.HALF) * sc)


func _draw() -> void:
    if tex == null:
        return
    var sc := float(WorldBuilder.MAP_PX) / (WorldData.HALF * 2.0)
    var win := WINDOW_M * sc
    var c := _w2p(player_pos)
    var top_left := Vector2(clampf(c.x - win * 0.5, 0.0, WorldBuilder.MAP_PX - win), clampf(c.y - win * 0.5, 0.0, WorldBuilder.MAP_PX - win))
    draw_texture_rect_region(tex, Rect2(Vector2.ZERO, size), Rect2(top_left, Vector2(win, win)))
    var k := size.x / win
    if path.size() > 1:
        var poly := PackedVector2Array()
        for i in range(0, path.size(), 2):
            poly.append((_w2p(path[i]) - top_left) * k)
        draw_polyline(poly, Color(0.1, 0.85, 1.0, 0.9), 2.5)
    for m: Dictionary in markers:
        var mp := (_w2p(m["pos"]) - top_left) * k
        if Rect2(Vector2.ZERO, size).has_point(mp):
            draw_circle(mp, 5.0, m["color"])
    draw_circle((c - top_left) * k, 7.0, UIKit.ACCENT)
    draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.6), false, 2.0)
