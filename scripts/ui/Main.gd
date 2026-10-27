extends Control
## Menu root: persistent 3D showroom + swappable screens.

var _screens: Dictionary = {}
var _showroom: Showroom
var _current := "menu"


func _ready() -> void:
    UIKit.full(self)
    theme = UIKit.make_theme()
    get_tree().paused = false
    _showroom = Showroom.new()
    add_child(_showroom)
    _showroom.show_car(CarData.by_id(GameData.selected_id()))

    var menu := MenuScreen.new()
    var tracks := TrackScreen.new()
    var garage := GarageScreen.new()
    var settings := SettingsScreen.new()
    _screens = {"menu": menu, "tracks": tracks, "garage": garage, "settings": settings}
    for name in _screens:
        var s: Control = _screens[name]
        s.navigate.connect(show_screen)
        add_child(s)
    garage.preview.connect(func(car: Dictionary) -> void: _showroom.show_car(car))
    show_screen("menu")


func show_screen(name: String) -> void:
    if not _screens.has(name):
        push_warning("Main: unknown screen '%s'" % name)
        return
    _current = name
    for k in _screens:
        (_screens[k] as Control).visible = (k == name)
    if _screens[name].has_method("refresh"):
        _screens[name].refresh()
    _showroom.set_shift(0.0)
    if name == "menu":
        _showroom.show_car(CarData.by_id(GameData.selected_id()))
        _showroom.set_shift(-1.6)
    elif name == "garage":
        _showroom.set_shift(-2.2)
    elif name == "tracks" or name == "settings":
        _showroom.set_shift(0.0)


func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST:
        if _current != "menu":
            show_screen("menu")
        else:
            GameData.flush()
            get_tree().quit()
