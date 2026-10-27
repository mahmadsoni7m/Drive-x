class_name MenuScreen
extends Control

signal navigate(screen: String)

var _coins: Label


func _ready() -> void:
    UIKit.full(self)
    var m := MarginContainer.new()
    UIKit.full(m)
    m.add_theme_constant_override("margin_left", 70)
    m.add_theme_constant_override("margin_top", 40)
    m.add_theme_constant_override("margin_bottom", 40)
    add_child(m)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 16)
    v.alignment = BoxContainer.ALIGNMENT_CENTER
    m.add_child(v)
    v.add_child(UIKit.label("DRIVE X", 120, UIKit.ACCENT))
    v.add_child(UIKit.label("ARCADE RACING", 28, UIKit.CYAN))
    var gap := Control.new()
    gap.custom_minimum_size = Vector2(0, 18)
    v.add_child(gap)
    for entry in [["RACE", "tracks"], ["GARAGE", "garage"], ["SETTINGS", "settings"]]:
        var target: String = entry[1]
        var b := UIKit.button(entry[0], func() -> void: navigate.emit(target), Vector2(380, 74), 32)
        b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
        v.add_child(b)
    if OS.get_name() != "Android" and OS.get_name() != "iOS":
        var q := UIKit.button("QUIT", func() -> void: get_tree().quit(), Vector2(380, 74), 32)
        q.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
        v.add_child(q)
    _coins = UIKit.label("", 32, Color(1.0, 0.85, 0.2), HORIZONTAL_ALIGNMENT_RIGHT)
    _coins.anchor_left = 1.0
    _coins.anchor_right = 1.0
    _coins.offset_left = -360.0
    _coins.offset_right = -30.0
    _coins.offset_top = 24.0
    _coins.offset_bottom = 70.0
    add_child(_coins)
    refresh()


func refresh() -> void:
    _coins.text = "COINS  %d" % GameData.coins()
