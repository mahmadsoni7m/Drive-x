class_name TrackBuilder
extends RefCounted
## Procedurally builds a race track (road, curbs, collidable barriers, start gantry,
## scenery, pickups) from TrackData, plus the matching sky/sun environment.

## Returns {"info": TrackInfo, "root": Node3D, "pickups": Array[{pos, type}]} or {} on failure.
static func build(track_index: int, quality: int) -> Dictionary:
    var td := TrackData.get_track(track_index)
    var pts := TrackData.sample(track_index)
    if pts.size() < 16:
        push_error("TrackBuilder: track %d produced too few points" % track_index)
        return {}
    var info := TrackInfo.new()
    info.setup(pts, float(td["width"]))
    var root := Node3D.new()
    root.name = "Track"
    root.add_child(_ground(td))
    root.add_child(_road(info))
    root.add_child(_curbs(info))
    root.add_child(_walls(info, td))
    root.add_child(_start_line(info, bool(td["night"])))
    _scenery(root, info, td, quality)
    return {"info": info, "root": root, "pickups": _pickups(info)}


# --- helpers ---------------------------------------------------------------------
static func _vtx(st: SurfaceTool, p: Vector3, uv: Vector2, col: Color, nrm: Vector3) -> void:
    st.set_color(col)
    st.set_normal(nrm)
    st.set_uv(uv)
    st.add_vertex(p)


static func _quad_uv(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
        ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, col: Color, nrm: Vector3) -> void:
    _vtx(st, a, ua, col, nrm)
    _vtx(st, b, ub, col, nrm)
    _vtx(st, c, uc, col, nrm)
    _vtx(st, a, ua, col, nrm)
    _vtx(st, c, uc, col, nrm)
    _vtx(st, d, ud, col, nrm)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, nrm: Vector3) -> void:
    _quad_uv(st, a, b, c, d, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, col, nrm)


static func _mat(color: Color = Color.WHITE, rough: float = 0.85) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = rough
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    return m


static func _vc_mat(unshaded: bool) -> StandardMaterial3D:
    var m := _mat(Color.WHITE, 0.7)
    m.vertex_color_use_as_albedo = true
    if unshaded:
        m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    return m


static func _mesh_node(mesh: Mesh, mat: Material) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = mat
    return mi


# --- ground & road -----------------------------------------------------------------
static func _ground(td: Dictionary) -> MeshInstance3D:
    var pm := PlaneMesh.new()
    pm.size = Vector2(3000.0, 3000.0)
    var mi := _mesh_node(pm, _mat(Color.html(str(td["ground"])), 1.0))
    mi.position.y = -0.03
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return mi


static func _road_texture() -> ImageTexture:
    var w := 64
    var h := 128
    var img := Image.create(w, h, true, Image.FORMAT_RGB8)
    var rng := RandomNumberGenerator.new()
    rng.seed = 1337
    for y in h:
        for x in w:
            var g := 0.15 + rng.randf() * 0.05
            var c := Color(g, g, g * 1.05)
            var u := float(x) / float(w)
            if u < 0.04 or u > 0.96:
                c = Color(0.9, 0.9, 0.9)
            elif absf(u - 0.5) < 0.012 and y < 64:
                c = Color(0.95, 0.8, 0.15)
            img.set_pixel(x, y, c)
    img.generate_mipmaps()
    return ImageTexture.create_from_image(img)


static func _road(info: TrackInfo) -> MeshInstance3D:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var n := info.count()
    var hw := info.width * 0.5
    var lift := Vector3(0.0, 0.01, 0.0)
    var v := 0.0
    for i in n:
        var p0 := info.point(i)
        var p1 := info.point(i + 1)
        var r0 := info.right(i)
        var r1 := info.right(i + 1)
        var seg := p0.distance_to(p1)
        var v0 := v / 16.0
        var v1 := (v + seg) / 16.0
        _quad_uv(st, p0 - r0 * hw + lift, p0 + r0 * hw + lift, p1 + r1 * hw + lift, p1 - r1 * hw + lift,
            Vector2(0, v0), Vector2(1, v0), Vector2(1, v1), Vector2(0, v1), Color.WHITE, Vector3.UP)
        v += seg
    var m := _mat(Color.WHITE, 0.9)
    m.albedo_texture = _road_texture()
    m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    var mi := _mesh_node(st.commit(), m)
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return mi


static func _curbs(info: TrackInfo) -> MeshInstance3D:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var n := info.count()
    var hw := info.width * 0.5
    var lift := Vector3(0.0, 0.02, 0.0)
    for side: float in [-1.0, 1.0]:
        for i in n:
            var col := Color(0.85, 0.1, 0.1) if i % 2 == 0 else Color(0.95, 0.95, 0.95)
            var r0 := info.right(i) * side
            var r1 := info.right(i + 1) * side
            var p0 := info.point(i)
            var p1 := info.point(i + 1)
            _quad(st, p0 + r0 * hw + lift, p0 + r0 * (hw + 1.1) + lift, p1 + r1 * (hw + 1.1) + lift, p1 + r1 * hw + lift, col, Vector3.UP)
    var mi := _mesh_node(st.commit(), _vc_mat(false))
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return mi


static func _walls(info: TrackInfo, td: Dictionary) -> StaticBody3D:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var n := info.count()
    var d0 := info.width * 0.5 + 1.8
    var d1 := d0 + 0.5
    var h := Vector3(0.0, 1.1, 0.0)
    var ca := Color.html(str(td["barrier_a"]))
    var cb := Color.html(str(td["barrier_b"]))
    for side: float in [-1.0, 1.0]:
        for i in n:
            var col := ca if (i % 6) < 3 else cb
            var p0 := info.point(i)
            var p1 := info.point(i + 1)
            var r0 := info.right(i) * side
            var r1 := info.right(i + 1) * side
            var ib0 := p0 + r0 * d0
            var ib1 := p1 + r1 * d0
            var ob0 := p0 + r0 * d1
            var ob1 := p1 + r1 * d1
            _quad(st, ib0, ib1, ib1 + h, ib0 + h, col, -r0)
            _quad(st, ib0 + h, ib1 + h, ob1 + h, ob0 + h, col, Vector3.UP)
            _quad(st, ob0, ob1, ob1 + h, ob0 + h, col, r0)
    var mesh := st.commit()
    var body := StaticBody3D.new()
    body.name = "Walls"
    var mi := _mesh_node(mesh, _vc_mat(bool(td["night"])))
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    body.add_child(mi)
    var shape: ConcavePolygonShape3D = mesh.create_trimesh_shape()
    shape.backface_collision = true
    var cs := CollisionShape3D.new()
    cs.shape = shape
    body.add_child(cs)
    return body


static func _start_line(info: TrackInfo, night: bool) -> Node3D:
    var root := Node3D.new()
    root.name = "StartLine"
    root.transform = Transform3D(Basis.looking_at(info.tangent(0), Vector3.UP), info.point(0))
    var hw := info.width * 0.5
    # checker strip
    var img := Image.create(16, 4, false, Image.FORMAT_RGB8)
    for y in 4:
        for x in 16:
            var on := ((x / 2) + (y / 2)) % 2 == 0
            img.set_pixel(x, y, Color.WHITE if on else Color.BLACK)
    var tex := ImageTexture.create_from_image(img)
    var qm := QuadMesh.new()
    qm.size = Vector2(info.width, 3.0)
    qm.orientation = PlaneMesh.FACE_Y
    var m := _mat(Color.WHITE, 0.8)
    m.albedo_texture = tex
    m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    var strip := _mesh_node(qm, m)
    strip.position.y = 0.03
    strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    root.add_child(strip)
    # gantry
    var accent := Color(1.0, 0.42, 0.1)
    var gm := _mat(accent, 0.5)
    if night:
        gm.emission_enabled = true
        gm.emission = accent
    for sx: float in [-1.0, 1.0]:
        var post := BoxMesh.new()
        post.size = Vector3(0.7, 7.0, 0.7)
        var pn := _mesh_node(post, gm)
        pn.position = Vector3(sx * (hw + 2.4), 3.5, 0.0)
        root.add_child(pn)
    var beam := BoxMesh.new()
    beam.size = Vector3(info.width + 5.5, 1.3, 0.8)
    var bn := _mesh_node(beam, gm)
    bn.position = Vector3(0.0, 7.0, 0.0)
    root.add_child(bn)
    var lbl := Label3D.new()
    lbl.text = "DRIVE X"
    lbl.font_size = 96
    lbl.pixel_size = 0.012
    lbl.modulate = Color.WHITE
    lbl.outline_size = 12
    lbl.position = Vector3(0.0, 7.0, 0.45)
    root.add_child(lbl)
    return root


# --- scenery -----------------------------------------------------------------------
static func _multi(root: Node3D, mesh: Mesh, mat: Material, xforms: Array[Transform3D]) -> void:
    if xforms.is_empty():
        return
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = mesh
    mm.instance_count = xforms.size()
    for i in xforms.size():
        mm.set_instance_transform(i, xforms[i])
    var mmi := MultiMeshInstance3D.new()
    mmi.multimesh = mm
    mmi.material_override = mat
    mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    root.add_child(mmi)


static func _scenery(root: Node3D, info: TrackInfo, td: Dictionary, quality: int) -> void:
    var kind := str(td["scenery"])
    var counts := [90, 200, 340]
    var want: int = counts[clampi(quality, 0, 2)]
    var rng := RandomNumberGenerator.new()
    rng.seed = int(td["seed"])
    var minp := Vector2(INF, INF)
    var maxp := Vector2(-INF, -INF)
    var coarse: Array[Vector3] = []
    for i in info.count():
        var p := info.points[i]
        minp = Vector2(minf(minp.x, p.x), minf(minp.y, p.z))
        maxp = Vector2(maxf(maxp.x, p.x), maxf(maxp.y, p.z))
        if i % 3 == 0:
            coarse.append(p)
    var keep_out := info.width * 0.5 + 12.0
    var a: Array[Transform3D] = []
    var b: Array[Transform3D] = []
    var tries := 0
    var placed := 0
    while placed < want and tries < want * 8:
        tries += 1
        var pos := Vector3(rng.randf_range(minp.x - 120.0, maxp.x + 120.0), 0.0, rng.randf_range(minp.y - 120.0, maxp.y + 120.0))
        var ok := true
        for c in coarse:
            var dx := c.x - pos.x
            var dz := c.z - pos.z
            if dx * dx + dz * dz < keep_out * keep_out:
                ok = false
                break
        if not ok:
            continue
        var s := rng.randf_range(0.8, 1.8)
        var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s))
        placed += 1
        match kind:
            "pine":
                a.append(Transform3D(basis, pos + Vector3(0.0, 4.2 * s, 0.0)))
                b.append(Transform3D(basis, pos + Vector3(0.0, 1.0 * s, 0.0)))
            "rock":
                a.append(Transform3D(basis.scaled(Vector3(1.4, 0.8, 1.2)), pos + Vector3(0.0, 0.8 * s, 0.0)))
            _:
                var pylon_xf := Transform3D(basis.scaled(Vector3(0.6, 1.0, 0.6)), pos + Vector3(0.0, 6.0 * s, 0.0))
                if placed % 2 == 0:
                    a.append(pylon_xf)
                else:
                    b.append(pylon_xf)
    match kind:
        "pine":
            var cone := CylinderMesh.new()
            cone.top_radius = 0.0
            cone.bottom_radius = 2.2
            cone.height = 6.0
            cone.radial_segments = 7
            cone.rings = 1
            var trunk := CylinderMesh.new()
            trunk.top_radius = 0.3
            trunk.bottom_radius = 0.4
            trunk.height = 2.0
            trunk.radial_segments = 5
            trunk.rings = 1
            _multi(root, cone, _mat(Color(0.1, 0.35, 0.15)), a)
            _multi(root, trunk, _mat(Color(0.3, 0.2, 0.1)), b)
        "rock":
            var rock := SphereMesh.new()
            rock.radius = 2.0
            rock.height = 3.2
            rock.radial_segments = 7
            rock.rings = 4
            _multi(root, rock, _mat(Color(0.55, 0.38, 0.22), 1.0), a)
        _:
            var pylon := BoxMesh.new()
            pylon.size = Vector3(0.8, 12.0, 0.8)
            var cy := StandardMaterial3D.new()
            cy.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
            cy.albedo_color = Color(0.1, 0.83, 1.0)
            var mg := StandardMaterial3D.new()
            mg.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
            mg.albedo_color = Color(1.0, 0.17, 0.84)
            _multi(root, pylon, cy, a)
            _multi(root, pylon, mg, b)


# --- pickups -----------------------------------------------------------------------
static func _pickups(info: TrackInfo) -> Array:
    var out: Array = []
    var n := info.count()
    var i := 10
    var k := 0
    while i < n - 6:
        var off := sin(float(k) * 0.9) * (info.width * 0.5 - 3.0)
        out.append({"pos": info.point(i) + info.right(i) * off, "type": "coin"})
        i += 10
        k += 1
    for q in [0.25, 0.5, 0.75]:
        var idx := int(float(n) * float(q))
        out.append({"pos": info.point(idx) + info.right(idx) * 2.0, "type": "nitro"})
    return out


# --- environment -------------------------------------------------------------------
static func make_environment(td: Dictionary, quality: int) -> Node3D:
    var root := Node3D.new()
    root.name = "Environment"
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var psm := ProceduralSkyMaterial.new()
    psm.sky_top_color = Color.html(str(td["sky_top"]))
    psm.sky_horizon_color = Color.html(str(td["sky_horizon"]))
    psm.ground_horizon_color = Color.html(str(td["sky_horizon"]))
    psm.ground_bottom_color = Color.html(str(td["ground"]))
    sky.sky_material = psm
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_energy = float(td["ambient"])
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.fog_enabled = true
    env.fog_light_color = Color.html(str(td["fog"]))
    env.fog_density = 0.0012
    var we := WorldEnvironment.new()
    we.environment = env
    root.add_child(we)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = td["sun_rot"]
    sun.light_energy = float(td["sun_energy"])
    sun.light_color = Color.html(str(td["sun_color"]))
    sun.shadow_enabled = quality >= 1
    if quality >= 2:
        sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
    else:
        sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
    sun.directional_shadow_max_distance = 90.0
    root.add_child(sun)
    return root
