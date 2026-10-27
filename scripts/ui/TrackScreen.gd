class_name TrackScreen
extends Control

signal navigate(screen: String)

var _holder: VBoxContainer


func _ready() -> void:
    UIKit.full(self)
    _holder = VBoxContainer.new()
    _holder.add_theme_constant_override("separation", 14)
    var m := MarginContainer.new()
    UIKit.full(m)
    for side in ["left", "right", "top", "bottom"]:
        m.add_theme_constant_override("margin_" + side, 36)
    add_child(m)
    m.add_child(_holder)
    refresh()


func refresh() -> void:
    for c in _holder.get_children():
        c.queue_free()
    var top := HBoxContainer.new()
    top.add_theme_constant_override("separation", 20)
    top.add_child(UIKit.button("BACK", func() -> void: navigate.emit("menu"), Vector2(160, 60), 26))
    var title := UIKit.label("SELECT TRACK", 44, UIKit.ACCENT)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(title)
    top.add_child(UIKit.label("COINS  %d" % GameData.coins(), 28, Color(1.0, 0.85, 0.2), HORIZONTAL_ALIGNMENT_RIGHT))
    _holder.add_child(top)

    var laps_row := HBoxContainer.new()
    laps_row.add_theme_constant_override("separation", 16)
    laps_row.alignment = BoxContainer.ALIGNMENT_CENTER
    var laps := int(GameData.setting("laps"))
    laps_row.add_child(UIKit.button("-", func() -> void: _set_laps(laps - 1), Vector2(70, 56), 30))
    laps_row.add_child(UIKit.label("LAPS  %d" % laps, 30, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
    laps_row.add_child(UIKit.button("+", func() -> void: _set_laps(laps + 1), Vector2(70, 56), 30))
    _holder.add_child(laps_row)

    var cards := HBoxContainer.new()
    cards.add_theme_constant_override("separation", 18)
    cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _holder.add_child(cards)
    for i in TrackData.count():
        cards.add_child(_card(i))


func _set_laps(v: int) -> void:
    GameData.set_setting("laps", clampi(v, 1, 10))
    GameData.save_game()
    refresh()


func _card(i: int) -> Control:
    var td := TrackData.get_track(i)
    var unlocked := GameData.is_unlocked(i)
    var p := PanelContainer.new()
    p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 10)
    p.add_child(v)
    v.add_child(UIKit.label(str(td["name"]), 34, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
    v.add_child(UIKit.label("LENGTH  %.1f km" % (TrackData.length_m(i) / 1000.0), 24, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
    v.add_child(UIKit.label("DIFFICULTY  %d / 3" % int(td["difficulty"]), 24, UIKit.CYAN, HORIZONTAL_ALIGNMENT_CENTER))
    v.add_child(UIKit.label("BEST  %s" % UIKit.fmt_time(GameData.best_lap(i)), 24, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
    var spacer := Control.new()
    spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    v.add_child(spacer)
    if unlocked:
        v.add_child(UIKit.button("START", func() -> void: _start(i), Vector2(200, 70), 30))
    else:
        v.add_child(UIKit.label("LOCKED", 30, UIKit.BAD, HORIZONTAL_ALIGNMENT_CENTER))
        v.add_child(UIKit.label("Finish top 3 on the previous track", 20, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
    return p


func _start(i: int) -> void:
    GameData.selected_track = i
    GameData.save_game()
    get_tree().change_scene_to_file("res://scenes/Race.tscn")
