extends Node3D
## Race controller: builds the track, spawns player + AI, runs countdown -> race -> results.

enum State { COUNTDOWN, RACING, FINISHED }

const NAMES: Array = ["NOVA", "BLAZE", "RIPTIDE", "KAIRO", "VEGA", "ORION", "DRAKE", "ZEPHYR"]
const AI_COLORS: Array = ["f77f00", "06d6a0", "ffd166", "ef476f", "118ab2", "b5179e", "8ac926"]
const REWARDS: Array = [300, 200, 140, 90, 60, 40, 30, 20]

var track_index := 0
var total_laps := 3
var state: State = State.COUNTDOWN
var race_time := 0.0
var countdown := 3.99
var info: TrackInfo
var td: Dictionary = {}
var player: Vehicle
var racers: Array[Vehicle] = []
var drivers: Array[AIDriver] = []
var finish_order: Array[Vehicle] = []
var hud: HUD
var cam: CameraRig
var pickups: Array[Dictionary] = []
var coins_picked := 0
var best_lap_this_race := INF

var _rng := RandomNumberGenerator.new()
var _quality := 1
var _last_count := 4
var _stuck := 0.0
var _player_rank := 1


func _ready() -> void:
    _rng.randomize()
    get_tree().paused = false
    track_index = clampi(GameData.selected_track, 0, TrackData.count() - 1)
    td = TrackData.get_track(track_index)
    total_laps = clampi(int(GameData.setting("laps")), 1, 10)
    _quality = clampi(int(GameData.setting("quality")), 0, 2)
    _apply_quality()

    var built := TrackBuilder.build(track_index, _quality)
    if built.is_empty():
        push_error("Race: track build failed, returning to menu")
        get_tree().change_scene_to_file("res://scenes/Main.tscn")
        return
    info = built["info"]
    add_child(built["root"])
    add_child(TrackBuilder.make_environment(td, _quality))
    _build_pickups(built["pickups"])
    _spawn_racers()

    cam = CameraRig.new()
    add_child(cam)
    cam.target = player
    cam.set_mode(int(GameData.setting("camera")))

    hud = HUD.new()
    add_child(hud)
    hud.setup(info, total_laps, racers, player)
    hud.camera_pressed.connect(_on_camera)
    hud.reset_pressed.connect(_on_reset)
    hud.restart_pressed.connect(_on_restart)
    hud.quit_pressed.connect(_on_quit)
    AudioManager.start_engine()


func _exit_tree() -> void:
    AudioManager.stop_engine()
    var vp := get_viewport()
    if vp != null:
        vp.msaa_3d = Viewport.MSAA_DISABLED
        vp.scaling_3d_scale = 1.0
    GameData.flush()


func _apply_quality() -> void:
    var vp := get_viewport()
    vp.msaa_3d = Viewport.MSAA_2X if _quality >= 2 else Viewport.MSAA_DISABLED
    vp.scaling_3d_scale = 0.75 if _quality == 0 else 1.0


# --- setup --------------------------------------------------------------------------------------
func _make_vehicle(car: Dictionary, stats: Dictionary, is_player: bool, rname: String) -> Vehicle:
    var v := Vehicle.new()
    v.setup(car, stats, is_player, rname)
    add_child(v)
    racers.append(v)
    v.crashed.connect(_on_crashed.bind(v))
    if is_player:
        v.lap_completed.connect(_on_player_lap)
    return v


func _place_on_grid(v: Vehicle, slot: int) -> void:
    v.place(info.grid_transform(slot), info.grid_index(slot))


func _spawn_racers() -> void:
    var cars := CarData.cars()
    var ai_n := clampi(int(GameData.setting("ai_count")), 1, 7)
    var player_slot := mini(ai_n, 4)
    var pcar := CarData.by_id(GameData.selected_id())
    var pstats := CarData.stats_for(pcar, GameData.upgrades_of(str(pcar["id"])))
    player = _make_vehicle(pcar, pstats, true, "YOU")
    var skills := [0.82, 0.9, 0.97]
    var base_skill: float = skills[clampi(track_index, 0, 2)]
    var made := 0
    for s in ai_n + 1:
        if s == player_slot:
            _place_on_grid(player, s)
            continue
        var ci := clampi(track_index + _rng.randi_range(0, 2), 0, cars.size() - 1)
        var acar: Dictionary = (cars[ci] as Dictionary).duplicate()
        acar["color"] = AI_COLORS[made % AI_COLORS.size()]
        var v := _make_vehicle(acar, CarData.stats_for(acar, {}), false, str(NAMES[made % NAMES.size()]))
        _place_on_grid(v, s)
        var skill := base_skill + _rng.randf_range(-0.05, 0.04)
        drivers.append(AIDriver.new(v, info, skill, _rng.randf_range(-3.0, 3.0)))
        made += 1
    if bool(td["night"]):
        player.add_headlights()


func _build_pickups(list: Array) -> void:
    var coin_mesh := CylinderMesh.new()
    coin_mesh.top_radius = 0.7
    coin_mesh.bottom_radius = 0.7
    coin_mesh.height = 0.12
    coin_mesh.radial_segments = 14
    coin_mesh.rings = 1
    var coin_mat := StandardMaterial3D.new()
    coin_mat.albedo_color = Color(1.0, 0.82, 0.15)
    coin_mat.metallic = 0.8
    coin_mat.roughness = 0.3
    coin_mat.emission_enabled = true
    coin_mat.emission = Color(1.0, 0.7, 0.1)
    coin_mat.emission_energy_multiplier = 0.6
    var nitro_mesh := SphereMesh.new()
    nitro_mesh.radius = 0.7
    nitro_mesh.height = 1.4
    nitro_mesh.radial_segments = 10
    nitro_mesh.rings = 5
    var nitro_mat := StandardMaterial3D.new()
    nitro_mat.albedo_color = Color(0.1, 0.8, 1.0)
    nitro_mat.emission_enabled = true
    nitro_mat.emission = Color(0.1, 0.8, 1.0)
    nitro_mat.emission_energy_multiplier = 1.5
    var holder := Node3D.new()
    holder.name = "Pickups"
    add_child(holder)
    for item in list:
        var kind := str(item["type"])
        var node := Node3D.new()
        node.position = (item["pos"] as Vector3) + Vector3(0.0, 1.1, 0.0)
        var mi := MeshInstance3D.new()
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        if kind == "coin":
            mi.mesh = coin_mesh
            mi.material_override = coin_mat
            mi.rotation_degrees = Vector3(90.0, 0.0, 0.0)
        else:
            mi.mesh = nitro_mesh
            mi.material_override = nitro_mat
        node.add_child(mi)
        holder.add_child(node)
        pickups.append({"node": node, "type": kind})


# --- loop -----------------------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
    if info == null:
        return
    if state == State.COUNTDOWN:
        countdown -= delta
        var c := ceili(countdown)
        if c != _last_count:
            _last_count = c
            if c > 0:
                hud.set_countdown(str(c), 1.0)
                AudioManager.play("beep")
        if countdown <= 0.0:
            state = State.RACING
            for v in racers:
                v.controllable = true
            hud.set_countdown("GO!", 0.9)
            AudioManager.play("go", 1.0)
    else:
        race_time += delta

    if not player.finished and state == State.RACING:
        _read_player_input(delta)
    var player_prog := player.progress
    for d in drivers:
        d.update(delta, clampf((player_prog - d.v.progress) / 400.0, -0.05, 0.06))
    for v in racers:
        v.update_progress(info, race_time)
        if not v.finished and v.lap > total_laps:
            v.finished = true
            v.finish_time = race_time
            finish_order.append(v)
            if v == player:
                _on_player_finished()
    _update_pickups(delta)
    _update_rank()
    var ratio := player.speed_kmh / 3.6 / player.top_speed
    AudioManager.set_engine(ratio, player.input_throttle, player.boosting)


func _process(_delta: float) -> void:
    if hud == null or player == null:
        return
    hud.update_hud(player, _player_rank, racers.size(), player.lap, total_laps, race_time, coins_picked)


func _read_player_input(delta: float) -> void:
    var steer := 0.0
    var gas := 0.0
    var brk := 0.0
    if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
        steer -= 1.0
    if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
        steer += 1.0
    if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
        gas = 1.0
    if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
        brk = 1.0
    steer += hud.steer_axis()
    if hud.gas():
        gas = 1.0
    if hud.brake():
        brk = 1.0
    if bool(GameData.setting("tilt")):
        var acc := Input.get_accelerometer()
        var sign_t := 1.0 if bool(GameData.setting("tilt_invert")) else -1.0
        var tilt := clampf(acc.x * sign_t / 5.0, -1.0, 1.0)
        if absf(tilt) > 0.08:
            steer += tilt
    player.input_steer = clampf(steer, -1.0, 1.0)
    player.input_throttle = gas
    player.input_brake = brk
    player.input_nitro = hud.nitro_held() or Input.is_key_pressed(KEY_SHIFT)
    player.input_drift = hud.drift_held() or Input.is_key_pressed(KEY_SPACE)
    if gas > 0.0 and player.velocity.length() < 1.5:
        _stuck += delta
        if _stuck > 4.0:
            _stuck = 0.0
            player.respawn(info)
    else:
        _stuck = 0.0


func _update_pickups(delta: float) -> void:
    var pp := player.global_position
    for pk in pickups:
        var node: Node3D = pk["node"]
        if not node.visible:
            continue
        node.rotate_y(delta * 2.5)
        var dx := node.global_position.x - pp.x
        var dz := node.global_position.z - pp.z
        if dx * dx + dz * dz < 5.0:
            node.visible = false
            if str(pk["type"]) == "coin":
                coins_picked += 10
                GameData.add_coins(10)
                AudioManager.play("coin")
            else:
                player.nitro = minf(1.0, player.nitro + 0.4)
                AudioManager.play("boost")
                hud.flash("NITRO +", 1.0)


func _score(v: Vehicle) -> float:
    if v.finished:
        return 1.0e9 - v.finish_time
    return v.progress


func _update_rank() -> void:
    var arr := racers.duplicate()
    arr.sort_custom(func(a: Vehicle, b: Vehicle) -> bool: return _score(a) > _score(b))
    _player_rank = arr.find(player) + 1


# --- events -----------------------------------------------------------------------------------------
func _on_crashed(impact: float, who: Vehicle) -> void:
    if who.is_player:
        AudioManager.play("crash", clampf(1.4 - impact / 40.0, 0.6, 1.2))
        cam.shake(clampf(impact / 25.0, 0.2, 1.0))


func _on_player_lap(lap_time: float) -> void:
    best_lap_this_race = minf(best_lap_this_race, lap_time)
    var lap_no := clampi(player.lap, 1, total_laps)
    if GameData.record_lap(track_index, lap_time):
        hud.flash("NEW BEST LAP  %s" % UIKit.fmt_time(lap_time), 2.4)
    else:
        hud.flash("LAP %d  %s" % [lap_no - 1, UIKit.fmt_time(lap_time)], 2.0)


func _on_player_finished() -> void:
    state = State.FINISHED
    var place := finish_order.size()
    var reward: int = REWARDS[clampi(place - 1, 0, REWARDS.size() - 1)]
    GameData.add_coins(reward)
    var unlocked := ""
    if place <= 3 and track_index + 1 < TrackData.count() and not GameData.is_unlocked(track_index + 1):
        GameData.unlock_track(track_index + 1)
        unlocked = str(TrackData.get_track(track_index + 1)["name"])
    GameData.save_game()
    AudioManager.play("finish")
    # Autopilot takes over so the player's car keeps rolling behind the results screen.
    drivers.append(AIDriver.new(player, info, 0.8, 0.0))
    hud.show_results({
        "position": place, "total": racers.size(), "time": race_time,
        "best_lap": best_lap_this_race, "reward": reward, "picked": coins_picked, "unlocked": unlocked,
    })


func _on_camera() -> void:
    hud.flash("CAMERA: %s" % cam.cycle_mode(), 1.2)


func _on_reset() -> void:
    if state == State.RACING and not player.finished:
        player.respawn(info)


func _on_restart() -> void:
    GameData.flush()
    get_tree().paused = false
    get_tree().reload_current_scene()


func _on_quit() -> void:
    GameData.flush()
    get_tree().paused = false
    get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_PAUSED and hud != null and state != State.FINISHED:
        hud.set_paused(true)
