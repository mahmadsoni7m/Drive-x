class_name GarageScreen
extends Control

signal navigate(screen: String)
signal preview(car: Dictionary)

var _i := 0
var _panel: VBoxContainer
var _toast: Label


func _ready() -> void:
    UIKit.full(self)
    _i = CarData.index_of(GameData.selected_id())
    var scroll := ScrollContainer.new()
    scroll.anchor_bottom = 1.0
    scroll.offset_left = 30.0
    scroll.offset_top = 20.0
    scroll.offset_right = 540.0
    scroll.offset_bottom = -20.0
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    add_child(scroll)
    _panel = VBoxContainer.new()
    _panel.add_theme_constant_override("separation", 8)
    _panel.custom_minimum_size = Vector2(490, 0)
    scroll.add_child(_panel)
    add_child(_corner_btn("<", -330.0, func() -> void: _browse(-1)))
    add_child(_corner_btn(">", -130.0, func() -> void: _browse(1)))
    _toast = UIKit.label("", 28, UIKit.GOOD, HORIZONTAL_ALIGNMENT_CENTER)
    _toast.anchor_left = 0.5
    _toast.anchor_right = 0.5
    _toast.offset_left = 0.0
    _toast.offset_right = 640.0
    _toast.offset_top = 24.0
    _toast.offset_bottom = 70.0
    add_child(_toast)
    refresh()


func _corner_btn(text: String, x: float, cb: Callable) -> Button:
    var b := UIKit.button(text, cb, Vector2(90, 90), 40)
    b.anchor_left = 1.0
    b.anchor_right = 1.0
    b.anchor_top = 1.0
    b.anchor_bottom = 1.0
    b.offset_left = x
    b.offset_right = x + 90.0
    b.offset_top = -130.0
    b.offset_bottom = -40.0
    return b


func _browse(d: int) -> void:
    _i = posmod(_i + d, CarData.cars().size())
    refresh()


func _notify(key: String, color: Color) -> void:
    _toast.text = Lang.t(key)
    _toast.add_theme_color_override("font_color", color)


func refresh() -> void:
    for c in _panel.get_children():
        c.queue_free()
    var car: Dictionary = CarData.cars()[_i]
    var id := str(car["id"])
    var owned := GameData.owns(id)
    preview.emit(car)
    var top := HBoxContainer.new()
    top.add_theme_constant_override("separation", 12)
    top.add_child(UIKit.button(Lang.t("common.back"), func() -> void: navigate.emit("menu"), Vector2(170, 56), 24))
    var coins := UIKit.label(Lang.t("common.coins", [GameData.coins()]), 24, Color(1.0, 0.85, 0.2), HORIZONTAL_ALIGNMENT_RIGHT)
    coins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(coins)
    _panel.add_child(top)
    _panel.add_child(UIKit.label(str(car["name"]), 44, UIKit.ACCENT))
    var lv: Dictionary = GameData.upgrades_of(id) if owned else {}
    var stats := CarData.stats_for(car, lv)
    var rows := [
        ["stat.speed", float(stats["top"]) / 95.0, UIKit.ACCENT],
        ["stat.accel", float(stats["accel"]) / 32.0, UIKit.GOOD],
        ["stat.handling", float(stats["handling"]) / 1.5, UIKit.CYAN],
        ["stat.nitro", float(stats["nitro"]) / 2.0, Color(0.8, 0.4, 1.0)],
    ]
    for r in rows:
        var h := HBoxContainer.new()
        var l := UIKit.label(Lang.t(str(r[0])), 22, UIKit.DIM)
        l.custom_minimum_size = Vector2(150, 0)
        h.add_child(l)
        var b := UIKit.bar(float(r[1]), r[2])
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        h.add_child(b)
        _panel.add_child(h)
    if not owned:
        var price := int(car["price"])
        var buy := UIKit.button(Lang.t("common.buy", [price]), func() -> void: _buy(id), Vector2(420, 66), 28)
        buy.disabled = GameData.coins() < price
        _panel.add_child(buy)
    else:
        var is_sel := GameData.selected_id() == id
        var sel := UIKit.button(Lang.t("common.selected") if is_sel else Lang.t("common.select"), func() -> void: _select(id), Vector2(420, 66), 28)
        sel.disabled = is_sel
        _panel.add_child(sel)
        _panel.add_child(UIKit.label(Lang.t("upg.title"), 24, UIKit.DIM))
        for key in CarData.UPGRADE_KEYS:
            _panel.add_child(_upgrade_row(id, str(key)))


func _upgrade_row(id: String, key: String) -> Control:
    var lvl := GameData.upgrade_level(id, key)
    var h := HBoxContainer.new()
    h.add_theme_constant_override("separation", 10)
    var l := UIKit.label("%s  %d/%d" % [Lang.t("upg." + key), lvl, CarData.MAX_UPGRADE], 22, UIKit.TEXT)
    l.custom_minimum_size = Vector2(230, 0)
    h.add_child(l)
    if lvl >= CarData.MAX_UPGRADE:
        h.add_child(UIKit.label(Lang.t("common.max"), 24, UIKit.GOOD))
    else:
        var cost := CarData.upgrade_cost(lvl)
        var b := UIKit.button(Lang.t("upg.buy", [cost]), func() -> void: _upgrade(id, key), Vector2(230, 52), 22)
        b.disabled = GameData.coins() < cost
        h.add_child(b)
    return h


func _buy(id: String) -> void:
    if GameData.buy_car(id):
        AudioManager.play("coin")
        _notify("common.bought", UIKit.GOOD)
    else:
        _notify("common.no_coins", UIKit.BAD)
    refresh()


func _select(id: String) -> void:
    GameData.select_car(id)
    _notify("common.selected", UIKit.CYAN)
    refresh()


func _upgrade(id: String, key: String) -> void:
    if GameData.buy_upgrade(id, key):
        AudioManager.play("boost")
        _notify("common.upgraded", UIKit.GOOD)
    else:
        _notify("common.no_coins", UIKit.BAD)
    refresh()
