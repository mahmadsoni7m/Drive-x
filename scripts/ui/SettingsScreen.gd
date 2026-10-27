class_name SettingsScreen
extends Control

signal navigate(screen: String)

const QUALITY_NAMES: Array = ["LOW", "MEDIUM", "HIGH"]


func _ready() -> void:
    UIKit.full(self)
    refresh()


func _slider(key: String) -> HSlider:
    var s := HSlider.new()
    s.min_value = 0.0
    s.max_value = 1.0
    s.step = 0.05
    s.value = float(GameData.setting(key))
    s.custom_minimum_size = Vector2(380, 44)
    s.value_changed.connect(func(v: float) -> void:
        GameData.set_setting(key, v)
        AudioManager.apply_volumes())
    s.drag_ended.connect(func(_changed: bool) -> void: GameData.save_game())
    return s


func _row(title: String, control: Control) -> Control:
    var h := HBoxContainer.new()
    h.add_theme_constant_override("separation", 20)
    var l := UIKit.label(title, 28, UIKit.TEXT)
    l.custom_minimum_size = Vector2(300, 0)
    h.add_child(l)
    h.add_child(control)
    return h


func _cycle(key: String, names: Array, offset: int = 0) -> Button:
    var cur := clampi(int(GameData.setting(key)) - offset, 0, names.size() - 1)
    var next_value := ((cur + 1) % names.size()) + offset
    return UIKit.button(str(names[cur]), _apply.bind(key, next_value), Vector2(260, 56), 24)


func _toggle(key: String) -> Button:
    var on := bool(GameData.setting(key))
    return UIKit.button("ON" if on else "OFF", _apply.bind(key, not on), Vector2(260, 56), 24)


func _apply(key: String, value: Variant) -> void:
    GameData.set_setting(key, value)
    GameData.save_game()
    refresh()


func _back() -> void:
    GameData.save_game()
    navigate.emit("menu")


func refresh() -> void:
    for c in get_children():
        c.queue_free()
    var m := MarginContainer.new()
    UIKit.full(m)
    for side in ["left", "right", "top", "bottom"]:
        m.add_theme_constant_override("margin_" + side, 40)
    add_child(m)
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    m.add_child(scroll)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 14)
    v.custom_minimum_size = Vector2(900, 0)
    scroll.add_child(v)
    var top := HBoxContainer.new()
    top.add_theme_constant_override("separation", 20)
    top.add_child(UIKit.button("BACK", _back, Vector2(160, 60), 26))
    top.add_child(UIKit.label("SETTINGS", 44, UIKit.ACCENT))
    v.add_child(top)
    v.add_child(_row("MUSIC", _slider("music")))
    v.add_child(_row("SOUND FX", _slider("sfx")))
    v.add_child(_row("GRAPHICS", _cycle("quality", QUALITY_NAMES)))
    v.add_child(_row("DEFAULT CAMERA", _cycle("camera", CameraRig.MODES)))
    v.add_child(_row("OPPONENTS", _cycle("ai_count", ["1", "2", "3", "4", "5", "6", "7"], 1)))
    v.add_child(_row("TILT STEERING", _toggle("tilt")))
    v.add_child(_row("INVERT TILT", _toggle("tilt_invert")))
