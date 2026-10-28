class_name SettingsScreen
extends Control


signal navigate(screen: String)


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
    var l := UIKit.label(title, 26, UIKit.TEXT)
    l.custom_minimum_size = Vector2(420, 0)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    h.add_child(l)
    h.add_child(control)
    return h


func _cycle(key: String, names: Array) -> Button:
    var cur := clampi(int(GameData.setting(key)), 0, names.size() - 1)
    var nxt := (cur + 1) % names.size()
    return UIKit.button(str(names[cur]), _apply.bind(key, nxt), Vector2(260, 56), 24)


func _toggle(key: String) -> Button:
    var on := bool(GameData.setting(key))
    return UIKit.button(Lang.t("settings.on") if on else Lang.t("settings.off"), _apply.bind(key, not on), Vector2(260, 56), 24)


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
    v.custom_minimum_size = Vector2(980, 0)
    scroll.add_child(v)
    var top := HBoxContainer.new()
    top.add_theme_constant_override("separation", 20)
    top.add_child(UIKit.button(Lang.t("common.back"), _back, Vector2(180, 60), 26))
    top.add_child(UIKit.label(Lang.t("settings.title"), 44, UIKit.ACCENT))
    v.add_child(top)
    v.add_child(_row(Lang.t("settings.music"), _slider("music")))
    v.add_child(_row(Lang.t("settings.sfx"), _slider("sfx")))
    v.add_child(_row(Lang.t("settings.graphics"), _cycle("quality", [Lang.t("settings.q0"), Lang.t("settings.q1"), Lang.t("settings.q2")])))
    v.add_child(_row(Lang.t("settings.camera"), _cycle("camera", [Lang.t("cam.chase"), Lang.t("cam.far"), Lang.t("cam.hood"), Lang.t("cam.top")])))
    v.add_child(_row(Lang.t("settings.tilt"), _toggle("tilt")))
    v.add_child(_row(Lang.t("settings.tilt_invert"), _toggle("tilt_invert")))
