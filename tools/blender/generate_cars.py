"""DRIVE X detailed procedural sedan generator for Blender 4.x.

Run from the repository root:
  blender -b -P tools/blender/generate_cars.py -- assets/models

Front of each car is +Y in Blender; Godot imports it facing -Z.
Exports <car_id>.glb with Wheel_FL/FR/RL/RR nodes for Vehicle.gd animation.
This creates detailed stylized game-ready models, not photogrammetry/photoreal assets.
"""
import bpy, sys, os, math
from mathutils import Vector, Matrix

CARS = [
    ("gt_rookie", "e63946", 4.3, 1.80, 0.50, 0.50, False),
    ("street_fox", "ff9f1c", 4.1, 1.80, 0.52, 0.52, True),
    ("apex_r", "2ec4b6", 4.4, 1.90, 0.46, 0.46, True),
    ("viper_s", "7b2cbf", 4.5, 1.95, 0.44, 0.44, True),
    ("phantom_x", "10151c", 4.6, 2.00, 0.42, 0.42, True),
]
R = 0.36
WW = 0.28
GROUND = R


def rgba(hex_color):
    h = hex_color.lstrip('#')
    return tuple(int(h[i:i+2], 16) / 255.0 for i in (0, 2, 4)) + (1.0,)


def mat(name, color, metallic=0.0, roughness=0.4, emission=None):
    m = bpy.data.materials.new(name)
    m.diffuse_color = color
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = color
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Roughness'].default_value = roughness
    if emission:
        bsdf.inputs['Emission Color'].default_value = emission
        bsdf.inputs['Emission Strength'].default_value = 2.0
    return m


def finish(obj, material, bevel=0.0, smooth=False):
    if material:
        obj.data.materials.append(material)
    if bevel > 0 and obj.type == 'MESH':
        mod = obj.modifiers.new('Soft manufactured edges', 'BEVEL')
        mod.width = bevel
        mod.segments = 3
        obj.modifiers.new('Weighted corner normals', 'WEIGHTED_NORMAL')
    if smooth and obj.type == 'MESH':
        for p in obj.data.polygons:
            p.use_smooth = True
    return obj


def cube(name, loc, size, material, bevel=0.04, parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.name = name
    o.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    finish(o, material, min(bevel, min(size) * 0.42) if bevel else 0)
    if parent:
        o.parent = parent
        o.matrix_parent_inverse = Matrix.Identity(4)
    return o


def cylinder(name, loc, radius, depth, material, vertices=32, axis='X', parent=None):
    rot = (0, math.radians(90), 0) if axis == 'X' else (0, 0, 0)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth,
                                        location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    finish(o, material, 0.008, True)
    if parent:
        o.parent = parent
        o.matrix_parent_inverse = Matrix.Identity(4)
    return o


def sphere(name, loc, scale, material, parent=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=10, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    finish(o, material, 0, True)
    if parent:
        o.parent = parent
        o.matrix_parent_inverse = Matrix.Identity(4)
    return o


def wheel(name, loc, mats):
    # Empty origin at axle centre is what the Godot wheel animation expects.
    bpy.ops.object.empty_add(type='PLAIN_AXES', location=loc)
    root = bpy.context.object
    root.name = name
    tire, rubber_dark, alloy, metal, brake, gold = mats
    cylinder(name+'_Tire', (0, 0, 0), R, WW, tire, 40, 'X', root)
    for side in (-1, 1):
        x = side * (WW * 0.5 + 0.012)
        cylinder(name+'_RimBarrel', (x, 0, 0), R*0.70, 0.025, rubber_dark, 32, 'X', root)
        cylinder(name+'_AlloyFace', (x+side*0.015, 0, 0), R*0.60, 0.035, alloy, 32, 'X', root)
        cylinder(name+'_BrakeDisc', (x+side*0.026, 0, 0), R*0.43, 0.025, brake, 32, 'X', root)
        cylinder(name+'_Hub', (x+side*0.045, 0, 0), R*0.16, 0.035, metal, 20, 'X', root)
        # Five raised spokes around each wheel face.
        for i in range(5):
            a = math.tau*i/5.0
            spoke = cube(name+'_Spoke', (x+side*0.044, math.sin(a)*R*0.30, math.cos(a)*R*0.30),
                         (0.025, R*0.095, R*0.52), alloy, 0.012, root)
            spoke.rotation_euler.x = -a
        for i in range(8):
            a = math.tau*i/8.0
            cylinder(name+'_DiscHole', (x+side*0.042, math.sin(a)*R*0.31, math.cos(a)*R*0.31),
                     0.018, 0.008, rubber_dark, 8, 'X', root)
        # Gold caliper visible behind alloy spokes.
        cube(name+'_Caliper', (x-side*0.01, R*0.20, R*0.12), (0.07, 0.15, 0.23), gold, 0.025, root)
    return root


def build(car):
    cid, color_hex, L, W, H, CH, spoiler = car
    paint = mat('Paint_'+cid, rgba(color_hex), 0.78, 0.22)
    paint_dark = mat('PaintDark_'+cid, tuple(v*0.55 for v in rgba(color_hex)[:3])+(1,), 0.65, 0.28)
    black = mat('GlossBlack', (0.012,0.016,0.021,1), 0.25, 0.25)
    rubber = mat('TireRubber', (0.018,0.02,0.023,1), 0.0, 0.82)
    alloy = mat('MachinedAlloy', (0.52,0.59,0.67,1), 0.92, 0.2)
    chrome = mat('Chrome', (0.72,0.78,0.82,1), 0.94, 0.16)
    glass = mat('TintedGlass', (0.018,0.045,0.062,1), 0.62, 0.12)
    head = mat('LED_White', (0.75,0.88,1,1), 0.15, 0.18, (0.65,0.82,1,1))
    tail = mat('LED_Red', (0.75,0.008,0.018,1), 0.15, 0.2, (1,0.005,0.012,1))
    brake = mat('BrakeRotor', (0.24,0.26,0.28,1), 0.72, 0.32)
    gold = mat('BrakeCaliper', (0.95,0.42,0.035,1), 0.45, 0.28)
    mats = (rubber, black, alloy, chrome, brake, gold)
    y0 = R
    wx = W*0.5 - WW*0.35 + 0.02
    wy = L*0.31

    # Main lower body and separate hood / trunk panels.
    cube('Body_Main', (0, 0, y0+H*0.52), (W, L*0.78, H*0.90), paint, 0.14)
    cube('Front_Bonnet', (0, L*0.27, y0+H*0.77), (W*0.91, L*0.27, H*0.24), paint, 0.075)
    cube('Rear_Deck', (0, -L*0.31, y0+H*0.75), (W*0.92, L*0.22, H*0.24), paint, 0.065)
    cube('Front_Bumper', (0, L*0.465, y0+0.08), (W*1.02, 0.18, 0.18), paint_dark, 0.055)
    cube('Rear_Bumper', (0, -L*0.465, y0+0.08), (W*1.02, 0.18, 0.18), paint_dark, 0.055)
    cube('Front_Splitter', (0, L*0.485, y0+0.025), (W*1.04, 0.24, 0.045), black, 0.012)
    cube('Rear_Diffuser', (0, -L*0.485, y0+0.03), (W*0.78, 0.18, 0.065), black, 0.012)

    # Sculpted cabin: roof, windshield and side glass are separate materials.
    cabin_center = -L*0.035
    cabin_len = L*0.42
    cabin_bottom = y0 + H*0.91
    cabin_top = cabin_bottom + CH*0.86
    cube('Cabin_Glass_Core', (0, cabin_center, cabin_bottom+CH*0.45), (W*0.76, cabin_len*0.88, CH*0.70), glass, 0.085)
    cube('Roof', (0, cabin_center-L*0.005, cabin_top), (W*0.69, cabin_len*0.70, 0.075), paint, 0.04)
    # windshield and rear glass tilted for a fastback silhouette
    wind = cube('Windshield', (0, L*0.12, cabin_bottom+CH*0.53), (W*0.70, 0.055, CH*0.68), glass, 0.018)
    wind.rotation_euler.x = math.radians(24)
    rearwin = cube('Rear_Window', (0, -L*0.20, cabin_bottom+CH*0.50), (W*0.68, 0.055, CH*0.58), glass, 0.018)
    rearwin.rotation_euler.x = math.radians(-25)
    for side in (-1, 1):
        x = side*W*0.386
        # side window pair and slim pillars
        cube('Side_Window_Front', (x, L*0.045, cabin_bottom+CH*0.48), (0.035, cabin_len*0.37, CH*0.47), glass, 0.012)
        cube('Side_Window_Rear', (x, -L*0.105, cabin_bottom+CH*0.48), (0.035, cabin_len*0.30, CH*0.43), glass, 0.012)
        cube('A_Pillar', (side*W*0.34, L*0.12, cabin_bottom+CH*0.42), (0.075, 0.10, CH*0.78), paint, 0.02)
        cube('C_Pillar', (side*W*0.34, -L*0.20, cabin_bottom+CH*0.42), (0.085, 0.11, CH*0.75), paint, 0.02)
        cube('Side_Skirt', (side*W*0.48, 0, y0+0.045), (0.07, L*0.56, 0.10), black, 0.02)
        cube('Door_Handle', (side*W*0.502, -L*0.015, y0+H*0.61), (0.025, 0.15, 0.035), chrome, 0.01)
        cube('Mirror_Stem', (side*W*0.48, L*0.115, cabin_bottom+CH*0.24), (0.10, 0.08, 0.045), black, 0.015)
        cube('Side_Mirror', (side*W*0.53, L*0.115, cabin_bottom+CH*0.28), (0.16, 0.13, 0.085), paint, 0.035)
        # Front air vents / bumper corner accents.
        cube('Front_Intake', (side*W*0.34, L*0.482, y0+H*0.30), (W*0.20, 0.025, H*0.24), black, 0.02)
        cube('Headlight_Housing', (side*W*0.32, L*0.482, y0+H*0.70), (W*0.23, 0.035, 0.105), black, 0.03)
        cube('Headlight_LED', (side*W*0.32, L*0.505, y0+H*0.71), (W*0.19, 0.018, 0.045), head, 0.018)
        cube('Tail_Lamp_Housing', (side*W*0.33, -L*0.482, y0+H*0.69), (W*0.25, 0.035, 0.09), black, 0.02)
        cube('Tail_Lamp_LED', (side*W*0.33, -L*0.505, y0+H*0.70), (W*0.21, 0.018, 0.035), tail, 0.012)
        # Exhaust tips point backward and sit under the rear bumper.
        cylinder('Exhaust_Tip', (side*W*0.31, -L*0.49, y0+0.075), 0.055, 0.10, chrome, 20, 'Y')

    # Front grille with vertical slats, badge and lower horizontal grille.
    cube('Grille_Bezel', (0, L*0.493, y0+H*0.43), (W*0.34, 0.035, H*0.40), chrome, 0.025)
    cube('Grille_Black', (0, L*0.516, y0+H*0.43), (W*0.31, 0.018, H*0.36), black, 0.012)
    for i in range(7):
        x = (i-3)*W*0.039
        cube('Grille_Slat', (x, L*0.529, y0+H*0.43), (0.018, 0.012, H*0.31), chrome, 0.006)
    cube('Lower_Grille', (0, L*0.496, y0+H*0.20), (W*0.39, 0.02, 0.055), black, 0.012)
    sphere('Front_Badge', (0, L*0.532, y0+H*0.57), (0.055, 0.018, 0.055), chrome)
    # Plate areas and trunk line.
    cube('Front_Plate', (0, L*0.515, y0+H*0.23), (0.42, 0.025, 0.09), black, 0.012)
    cube('Rear_Plate', (0, -L*0.515, y0+H*0.24), (0.42, 0.025, 0.09), black, 0.012)
    cube('Trunk_Line', (0, -L*0.30, y0+H*0.89), (W*0.76, 0.018, 0.018), paint_dark, 0.006)

    # Subtle hood creases and roof rails/antenna.
    for side in (-1, 1):
        cube('Hood_Crease', (side*W*0.27, L*0.29, y0+H*0.90), (0.018, L*0.22, 0.012), paint_dark, 0.004)
    cube('Roof_Antenna', (0, -L*0.19, cabin_top+0.045), (0.018, 0.12, 0.025), black, 0.008)
    if spoiler:
        for side in (-1, 1):
            cube('Spoiler_Stand', (side*W*0.31, -L*0.42, y0+H+0.16), (0.045, 0.055, 0.18), black, 0.012)
        cube('Rear_Spoiler', (0, -L*0.43, y0+H+0.26), (W*0.88, 0.20, 0.055), paint, 0.025)

    # Four detailed wheel assemblies; root empties are kept named for Godot.
    for name, sx, sy in [('Wheel_FL',-1,1),('Wheel_FR',1,1),('Wheel_RL',-1,-1),('Wheel_RR',1,-1)]:
        wheel(name, (sx*wx, sy*wy, R), mats)


def main():
    argv = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    out = argv[0] if argv else 'assets/models'
    os.makedirs(out, exist_ok=True)
    for car in CARS:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        build(car)
        bpy.ops.object.select_all(action='DESELECT')
        for obj in bpy.data.objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = bpy.data.objects[0] if bpy.data.objects else None
        path = os.path.join(out, car[0]+'.glb')
        bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True,
                                  export_apply=True, export_materials='EXPORT')
        print('EXPORTED:', path)

if __name__ == '__main__':
    main()
    
