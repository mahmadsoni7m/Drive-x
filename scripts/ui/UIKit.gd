class_name UIKit
extends RefCounted
## Shared UI palette, theme and small widget helpers (all UI is built in code).

const BG := Color("0a0e1a")
const ACCENT := Color("ff6a1a")
const CYAN := Color("19d3ff")
const TEXT := Color("f2f5ff")
const DIM := Color("8a93b2")
const GOOD := Color("3ddc84")
const BAD := Color("ff4d5e")


static func flat(color: Color, radius: int = 14, border: Color = Color(0, 0, 0, 0), bw: int = 0) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = color
    s.set_corner_radius_all(radius)
    s.border_color = border
    s.set_border_width_all(bw)
    s.content_margin_left = 18.0
    s.content_margin_right = 18.0
    s.content_margin_top = 10.0
    s.content_margin_bottom = 10.0
    return s


static func make_theme() -> Theme:
    var t := Theme.new()
    t.default_font_size = 26
    t.set_stylebox("normal", "Button", flat(Color(0.14, 0.17, 0.28, 0.95), 14, Color(1, 1, 1, 0.14), 2))
    t.set_stylebox("hover", "Button", flat(Color(0.2, 0.24, 0.38, 0.98), 14, CYAN, 2))
    t.set_stylebox("pressed", "Button", flat(ACCENT, 14, Color(1, 1, 1, 0.5), 2))
    t.set_stylebox("disabled", "Button", flat(Color(0.1, 0.11, 0.17, 0.8), 14, Color(1, 1, 1, 0.06), 2))
    t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
    t.set_color("font_color", "Button", TEXT)
    t.set_color("font_hover_color", "Button", TEXT)
    t.set_color("font_pressed_color", "Button", Color.WHITE)
    t.set_color("font_disabled_color", "Button", DIM)
    t.set_color("font_color", "Label", TEXT)
    t.set_stylebox("background", "ProgressBar", flat(Color(1, 1, 1, 0.12), 6))
    t.set_stylebox("fill", "ProgressBar", flat(ACCENT, 6))
    t.set_stylebox("panel", "PanelContainer", flat(Color(0.05, 0.07, 0.14, 0.82), 18, Color(1, 1, 1, 0.1), 2))
    t.set_stylebox("slider", "HSlider", flat(Color(1, 1, 1, 0.15), 5))
    t.set_stylebox("grabber_area", "HSlider", flat(ACCENT, 5))
    t.set_stylebox("grabber_area_highlight", "HSlider", flat(ACCENT, 5))
    return t


static func full(c: Control) -> void:
    c.anchor_left = 0.0
    c.anchor_top = 0.0
    c.anchor_right = 1.0
    c.anchor_bottom = 1.0
    c.offset_left = 0.0
    c.offset_top = 0.0
    c.offset_right = 0.0
    c.offset_bottom = 0.0
    c.grow_horizontal = Control.GROW_DIRECTION_BOTH
    c.grow_vertical = Control.GROW_DIRECTION_BOTH


static func label(text: String, size: int = 26, color: Color = TEXT, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
    var l := Label.new()
    l.text = text
    l.horizontal_alignment = align
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return l


static func button(text: String, cb: Callable, min_size: Vector2 = Vector2(300, 64), font_size: int = 28) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = min_size
    b.add_theme_font_size_override("font_size", font_size)
    b.pressed.connect(func() -> void:
        AudioManager.play("click")
        cb.call()
    )
    return b


static func bar(value: float, color: Color = ACCENT) -> ProgressBar:
    var p := ProgressBar.new()
    p.min_value = 0.0
    p.max_value = 1.0
    p.value = clampf(value, 0.0, 1.0)
    p.show_percentage = false
    p.custom_minimum_size = Vector2(220, 16)
    p.add_theme_stylebox_override("fill", flat(color, 6))
    return p


static func fmt_time(t: float) -> String:
    if t <= 0.0 or is_inf(t):
        return "--:--.--"
    var m := int(t / 60.0)
    var s := t - float(m) * 60.0
    return "%d:%05.2f" % [m, s]
