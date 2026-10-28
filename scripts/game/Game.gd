extends Node3D
## Open world: walk, fight, drive, and start races from the glowing beacons.

enum Mode { FOOT, CAR }

const AI_NAMES: Array = ["Рустам", "Фарҳод", "Ҷамшед", "Дилшод", "Бахтиёр", "Сомон", "Фирӯз"]
const COLORS: Array = ["f77f00", "06d6a0", "ffd166", "ef476f", "118ab2", "b5179e", "8ac926", "e63946"]
const RACE_PAYOUT: Array = [1.0, 0.6, 0.4, 0.25, 0.15, 0.1]
const KO_REWARD := 25

var net: RoadNet
var quality := 1
var mode: int = Mode.FOOT
var player: Person
var own_car: Vehicle
var cur_car: Vehicle
var vehicles: Array[Vehicle] = []
var people: Array = []
var fighters: Array = []
var markers: Array = []
var hud: HUD
var cam: CameraRig
var race: Dictionary = {}

var _rng := RandomNumberGenerator.new()
var _cull_t := 0.0
var _ai_t := 0.0
var _respawn_t := -1.0
var _race_cd := 0.0
var _car_cam := 0
var _map_markers: Array = []


func _ready() -> void:
    _rng.randomize()
    get_tree().paused = false
    quality = clampi(int(GameData.setting("quality")), 0, 2)
    _car_cam = clampi(int(GameData.setting("camera")), 0, 3)
    var vp := get_viewport()
    vp.msaa_3d = Viewport.MSAA_2X if quality >= 2 else Viewport.MSAA_DISABLED
    vp.scaling_3d_scale = 0.75 if quality == 0 else 1.0

    net = RoadNet.new()
    net.build()
    add_child(WorldBuilder.build(net, quality))
    add_child(WorldBuilder.make_environment(quality))
    _spawn_player()
    _spawn_parked()
    _spawn_people()
    _spawn_fighters()
    _spawn_markers()

    cam = CameraRig.new()
    add_child(cam)
    cam.target = player
    cam.yaw = PI * 0.5

    hud = HUD.new()
    add_child(hud)
    hud.minimap.tex = WorldBuilder.minimap_texture(net)
    hud.camera_pressed.connect(_on_camera)
    hud.reset_pressed.connect(_on_reset)
    hud.enter_pressed.connect(_toggle_car)
    hud.exit_pressed.connect(_toggle_car)
    hud.punch_pressed.connect(func() -> void: _attack("punch"))
    hud.kick_pressed.connect(func() -> void: _attack("kick"))
    hud.look_moved.connect(func(d: Vector2) -> void: cam.look(d))
    hud.results_closed.connect(_end_race)
    hud.quit_pressed.connect(_on_quit)
    hud.hint(Lang.t("hint.start"), 7.0)


func _exit_tree() -> void:
    AudioManager.stop_engine()
    var vp := get_viewport()
    if vp != null:
        vp.msaa_3d = Viewport.MSAA_DISABLED
        vp.scaling_3d_scale = 1.0
    GameData.flush()


# --- spawning ---------------------------------------------------------------------------------
func _make_vehicle(car: Dictionary, stats: Dictionary, is_player: bool, rname: String) -> Vehicle:
    var v := Vehicle.new()
    v.setup(car, stats, is_player, rname)
    add_child(v)
    vehicles.append(v)
    v.crashed.connect(_on_crashed.bind(v))
    v.lap_completed.connect(_on_lap.bind(v))
    v.set_physics_process(false)
    return v


func _make_person(app: Dictionary, role: int, hp: float, pos: Vector3) -> Person:
    var p := Person.new()
    p.setup(app, role, hp)
    add_child(p)
    p.global_position = pos
    p.home = pos
    p.people = people
    people.append(p)
    p.died.connect(_on_person_died)
    return p


func _spawn_player() -> void:
    var car := CarData.by_id(GameData.selected_id())
    var stats := CarData.stats_for(car, GameData.upgrades_of(str(car["id"])))
    own_car = _make_vehicle(car, stats, true, Lang.t("name.you"))
    own_car.place(Transform3D(Basis(Vector3.UP, -PI * 0.5), WorldData.PLAYER_CAR), 0)
    var app := HumanBuilder.resolve(GameData.skin(), GameData.equipped())
    player = _make_person(app, Person.Role.PLAYER, 100.0, WorldData.PLAYER_START)
    player.yaw = PI * 0.5
    player.died.connect(_on_player_died)


func _spawn_parked() -> void:
    var cars := Content.cars()
    var rng := RandomNumberGenerator.new()
    rng.seed = 5
    var made := 0
    var tries := 0
    while made < 10 and tries < 120:
        tries += 1
        var vertical := rng.randf() < 0.5
        var street: float = WorldData.STREETS[rng.randi_range(0, 4)]
        var along := rng.randf_range(-280.0, 280.0)
        var skip := false
        for s: float in WorldData.STREETS:
            if absf(along - s) < 16.0:
                skip = true
        if skip:
            continue
        var side := 6.8 if rng.randf() < 0.5 else -6.8
        var pos := Vector3(street + side, 0.0, along) if vertical else Vector3(along, 0.0, street + side)
        if pos.distance_to(WorldData.PLAYER_CAR) < 25.0:
            continue
        var car: Dictionary = (cars[rng.randi() % cars.size()] as Dictionary).duplicate()
        car["color"] = COLORS[rng.randi() % COLORS.size()]
        var v := _make_vehicle(car, CarData.stats_for(car, {}), false, "")
        var yaw := (0.0 if vertical else PI * 0.5) + (PI if rng.randf() < 0.5 else 0.0)
        v.place(Transform3D(Basis(Vector3.UP, yaw), pos), 0)
        made += 1


func _spawn_people() -> void:
    var npcs := Content.characters_with_role("npc")
    var counts := [10, 16, 24]
    for i in counts[quality]:
        var ch: Dictionary = npcs[_rng.randi() % npcs.size()]
        var street: float = WorldData.STREETS[_rng.randi_range(0, 4)]
        var along := _rng.randf_range(-290.0, 290.0)
        var off := _rng.randf_range(8.0, 15.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
        var pos := Vector3(street + off, 0.0, along) if _rng.randf() < 0.5 else Vector3(along, 0.0, street + off)
        var p := _make_person(HumanBuilder.resolve_character(ch), Person.Role.NPC, float(ch.get("hp", 40)), pos)
        p.yaw = _rng.randf() * TAU


func _spawn_fighters() -> void:
    var chars := Content.characters_with_role("fighter")
    for spot: Vector3 in WorldData.FIGHTER_SPOTS:
        for k in 3:
            var ch: Dictionary = chars[_rng.randi() % chars.size()]
            var pos := spot + Vector3(float(k - 1) * 3.0, 0.0, _rng.randf_range(-2.0, 2.0))
            var f := _make_person(HumanBuilder.resolve_character(ch), Person.Role.FIGHTER, float(ch.get("hp", 70)), pos)
            fighters.append(f)


func _spawn_markers() -> void:
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = Color(0.1, 0.85, 1.0, 0.28)
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    for def: Dictionary in Content.races():
        var ctrl := PackedVector2Array()
        for w in def["waypoints"]:
            ctrl.append(Vector2(float(w[0]), float(w[1])))
        var info := TrackInfo.new()
        info.setup(PathUtil.resample(ctrl, true, true, 4.0), 14.0)
        var node := Node3D.new()
        node.position = info.point(0)
        var mi := MeshInstance3D.new()
        var cm := CylinderMesh.new()
        cm.top_radius = 4.0
        cm.bottom_radius = 4.0
        cm.height = 40.0
        cm.radial_segments = 16
        cm.rings = 1
        mi.mesh = cm
        mi.material_override = mat
        mi.position.y = 20.0
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        node.add_child(mi)
        var lbl := Label3D.new()
        lbl.text = str(def["name"])
        lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        lbl.font_size = 96
        lbl.pixel_size = 0.02
        lbl.outline_size = 14
        lbl.position.y = 44.0
        node.add_child(lbl)
        add_child(node)
        markers.append({"def": def, "info": info, "pos": info.point(0)})
        _map_markers.append({"pos": info.point(0), "color": Color(1.0, 0.85, 0.1)})


# --- input -------------------------------------------------------------------------------------
func _unhandled_key_input(event: InputEvent) -> void:
    if not (event is InputEventKey) or not event.pressed or event.echo:
        return
    match (event as InputEventKey).keycode:
        KEY_E:
            _toggle_car()
        KEY_J:
            _attack("punch")
        KEY_K:
            _attack("kick")
        KEY_C:
            _on_camera()
        KEY_R:
            _on_reset()


func _key(a: int, b: int) -> float:
    return (1.0 if Input.is_key_pressed(a) or Input.is_key_pressed(b) else 0.0)


func _read_input() -> void:
    if mode == Mode.FOOT:
        var s := hud.stick()
        var v := Vector2(s.x + _key(KEY_D, KEY_RIGHT) - _key(KEY_A, KEY_LEFT), s.y + _key(KEY_W, KEY_UP) - _key(KEY_S, KEY_DOWN)).limit_length(1.0)
        player.move_dir = Basis(Vector3.UP, cam.yaw) * Vector3(v.x, 0.0, -v.y)
        player.blocking = hud.block_held() or Input.is_key_pressed(KEY_Q)
        return
    var c := cur_car
    var steer := hud.steer_axis() + _key(KEY_D, KEY_RIGHT) - _key(KEY_A, KEY_LEFT)
    if bool(GameData.setting("tilt")):
        var acc := Input.get_accelerometer()
        var sg := 1.0 if bool(GameData.setting("tilt_invert")) else -1.0
        var tilt := clampf(acc.x * sg / 5.0, -1.0, 1.0)
        if absf(tilt) > 0.08:
            steer += tilt
    c.input_steer = clampf(steer, -1.0, 1.0)
    c.input_throttle = 1.0 if hud.gas() or _key(KEY_W, KEY_UP) > 0.0 else 0.0
    c.input_brake = 1.0 if hud.brake() or _key(KEY_S, KEY_DOWN) > 0.0 else 0.0
    c.input_nitro = hud.nitro_held() or Input.is_key_pressed(KEY_SHIFT)
    c.input_drift = hud.drift_held() or Input.is_key_pressed(KEY_SPACE)


func _attack(kind: String) -> void:
    if mode == Mode.FOOT and player != null and not player.ko:
        player.attack(kind)


# --- enter / exit car -----------------------------------------------------------------------------
func _nearest_vehicle(pos: Vector3, r: float) -> Vehicle:
    var best: Vehicle = null
    var bd := r
    for v in vehicles:
        if is_instance_valid(v) and v != cur_car:
            var d := v.global_position.distance_to(pos)
            if d < bd:
                bd = d
                best = v
    return best


func _toggle_car() -> void:
    if not race.is_empty() and mode == Mode.CAR:
        return
    if mode == Mode.FOOT:
        if player.ko:
            return
        var v := _nearest_vehicle(player.global_position, 4.0)
        if v != null:
            _enter_car(v)
    else:
        _exit_car()


func _enter_car(v: Vehicle) -> void:
    mode = Mode.CAR
    cur_car = v
    v.set_physics_process(true)
    v.controllable = true
    player.visible = false
    player.collision_layer = 0
    player.set_physics_process(false)
    cam.target = v
    cam.set_mode(_car_cam)
    hud.set_mode("car")
    AudioManager.start_engine()


func _exit_car() -> void:
    var v := cur_car
    v.controllable = false
    v.input_throttle = 0.0
    v.input_brake = 0.0
    v.input_steer = 0.0
    v.input_nitro = false
    v.input_drift = false
    var p := v.global_position + v.global_transform.basis.x * 2.4
    p.y = 0.0
    player.global_position = p
    player.velocity = Vector3.ZERO
    player.visible = true
    player.collision_layer = 2
    player.set_physics_process(true)
    cam.yaw = v.rotation.y
    cam.target = player
    mode = Mode.FOOT
    cur_car = null
    hud.set_mode("foot")
    AudioManager.stop_engine()


func _on_camera() -> void:
    if mode == Mode.CAR:
        var key := cam.cycle_mode()
        _car_cam = cam.mode
        hud.flash(Lang.t("cam.label", [Lang.t(key)]), 1.2)


func _on_reset() -> void:
    if mode != Mode.CAR or cur_car == null:
        return
    if not race.is_empty():
        if str(race["state"]) == "racing":
            cur_car.respawn(race["info"])
    else:
        cur_car.place(Transform3D(Basis(Vector3.UP, -PI * 0.5), WorldData.PLAYER_CAR), 0)


func _on_quit() -> void:
    GameData.flush()
    get_tree().paused = false
    get_tree().change_scene_to_file("res://scenes/Main.tscn")


# --- events --------------------------------------------------------------------------------------------
func _on_crashed(impact: float, who: Vehicle) -> void:
    if who == cur_car:
        AudioManager.play("crash", clampf(1.4 - impact / 40.0, 0.6, 1.2))
        cam.shake(clampf(impact / 25.0, 0.2, 1.0))


func _on_person_died(p: Person) -> void:
    if p.role == Person.Role.FIGHTER:
        GameData.add_coins(KO_REWARD)
        hud.flash(Lang.t("msg.ko_reward", [KO_REWARD]), 1.5)
        fighters.erase(p)


func _on_player_died(_p: Person) -> void:
    hud.flash(Lang.t("msg.defeated"), 3.0)
    _respawn_t = 3.0


func _on_lap(lap_time: float, who: Vehicle) -> void:
    if race.is_empty() or who != cur_car:
        return
    race["best"] = minf(float(race["best"]), lap_time)
    var rid := str((race["def"] as Dictionary)["id"])
    if GameData.record_lap(rid, lap_time):
        hud.flash(Lang.t("race.best_new", [UIKit.fmt_time(lap_time)]), 2.4)
    else:
        hud.flash(Lang.t("race.lap_done", [clampi(who.lap - 1, 1, int(race["laps"])), UIKit.fmt_time(lap_time)]), 2.0)


# --- races ---------------------------------------------------------------------------------------------
func _start_race(m: Dictionary) -> void:
    var def: Dictionary = m["def"]
    var info: TrackInfo = m["info"]
    var ai_n := clampi(int(def.get("ai", 4)), 1, 7)
    var cars := Content.cars()
    race = {"def": def, "info": info, "state": "countdown", "t": 3.99, "time": 0.0, "laps": int(def["laps"]),
        "last": 4, "ai": [], "drivers": [], "finish": [], "best": INF, "rank": 1, "guides": null}
    var slot := mini(ai_n, 4)
    cur_car.controllable = false
    cur_car.lap = 0
    cur_car.finished = false
    cur_car.best_lap = INF
    cur_car.place(info.grid_transform(slot), info.grid_index(slot))
    var tier := float(def.get("reward", 600)) / 1400.0
    var base_skill := float(def.get("skill", 0.88))
    var made := 0
    for s in ai_n + 1:
        if s == slot:
            continue
        var ci := clampi(roundi(tier * float(cars.size() - 1)) + _rng.randi_range(-1, 0), 0, cars.size() - 1)
        var acar: Dictionary = (cars[ci] as Dictionary).duplicate()
        acar["color"] = COLORS[made % COLORS.size()]
        var v := _make_vehicle(acar, CarData.stats_for(acar, {}), false, str(AI_NAMES[made % AI_NAMES.size()]))
        v.set_physics_process(true)
        v.place(info.grid_transform(s), info.grid_index(s))
        (race["ai"] as Array).append(v)
        (race["drivers"] as Array).append(AIDriver.new(v, info, base_skill + _rng.randf_range(-0.05, 0.04), _rng.randf_range(-3.0, 3.0)))
        made += 1
    # guide pillars along the route
    var pillar := BoxMesh.new()
    pillar.size = Vector3(0.8, 7.0, 0.8)
    var pm := StandardMaterial3D.new()
    pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    pm.albedo_color = Color(0.1, 0.85, 1.0)
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = pillar
    var n := info.count()
    var count := n / 12
    mm.instance_count = count
    for i in count:
        mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, info.point(i * 12) + Vector3(0.0, 3.5, 0.0)))
    var mmi := MultiMeshInstance3D.new()
    mmi.multimesh = mm
    mmi.material_override = pm
    mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mmi)
    race["guides"] = mmi
    hud.set_exit_visible(false)
    hud.flash(str(def["name"]), 2.5)


func _race_racers() -> Array:
    return [cur_car] + (race["ai"] as Array)


func _score(v: Vehicle) -> float:
    if v.finished:
        return 1.0e9 - v.finish_time
    return v.progress


func _update_race(delta: float) -> void:
    var info: TrackInfo = race["info"]
    var racers := _race_racers()
    var state := str(race["state"])
    if state == "countdown":
        race["t"] = float(race["t"]) - delta
        var c := ceili(float(race["t"]))
        if c != int(race["last"]):
            race["last"] = c
            if c > 0:
                hud.set_countdown(str(c), 1.0)
                AudioManager.play("beep")
        if float(race["t"]) <= 0.0:
            race["state"] = "racing"
            for v: Vehicle in racers:
                v.controllable = true
            hud.set_countdown(Lang.t("race.go"), 0.9)
            AudioManager.play("go")
    else:
        race["time"] = float(race["time"]) + delta
    var now := float(race["time"])
    for d: AIDriver in (race["drivers"] as Array):
        d.update(delta, clampf((cur_car.progress - d.v.progress) / 400.0, -0.05, 0.06))
    var laps := int(race["laps"])
    for v: Vehicle in racers:
        v.update_progress(info, now)
        if not v.finished and v.lap > laps:
            v.finished = true
            v.finish_time = now
            (race["finish"] as Array).append(v)
            if v == cur_car:
                _finish_player_race()
    var arr := racers.duplicate()
    arr.sort_custom(func(a: Vehicle, b: Vehicle) -> bool: return _score(a) > _score(b))
    race["rank"] = arr.find(cur_car) + 1


func _finish_player_race() -> void:
    var def: Dictionary = race["def"]
    var place := (race["finish"] as Array).size()
    var reward := int(float(def["reward"]) * float(RACE_PAYOUT[clampi(place - 1, 0, RACE_PAYOUT.size() - 1)]))
    GameData.add_coins(reward)
    GameData.save_game()
    AudioManager.play("finish")
    race["state"] = "done"
    (race["drivers"] as Array).append(AIDriver.new(cur_car, race["info"], 0.8, 0.0))
    hud.show_results({"position": place, "total": _race_racers().size(), "time": float(race["time"]),
        "best_lap": float(race["best"]), "reward": reward})


func _end_race() -> void:
    if race.is_empty():
        return
    for v: Vehicle in (race["ai"] as Array):
        vehicles.erase(v)
        v.queue_free()
    if race["guides"] != null:
        (race["guides"] as Node).queue_free()
    if cur_car != null:
        cur_car.input_throttle = 0.0
        cur_car.input_brake = 0.0
        cur_car.input_steer = 0.0
    race = {}
    _race_cd = 20.0
    hud.update_race(false)
    hud.set_exit_visible(true)


# --- frame ----------------------------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
    if hud == null:
        return
    _race_cd = maxf(0.0, _race_cd - delta)
    if _respawn_t > 0.0:
        _respawn_t -= delta
        if _respawn_t <= 0.0:
            GameData.add_coins(-int(GameData.coins() * 0.1))
            player.revive(WorldData.HOSPITAL)
            _respawn_t = -1.0
    if player.ko and _respawn_t < 0.0 and mode == Mode.FOOT:
        _respawn_t = 3.0
    if not (mode == Mode.FOOT and player.ko):
        _read_input()
    if mode == Mode.CAR and cur_car != null:
        cur_car.set_surface(net.surface_at(cur_car.global_position))
    if not race.is_empty():
        for v: Vehicle in (race["ai"] as Array):
            v.set_surface(net.surface_at(v.global_position))
        _update_race(delta)
    elif mode == Mode.CAR and cur_car != null and _race_cd <= 0.0:
        for m: Dictionary in markers:
            if cur_car.global_position.distance_squared_to(m["pos"]) < 144.0:
                _start_race(m)
                break
    _update_fighters(delta)
    _update_hud(delta)
    _cull(delta)
    if mode == Mode.CAR and cur_car != null:
        AudioManager.set_engine(cur_car.speed_kmh / 3.6 / cur_car.top_speed, cur_car.input_throttle, cur_car.boosting)


func _update_fighters(delta: float) -> void:
    _ai_t -= delta
    if _ai_t > 0.0:
        return
    _ai_t = 0.25
    for f in fighters:
        var p := f as Person
        if p == null or not is_instance_valid(p) or p.ko:
            continue
        if mode == Mode.FOOT and not player.ko and p.global_position.distance_to(player.global_position) < 22.0:
            p.target = player
        elif p.target != null and (mode != Mode.FOOT or player.ko):
            p.target = null


func _update_hud(delta: float) -> void:
    var focus := player.global_position if mode == Mode.FOOT else cur_car.global_position
    var near := mode == Mode.FOOT and not player.ko and _nearest_vehicle(player.global_position, 4.0) != null
    hud.set_enter_visible(near)
    var kmh := cur_car.speed_kmh if mode == Mode.CAR else 0.0
    var nitro := cur_car.nitro if mode == Mode.CAR else 0.0
    var wrong := mode == Mode.CAR and cur_car.wrong_way and not race.is_empty()
    hud.update_status(GameData.coins(), player.health / player.max_health, kmh, nitro, wrong)
    var path := PackedVector3Array()
    if race.is_empty():
        hud.update_race(false)
    else:
        path = (race["info"] as TrackInfo).points
        hud.update_race(str(race["state"]) != "countdown", int(race["rank"]), _race_racers().size(), cur_car.lap, int(race["laps"]), float(race["time"]))
    hud.update_map(focus, _map_markers, path, delta)


func _cull(delta: float) -> void:
    _cull_t -= delta
    if _cull_t > 0.0:
        return
    _cull_t = 0.5
    var focus := player.global_position if mode == Mode.FOOT else cur_car.global_position
    var i := people.size() - 1
    while i >= 0:
        var p := people[i] as Person
        if p == null or not is_instance_valid(p):
            people.remove_at(i)
        elif p != player:
            var far := p.global_position.distance_squared_to(focus) > 12100.0
            p.visible = not far
            p.set_physics_process(not far)
        i -= 1
