class_name HUD
extends CanvasLayer
## In-race UI: telemetry, minimap, multi-touch controls, pause menu and results screen.

signal camera_pressed
signal reset_pressed
signal restart_pressed
signal quit_pressed

var _root: Control
var _lbl_pos: Label
var _lbl_lap: Label
var _lbl_time: Label
var _lbl_coins: Label
var _lbl_speed: Label
var _lbl_center: Label
var _lbl_flash: Label
var _lbl_wrong: Label
var _nitro_bar: ProgressBar
var _minimap: MiniMap
var _pause_panel: Control
var _results: Control
var _btn_left: TouchButton
var _btn_right: TouchButton
var _btn_gas: TouchButton
var _btn_brake: TouchButton
var _btn_nitro: TouchButton
var _btn_drift: TouchButton
var _flash_t := 0.0
var _center_t := 0.0
var _redraw_t := 0.0


func _ready() -> void:
    layer = 10
    process_mode = Node.PROCESS_MODE_ALWAYS
    _root = Control.new()
    UIKit.full(_root)
    _root.theme = UIKit.make_theme()
    _root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_root)
    _build()


func setup(info: TrackInfo, total_laps: int, racers: Array, player: Vehicle) -> void:
    _minimap.setup(info, racers, player)
    _lbl_lap.text = "LAP 1/%d" % total_laps


func _place(c: Control, anchor: Vector2, pos: Vector2, sz: Vector2) -> void:
    c.anchor_left = anchor.x
    c.anchor_right = anchor.x
    c.anchor_top = anchor.y
    c.anchor_bottom = anchor.y
    c.offset_left = pos.x
    c.offset_top = pos.y
    c.offset_right = pos.x + sz.x
    c.offset_bottom = pos.y + sz.y
    _root.add_child(c)


func _lbl(text: String, size: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
    var l := UIKit.label(text, size, color, align)
    l.add_theme_constant_override("outline_size", 6)
    l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
    return l


func _small_btn(text: String, cb: Callable) -> Button:
    var b := UIKit.button(text, cb, Vector2(80, 64), 22)
    return b


func _build() -> void:
    _lbl_pos = _lbl("POS 1/6", 44, UIKit.TEXT)
    _place(_lbl_pos, Vector2(0, 0), Vector2(24, 10), Vector2(280, 56))
    _lbl_lap = _lbl("LAP 1/3", 30, UIKit.CYAN)
    _place(_lbl_lap, Vector2(0, 0), Vector2(24, 64), Vector2(280, 40))
    _lbl_time = _lbl("0:00.00", 28, UIKit.DIM)
    _place(_lbl_time, Vector2(0, 0), Vector2(24, 100), Vector2(280, 36))
    _minimap = MiniMap.new()
    _place(_minimap, Vector2(0, 0), Vector2(24, 144), Vector2(170, 170))

    _lbl_coins = _lbl("+0", 30, Color(1.0, 0.85, 0.2), HORIZONTAL_ALIGNMENT_RIGHT)
    _place(_lbl_coins, Vector2(1, 0), Vector2(-420, 28), Vector2(150, 40))
    _place(_small_btn("CAM", func() -> void: camera_pressed.emit()), Vector2(1, 0), Vector2(-270, 18), Vector2(80, 64))
    _place(_small_btn("RST", func() -> void: reset_pressed.emit()), Vector2(1, 0), Vector2(-180, 18), Vector2(80, 64))
    _place(_small_btn("II", func() -> void: set_paused(true)), Vector2(1, 0), Vector2(-90, 18), Vector2(70, 64))

    _lbl_speed = _lbl("0", 72, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
    _place(_lbl_speed, Vector2(0.5, 1), Vector2(-110, -150), Vector2(220, 90))
    var unit := _lbl("KM/H", 22, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER)
    _place(unit, Vector2(0.5, 1), Vector2(-110, -66), Vector2(220, 28))
    _nitro_bar = UIKit.bar(1.0, UIKit.CYAN)
    _nitro_bar.custom_minimum_size = Vector2(300, 18)
    _place(_nitro_bar, Vector2(0.5, 1), Vector2(-150, -34), Vector2(300, 18))

    _lbl_center = _lbl("", 120, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
    _lbl_center.add_theme_constant_override("outline_size", 14)
    _place(_lbl_center, Vector2(0.5, 0.4), Vector2(-320, -100), Vector2(640, 200))
    _lbl_flash = _lbl("", 44, UIKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
    _place(_lbl_flash, Vector2(0.5, 0.18), Vector2(-360, 0), Vector2(720, 60))
    _lbl_wrong = _lbl("WRONG WAY", 56, UIKit.BAD, HORIZONTAL_ALIGNMENT_CENTER)
    _lbl_wrong.visible = false
    _place(_lbl_wrong, Vector2(0.5, 0.3), Vector2(-320, 0), Vector2(640, 80))

    _btn_left = TouchButton.new("", Color(0.6, 0.8, 1.0), "left")
    _place(_btn_left, Vector2(0, 1), Vector2(30, -200), Vector2(170, 170))
    _btn_right = TouchButton.new("", Color(0.6, 0.8, 1.0), "right")
    _place(_btn_right, Vector2(0, 1), Vector2(215, -200), Vector2(170, 170))
    _btn_gas = TouchButton.new("GAS", UIKit.GOOD)
    _place(_btn_gas, Vector2(1, 1), Vector2(-220, -240), Vector2(190, 210))
    _btn_brake = TouchButton.new("BRAKE", UIKit.BAD)
    _place(_btn_brake, Vector2(1, 1), Vector2(-420, -180), Vector2(180, 150))
    _btn_nitro = TouchButton.new("NITRO", UIKit.CYAN)
    _place(_btn_nitro, Vector2(1, 1), Vector2(-200, -400), Vector2(150, 140))
    _btn_drift = TouchButton.new("DRIFT", UIKit.ACCENT)
    _place(_btn_drift, Vector2(1, 1), Vector2(-390, -340), Vector2(150, 140))

    _build_pause()


func _build_pause() -> void:
    _pause_panel = Control.new()
    UIKit.full(_pause_panel)
    _pause_panel.visible = false
    _root.add_child(_pause_panel)
    var dim := ColorRect.new()
    UIKit.full(dim)
    dim.color = Color(0, 0, 0, 0.65)
    _pause_panel.add_child(dim)
    var center := CenterContainer.new()
    UIKit.full(center)
    _pause_panel.add_child(center)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 14)
    center.add_child(box)
    box.add_child(UIKit.label("PAUSED", 64, UIKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
    box.add_child(UIKit.button("RESUME", func() -> void: set_paused(false)))
    box.add_child(UIKit.button("RESTART", func() -> void:
        get_tree().paused = false
        restart_pressed.emit()))
    box.add_child(UIKit.button("QUIT TO MENU", func() -> void:
        get_tree().paused = false
        quit_pressed.emit()))


func set_paused(p: bool) -> void:
    if _results != null and _results.visible and p:
        return
    get_tree().paused = p
    _pause_panel.visible = p
    AudioManager.pause_engine(p)


func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        var k := (event as InputEventKey).keycode
        if k == KEY_ESCAPE or k == KEY_P:
            set_paused(not get_tree().paused)
        elif k == KEY_C:
            camera_pressed.emit()
        elif k == KEY_R:
            reset_pressed.emit()


func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST:
        set_paused(not get_tree().paused)


# --- input state for the race controller ------------------------------------------------
func steer_axis() -> float:
    return (1.0 if _btn_right.pressed else 0.0) - (1.0 if _btn_left.pressed else 0.0)


func gas() -> bool:
    return _btn_gas.pressed


func brake() -> bool:
    return _btn_brake.pressed


func nitro_held() -> bool:
    return _btn_nitro.pressed


func drift_held() -> bool:
    return _btn_drift.pressed


# --- feedback ---------------------------------------------------------------------------------
func set_countdown(text: String, secs: float = 1.2) -> void:
    _lbl_center.text = text
    _center_t = secs


func flash(text: String, secs: float = 1.8) -> void:
    _lbl_flash.text = text
    _flash_t = secs


func update_hud(p: Vehicle, pos: int, total: int, lap: int, laps: int, time: float, coins: int) -> void:
    _lbl_pos.text = "POS %d/%d" % [pos, total]
    _lbl_lap.text = "LAP %d/%d" % [clampi(lap, 1, laps), laps]
    _lbl_time.text = UIKit.fmt_time(time)
    _lbl_coins.text = "+%d" % coins
    _lbl_speed.text = str(int(p.speed_kmh))
    _nitro_bar.value = p.nitro
    _lbl_wrong.visible = p.wrong_way
    _redraw_t -= get_process_delta_time()
    if _redraw_t <= 0.0:
        _redraw_t = 0.08
        _minimap.queue_redraw()


func _process(delta: float) -> void:
    if _center_t > 0.0:
        _center_t -= delta
        if _center_t <= 0.0:
            _lbl_center.text = ""
    if _flash_t > 0.0:
        _flash_t -= delta
        if _flash_t <= 0.0:
            _lbl_flash.text = ""


func show_results(d: Dictionary) -> void:
    _results = Control.new()
    UIKit.full(_results)
    _root.add_child(_results)
    var dim := ColorRect.new()
    UIKit.full(dim)
    dim.color = Color(0, 0, 0, 0.7)
    _results.add_child(dim)
    var center := CenterContainer.new()
    UIKit.full(center)
    _results.add_child(center)
    var panel := PanelContainer.new()
    center.add_child(panel)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 10)
    panel.add_child(box)
    var place := int(d["position"])
    var title := "FINISHED!" if place > 1 else "VICTORY!"
    box.add_child(UIKit.label(title, 60, UIKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
    box.add_child(UIKit.label("POSITION  %d / %d" % [place, int(d["total"])], 40, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
    box.add_child(UIKit.label("TIME  %s" % UIKit.fmt_time(float(d["time"])), 30, UIKit.CYAN, HORIZONTAL_ALIGNMENT_CENTER))
    box.add_child(UIKit.label("BEST LAP  %s" % UIKit.fmt_time(float(d["best_lap"])), 28, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
    box.add_child(UIKit.label("COINS  +%d  (reward %d + pickups %d)" % [int(d["reward"]) + int(d["picked"]), int(d["reward"]), int(d["picked"])], 28, Color(1.0, 0.85, 0.2), HORIZONTAL_ALIGNMENT_CENTER))
    if str(d.get("unlocked", "")) != "":
        box.add_child(UIKit.label("UNLOCKED: %s" % str(d["unlocked"]), 28, UIKit.GOOD, HORIZONTAL_ALIGNMENT_CENTER))
    box.add_child(UIKit.button("RACE AGAIN", func() -> void: restart_pressed.emit()))
    box.add_child(UIKit.button("MENU", func() -> void: quit_pressed.emit()))
