"""The home-screen icon: the three lands as small floating islands round a glowing heart, light streaming
between them (the game's story: three lands, one bond). The meadow (green, a round house, trees, a waterfall),
the second land (sand, old stone ruins) and the third (violet, glowing crystals), low-poly like the game.
(The earlier sword-and-chain emblem is make_icon_sword.py.)
Renders on a transparent background; tools-src/make_icon_art.py lays it on the night sky and sizes it.
Run: tools/blender/blender.exe --background --python tools-src/blender/make_icon.py -- <out.png>
"""
import math
import random
import sys
import bpy
import bmesh
from mathutils import Vector as V

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "icon_emblem.png"
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
rng = random.Random(7)


def mat(name, color, rough=0.8, emit=None, strength=0.0, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    if emit:
        p.inputs["Emission Color"].default_value = (*emit, 1)
        p.inputs["Emission Strength"].default_value = strength
    return m


M = {
    "grass": mat("grass", (0.18, 0.62, 0.12)),
    "sand": mat("sand", (0.92, 0.62, 0.28)),
    "violet": mat("violet", (0.4, 0.18, 0.75)),
    "dirt": mat("dirt", (0.36, 0.22, 0.12)),
    "rock": mat("rock", (0.3, 0.27, 0.3)),
    "rock_warm": mat("rock_warm", (0.48, 0.33, 0.22)),
    "rock_cool": mat("rock_cool", (0.2, 0.16, 0.3)),
    "leaf": mat("leaf", (0.14, 0.45, 0.14)),
    "leaf2": mat("leaf2", (0.3, 0.55, 0.12)),
    "trunk": mat("trunk", (0.3, 0.17, 0.08)),
    "wall": mat("wall", (0.95, 0.88, 0.72)),
    "roof": mat("roof", (0.75, 0.2, 0.12)),
    "stone": mat("stone", (0.8, 0.7, 0.52)),
    "crystal": mat("crystal", (0.62, 0.3, 1.0), 0.2, (0.55, 0.2, 1.0), 2.2),
    "water": mat("water", (0.35, 0.7, 1.0), 0.1, (0.3, 0.65, 1.0), 0.7),
    "heart": mat("heart", (1, 1, 1), 0.2, (0.6, 0.9, 1.0), 8.0),
}


def flat_obj(bm, name):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    return ob


def island(name, at, r, top, side, under):
    """A floating island: a grassy (or sandy, violet) top, a band of earth, and a jagged rock root below."""
    bm = bmesh.new()
    n = 11
    centre = bm.verts.new((0, 0, 0.06 * r))
    rim = []
    band = []
    for k in range(n):
        a = math.tau * k / n
        rr = r * rng.uniform(0.88, 1.08)
        rim.append(bm.verts.new((math.cos(a) * rr, math.sin(a) * rr, rng.uniform(-0.02, 0.03) * r)))
        band.append(bm.verts.new((math.cos(a) * rr * 0.96, math.sin(a) * rr * 0.96, -0.2 * r)))
    under_ring = []
    for k in range(n):
        a = math.tau * (k + 0.5) / n
        rr = r * rng.uniform(0.55, 0.75)
        under_ring.append(bm.verts.new((math.cos(a) * rr, math.sin(a) * rr, -r * rng.uniform(0.45, 0.6))))
    tip = bm.verts.new((rng.uniform(-0.1, 0.1) * r, rng.uniform(-0.1, 0.1) * r, -1.35 * r))
    faces = []
    for k in range(n):
        j = (k + 1) % n
        faces.append((bm.faces.new((centre, rim[k], rim[j])), 0))
        faces.append((bm.faces.new((rim[k], band[k], band[j], rim[j])), 1))
        faces.append((bm.faces.new((band[k], under_ring[k], band[j])), 2))
        faces.append((bm.faces.new((band[j], under_ring[k], under_ring[j])), 2))
        faces.append((bm.faces.new((under_ring[k], tip, under_ring[j])), 2))
    for f, i in faces:
        f.material_index = i
    bmesh.ops.recalc_face_normals(bm, faces=[f for f, _ in faces])
    ob = flat_obj(bm, name)
    for m in (top, side, under):
        ob.data.materials.append(m)
    ob.location = at
    return ob


def prim(kind, material, loc, **kw):
    getattr(bpy.ops.mesh, kind)(location=loc, **kw)
    ob = bpy.context.active_object
    ob.data.materials.append(material)
    return ob


def tree(at, h, leaf):
    prim("primitive_cylinder_add", M["trunk"], at + V((0, 0, h * 0.2)), vertices=6, radius=h * 0.07, depth=h * 0.4)
    prim("primitive_cone_add", leaf, at + V((0, 0, h * 0.62)), vertices=7, radius1=h * 0.3, radius2=0, depth=h * 0.75)
    prim("primitive_cone_add", leaf, at + V((0, 0, h * 0.95)), vertices=7, radius1=h * 0.22, radius2=0, depth=h * 0.55)


def house(at, s, turn):
    prim("primitive_cylinder_add", M["wall"], at + V((0, 0, s * 0.3)), vertices=8, radius=s * 0.45, depth=s * 0.6)
    prim("primitive_cone_add", M["roof"], at + V((0, 0, s * 0.85)), vertices=8, radius1=s * 0.6, radius2=0, depth=s * 0.6)
    door = prim("primitive_cube_add", M["trunk"], at + V((math.cos(turn) * s * 0.44, math.sin(turn) * s * 0.44, s * 0.18)), size=1)
    door.scale = (s * 0.06, s * 0.16, s * 0.34)
    door.rotation_euler = (0, 0, turn)


def pillar(at, h, r):
    prim("primitive_cylinder_add", M["stone"], at + V((0, 0, h / 2)), vertices=6, radius=r, depth=h)


def crystal(at, h, r, lean):
    ob = prim("primitive_cylinder_add", M["crystal"], at + V((0, 0, h * 0.4)), vertices=6, radius=r, depth=h * 0.8)
    cap = prim("primitive_cone_add", M["crystal"], at + V((0, 0, h * 0.9)), vertices=6, radius1=r, radius2=0, depth=h * 0.25)
    for o in (ob, cap):
        o.rotation_euler = lean


def stream(a, b, color, lift):
    """A ribbon of light from a to b, bowed upwards."""
    curve = bpy.data.curves.new("stream", "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = 0.018
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(1)
    mid = (a + b) / 2 + V((0, 0, lift))
    p0, p1 = spline.bezier_points[0], spline.bezier_points[1]
    p0.co, p1.co = a, b
    p0.handle_left_type = p0.handle_right_type = p1.handle_left_type = p1.handle_right_type = "FREE"
    p0.handle_left, p0.handle_right = a, a + (mid - a) * 0.8
    p1.handle_left, p1.handle_right = b + (mid - b) * 0.8, b
    ob = bpy.data.objects.new("stream", curve)
    scene.collection.objects.link(ob)
    ob.data.materials.append(mat("stream", color, 0.3, color, 3.5))


# The world faces the camera along -Y; islands in a triangle round the heart at the origin.
heart = V((0, 0, 0.05))
meadow_at, sand_at, violet_at = V((-1.08, -0.2, -0.55)), V((1.1, 0.15, -0.5)), V((0.0, 0.35, 0.95))
island("Meadow", meadow_at, 0.78, M["grass"], M["dirt"], M["rock"])
island("Sands", sand_at, 0.72, M["sand"], M["rock_warm"], M["rock_warm"])
island("Third", violet_at, 0.68, M["violet"], M["rock_cool"], M["rock_cool"])

# Meadow: a round house, trees, a waterfall over the edge.
house(meadow_at + V((-0.08, 0.05, 0.03)), 0.42, -math.pi / 2)
tree(meadow_at + V((0.35, 0.25, 0.02)), 0.5, M["leaf"])
tree(meadow_at + V((-0.42, 0.3, 0.02)), 0.38, M["leaf2"])
tree(meadow_at + V((0.42, -0.2, 0.02)), 0.32, M["leaf2"])
fall = prim("primitive_cube_add", M["water"], meadow_at + V((-0.5, -0.45, -0.28)), size=1)
fall.scale = (0.1, 0.02, 0.55)

# The second land: sand and old stone ruins, a lone tree.
for x, y, h in ((-0.28, 0.0, 0.5), (0.0, 0.18, 0.42), (0.26, -0.05, 0.22)):
    pillar(sand_at + V((x, y, 0.02)), h, 0.06)
lintel = prim("primitive_cube_add", M["stone"], sand_at + V((-0.14, 0.09, 0.52)), size=1)
lintel.scale = (0.42, 0.1, 0.07)
lintel.rotation_euler = (0, 0, 0.55)
tree(sand_at + V((0.35, 0.25, 0.02)), 0.36, M["leaf2"])

# The third land: crystals, glowing.
crystal(violet_at + V((0.0, 0.05, 0.02)), 0.75, 0.09, (0, 0, 0))
crystal(violet_at + V((-0.22, -0.05, 0.02)), 0.45, 0.065, (0.0, -0.3, 0))
crystal(violet_at + V((0.22, -0.02, 0.02)), 0.5, 0.07, (0.0, 0.32, 0))
crystal(violet_at + V((0.1, 0.25, 0.02)), 0.32, 0.05, (0.2, 0.2, 0))

# The heart, and light streaming from it to each land.
prim("primitive_ico_sphere_add", M["heart"], heart, radius=0.16, subdivisions=3)
stream(heart, meadow_at + V((0.15, 0, 0.1)), (0.5, 1.0, 0.45), 0.15)
stream(heart, sand_at + V((-0.15, 0, 0.1)), (1.0, 0.75, 0.35), 0.15)
stream(heart, violet_at + V((0, 0, -0.1)), (0.75, 0.45, 1.0), 0.0)
for k in range(26):                         # motes of light about the heart
    a, r = rng.uniform(0, math.tau), rng.uniform(0.25, 1.5)
    prim("primitive_ico_sphere_add", M["heart"], heart + V((math.cos(a) * r, -0.3, math.sin(a) * r * 0.9)),
         radius=rng.uniform(0.008, 0.02), subdivisions=1)

for ob in scene.objects:                    # flat faces, like the game
    if ob.type == "MESH":
        for poly in ob.data.polygons:
            poly.use_smooth = False


def light(name, kind, energy, color, loc, size=2.0):
    ld = bpy.data.lights.new(name, kind)
    ld.energy = energy
    ld.color = color
    if kind == "AREA":
        ld.size = size
    ob = bpy.data.objects.new(name, ld)
    ob.location = loc
    scene.collection.objects.link(ob)
    ob.rotation_euler = (V((0, 0, 0)) - V(loc)).to_track_quat("-Z", "Y").to_euler()


light("Key", "AREA", 700, (1.0, 0.9, 0.75), (-3, -4, 5), 4)
light("Rim", "AREA", 900, (0.55, 0.6, 1.0), (2, 4, 3), 4)
light("Heart", "POINT", 120, (0.7, 0.9, 1.0), (0, -0.3, 0.05))
light("Fill", "AREA", 150, (0.8, 0.8, 1.0), (0, -5, -2), 5)

cam_data = bpy.data.cameras.new("Cam")
cam_data.lens = 50
cam = bpy.data.objects.new("Cam", cam_data)
pitch = math.radians(14)
cam.location = (0, -6.0 * math.cos(pitch), 6.0 * math.sin(pitch) + 0.05)
cam.rotation_euler = (math.radians(90) - pitch, 0, 0)
scene.collection.objects.link(cam)
scene.camera = cam

world = bpy.data.worlds.new("World")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.1, 0.09, 0.2, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8
scene.world = world
for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
    try:
        scene.render.engine = engine
        break
    except TypeError:
        pass
scene.render.resolution_x = scene.render.resolution_y = 1024
scene.render.film_transparent = True
scene.view_settings.view_transform = "AgX"
try:
    scene.view_settings.look = "AgX - Punchy"
except TypeError:
    pass
scene.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("ICON written", OUT)
