class_name Joystick
extends Control
## Virtual stick. value.x = right, value.y = forward (both -1..1).

var value := Vector2.ZERO
var _touch := -1


func _init() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var t := event as InputEventScreenTouch
        if t.pressed and _touch == -1:
            _touch = t.index
            _update_value(t.position)
            accept_event()
        elif not t.pressed and t.index == _touch:
            _touch = -1
            value = Vector2.ZERO
            queue_redraw()
            accept_event()
    elif event is InputEventScreenDrag:
        var d := event as InputEventScreenDrag
        if d.index == _touch:
            _update_value(d.position)
            accept_event()


func _update_value(p: Vector2) -> void:
    var d := (p - size * 0.5) / (size.x * 0.4)
    d = d.limit_length(1.0)
    value = Vector2(d.x, -d.y)
    queue_redraw()


func _notification(what: int) -> void:
    if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
        _touch = -1
        value = Vector2.ZERO


func _draw() -> void:
    var c := size * 0.5
    draw_circle(c, size.x * 0.46, Color(1, 1, 1, 0.12))
    draw_arc(c, size.x * 0.46, 0.0, TAU, 40, Color(1, 1, 1, 0.45), 3.0)
    draw_circle(c + Vector2(value.x, -value.y) * size.x * 0.4, size.x * 0.17, Color(1, 1, 1, 0.55))
