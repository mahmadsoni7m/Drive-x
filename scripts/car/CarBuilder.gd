class_name CarBuilder
extends RefCounted
## Builds a car visual. If res://assets/models/<id>.glb exists (made with tools/blender/generate_cars.py)
## it is used; otherwise a procedural low-poly model is generated so the game always runs.
## Car convention: forward = -Z, wheels' bottoms at y = 0.

const WHEEL_R := 0.36
const WHEEL_W := 0.28


## Returns {"root": Node3D, "wheels": Array[Node3D]} (order: FL, FR, RL, RR).
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
    return {"root": root, "wheels": wheels}


static func _mat(c: Color, metal: float = 0.0, rough: float = 0.6) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.metallic = metal
    m.roughness = rough
    return m


static func _glow(c: Color, energy: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.emission_enabled = true
    m.emission = c
    m.emission_energy_multiplier = energy
    return m


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.material_override = mat
    mi.position = pos
    parent.add_child(mi)
    return mi


static func _wheel(parent: Node3D, pos: Vector3, tire: Material, rim: Material) -> Node3D:
    var w := Node3D.new()
    w.position = pos
    var tm := MeshInstance3D.new()
    var cyl := CylinderMesh.new()
    cyl.top_radius = WHEEL_R
    cyl.bottom_radius = WHEEL_R
    cyl.height = WHEEL_W
    cyl.radial_segments = 14
    cyl.rings = 1
    tm.mesh = cyl
    tm.material_override = tire
    tm.rotation_degrees = Vector3(0.0, 0.0, 90.0)
    w.add_child(tm)
    var rm := MeshInstance3D.new()
    var rc := CylinderMesh.new()
    rc.top_radius = WHEEL_R * 0.62
    rc.bottom_radius = WHEEL_R * 0.62
    rc.height = WHEEL_W + 0.03
    rc.radial_segments = 10
    rc.rings = 1
    rm.mesh = rc
    rm.material_override = rim
    rm.rotation_degrees = Vector3(0.0, 0.0, 90.0)
    w.add_child(rm)
    parent.add_child(w)
    return w


static func _procedural(car: Dictionary) -> Dictionary:
    var L: float = car["len"]
    var W: float = car["wid"]
    var H: float = car["hei"]
    var CH: float = car["cabin"]
    var col := Color.html(str(car["color"]))
    var root := Node3D.new()
    var paint := _mat(col, 0.6, 0.25)
    var dark := _mat(Color(0.04, 0.04, 0.05), 0.3, 0.5)
    var glass := _mat(Color(0.05, 0.09, 0.14), 0.9, 0.08)
    var y0 := 0.28
    # body, cabin glass and roof
    _box(root, Vector3(W, H, L), Vector3(0.0, y0 + H * 0.5, 0.0), paint)
    var cl := L * 0.42
    _box(root, Vector3(W * 0.84, CH, cl), Vector3(0.0, y0 + H + CH * 0.5 - 0.02, L * 0.07), glass)
    _box(root, Vector3(W * 0.8, 0.05, cl * 0.82), Vector3(0.0, y0 + H + CH, L * 0.08), paint)
    # splitter / diffuser
    _box(root, Vector3(W * 1.02, 0.08, 0.35), Vector3(0.0, y0 + 0.02, -L * 0.5 + 0.1), dark)
    _box(root, Vector3(W, 0.1, 0.3), Vector3(0.0, y0 + 0.04, L * 0.5 - 0.1), dark)
    # lights
    var hl := _glow(Color(1.0, 0.97, 0.8), 2.5)
    var tl := _glow(Color(1.0, 0.05, 0.05), 2.0)
    for sx: float in [-1.0, 1.0]:
        _box(root, Vector3(0.38, 0.1, 0.06), Vector3(sx * W * 0.32, y0 + H * 0.65, -L * 0.5 - 0.01), hl)
        _box(root, Vector3(0.42, 0.1, 0.06), Vector3(sx * W * 0.32, y0 + H * 0.7, L * 0.5 + 0.01), tl)
    # racing stripe
    var stripe: bool = car.get("stripe", false)
    if stripe:
        _box(root, Vector3(0.3, 0.012, L * 0.99), Vector3(0.0, y0 + H + 0.007, 0.0), _mat(Color(0.95, 0.95, 0.95), 0.0, 0.4))
    # spoiler
    var spoiler: bool = car.get("spoiler", false)
    if spoiler:
        for sx: float in [-1.0, 1.0]:
            _box(root, Vector3(0.06, 0.28, 0.12), Vector3(sx * W * 0.3, y0 + H + 0.12, L * 0.5 - 0.22), dark)
        _box(root, Vector3(W * 0.98, 0.05, 0.42), Vector3(0.0, y0 + H + 0.28, L * 0.5 - 0.22), paint)
    # wheels (FL, FR, RL, RR)
    var wx := W * 0.5 - WHEEL_W * 0.5 + 0.03
    var wz := L * 0.31
    var tire := _mat(Color(0.03, 0.03, 0.03), 0.0, 0.9)
    var rim := _mat(Color(0.75, 0.78, 0.85), 0.9, 0.25)
    var wheels: Array = []
    for p: Vector3 in [Vector3(-wx, WHEEL_R, -wz), Vector3(wx, WHEEL_R, -wz), Vector3(-wx, WHEEL_R, wz), Vector3(wx, WHEEL_R, wz)]:
        wheels.append(_wheel(root, p, tire, rim))
    return {"root": root, "wheels": wheels}
