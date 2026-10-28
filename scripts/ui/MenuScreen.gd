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
    v.add_child(UIKit.label(Lang.t("menu.title"), 120, UIKit.ACCENT))
    v.add_child(UIKit.label(Lang.t("menu.subtitle"), 26, UIKit.CYAN))
    var gap := Control.new()
    gap.custom_minimum_size = Vector2(0, 14)
    v.add_child(gap)
    v.add_child(_btn(Lang.t("menu.play"), func() -> void: get_tree().change_scene_to_file("res://scenes/Game.tscn")))
    v.add_child(_btn(Lang.t("menu.garage"), func() -> void: navigate.emit("garage")))
    v.add_child(_btn(Lang.t("menu.wardrobe"), func() -> void: navigate.emit("wardrobe")))
    v.add_child(_btn(Lang.t("menu.settings"), func() -> void: navigate.emit("settings")))
    if OS.get_name() != "Android" and OS.get_name() != "iOS":
        v.add_child(_btn(Lang.t("menu.quit"), func() -> void: get_tree().quit()))
    _coins = UIKit.label("", 32, Color(1.0, 0.85, 0.2), HORIZONTAL_ALIGNMENT_RIGHT)
    _coins.anchor_left = 1.0
    _coins.anchor_right = 1.0
    _coins.offset_left = -460.0
    _coins.offset_right = -30.0
    _coins.offset_top = 24.0
    _coins.offset_bottom = 70.0
    add_child(_coins)
    refresh()


func _btn(text: String, cb: Callable) -> Button:
    var b := UIKit.button(text, cb, Vector2(400, 74), 32)
    b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    return b


func refresh() -> void:
    _coins.text = Lang.t("common.coins", [GameData.coins()])
