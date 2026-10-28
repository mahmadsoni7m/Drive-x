class_name CameraRig
extends Node3D
## One camera for both modes. Driving: chase / far / hood / top. On foot: orbit around the person.

const MODES: Array = ["cam.chase", "cam.far", "cam.hood", "cam.top"]

var target: Node3D
var mode := 0
var yaw := 0.0
var pitch := 0.38
var cam: Camera3D
var _dir := Vector3(0, 0, -1)
var _shake := 0.0
var _fov := 68.0


func _ready() -> void:
    cam = Camera3D.new()
    cam.near = 0.1
    cam.far = 2500.0
    cam.fov = _fov
    add_child(cam)
    cam.current = true


func set_mode(m: int) -> void:
    mode = posmod(m, MODES.size())


func cycle_mode() -> String:
    set_mode(mode + 1)
    return str(MODES[mode])


func shake(amount: float) -> void:
    _shake = maxf(_shake, clampf(amount, 0.0, 1.0))


## Drag on screen (pixels) rotates the on-foot camera.
func look(delta_px: Vector2) -> void:
    yaw -= delta_px.x * 0.006
    pitch = clampf(pitch + delta_px.y * 0.004, 0.05, 1.15)


func snap_behind(v: Vector3) -> void:
    _dir = v.normalized()
    cam.global_position = target.global_position - _dir * 7.0 + Vector3.UP * 3.0 if target != null else cam.global_position


func _process(delta: float) -> void:
    if target == null or cam == null:
        return
    if target is Vehicle:
        _car_cam(target as Vehicle, delta)
    else:
        _foot_cam(delta)


func _foot_cam(delta: float) -> void:
    var base := target.global_position + Vector3(0.0, 1.5, 0.0)
    var off := Basis(Vector3.UP, yaw) * Vector3(0.0, sin(pitch) * 5.0, cos(pitch) * 5.0)
    cam.global_position = cam.global_position.lerp(base + off, 1.0 - exp(-14.0 * delta))
    _fov = lerpf(_fov, 68.0, 1.0 - exp(-5.0 * delta))
    cam.fov = _fov
    cam.h_offset = 0.0
    cam.v_offset = 0.0
    if cam.global_position.distance_to(base) > 0.05:
        cam.look_at(base, Vector3.UP)


func _car_cam(v: Vehicle, delta: float) -> void:
    var pos := v.global_position
    var car_fwd := -v.global_transform.basis.z
    car_fwd.y = 0.0
    var vel := v.velocity
    vel.y = 0.0
    var want := car_fwd.normalized()
    if vel.length() > 8.0:
        want = (car_fwd.normalized() + vel.normalized() * 0.5).normalized()
    _dir = _dir.lerp(want, 1.0 - exp(-4.0 * delta)).normalized()
    yaw = atan2(-_dir.x, -_dir.z)
    var sp := clampf(vel.length() / 60.0, 0.0, 1.0)
    var fov_t := 68.0 + sp * 14.0 + (10.0 if v.boosting else 0.0)
    _fov = lerpf(_fov, fov_t, 1.0 - exp(-5.0 * delta))
    cam.fov = _fov
    var desired := pos
    var look_at_pt := pos
    match mode:
        0:
            desired = pos - _dir * 7.0 + Vector3.UP * 3.0
            look_at_pt = pos + _dir * 6.0 + Vector3.UP * 1.0
        1:
            desired = pos - _dir * 11.5 + Vector3.UP * 5.0
            look_at_pt = pos + _dir * 6.0 + Vector3.UP * 0.8
        2:
            var xf := v.global_transform
            desired = xf * Vector3(0.0, 1.15, -0.2)
            look_at_pt = xf * Vector3(0.0, 1.1, -25.0)
        _:
            desired = pos + Vector3.UP * 30.0 - _dir * 8.0
            look_at_pt = pos
    if mode == 2:
        cam.global_position = desired
    else:
        cam.global_position = cam.global_position.lerp(desired, 1.0 - exp(-18.0 * delta))
    if cam.global_position.distance_to(look_at_pt) > 0.01:
        cam.look_at(look_at_pt, _dir if mode == 3 else Vector3.UP)
    var amp := _shake * 0.35
    if v.boosting:
        amp = maxf(amp, 0.04)
    cam.h_offset = randf_range(-amp, amp)
    cam.v_offset = randf_range(-amp, amp)
    _shake = maxf(0.0, _shake - delta * 2.0)
