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


const STYLES: Dictionary = {
    "sedan": {"nose": 0.5, "hood_z": -0.37, "hood_y": 0.84, "wb": -0.14, "rf": 0.02, "rr": 0.24, "rb": 0.36, "tail": 0.95},
    "coupe": {"nose": 0.5, "hood_z": -0.38, "hood_y": 0.82, "wb": -0.10, "rf": 0.06, "rr": 0.20, "rb": 0.33, "tail": 0.90},
    "hatch": {"nose": 0.55, "hood_z": -0.36, "hood_y": 0.88, "wb": -0.18, "rf": -0.04, "rr": 0.30, "rb": 0.40, "tail": 1.00},
    "super": {"nose": 0.40, "hood_z": -0.40, "hood_y": 0.70, "wb": -0.06, "rf": 0.08, "rr": 0.18, "rb": 0.30, "tail": 0.82},
}


static func _paint_mat(c: Color, metal: float, rough: float) -> StandardMaterial3D:
    var m := _mat(c, metal, rough)
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    return m


## Extrudes a side-view polygon (x = z-along-car, y = height) across the car width.
static func _extrude(parent: Node3D, poly: PackedVector2Array, width: float, mat: Material) -> void:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var hw := width * 0.5
    var n := poly.size()
    var c := Vector2.ZERO
    for pt in poly:
        c += pt
    c /= float(n)
    for i in n:
        var a := poly[i]
        var b := poly[(i + 1) % n]
        var d := b - a
        var perp := Vector2(d.y, -d.x).normalized()
        if perp.dot((a + b) * 0.5 - c) < 0.0:
            perp = -perp
        var nrm := Vector3(0.0, perp.y, perp.x)
        var al := Vector3(-hw, a.y, a.x)
        var ar := Vector3(hw, a.y, a.x)
        var bl := Vector3(-hw, b.y, b.x)
        var br := Vector3(hw, b.y, b.x)
        for v: Vector3 in [al, bl, br, al, br, ar]:
            st.set_normal(nrm)
            st.add_vertex(v)
    var idx := Geometry2D.triangulate_polygon(poly)
    for k in range(0, idx.size(), 3):
        for sx: float in [-1.0, 1.0]:
            for j in 3:
                var pt := poly[idx[k + j]]
                st.set_normal(Vector3(sx, 0.0, 0.0))
                st.add_vertex(Vector3(sx * hw, pt.y, pt.x))
    var mi := MeshInstance3D.new()
    mi.mesh = st.commit()
    mi.material_override = mat
    parent.add_child(mi)


static func _procedural(car: Dictionary) -> Dictionary:
    var L: float = car["len"]
    var W: float = car["wid"]
    var H: float = car["hei"]
    var CH: float = car["cabin"]
    var st: Dictionary = STYLES.get(str(car.get("style", "sedan")), STYLES["sedan"])
    var col := Color.html(str(car["color"]))
    var striped: bool = car.get("stripe", false)
    var spoiler: bool = car.get("spoiler", false)
    var root := Node3D.new()
    var paint := _paint_mat(col, 0.55, 0.3)
    var dark := _mat(Color(0.04, 0.04, 0.05), 0.3, 0.5)
    var glass := _paint_mat(Color(0.1, 0.16, 0.24), 0.85, 0.08)
    var roof_mat := _paint_mat(Color(0.96, 0.96, 0.96) if striped else col, 0.55, 0.3)
    var y0 := 0.26
    var roof_y := y0 + H + CH
    var nose: float = st["nose"]
    var hood_z: float = st["hood_z"]
    var hood_y: float = st["hood_y"]
    var wb: float = st["wb"]
    var rf: float = st["rf"]
    var rr: float = st["rr"]
    var rb: float = st["rb"]
    var tail: float = st["tail"]
    # lower body (bonnet, doors, boot)
    _extrude(root, PackedVector2Array([
        Vector2(-0.5 * L, y0), Vector2(-0.5 * L, y0 + nose * H), Vector2(hood_z * L, y0 + hood_y * H),
        Vector2(wb * L, y0 + H), Vector2(rb * L, y0 + H), Vector2(0.5 * L, y0 + tail * H), Vector2(0.5 * L, y0)]), W, paint)
    # greenhouse (windows) and roof panel
    _extrude(root, PackedVector2Array([
        Vector2(wb * L, y0 + H - 0.02), Vector2(rf * L, roof_y), Vector2(rr * L, roof_y), Vector2(rb * L, y0 + H - 0.02)]), W * 0.86, glass)
    _extrude(root, PackedVector2Array([
        Vector2(rf * L - 0.02, roof_y - 0.02), Vector2(rr * L + 0.02, roof_y - 0.02),
        Vector2(rr * L + 0.02, roof_y + 0.035), Vector2(rf * L - 0.02, roof_y + 0.035)]), W * 0.84, roof_mat)
    # bumpers, grille, side skirts
    _box(root, Vector3(W * 1.02, 0.12, 0.3), Vector3(0.0, y0 + 0.07, -L * 0.5 + 0.08), dark)
    _box(root, Vector3(W * 1.0, 0.14, 0.26), Vector3(0.0, y0 + 0.09, L * 0.5 - 0.06), dark)
    _box(root, Vector3(W * 0.5, 0.1, 0.05), Vector3(0.0, y0 + nose * H * 0.7, -L * 0.5 - 0.02), dark)
    for sx: float in [-1.0, 1.0]:
        _box(root, Vector3(0.06, 0.1, L * 0.45), Vector3(sx * (W * 0.5 + 0.01), y0 + 0.08, 0.0), dark)
        _box(root, Vector3(0.1, 0.1, 0.14), Vector3(sx * (W * 0.5 + 0.06), y0 + H + 0.06, wb * L + 0.1), paint)
    # lights
    var hl := _glow(Color(1.0, 0.97, 0.8), 2.5)
    var tl := _glow(Color(1.0, 0.05, 0.05), 2.0)
    for sx: float in [-1.0, 1.0]:
        _box(root, Vector3(0.36, 0.1, 0.06), Vector3(sx * W * 0.32, y0 + nose * H * 0.95, -L * 0.5 - 0.03), hl)
        _box(root, Vector3(0.4, 0.09, 0.06), Vector3(sx * W * 0.32, y0 + tail * H * 0.8, L * 0.5 + 0.02), tl)
    if spoiler:
        for sx: float in [-1.0, 1.0]:
            _box(root, Vector3(0.06, 0.26, 0.12), Vector3(sx * W * 0.3, y0 + tail * H + 0.1, L * 0.5 - 0.24), dark)
        _box(root, Vector3(W * 0.98, 0.05, 0.4), Vector3(0.0, y0 + tail * H + 0.24, L * 0.5 - 0.24), paint)
    # wheels (FL, FR, RL, RR)
    var wx := W * 0.5 - WHEEL_W * 0.5 + 0.03
    var wz := L * 0.31
    var tire := _mat(Color(0.03, 0.03, 0.03), 0.0, 0.9)
    var rim := _mat(Color(0.8, 0.82, 0.88), 0.9, 0.25)
    var wheels: Array = []
    for p: Vector3 in [Vector3(-wx, WHEEL_R, -wz), Vector3(wx, WHEEL_R, -wz), Vector3(-wx, WHEEL_R, wz), Vector3(wx, WHEEL_R, wz)]:
        wheels.append(_wheel(root, p, tire, rim))
    return {"root": root, "wheels": wheels}
