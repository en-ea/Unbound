"""Builds the boar enemy: a faceted dark boar with a red spiked mane, ivory tusks and red hooves.
Made of separate parts (Body, Head, Leg_FL/FR/BL/BR) whose origins are their pivots (neck, hips),
so the game can animate it (trot, charge, flinch, fall). Faces -Y in Blender (+Z in Godot).
Exported to game/assets/creatures/boar.glb.

Run: tools/blender/blender.exe --background --python tools-src/blender/make_boar.py
"""
import math
import os
import random
import sys
import bpy
from mathutils import Vector as V

sys.path.append(os.path.dirname(__file__))
import rigkit as rk  # noqa: E402
from lowpoly import Builder, clump  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "creatures", "boar.glb")
rnd = random.Random(4)

HIDE = [(0.62, 0.54, 0.64), (0.55, 0.47, 0.58), (0.68, 0.59, 0.69)]
RED = [(0.8, 0.22, 0.18), (0.7, 0.18, 0.16), (0.88, 0.3, 0.22)]
IVORY = (0.94, 0.9, 0.78)
NECK = V((0, -0.5, 0.68))
HIPS = {"FL": V((0.2, -0.33, 0.46)), "FR": V((-0.2, -0.33, 0.46)), "BL": V((0.2, 0.38, 0.46)), "BR": V((-0.2, 0.38, 0.46))}


def faceted(b, pts, radii, palette, seg=6, ref=V((1, 0, 0))):
    faces = b.new_faces(lambda: rk.tube(b.bm, pts, radii, ref=ref, seg=seg))
    for f in faces:
        b.paint([f], "Boar", rnd.choice(palette))
    return faces


def spike(b, base, tip, width, palette=RED):
    faced = faceted(b, [base, tip], [(width, width * 0.8), (0.004, 0.004)], palette, seg=4, ref=V((1, 0, 0)))
    return faced


def body():
    b = Builder(["Boar", "Eye"])
    # Heavy, hunched shoulders tapering to lean hindquarters (the back is +Y).
    pts = [V((0, 0.66, 0.58)), V((0, 0.42, 0.6)), V((0, 0.12, 0.64)), V((0, -0.18, 0.72)), V((0, -0.42, 0.72)), V((0, -0.58, 0.64))]
    faceted(b, pts, [(0.16, 0.18), (0.27, 0.28), (0.32, 0.33), (0.39, 0.44), (0.37, 0.42), (0.26, 0.3)], HIDE, seg=8)
    clump(b, V((0, -0.3, 1.0)), 0.26, 1, rnd, HIDE[1], "Boar", 0.7)                 # shoulder hump
    # The red mane: big plates along the spine, tallest over the shoulders, leaning back.
    for i, y in enumerate([-0.5, -0.38, -0.25, -0.12, 0.02, 0.16, 0.3, 0.44]):
        h = 0.42 - abs(i - 2) * 0.05
        z = 1.08 - max(0, i - 2) * 0.05
        spike(b, V((0, y, z)), V((0, y + 0.22, z + h)), 0.085 - i * 0.004)
    for s in (1, -1):
        spike(b, V((s * 0.36, -0.36, 0.84)), V((s * 0.58, -0.24, 1.0)), 0.07)       # shoulder plates
        spike(b, V((s * 0.34, -0.12, 0.8)), V((s * 0.52, 0.02, 0.92)), 0.06)
        spike(b, V((s * 0.26, 0.38, 0.72)), V((s * 0.42, 0.56, 0.82)), 0.05)        # hip plates
    faceted(b, [V((0, 0.66, 0.62)), V((0, 0.78, 0.6)), V((0.04, 0.84, 0.5))], [(0.045, 0.045), (0.03, 0.03), (0.008, 0.008)], HIDE, seg=4)
    return b


def head():
    b = Builder(["Boar", "Eye"])
    pts = [NECK + V((0, 0.08, 0.04)), NECK + V((0, -0.2, 0.0)), NECK + V((0, -0.42, -0.1)), NECK + V((0, -0.58, -0.17))]
    faceted(b, pts, [(0.28, 0.3), (0.25, 0.26), (0.17, 0.16), (0.13, 0.12)], HIDE, seg=6)
    faceted(b, [NECK + V((0, -0.05, 0.2)), NECK + V((0, -0.32, 0.12))], [(0.2, 0.06), (0.14, 0.04)], HIDE, seg=4)   # brow ridge
    faceted(b, [NECK + V((0, -0.2, -0.2)), NECK + V((0, -0.5, -0.24))], [(0.15, 0.06), (0.1, 0.045)], HIDE, seg=4)  # jaw
    snout = NECK + V((0, -0.6, -0.17))
    faceted(b, [snout, snout + V((0, -0.05, 0))], [(0.14, 0.11), (0.12, 0.095)], [(0.82, 0.42, 0.42)], seg=6)
    for s in (1, -1):
        clump(b, snout + V((s * 0.045, -0.06, 0.0)), 0.022, 1, rnd, (0.3, 0.12, 0.12), "Boar", 1.0)   # nostrils
        base = NECK + V((s * 0.11, -0.46, -0.22))                                                    # tusks
        faceted(b, [base, base + V((s * 0.07, -0.07, 0.05)), base + V((s * 0.1, -0.06, 0.18)), base + V((s * 0.07, -0.02, 0.26))],
                [(0.038, 0.038), (0.03, 0.03), (0.018, 0.018), (0.003, 0.003)], [IVORY], seg=5)
        eye = NECK + V((s * 0.16, -0.3, 0.1))
        b.paint(b.new_faces(lambda eye=eye: clump(b, eye, 0.034, 1, rnd, (0.9, 0.2, 0.15), "Eye", 1.0)), "Eye", (0.9, 0.2, 0.15))
        spike(b, eye + V((-s * 0.05, 0.02, 0.04)), eye + V((s * 0.06, -0.03, 0.07)), 0.03)      # angry brow
        spike(b, NECK + V((s * 0.16, 0.04, 0.24)), NECK + V((s * 0.3, 0.16, 0.44)), 0.08, HIDE)   # ears
    return b


def leg(hip, front):
    b = Builder(["Boar"])
    foot = V((hip.x * 1.05, hip.y + (-0.03 if front else 0.03), 0.07))
    knee = (hip + foot) / 2 + V((0, 0.05 if front else -0.07, 0))
    top = (0.14, 0.16) if not front else (0.13, 0.14)
    faceted(b, [hip + V((0, 0, 0.1)), knee, foot], [top, (0.08, 0.08), (0.065, 0.065)], HIDE, seg=6)
    faceted(b, [foot, foot + V((0, -0.03, -0.08))], [(0.075, 0.08), (0.08, 0.09)], RED, seg=6)
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


bpy.ops.wm.read_factory_settings(use_empty=True)
rk.make_materials({"Boar": (1, 1, 1), "Eye": (1, 1, 1)}, roughness=0.85)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
objs = [to_object("Body", body(), V((0, 0, 0.6))), to_object("Head", head(), NECK)]
for key, hip in HIPS.items():
    objs.append(to_object("Leg_" + key, leg(hip, key.startswith("F")), hip))
bpy.ops.object.select_all(action="DESELECT")
for o in objs:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True)
print("BOAR tris", rk.tri_count(objs), [o.name for o in objs])
