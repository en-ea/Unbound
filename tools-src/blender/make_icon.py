"""The home-screen icon: a glowing sword cutting through a chain that breaks apart ("Unbound").
Renders the emblem on a transparent background; tools-src/make_icon_art.py lays it on the glow and sizes it.
Run: tools/blender/blender.exe --background --python tools-src/blender/make_icon.py -- <out.png>
"""
import math
import sys
import bpy
import bmesh
from mathutils import Vector as V, Matrix

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "icon_emblem.png"

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def mat(name, color, metal=0.0, rough=0.5, emit=None, strength=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Metallic"].default_value = metal
    p.inputs["Roughness"].default_value = rough
    if emit:
        p.inputs["Emission Color"].default_value = (*emit, 1)
        p.inputs["Emission Strength"].default_value = strength
    return m


STEEL = mat("steel", (0.85, 0.9, 1.0), 0.75, 0.18)
GOLD = mat("gold", (1.0, 0.68, 0.22), 1.0, 0.28)
LEATHER = mat("leather", (0.16, 0.07, 0.04), 0.0, 0.6)
RUNE = mat("rune", (0.2, 0.85, 1.0), 0.0, 0.3, (0.2, 0.8, 1.0), 12.0)
GEM = mat("gem", (0.9, 0.1, 0.12), 0.0, 0.1, (1.0, 0.15, 0.1), 4.0)
IRON = mat("iron", (0.62, 0.58, 0.55), 0.9, 0.3)
SPARK = mat("spark", (1, 0.8, 0.4), 0.0, 0.5, (1.0, 0.7, 0.3), 30.0)


def obj_from(bm, name, material, smooth=False):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    me.materials.append(material)
    if smooth:
        for poly in me.polygons:
            poly.use_smooth = True
    return ob


def blade():
    """A tapering blade with a diamond cross-section, along +Z from 0 to its tip."""
    bm = bmesh.new()
    length, width, thick = 2.35, 0.3, 0.075
    rings = []
    for k in range(9):
        t = k / 8
        z = t * length
        w = width * (1.0 - 0.18 * t) if t < 0.86 else width * 0.82 * (1 - (t - 0.86) / 0.14)
        th = thick * (1.0 - 0.4 * t)
        rings.append([bm.verts.new((x, y, z)) for x, y in ((-w / 2, 0), (0, -th), (w / 2, 0), (0, th))])
    for a, b in zip(rings, rings[1:]):
        for i in range(4):
            bm.faces.new((a[i], a[(i + 1) % 4], b[(i + 1) % 4], b[i]))
    bm.faces.new(list(reversed(rings[0])))
    return obj_from(bm, "Blade", STEEL)


def fuller():
    """The glowing rune line down the middle of the blade, both faces."""
    bm = bmesh.new()
    for side in (-1, 1):
        y = side * 0.071
        a = bm.verts.new((-0.035, y, 0.12)); b = bm.verts.new((0.035, y, 0.12))
        c = bm.verts.new((0.012, y * 0.75, 1.75)); d = bm.verts.new((-0.012, y * 0.75, 1.75))
        bm.faces.new((a, b, c, d))
    return obj_from(bm, "Fuller", RUNE)


def add(prim, name, material, **kw):
    getattr(bpy.ops.mesh, prim)(**kw)
    ob = bpy.context.active_object
    ob.name = name
    ob.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    return ob


def bevel(ob, width=0.03):
    mod = ob.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = 3


def link(name, at, rot, open_gap=0.0):
    """One oval chain link (a torus stretched long), optionally broken open."""
    bpy.ops.mesh.primitive_torus_add(major_radius=0.17, minor_radius=0.045, major_segments=40, minor_segments=12)
    ob = bpy.context.active_object
    ob.name = name
    if open_gap > 0.0:
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        gone = [v for v in bm.verts if abs(math.atan2(v.co.y, v.co.x)) < open_gap]
        bmesh.ops.delete(bm, geom=gone, context="VERTS")
        bm.to_mesh(ob.data)
        bm.free()
    ob.scale = (1.55, 1.0, 1.0)          # long along the chain (local X)
    ob.rotation_euler = rot
    ob.location = at
    ob.data.materials.append(IRON)
    bpy.ops.object.shade_smooth()
    return ob


# The sword: blade up, tilted, its parts parented so it turns as one.
sword = bpy.data.objects.new("Sword", None)
scene.collection.objects.link(sword)
parts = [blade(), fuller()]
guard = add("primitive_cube_add", "Guard", GOLD, size=1)
guard.scale = (0.78, 0.13, 0.11)
bevel(guard, 0.04)
for side in (-1, 1):                      # curled guard ends
    tip = add("primitive_uv_sphere_add", "GuardTip", GOLD, radius=0.09, location=(side * 0.42, 0, 0.03))
    parts.append(tip)
gem = add("primitive_ico_sphere_add", "Gem", GEM, radius=0.075, subdivisions=2, location=(0, -0.07, 0))
grip = add("primitive_cylinder_add", "Grip", LEATHER, radius=0.06, depth=0.55, location=(0, 0, -0.33))
for k in range(4):                        # wrapped bands
    band = add("primitive_torus_add", "Wrap", LEATHER, major_radius=0.062, minor_radius=0.014, location=(0, 0, -0.12 - k * 0.14))
    parts.append(band)
pommel = add("primitive_uv_sphere_add", "Pommel", GOLD, radius=0.11, location=(0, 0, -0.66))
pommel_gem = add("primitive_ico_sphere_add", "PommelGem", GEM, radius=0.05, subdivisions=2, location=(0, -0.09, -0.66))
parts += [guard, gem, grip, pommel, pommel_gem]
for p in parts:
    p.parent = sword
sword.location = (-0.05, 0, -0.85)
sword.rotation_euler = (0, math.radians(24), 0)    # tip to the upper right

# The chain: across the sword from upper left to lower right, broken where the blade cuts it, ends flying apart.
direction = V((1.0, 0, -0.75)).normalized()
centre = V((0.47, -0.3, 0.32))      # on the blade: the cut
spacing = 0.36
angle = math.atan2(direction.z, direction.x)
for side in (-1, 1):
    for k in range(4):
        d = 0.36 + k * spacing
        sag = V((0, 0, -0.035 * k * k)) if side < 0 else V((0, 0, 0.03 * k * k))   # the halves swing apart
        at = centre + direction * d * side + sag
        face_on = (k % 2 == 0)
        link(f"Link{side}_{k}", at, (math.radians(90) if face_on else 0.0, -angle, 0.0), open_gap=0.75 if k == 0 else 0.0)
for k in range(18):                       # sparks bursting from the break
    a = k * 2.399
    r = 0.12 + 0.55 * ((k * 37) % 18) / 18
    p = centre + V((math.cos(a) * r, -0.15, math.sin(a) * r * 0.8))
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.012 + 0.02 * ((k * 13) % 5) / 5, subdivisions=1, location=p)
    bpy.context.active_object.data.materials.append(SPARK)

# Lights: warm key from the top left, a cool rim from behind, a soft fill.
def light(name, kind, energy, color, loc, size=2.0):
    ld = bpy.data.lights.new(name, kind)
    ld.energy = energy
    ld.color = color
    if kind == "AREA":
        ld.size = size
    ob = bpy.data.objects.new(name, ld)
    ob.location = loc
    scene.collection.objects.link(ob)
    direction = V((0, 0, 0)) - V(loc)
    ob.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


light("Key", "AREA", 1500, (1.0, 0.86, 0.68), (-3, -4, 4), 3)
light("Rim", "AREA", 2600, (0.45, 0.7, 1.0), (3.5, 3, 2.5), 3)
light("Rim2", "AREA", 1600, (1.0, 0.5, 0.3), (-3.5, 3, -2), 3)
light("Fill", "AREA", 220, (0.8, 0.85, 1.0), (2, -5, -1), 5)

cam_data = bpy.data.cameras.new("Cam")
cam_data.lens = 50
cam = bpy.data.objects.new("Cam", cam_data)
cam.location = (0, -5.4, 0.0)
cam.rotation_euler = (math.radians(90), 0, 0)
scene.collection.objects.link(cam)
scene.camera = cam

world = bpy.data.worlds.new("World")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.08, 0.07, 0.14, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6
scene.world = world

for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
    try:
        scene.render.engine = engine
        break
    except TypeError:
        pass
scene.render.resolution_x = 1024
scene.render.resolution_y = 1024
scene.render.film_transparent = True
scene.view_settings.view_transform = "Filmic" if "Filmic" in [i.identifier for i in scene.view_settings.bl_rna.properties["view_transform"].enum_items] else "AgX"
scene.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("ICON written", OUT)
