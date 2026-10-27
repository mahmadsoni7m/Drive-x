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
    scroll.offset_right = 520.0
    scroll.offset_bottom = -20.0
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    add_child(scroll)
    _panel = VBoxContainer.new()
    _panel.add_theme_constant_override("separation", 8)
    _panel.custom_minimum_size = Vector2(470, 0)
    scroll.add_child(_panel)
    var prev := UIKit.button("<", func() -> void: _browse(-1), Vector2(90, 90), 40)
    prev.anchor_left = 1.0
    prev.anchor_right = 1.0
    prev.anchor_top = 1.0
    prev.anchor_bottom = 1.0
    prev.offset_left = -330.0
    prev.offset_right = -240.0
    prev.offset_top = -130.0
    prev.offset_bottom = -40.0
    add_child(prev)
    var nxt := UIKit.button(">", func() -> void: _browse(1), Vector2(90, 90), 40)
    nxt.anchor_left = 1.0
    nxt.anchor_right = 1.0
    nxt.anchor_top = 1.0
    nxt.anchor_bottom = 1.0
    nxt.offset_left = -130.0
    nxt.offset_right = -40.0
    nxt.offset_top = -130.0
    nxt.offset_bottom = -40.0
    add_child(nxt)
    _toast = UIKit.label("", 28, UIKit.GOOD, HORIZONTAL_ALIGNMENT_CENTER)
    _toast.anchor_left = 0.5
    _toast.anchor_right = 0.5
    _toast.offset_left = -40.0
    _toast.offset_right = 640.0
    _toast.offset_top = 24.0
    _toast.offset_bottom = 70.0
    add_child(_toast)
    refresh()


func _browse(d: int) -> void:
    AudioManager.play("click")
    _i = posmod(_i + d, CarData.cars().size())
    refresh()


func _notify(text: String, color: Color) -> void:
    _toast.text = text
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
    top.add_child(UIKit.button("BACK", func() -> void: navigate.emit("menu"), Vector2(140, 56), 24))
    var coins := UIKit.label("COINS %d" % GameData.coins(), 26, Color(1.0, 0.85, 0.2), HORIZONTAL_ALIGNMENT_RIGHT)
    coins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(coins)
    _panel.add_child(top)
    _panel.add_child(UIKit.label(str(car["name"]), 46, UIKit.ACCENT))

    var stats := CarData.stats_for(car, GameData.upgrades_of(id) if owned else {})
    var rows := [
        ["SPEED", float(stats["top"]) / 95.0, UIKit.ACCENT],
        ["ACCEL", float(stats["accel"]) / 32.0, UIKit.GOOD],
        ["HANDLING", float(stats["handling"]) / 1.5, UIKit.CYAN],
        ["NITRO", float(stats["nitro"]) / 2.0, Color(0.8, 0.4, 1.0)],
    ]
    for r in rows:
        var h := HBoxContainer.new()
        var l := UIKit.label(r[0], 22, UIKit.DIM)
        l.custom_minimum_size = Vector2(130, 0)
        h.add_child(l)
        var b := UIKit.bar(r[1], r[2])
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        h.add_child(b)
        _panel.add_child(h)

    if not owned:
        var price := int(car["price"])
        var buy := UIKit.button("BUY  %d" % price, func() -> void: _buy(id), Vector2(400, 66), 28)
        buy.disabled = GameData.coins() < price
        _panel.add_child(buy)
    else:
        var sel := UIKit.button("SELECTED" if GameData.selected_id() == id else "SELECT", func() -> void: _select(id), Vector2(400, 66), 28)
        sel.disabled = GameData.selected_id() == id
        _panel.add_child(sel)
        _panel.add_child(UIKit.label("UPGRADES", 24, UIKit.DIM))
        for key in CarData.UPGRADE_KEYS:
            _panel.add_child(_upgrade_row(id, str(key)))


func _upgrade_row(id: String, key: String) -> Control:
    var lvl := GameData.upgrade_level(id, key)
    var h := HBoxContainer.new()
    h.add_theme_constant_override("separation", 10)
    var l := UIKit.label("%s  %d/%d" % [CarData.UPGRADE_NAMES[key], lvl, CarData.MAX_UPGRADE], 22, UIKit.TEXT)
    l.custom_minimum_size = Vector2(200, 0)
    h.add_child(l)
    if lvl >= CarData.MAX_UPGRADE:
        h.add_child(UIKit.label("MAX", 24, UIKit.GOOD))
    else:
        var cost := CarData.upgrade_cost(lvl)
        var b := UIKit.button("UPGRADE  %d" % cost, func() -> void: _upgrade(id, key), Vector2(230, 52), 22)
        b.disabled = GameData.coins() < cost
        h.add_child(b)
    return h


func _buy(id: String) -> void:
    if GameData.buy_car(id):
        AudioManager.play("coin")
        _notify("PURCHASED", UIKit.GOOD)
    else:
        _notify("NOT ENOUGH COINS", UIKit.BAD)
    refresh()


func _select(id: String) -> void:
    GameData.select_car(id)
    _notify("CAR SELECTED", UIKit.CYAN)
    refresh()


func _upgrade(id: String, key: String) -> void:
    if GameData.buy_upgrade(id, key):
        AudioManager.play("boost")
        _notify("UPGRADED", UIKit.GOOD)
    else:
        _notify("NOT ENOUGH COINS", UIKit.BAD)
    refresh()
