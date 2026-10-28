class_name Showroom
extends SubViewportContainer
## 3D turntable behind the menus (own World3D, so it never touches the race scene).

var _vp: SubViewport
var _cam: Camera3D
var _pivot: Node3D
var _model: Node3D


func _ready() -> void:
    UIKit.full(self)
    stretch = true
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _vp = SubViewport.new()
    _vp.own_world_3d = true
    _vp.msaa_3d = Viewport.MSAA_2X
    _vp.handle_input_locally = false
    add_child(_vp)
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.03, 0.04, 0.09)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.5, 0.55, 0.7)
    env.ambient_light_energy = 0.8
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    _cam = Camera3D.new()
    _cam.environment = env
    _cam.fov = 40.0
    _vp.add_child(_cam)
    _cam.look_at_from_position(Vector3(0.0, 1.7, 6.6), Vector3(0.0, 0.6, 0.0))
    var key := DirectionalLight3D.new()
    key.rotation_degrees = Vector3(-35.0, 40.0, 0.0)
    key.light_energy = 1.4
    _vp.add_child(key)
    var fill := DirectionalLight3D.new()
    fill.rotation_degrees = Vector3(-20.0, -140.0, 0.0)
    fill.light_energy = 0.6
    _vp.add_child(fill)
    var plat := MeshInstance3D.new()
    var cyl := CylinderMesh.new()
    cyl.top_radius = 3.4
    cyl.bottom_radius = 3.4
    cyl.height = 0.1
    cyl.radial_segments = 36
    var pm := StandardMaterial3D.new()
    pm.albedo_color = Color(0.08, 0.1, 0.16)
    pm.metallic = 0.7
    pm.roughness = 0.35
    plat.mesh = cyl
    plat.material_override = pm
    plat.position.y = -0.05
    _vp.add_child(plat)
    var ring := MeshInstance3D.new()
    var tm := TorusMesh.new()
    tm.inner_radius = 3.3
    tm.outer_radius = 3.5
    tm.rings = 36
    tm.ring_segments = 6
    var rm := StandardMaterial3D.new()
    rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    rm.albedo_color = UIKit.CYAN
    ring.mesh = tm
    ring.material_override = rm
    ring.position.y = 0.02
    _vp.add_child(ring)
    _pivot = Node3D.new()
    _vp.add_child(_pivot)


func _process(delta: float) -> void:
    if _pivot != null:
        _pivot.rotate_y(delta * 0.5)


## Shift the car sideways on screen (garage puts the car to the right of the stats panel).
func set_shift(x: float) -> void:
    _cam.h_offset = x


func _clear() -> void:
    if _model != null:
        _model.queue_free()
        _model = null


func _frame(close: bool) -> void:
    if close:
        _cam.look_at_from_position(Vector3(0.0, 1.3, 3.6), Vector3(0.0, 0.95, 0.0))
    else:
        _cam.look_at_from_position(Vector3(0.0, 1.7, 6.6), Vector3(0.0, 0.6, 0.0))


func show_car(car: Dictionary) -> void:
    _clear()
    _frame(false)
    var built := CarBuilder.build(car)
    _model = built["root"]
    _pivot.add_child(_model)


## Shows a character; app = HumanBuilder.resolve(...) or resolve_character(...).
func show_person(app: Dictionary) -> void:
    _clear()
    _frame(true)
    var built := HumanBuilder.build(app)
    _model = built["root"]
    _pivot.add_child(_model)
