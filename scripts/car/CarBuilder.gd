class_name CarBuilder
extends RefCounted
## Builds detailed procedural cars from content/cars/*.json (or res://assets/models/<id>.glb if present).
## Body, glass, trim, lights and grille are batched into ONE mesh (see MeshKit); each wheel is one mesh.
## Car convention: forward = -Z, wheel bottoms at y = 0.
##
## JSON design fields (all optional except the basics):
##   style     sedan | sedan_sport | sedan_lux | coupe | hatch | suv | muscle | fastback | gt | super | wedge
##   grille    kidney | mesh | single | slats | slats_v | vent | wide
##   headlight round | led_strip | slim          taillight bar | split | round
##   wheel     wheel radius in metres (default 0.36)

const WHEEL_R := 0.36
const WHEEL_W := 0.28

const STYLES: Dictionary = {
    "sedan": {"nose": 0.5, "hood_z": -0.37, "hood_y": 0.84, "wb": -0.14, "rf": 0.02, "rr": 0.24, "rb": 0.36, "tail": 0.95},
    "sedan_sport": {"nose": 0.5, "hood_z": -0.38, "hood_y": 0.86, "wb": -0.13, "rf": 0.03, "rr": 0.24, "rb": 0.35, "tail": 0.96},
    "sedan_lux": {"nose": 0.52, "hood_z": -0.38, "hood_y": 0.88, "wb": -0.10, "rf": 0.04, "rr": 0.28, "rb": 0.38, "tail": 0.98},
    "coupe": {"nose": 0.5, "hood_z": -0.38, "hood_y": 0.82, "wb": -0.10, "rf": 0.06, "rr": 0.20, "rb": 0.33, "tail": 0.90},
    "hatch": {"nose": 0.55, "hood_z": -0.36, "hood_y": 0.88, "wb": -0.18, "rf": -0.04, "rr": 0.30, "rb": 0.40, "tail": 1.00},
    "suv": {"nose": 0.62, "hood_z": -0.40, "hood_y": 0.92, "wb": -0.22, "rf": -0.08, "rr": 0.40, "rb": 0.47, "tail": 1.00},
    "muscle": {"nose": 0.5, "hood_z": -0.43, "hood_y": 0.90, "wb": -0.04, "rf": 0.06, "rr": 0.18, "rb": 0.30, "tail": 0.97},
    "fastback": {"nose": 0.45, "hood_z": -0.38, "hood_y": 0.78, "wb": -0.12, "rf": 0.02, "rr": 0.12, "rb": 0.45, "tail": 0.78},
    "gt": {"nose": 0.42, "hood_z": -0.42, "hood_y": 0.74, "wb": -0.08, "rf": 0.04, "rr": 0.16, "rb": 0.38, "tail": 0.80},
    "super": {"nose": 0.40, "hood_z": -0.40, "hood_y": 0.70, "wb": -0.06, "rf": 0.08, "rr": 0.18, "rb": 0.30, "tail": 0.82},
    "wedge": {"nose": 0.30, "hood_z": -0.46, "hood_y": 0.60, "wb": -0.12, "rf": 0.0, "rr": 0.14, "rb": 0.30, "tail": 0.78},
}

static var _cache: Dictionary = {}
static var _blob_tex: ImageTexture


## Returns {"root": Node3D, "wheels": Array[Node3D] (FL, FR, RL, RR), "tail_mat": Material or null}.
static func build(car: Dictionary) -> Dictionary:
    var imported := _try_import(car)
    if not imported.is_empty():
        return imported
    return _procedural(car)


static func _try_import(car: Dictionary) -> Dictionary:
    var path := "res://assets/models/%s.glb" % str(car["id"])
    if not ResourceLoader.exists(path):
        return {}
    var res: Resource = load(path)
    if not (res is PackedScene):
        return {}
    var inst: Node = (res as PackedScene).instantiate()
    var wheels: Array = []
    for nm in ["Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"]:
        var w := inst.find_child(nm, true, false)
        if w == null or not (w is Node3D):
            push_warning("CarBuilder: %s lacks node %s - using procedural model" % [path, nm])
            inst.free()
            return {}
        wheels.append(w)
    var root := Node3D.new()
    root.add_child(inst)
    return {"root": root, "wheels": wheels, "tail_mat": null}


# --- materials -----------------------------------------------------------------------------
static func _m(c: Color, metal: float = 0.0, rough: float = 0.6) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.metallic = metal
    m.roughness = rough
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    return m


static func _emit(c: Color, energy: float) -> StandardMaterial3D:
    var m := _m(c, 0.0, 0.3)
    m.emission_enabled = true
    m.emission = c
    m.emission_energy_multiplier = energy
    return m


static func _materials(car: Dictionary) -> Dictionary:
    var col := Color.html(str(car["color"]))
    var paint := _m(col, 0.7, 0.26)
    paint.clearcoat_enabled = true
    paint.clearcoat = 1.0
    paint.clearcoat_roughness = 0.08
    var striped: bool = car.get("stripe", false)
    var roof: StandardMaterial3D = paint
    if striped:
        roof = _m(Color(0.95, 0.95, 0.95), 0.6, 0.3)
    return {
        "paint": paint, "roof": roof,
        "glass": _m(Color(0.04, 0.07, 0.1), 0.95, 0.04),
        "dark": _m(Color(0.03, 0.03, 0.035), 0.3, 0.55),
        "chrome": _m(Color(0.85, 0.87, 0.9), 1.0, 0.12),
        "plate": _m(Color(0.95, 0.95, 0.9), 0.0, 0.6),
        "head": _emit(Color(1.0, 0.97, 0.85), 2.5),
        "tail": _emit(Color(1.0, 0.04, 0.04), 1.6),
        "tire": _m(Color(0.025, 0.025, 0.027), 0.0, 0.85),
        "rim": _m(Color(0.82, 0.84, 0.9), 0.95, 0.22),
        "disc": _m(Color(0.35, 0.36, 0.4), 0.8, 0.5),
        "caliper": _m(Color(0.8, 0.1, 0.08), 0.3, 0.5),
        "arch": _m(Color(0.01, 0.01, 0.012), 0.0, 1.0),
    }


static func _apply(mi: MeshInstance3D, keys: Array, mats: Dictionary) -> void:
    for i in keys.size():
        mi.set_surface_override_material(i, mats.get(keys[i]))


# --- geometry ---------------------------------------------------------------------------------
static func _frame(k: MeshKit, cx: float, cy: float, w: float, h: float, z: float) -> void:
    var t := 0.014
    k.box("chrome", Vector3(w + t, t, 0.035), Vector3(cx, cy + h * 0.5, z))
    k.box("chrome", Vector3(w + t, t, 0.035), Vector3(cx, cy - h * 0.5, z))
    k.box("chrome", Vector3(t, h, 0.035), Vector3(cx - w * 0.5, cy, z))
    k.box("chrome", Vector3(t, h, 0.035), Vector3(cx + w * 0.5, cy, z))


static func _grille(k: MeshKit, kind: String, W: float, gy: float, gh: float, z: float) -> void:
    match kind:
        "kidney":
            for sx: float in [-1.0, 1.0]:
                k.box("dark", Vector3(W * 0.13, gh, 0.03), Vector3(sx * W * 0.085, gy, z))
                _frame(k, sx * W * 0.085, gy, W * 0.13, gh, z - 0.004)
                for j in 3:
                    k.box("chrome", Vector3(0.008, gh * 0.9, 0.032), Vector3(sx * W * 0.085 + float(j - 1) * W * 0.03, gy, z - 0.002))
        "single":
            k.box("dark", Vector3(W * 0.46, gh * 1.15, 0.03), Vector3(0.0, gy, z))
            _frame(k, 0.0, gy, W * 0.46, gh * 1.15, z - 0.004)
            for j in 4:
                k.box("chrome", Vector3(W * 0.44, 0.008, 0.032), Vector3(0.0, gy + (float(j) - 1.5) * gh * 0.26, z - 0.002))
        "slats":
            k.box("dark", Vector3(W * 0.5, gh, 0.028), Vector3(0.0, gy, z))
            for j in 4:
                k.box("chrome", Vector3(W * 0.5, 0.02, 0.034), Vector3(0.0, gy + (float(j) - 1.5) * gh * 0.28, z - 0.003))
        "slats_v":
            k.box("dark", Vector3(W * 0.46, gh, 0.028), Vector3(0.0, gy, z))
            for j in 9:
                k.box("chrome", Vector3(0.012, gh * 0.95, 0.034), Vector3(float(j - 4) * W * 0.05, gy, z - 0.003))
            _frame(k, 0.0, gy, W * 0.46, gh, z - 0.004)
        "vent":
            k.box("dark", Vector3(W * 0.55, gh * 0.9, 0.03), Vector3(0.0, gy, z))
            for sx: float in [-1.0, 1.0]:
                k.box("dark", Vector3(W * 0.15, gh * 0.8, 0.03), Vector3(sx * W * 0.39, gy, z))
            k.box("chrome", Vector3(W * 0.55, 0.01, 0.034), Vector3(0.0, gy + gh * 0.15, z - 0.003))
        "wide":
            k.box("dark", Vector3(W * 0.62, gh * 0.65, 0.03), Vector3(0.0, gy, z))
            _frame(k, 0.0, gy, W * 0.62, gh * 0.65, z - 0.004)
        _:
            k.box("dark", Vector3(W * 0.5, gh, 0.03), Vector3(0.0, gy, z))
            for j in 3:
                k.box("chrome", Vector3(W * 0.5, 0.012, 0.034), Vector3(0.0, gy + float(j - 1) * gh * 0.3, z - 0.003))
            _frame(k, 0.0, gy, W * 0.5, gh, z - 0.004)


static func _headlights(k: MeshKit, kind: String, W: float, hy: float, z: float) -> void:
    for sx: float in [-1.0, 1.0]:
        var x := sx * W * 0.31
        match kind:
            "round":
                k.lathe("chrome", PackedVector2Array([Vector2(0.1, -0.02), Vector2(0.1, 0.03)]), 16, Vector3(x, hy, z), Vector3(0.0, PI * 0.5, 0.0))
                k.lathe("head", PackedVector2Array([Vector2(0.0, -0.03), Vector2(0.085, -0.03), Vector2(0.085, 0.02), Vector2(0.0, 0.02)]), 16, Vector3(x, hy, z - 0.005), Vector3(0.0, PI * 0.5, 0.0))
            "slim":
                k.box("dark", Vector3(W * 0.22, 0.07, 0.04), Vector3(x, hy, z + 0.01), Vector3(0.0, 0.0, sx * -0.12))
                k.box("head", Vector3(W * 0.2, 0.04, 0.05), Vector3(x, hy, z - 0.005), Vector3(0.0, 0.0, sx * -0.12))
            _:
                k.box("dark", Vector3(W * 0.24, 0.085, 0.04), Vector3(x, hy, z + 0.01))
                k.box("head", Vector3(W * 0.22, 0.026, 0.052), Vector3(x, hy + 0.012, z - 0.006))
                k.box("head", Vector3(W * 0.07, 0.04, 0.052), Vector3(x - sx * W * 0.07, hy - 0.016, z - 0.006))


static func _taillights(k: MeshKit, kind: String, W: float, ty: float, z: float) -> void:
    match kind:
        "bar":
            k.box("tail", Vector3(W * 0.84, 0.045, 0.04), Vector3(0.0, ty + 0.02, z))
            for sx: float in [-1.0, 1.0]:
                k.box("tail", Vector3(W * 0.2, 0.1, 0.045), Vector3(sx * W * 0.37, ty, z))
        "round":
            for sx: float in [-1.0, 1.0]:
                k.lathe("chrome", PackedVector2Array([Vector2(0.085, -0.02), Vector2(0.085, 0.02)]), 14, Vector3(sx * W * 0.33, ty, z), Vector3(0.0, PI * 0.5, 0.0))
                k.lathe("tail", PackedVector2Array([Vector2(0.0, -0.02), Vector2(0.07, -0.02), Vector2(0.07, 0.03), Vector2(0.0, 0.03)]), 14, Vector3(sx * W * 0.33, ty, z + 0.004), Vector3(0.0, PI * 0.5, 0.0))
        _:
            for sx: float in [-1.0, 1.0]:
                k.box("tail", Vector3(W * 0.2, 0.1, 0.045), Vector3(sx * W * 0.34, ty, z))
                k.box("tail", Vector3(W * 0.1, 0.05, 0.045), Vector3(sx * W * 0.2, ty + 0.02, z))


static func _wheel_mesh(R: float) -> Dictionary:
    var kw := MeshKit.new()
    var ww := R * 0.78
    var rr := R * 0.62
    var ox := ww * 0.5 - 0.012
    kw.lathe("tire", PackedVector2Array([
        Vector2(R * 0.60, -ww * 0.5), Vector2(R * 0.9, -ww * 0.5), Vector2(R * 0.985, -ww * 0.38), Vector2(R, -ww * 0.2),
        Vector2(R, ww * 0.2), Vector2(R * 0.985, ww * 0.38), Vector2(R * 0.9, ww * 0.5), Vector2(R * 0.62, ww * 0.5)]), 20)
    kw.lathe("rim", PackedVector2Array([Vector2(rr, ww * 0.5 - 0.06), Vector2(rr, ww * 0.5 - 0.004)]), 20)
    kw.lathe("rim", PackedVector2Array([Vector2(R * 0.17, ox), Vector2(0.0, ox)]), 14)
    kw.lathe("disc", PackedVector2Array([Vector2(rr * 0.97, ox - 0.05), Vector2(0.0, ox - 0.05)]), 20)
    for s in 5:
        var ang := TAU * float(s) / 5.0
        var dist := R * 0.38
        kw.box("rim", Vector3(0.016, R * 0.46, R * 0.12), Vector3(ox, cos(ang) * dist, sin(ang) * dist), Vector3(ang, 0.0, 0.0))
    kw.box("caliper", Vector3(0.05, R * 0.3, R * 0.2), Vector3(ox - 0.07, R * 0.28, -R * 0.1))
    var mesh := kw.build()
    return {"mesh": mesh, "keys": kw.surface_keys, "ww": ww}


static func _make_meshes(car: Dictionary) -> Dictionary:
    var L: float = car["len"]
    var W: float = car["wid"]
    var H: float = car["hei"]
    var CH: float = car["cabin"]
    var R: float = float(car.get("wheel", WHEEL_R))
    var sty: Dictionary = STYLES.get(str(car.get("style", "sedan")), STYLES["sedan"])
    var nose: float = sty["nose"]
    var hood_z: float = sty["hood_z"]
    var hood_y: float = sty["hood_y"]
    var wb: float = sty["wb"]
    var rf: float = sty["rf"]
    var rr: float = sty["rr"]
    var rb: float = sty["rb"]
    var tail: float = sty["tail"]
    var y0 := R * 0.72
    var roof_y := y0 + H + CH
    var k := MeshKit.new()
    # --- shell
    k.extrude("paint", PackedVector2Array([
        Vector2(-0.5 * L, y0), Vector2(-0.5 * L, y0 + nose * H), Vector2(hood_z * L, y0 + hood_y * H),
        Vector2(wb * L, y0 + H), Vector2(rb * L, y0 + H), Vector2(0.5 * L, y0 + tail * H), Vector2(0.5 * L, y0)]), W, 0.05)
    k.extrude("glass", PackedVector2Array([
        Vector2(wb * L, y0 + H - 0.02), Vector2(rf * L, roof_y), Vector2(rr * L, roof_y), Vector2(rb * L, y0 + H - 0.02)]), W * 0.9, 0.2)
    k.extrude("roof", PackedVector2Array([
        Vector2(rf * L - 0.02, roof_y - 0.02), Vector2(rr * L + 0.02, roof_y - 0.02),
        Vector2(rr * L + 0.02, roof_y + 0.035), Vector2(rf * L - 0.02, roof_y + 0.035)]), W * 0.74, 0.0)
    var zmid := (rf + rr) * 0.5 * L
    for sx: float in [-1.0, 1.0]:
        k.box("dark", Vector3(0.05, CH * 0.95, 0.07), Vector3(sx * W * 0.395, y0 + H + CH * 0.5, zmid))
    # --- lower trim
    k.box("dark", Vector3(W * 1.0, 0.1, 0.28), Vector3(0.0, y0 + 0.06, -L * 0.5 + 0.06))
    k.box("dark", Vector3(W * 1.0, 0.12, 0.24), Vector3(0.0, y0 + 0.08, L * 0.5 - 0.05))
    for sx: float in [-1.0, 1.0]:
        k.box("dark", Vector3(0.05, 0.09, L * 0.4), Vector3(sx * W * 0.5, y0 + 0.07, 0.0))
    # --- front / rear details
    var gh := maxf(nose * H * 0.5, 0.1)
    _grille(k, str(car.get("grille", "mesh")), W, y0 + nose * H * 0.55, gh, -L * 0.5 - 0.012)
    _headlights(k, str(car.get("headlight", "led_strip")), W, y0 + nose * H * 0.92, -L * 0.5 - 0.012)
    _taillights(k, str(car.get("taillight", "bar")), W, y0 + tail * H * 0.78, L * 0.5 + 0.012)
    k.box("plate", Vector3(0.5, 0.12, 0.02), Vector3(0.0, y0 + 0.14, -L * 0.5 - 0.01))
    k.box("plate", Vector3(0.5, 0.12, 0.02), Vector3(0.0, y0 + tail * H * 0.4, L * 0.5 + 0.012))
    for sx: float in [-1.0, 1.0]:
        k.lathe("chrome", PackedVector2Array([Vector2(0.04, -0.06), Vector2(0.04, 0.06)]), 10, Vector3(sx * W * 0.27, y0 + 0.06, L * 0.5 + 0.03), Vector3(0.0, PI * 0.5, 0.0))
        k.box("paint", Vector3(0.12, 0.09, 0.16), Vector3(sx * (W * 0.5 + 0.07), y0 + H + 0.05, wb * L + 0.12))
        var sx_body := sx * (W * 0.5 * 0.985 + 0.004)
        for f: float in [0.03, 0.5, 0.94]:
            k.box("dark", Vector3(0.012, H * 0.78, 0.012), Vector3(sx_body, y0 + H * 0.5 + 0.03, lerpf(wb * L, rb * L, f)))
        for f: float in [0.36, 0.78]:
            k.box("chrome", Vector3(0.012, 0.025, 0.14), Vector3(sx_body, y0 + H * 0.78, lerpf(wb * L, rb * L, f)))
    if str(car.get("style", "")) == "muscle":
        k.box("dark", Vector3(W * 0.3, 0.05, L * 0.14), Vector3(0.0, y0 + (hood_y + 1.0) * 0.5 * H + 0.03, (hood_z + wb) * 0.5 * L))
    if bool(car.get("spoiler", false)):
        for sx: float in [-1.0, 1.0]:
            k.box("dark", Vector3(0.06, 0.26, 0.12), Vector3(sx * W * 0.3, y0 + tail * H + 0.1, L * 0.5 - 0.24))
        k.box("paint", Vector3(W * 0.98, 0.05, 0.4), Vector3(0.0, y0 + tail * H + 0.24, L * 0.5 - 0.24))
    # --- wheel arches (dark discs behind the tyres)
    var wx := W * 0.5 - R * 0.78 * 0.5 + 0.03
    var wz := L * 0.31
    for sx: float in [-1.0, 1.0]:
        for sz: float in [-1.0, 1.0]:
            k.lathe("arch", PackedVector2Array([Vector2(0.0, -0.01), Vector2(R * 1.18, -0.01), Vector2(R * 1.18, 0.012), Vector2(0.0, 0.012)]), 18,
                Vector3(sx * W * 0.5, R, sz * wz))
    var wheel := _wheel_mesh(R)
    return {"body": k.build(), "body_keys": k.surface_keys, "wheel": wheel["mesh"], "wheel_keys": wheel["keys"], "wx": wx, "wz": wz, "R": R}


static func _blob(L: float, W: float) -> MeshInstance3D:
    if _blob_tex == null:
        var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
        for y in 64:
            for x in 64:
                var d := Vector2(float(x) - 31.5, float(y) - 31.5).length() / 32.0
                img.set_pixel(x, y, Color(0, 0, 0, clampf(1.0 - d, 0.0, 1.0) * 0.55))
        _blob_tex = ImageTexture.create_from_image(img)
    var mi := MeshInstance3D.new()
    var q := QuadMesh.new()
    q.size = Vector2(W * 1.5, L * 1.2)
    q.orientation = PlaneMesh.FACE_Y
    mi.mesh = q
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.albedo_texture = _blob_tex
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    mi.material_override = m
    mi.position.y = 0.025
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return mi


static func _procedural(car: Dictionary) -> Dictionary:
    var id := str(car["id"])
    if not _cache.has(id):
        _cache[id] = _make_meshes(car)
    var data: Dictionary = _cache[id]
    var mats := _materials(car)
    var L: float = car["len"]
    var W: float = car["wid"]
    var root := Node3D.new()
    var body := MeshInstance3D.new()
    body.mesh = data["body"]
    _apply(body, data["body_keys"], mats)
    root.add_child(body)
    root.add_child(_blob(L, W))
    var wheels: Array = []
    var R: float = data["R"]
    for p: Vector3 in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1)]:
        var node := Node3D.new()
        node.position = Vector3(p.x * float(data["wx"]), R, p.z * float(data["wz"]))
        var mi := MeshInstance3D.new()
        mi.mesh = data["wheel"]
        _apply(mi, data["wheel_keys"], mats)
        if p.x < 0.0:
            mi.rotation.y = PI
        node.add_child(mi)
        root.add_child(node)
        wheels.append(node)
    return {"root": root, "wheels": wheels, "tail_mat": mats["tail"]}
