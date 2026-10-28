class_name AIDriver
extends RefCounted
## Waypoint-following AI: looks ahead along the centreline, brakes for curvature,
## uses nitro on straights and handbrake drifts on tight corners. Self-recovers when stuck.

var v: Vehicle
var info: TrackInfo
var skill := 0.9
var lane := 0.0
var _stuck := 0.0


func _init(vehicle: Vehicle, track: TrackInfo, s: float, lane_offset: float) -> void:
    v = vehicle
    info = track
    skill = s
    lane = lane_offset


func update(delta: float, rubber: float) -> void:
    if not v.controllable:
        return
    var spd := maxf(v.forward_speed, 0.0)
    var idx := v.track_idx
    var look := 5 + int(spd / 5.0)
    var tgt := info.point(idx + look) + info.right(idx + look) * lane
    var local := v.to_local(tgt)
    var ang := atan2(local.x, -local.z)
    v.input_steer = clampf(ang * 2.2, -1.0, 1.0)

    var t0 := info.tangent(idx + 2)
    var t1 := info.tangent(idx + look + int(spd / 3.0))
    var curv := acos(clampf(t0.dot(t1), -1.0, 1.0))
    var target := v.top_speed * clampf(skill + rubber, 0.6, 1.08) * lerpf(1.0, 0.42, clampf(curv / 0.9, 0.0, 1.0))
    if v.offroad:
        target = minf(target, v.top_speed * 0.45)
    if spd < target:
        v.input_throttle = 1.0
        v.input_brake = 0.0
    else:
        v.input_throttle = 0.0
        v.input_brake = clampf((spd - target - 4.0) / 12.0, 0.0, 1.0)
    v.input_nitro = v.nitro > 0.35 and curv < 0.12 and absf(ang) < 0.15 and spd > 20.0 and skill > 0.85
    v.input_drift = absf(ang) > 0.55 and spd > 28.0 and skill > 0.88

    if spd < 2.0:
        _stuck += delta
    else:
        _stuck = 0.0
    if _stuck > 3.0:
        _stuck = 0.0
        v.respawn(info)
