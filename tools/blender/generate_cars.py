"""Generate low-poly DRIVE X car models as .glb.
Run:  blender -b -P tools/blender/generate_cars.py -- assets/models
Conventions: car front = +Y in Blender (becomes -Z in Godot), wheels are named
Wheel_FL/FR/RL/RR with origin at the wheel centre, ground at z=0.
Keep the table in sync with scripts/data/CarData.gd.
"""
import sys, os, math
import bpy

CARS = [  # id, hex colour, len, wid, hei, cabin, spoiler
    ("gt_rookie", "e63946", 4.3, 1.80, 0.50, 0.50, False),
    ("street_fox", "ff9f1c", 4.1, 1.80, 0.52, 0.52, True),
    ("apex_r", "2ec4b6", 4.4, 1.90, 0.46, 0.46, True),
    ("viper_s", "7b2cbf", 4.5, 1.95, 0.44, 0.44, True),
    ("phantom_x", "e8ecf4", 4.6, 2.00, 0.42, 0.42, True),
]
WHEEL_R, WHEEL_W, Y0 = 0.36, 0.28, 0.28


def hex_rgba(h):
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)) + (1.0,)


def material(name, rgba, metallic=0.0, rough=0.5):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = rgba
    b.inputs["Metallic"].default_value = metallic
    b.inputs["Roughness"].default_value = rough
    return m


def box(name, size, loc, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(mat)
    return o


def wheel(name, loc, tire, rim):
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=WHEEL_R, depth=WHEEL_W, location=loc,
                                        rotation=(0, math.radians(90), 0))
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(tire)
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=WHEEL_R * 0.62, depth=WHEEL_W + 0.03, location=loc,
                                        rotation=(0, math.radians(90), 0))
    r = bpy.context.active_object
    r.name = name + "_rim"
    r.data.materials.append(rim)
    r.parent = o
    r.matrix_parent_inverse = o.matrix_world.inverted()
    return o


def build(car):
    cid, col, L, W, H, CH, spoiler = car
    paint = material("Paint", hex_rgba(col), 0.6, 0.25)
    dark = material("Dark", (0.04, 0.04, 0.05, 1), 0.3, 0.5)
    glass = material("Glass", (0.05, 0.09, 0.14, 1), 0.9, 0.08)
    tire = material("Tire", (0.03, 0.03, 0.03, 1), 0.0, 0.9)
    rim = material("Rim", (0.75, 0.78, 0.85, 1), 0.9, 0.25)
    parts = []
    parts.append(box("Body", (W, L, H), (0, 0, Y0 + H / 2), paint))
    cl = L * 0.42
    parts.append(box("Cabin", (W * 0.84, cl, CH), (0, -L * 0.07, Y0 + H + CH / 2 - 0.02), glass))
    parts.append(box("Roof", (W * 0.8, cl * 0.82, 0.05), (0, -L * 0.08, Y0 + H + CH), paint))
    parts.append(box("Splitter", (W * 1.02, 0.35, 0.08), (0, L / 2 - 0.1, Y0 + 0.02), dark))
    if spoiler:
        parts.append(box("Wing", (W * 0.98, 0.42, 0.05), (0, -L / 2 + 0.22, Y0 + H + 0.28), paint))
    wx, wy = W / 2 - WHEEL_W / 2 + 0.03, L * 0.31
    for n, (sx, sy) in {"FL": (-1, 1), "FR": (1, 1), "RL": (-1, -1), "RR": (1, -1)}.items():
        parts.append(wheel("Wheel_" + n, (sx * wx, sy * wy, WHEEL_R), tire, rim))
    return parts


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = argv[0] if argv else "assets/models"
    os.makedirs(out, exist_ok=True)
    for car in CARS:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        parts = build(car)
        bpy.ops.object.select_all(action="DESELECT")
        for o in bpy.data.objects:
            o.select_set(True)
        path = os.path.join(out, car[0] + ".glb")
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True)
        print("exported", path)


main()
