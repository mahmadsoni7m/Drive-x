class_name CameraRig
extends Node3D
## Chase / far / hood / top camera with speed-based FOV and nitro/crash shake.

const MODES: Array = ["CHASE", "FAR", "HOOD", "TOP"]

var target: Vehicle
var mode := 0
var cam: Camera3D
var _dir := Vector3(0, 0, -1)
var _shake := 0.0
var _fov := 68.0


func _ready() -> void:
    cam = Camera3D.new()
    cam.near = 0.1
    cam.far = 700.0
    cam.fov = _fov
    add_child(cam)
    cam.current = true


func set_mode(m: int) -> void:
    mode = posmod(m, MODES.size())


func cycle_mode() -> String:
    set_mode(mode + 1)
    return MODES[mode]


func shake(amount: float) -> void:
    _shake = maxf(_shake, clampf(amount, 0.0, 1.0))


func _process(delta: float) -> void:
    if target == null or cam == null:
        return
    var pos := target.global_position
    var car_fwd := -target.global_transform.basis.z
    car_fwd.y = 0.0
    var vel := target.velocity
    vel.y = 0.0
    var want := car_fwd.normalized()
    if vel.length() > 8.0:
        want = (car_fwd.normalized() + vel.normalized() * 0.5).normalized()
    _dir = _dir.lerp(want, 1.0 - exp(-4.0 * delta)).normalized()
    var sp := clampf(vel.length() / 60.0, 0.0, 1.0)
    var fov_t := 68.0 + sp * 14.0 + (10.0 if target.boosting else 0.0)
    _fov = lerpf(_fov, fov_t, 1.0 - exp(-5.0 * delta))
    cam.fov = _fov
    var desired := pos
    var look := pos
    match mode:
        0:
            desired = pos - _dir * 7.0 + Vector3.UP * 3.0
            look = pos + _dir * 6.0 + Vector3.UP * 1.0
        1:
            desired = pos - _dir * 11.5 + Vector3.UP * 5.0
            look = pos + _dir * 6.0 + Vector3.UP * 0.8
        2:
            var xf := target.global_transform
            desired = xf * Vector3(0.0, 1.15, -0.2)
            look = xf * Vector3(0.0, 1.1, -25.0)
        _:
            desired = pos + Vector3.UP * 30.0 - _dir * 8.0
            look = pos
    if mode == 2:
        cam.global_position = desired
    else:
        cam.global_position = cam.global_position.lerp(desired, 1.0 - exp(-18.0 * delta))
    if cam.global_position.distance_to(look) > 0.01:
        var up := Vector3.UP
        if mode == 3:
            up = _dir
        cam.look_at(look, up)
    var amp := _shake * 0.35
    if target.boosting:
        amp = maxf(amp, 0.04)
    cam.h_offset = randf_range(-amp, amp)
    cam.v_offset = randf_range(-amp, amp)
    _shake = maxf(0.0, _shake - delta * 2.0)
