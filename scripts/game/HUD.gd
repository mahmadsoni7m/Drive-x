class_name HUD
extends CanvasLayer
## All in-game UI: foot controls (stick, punch, kick, block, enter), car controls
## (steer, gas, brake, nitro, drift, exit), minimap, race panel, pause and results.

signal camera_pressed
signal reset_pressed
signal enter_pressed
signal exit_pressed
signal punch_pressed
signal kick_pressed
signal look_moved(delta_px: Vector2)
signal results_closed
signal quit_pressed

var minimap: MiniMap
var _root: Control
var _foot: Control
var _car: Control
var _lbl_coins: Label
var _lbl_speed: Label
var _lbl_center: Label
var _lbl_flash: Label
var _lbl_hint: Label
var _lbl_wrong: Label
var _race_panel: Control
var _lbl_pos: Label
var _lbl_lap: Label
var _lbl_time: Label
var _health: ProgressBar
var _nitro: ProgressBar
var _stick: Joystick
var _b_punch: TouchButton
var _b_kick: TouchButton
var _b_block: TouchButton
var _b_enter: TouchButton
var _b_exit: TouchButton
var _b_left: TouchButton
var _b_right: TouchButton
var _b_gas: TouchButton
var _b_brake: TouchButton
var _b_nitro: TouchButton
var _b_drift: TouchButton
var _pause: Control
var _results: Control
var _prev := {}
var _flash_t := 0.0
var _center_t := 0.0
var _hint_t := 0.0
var _map_t := 0.0


func _ready() -> void:
    layer = 10
    process_mode = Node.PROCESS_MODE_ALWAYS
    _root = Control.new()
    UIKit.full(_root)
    _root.theme = UIKit.make_theme()
    _root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_root)
    _build()
    set_mode("foot")


func _place(parent: Control, c: Control, anchor: Vector2, pos: Vector2, sz: Vector2) -> void:
    c.anchor_left = anchor.x
    c.anchor_right = anchor.x
    c.anchor_top = anchor.y
    c.anchor_bottom = anchor.y
    c.offset_left = pos.x
    c.offset_top = pos.y
    c.offset_right = pos.x + sz.x
    c.offset_bottom = pos.y + sz.y
    parent.add_child(c)


func _lbl(text: String, size: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
    var l := UIKit.label(text, size, color, align)
    l.add_theme_constant_override("outline_size", 6)
    l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
    return l


func _layer() -> Control:
    var c := Control.new()
    UIKit.full(c)
    c.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.add_child(c)
    return c


func _build() -> void:
    var pad := LookPad.new()
    UIKit.full(pad)
    pad.anchor_left = 0.4
    pad.offset_left = 0.0
    pad.looked.connect(func(d: Vector2) -> void: look_moved.emit(d))
    _root.add_child(pad)

    _foot = _layer()
    _car = _layer()
    var top := _layer()

    _lbl_coins = _lbl("", 30, Color(1.0, 0.85, 0.2))
    _place(top, _lbl_coins, Vector2(0, 0), Vector2(24, 10), Vector2(360, 40))
    _health = UIKit.bar(1.0, UIKit.BAD)
    _health.custom_minimum_size = Vector2(220, 16)
    _place(_foot, _health, Vector2(0, 0), Vector2(24, 54), Vector2(220, 16))
    minimap = MiniMap.new()
    _place(top, minimap, Vector2(0, 0), Vector2(24, 82), Vector2(170, 170))
    _place(top, UIKit.button(Lang.t("btn.cam"), func() -> void: camera_pressed.emit(), Vector2(90, 64), 22), Vector2(1, 0), Vector2(-290, 18), Vector2(90, 64))
    _place(top, UIKit.button(Lang.t("btn.reset"), func() -> void: reset_pressed.emit(), Vector2(90, 64), 22), Vector2(1, 0), Vector2(-195, 18), Vector2(90, 64))
    _place(top, UIKit.button("II", func() -> void: set_paused(true), Vector2(80, 64), 24), Vector2(1, 0), Vector2(-100, 18), Vector2(80, 64))

    _race_panel = _layer()
    _lbl_pos = _lbl("", 40, UIKit.TEXT)
    _place(_race_panel, _lbl_pos, Vector2(0, 0), Vector2(220, 8), Vector2(300, 50))
    _lbl_lap = _lbl("", 28, UIKit.CYAN)
    _place(_race_panel, _lbl_lap, Vector2(0, 0), Vector2(220, 56), Vector2(300, 36))
    _lbl_time = _lbl("", 26, UIKit.DIM)
    _place(_race_panel, _lbl_time, Vector2(0, 0), Vector2(220, 90), Vector2(300, 34))
    _race_panel.visible = false

    _lbl_center = _lbl("", 120, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
    _place(top, _lbl_center, Vector2(0.5, 0.4), Vector2(-320, -100), Vector2(640, 200))
    _lbl_flash = _lbl("", 40, UIKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
    _place(top, _lbl_flash, Vector2(0.5, 0.16), Vector2(-420, 0), Vector2(840, 56))
    _lbl_hint = _lbl("", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
    _lbl_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _place(top, _lbl_hint, Vector2(0.5, 0.0), Vector2(-330, 90), Vector2(660, 90))
    _lbl_wrong = _lbl(Lang.t("race.wrong"), 52, UIKit.BAD, HORIZONTAL_ALIGNMENT_CENTER)
    _lbl_wrong.visible = false
    _place(top, _lbl_wrong, Vector2(0.5, 0.3), Vector2(-320, 0), Vector2(640, 70))

    # --- on foot
    _stick = Joystick.new()
    _place(_foot, _stick, Vector2(0, 1), Vector2(40, -250), Vector2(210, 210))
    _b_punch = TouchButton.new(Lang.t("btn.punch"), UIKit.ACCENT)
    _place(_foot, _b_punch, Vector2(1, 1), Vector2(-250, -250), Vector2(210, 200))
    _b_kick = TouchButton.new(Lang.t("btn.kick"), UIKit.BAD)
    _place(_foot, _b_kick, Vector2(1, 1), Vector2(-440, -170), Vector2(170, 140))
    _b_block = TouchButton.new(Lang.t("btn.block"), UIKit.CYAN)
    _place(_foot, _b_block, Vector2(1, 1), Vector2(-440, -330), Vector2(170, 140))
    _b_enter = TouchButton.new(Lang.t("btn.enter"), UIKit.GOOD)
    _place(_foot, _b_enter, Vector2(1, 1), Vector2(-250, -440), Vector2(210, 100))
    _b_enter.visible = false

    # --- driving
    _b_left = TouchButton.new("", Color(0.6, 0.8, 1.0), "left")
    _place(_car, _b_left, Vector2(0, 1), Vector2(30, -200), Vector2(170, 170))
    _b_right = TouchButton.new("", Color(0.6, 0.8, 1.0), "right")
    _place(_car, _b_right, Vector2(0, 1), Vector2(215, -200), Vector2(170, 170))
    _b_gas = TouchButton.new(Lang.t("btn.gas"), UIKit.GOOD)
    _place(_car, _b_gas, Vector2(1, 1), Vector2(-220, -240), Vector2(190, 210))
    _b_brake = TouchButton.new(Lang.t("btn.brake"), UIKit.BAD)
    _place(_car, _b_brake, Vector2(1, 1), Vector2(-420, -180), Vector2(180, 150))
    _b_nitro = TouchButton.new(Lang.t("btn.nitro"), UIKit.CYAN)
    _place(_car, _b_nitro, Vector2(1, 1), Vector2(-200, -400), Vector2(150, 140))
    _b_drift = TouchButton.new(Lang.t("btn.drift"), UIKit.ACCENT)
    _place(_car, _b_drift, Vector2(1, 1), Vector2(-390, -340), Vector2(150, 140))
    _b_exit = TouchButton.new(Lang.t("btn.exit"), Color(0.8, 0.8, 0.9))
    _place(_car, _b_exit, Vector2(0, 1), Vector2(400, -150), Vector2(120, 100))
    _lbl_speed = _lbl("0", 68, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
    _place(_car, _lbl_speed, Vector2(0.5, 1), Vector2(-110, -150), Vector2(220, 86))
    _place(_car, _lbl(Lang.t("hud.kmh"), 22, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0.5, 1), Vector2(-110, -66), Vector2(220, 28))
    _nitro = UIKit.bar(1.0, UIKit.CYAN)
    _nitro.custom_minimum_size = Vector2(300, 18)
    _place(_car, _nitro, Vector2(0.5, 1), Vector2(-150, -34), Vector2(300, 18))
    _build_pause()


func _build_pause() -> void:
    _pause = Control.new()
    UIKit.full(_pause)
    _pause.visible = false
    _root.add_child(_pause)
    var dim := ColorRect.new()
    UIKit.full(dim)
    dim.color = Color(0, 0, 0, 0.65)
    _pause.add_child(dim)
    var center := CenterContainer.new()
    UIKit.full(center)
    _pause.add_child(center)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 14)
    center.add_child(box)
    box.add_child(UIKit.label(Lang.t("pause.title"), 64, UIKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
    box.add_child(UIKit.button(Lang.t("pause.resume"), func() -> void: set_paused(false)))
    box.add_child(UIKit.button(Lang.t("pause.menu"), func() -> void:
        get_tree().paused = false
        quit_pressed.emit()))


# --- mode / pause -------------------------------------------------------------------------
func set_mode(m: String) -> void:
    _foot.visible = m == "foot"
    _car.visible = m == "car"


func set_paused(p: bool) -> void:
    if _results != null and p:
        return
    get_tree().paused = p
    _pause.visible = p
    AudioManager.pause_engine(p)


func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        var k := (event as InputEventKey).keycode
        if k == KEY_ESCAPE or k == KEY_P:
            set_paused(not get_tree().paused)


func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST:
        set_paused(not get_tree().paused)


# --- polled input --------------------------------------------------------------------------
func stick() -> Vector2:
    return _stick.value


func block_held() -> bool:
    return _b_block.pressed


func steer_axis() -> float:
    return (1.0 if _b_right.pressed else 0.0) - (1.0 if _b_left.pressed else 0.0)


func gas() -> bool:
    return _b_gas.pressed


func brake() -> bool:
    return _b_brake.pressed


func nitro_held() -> bool:
    return _b_nitro.pressed


func drift_held() -> bool:
    return _b_drift.pressed


func _edge(id: String, btn: TouchButton, sig: Signal) -> void:
    var now := btn.pressed and btn.is_visible_in_tree()
    if now and not bool(_prev.get(id, false)):
        sig.emit()
    _prev[id] = now


# --- output --------------------------------------------------------------------------------
func set_countdown(text: String, secs: float = 1.2) -> void:
    _lbl_center.text = text
    _center_t = secs


func flash(text: String, secs: float = 2.0) -> void:
    _lbl_flash.text = text
    _flash_t = secs


func hint(text: String, secs: float = 4.0) -> void:
    _lbl_hint.text = text
    _hint_t = secs


func set_enter_visible(v: bool) -> void:
    _b_enter.visible = v


func set_exit_visible(v: bool) -> void:
    _b_exit.visible = v


func update_status(coins: int, health_ratio: float, kmh: float, nitro: float, wrong_way: bool) -> void:
    _lbl_coins.text = Lang.t("common.coins", [coins])
    _health.value = health_ratio
    _lbl_speed.text = str(int(kmh))
    _nitro.value = nitro
    _lbl_wrong.visible = wrong_way


func update_race(active: bool, pos: int = 1, total: int = 1, lap: int = 1, laps: int = 1, time: float = 0.0) -> void:
    _race_panel.visible = active
    if active:
        _lbl_pos.text = Lang.t("race.pos", [pos, total])
        _lbl_lap.text = Lang.t("race.lap", [clampi(lap, 1, laps), laps])
        _lbl_time.text = UIKit.fmt_time(time)


func update_map(player_pos: Vector3, markers: Array, path: PackedVector3Array, delta: float) -> void:
    _map_t -= delta
    if _map_t <= 0.0:
        _map_t = 0.1
        minimap.player_pos = player_pos
        minimap.markers = markers
        minimap.path = path
        minimap.queue_redraw()


func _process(delta: float) -> void:
    if _center_t > 0.0:
        _center_t -= delta
        if _center_t <= 0.0:
            _lbl_center.text = ""
    if _flash_t > 0.0:
        _flash_t -= delta
        if _flash_t <= 0.0:
            _lbl_flash.text = ""
    if _hint_t > 0.0:
        _hint_t -= delta
        if _hint_t <= 0.0:
            _lbl_hint.text = ""
    _edge("enter", _b_enter, enter_pressed)
    _edge("exit", _b_exit, exit_pressed)
    _edge("punch", _b_punch, punch_pressed)
    _edge("kick", _b_kick, kick_pressed)


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
    box.add_child(UIKit.label(Lang.t("race.victory") if place == 1 else Lang.t("race.finished"), 56, UIKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
    box.add_child(UIKit.label(Lang.t("race.position", [place, int(d["total"])]), 38, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
    box.add_child(UIKit.label(Lang.t("race.time", [UIKit.fmt_time(float(d["time"]))]), 30, UIKit.CYAN, HORIZONTAL_ALIGNMENT_CENTER))
    box.add_child(UIKit.label(Lang.t("race.best", [UIKit.fmt_time(float(d["best_lap"]))]), 28, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
    box.add_child(UIKit.label(Lang.t("race.reward", [int(d["reward"])]), 30, Color(1.0, 0.85, 0.2), HORIZONTAL_ALIGNMENT_CENTER))
    box.add_child(UIKit.button(Lang.t("common.continue"), func() -> void:
        _results.queue_free()
        _results = null
        results_closed.emit()))
