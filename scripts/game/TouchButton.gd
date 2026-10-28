class_name TouchButton
extends Control
## Multi-touch-safe on-screen button: tracks its own finger index so steering, gas, brake,
## nitro and drift can all be held simultaneously. Mouse works too (touch is emulated from mouse).

var pressed := false
var label := ""
var shape := ""
var tint := Color.WHITE
var _touch := -1
var _up: StyleBoxFlat
var _down: StyleBoxFlat


func _init(text: String = "", color: Color = Color.WHITE, shape_name: String = "", radius: int = 28) -> void:
    label = text
    shape = shape_name
    tint = color
    mouse_filter = Control.MOUSE_FILTER_STOP
    _up = UIKit.flat(Color(color.r, color.g, color.b, 0.26), radius, Color(color.r, color.g, color.b, 0.8), 3)
    _down = UIKit.flat(Color(color.r, color.g, color.b, 0.7), radius, Color(1, 1, 1, 0.9), 3)


func _gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var t := event as InputEventScreenTouch
        if t.pressed and _touch == -1:
            _touch = t.index
            pressed = true
            queue_redraw()
            accept_event()
        elif not t.pressed and t.index == _touch:
            _release()
            accept_event()


func _release() -> void:
    _touch = -1
    pressed = false
    queue_redraw()


func _notification(what: int) -> void:
    if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
        _release()


func _draw() -> void:
    draw_style_box(_down if pressed else _up, Rect2(Vector2.ZERO, size))
    var c := size * 0.5
    var r := minf(size.x, size.y) * 0.22
    if shape == "left":
        draw_colored_polygon(PackedVector2Array([c + Vector2(-r, 0), c + Vector2(r, -r * 1.2), c + Vector2(r, r * 1.2)]), Color.WHITE)
    elif shape == "right":
        draw_colored_polygon(PackedVector2Array([c + Vector2(r, 0), c + Vector2(-r, -r * 1.2), c + Vector2(-r, r * 1.2)]), Color.WHITE)
    else:
        var fs := int(minf(size.y * 0.26, 32.0))
        draw_string(ThemeDB.fallback_font, Vector2(0.0, c.y + fs * 0.35), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color.WHITE)
