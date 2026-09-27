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

HIDE = [(0.52, 0.45, 0.55), (0.45, 0.39, 0.49), (0.58, 0.5, 0.6)]
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
    b = Builder(["Boar"])
    pts = [V((0, 0.62, 0.6)), V((0, 0.35, 0.64)), V((0, 0.0, 0.66)), V((0, -0.3, 0.7)), V((0, -0.52, 0.66))]
    faceted(b, pts, [(0.2, 0.2), (0.3, 0.3), (0.34, 0.34), (0.36, 0.38), (0.26, 0.28)], HIDE, seg=7)
    # The red mane: tall spikes along the spine, leaning back.
    for i, y in enumerate([-0.42, -0.3, -0.17, -0.04, 0.1, 0.24]):
        h = 0.34 - i * 0.035
        spike(b, V((0, y, 0.95 + (0.03 if i < 3 else 0))), V((0, y + 0.18, 0.98 + h)), 0.07)
    # A few spikes on the shoulders and hips, like armour plates.
    for s in (1, -1):
        spike(b, V((s * 0.3, -0.35, 0.8)), V((s * 0.5, -0.25, 0.95)), 0.06)
        spike(b, V((s * 0.3, 0.3, 0.75)), V((s * 0.48, 0.45, 0.88)), 0.05)
        spike(b, V((s * 0.22, 0.52, 0.72)), V((s * 0.36, 0.72, 0.8)), 0.045)
    faceted(b, [V((0, 0.62, 0.62)), V((0, 0.78, 0.5))], [(0.04, 0.04), (0.01, 0.01)], HIDE, seg=4)   # tail
    return b


def head():
    b = Builder(["Boar"])
    pts = [NECK + V((0, 0.05, 0.02)), NECK + V((0, -0.22, -0.02)), NECK + V((0, -0.42, -0.12)), NECK + V((0, -0.52, -0.16))]
    faceted(b, pts, [(0.25, 0.27), (0.22, 0.23), (0.15, 0.14), (0.12, 0.11)], HIDE, seg=6)
    snout = NECK + V((0, -0.54, -0.16))
    faceted(b, [snout, snout + V((0, -0.04, 0))], [(0.12, 0.1), (0.1, 0.085)], [(0.78, 0.36, 0.36)], seg=6)
    for s in (1, -1):
        # Tusks curving up from the jaw.
        base = NECK + V((s * 0.1, -0.44, -0.2))
        faceted(b, [base, base + V((s * 0.06, -0.06, 0.05)), base + V((s * 0.08, -0.05, 0.16))],
                [(0.03, 0.03), (0.022, 0.022), (0.003, 0.003)], [IVORY], seg=5)
        # Eyes with an angry red brow.
        eye = NECK + V((s * 0.14, -0.3, 0.1))
        clump(b, eye, 0.03, 1, rnd, (0.08, 0.06, 0.07), "Boar", 1.0)
        spike(b, eye + V((-s * 0.04, 0.02, 0.03)), eye + V((s * 0.05, -0.02, 0.06)), 0.025)
        # Ears.
        spike(b, NECK + V((s * 0.14, 0.02, 0.2)), NECK + V((s * 0.24, 0.12, 0.36)), 0.06, HIDE)
    return b


def leg(hip, front):
    b = Builder(["Boar"])
    foot = V((hip.x * 1.05, hip.y + (-0.03 if front else 0.03), 0.07))
    knee = (hip + foot) / 2 + V((0, 0.04 if front else -0.05, 0))
    faceted(b, [hip + V((0, 0, 0.08)), knee, foot], [(0.12, 0.13), (0.075, 0.075), (0.06, 0.06)], HIDE, seg=5)
    faceted(b, [foot, foot + V((0, -0.02, -0.08))], [(0.07, 0.075), (0.075, 0.08)], RED, seg=5)
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
    mesh.materials.append(rk.MATERIALS["Boar"])
    for p in mesh.polygons:
        p.use_smooth = False
    obj = bpy.data.objects.new(name, mesh)
    obj.location = pivot
    bpy.context.collection.objects.link(obj)
    return obj


bpy.ops.wm.read_factory_settings(use_empty=True)
rk.make_materials({"Boar": (1, 1, 1)}, roughness=0.85)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
objs = [to_object("Body", body(), V((0, 0, 0.6))), to_object("Head", head(), NECK)]
for key, hip in HIPS.items():
    objs.append(to_object("Leg_" + key, leg(hip, key.startswith("F")), hip))
bpy.ops.object.select_all(action="DESELECT")
for o in objs:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True)
print("BOAR tris", rk.tri_count(objs), [o.name for o in objs])
