class_name MeshKit
extends RefCounted
## Batches many boxes / extrusions / lathes into ONE ArrayMesh with one surface per material key.
## A car body becomes ~8 draw calls instead of ~60 separate MeshInstance3D nodes.

var surface_keys: Array = []
var _st: Dictionary = {}
var _n: Dictionary = {}


func _s(key: String) -> SurfaceTool:
    if not _st.has(key):
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        _st[key] = st
        _n[key] = 0
    return _st[key]


func _vert(st: SurfaceTool, xf: Transform3D, p: Vector3, n: Vector3) -> void:
    st.set_normal((xf.basis * n).normalized())
    st.add_vertex(xf * p)


func tri(key: String, xf: Transform3D, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
    var st := _s(key)
    _vert(st, xf, a, n)
    _vert(st, xf, b, n)
    _vert(st, xf, c, n)
    _n[key] = int(_n[key]) + 3


func quad(key: String, xf: Transform3D, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
    tri(key, xf, a, b, c, n)
    tri(key, xf, a, c, d, n)


func box(key: String, size: Vector3, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
    var xf := Transform3D(Basis.from_euler(rot), pos)
    var h := size * 0.5
    for ax in 3:
        var n := Vector3.ZERO
        n[ax] = 1.0
        var u := Vector3.ZERO
        u[(ax + 1) % 3] = 1.0
        var v := Vector3.ZERO
        v[(ax + 2) % 3] = 1.0
        for sgn: float in [-1.0, 1.0]:
            var c := n * sgn * h[ax]
            var du := u * h[(ax + 1) % 3]
            var dv := v * h[(ax + 2) % 3]
            quad(key, xf, c - du - dv, c + du - dv, c + du + dv, c - du + dv, n * sgn)


## Side-view polygon (x = along car z, y = height) extruded across the width.
## taper = how much narrower the TOP edge is (tumblehome), 0..0.3.
func extrude(key: String, poly: PackedVector2Array, width: float, taper: float = 0.0) -> void:
    var st := _s(key)
    var hw := width * 0.5
    var n := poly.size()
    var c := Vector2.ZERO
    for pt in poly:
        c += pt
    c /= float(n)
    var ymin := INF
    var ymax := -INF
    for pt in poly:
        ymin = minf(ymin, pt.y)
        ymax = maxf(ymax, pt.y)
    var span := maxf(ymax - ymin, 0.001)
    for i in n:
        var a := poly[i]
        var b := poly[(i + 1) % n]
        var d := b - a
        if d.length() < 0.0001:
            continue
        var perp := Vector2(d.y, -d.x).normalized()
        if perp.dot((a + b) * 0.5 - c) < 0.0:
            perp = -perp
        var nrm := Vector3(0.0, perp.y, perp.x)
        var wa := hw * (1.0 - taper * (a.y - ymin) / span)
        var wb := hw * (1.0 - taper * (b.y - ymin) / span)
        var al := Vector3(-wa, a.y, a.x)
        var ar := Vector3(wa, a.y, a.x)
        var bl := Vector3(-wb, b.y, b.x)
        var br := Vector3(wb, b.y, b.x)
        for p: Vector3 in [al, bl, br, al, br, ar]:
            st.set_normal(nrm)
            st.add_vertex(p)
        _n[key] = int(_n[key]) + 6
    var idx := Geometry2D.triangulate_polygon(poly)
    for k in range(0, idx.size(), 3):
        for sx: float in [-1.0, 1.0]:
            for j in 3:
                var pt := poly[idx[k + j]]
                var w := hw * (1.0 - taper * (pt.y - ymin) / span)
                st.set_normal(Vector3(sx, 0.0, 0.0))
                st.add_vertex(Vector3(sx * w, pt.y, pt.x))
            _n[key] = int(_n[key]) + 3


## Revolve a profile of Vector2(radius, axial_x) around the local X axis.
func lathe(key: String, profile: PackedVector2Array, segs: int, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO) -> void:
    var st := _s(key)
    var xf := Transform3D(Basis.from_euler(rot), pos)
    for i in profile.size() - 1:
        var a := profile[i]
        var b := profile[i + 1]
        var d := b - a
        var nn := Vector2(d.y, -d.x)
        if nn.length() < 0.00001:
            continue
        nn = nn.normalized()
        for s in segs:
            var a0 := TAU * float(s) / float(segs)
            var a1 := TAU * float(s + 1) / float(segs)
            var c0 := cos(a0)
            var s0 := sin(a0)
            var c1 := cos(a1)
            var s1 := sin(a1)
            var p00 := Vector3(a.y, a.x * c0, a.x * s0)
            var p01 := Vector3(a.y, a.x * c1, a.x * s1)
            var p10 := Vector3(b.y, b.x * c0, b.x * s0)
            var p11 := Vector3(b.y, b.x * c1, b.x * s1)
            var n0 := Vector3(nn.y, nn.x * c0, nn.x * s0)
            var n1 := Vector3(nn.y, nn.x * c1, nn.x * s1)
            _vert(st, xf, p00, n0)
            _vert(st, xf, p10, n0)
            _vert(st, xf, p11, n1)
            _vert(st, xf, p00, n0)
            _vert(st, xf, p11, n1)
            _vert(st, xf, p01, n1)
            _n[key] = int(_n[key]) + 6


func build() -> ArrayMesh:
    var mesh := ArrayMesh.new()
    surface_keys = []
    for key in _st:
        if int(_n[key]) == 0:
            continue
        (_st[key] as SurfaceTool).commit(mesh)
        surface_keys.append(key)
    return mesh
