extends SceneTree
## Headless self-test: godot --headless --path . --script res://tools/self_test.gd
## Parses every script, loads every scene, builds all cars/tracks, checks track geometry,
## and runs a short physics simulation. Prints "SELFTEST OK" and exits 0 only if all checks pass.

var failures := 0


func _check(ok: bool, msg: String) -> void:
    if ok:
        print("  ok   ", msg)
    else:
        failures += 1
        printerr("  FAIL ", msg)


func _collect(dir_path: String, ext: String, out: Array) -> void:
    var d := DirAccess.open(dir_path)
    if d == null:
        return
    d.list_dir_begin()
    var f := d.get_next()
    while f != "":
        if d.current_is_dir():
            if not f.begins_with("."):
                _collect(dir_path.path_join(f), ext, out)
        elif f.ends_with(ext):
            out.append(dir_path.path_join(f))
        f = d.get_next()
    d.list_dir_end()


func _initialize() -> void:
    print("== DRIVE X self-test ==")
    var scripts: Array = []
    _collect("res://scripts", ".gd", scripts)
    for p in scripts:
        var s := load(p)
        _check(s is GDScript and (s as GDScript).can_instantiate(), "script parses: %s" % p)
    var scenes: Array = []
    _collect("res://scenes", ".tscn", scenes)
    for p in scenes:
        _check(load(p) is PackedScene, "scene loads: %s" % p)

    for car in CarData.cars():
        var b := CarBuilder.build(car)
        _check(not b.is_empty() and (b["wheels"] as Array).size() == 4, "car model: %s" % car["id"])
        if not b.is_empty():
            (b["root"] as Node).free()

    for i in TrackData.count():
        var built := TrackBuilder.build(i, 0)
        _check(not built.is_empty(), "track builds: %d" % i)
        if built.is_empty():
            continue
        var info: TrackInfo = built["info"]
        _check(info.count() > 100 and info.length > 1000.0, "track %d length %.0f m, %d pts" % [i, info.length, info.count()])
        var clear := true
        var n := info.count()
        for a in range(0, n, 2):
            for b in range(a + 60, n, 2):
                if n - (b - a) < 60:
                    continue
                if info.points[a].distance_to(info.points[b]) < info.width * 2.0:
                    clear = false
        _check(clear, "track %d has no self-overlap" % i)
        _check(info.nearest_index(info.point(17), -1) == 17 and info.nearest_index(info.point(17), 12) == 17, "track %d nearest_index" % i)
        (built["root"] as Node).free()

    # physics smoke test
    var info2: TrackInfo = TrackBuilder.build(0, 0)["info"]
    var v := Vehicle.new()
    var car0: Dictionary = CarData.cars()[0]
    v.setup(car0, CarData.stats_for(car0, {}), true, "TEST")
    root.add_child(v)
    v.place(info2.grid_transform(0), info2.grid_index(0))
    v.controllable = true
    v.input_throttle = 1.0
    for i in 300:
        v._physics_process(1.0 / 60.0)
    _check(v.forward_speed > 15.0, "accelerates (%.1f m/s)" % v.forward_speed)
    v.input_steer = 1.0
    v.input_drift = true
    v.input_nitro = true
    for i in 120:
        v._physics_process(1.0 / 60.0)
    _check(is_finite(v.velocity.length()) and v.global_position.is_finite(), "steer/drift/nitro stay finite")
    v.input_throttle = 0.0
    v.input_brake = 1.0
    v.input_drift = false
    for i in 400:
        v._physics_process(1.0 / 60.0)
    _check(v.velocity.length() < 1.0, "brakes to stop")
    v.free()

    # save-data logic (no autoload needed)
    var gd: Node = load("res://scripts/autoload/GameData.gd").new()
    gd.data = gd.default_data()
    gd._sanitize()
    _check(gd.coins() == 500 and gd.owns("gt_rookie"), "default save data")
    _check(not gd.buy_car("phantom_x"), "cannot buy car without coins")
    gd.free()

    if failures == 0:
        print("SELFTEST OK")
    else:
        printerr("SELFTEST FAILED: %d check(s)" % failures)
    quit(1 if failures > 0 else 0)
