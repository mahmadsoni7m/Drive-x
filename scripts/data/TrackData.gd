class_name TrackData
extends RefCounted
## Track definitions: closed control loops (x,z in metres) + visual theme.
## Control points are smoothed with a Catmull-Rom spline and resampled every SPACING metres.

const SPACING := 4.0

static var _tracks: Array = []
static var _samples: Dictionary = {}


static func tracks() -> Array:
    if _tracks.is_empty():
        _tracks = _build()
    return _tracks


static func count() -> int:
    return tracks().size()


static func get_track(i: int) -> Dictionary:
    return tracks()[clampi(i, 0, count() - 1)]


static func _build() -> Array:
    return [
        {
            "name": "SUNSET CIRCUIT", "difficulty": 1, "width": 14.0, "seed": 11, "scenery": "pine", "night": false,
            "controls": PackedVector2Array([
                Vector2(-100, -220), Vector2(100, -220), Vector2(240, -140), Vector2(260, 0), Vector2(180, 100),
                Vector2(60, 60), Vector2(-40, 120), Vector2(-60, 240), Vector2(-200, 260), Vector2(-300, 160),
                Vector2(-280, 0), Vector2(-200, -120)]),
            "sky_top": "3a5ba0", "sky_horizon": "ffb26b", "ground": "3f6b35", "fog": "f2b27a", "ambient": 0.9,
            "sun_color": "fff0d0", "sun_energy": 1.25, "sun_rot": Vector3(-32.0, -60.0, 0.0),
            "barrier_a": "f2f2f2", "barrier_b": "d62828",
        },
        {
            "name": "DESERT RUN", "difficulty": 2, "width": 15.0, "seed": 22, "scenery": "rock", "night": false,
            "controls": PackedVector2Array([
                Vector2(0, -250), Vector2(180, -250), Vector2(300, -150), Vector2(300, -20), Vector2(200, 40),
                Vector2(300, 120), Vector2(280, 260), Vector2(120, 300), Vector2(0, 220), Vector2(-120, 300),
                Vector2(-280, 260), Vector2(-300, 100), Vector2(-200, 0), Vector2(-300, -100), Vector2(-200, -230)]),
            "sky_top": "4aa3df", "sky_horizon": "f9e0b0", "ground": "c99a58", "fog": "ecd3a5", "ambient": 1.0,
            "sun_color": "fff4e0", "sun_energy": 1.5, "sun_rot": Vector3(-55.0, 30.0, 0.0),
            "barrier_a": "f2f2f2", "barrier_b": "e07a1f",
        },
        {
            "name": "NEON NIGHT", "difficulty": 3, "width": 14.0, "seed": 33, "scenery": "neon", "night": true,
            "controls": PackedVector2Array([
                Vector2(0, -300), Vector2(200, -300), Vector2(320, -200), Vector2(220, -100), Vector2(320, 0),
                Vector2(200, 120), Vector2(80, 60), Vector2(-40, 160), Vector2(80, 280), Vector2(-120, 320),
                Vector2(-300, 240), Vector2(-320, 60), Vector2(-220, -40), Vector2(-320, -140), Vector2(-200, -280)]),
            "sky_top": "05060f", "sky_horizon": "1b1040", "ground": "0c1018", "fog": "140c2e", "ambient": 0.75,
            "sun_color": "8aa4ff", "sun_energy": 0.55, "sun_rot": Vector3(-45.0, -20.0, 0.0),
            "barrier_a": "19d3ff", "barrier_b": "ff2bd6",
        },
    ]


## Evenly spaced closed centreline (y = 0).
static func sample(i: int) -> PackedVector3Array:
    var idx := clampi(i, 0, count() - 1)
    if _samples.has(idx):
        return _samples[idx]
    var ctrl: PackedVector2Array = get_track(idx)["controls"]
    var k := ctrl.size()
    var dense := PackedVector3Array()
    var steps := 24
    for a in k:
        var p0 := _v3(ctrl[(a - 1 + k) % k])
        var p1 := _v3(ctrl[a])
        var p2 := _v3(ctrl[(a + 1) % k])
        var p3 := _v3(ctrl[(a + 2) % k])
        for s in steps:
            var t := float(s) / float(steps)
            var t2 := t * t
            var t3 := t2 * t
            dense.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
    var m := dense.size()
    var cum := PackedFloat32Array()
    cum.resize(m + 1)
    for q in m:
        cum[q + 1] = cum[q] + dense[q].distance_to(dense[(q + 1) % m])
    var total := cum[m]
    var n := maxi(16, roundi(total / SPACING))
    var out := PackedVector3Array()
    var j := 0
    for q in n:
        var target := total * float(q) / float(n)
        while j < m - 1 and cum[j + 1] < target:
            j += 1
        var seg := cum[j + 1] - cum[j]
        var f := 0.0
        if seg > 0.0001:
            f = (target - cum[j]) / seg
        out.append(dense[j].lerp(dense[(j + 1) % m], f))
    _samples[idx] = out
    return out


static func length_m(i: int) -> float:
    return float(sample(i).size()) * SPACING


static func _v3(v: Vector2) -> Vector3:
    return Vector3(v.x, 0.0, v.y)
