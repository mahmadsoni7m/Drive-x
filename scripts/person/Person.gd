class_name Person
extends CharacterBody3D
## A human: the player on foot, a wandering pedestrian, or a street fighter.
## Combat: punch / kick (reach ~1.9 m), blocking, knock-back, KO. Fully procedural animation.

signal died(person: Person)
signal hurt(person: Person, amount: float)

enum Role { PLAYER, NPC, FIGHTER }

const RUN := 4.6
const REACH := 1.9

var role: int = Role.NPC
var team := 2                       # 0 player, 1 fighters, 2 neutral
var health := 100.0
var max_health := 100.0
var app: Dictionary = {}
var parts: Dictionary = {}
var people: Array = []              # shared list of every Person (assigned by Game)
var target: Person = null           # fighter's current victim
var home := Vector3.ZERO
var move_dir := Vector3.ZERO        # player input (world space, length 0..1)
var blocking := false
var ko := false
var yaw := 0.0

var _body: Node3D
var _phase := 0.0
var _atk_t := 0.0
var _atk_dur := 0.4
var _atk_kind := "punch"
var _atk_hit := true
var _cool := 0.0
var _wander_t := 0.0
var _wander_to := Vector3.ZERO
var _stuck_t := 0.0
var _flee_t := 0.0
var _flee_from := Vector3.ZERO
var _ko_t := 0.0
var _flash := 0.0
var _kb := Vector3.ZERO


func setup(appearance: Dictionary, r: int, hp: float) -> void:
    app = appearance
    role = r
    max_health = hp
    health = hp
    team = 0 if r == Role.PLAYER else (1 if r == Role.FIGHTER else 2)
    motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
    collision_layer = 2
    collision_mask = 1
    var built := HumanBuilder.build(appearance)
    _body = built["root"]
    parts = built["parts"]
    add_child(_body)
    var cs := CollisionShape3D.new()
    var cap := CapsuleShape3D.new()
    cap.radius = 0.3
    cap.height = 1.7
    cs.shape = cap
    cs.position.y = 0.85
    add_child(cs)


func revive(pos: Vector3) -> void:
    ko = false
    _ko_t = 0.0
    health = max_health
    _body.rotation = Vector3.ZERO
    _body.position = Vector3.ZERO
    global_position = pos
    velocity = Vector3.ZERO


# --- combat ------------------------------------------------------------------------
func attack(kind: String) -> bool:
    if ko or _atk_t > 0.0 or _cool > 0.0:
        return false
    _atk_kind = kind
    _atk_dur = 0.36 if kind == "punch" else 0.5
    _atk_t = _atk_dur
    _atk_hit = false
    _cool = _atk_dur + 0.08
    return true


func _sfx(sound: String, pitch: float) -> void:
    var am := get_node_or_null("/root/AudioManager")
    if am != null:
        am.play(sound, pitch)


func _forward() -> Vector3:
    return Vector3(-sin(yaw), 0.0, -cos(yaw))


func _can_hit(p: Person) -> bool:
    return team != p.team and (team == 0 or p.team == 0)


func _apply_hit() -> void:
    var dmg := 8.0 if _atk_kind == "punch" else 14.0
    var fwd := _forward()
    var landed := false
    for o in people:
        var p := o as Person
        if p == null or not is_instance_valid(p) or p == self or p.ko or not p.visible or not _can_hit(p):
            continue
        var to := p.global_position - global_position
        to.y = 0.0
        var d := to.length()
        if d <= REACH and (d < 0.5 or fwd.dot(to / d) > 0.35):
            p.take_hit(dmg, fwd, self)
            landed = true
    if not landed:
        _sfx("punch", 1.3)


func take_hit(dmg: float, dir: Vector3, from: Person) -> void:
    if ko:
        return
    var amount := dmg
    if blocking and _forward().dot(-dir) > 0.3:
        amount *= 0.25
    health -= amount
    _flash = 1.0
    _kb = dir * (3.6 if dmg > 10.0 else 2.2)
    hurt.emit(self, amount)
    _sfx("hit", 1.0)
    if role == Role.NPC:
        _flee_t = 6.0
        if from != null:
            _flee_from = from.global_position
    if role == Role.FIGHTER and from != null and from.role == Role.PLAYER:
        target = from
    if health <= 0.0:
        ko = true
        _ko_t = 0.0
        velocity = Vector3.ZERO
        died.emit(self)


# --- AI ----------------------------------------------------------------------------
func _wander(delta: float, mag: float, radius: float) -> Vector3:
    _wander_t -= delta
    var to := _wander_to - global_position
    to.y = 0.0
    if _wander_t <= 0.0 or _stuck_t > 1.2:
        _wander_t = randf_range(3.0, 8.0)
        _stuck_t = 0.0
        if randf() < 0.3:
            _wander_to = global_position
        else:
            _wander_to = home + Vector3(randf_range(-radius, radius), 0.0, randf_range(-radius, radius))
        return Vector3.ZERO
    if to.length() < 0.8:
        return Vector3.ZERO
    if Vector2(velocity.x, velocity.z).length() < 0.25:
        _stuck_t += delta
    else:
        _stuck_t = 0.0
    return to.normalized() * mag


func _npc_ai(delta: float) -> Vector3:
    if _flee_t > 0.0:
        _flee_t -= delta
        var away := global_position - _flee_from
        away.y = 0.0
        return away.normalized()
    return _wander(delta, 0.38, 22.0)


func _fighter_ai(delta: float) -> Vector3:
    if target == null or not is_instance_valid(target) or target.ko or not target.visible:
        return _wander(delta, 0.3, 5.0)
    var to := target.global_position - global_position
    to.y = 0.0
    var d := to.length()
    if d > 30.0:
        return _wander(delta, 0.3, 5.0)
    if d > 1.5:
        return to.normalized()
    yaw = lerp_angle(yaw, atan2(-to.x, -to.z), clampf(delta * 12.0, 0.0, 1.0))
    if _cool <= 0.0 and _atk_t <= 0.0:
        attack("punch" if randf() < 0.65 else "kick")
        _cool += randf_range(0.5, 1.2)
    return Vector3.ZERO


# --- simulation --------------------------------------------------------------------
func _physics_process(delta: float) -> void:
    if ko:
        _update_ko(delta)
        return
    _cool = maxf(0.0, _cool - delta)
    var desired := Vector3.ZERO
    match role:
        Role.PLAYER:
            desired = move_dir
        Role.FIGHTER:
            desired = _fighter_ai(delta)
        _:
            desired = _npc_ai(delta)
    var mag := minf(desired.length(), 1.0)
    var speed := RUN * mag
    if blocking:
        speed *= 0.4
    if _atk_t > 0.0:
        speed *= 0.3
        _atk_t -= delta
        if not _atk_hit and _atk_t <= _atk_dur * 0.55:
            _atk_hit = true
            _apply_hit()
    if mag > 0.05:
        var want := desired.normalized() * speed
        if _atk_t <= 0.0 and not (role == Role.FIGHTER and target != null and (target.global_position - global_position).length() < 3.0):
            yaw = lerp_angle(yaw, atan2(-desired.x, -desired.z), clampf(delta * 12.0, 0.0, 1.0))
        velocity = velocity.lerp(want + _kb, clampf(delta * 10.0, 0.0, 1.0))
    else:
        velocity = velocity.lerp(_kb, clampf(delta * 10.0, 0.0, 1.0))
    _kb = _kb.move_toward(Vector3.ZERO, delta * 12.0)
    velocity.y = 0.0
    move_and_slide()
    global_position.y = 0.0
    rotation.y = yaw
    _animate(delta)


func _animate(delta: float) -> void:
    var spd := Vector2(velocity.x, velocity.z).length()
    _phase += delta * (4.0 + spd * 2.0)
    var amp := clampf(spd / 3.0, 0.0, 1.0) * 0.9
    var sw := sin(_phase) * amp
    var ll: Node3D = parts["leg_l"]
    var lr: Node3D = parts["leg_r"]
    var al: Node3D = parts["arm_l"]
    var ar: Node3D = parts["arm_r"]
    ll.rotation.x = sw
    lr.rotation.x = -sw
    al.rotation.x = -sw * 0.8
    ar.rotation.x = sw * 0.8
    if _atk_t > 0.0:
        var p := 1.0 - _atk_t / _atk_dur
        var k := sin(p * PI)
        if _atk_kind == "punch":
            ar.rotation.x = PI * 0.5 * k
        else:
            lr.rotation.x = PI * 0.55 * k
    elif blocking:
        al.rotation.x = 1.9
        ar.rotation.x = 1.9
    _flash = maxf(0.0, _flash - delta * 4.0)
    _body.rotation.x = -0.25 * _flash
    _body.position.y = absf(sin(_phase)) * 0.03 * amp


func _update_ko(delta: float) -> void:
    _ko_t += delta
    var k := clampf(_ko_t / 0.35, 0.0, 1.0)
    _body.rotation.x = lerpf(0.0, -PI * 0.5, k)
    _body.position.y = lerpf(0.0, 0.2, k)
    if role != Role.PLAYER and _ko_t > 6.0:
        queue_free()
