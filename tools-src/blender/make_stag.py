"""Builds the stag (from the owner's reference: a faceted low-poly deer, huge pale branching antlers,
orange coat, cream belly and throat, a dark teal chest and forehead). Separate parts (Body, Head with
neck and antlers, Leg_FL/FR/BL/BR, Tail) whose origins are their pivots, animated in code
(stag_visual.gd). Faces -Y in Blender (+Z in Godot). Exported to game/assets/creatures/stag.glb.

Run: tools/blender/blender.exe --background --python tools-src/blender/make_stag.py
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
OUT = os.path.join(ROOT, "game", "assets", "creatures", "stag.glb")
rnd = random.Random(7)

COAT = [(0.86, 0.46, 0.2), (0.8, 0.4, 0.17), (0.9, 0.52, 0.24), (0.76, 0.36, 0.16)]
CREAM = [(0.95, 0.87, 0.72), (0.9, 0.8, 0.64)]
TEAL = [(0.1, 0.3, 0.31), (0.13, 0.35, 0.35)]
BONE = [(0.93, 0.86, 0.72), (0.88, 0.8, 0.66), (0.97, 0.91, 0.79)]
DARK = (0.12, 0.08, 0.07)
NECK = V((0, -0.5, 1.28))          # where the neck meets the shoulders (the head's pivot)
HIPS = {"FL": V((0.16, -0.42, 1.02)), "FR": V((-0.16, -0.42, 1.02)), "BL": V((0.16, 0.5, 1.02)), "BR": V((-0.16, 0.5, 1.02))}


def faceted(b, pts, radii, palette, seg=6, ref=V((1, 0, 0))):
    faces = b.new_faces(lambda: rk.tube(b.bm, pts, radii, ref=ref, seg=seg))
    for f in faces:
        b.paint([f], "Stag", rnd.choice(palette))
    return faces


def recolor(b, faces, test, palette):
    """Repaint the faces whose centre passes `test` (a belly, a chest patch)."""
    for f in faces:
        if test(f.calc_center_median()):
            b.paint([f], "Stag", rnd.choice(palette))


def body():
    b = Builder(["Stag", "Eye"])
    # A deep barrel chest and a round rump (the first one was a thin tube on stilts).
    pts = [V((0, 0.78, 1.16)), V((0, 0.62, 1.2)), V((0, 0.32, 1.14)), V((0, -0.04, 1.16)), V((0, -0.38, 1.28)), V((0, -0.62, 1.24)), V((0, -0.72, 1.14))]
    faces = faceted(b, pts, [(0.16, 0.18), (0.34, 0.38), (0.36, 0.42), (0.38, 0.46), (0.37, 0.5), (0.28, 0.38), (0.14, 0.18)], COAT, seg=8)
    recolor(b, faces, lambda c: c.z < 0.88, CREAM)                        # pale belly
    recolor(b, faces, lambda c: c.y < -0.4 and c.z < 1.18, TEAL)          # the dark chest
    return b


def head():
    b = Builder(["Stag", "Eye"])
    # A long neck rising forward, then the narrow head pointing down the muzzle.
    neck = [NECK + V((0, 0.06, -0.06)), NECK + V((0, -0.12, 0.3)), NECK + V((0, -0.24, 0.62)), NECK + V((0, -0.3, 0.78))]
    nf = faceted(b, neck, [(0.3, 0.36), (0.22, 0.26), (0.16, 0.18), (0.14, 0.15)], COAT, seg=6)
    recolor(b, nf, lambda c: c.y < NECK.y - 0.12 and c.z < NECK.z + 0.55, CREAM)    # the pale throat
    recolor(b, nf, lambda c: c.y < NECK.y - 0.05 and c.z < NECK.z + 0.12, TEAL)
    top = NECK + V((0, -0.3, 0.82))
    hf = faceted(b, [top + V((0, 0.08, 0.02)), top + V((0, -0.1, -0.02)), top + V((0, -0.3, -0.14)), top + V((0, -0.4, -0.2))],
                 [(0.12, 0.13), (0.12, 0.12), (0.07, 0.07), (0.05, 0.05)], COAT, seg=6)
    recolor(b, hf, lambda c: c.z > top.z + 0.02 and c.y < top.y + 0.02, TEAL)       # forehead blaze
    faceted(b, [top + V((0, -0.4, -0.2)), top + V((0, -0.43, -0.21))], [(0.05, 0.05), (0.04, 0.04)], [DARK], seg=5)   # nose
    for s in (1, -1):
        eye = top + V((s * 0.1, -0.08, 0.02))
        b.paint(b.new_faces(lambda eye=eye: clump(b, eye, 0.025, 1, rnd, DARK, "Eye", 1.0)), "Eye", DARK)
        ear = top + V((s * 0.1, 0.06, 0.08))
        faceted(b, [ear, ear + V((s * 0.2, 0.04, 0.06)), ear + V((s * 0.3, 0.06, 0.05))], [(0.04, 0.02), (0.045, 0.02), (0.005, 0.004)],
                [COAT[0], CREAM[0]], seg=4, ref=V((0, 0, 1)))
        antler(b, top + V((s * 0.06, 0.04, 0.1)), s)
    return b


def antler(b, base, s):
    """A great curving beam, up and out then curling back in (a C seen from the front), with tines."""
    beam = [base, base + V((s * 0.16, 0.02, 0.22)), base + V((s * 0.42, 0.06, 0.5)), base + V((s * 0.62, 0.1, 0.82)),
            base + V((s * 0.66, 0.14, 1.14)), base + V((s * 0.52, 0.16, 1.38)), base + V((s * 0.3, 0.14, 1.5))]
    radii = [(0.045, 0.045), (0.04, 0.04), (0.035, 0.035), (0.03, 0.03), (0.026, 0.026), (0.02, 0.02), (0.006, 0.006)]
    faceted(b, beam, radii, BONE, seg=5)
    # Tines: short points off the beam, up and forward, and one brow tine low down.
    for i, (dx, dy, dz, length) in {1: (0.02, -0.18, 0.12, 0.26), 2: (-0.05, -0.12, 0.3, 0.32), 3: (0.08, -0.1, 0.3, 0.36),
                                    4: (0.14, -0.06, 0.22, 0.26), 5: (0.02, -0.08, 0.26, 0.22)}.items():
        p = beam[i]
        d = V((s * dx, dy, dz)).normalized() * length
        faceted(b, [p, p + d * 0.6, p + d], [(0.024, 0.024), (0.016, 0.016), (0.004, 0.004)], BONE, seg=4)


def leg(hip, front):
    b = Builder(["Stag"])
    foot = V((hip.x * 1.02, hip.y + (-0.02 if front else 0.04), 0.06))
    knee = V((hip.x, hip.y + (0.04 if front else -0.1), 0.52))
    top = (0.17, 0.22) if not front else (0.15, 0.19)
    faces = faceted(b, [hip + V((0, 0, 0.12)), hip + V((0, 0.02, -0.14)), knee, foot], [top, (0.09, 0.1), (0.055, 0.055), (0.04, 0.04)], COAT, seg=6)
    recolor(b, faces, lambda c: c.z < 0.4, CREAM)
    faceted(b, [foot, foot + V((0, -0.02, -0.06))], [(0.05, 0.06), (0.055, 0.07)], [DARK], seg=5)       # hooves
    return b


def tail():
    b = Builder(["Stag"])
    root = V((0, 0.72, 1.16))
    faceted(b, [root, root + V((0, 0.08, -0.06)), root + V((0, 0.1, -0.18))], [(0.06, 0.04), (0.06, 0.04), (0.01, 0.01)], CREAM, seg=4, ref=V((1, 0, 0)))
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
rk.make_materials({"Stag": (1, 1, 1), "Eye": (1, 1, 1)}, roughness=0.85)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
objs = [to_object("Body", body(), V((0, 0, 1.15))), to_object("Head", head(), NECK), to_object("Tail", tail(), V((0, 0.72, 1.16)))]
for key, hip in HIPS.items():
    objs.append(to_object("Leg_" + key, leg(hip, key.startswith("F")), hip))
bpy.ops.object.select_all(action="DESELECT")
for o in objs:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True)
print("STAG tris", rk.tri_count(objs), [o.name for o in objs])
