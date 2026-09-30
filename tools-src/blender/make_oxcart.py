"""Builds the Dray Ox and its cart (the transport: you ride the bench, the ox pulls, the bed carries bodies).

ox.glb: a big shaggy dark ox with pale curled horns, a cream muzzle, a red blanket and a wooden yoke. Parts
(Body, Head, Leg_FL/FR/BL/BR, Tail) with their pivots, animated in code (the boar's trot, ox_cart.gd).
cart.glb: Cart (bed, rails, bench, shafts) and Wheel_L / Wheel_R (pivots on the axle, so they spin).
Both face -Y in Blender (+Z in Godot). The cart's origin is the middle of its axle, on the ground.

Run: tools/blender/blender.exe --background --python tools-src/blender/make_oxcart.py
"""
import os
import random
import sys
import bpy
from mathutils import Vector as V

sys.path.append(os.path.dirname(__file__))
import rigkit as rk  # noqa: E402
from lowpoly import Builder, clump  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "creatures")
rnd = random.Random(11)

FUR = [(0.46, 0.33, 0.24), (0.4, 0.28, 0.2), (0.52, 0.38, 0.27), (0.43, 0.3, 0.22)]
PALE = [(0.88, 0.78, 0.62), (0.82, 0.72, 0.56)]
HORN = [(0.94, 0.9, 0.78), (0.88, 0.82, 0.68)]
RED = [(0.62, 0.18, 0.14), (0.7, 0.24, 0.16)]
WOOD = [(0.78, 0.58, 0.36), (0.72, 0.52, 0.32), (0.84, 0.63, 0.4)]
DARKWOOD = [(0.52, 0.38, 0.25), (0.47, 0.34, 0.22)]
IRON = [(0.42, 0.42, 0.45)]
NECK = V((0, -0.95, 1.35))
HIPS = {"FL": V((0.3, -0.7, 1.0)), "FR": V((-0.3, -0.7, 1.0)), "BL": V((0.3, 0.72, 1.0)), "BR": V((-0.3, 0.72, 1.0))}


def faceted(b, pts, radii, palette, seg=6, ref=V((1, 0, 0)), mat="Ox"):
    faces = b.new_faces(lambda: rk.tube(b.bm, pts, radii, ref=ref, seg=seg))
    for f in faces:
        b.paint([f], mat, rnd.choice(palette))
    return faces


def box(b, c, size, palette, mat="Ox"):
    """A plain box (planks, boards, the yoke), one colour."""
    import bmesh
    faces = b.new_faces(lambda: bmesh.ops.create_cube(b.bm, size=1.0, matrix=(
        __import__("mathutils").Matrix.Translation(c) @ __import__("mathutils").Matrix.Diagonal((size[0], size[1], size[2], 1.0)))))
    b.paint(faces, mat, rnd.choice(palette))
    return faces


def ox_body():
    b = Builder(["Ox"])
    pts = [V((0, 1.05, 1.18)), V((0, 0.8, 1.3)), V((0, 0.3, 1.34)), V((0, -0.3, 1.46)), V((0, -0.8, 1.5)), V((0, -1.02, 1.36))]
    faceted(b, pts, [(0.2, 0.22), (0.46, 0.44), (0.52, 0.5), (0.56, 0.56), (0.5, 0.56), (0.32, 0.38)], FUR, seg=8)
    clump(b, V((0, -0.6, 1.95)), 0.36, 1, rnd, FUR[1], "Ox", 0.75)                   # the hump
    for i in range(14):                                                             # shaggy locks hanging down the flanks
        y = -0.9 + i * 0.14
        for s in (1, -1):
            top = V((s * 0.5, y, 1.25 + rnd.uniform(-0.05, 0.1)))
            faceted(b, [top, top + V((s * 0.06, 0.02, -0.38 - rnd.uniform(0, 0.12)))], [(0.09, 0.05), (0.01, 0.01)], FUR, seg=4)
    # A red blanket over the back, and the wooden yoke on the shoulders.
    faceted(b, [V((0, -0.2, 1.62)), V((0, 0.45, 1.6))], [(0.62, 0.2), (0.6, 0.2)], RED, seg=4, ref=V((1, 0, 0)))
    box(b, V((0, -0.86, 1.98)), (1.3, 0.14, 0.12), DARKWOOD)
    return b


def ox_head():
    b = Builder(["Ox"])
    pts = [NECK + V((0, 0.12, 0.06)), NECK + V((0, -0.22, 0.0)), NECK + V((0, -0.5, -0.16)), NECK + V((0, -0.7, -0.28))]
    faceted(b, pts, [(0.34, 0.34), (0.3, 0.3), (0.24, 0.22), (0.2, 0.17)], FUR, seg=6)
    muzzle = NECK + V((0, -0.72, -0.3))
    faceted(b, [muzzle + V((0, 0.08, 0)), muzzle + V((0, -0.08, -0.02))], [(0.21, 0.17), (0.19, 0.14)], PALE, seg=6)
    for s in (1, -1):
        clump(b, muzzle + V((s * 0.07, -0.09, 0.0)), 0.03, 1, rnd, (0.15, 0.1, 0.08), "Ox", 1.0)
        eye = NECK + V((s * 0.2, -0.36, 0.08))
        clump(b, eye, 0.035, 1, rnd, (0.08, 0.06, 0.05), "Ox", 1.0)
        base = NECK + V((s * 0.26, -0.18, 0.22))                                     # horns: out, then up and forward
        faceted(b, [base, base + V((s * 0.22, 0.02, 0.02)), base + V((s * 0.4, -0.04, 0.16)), base + V((s * 0.44, -0.14, 0.36))],
                [(0.07, 0.07), (0.055, 0.055), (0.04, 0.04), (0.006, 0.006)], HORN, seg=6)
        faceted(b, [base + V((0, 0.06, -0.02)), base + V((s * 0.14, 0.12, -0.14))], [(0.07, 0.03), (0.02, 0.01)], FUR, seg=4)   # ears
    for i in range(5):                                                                              # a shaggy fringe
        top = NECK + V((rnd.uniform(-0.18, 0.18), -0.3 - i * 0.03, 0.3))
        faceted(b, [top, top + V((0, -0.14, -0.2))], [(0.06, 0.04), (0.01, 0.01)], FUR, seg=4)
    return b


def ox_leg(hip, front):
    b = Builder(["Ox"])
    foot = V((hip.x, hip.y + (-0.03 if front else 0.04), 0.08))
    knee = V((hip.x, hip.y + (0.04 if front else -0.08), 0.5))
    faceted(b, [hip + V((0, 0, 0.15)), knee, foot], [(0.18, 0.2), (0.12, 0.12), (0.1, 0.1)], FUR, seg=6)
    faceted(b, [foot, foot + V((0, -0.03, -0.08))], [(0.11, 0.12), (0.12, 0.13)], DARKWOOD, seg=6)   # hooves
    return b


def ox_tail():
    b = Builder(["Ox"])
    root = V((0, 1.08, 1.3))
    faceted(b, [root, root + V((0, 0.1, -0.3)), root + V((0, 0.12, -0.7))], [(0.05, 0.05), (0.04, 0.04), (0.02, 0.02)], FUR, seg=4)
    clump(b, root + V((0, 0.12, -0.78)), 0.08, 1, rnd, FUR[1], "Ox", 1.3)
    return b


def cart():
    b = Builder(["Ox"])
    # The bed: planks on two long beams, over the axle; low rails; a bench at the front.
    for i in range(6):
        x = -0.6 + i * 0.24
        box(b, V((x, 0.0, 0.82)), (0.22, 2.1, 0.06), WOOD)
    for s in (1, -1):
        box(b, V((s * 0.62, 0.0, 0.74)), (0.1, 2.2, 0.12), DARKWOOD)
        box(b, V((s * 0.72, 0.1, 1.02)), (0.06, 1.9, 0.08), WOOD)                   # side rail
        for y in (-0.8, 0.1, 0.95):
            box(b, V((s * 0.72, y, 0.93)), (0.07, 0.07, 0.2), DARKWOOD)              # rail posts
        # Shafts forward to the ox's yoke.
        faceted(b, [V((s * 0.5, -1.0, 0.76)), V((s * 0.52, -2.2, 0.95)), V((s * 0.6, -3.1, 1.55))], [(0.05, 0.05), (0.045, 0.045), (0.04, 0.04)], DARKWOOD, seg=5)
    box(b, V((0, 1.08, 0.95)), (1.44, 0.07, 0.3), WOOD)                              # back board
    box(b, V((0, -0.7, 1.12)), (1.3, 0.34, 0.08), WOOD)                              # the bench
    for s in (1, -1):
        box(b, V((s * 0.55, -0.7, 0.98)), (0.08, 0.3, 0.26), DARKWOOD)
    box(b, V((0, -0.52, 1.3)), (1.3, 0.05, 0.28), WOOD)                              # bench back
    box(b, V((0, 0.0, 0.52)), (1.5, 0.1, 0.1), DARKWOOD)                             # axle
    return b


def wheel(side):
    b = Builder(["Ox"])
    c = V((side * 0.84, 0, 0.55))
    faceted(b, [c + V((-side * 0.05, 0, 0)), c + V((side * 0.05, 0, 0))], [(0.55, 0.55), (0.55, 0.55)], DARKWOOD, seg=10, ref=V((0, 1, 0)))
    faceted(b, [c + V((-side * 0.09, 0, 0)), c + V((side * 0.09, 0, 0))], [(0.12, 0.12), (0.12, 0.12)], IRON, seg=6, ref=V((0, 1, 0)))
    return b


def to_object(name, b, pivot):
    mesh = bpy.data.meshes.new(name)
    for v in b.bm.verts:
        v.co -= pivot
    import bmesh
    bmesh.ops.remove_doubles(b.bm, verts=b.bm.verts, dist=0.0005)
    bmesh.ops.recalc_face_normals(b.bm, faces=b.bm.faces)
    b.bm.to_mesh(mesh)
    b.bm.free()
    for m in b.mats:
        mesh.materials.append(rk.MATERIALS[m])
    for p in mesh.polygons:
        p.use_smooth = False
    obj = bpy.data.objects.new(name, mesh)
    obj.location = pivot
    bpy.context.collection.objects.link(obj)
    return obj


def export(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name), export_format="GLB", use_selection=True)
    print(name, "tris", rk.tri_count(objs))
    for o in objs:
        bpy.data.objects.remove(o)


bpy.ops.wm.read_factory_settings(use_empty=True)
rk.make_materials({"Ox": (1, 1, 1)}, roughness=0.85)
os.makedirs(OUT, exist_ok=True)
ox = [to_object("Body", ox_body(), V((0, 0, 1.3))), to_object("Head", ox_head(), NECK), to_object("Tail", ox_tail(), V((0, 1.08, 1.3)))]
for key, hip in HIPS.items():
    ox.append(to_object("Leg_" + key, ox_leg(hip, key.startswith("F")), hip))
export(ox, "ox.glb")
export([to_object("Cart", cart(), V((0, 0, 0))), to_object("Wheel_L", wheel(1), V((0.84, 0, 0.55))),
        to_object("Wheel_R", wheel(-1), V((-0.84, 0, 0.55)))], "cart.glb")
