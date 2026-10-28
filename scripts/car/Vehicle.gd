class_name Vehicle
extends CharacterBody3D
## Arcade-realistic car: forward/lateral velocity decomposition with grip model,
## handbrake drifting, nitro, off-road drag and wall collisions (CharacterBody3D, floating mode).
## Inputs are plain fields so the same body is driven by the player or by AIDriver.

signal crashed(impact: float)
signal lap_completed(lap_time: float)

const GRIP_BASE := 6.0
const GRIP_DRIFT := 1.7

var racer_name := "PLAYER"
var car: Dictionary = {}
var is_player := false

var top_speed := 46.0
var accel := 15.0
var handling := 1.0
var grip_mult := 1.0
var nitro_mult := 1.0

var input_throttle := 0.0
var input_brake := 0.0
var input_steer := 0.0
var input_drift := false
var input_nitro := false
var controllable := false

var steer_cur := 0.0
var nitro := 0.5
var boosting := false
var drifting := false
var drift_time := 0.0
var offroad := false
var surface_speed := 1.0
var surface_grip := 1.0
var forward_speed := 0.0
var speed_kmh := 0.0

var lap := 0
var track_idx := 0
var progress := 0.0
var lateral_offset := 0.0
var finished := false
var finish_time := 0.0
var best_lap := INF
var wrong_way := false

var _model: Node3D
var _wheels: Array = []
var _grip := GRIP_BASE
var _wheel_spin := 0.0
var _roll := 0.0
var _pitch := 0.0
var _long_acc := 0.0
var _crash_cd := 0.0
var _lap_start := 0.0
var _smoke_l: CPUParticles3D
var _smoke_r: CPUParticles3D
var _flame: CPUParticles3D


func setup(car_data: Dictionary, stats: Dictionary, player: bool, rname: String) -> void:
    car = car_data
    is_player = player
    racer_name = rname
    top_speed = float(stats["top"])
    accel = float(stats["accel"])
    handling = float(stats["handling"])
    grip_mult = float(stats["grip"])
    nitro_mult = float(stats["nitro"])
    motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
    collision_layer = 4
    collision_mask = 1 | 4
    var built := CarBuilder.build(car_data)
    _model = built["root"]
    add_child(_model)
    _wheels = built["wheels"]
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(float(car_data["wid"]) * 0.95, 0.9, float(car_data["len"]) * 0.95)
    shape.shape = box
    shape.position.y = 0.65
    add_child(shape)
    _build_fx()


func add_headlights() -> void:
    var spot := SpotLight3D.new()
    spot.position = Vector3(0.0, 0.8, -float(car["len"]) * 0.5)
    spot.rotation_degrees = Vector3(-4.0, 0.0, 0.0)
    spot.spot_range = 70.0
    spot.spot_angle = 32.0
    spot.light_energy = 4.0
    add_child(spot)


func _make_particles(c0: Color, c1: Color, amount: int, life: float, vmin: float, vmax: float, size: float) -> CPUParticles3D:
    var p := CPUParticles3D.new()
    p.amount = amount
    p.lifetime = life
    p.emitting = false
    p.local_coords = false
    p.direction = Vector3(0.0, 0.4, 1.0)
    p.spread = 25.0
    p.initial_velocity_min = vmin
    p.initial_velocity_max = vmax
    p.gravity = Vector3(0.0, 0.6, 0.0)
    p.scale_amount_min = 0.6
    p.scale_amount_max = 1.6
    var m := SphereMesh.new()
    m.radius = size
    m.height = size * 2.0
    m.radial_segments = 6
    m.rings = 3
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.vertex_color_use_as_albedo = true
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.material = mat
    p.mesh = m
    var g := Gradient.new()
    g.set_color(0, c0)
    g.set_color(1, c1)
    p.color_ramp = g
    return p


func _build_fx() -> void:
    var L := float(car["len"])
    var W := float(car["wid"])
    _smoke_l = _make_particles(Color(0.9, 0.9, 0.9, 0.55), Color(0.9, 0.9, 0.9, 0.0), 24, 0.9, 1.0, 2.5, 0.35)
    _smoke_r = _make_particles(Color(0.9, 0.9, 0.9, 0.55), Color(0.9, 0.9, 0.9, 0.0), 24, 0.9, 1.0, 2.5, 0.35)
    _smoke_l.position = Vector3(-W * 0.4, 0.2, L * 0.31)
    _smoke_r.position = Vector3(W * 0.4, 0.2, L * 0.31)
    _flame = _make_particles(Color(1.0, 0.8, 0.3, 0.95), Color(1.0, 0.2, 0.05, 0.0), 20, 0.25, 6.0, 9.0, 0.16)
    _flame.position = Vector3(0.0, 0.45, L * 0.5 + 0.1)
    _flame.spread = 8.0
    _flame.gravity = Vector3.ZERO
    add_child(_smoke_l)
    add_child(_smoke_r)
    add_child(_flame)


## Apply road-surface effects (WorldData.K_*): grass is slow and slippery, dirt less so.
func set_surface(kind: int) -> void:
    surface_speed = float(WorldData.SPEED_MULT[kind])
    surface_grip = float(WorldData.GRIP_MULT[kind])
    offroad = kind == WorldData.K_GRASS


func place(xform: Transform3D, idx: int) -> void:
    global_transform = xform
    velocity = Vector3.ZERO
    track_idx = idx
    steer_cur = 0.0
    _grip = GRIP_BASE * grip_mult


func respawn(info: TrackInfo, idx: int = -1) -> void:
    if idx < 0:
        idx = track_idx
    idx = posmod(idx + 1, info.count())
    place(Transform3D(Basis.looking_at(info.tangent(idx), Vector3.UP), info.point(idx)), idx)


func update_progress(info: TrackInfo, now: float) -> void:
    var n := info.count()
    var new_idx := info.nearest_index(global_position, track_idx)
    if track_idx > int(n * 0.75) and new_idx < int(n * 0.25):
        lap += 1
        if lap >= 2:
            var lt := now - _lap_start
            best_lap = minf(best_lap, lt)
            lap_completed.emit(lt)
        _lap_start = now
    elif track_idx < int(n * 0.25) and new_idx > int(n * 0.75):
        lap -= 1
    track_idx = new_idx
    lateral_offset = info.lateral_offset(global_position, new_idx)
    progress = float(lap * n + track_idx)
    wrong_way = is_player and controllable and forward_speed > 3.0 and velocity.normalized().dot(info.tangent(new_idx)) < -0.3


func _physics_process(delta: float) -> void:
    var thr := input_throttle if controllable else 0.0
    var brk := input_brake if controllable else 0.0
    var steer_in := input_steer if controllable else 0.0
    var handbrake := input_drift and controllable
    var want_nitro := input_nitro and controllable
    if _crash_cd > 0.0:
        _crash_cd -= delta

    var vel := velocity
    vel.y = 0.0
    var fwd := -global_transform.basis.z
    var vf := vel.dot(fwd)

    # --- steering -> yaw
    steer_cur = move_toward(steer_cur, steer_in, delta * (4.5 if absf(steer_in) > 0.01 else 7.0))
    var steer_scale := clampf(absf(vf) / 5.0, 0.0, 1.0) * (1.0 - 0.5 * clampf(absf(vf) / (top_speed * 1.1), 0.0, 1.0))
    var dir_sign := 1.0
    if vf < -0.1:
        dir_sign = -1.0
    var yaw_rate := steer_cur * 1.9 * handling * steer_scale * dir_sign
    if handbrake and absf(vf) > 12.0:
        yaw_rate *= 1.35
    rotate_y(-yaw_rate * delta)

    # --- re-decompose velocity in the new heading
    fwd = -global_transform.basis.z
    var right := global_transform.basis.x
    vf = vel.dot(fwd)
    var vl := vel.dot(right)

    var hb_active := handbrake and absf(vf) > 12.0
    var slip := absf(atan2(vl, maxf(absf(vf), 0.1)))
    drifting = (hb_active and absf(vl) > 1.5) or (slip > 0.4 and absf(vf) > 10.0)

    # --- nitro
    boosting = want_nitro and nitro > 0.0 and vf > 3.0
    if boosting:
        nitro = maxf(0.0, nitro - delta / (3.2 * nitro_mult))
    else:
        nitro = minf(1.0, nitro + delta * 0.01)
    if drifting and absf(vl) > 2.0:
        drift_time += delta
        nitro = minf(1.0, nitro + delta * 0.08)

    # --- longitudinal
    var max_sp := top_speed * (1.3 if boosting else 1.0)
    max_sp *= surface_speed
    var a := 0.0
    if thr > 0.0:
        if vf < -0.5:
            a = 30.0 * thr
        else:
            var ratio := clampf(vf / max_sp, 0.0, 1.0)
            a = accel * 0.9 * thr * (1.0 - pow(ratio, 1.5))
        if boosting:
            a += accel * 0.9
    if brk > 0.0:
        if vf > 1.0:
            a -= 34.0 * brk
        elif vf > -14.0:
            a -= accel * 0.5 * brk
    if thr == 0.0 and brk == 0.0:
        a -= signf(vf) * 3.0
    if vf > max_sp:
        a -= (vf - max_sp) * 2.0
    a -= vf * absf(vf) * 0.0007
    a -= signf(vf) * (1.0 - surface_speed) * 14.0
    if hb_active:
        a -= 4.0 * signf(vf)
    vf += a * delta
    if thr == 0.0 and brk == 0.0 and absf(vf) < 0.25:
        vf = 0.0
    _long_acc = lerpf(_long_acc, a, clampf(delta * 8.0, 0.0, 1.0))

    # --- lateral grip (low while handbraking => slide)
    var grip_target := GRIP_BASE * grip_mult * surface_grip
    if hb_active:
        grip_target = GRIP_DRIFT
    _grip = move_toward(_grip, grip_target, delta * (40.0 if hb_active else 7.0))
    vl *= exp(-_grip * delta)
    if drifting:
        vf = move_toward(vf, 0.0, absf(vl) * 0.3 * delta)

    # --- integrate
    var pre_speed := velocity.length()
    velocity = fwd * vf + right * vl
    velocity.y = 0.0
    move_and_slide()
    global_position.y = 0.0
    velocity.y = 0.0
    var post_speed := velocity.length()
    if pre_speed - post_speed > 9.0 and _crash_cd <= 0.0:
        _crash_cd = 0.5
        crashed.emit(pre_speed - post_speed)

    forward_speed = vf
    speed_kmh = post_speed * 3.6
    _update_visuals(delta, vf, vl)


func _update_visuals(delta: float, vf: float, vl: float) -> void:
    _wheel_spin += vf / CarBuilder.WHEEL_R * delta
    for i in _wheels.size():
        var w: Node3D = _wheels[i]
        var steer_angle := -steer_cur * 0.45 if i < 2 else 0.0
        w.rotation = Vector3(-_wheel_spin, steer_angle, 0.0)
    var roll_t := steer_cur * clampf(vf / top_speed, 0.0, 1.0) * 0.07 - clampf(vl * 0.012, -0.1, 0.1)
    var pitch_t := clampf(_long_acc * 0.004, -0.08, 0.08)
    var k := clampf(delta * 8.0, 0.0, 1.0)
    _roll = lerpf(_roll, roll_t, k)
    _pitch = lerpf(_pitch, pitch_t, k)
    if _model != null:
        _model.rotation = Vector3(_pitch, 0.0, _roll)
    var smoke := drifting and absf(vl) > 2.0
    _smoke_l.emitting = smoke
    _smoke_r.emitting = smoke
    _flame.emitting = boosting
