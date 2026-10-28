class_name LookPad
extends Control
## Transparent area: dragging a finger over it rotates the on-foot camera.

signal looked(delta_px: Vector2)

var _touch := -1


func _init() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var t := event as InputEventScreenTouch
        if t.pressed and _touch == -1:
            _touch = t.index
        elif not t.pressed and t.index == _touch:
            _touch = -1
    elif event is InputEventScreenDrag:
        var d := event as InputEventScreenDrag
        if d.index == _touch:
            looked.emit(d.relative)
