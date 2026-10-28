extends SceneTree
## Headless self-test: godot --headless --path . --script res://tools/self_test.gd
## Prints "SELFTEST OK" and exits 0 only if every check passes.

const EQUIPPED := {"top": "top_tshirt_white", "bottom": "bottom_jeans_blue", "shoes": "shoes_sneakers_white", "hat": ""}

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
    _test_scripts()
    _test_content()
    _test_lang()
    _test_models()
    _test_world()
    _test_vehicle()
    _test_combat()
    if failures == 0:
        print("SELFTEST OK")
    else:
        printerr("SELFTEST FAILED: %d check(s)" % failures)
    quit(1 if failures > 0 else 0)


func _test_scripts() -> void:
    var scripts: Array = []
    _collect("res://scripts", ".gd", scripts)
    for p in scripts:
        var s := load(p)
        _check(s is GDScript and (s as GDScript).can_instantiate(), "script parses: %s" % p)
    var scenes: Array = []
    _collect("res://scenes", ".tscn", scenes)
    for p in scenes:
        _check(load(p) is PackedScene, "scene loads: %s" % p)


func _test_content() -> void:
    var problems := Content.validate()
    for pr in problems:
        printerr("  content problem: ", pr)
    _check(problems.is_empty(), "content/*.json valid (%d cars, %d outfits, %d characters, %d races)" % [Content.cars().size(), Content.outfits().size(), Content.characters().size(), Content.races().size()])


func _test_lang() -> void:
    var files: Array = []
    _collect("res://scripts", ".gd", files)
    var re := RegEx.new()
    re.compile("Lang\\.t\\(\"([^\"]+)\"")
    var missing := 0
    var used := 0
    for path in files:
        var f := FileAccess.open(path, FileAccess.READ)
        if f == null:
            continue
        for m in re.search_all(f.get_as_text()):
            var key := m.get_string(1)
            used += 1
            var keys: Array = [key]
            if key == "upg.":
                keys = []
                for k in CarData.UPGRADE_KEYS:
                    keys.append("upg." + str(k))
            elif key == "slot.":
                keys = []
                for k in Content.SLOTS:
                    keys.append("slot." + str(k))
            for kk in keys:
                if not Lang.has(str(kk)):
                    missing += 1
                    printerr("  missing Tajik text: ", kk, "  (", path, ")")
    for k in CameraRig.MODES:
        if not Lang.has(str(k)):
            missing += 1
            printerr("  missing Tajik text: ", k)
    _check(missing == 0 and used > 20, "all %d Lang keys exist in tg.json" % used)


func _test_models() -> void:
    for car in Content.cars():
        var b := CarBuilder.build(car)
        _check(not b.is_empty() and (b["wheels"] as Array).size() == 4, "car model: %s" % car["id"])
        if not b.is_empty():
            (b["root"] as Node).free()
    for ch in Content.characters():
        var h := HumanBuilder.build(HumanBuilder.resolve_character(ch))
        _check((h["parts"] as Dictionary).size() == 5, "character model: %s" % ch["id"])
        (h["root"] as Node).free()
    var pl := HumanBuilder.build(HumanBuilder.resolve(1, EQUIPPED))
    _check((pl["parts"] as Dictionary).size() == 5, "player model")
    (pl["root"] as Node).free()


func _test_world() -> void:
    var net := RoadNet.new()
    net.build()
    _check(net.polylines.size() > 15, "road network built (%d roads)" % net.polylines.size())
    _check(net.surface_at(WorldData.PLAYER_CAR) == WorldData.K_CITY, "player spawn is on a city street")
    _check(net.surface_at(Vector3(800, 0, 0)) == WorldData.K_HIGHWAY, "highway ring exists")
    var loop := WorldData.dirt_loop(0.0, 1000.0, 120.0, 25.0, 3, 12, -PI / 2.0)
    _check(net.surface_at(Vector3(loop[0].x, 0.0, loop[0].y)) == WorldData.K_DIRT, "dirt mountain road exists")
    _check(net.surface_at(Vector3(500, 0, -100)) == WorldData.K_GRASS, "open grass between roads")
    for r in Content.races():
        var ctrl := PackedVector2Array()
        for w in r["waypoints"]:
            ctrl.append(Vector2(float(w[0]), float(w[1])))
        var pts := PathUtil.resample(ctrl, true, true, 4.0)
        var off := 0
        for p in pts:
            if net.surface_at(p) == WorldData.K_GRASS:
                off += 1
        _check(pts.size() > 100 and off == 0, "race '%s' lies on roads (%d pts, %d off-road)" % [r["id"], pts.size(), off])
    var world := WorldBuilder.build(net, 0)
    _check(world.get_child_count() > 5, "world meshes + colliders built")
    world.free()
    var tex := WorldBuilder.minimap_texture(net)
    _check(tex != null, "minimap texture")


func _test_vehicle() -> void:
    var info := TrackInfo.new()
    var ctrl := PackedVector2Array([Vector2(-300, -300), Vector2(300, -300), Vector2(300, 300), Vector2(-300, 300)])
    info.setup(PathUtil.resample(ctrl, true, true, 4.0), 14.0)
    var v := Vehicle.new()
    var car0: Dictionary = Content.cars()[0]
    v.setup(car0, CarData.stats_for(car0, {}), true, "TEST")
    root.add_child(v)
    v.place(info.grid_transform(0), info.grid_index(0))
    v.controllable = true
    v.input_throttle = 1.0
    for i in 300:
        v._physics_process(1.0 / 60.0)
    _check(v.forward_speed > 15.0, "car accelerates (%.1f m/s)" % v.forward_speed)
    v.set_surface(WorldData.K_DIRT)
    _check(v.surface_speed < 1.0, "dirt slows the car")
    v.set_surface(WorldData.K_CITY)
    v.input_steer = 1.0
    v.input_drift = true
    v.input_nitro = true
    for i in 120:
        v._physics_process(1.0 / 60.0)
    _check(v.global_position.is_finite() and is_finite(v.velocity.length()), "steer/drift/nitro stay finite")
    v.input_throttle = 0.0
    v.input_brake = 1.0
    v.input_drift = false
    var stopped := false
    for i in 600:
        v._physics_process(1.0 / 60.0)
        if v.velocity.length() < 1.0:
            stopped = true
            break
    _check(stopped, "car brakes to a stop")
    v.free()


func _test_combat() -> void:
    var hero := Person.new()
    hero.setup(HumanBuilder.resolve(1, EQUIPPED), Person.Role.PLAYER, 100.0)
    var foe := Person.new()
    foe.setup(HumanBuilder.resolve_character(Content.characters_with_role("fighter")[0]), Person.Role.FIGHTER, 70.0)
    root.add_child(hero)
    root.add_child(foe)
    hero.global_position = Vector3.ZERO
    foe.global_position = Vector3(0, 0, -1.2)
    var all: Array = [hero, foe]
    hero.people = all
    foe.people = all
    _check(hero.attack("punch"), "player can punch")
    for i in 40:
        hero._physics_process(1.0 / 60.0)
    _check(foe.health < 70.0, "punch damages the fighter (hp %.0f)" % foe.health)
    foe.take_hit(500.0, Vector3(0, 0, -1), hero)
    _check(foe.ko, "fighter is knocked out")
    hero.free()
    foe.free()
