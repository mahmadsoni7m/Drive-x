class_name WorldBuilder
extends RefCounted
## Builds the open world from WorldData/RoadNet: ground, 3 road types, city buildings
## (with colliders), map-edge walls, trees/rocks, distant mountains, sky + sun.

static func _mat(color: Color, rough: float = 0.9) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = rough
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    return m


static func build(net: RoadNet, quality: int) -> Node3D:
    var root := Node3D.new()
    root.name = "World"
    var ground := MeshInstance3D.new()
    var pm := PlaneMesh.new()
    pm.size = Vector2(7000.0, 7000.0)
    ground.mesh = pm
    var gm := _mat(Color.WHITE, 1.0)
    gm.albedo_texture = _grass_tex()
    gm.uv1_triplanar = true
    gm.uv1_world_triplanar = true
    gm.uv1_scale = Vector3(0.05, 0.05, 0.05)
    gm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    gm.normal_enabled = true
    gm.normal_texture = _normal_tex(128, 0.06, 6.0, 5)
    gm.normal_scale = 0.9
    ground.material_override = gm
    ground.position.y = -0.03
    ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    root.add_child(ground)
    _roads(root, net)
    _sidewalks_and_lamps(root)
    _buildings(root)
    _walls(root)
    _scenery(root, net, quality)
    _mountains(root)
    if quality >= 1:
        _clouds(root)
    return root


static func _normal_tex(size: int, freq: float, strength: float, seed_v: int) -> ImageTexture:
    var noise := FastNoiseLite.new()
    noise.seed = seed_v
    noise.frequency = freq
    var img := noise.get_image(size, size, false, false, true)
    img.bump_map_to_normal_map(strength)
    img.generate_mipmaps()
    return ImageTexture.create_from_image(img)


static func _cloud_texture() -> ImageTexture:
    var noise := FastNoiseLite.new()
    noise.seed = 77
    noise.frequency = 0.018
    noise.fractal_octaves = 4
    var src := noise.get_image(128, 128, false, false, true)
    var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
    for y in 128:
        for x in 128:
            var v := src.get_pixel(x, y).r
            var edge := minf(minf(float(x), 127.0 - float(x)), minf(float(y), 127.0 - float(y))) / 28.0
            var a := clampf((v - 0.52) * 3.0, 0.0, 1.0) * clampf(edge, 0.0, 1.0)
            img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a * 0.9))
    return ImageTexture.create_from_image(img)


static func _clouds(root: Node3D) -> void:
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.albedo_texture = _cloud_texture()
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.disable_fog = true
    var rng := RandomNumberGenerator.new()
    rng.seed = 123
    for i in 22:
        var q := QuadMesh.new()
        q.size = Vector2(rng.randf_range(500.0, 900.0), rng.randf_range(300.0, 600.0))
        q.orientation = PlaneMesh.FACE_Y
        var mi := MeshInstance3D.new()
        mi.mesh = q
        mi.material_override = mat
        var a := rng.randf() * TAU
        var d := rng.randf_range(100.0, 1700.0)
        mi.position = Vector3(cos(a) * d, rng.randf_range(420.0, 560.0), sin(a) * d)
        mi.rotation.y = rng.randf() * TAU
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        root.add_child(mi)


static func _grass_tex() -> ImageTexture:
    var img := Image.create(64, 64, true, Image.FORMAT_RGB8)
    var rng := RandomNumberGenerator.new()
    rng.seed = 21
    for y in 64:
        for x in 64:
            var n := rng.randf()
            img.set_pixel(x, y, Color(0.22 + n * 0.08, 0.36 + n * 0.1, 0.16 + n * 0.05))
    img.generate_mipmaps()
    return ImageTexture.create_from_image(img)


static func _window_tex() -> ImageTexture:
    var img := Image.create(64, 64, true, Image.FORMAT_RGB8)
    var rng := RandomNumberGenerator.new()
    rng.seed = 31
    for gy in 4:
        for gx in 4:
            var lit := rng.randf() < 0.25
            for y in 16:
                for x in 16:
                    var c := Color(0.92, 0.92, 0.92)
                    if x >= 4 and x < 12 and y >= 4 and y < 11:
                        c = Color(0.95, 0.85, 0.5) if lit else Color(0.22, 0.3, 0.4)
                    img.set_pixel(gx * 16 + x, gy * 16 + y, c)
    img.generate_mipmaps()
    return ImageTexture.create_from_image(img)


static func _sidewalks_and_lamps(root: Node3D) -> void:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var pole_list: Array[Transform3D] = []
    var head_list: Array[Transform3D] = []
    var streets: Array = WorldData.STREETS
    for s: float in streets:
        for axis in 2:
            for i in streets.size() - 1:
                var z0: float = float(streets[i]) + 5.0
                var z1: float = float(streets[i + 1]) - 5.0
                for side: float in [-1.0, 1.0]:
                    var a0 := s + side * 5.0
                    var a1 := s + side * 9.5
                    var p00: Vector3
                    var p01: Vector3
                    var p10: Vector3
                    var p11: Vector3
                    if axis == 0:
                        p00 = Vector3(a0, 0.1, z0)
                        p01 = Vector3(a0, 0.1, z1)
                        p10 = Vector3(a1, 0.1, z0)
                        p11 = Vector3(a1, 0.1, z1)
                    else:
                        p00 = Vector3(z0, 0.1, a0)
                        p01 = Vector3(z1, 0.1, a0)
                        p10 = Vector3(z0, 0.1, a1)
                        p11 = Vector3(z1, 0.1, a1)
                    for v: Vector3 in [p00, p01, p11, p00, p11, p10]:
                        st.set_normal(Vector3.UP)
                        st.add_vertex(v)
                var step := 45.0
                var t := z0 + 10.0
                var flip := 1.0
                while t < z1 - 6.0:
                    var lx := s + flip * 8.8
                    var pos := Vector3(lx, 0.0, t) if axis == 0 else Vector3(t, 0.0, lx)
                    pole_list.append(Transform3D(Basis.IDENTITY, pos + Vector3(0.0, 3.0, 0.0)))
                    head_list.append(Transform3D(Basis.IDENTITY, pos + Vector3(-flip * 0.5 if axis == 0 else 0.0, 6.1, 0.0 if axis == 0 else -flip * 0.5)))
                    t += step
                    flip = -flip
    var mi := MeshInstance3D.new()
    mi.mesh = st.commit()
    mi.material_override = _mat(Color(0.62, 0.62, 0.64), 0.95)
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    mi.name = "Sidewalks"
    root.add_child(mi)
    var pole := BoxMesh.new()
    pole.size = Vector3(0.2, 6.0, 0.2)
    var head := BoxMesh.new()
    head.size = Vector3(0.9, 0.2, 0.5)
    var glow := StandardMaterial3D.new()
    glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    glow.albedo_color = Color(1.0, 0.92, 0.6)
    _multi(root, pole, _mat(Color(0.25, 0.27, 0.3)), pole_list)
    _multi(root, head, glow, head_list)


# --- roads -----------------------------------------------------------------------------
static func _road_tex(kind: int) -> ImageTexture:
    var w := 64
    var h := 128
    var img := Image.create(w, h, true, Image.FORMAT_RGB8)
    var rng := RandomNumberGenerator.new()
    rng.seed = 100 + kind
    for y in h:
        for x in w:
            var u := float(x) / float(w)
            var c := Color.BLACK
            if kind == WorldData.K_DIRT:
                var g := 0.36 + rng.randf() * 0.08
                c = Color(g, g * 0.78, g * 0.55)
                if absf(u - 0.3) < 0.05 or absf(u - 0.7) < 0.05:
                    c = c.darkened(0.15)
            else:
                var g := 0.24 + rng.randf() * 0.05
                c = Color(g, g, g * 1.04)
                if kind == WorldData.K_HIGHWAY:
                    if u < 0.04 or u > 0.96:
                        c = Color(0.92, 0.92, 0.92)
                    elif absf(u - 0.5) < 0.012 and y < 64:
                        c = Color(0.95, 0.95, 0.95)
                else:
                    if u < 0.02 or u > 0.98:
                        c = Color(0.55, 0.55, 0.55)
                    elif absf(u - 0.5) < 0.01 and y < 80:
                        c = Color(0.9, 0.75, 0.15)
            img.set_pixel(x, y, c)
    img.generate_mipmaps()
    return ImageTexture.create_from_image(img)


static func _roads(root: Node3D, net: RoadNet) -> void:
    var tools: Dictionary = {}
    for k in [WorldData.K_HIGHWAY, WorldData.K_CITY, WorldData.K_DIRT]:
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        tools[k] = st
    var lift := {WorldData.K_HIGHWAY: 0.015, WorldData.K_CITY: 0.01, WorldData.K_DIRT: 0.005}
    for road: Dictionary in net.polylines:
        var kind := int(road["kind"])
        var st: SurfaceTool = tools[kind]
        var pts: PackedVector3Array = road["pts"]
        var closed := bool(road["closed"])
        var hw := float(road["width"]) * 0.5
        var n := pts.size()
        var rights := PackedVector3Array()
        rights.resize(n)
        for i in n:
            var prev := pts[(i - 1 + n) % n] if closed else pts[maxi(i - 1, 0)]
            var nxt := pts[(i + 1) % n] if closed else pts[mini(i + 1, n - 1)]
            var t := (nxt - prev)
            t.y = 0.0
            rights[i] = t.normalized().cross(Vector3.UP)
        var up := Vector3(0.0, float(lift[kind]), 0.0)
        var v := 0.0
        var segs := n if closed else n - 1
        for i in segs:
            var j := (i + 1) % n
            var seg := pts[i].distance_to(pts[j])
            var v0 := v / 16.0
            var v1 := (v + seg) / 16.0
            var a := pts[i] - rights[i] * hw + up
            var b := pts[i] + rights[i] * hw + up
            var c := pts[j] + rights[j] * hw + up
            var d := pts[j] - rights[j] * hw + up
            _tri(st, a, Vector2(0, v0), b, Vector2(1, v0), c, Vector2(1, v1))
            _tri(st, a, Vector2(0, v0), c, Vector2(1, v1), d, Vector2(0, v1))
            v += seg
    for k in tools:
        var mi := MeshInstance3D.new()
        (tools[k] as SurfaceTool).generate_tangents()
        mi.mesh = (tools[k] as SurfaceTool).commit()
        var m := _mat(Color.WHITE, 0.9)
        m.albedo_texture = _road_tex(int(k))
        m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
        m.normal_enabled = true
        m.normal_texture = _normal_tex(64, 0.09 if int(k) != WorldData.K_DIRT else 0.05, 5.0 if int(k) != WorldData.K_DIRT else 9.0, 40 + int(k))
        m.normal_scale = 0.8
        m.roughness = 0.75 if int(k) != WorldData.K_DIRT else 1.0
        mi.material_override = m
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        mi.name = "Roads_%d" % int(k)
        root.add_child(mi)


static func _tri(st: SurfaceTool, a: Vector3, ua: Vector2, b: Vector3, ub: Vector2, c: Vector3, uc: Vector2) -> void:
    for pair in [[a, ua], [b, ub], [c, uc]]:
        st.set_normal(Vector3.UP)
        st.set_uv(pair[1])
        st.add_vertex(pair[0])


# --- buildings -------------------------------------------------------------------------
static func _buildings(root: Node3D) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 77
    var palette: Array = [Color("c9b79c"), Color("a8b5c4"), Color("d4a373"), Color("9aa5a0"), Color("c7c7c7"), Color("b88b7a")]
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.use_colors = true
    var bm := BoxMesh.new()
    bm.size = Vector3.ONE
    mm.mesh = bm
    var list: Array = []
    var centers := [-225.0, -75.0, 75.0, 225.0]
    for bx: float in centers:
        for bz: float in centers:
            for ox: float in [-30.0, 30.0]:
                for oz: float in [-30.0, 30.0]:
                    var size := Vector3(rng.randf_range(38.0, 50.0), rng.randf_range(12.0, 55.0), rng.randf_range(38.0, 50.0))
                    list.append({"pos": Vector3(bx + ox, size.y * 0.5, bz + oz), "size": size, "col": palette[rng.randi() % palette.size()]})
    mm.instance_count = list.size()
    var bodies := Node3D.new()
    bodies.name = "BuildingColliders"
    for i in list.size():
        var d: Dictionary = list[i]
        var size: Vector3 = d["size"]
        mm.set_instance_transform(i, Transform3D(Basis.from_scale(size), d["pos"]))
        mm.set_instance_color(i, d["col"])
        var sb := StaticBody3D.new()
        sb.position = d["pos"]
        var cs := CollisionShape3D.new()
        var bs := BoxShape3D.new()
        bs.size = size
        cs.shape = bs
        sb.add_child(cs)
        bodies.add_child(sb)
    var mmi := MultiMeshInstance3D.new()
    mmi.multimesh = mm
    var m := StandardMaterial3D.new()
    m.vertex_color_use_as_albedo = true
    m.roughness = 0.8
    m.albedo_texture = _window_tex()
    m.uv1_triplanar = true
    m.uv1_world_triplanar = true
    m.uv1_scale = Vector3(0.0625, 0.0625, 0.0625)
    m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    m.normal_enabled = true
    m.normal_texture = _normal_tex(64, 0.12, 3.0, 8)
    m.normal_scale = 0.5
    m.uv1_scale = Vector3(0.0625, 0.0625, 0.0625)
    mmi.material_override = m
    mmi.name = "Buildings"
    root.add_child(mmi)
    root.add_child(bodies)


static func _walls(root: Node3D) -> void:
    var h := WorldData.HALF
    var defs := [
        [Vector3(h + 6.0, 5.0, 0.0), Vector3(10.0, 10.0, h * 2.0 + 24.0)],
        [Vector3(-h - 6.0, 5.0, 0.0), Vector3(10.0, 10.0, h * 2.0 + 24.0)],
        [Vector3(0.0, 5.0, h + 6.0), Vector3(h * 2.0 + 24.0, 10.0, 10.0)],
        [Vector3(0.0, 5.0, -h - 6.0), Vector3(h * 2.0 + 24.0, 10.0, 10.0)],
    ]
    for d in defs:
        var sb := StaticBody3D.new()
        sb.position = d[0]
        var cs := CollisionShape3D.new()
        var bs := BoxShape3D.new()
        bs.size = d[1]
        cs.shape = bs
        sb.add_child(cs)
        root.add_child(sb)


# --- scenery ---------------------------------------------------------------------------
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


static func _scenery(root: Node3D, net: RoadNet, quality: int) -> void:
    var counts := [120, 260, 420]
    var want: int = counts[clampi(quality, 0, 2)]
    var rng := RandomNumberGenerator.new()
    rng.seed = 5
    var cones: Array[Transform3D] = []
    var trunks: Array[Transform3D] = []
    var rocks: Array[Transform3D] = []
    var tries := 0
    var lim := WorldData.HALF - 20.0
    while cones.size() + rocks.size() < want and tries < want * 10:
        tries += 1
        var pos := Vector3(rng.randf_range(-lim, lim), 0.0, rng.randf_range(-lim, lim))
        if absf(pos.x) < 335.0 and absf(pos.z) < 335.0:
            continue
        if net.near_road(pos, 18.0):
            continue
        var s := rng.randf_range(0.8, 1.9)
        var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s))
        if rng.randf() < 0.75:
            cones.append(Transform3D(basis, pos + Vector3(0.0, 4.2 * s, 0.0)))
            trunks.append(Transform3D(basis, pos + Vector3(0.0, 1.0 * s, 0.0)))
        else:
            rocks.append(Transform3D(basis.scaled(Vector3(1.4, 0.8, 1.2)), pos + Vector3(0.0, 0.6 * s, 0.0)))
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
    var rock := SphereMesh.new()
    rock.radius = 2.0
    rock.height = 3.2
    rock.radial_segments = 7
    rock.rings = 4
    _multi(root, cone, _mat(Color(0.1, 0.35, 0.15)), cones)
    _multi(root, trunk, _mat(Color(0.3, 0.2, 0.1)), trunks)
    _multi(root, rock, _mat(Color(0.5, 0.45, 0.4), 1.0), rocks)


static func _mountains(root: Node3D) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 9
    var base: Array[Transform3D] = []
    var caps: Array[Transform3D] = []
    for i in 40:
        var a := TAU * float(i) / 40.0 + rng.randf_range(-0.05, 0.05)
        var dist := rng.randf_range(1450.0, 1750.0)
        var r := rng.randf_range(160.0, 280.0)
        var h := rng.randf_range(220.0, 420.0)
        var pos := Vector3(cos(a) * dist, 0.0, sin(a) * dist)
        base.append(Transform3D(Basis.from_scale(Vector3(r, h, r)), pos + Vector3(0.0, h * 0.5, 0.0)))
        caps.append(Transform3D(Basis.from_scale(Vector3(r * 0.4, h * 0.4, r * 0.4)), pos + Vector3(0.0, h * 0.8, 0.0)))
    var cone := CylinderMesh.new()
    cone.top_radius = 0.0
    cone.bottom_radius = 1.0
    cone.height = 1.0
    cone.radial_segments = 8
    cone.rings = 1
    _multi(root, cone, _mat(Color(0.42, 0.38, 0.35), 1.0), base)
    _multi(root, cone, _mat(Color(0.95, 0.97, 1.0), 0.8), caps)


# --- sky / sun ---------------------------------------------------------------------------
static func make_environment(quality: int) -> Node3D:
    var root := Node3D.new()
    root.name = "Environment"
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var psm := ProceduralSkyMaterial.new()
    psm.sky_top_color = Color(0.3, 0.5, 0.86)
    psm.sky_horizon_color = Color(0.78, 0.87, 0.95)
    psm.ground_horizon_color = Color(0.78, 0.87, 0.95)
    psm.ground_bottom_color = Color(0.34, 0.47, 0.26)
    sky.sky_material = psm
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_energy = 0.55
    env.tonemap_exposure = 0.9
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.fog_enabled = true
    env.fog_light_color = Color(0.8, 0.88, 0.95)
    env.fog_density = 0.0005
    env.adjustment_enabled = true
    env.adjustment_saturation = 1.12
    env.adjustment_contrast = 1.06
    if quality >= 2:
        env.glow_enabled = true
        env.glow_intensity = 0.5
        env.glow_bloom = 0.08
        env.glow_hdr_threshold = 1.1
    var we := WorldEnvironment.new()
    we.environment = env
    root.add_child(we)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-50.0, -40.0, 0.0)
    sun.light_energy = 0.95
    sun.light_color = Color(1.0, 0.96, 0.88)
    sun.shadow_enabled = quality >= 1
    if quality >= 2:
        sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
    else:
        sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
    sun.directional_shadow_max_distance = 110.0
    sun.shadow_normal_bias = 1.2
    sun.shadow_blur = 1.2
    root.add_child(sun)
    return root


# --- minimap texture ---------------------------------------------------------------------
const MAP_PX := 512


static func minimap_texture(net: RoadNet) -> ImageTexture:
    var img := Image.create(MAP_PX, MAP_PX, false, Image.FORMAT_RGBA8)
    img.fill(Color(0.16, 0.24, 0.14, 1.0))
    var sc := float(MAP_PX) / (WorldData.HALF * 2.0)
    var colors := {WorldData.K_HIGHWAY: Color(0.9, 0.9, 0.95), WorldData.K_CITY: Color(0.7, 0.7, 0.75), WorldData.K_DIRT: Color(0.65, 0.5, 0.32)}
    for road: Dictionary in net.polylines:
        var col: Color = colors[int(road["kind"])]
        var rad := maxi(1, roundi(float(road["width"]) * 0.5 * sc))
        for p: Vector3 in (road["pts"] as PackedVector3Array):
            var cx := roundi((p.x + WorldData.HALF) * sc)
            var cy := roundi((p.z + WorldData.HALF) * sc)
            for dx in range(-rad, rad + 1):
                for dy in range(-rad, rad + 1):
                    var x := cx + dx
                    var y := cy + dy
                    if x >= 0 and y >= 0 and x < MAP_PX and y < MAP_PX:
                        img.set_pixel(x, y, col)
    return ImageTexture.create_from_image(img)
