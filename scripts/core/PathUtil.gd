class_name PathUtil
extends RefCounted
## Turns control points (x,z) into evenly spaced Vector3 points (y = 0).
## smooth = Catmull-Rom spline through the points, otherwise straight segments.

static func _v3(v: Vector2) -> Vector3:
    return Vector3(v.x, 0.0, v.y)


static func resample(ctrl: PackedVector2Array, closed: bool, smooth: bool, spacing: float) -> PackedVector3Array:
    var k := ctrl.size()
    var out := PackedVector3Array()
    if k < 2:
        return out
    var dense := PackedVector3Array()
    var segs := k if closed else k - 1
    var steps := 24 if smooth else 1
    for a in segs:
        var i0 := (a - 1 + k) % k if closed else maxi(a - 1, 0)
        var i3 := (a + 2) % k if closed else mini(a + 2, k - 1)
        var p0 := _v3(ctrl[i0])
        var p1 := _v3(ctrl[a])
        var p2 := _v3(ctrl[(a + 1) % k])
        var p3 := _v3(ctrl[i3])
        for s in steps:
            var t := float(s) / float(steps)
            if smooth:
                var t2 := t * t
                var t3 := t2 * t
                dense.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
            else:
                dense.append(p1.lerp(p2, t))
    if not closed:
        dense.append(_v3(ctrl[k - 1]))
    var m := dense.size()
    var seg_count := m if closed else m - 1
    var cum := PackedFloat32Array()
    cum.resize(seg_count + 1)
    for i in seg_count:
        cum[i + 1] = cum[i] + dense[i].distance_to(dense[(i + 1) % m])
    var total := cum[seg_count]
    var n := maxi(2, roundi(total / spacing))
    var count := n if closed else n + 1
    var j := 0
    for q in count:
        var target := total * float(q) / float(n)
        while j < seg_count - 1 and cum[j + 1] < target:
            j += 1
        var seg := cum[j + 1] - cum[j]
        var f := 0.0
        if seg > 0.0001:
            f = clampf((target - cum[j]) / seg, 0.0, 1.0)
        out.append(dense[j].lerp(dense[(j + 1) % m], f))
    return out
